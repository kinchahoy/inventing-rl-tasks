"""Private draft verifier (trusted parent).

Timed samples run in fresh worker processes; the parent clock runs from GO to the complete encoded result.
The fixed cost of snapshotting/encoding a correct result is subtracted using a trusted estimate measured on the
reference library (E_gil from the reference GIL run, E_ft from a reference one-core free-threaded run); the
submission's own reported split is never used.

The parent owns case generation (the timed operations are baked in config.json), reference answers, comparison, clocks, and
the verdict. Workers (reference and submission) receive one serialised job at a time and return
raw encoded outcomes; see worker.py. Only worker.py, sandbox.py, and adapter.py are exposed to them.
"""

from __future__ import annotations

import json
import os
import random
import selectors
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
LOG = Path("/logs/verifier")
REFERENCE = Path("/opt/reference")
CONFIG = json.loads((ROOT / "config.json").read_text())
PYTHON = {True: "python-gil", False: "python-ft"}
VERSION = CONFIG["python_version"]
REFERENCE_UID = 65533  # reference worker; may read /opt/reference
SUBMISSION_UID = 65534  # submission worker; may read neither /opt/reference nor /tests
SCRATCH = ("/tmp", "/var/tmp", "/dev/shm")  # noqa: S108 -- world-writable locations workers could use to persist state

sys.path.append(str(REFERENCE))  # after ROOT, so the reference package can never shadow private modules
from workloads import correctness_cases, operation_cases  # noqa: E402


def performance_rows(seed: int) -> list[dict[str, Any]]:
    """Baked operations (config.json "operations"): one row each, with one input per repetition."""
    variants = [operation_cases(seed, variant) for variant in range(CONFIG["repetitions"])]
    return [{"label": label, "cases": [variant[label] for variant in variants]} for label in CONFIG["operations"]]


def isolate_reference() -> None:
    """Make /opt/reference and /tests unreadable to the submission worker's uid."""
    if os.geteuid() != 0:
        raise RuntimeError("The verifier must run as root to isolate private files from the submission worker")
    subprocess.run(["chown", "-R", f"root:{REFERENCE_UID}", str(REFERENCE)], check=True)
    subprocess.run(["chmod", "-R", "u=rwX,g=rX,o=", str(REFERENCE)], check=True)
    if ROOT.stat().st_mode & 0o007:
        raise RuntimeError(f"{ROOT} must not be accessible to other users (test.sh sets mode 700)")


def scrub(uid: int) -> None:
    """Delete files a worker left in shared scratch locations so no state crosses worker runs."""
    for top in SCRATCH:
        subprocess.run(["find", top, "-xdev", "-user", str(uid), "-delete"], check=False, capture_output=True)


def stage(package: str, dependencies: list[str], directory: Path) -> tuple[Path, Path]:
    """Copy the submission and its allowed dependencies into worker-readable, read-only trees."""
    submitted = Path("/app") / package
    if submitted.is_symlink() or not submitted.is_dir():
        raise ValueError("Submitted package must be a real directory")
    for source in submitted.rglob("*"):
        if source.is_symlink():
            raise ValueError(f"Source symlink is not permitted: {source.relative_to(submitted)}")
        if source.is_file() and source.suffix.lower() in {".so", ".pyd", ".dll", ".dylib"}:
            raise ValueError("Native algorithm binaries are outside this track")
    ignore = shutil.ignore_patterns("__pycache__", "*.pyc")
    library, deps = directory / "library", directory / "deps"
    shutil.copytree(submitted, library / package, ignore=ignore)
    deps.mkdir()
    for name in dependencies:
        shutil.copytree(REFERENCE / name, deps / name, ignore=ignore)
    for tree in (library, deps):
        for path in tree.rglob("*"):
            path.chmod(0o755 if path.is_dir() else 0o444)
        tree.chmod(0o755)
    return library, deps


