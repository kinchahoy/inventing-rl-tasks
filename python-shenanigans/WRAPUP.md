# Wrap-up: python-shenanigans (2026-11-03)

Attack: make a real pure-Python library faster *within one call* on free-threaded CPython 3.15, as a drop-in
replacement (exact behaviour, still correct on the GIL build). Two active tasks in `series/third-attempt/`.

## What's here

| Task | Timed rows | Oracle | nop | Jobs (`jobs/mi60/`) |
| --- | --- | --- | --- | --- |
| `sympy-state-space` | `StateSpace.dsolve` order 8 and 10; `Basic.doit` on one solution entry | 1.0 | 0.0 | `sympy-oracle-final2`, `sympy-nop-final2` |
| `lark-earley` | `Lark.parse` (70-74-operand inputs) | 1.0 | 0.0 | `lark-oracle-final2`, `lark-nop-final2` |

Limits (per row, median of 3 paired ratios on distinct same-shape inputs, each sample a fresh process pinned to
distinct physical cores; times minus the original's fixed result-encoding cost):

- single core: free-threaded `T_1 <= 1.05 x` the original on GIL;
- each doubling of cores at least 1.10x faster end to end, 1.05x for constituent operations;
- every timed input takes at least ~100 ms with the original (stated to the agent).

Oracle margins on mi60 (Intel Core Ultra 7 265K, P-cores): SymPy single core 0.84-0.90, steps 1.23-1.40;
Lark single core 0.46, steps 1.19 / 1.12.

Verifier: cases generated and compared in the trusted parent; submission worker runs as an unprivileged uid with
seccomp and sees only its inputs; correctness on GIL and free-threaded 1/2/4 cores, exact; early exit once the reward
is certainly 0. Agent and verifier both get 4 CPUs; the agent image has `pytest` (+ `hypothesis` for SymPy).

Evidence for the report (controls, old model trials, failure quotes): [EVIDENCE.md](EVIDENCE.md).

## What's not done

- **Haiku 5.5 headroom (k=3, 60 min, mi60, one trial at a time, 2026-11-03; jobs `jobs/mi60/*-haiku-k3`):**
  SymPy 0/3: all correct (47/47 cases) but failed the single-core limit (2 trials on all three rows, 1 only on
  `solution_entry_doit`); agent time 11, 35 and 38 min. Lark 0/2 valid: both correct (29/29) but no speedup at all
  (single core 1.00/1.01, steps ~1.00); agents stopped after 5 and 8 min. The third Lark trial was a harness
  failure (`AgentSetupTimeoutError`, 360 s) and does not count; its replacement
  (`lark-earley-haiku-k3-replacement`) was also correct (29/29) but failed the single-core limit after 7 min of agent
  time. **Lark 0/3 valid.**
  Earlier: one 15-minute SymPy pilot scored 0 after finding the right hotspot and hitting a real free-threading race.
- Limits are calibrated from one oracle per task on one machine; headroom numbers are hardware-dependent.
- SymPy's broader upstream test files timed out locally (inconclusive, same on the GIL build); correctness rests on
  the verifier's exact comparison and the targeted `test_StateSpace_dsolve`.
- Verifier cost is a few minutes per run (fresh process per sample); its 900 s timeout is a placeholder.

## Fair

- Real libraries (SymPy 1.14.0, Lark 1.3.1) with a strict, explicit contract: exact outputs, exceptions, effects.
- Everything graded is stated: limits, core counts, timing method, minimum input size, banned techniques.
- The agent can reproduce the grading conditions (4 CPUs, both runtimes, the original in `/opt/reference`, pytest).
- Oracles obey the same rules as the agent (pure Python, standard library; a `ctypes` refcount trick was removed).
- The no-op control fails only on performance, so failures measure engineering, not harness breakage.

## Unfair or weak spots

- Which constituent operations are timed is hidden (the selection rule and minimum size are stated).
- Rare races can pass: each case runs once per mode, and the library is never called from several user threads.
- Timing noise: margins are 5-30% above the limits, Lark's 2->4 step only 1.12 vs 1.10.
- The single-core limit forces a real serial optimisation before parallelism counts (intended, but demanding).
- Lark's oracle relies on CPython 3.15t details (immortal code constants, GC pauses); Earley parsing is largely
  sequential, so its headroom is partly "hard to find any parallelism". Its forest-transform row was dropped as
  infeasible within the rules (`lark-earley/AUTHOR.md`).
- SymPy's scaling comes mostly from fanning independent integrals out; difficulty is mainly correctness under free
  threading (the `manualintegrate` in-progress marker and other shared state) plus the single-core limit.

## Known issues found in trajectory review (recorded, not fixed)

From [TRAJECTORY-NOTES.md](TRAJECTORY-NOTES.md), on the headroom runs above:

- **Stale Lark scope sentence.** `lark-earley/instruction.md` line 3 still says "The scope includes substantial
  public forest visitor and transformation operations", although the forest row was dropped and only `Lark.parse`
  is timed. It points agents at a path the oracle's author found cannot scale. All Lark trials ran with it.
- **No ratios recorded on early exit.** When the single-core limit fails, SymPy's `checks.json` stores only the
  failing rows, not the measured ratios, so near-misses (e.g. `FKbSGLy`, failing only `solution_entry_doit`) cannot
  be quantified from the record.
- **Racy code can pass correctness.** `CMuVNu4` hit the real free-threading race (`Invalid limits given`) and still
  passed 47/47 hidden cases (already listed under weak spots: each case runs once per mode).
- **Benchmark/grader mismatch.** Lark agents timed 0.4-3 s inputs inside one process; the grader times ~120 ms
  inputs in fresh processes, which the prompt states. Their index-only fix measured 0.996 and 1.0115 on one core.

## Accepted `harbor check` findings (2026-11-03)

- **`test_deps_in_image` (both tasks): accepted, deliberately.** The agent image installs `pytest` (SymPy also
  `hypothesis`, required by SymPy's own `conftest.py`) into `/opt/devtools` so the agent can run the library's test
  suite while it works; a pilot agent without it wasted time writing its own test runner. The verifier does not use
  them and its worker cannot import them (its `PYTHONPATH` is only the staged submission). The rubric item targets
  verifier test dependencies leaking into the agent image, which is not the case here, so it stays red by design.
- **Lark `behavior_in_tests`: fixed.** The prompt no longer mentions timed constituent operations (only `Lark.parse`
  is timed); the "complete public API" wording was softened to describe the hidden-case check, and correctness cases
  were added in both tasks.
- **Explanatory comments (2026-11-03 18:25):** both Dockerfiles now explain the `/opt/devtools` tooling next to the
  install. A re-check still flags `test_deps_in_image` on both tasks (jobs `2026-11-03__18-25-55`, `18-28-09`); the
  reviewer reads the comment and applies the criterion literally. Left as is: removing the tools would hurt the agent.

## Headroom runs (not yet run; only when the user says go)

Timing-sensitive: run on mi60, one task at a time, with nothing else on that machine:

```sh
tools/mi60-headroom                     # both tasks; or: tools/mi60-headroom sympy-state-space
uv run tools/trial-stats.py python-shenanigans/jobs/mi60/sympy-state-space-haiku-k3
```

The script copies the gateway `.env` to mi60 as a 0600 file for the duration and deletes it afterwards (user to
approve). Model name follows the brief's form (`claude-haiku-5-5`).
