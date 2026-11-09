"""A small shared thread pool for the Earley parser.

Work is only ever handed to threads on free-threaded builds with more than one usable CPU; everywhere
else (GIL builds, a single CPU) callers run their tasks inline and never touch this module's threads.
"""

import os
import sys
import threading
from collections import deque
from queue import SimpleQueue

MAX_THREADS = 16

_wakeups = SimpleQueue()    # one token (a Batch) per submitted task
_threads = []
_threads_lock = threading.Lock()


def thread_budget():
    """Threads one call may use: 1 on GIL builds, otherwise the size of the CPU affinity mask."""
    if getattr(sys, '_is_gil_enabled', None) is None or sys._is_gil_enabled():
        return 1
    try:
        usable = len(os.sched_getaffinity(0))
    except AttributeError:
        usable = os.cpu_count() or 1
    return max(1, min(usable, MAX_THREADS))


def _worker():
    get = _wakeups.get
    while True:
        get().run_one()


def _ensure_workers(count):
    if len(_threads) >= count:
        return
    with _threads_lock:
        while len(_threads) < count:
            thread = threading.Thread(target=_worker, name='lark-earley-%d' % len(_threads), daemon=True)
            thread.start()
            _threads.append(thread)


class Abort(Exception):
    """Raised in gang members when another member failed."""


_gang_lock = threading.Lock()


class Gang:
    """`size` threads (the caller and `size - 1` pool threads) running one function in lock step.

    Members synchronise with a spinning barrier, so they must all run at once: only one gang runs at
    a time, and gang members never wait on anything else.
    """

    def __init__(self, size):
        self.size = size
        self.flags = [0] * size     # generation (mod 3) each member has reached
        self.abort = False

    def _waiter(self, w):
        flags = self.flags
        size = self.size
        gen = 0

        def wait():
            nonlocal gen
            gen = (gen + 1) % 3
            behind = (gen + 2) % 3     # a member still at the previous generation has not arrived
            flags[w] = gen
            for j in range(size):
                spins = 0
                while flags[j] == behind:
                    if self.abort:
                        raise Abort()
                    spins += 1
                    if spins == 1000:
                        spins = 0
                        os.sched_yield()
        return wait

    def run(self, func):
        """Call `func(w, wait)` on every member `w` (the caller is 0); return the results in order."""
        results = [None] * self.size

        def member(w):
            try:
                results[w] = func(w, self._waiter(w))
            except BaseException:
                self.abort = True
                raise

        if self.size == 1:
            member(0)
            return results
        with _gang_lock:
            batch = Batch(self.size - 1)
            for w in range(1, self.size):
                batch.submit(member, w)
            try:
                member(0)
            finally:
                batch.join()
        return results


class Batch:
    """Tasks of one parse. The submitting thread helps in `join` and re-raises the first task error."""

    def __init__(self, workers):
        self.tasks = deque()
        self.lock = threading.Lock()
        self.pending = 0
        self.idle = threading.Event()
        self.idle.set()
        self.error = None
        _ensure_workers(workers)

    def submit(self, func, *args):
        with self.lock:
            self.pending += 1
            self.idle.clear()
        self.tasks.append((func, args))
        _wakeups.put(self)

    def run_one(self):
        try:
            func, args = self.tasks.popleft()
        except IndexError:
            return False
        try:
            func(*args)
        except BaseException as exc:    # re-raised by join()
            if self.error is None:
                self.error = exc
        finally:
            with self.lock:
                self.pending -= 1
                if not self.pending:
                    self.idle.set()
        return True

    def join(self):
        while self.run_one():
            pass
        self.idle.wait()
        if self.error is not None:
            raise self.error

    def cancel(self):
        """Drop tasks nobody started; running ones finish on their own."""
        self.tasks.clear()
