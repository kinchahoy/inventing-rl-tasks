"""Internal helpers for within-call parallelism on free-threaded CPython.

Threads are used only when all of the following hold: the interpreter runs
without the GIL, more than one CPU is in the process affinity mask, the caller
is not itself a pool worker, and the thread-local SymPy parameters have their
defaults (worker threads start with the defaults).  Otherwise every helper runs
serially in the calling thread and returns exactly what the plain loop would.

``Basic.doit`` additionally keeps a per-call memo of ``Integral.doit`` results:
equal integrals inside one ``doit`` call are evaluated once.
"""

from __future__ import annotations

import os
import sys
import threading


class _State(threading.local):
    # Class attributes are the per-thread defaults.
    busy = False  # inside a doit scope, or a pool worker: never start another one
    memo = None  # Integral.doit results of the current doit scope


state = _State()

_FAILED = object()
_pool = None
_pool_lock = threading.Lock()


def _cpus():
    try:
        return len(os.sched_getaffinity(0))
    except AttributeError:
        return os.cpu_count() or 1


def _mark_worker():
    state.busy = True


def _get_pool():
    global _pool
    if _pool is None:
        with _pool_lock:
            if _pool is None:
                from concurrent.futures import ThreadPoolExecutor

                _pool = ThreadPoolExecutor(
                    max_workers=_cpus(),
                    thread_name_prefix="sympy-par",
                    initializer=_mark_worker,
                )
    return _pool


def parallel_ok():
    """True if the calling thread may fan work out to the pool."""
    if state.busy or getattr(sys, "_is_gil_enabled", lambda: True)():
        return False
    if _cpus() < 2:
        return False
    from sympy.core.parameters import global_parameters as gp

    utilities = sys.modules.get("sympy.matrices.utilities")
    return bool(gp.evaluate and gp.distribute and not gp.exp_is_pow
                and (utilities is None or utilities._dotprodsimp_state.state is None))


def pmap(func, items):
    """``[func(item) for item in items]``, evaluated on the pool when allowed.

    Results keep the input order; the first exception in input order is raised.
    ``func`` must not rely on thread-local SymPy state.
    """
    items = list(items)
    if len(items) < 2 or not parallel_ok():
        return [func(item) for item in items]
    pool = _get_pool()
    futures = [pool.submit(func, item) for item in items]
    try:
        return [future.result() for future in futures]
    except BaseException:
        for future in futures:
            future.cancel()
        raise


def hints_key(hints):
    try:
        key = tuple(sorted(hints.items()))
        hash(key)
    except TypeError:
        return None
    return key


def _top_integrals(expr):
    """Distinct outermost ``Integral`` nodes of ``expr`` in first-seen order."""
    from sympy.core.basic import Basic
    from sympy.integrals.integrals import Integral

    found = {}
    seen = set()
    stack = [expr]
    while stack:
        node = stack.pop()
        if not isinstance(node, Basic) or node in seen:
            continue
        seen.add(node)
        if isinstance(node, Integral):
            found.setdefault(node, None)
        else:
            stack.extend(reversed(node.args))
    return list(found)


def _size(node):
    count = 0
    stack = [node]
    while stack:
        item = stack.pop()
        count += 1
        stack.extend(getattr(item, "args", ()))
    return count


def _evaluate(job):
    integral, hints = job
    try:
        return integral.doit(**hints)
    except Exception:
        # Recomputed (and raised) in order by the serial pass.
        return _FAILED


def _prefill(memos, exprs, hints, hk):
    """Evaluate the distinct integrals of every expression on the pool into its memo."""
    jobs = []
    for memo, expr in zip(memos, exprs):
        for integral in _top_integrals(expr):
            jobs.append((_size(integral.function), memo, integral))
    if len(jobs) < 2:
        return
    jobs.sort(key=lambda job: -job[0])  # longest first for a balanced schedule
    results = pmap(_evaluate, [(integral, hints) for _, _, integral in jobs])
    for (_, memo, integral), result in zip(jobs, results):
        if result is not _FAILED:
            memo[(integral, hk)] = result


def enter(expr, hints):
    """Open the doit scope of an outermost ``Basic.doit`` body: deduplicate (and parallelise) its integrals."""
    hk = hints_key(hints)
    memo = None if hk is None else {}
    if memo is not None and "sympy.integrals.integrals" in sys.modules and parallel_ok():
        _prefill([memo], [expr], hints, hk)
    state.busy = True
    state.memo = memo


def leave():
    state.busy = False
    state.memo = None


def doit_all(exprs, **hints):
    """``[e.doit(**hints) for e in exprs]`` with all expressions' integrals evaluated in parallel.

    Each expression keeps its own memo, as if ``doit`` had been called on it separately.
    """
    exprs = list(exprs)
    hk = hints_key(hints)
    if hk is None or not exprs or "sympy.integrals.integrals" not in sys.modules or not parallel_ok():
        return [expr.doit(**hints) for expr in exprs]
    memos = [{} for _ in exprs]
    _prefill(memos, exprs, hints, hk)

    def rebuild(job):
        memo, expr = job
        busy, state.busy, state.memo = state.busy, True, memo
        try:
            return expr.doit(**hints)
        finally:
            state.busy, state.memo = busy, None

    return pmap(rebuild, list(zip(memos, exprs)))