class Worker:
    """One persistent interpreter; each timed request remains a single API call."""

    def __init__(self, library: Path, path: Path, cpus: list[int], gil: bool, runner: Path, uid: int | None) -> None:
        self.uid = uid
        self.encode_seconds = 0.0
        self.buffer = b""
        self.error_log = tempfile.TemporaryFile()
        self.process = subprocess.Popen(
            [PYTHON[gil], "-B", "-X", f"gil={int(gil)}", str(runner / "worker.py"),
             str(library), ",".join(map(str, cpus)), str(int(gil)), ".".join(map(str, VERSION))],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.error_log,
            env={"PATH": "/usr/local/bin:/usr/bin:/bin", "PYTHONPATH": str(path),
                 "SYMPY_GROUND_TYPES": "python", "PYTHON_JIT": "0",
                 "PYTHONDONTWRITEBYTECODE": "1", "PYTHONHASHSEED": "0"},
            cwd="/tmp", user=uid, group=uid, extra_groups=[] if uid is not None else None,  # noqa: S108
        )
        try:
            if self.read(CONFIG["startup_timeout_seconds"]) != "INITIALIZED":
                raise RuntimeError("Worker failed to initialize")
        except BaseException:
            self.close()
            raise

    def read(self, timeout: float) -> str:
        """Next line from the worker; buffers raw reads so already-received lines are never missed."""
        if self.process.stdout is None:
            raise RuntimeError("Worker stdout missing")
        fd = self.process.stdout.fileno()
        deadline = time.monotonic() + timeout
        while b"\n" not in self.buffer:
            remaining = deadline - time.monotonic()
            with selectors.DefaultSelector() as selector:
                selector.register(fd, selectors.EVENT_READ)
                if remaining <= 0 or not selector.select(remaining):
                    raise TimeoutError("Worker response timeout")
            chunk = os.read(fd, 1 << 20)
            if not chunk:
                self.error_log.seek(0)
                raise RuntimeError(self.error_log.read().decode(errors="replace")[-3000:])
            self.buffer += chunk
        line, _, self.buffer = self.buffer.partition(b"\n")
        return line.decode().strip()

    def send(self, value: str) -> None:
        if self.process.stdin is None:
            raise RuntimeError("Worker stdin missing")
        self.process.stdin.write((value + "\n").encode())
        self.process.stdin.flush()

    def call(self, job: dict[str, Any]) -> tuple[Any, float, int]:
        """Return (outcome, parent-clock seconds from GO to the complete result line, extra threads after).

        The worker's self-reported snapshot+encode+serialise seconds are left in `self.encode_seconds`
        (trusted only for the reference worker).
        """
        self.send(json.dumps({"job": job}))
        ready = self.read(CONFIG["call_timeout_seconds"]).split()
        if len(ready) != 2 or ready[0] != "READY":
            raise RuntimeError("Worker did not prepare the public operation")
        started = time.perf_counter()
        self.send("GO")
        line = self.read(CONFIG["call_timeout_seconds"])
        elapsed = time.perf_counter() - started
        result = json.loads(line)
        split = self.read(CONFIG["call_timeout_seconds"] + 5).split()
        if len(split) != 3 or split[0] != "SPLIT":
            raise RuntimeError("Worker did not report its timing split")
        self.encode_seconds = float(split[2])
        report = self.read(CONFIG["call_timeout_seconds"] + 5).split()
        if len(report) != 2 or report[0] != "THREADS":
            raise RuntimeError("Worker did not report its thread count")
        return result, elapsed, int(report[1]) - int(ready[1])

    def close(self) -> None:
        if self.process.poll() is None:
            self.process.kill()
        self.process.communicate()
        self.error_log.close()
        if self.uid is not None:
            scrub(self.uid)


THREAD_NOTES: list[dict[str, Any]] = []


def note_threads(mode: str, label: str, extra: int) -> None:
    """Diagnostic only: threads still alive after the settle window. Never affects pass/fail."""
    if extra > 0:
        THREAD_NOTES.append({"mode": mode, "case": label, "extra_threads": extra})


