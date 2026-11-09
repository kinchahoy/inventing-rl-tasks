"""Generic serial RPC worker for one library (reference or submission).

Receives only the serialised inputs of the current invocation, builds them through the non-secret
adapter, runs the single public call, and returns the raw encoded outcome. Encoding the result and
taking the after-snapshot happen before the response line is written, i.e. inside the parent's clock. After the result
line, an untimed SPLIT line reports the worker's own seconds in the call and in snapshot+encode+serialise; the parent
trusts it only when the worker runs the reference library. It holds no expected
answers, case pools, thresholds, or checks; the trusted parent compares against the reference.
"""

from __future__ import annotations

import json
import os
import sys
import time
from collections.abc import Callable
from typing import Any

from sandbox import restrict

THREAD_SETTLE_SECONDS = 2.0


def threads() -> int:
    """OS-level thread count, including threads not created through `threading`."""
    return len(os.listdir("/proc/self/task"))


def main() -> None:
    library, cpus, expected_gil, version = sys.argv[1:]
    os.sched_setaffinity(0, {int(cpu) for cpu in cpus.split(",")})
    restrict()
    sys.path.insert(0, library)
    from adapter import encode, prepare

    expected_version = tuple(int(part) for part in version.split("."))

    print("INITIALIZED", flush=True)
    for line in sys.stdin:
        job = json.loads(line)["job"]
        operation: Callable[[], Any]
        snapshot: Callable[[], Any]
        operation, snapshot = prepare(job)
        before = snapshot()
        if sys.version_info[:3] != expected_version or sys._is_gil_enabled() != bool(int(expected_gil)):
            raise RuntimeError("Wrong Python build or GIL mode after library setup")
        affinity = set(os.sched_getaffinity(0))
        baseline = threads()
        print(f"READY {baseline}", flush=True)
        if sys.stdin.readline().strip() != "GO":
            raise RuntimeError("Missing invocation signal")
        result: Any = None
        error: dict[str, str] | None = None
        call_start = time.perf_counter()
        try:
            result = operation()
        except Exception as failure:  # noqa: BLE001 -- exceptions are observable differential results.
            error = {
                "type": f"{type(failure).__module__}.{type(failure).__qualname__}",
                "message": str(failure),
            }
        call_seconds = time.perf_counter() - call_start
        encode_start = time.perf_counter()
        response = {
            "result": encode(result) if error is None else None,
            "exception": error,
            "before": before,
            "after": snapshot(),
        }
        if sys._is_gil_enabled() != bool(int(expected_gil)) or set(os.sched_getaffinity(0)) != affinity:
            raise RuntimeError("The call changed GIL mode or CPU affinity")
        line = json.dumps(response, sort_keys=True, allow_nan=False)
        encode_seconds = time.perf_counter() - encode_start
        print(line, flush=True)
        print(f"SPLIT {call_seconds!r} {encode_seconds!r}", flush=True)
        # Untimed diagnostic: report threads still alive after a short settle window.
        deadline = time.monotonic() + THREAD_SETTLE_SECONDS
        while threads() > baseline and time.monotonic() < deadline:
            time.sleep(0.01)
        print(f"THREADS {threads()}", flush=True)


if __name__ == "__main__":
    main()
