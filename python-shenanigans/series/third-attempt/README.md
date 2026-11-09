# Third attempt: library migrations

Two draft Harbor problems:

- `sympy-state-space`: symbolic state-space analysis and its shared matrix/solver machinery.
- `lark-earley`: Earley parsing and shared-forest transformation.

Status (2026-11-03): each task has a validated oracle (`solution/`; reward 1.0) and a nop control (reward 0.0) on mi60; see `../../WRAPUP.md` and `../../handoff.md`. No model trials have been run.

## Provisional requirements

For every retained performance case, with N available cores:

- Single core: free-threaded `T_1 <= 1.05 *` the original one-core GIL-enabled time (`maximum_serial_regression`).
- Each doubling of cores (`T_1/T_2`, `T_2/T_4`): at least 1.10× end to end, 1.05× for constituent operations (`minimum_step_speedup`, `minimum_step_speedup_constituent`).
- Every timed input takes at least ~100 ms with the original on one GIL core (stated in the prompts).

The private configuration offers allocations of one, two, and four cores (stated in the instruction). The agent environment has 4 CPUs, matching the verifier. Limits are calibrated against one oracle per task on mi60 (margins in `WRAPUP.md`). Each case is assessed independently. Three samples are retained, each on a different input of the same kind (same sizes and structure class, different values) and each in a fresh worker process, so first-call effects are included and in-process memoisation cannot serve later samples. The original is measured on the same three inputs and ratios are paired per input; the median of the paired ratios is assessed. Import, process startup, and object construction are outside the clock. Algorithm-required preparation, conversion, and result assembly must not be moved into excluded setup to evade timing.

Timed operations are baked into the private `tests/config.json` ("operations"): the end-to-end anchor plus 1-3 independently callable public constituent operations per task, chosen once by the authors from baseline profiles (SymPy: two `dsolve` sizes plus `Basic.doit` on a solution entry; Lark: `Lark.parse` only) of the untouched library (author-side evidence in each `AUTHOR.md`). The verifier does no profiling at run time. The instruction states only that the operations are author-chosen and undisclosed; the agent receives neither the list, the pool, nor the inputs.

Correctness uses original-library comparisons, input/effect snapshots, invalid-input exceptions, and inexpensive invariants on both runtimes. Verifier runtime is a few minutes (fresh process per sample). Startup and per-call timeouts are containment limits, not evidence of a fast verifier.

## Packaging and boundaries

Each task is standalone. Only `environment/` is the Docker build context. Only library source and an input-free runtime check enter the agent image. `tests/`, this README, task author notes, workload parameters, and source-screen artifacts are private. Harbor's separate verifier receives the submitted library artifact in a fresh environment.

## Verifier structure and isolation

`tests/verify.py` (trusted parent, root) owns case generation (`workloads.py`, including the baked operations), reference answers, comparison, clocks, and the verdict. `tests/worker.py` is a generic serial RPC loop: it receives one serialised job (grammar/source text, matrices as strings, parameters), builds it through `tests/adapter.py` (object construction, snapshots, result encoding; no pools, seeds, thresholds, or checks), runs the single call, and returns the encoded result, exception, and before/after snapshots. The parent's clock runs from `GO` until the complete result line (including `encode` and the after-snapshot) is received, so deferred or post-`DONE` work counts. The worker additionally reports a `SPLIT` line (seconds in the call vs. snapshot+encode+serialise), trusted only from reference workers. The worker then reports its OS thread count (waiting up to 2 s for it to return to the pre-call baseline); excess threads are logged in `checks.json` diagnostics only, with no pass/fail effect (persistent thread pools are legitimate, and with a fresh process per sample they cannot help timing). The fixed encoding cost of a correct result cannot be sped up by a submission, so it is subtracted using a trusted estimate from the reference: E_gil (reference GIL run, giving T_original) and E_ft (an added reference free-threaded one-core run per timed input). Assessment uses T_original_eff = T_original - E_gil and T_N_eff = T_N - E_ft for every N (including 1); the formulas are otherwise unchanged. An input with an effective time <= 0 or E > 80% of T is a verifier error. A submission that defers work into encoding still pays for it, because the clock covers it and the subtracted amount is the reference's. The parent compares results to the reference worker's output for the same job; every timed input has its own reference answer. The old in-worker `check_result` invariants were dropped; full differential comparison subsumes them. Only `worker.py`, `sandbox.py`, and `adapter.py` are copied where a worker can read them.

