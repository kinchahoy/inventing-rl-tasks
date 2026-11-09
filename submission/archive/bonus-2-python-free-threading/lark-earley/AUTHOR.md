# Author notes

## Baked operation selection (author-side only)

Selection was made once by the authors and is baked into `tests/config.json` ("operations") with generators in
`tests/workloads.py::operation_cases`; the verifier does no runtime profiling. The instruction only says the
assessed operations are chosen by the authors and not disclosed.

| Row | Public callable | Fixture | 1-core GIL time (fresh process, CPython 3.15.2) |
| --- | --- | --- | --- |
| `end_to_end:parse` | `Lark.parse` | ambiguous `expr "+" expr` grammar, 70-74 operands, `ambiguity="resolve"` | ~115-140 ms |

Earlier: `forest_to_parse_tree` was also timed; dropped (see below).

Why: on the original workloads, `Lark.parse` is 100% by construction; `predict_and_complete`/`scan` (the Earley chart
build, ~86% of a parse at 60 operands) is not an independently callable public operation, so `Lark.parse` is its only
public handle. The forest transform/visit step is the only other public, independently callable part (about 7% of a
parse at 60 operands, 27% at 24 operands, via `ForestToParseTree.transform` -> `ForestVisitor.visit`; the two are nested,
visit is ~100% of transform). Standalone `use_cache=False` transforms cost more than the whole parse because the parse path
caches. The previous sizes (22-28 operands, 48-60-token nullable text) cost only 6-30 ms and 2-7 ms per call, so the
sizes were raised to give >= ~50 ms per call and the trivial nullable end-to-end case was dropped (it remains in the
correctness set). Remaining limits: all three rows share one grammar/forest shape; chart-building parallelism has no
constituent handle.

Forest snapshots are taken only after the timed invocation, because accessing
`children` can materialize lazy paths. Initial node priorities can be infinite;
they are encoded as hexadecimal float strings rather than invalid JSON numbers.
Static review is not runtime validation. Corpus breadth, profile attribution,
grammar compatibility, and total verifier cost remain to be checked.

## Structure

Case generators and the baked operations live in `tests/workloads.py` (parent only). Object construction, snapshots, and encoding live in `tests/adapter.py`, which workers can read; it contains no pools or checks. Result invariants (`check_result`) were removed in favour of full differential comparison.

Generators take a `variant` argument: sizes and structure are fixed by the seed, only values differ, giving the three timed inputs per operation.

Dropped 2026-11-03: `forest_sum_visit` and `forest_to_parse_tree` (see Oracle); forest operations stay in the correctness set.

## Oracle (v4, validated on mi60: oracle 1.0, nop 0.0)

`solution/` (`solve.sh` overlays patched `lark/parsers/*.py`; pure Python) gives output identical to 1.3.1 (differential
check, GIL and FT, 1/2/4 CPUs). Harbor jobs `lark-oracle-v4` (1.0) and `lark-nop-v4` (0.0); margins: single core 0.46,
steps 1.19 / 1.12. The forest transform cannot scale in pure Python (best 0.93 / 0.98): atomic refcount contention on the
shared `Rule`/`RuleOptions` objects (a ctypes deferred-refcount trick helped but is not allowed and was removed). See
`solution/README.md`.

## Timing: encode-cost subtraction (2026-11-03)

The clock still covers GO to the complete result line (snapshot, `encode`, JSON included, so lazy results cannot hide work).
The worker also prints an untimed `SPLIT <call> <encode>` line (seconds in the call vs. snapshot+encode+serialise). The parent
trusts it only from reference workers: E_gil comes from the reference GIL run that already yields T_original, E_ft from an
added reference run on free-threaded with one core (per timed input). Effective times: T_original_eff = T_original - E_gil,
T_N_eff = T_N - E_ft for every N including 1; all formulas then use effective times. The submission's own split is ignored.
A row input with effective time <= 0 or E > 80% of T yields a verifier error (checks.json `performance.verifier_errors`,
top-level `failure`). `checks.json` records raw totals, E_gil, E_ft, reference ft_1 totals and effective times.
Cost: +1 reference process start per timed input (one per row x repetition, i.e. +3 per row).

Changed 2026-11-03: timed parse inputs enlarged to 70-74 operands (original parse ~115-140 ms on one GIL core) so fixed
setup is a smaller share; `forest_to_parse_tree` dropped: within the task's pure-Python rules it cannot scale (shared
`Rule` refcount contention; best oracle 0.93/0.98 per doubling). Only `end_to_end:parse` is timed.

## Correctness coverage (2026-11-03)

Correctness set is now 26 cases (12 original + 14 added in `workloads._extra_correctness_cases`): nested lists and parentheses,
`keep_all_tokens`, `maybe_placeholders`, terminal priorities, rule priorities, templates, regex flags, `dynamic` /
`dynamic_complete` / `basic` lexers, `ambiguity="explicit"`, and `UnexpectedCharacters` / `UnexpectedToken` errors. `case["options"]`
is forwarded to `Lark(...)` by the adapter. `forest_sum_visit` removed (dead). The prompt now says the hidden cases sample the API.
Local differential check (original vs oracle, GIL and FT, 1 and 4 CPUs, 3 seeds, `PYTHONHASHSEED=0`): identical.
