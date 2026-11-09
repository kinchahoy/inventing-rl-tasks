# Oracle for `lark-earley` (v4)

**Final status (2026-11-03):** validated on mi60. Oracle 1.0 and nop 0.0 (`jobs/mi60/lark-oracle-v4`, `lark-nop-v4`); margins: single core 0.46, steps 1.19 / 1.12. Only `end_to_end:parse` is timed; the forest rows below were dropped because they cannot scale in pure Python (best 0.93 / 0.98), and the ctypes deferred-refcount trick mentioned below was removed. Earlier: v3 scored 0 (forest row, smaller parse).

`solve.sh` copies the five files in `solution/lark/parsers/` over `/app/lark/parsers/`. The copy is idempotent, and the
rest of the package is untouched Lark 1.3.1. The oracle is pure Python and standard library only.

Correctness: a differential check against pristine 1.3.1 (`correctness_cases` plus every `operation_cases` input, seeds
1234/7/99, 63 cases) gives identical worker responses on GIL and on free-threaded with 1/2/4 CPUs.

## Chart construction (`xearley.py`, `earley_common.py`)

Dynamic-lexer Earley fast path. It applies only when `ordered_sets=True`, the parser is the exact class, and the grammar
has no empty rules; anything else runs the original code.

- `_column` replaces `predict_and_complete`. It produces the same items in the same order with the same SPPF. The
  differences: an originator index per column, each completion and prediction handled once per column, static LR0
  position records, and no construction of duplicate items.
- `PackedNode` creation is taken out of the completer and done per column (`_add_families`). On free-threaded builds with
  more than one CPU, groups of at least 600 families go to a small daemon pool (`_parallel.Batch`) while the caller keeps
  building the chart. Columns never share target nodes, so `_children` order equals the sequential order.
- The scan matches each terminal once per column.
- **New in v3:** the cyclic GC is paused (`gc.disable`, restored afterwards) during chart construction. The chart only
  allocates, and on free-threaded builds every collection is a stop-the-world scan of the whole heap. Before this,
  collections took about 18 of 68 ms on one core, and they serialised the pool.

## Forest (`earley_forest.py`)

- **New in v3:** `ForestSumVisitor.visit` (exact class, root is a `SymbolNode`) uses `_sum_by_span`. A child's span lies
  inside its parent's, so priorities are computed level by span length:
  1. Walk the forest top down by decreasing length.
  2. Assign priorities bottom up. Nodes that share a span (unary chains) are ordered children-first. A cycle, a
     childless node or a malformed forest makes the function return False before any priority is written, and the
     generic walk then runs.

  On free-threaded builds with more than one CPU, and a root span of at least 64 characters, a gang of
  `len(sched_getaffinity)` threads (`_parallel.Gang`: the caller plus pool threads) runs both phases. Each node is owned
  by a thread, chosen by a Fibonacci hash of its start, so nodes with the same span have the same owner. Nodes are
  posted to their owner, and the threads meet at a spinning barrier after each length. Only one gang runs at a time, and
  GC is paused during the walk. Even on one core the two-pass version is about 3x faster than v2's iterative walk.
- The shared initial priority `NEG_INF` comes from an unmarshalled code constant. On free-threaded CPython 3.15 such
  constants are immortal (an implementation detail; elsewhere it is an ordinary float). Every priority store in the
  parallel walk drops a reference to the old value. With one ordinary shared float, all threads contend on its
  reference count. With one float per node, every store frees an object across threads. Both were measured and both
  were slower.
- Kept from v2: `SymbolNode.children` skips the sort for one child, and `PackedNode.sort_key` and `.children` are
  cheaper.

## What limits scaling (measured on mi60, cores 0-3 = P-cores, CPython 3.15.2t)

- Stop-the-world GC: fixed by pausing collection in both phases.
- Atomic reference counting on objects that every thread touches. On free-threaded builds an object is increfed
  atomically by every thread except the one that created it. Hot objects are:
  - the shared `-inf`: fixed with the immortal constant;
  - the type objects loaded through `__class__`: replaced by `isinstance`;
  - duplicate posts of child nodes: deduplicated per thread;
  - the 2-3 `Rule`/`RuleOptions` objects, loaded once per packed node: **not fixable in pure Python.** With
    `PyUnstable_Object_EnableDeferredRefcount` (through ctypes, which is not allowed and has been removed), the forest
    walk took 25.9 ms on 1 thread, 20.7 ms on 2 and 14.7 ms on 4. Without it, 25.2 / 23.5 / 21.6 ms.
  - Child nodes are shared by many parents across threads: inherent to an SPPF.
- Ownership leak into the timed snapshot. In the `forest_to_parse_tree` row the forest is built by a parse in
  `prepare` that uses the pool, so most packed nodes are owned by pool threads. The serial `_forest_snapshot` inside
  the clock then pays atomic refcounts: about +3 ms on 2 CPUs and +5 ms on 4. Because the row's effective time is only
  about 29 ms, this alone cancels most of the gain.

## Measured (mi60 micro-benchmark, fresh processes, effective times as the verifier computes them)

| Row | T1 / T_orig | T1/T2 | T2/T4 |
| --- | --- | --- | --- |
| `end_to_end:parse` | 0.49 | 1.20 | 1.12 |
| `forest_to_parse_tree` | 0.16 | 0.94-0.95 | 0.96 |

Turning the gang off for the forest walk is worse (T2 33.8 ms instead of 30.2 ms), because the gang offsets part of
the snapshot penalty.

Harbor `lark-oracle-v3` on mi60 (`python-shenanigans/jobs/mi60/`) scored reward 0, with correctness passed. The
harbor seed gives a smaller parse (T_orig 85 ms):

| Row | T1 / T_orig | T1/T2 | T2/T4 |
| --- | --- | --- | --- |
| `end_to_end:parse` | 0.47 | 1.15 | 1.05 (fails) |
| `forest_to_parse_tree` | 0.18 | 0.93 | 0.98 (fails) |

On this smaller input the parse's serial skeleton (chart items, scan, final transform), about 25 ms, dominates.
