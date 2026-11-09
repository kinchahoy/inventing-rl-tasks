# Private author notes

Keep this file and `tests/workloads.py` out of the agent image. The public instructions deliberately name the `StateSpace.dsolve` surface without naming measured methods, fixture families, or matrix structures.

## Baked operation selection (author-side only)

Selection was made once by the authors and is baked into `tests/config.json` ("operations") with generators in
`tests/workloads.py::operation_cases`; the verifier does no runtime profiling. The instruction only says the assessed
operations are chosen by the authors and not disclosed.

| Row | Public callable | Fixture | 1-core GIL time (fresh process, CPython 3.15.2) |
| --- | --- | --- | --- |
| `end_to_end:dsolve_8` | `StateSpace.dsolve` | order 8, 2 in / 2 out | 1.2 s |
| `end_to_end:dsolve_10` | `StateSpace.dsolve` | order 10 | 1.4-1.7 s |
| `solution_entry_doit` | `Basic.doit` (`AssocOp.doit`) | entry 3 of `linodesolve(..., doit=False)` for an order-10 system (a sum of ~17 unevaluated `Integral`s of exponential-polynomial terms) | 0.14-0.17 s |

Fixtures for the last two are built untimed in `adapter._linode_fixture`; arbitrary-constant `Dummy` symbols are replaced by
stable symbols so `srepr` comparison is process-independent.

Profile evidence (original SymPy 1.14.0, CPython 3.15.2 GIL, `PYTHONHASHSEED=0`, ground types python, caches cleared, 3 seeds x
3 variants): per-dsolve wall 0.76-1.17 s (order 8), 1.4-2.1 s (order 10). Time sits in `linodesolve` (96%), of which
`Basic.doit` on the solution entries is 63-74% (8-10 top-level calls of 57-145 ms each), i.e. ~1400-4300 `Integral.doit`/
`risch_integrate` calls of ~1.7 ms real each; `collect` 9-15% (8-10 calls of 13-18 ms), `Matrix.__mul__` 7-8% (7 calls, the two
matrix-vector products 55-66 ms), `expand_mul` 4-7%, `jordan_form` 2.5-3%, `matrix_exp_jordan_form` 3%. The old
matrix/DomainMatrix pool never reached 5% because those operations are 3% or less; the cost is the symbolic
integration of many small terms (flat profile: the top function by self time is 3.8%, top 100 functions 69%; self time 43% `core`,
31% `polys`, 15% builtins). Rejected: `Integral.doit`/`risch_integrate` (~2-7 ms per call, too fine-grained),
`collect` (13-18 ms), `jordan_form` (22-49 ms, 2.5-3%).

## Workload intent and limits

End-to-end fixtures use dense similarity transforms of small Jordan forms, with exact rational spectra and nonzero state/input/output data. Sizes are deliberately modest because `StateSpace.dsolve` includes symbolic Jordan, integration, and solving work; independent selected matrix operations can use their own fixtures. Correctness fixtures include defaults, defective/repeated eigenvalues, a symbolic parameter, wrong variable/initial/input shapes, and constructor shape failure. These choices exercise a range of behavior but do not define the public API contract or hidden verifier distribution.

Limits are calibrated against the oracle on mi60 (see Oracle); every timed input takes >= ~100 ms with the original on one GIL core.

## Structure

Case generators and the baked operations live in `tests/workloads.py` (parent only). Object construction, snapshots, and encoding live in `tests/adapter.py`, which workers can read; it contains no pools or checks. Result invariants (`check_result`) were removed in favour of full differential comparison.

Generators take a `variant` argument: sizes and structure are fixed by the seed, only values differ, giving the three timed inputs per operation.

Dropped 2026-11-03: `jordan_chain_product`, small (~3% of dsolve, under the 50 ms aim) and trivially parallel per entry.

## Oracle

`solution/` holds a reference solution (`solve.sh` applies `oracle.patch` to `/app/sympy`; see `solution/README.md`).
Validated on mi60: oracle 1.0, nop 0.0 (`jobs/mi60/sympy-oracle-v3`, `sympy-nop-v3`; a final confirmation run `sympy-oracle-final`/`-nop-final` was in progress); margins: single core 0.84-0.90, steps 1.23-1.40.
Root cause of the pilot's `Invalid limits given: ((0,),)`: `manualintegrate._integral_cache` is a shared in-progress
marker, so concurrent integrations of equal integrands return unevaluated `Integral`s.

## Timing: encode-cost subtraction (2026-11-03)

The clock still covers GO to the complete result line (snapshot, `encode`, JSON included, so lazy results cannot hide work).
The worker also prints an untimed `SPLIT <call> <encode>` line (seconds in the call vs. snapshot+encode+serialise). The parent
trusts it only from reference workers: E_gil comes from the reference GIL run that already yields T_original, E_ft from an
added reference run on free-threaded with one core (per timed input). Effective times: T_original_eff = T_original - E_gil,
T_N_eff = T_N - E_ft for every N including 1; all formulas then use effective times. The submission's own split is ignored.
A row input with effective time <= 0 or E > 80% of T yields a verifier error (checks.json `performance.verifier_errors`,
top-level `failure`). `checks.json` records raw totals, E_gil, E_ft, reference ft_1 totals and effective times.
Cost: +1 reference process start per timed input (one per row x repetition, i.e. +3 per row).

## Correctness coverage (2026-11-03)

Correctness set is now 38 cases (17 original + 21 added in `workloads._extra_correctness_cases`): `dsolve` on orders 2-5
(integer, singular, non-square, input-only/initial-only/neither, other time symbols) and `StateSpace` methods via the adapter's
`statespace_method` kind (controllability/observability matrices and subspaces, `is_*`, `state_matrix`, `shape`, `neg`/`add`/`sub`/`mul`,
`evalf`, one `ShapeError`). The prompt now says the hidden cases sample the API.
Local differential check (original vs oracle, GIL and FT, 1 and 4 CPUs, 3 seeds, `PYTHONHASHSEED=0`): identical.