def one_shot(
    library: Path, path: Path, cpus: list[int], gil: bool, runner: Path, uid: int, job: dict[str, Any],
) -> tuple[Any, float, int, float]:
    """One timed sample in a fresh process; startup and import are outside the clock.

    Returns (outcome, clock seconds, extra threads, worker-reported encode seconds).
    """
    worker = Worker(library, path, cpus, gil, runner, uid)
    try:
        return (*worker.call(job), worker.encode_seconds)
    finally:
        worker.close()


def run_reference(
    runner: Path, cpu: int, small: list[dict[str, Any]], performance: list[dict[str, Any]],
) -> tuple[list[Any], list[list[Any]], list[list[float]], list[list[float]], list[list[float]]]:
    """Reference answers for the small cases and every timed input, plus one-core timings.

    Each timed input is run in a fresh process on GIL (T_original, E_gil) and, for the encode estimate,
    on free-threaded with one core (E_ft, plus its total for the record). Returns
    (small answers, answers, original totals, E_gil, E_ft, ft totals).
    """
    expected_small: list[Any] = []
    worker = Worker(REFERENCE, REFERENCE, [cpu], True, runner, REFERENCE_UID)
    try:
        for case in small:
            result, _, extra = worker.call(case)
            note_threads("reference", f"correctness:{len(expected_small)}", extra)
            expected_small.append(result)
    finally:
        worker.close()
    expected: list[list[Any]] = []
    original_times: list[list[float]] = []
    encode_gil: list[list[float]] = []
    encode_ft: list[list[float]] = []
    reference_ft_times: list[list[float]] = []
    for row in performance:
        answers, times, e_gil, e_ft, ft_times = [], [], [], [], []
        for case in row["cases"]:
            result, elapsed, extra, encode = one_shot(REFERENCE, REFERENCE, [cpu], True, runner, REFERENCE_UID, case)
            note_threads("reference", row["label"], extra)
            if result["exception"] is not None:
                raise RuntimeError(f"Original performance fixture raises an exception: {row['label']}")
            answers.append(result)
            times.append(elapsed)
            e_gil.append(encode)
            _, ft_elapsed, extra, encode = one_shot(REFERENCE, REFERENCE, [cpu], False, runner, REFERENCE_UID, case)
            note_threads("reference_ft", row["label"], extra)
            e_ft.append(encode)
            ft_times.append(ft_elapsed)
        expected.append(answers)
        original_times.append(times)
        encode_gil.append(e_gil)
        encode_ft.append(e_ft)
        reference_ft_times.append(ft_times)
    return expected_small, expected, original_times, encode_gil, encode_ft, reference_ft_times


def run_submission(
    name: str, gil: bool, count: int, cpus: list[int], library: Path, deps: Path, runner: Path,
    small: list[dict[str, Any]], performance: list[dict[str, Any]],
    expected_small: list[Any], expected: list[list[Any]],
) -> tuple[list[dict[str, Any]], list[list[float]] | None]:
    """Run one mode; return correctness failures and timings (None if the mode did not finish).

    Correctness cases share one process; every timed input gets a fresh process. The GIL mode is
    checked for correctness only, so it runs the first input of each timed case.
    """
    failures: list[dict[str, Any]] = []
    times_by_case: list[list[float]] = []
    try:
        worker = Worker(library, deps, cpus[:count], gil, runner, SUBMISSION_UID)
        try:
            for index, case in enumerate(small):
                actual, _, extra = worker.call(case)
                note_threads(name, f"correctness:{index}", extra)
                if actual != expected_small[index]:
                    failures.append({"mode": name, "case": index, "reason": "mismatch"})
        finally:
            worker.close()
        for index, row in enumerate(performance):
            times = []
            for sample, case in enumerate(row["cases"][: 1 if gil else None]):
                actual, elapsed, extra, _ = one_shot(library, deps, cpus[:count], gil, runner, SUBMISSION_UID, case)
                if actual != expected[index][sample]:
                    failures.append({"mode": name, "operation": row["label"], "input": sample,
                                     "reason": "timed_mismatch"})
                note_threads(name, row["label"], extra)
                times.append(elapsed)
            times_by_case.append(times)
    except (RuntimeError, TimeoutError) as failure:
        failures.append({"mode": name, "reason": "worker_error", "error": str(failure)})
        return failures, None
    return failures, times_by_case


