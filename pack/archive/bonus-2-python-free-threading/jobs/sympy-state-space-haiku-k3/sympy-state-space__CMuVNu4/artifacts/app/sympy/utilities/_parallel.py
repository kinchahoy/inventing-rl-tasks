"""Internal helpers for order-preserving, thread-level parallel maps.

On a free-threaded CPython build (where Python code can run concurrently on
several cores) independent entries of a symbolic computation can be processed
by a small thread pool.  On a GIL build, or when only one CPU is available to
the process, or when the work list is trivially small, the map is executed
serially in the calling thread, exactly as a list comprehension would be.

Results are always returned in input order and the first exception (in input
order) is re-raised, so the observable behaviour matches the serial loop.
"""

import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

from sympy.core.parameters import global_parameters

__all__ = ['pmap', 'parallel_enabled']

_state = threading.local()


def _ncpus():
    try:
        return len(os.sched_getaffinity(0))
    except (AttributeError, OSError):  # pragma: no cover
        return os.cpu_count() or 1


_NCPUS = None


def _available_cpus():
    global _NCPUS
    if _NCPUS is None:
        _NCPUS = max(1, _ncpus())
    return _NCPUS


def parallel_enabled():
    """Return True when thread-level parallelism is worth using here."""
    is_gil_enabled = getattr(sys, '_is_gil_enabled', None)
    if is_gil_enabled is None or is_gil_enabled():
        return False
    return _available_cpus() > 1 and not getattr(_state, 'in_worker', False)


def _run_in_worker(func, item, params):
    gp = global_parameters
    for name, value in params.items():
        if getattr(gp, name, None) != value:
            setattr(gp, name, value)
    _state.in_worker = True
    try:
        return func(item)
    finally:
        _state.in_worker = False


def pmap(func, items):
    """Return ``[func(x) for x in items]``, evaluated in parallel when useful.

    ``func`` must be safe to call from several threads at once and must not
    depend on the order in which the calls are made beyond what the serial
    loop already guarantees (the returned list is always in input order).
    """
    items = list(items)
    n = len(items)
    if n < 2 or not parallel_enabled():
        return [func(x) for x in items]

    params = dict(vars(global_parameters))
    workers = min(n, _available_cpus())
    with ThreadPoolExecutor(max_workers=workers) as ex:
        return list(ex.map(lambda x: _run_in_worker(func, x, params), items))