Enforced for the submission worker (uid 65534): runs as an unprivileged user; `/tests` is mode 700 and `/opt/reference` is made `root:65533 0750` by the parent (the reference worker runs as uid 65533), so neither is readable; the allowed `mpmath` is staged separately from `/opt/reference`; files the worker leaves in `/tmp`, `/var/tmp`, `/dev/shm` are deleted after each worker so nothing persists across modes; seccomp blocks fork/exec, sockets, ptrace, `process_vm_*`, affinity changes, and non-thread `clone`. Sources with symlinks or native binaries are rejected. Worker or protocol failures of the submission are reported as correctness failures, not verifier errors.

Residual risk (not closed): everything runs in-process with the submission, so it can monkeypatch `adapter`/`worker`, and import a vendored copy of the original code. Closed: early/forged completion, lazy work during `encode` (inside the parent clock); memoisation across samples (fresh process per sample, scratch directories scrubbed). Still open: a submission can keep disk state outside the scrubbed locations, or memoise within one call. Threads outliving the result cannot shorten the measured interval or help later samples (fresh process each). It cannot read the private generators or reference answers, but forged timing or deferred computation needs manual code review of submissions. `restrict()` has no filesystem confinement (no Landlock/mount namespace); file privacy relies on uid and mode only. The current job's inputs are visible to it by necessity.

The images use uv 0.13.7 and matched CPython 3.15.2 builds. SymPy's only allowed third-party runtime dependency is its supplied mpmath 1.3.0; Lark has no third-party runtime dependencies. Adding, installing, vendoring, bundling, upgrading, or requiring other packages is forbidden. Original package code, new implementation helper modules, and ordinary standard-library facilities are allowed. Clean images help enforce installation requirements but cannot prove the absence of vendored packages or native offloading; review submitted code too. No runtime is compiled from source. No custom concurrency context manager is required; existing calls should adapt to CPU availability.

## Deferred (by decision)

- Verifier timeout is provisionally 900 s (cost is a few minutes, not tuned); fresh processes make it roughly (rows x (3 reference GIL + 3 reference free-threaded + 1 GIL + 9 free-threaded)) process starts, each with seccomp setup and library import (SymPy import is the heavy case, a few seconds), so expect a few minutes of startup overhead beyond call time.
- Coverage limits of the baked lists: Lark's Earley chart construction has no independent public handle (only `Lark.parse`); SymPy's cost is symbolic integration inside `doit`. See each `AUTHOR.md`.

## Remaining work

Haiku k=3 headroom trials (user decides), final report, and a re-run of `harbor check` after the last changes. Controls:
`harbor run -p python-shenanigans/series/third-attempt/<task> -a nop|oracle -n 1 --env-file .env`; healthy nop has
`correctness.passed: true`, `performance.passed: false`, reward 0. `harbor check` flags only `test_deps_in_image`
(pytest/hypothesis are deliberate agent tooling; accepted).

## Known verifier limitation: race detection (accepted 2026-11-03)

Correctness runs every case once per mode (GIL, free-threaded on 1, 2 and 4 cores) and every timed input on
2 and 4 cores, exactly compared with the original. This catches races that fire often (e.g. the
`manualintegrate` in-progress-marker race a pilot hit). It does not catch rare races (one result in hundreds),
and it never calls the library from several user threads at once, which the original is not safe for either.
Possible later hardening: repeat the 4-core correctness pass in shuffled order; a concurrent-caller test
(would need an explicit requirement in the prompt).

## Early exit (2026-11-03)

Once the reward is certainly 0 the verifier stops measuring: after the first correctness failure, or when the single-core
limit already fails after the 1-core run (then the 2- and 4-core modes are skipped). `checks.json` records why in
`performance.skipped`. Rewards are unchanged.