MAX_ENCODE_FRACTION = 0.8


def effective(
    total: list[float], encode: list[float], where: str, errors: list[str],
) -> list[float]:
    """Per-input T - E; a non-positive result or E > 80% of T is a verifier error (no tiny denominators)."""
    out = []
    for sample, (t, e) in enumerate(zip(total, encode, strict=True)):
        if t - e <= 0 or e > MAX_ENCODE_FRACTION * t:
            errors.append(f"{where} input {sample}: total {t:.4f}s, encode estimate {e:.4f}s")
        out.append(t - e)
    return out


def assess(
    performance: list[dict[str, Any]], original_times: list[list[float]], measurements: dict[str, list[list[float]]],
    encode_gil: list[list[float]], encode_ft: list[list[float]],
) -> dict[str, Any]:
    """Gates on effective times: T_original_eff = T_original - E_gil, T_N_eff = T_N - E_ft (reference estimates)."""
    allocations = CONFIG["cpu_allocations"]
    rows = []
    errors: list[str] = []
    for index, row in enumerate(performance):
        label = row["label"]
        original = effective(original_times[index], encode_gil[index], f"{label} original", errors)
        eff = {name: effective(values[index], encode_ft[index], f"{label} {name}", errors)
               for name, values in measurements.items() if name != "gil"}
        one = eff["ft_1"]
        # Paired per-input ratios (input i against the original on the same input i), then the median.
        regression = statistics.median(o1 / o for o1, o in zip(one, original, strict=True))
        gates = {"serial": regression <= CONFIG["maximum_serial_regression"]}
        metrics: dict[str, Any] = {"serial_regression": regression}
        # Each allocation must beat the previous one (paired per input): end-to-end rows by
        # minimum_step_speedup, constituent operations by minimum_step_speedup_constituent.
        previous = one
        for count in allocations:
            if count == 1:
                continue
            elapsed = eff[f"ft_{count}"]
            overall = statistics.median(o / e for o, e in zip(original, elapsed, strict=True))
            scaling = statistics.median(o1 / e for o1, e in zip(one, elapsed, strict=True))
            step = statistics.median(p / e for p, e in zip(previous, elapsed, strict=True))
            metrics[str(count)] = {"overall_speedup": overall, "scaling": scaling, "step_speedup": step}
            required = CONFIG["minimum_step_speedup" if label.startswith("end_to_end:") else "minimum_step_speedup_constituent"]
            gates[str(count)] = step >= required
            previous = elapsed
        rows.append({"operation": label, "metrics": metrics, "gates": gates,
                     "original_samples": original_times[index], "encode_gil": encode_gil[index],
                     "original_effective": original, "encode_ft": encode_ft[index],
                     "submitted_samples": {name: values[index] for name, values in measurements.items()},
                     "submitted_effective": eff})
    return {"passed": not errors and all(all(row["gates"].values()) for row in rows), "rows": rows,
            "verifier_errors": errors}


def serial_failures(
    performance: list[dict[str, Any]], original_times: list[list[float]], one_core: list[list[float]],
    encode_gil: list[list[float]], encode_ft: list[list[float]],
) -> list[str]:
    """Rows already failing the single-core limit (same paired median as assess); [] if unsure."""
    errors: list[str] = []
    slow = []
    for index, row in enumerate(performance):
        original = effective(original_times[index], encode_gil[index], row["label"], errors)
        one = effective(one_core[index], encode_ft[index], row["label"], errors)
        if errors:
            return []  # let the full assessment report verifier errors
        regression = statistics.median(o1 / o for o1, o in zip(one, original, strict=True))
        if regression > CONFIG["maximum_serial_regression"]:
            slow.append(row["label"])
    return slow


