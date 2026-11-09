"""
Internal helpers for evaluating independent subcomputations concurrently.

Concurrency is only used on free-threaded CPython builds (where threads run
Python code truly in parallel) and only when more than one CPU is available to
the process.  On GIL-enabled builds, and on a single core, everything runs
sequentially in the calling thread so behaviour and cost are unchanged.

Worker threads never submit work to the pool themselves: a call made from
inside a worker runs sequentially, which avoids pool deadlocks.
"""

import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

__all__ = []

_lock = threading.Lock()
_executor = None
_executor_workers = 0
_local = threading.local()


def _available_cpus():
    try:
        return len(os.sched_getaffinity(0))
    except (AttributeError, OSError):  # pragma: no cover
        return os.cpu_count() or 1


def _is_free_threaded():
    is_gil_enabled = getattr(sys, "_is_gil_enabled", None)
    return is_gil_enabled is not None and not is_gil_enabled()


def _worker_count():
    """Number of threads that may be used right now (1 means sequential)."""
    if getattr(_local, "in_worker", False) or not _is_free_threaded():
        return 1
    return _available_cpus()


def _get_executor(workers):
    global _executor, _executor_workers
    with _lock:
        if _executor is None or _executor_workers != workers:
            if _executor is not None:
                _executor.shutdown(wait=False)
            _executor = ThreadPoolExecutor(max_workers=workers,
                                           thread_name_prefix="sympy-par",
                                           initializer=_mark_worker)
            _executor_workers = workers
        return _executor


def _mark_worker():
    _local.in_worker = True


def parallel_map(func, items):
    """
    Return ``[func(x) for x in items]``, evaluating the calls concurrently
    when that is possible.  Results keep the order of ``items``; if several
    calls raise, the exception of the earliest item is re-raised.
    """
    items = list(items)
    workers = _worker_count()
    if len(items) < 2 or workers < 2:
        return [func(x) for x in items]
    workers = min(workers, len(items))
    executor = _get_executor(workers)
    futures = [executor.submit(func, x) for x in items]
    results = []
    error = None
    for fut in futures:
        try:
            results.append(fut.result())
        except BaseException as exc:  # noqa: BLE001
            if error is None:
                error = exc
    if error is not None:
        raise error
    return results
