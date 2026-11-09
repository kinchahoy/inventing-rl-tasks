# Oracle (reference solution)

**Final status (2026-11-03):** validated on mi60. Oracle 1.0 and nop 0.0 (`jobs/mi60/sympy-oracle-v3`, `sympy-nop-v3`; a final confirmation run `sympy-oracle-final`/`-nop-final` was in progress); margins: single core 0.84-0.90, steps 1.23-1.40. Timed rows: `dsolve_8`, `dsolve_10`, `solution_entry_doit`. The STATUS paragraph, the "Estimated margins (unvalidated)" and "Not validated" sections below predate this and are superseded; the limits are now 1.05 single core and 1.10 / 1.05 per doubling, not the 2.2 gate.

`solve.sh` applies `oracle.patch` (`git apply -p1`, run in `/app/sympy`; idempotent) to the SymPy 1.14.0 package.
The patch is a diff against the untouched package (10 files, one new: `sympy/core/_parallel.py`).

Earlier: written by code reading only. It has been compiled and imported, and `test_StateSpace_dsolve` passed once on
free-threaded and once on GIL CPython 3.15.2 with the pool active (8 CPUs visible). Nothing else is validated: no
timings, no differential comparison, no Harbor run. The margins below are estimates from the profile in `AUTHOR.md`.

## Shared-state races found (the pilot's `Invalid limits given: ((0,),)`)

1. `integrals/manualintegrate.py`: `_integral_cache` is not a memo but an in-progress marker (`cachekey -> None`
   while that integrand is being integrated, used to break cycles). With threads, a second thread integrating a
   structurally equal integrand sees the marker and gets `DontKnowRule`, so `Integral.doit` silently returns an
   unevaluated `Integral`; `replace(t, 0)` on it then fails with the pilot's error. Also racy: `_parts_u_cache` (shared
   counter, cleared per call), the lazy `_special_function_patterns`/`_wilds` initialisation (visible half-built), and
   the `del _integral_cache[key]`. The pilot's `Dummy` lock was necessary but not the cause.
2. `core/symbol.py`: `Dummy._count` read-modify-write (duplicate dummy indices/names, i.e. two "unique" dummies equal).
3. Same lazy-global pattern on fallback integration paths: `heurisch._symbols_cache`, `meijerint._dummies` (check then
   set) and `meijerint._lookup_table` (published empty, filled afterwards).

Checked and fine: `cacheit` (C `lru_cache`), assumptions `_ask` (already written for threads in 1.14), `global_parameters`
and `dotprodsimp` state (thread-local; the pool is used only when the caller has the defaults), `polys.polyconfig`
(read only), polys ring/field caches (`cacheit`).

Fixes: thread-local manualintegrate caches, locks/atomic publish for the lazy tables, lock around the `Dummy` counter
(same names and indices as before when single-threaded). `Dummy.dummy_index` is already randomised per process
(`_base_dummy_index`), so results cannot depend on the Dummy sequence.

## Speed-ups

- `core/_parallel.py`: one module-level `ThreadPoolExecutor` sized to the CPU affinity at first use; `pmap` helper.
  Threads are used only on a free-threaded build, with more than one CPU, from a non-worker thread; otherwise everything
  runs serially in the caller. Pool workers never fan out again (no nested waits).
- `Basic.doit` / `AssocOp.doit` (outermost call only): all distinct outermost `Integral`s of the expression are
  evaluated first (largest first, on the pool when allowed) into a per-call memo; the ordinary serial `doit` walk then
  rebuilds the result with memo hits, so term order and construction are exactly the original's. `Integral.doit` is now a
  thin memo wrapper over the unchanged body (`_doit`). Single-core saving: equal integrals inside one `doit` call are
  evaluated once (about 17 `Integral.doit` per solution entry collapse to about 10 distinct), which is what pays for the
  ~1.11x free-threading overhead. Failures in the prefill are swallowed and recomputed in order by the serial walk, so
  exceptions are the original's.
- `linodesolve` (`solvers/ode/systems.py`): per-entry `expand_mul` + `collect` via `pmap`; `doit=True` goes through
  `doit_all`, which prefills the integrals of all entries in one flat parallel batch (per-entry memos, as if `doit` were
  called on each entry) and rebuilds the entries in parallel.
- `polys/matrices/ddm.py` `DDM.matmul`: one task per row for `EXRAW` matrices with at least 64 multiply-adds
  (the two matrix-vector products in `linodesolve`, about 125 ms of ~1.6 s). Row sums keep their order.

Deliberately not done: a memo shared across entries in `linodesolve` (only 10 distinct integrals across all entries vs
~97 per-entry distinct, ~170 total). It would cut one-core time to roughly half but shrink the parallel fraction so the
4-core scaling gate (T_1/T_4 >= 2.2) would very likely fail; that interplay of the single-core and scaling gates is worth
knowing when calibrating thresholds.

## Estimated margins (unvalidated)

From the GIL profile of `dsolve_10` (1.64 s): serial parts (jordan form 60 ms, post-processing ~60 ms, misc) are about
10%; the rest (`expand_mul` 111, `collect` 246, integrals, products) is parallel. Ideal 4-core scaling about 3x against the
2.2 gate, so overheads and load imbalance (10 entries, ~97 integral tasks) must stay below ~25%. One-core: per-entry dedup
removes roughly 40% of the integral work, expected T_1 well below 1.05x T_original. `solution_entry_doit` has about 10
distinct integrals of uneven cost, so its 4-core scaling is limited by the largest task and the serial rebuild; this is the
most likely gate to miss.

## Not validated; how to validate later

Work from `/home/raist/code/workshop/rl-env-explore/python-shenanigans`. PYTHONPATH must contain a patched copy of sympy
(`git apply -p1 solution/oracle.patch` inside the copy), mpmath 1.3.0 and pytest.

1. Local tests (both builds; `SYMPY_GROUND_TYPES=python PYTHONHASHSEED=0`), repeat the FT run several times:
   `python3.15t -m pytest -q sympy/physics/control/tests/test_lti.py sympy/solvers/ode/tests/test_systems.py sympy/integrals/tests/test_risch.py sympy/integrals/tests/test_manual.py sympy/integrals/tests/test_integrals.py sympy/polys/matrices/tests/test_ddm.py`
   (compare any failures with the untouched package).
2. Differential check: for each case in `tests/workloads.py` (`correctness_cases`, `operation_cases` for 3 variants)
   compare `adapter.encode(adapter.prepare(case)[0]())` between untouched SymPy on GIL and the patched package on both
   builds, with `taskset -c 0`, `0,1`, `0-3`.
3. Timing: for each of the three rows, fresh process per sample, median of 3 inputs, `taskset` to 1/2/4 CPUs, patched FT
   vs untouched GIL (ratios as in `tests/verify.py::assess`).
4. Harbor (from `python-shenanigans`; images rebuild because the Dockerfile gained pytest):
   `harbor run -p series/third-attempt/sympy-state-space -a oracle -n 1 --env-file ../.env -y`, then read `verifier/checks.json`.

Known risks: Float-precision-insensitive equality could merge two integrals that differ only in `Float` precision (not
present in the workloads); the pool is not used if the caller is inside `evaluate(False)`/`dotprodsimp(True)` (serial
fallback); thread stacks use the platform default; contention on shared `lru_cache`s may cost scaling.