def verify() -> dict[str, Any]:
    isolate_reference()
    physical: dict[tuple[str, str], int] = {}
    for cpu in sorted(os.sched_getaffinity(0)):
        topology = Path(f"/sys/devices/system/cpu/cpu{cpu}/topology")
        key = ((topology / "physical_package_id").read_text(), (topology / "core_id").read_text())
        physical.setdefault(key, cpu)
    all_cpus = list(physical.values())
    allocations = CONFIG["cpu_allocations"]
    if len(all_cpus) < max(allocations):
        raise RuntimeError("Insufficient distinct physical cores for configured verifier allocations")
    os.sched_setaffinity(0, {all_cpus[0]})
    seed = random.SystemRandom().randrange(2**63)
    performance = performance_rows(seed)
    small = correctness_cases(seed ^ 0xA531)
    with tempfile.TemporaryDirectory(prefix="third-attempt-") as temporary:
        directory = Path(temporary)
        directory.chmod(0o755)
        runner = directory / "runner"
        runner.mkdir(mode=0o755)
        for name in ("worker.py", "sandbox.py", "adapter.py"):
            shutil.copyfile(ROOT / name, runner / name)
            (runner / name).chmod(0o444)
        library, deps = stage(CONFIG["package"], CONFIG["dependencies"], directory)
        expected_small, expected, original_times, encode_gil, encode_ft, reference_ft = run_reference(runner, all_cpus[0], small, performance)
        failures: list[dict[str, Any]] = []
        measurements: dict[str, list[list[float]]] = {}
        incomplete: list[str] = []
        early_exit = ""  # once the reward is certainly 0, skip the remaining (slow) modes
        for name, gil, count in [("gil", True, 1)] + [(f"ft_{n}", False, n) for n in allocations]:
            mode_failures, times = run_submission(
                name, gil, count, all_cpus, library, deps, runner, small, performance, expected_small, expected
            )
            failures.extend(mode_failures)
            if times is None:
                incomplete.append(name)
            else:
                measurements[name] = times
            if failures:
                early_exit = f"correctness failed in mode {name}; remaining modes skipped"
                break
            if name == "ft_1" and times is not None:
                slow = serial_failures(performance, original_times, times, encode_gil, encode_ft)
                if slow:
                    early_exit = f"single-core limit failed for {slow}; multi-core modes skipped"
                    break
    correctness = {"passed": not failures, "cases": len(small) + sum(len(row["cases"]) for row in performance), "failures": failures}
    if early_exit:
        timing: dict[str, Any] = {"passed": False, "skipped": early_exit}
    elif incomplete:
        timing = {"passed": False, "skipped": f"no complete timings for modes: {incomplete}"}
    else:
        timing = assess(performance, original_times, measurements, encode_gil, encode_ft)
        timing["reference_ft_1_samples"] = reference_ft
    failure = {"failure": "verifier_setup_or_execution_error", "error": timing["verifier_errors"]} if timing.get("verifier_errors") else {}
    return {"reward": float(correctness["passed"] and timing["passed"]), **failure, "correctness": correctness,
            "performance": timing, "diagnostics": {"extra_threads_after_call": THREAD_NOTES}, "seed": seed, "config": CONFIG}


if __name__ == "__main__":
    LOG.mkdir(parents=True, exist_ok=True)
    LOG.chmod(0o700)
    try:
        report = verify()
    except Exception as failure:  # noqa: BLE001 -- infrastructure failures must be explicit, never headroom evidence.
        report = {"reward": 0.0, "failure": "verifier_setup_or_execution_error",
                  "error": f"{type(failure).__name__}: {failure}"}
    (LOG / "checks.json").write_text(json.dumps(report, indent=2, allow_nan=False))
    (LOG / "reward.txt").write_text(str(report["reward"]))
    summary = {key: report[key].get("passed") for key in ("correctness", "performance") if key in report}
    print(json.dumps({"reward": report["reward"], **summary, **{k: report[k] for k in ("failure", "error") if k in report}}))
