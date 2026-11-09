# Handoff: python-shenanigans (2026-11-03)

Authoritative summary: [WRAPUP.md](WRAPUP.md). Contract: [clarified-vision.md](clarified-vision.md).

## Goal

A hard, fair Harbor task where the agent parallelizes a substantial pure-Python library subsystem for
free-threaded CPython 3.15 (exact behaviour, bounded one-core regression, real multicore scaling), with Haiku 5.5
failing pass@3.

## Current contract

- Active: `series/third-attempt/{lark-earley,sympy-state-space}`, same verifier design in both.
- Agent: 3600 s, 4 CPUs (matches verifier); verifier: separate environment, 4 CPUs, timeout 900 s (placeholder).
  Gateway `[environment.env]` block in every `task.toml` (required by the brief).
- Limits per timed row (median of 3 paired ratios over distinct same-shape inputs, each sample a fresh process on
  distinct physical cores; times minus the original's fixed encode cost): single core `T_1 <= 1.05 * T_original`
  (`maximum_serial_regression`); each doubling of cores (`T_1/T_2`, `T_2/T_4`) >= 1.10 end to end
  (`minimum_step_speedup`) and >= 1.05 for constituent operations (`minimum_step_speedup_constituent`). Every timed
  input takes >= ~100 ms with the original on one GIL core (stated in the prompts). Early exit after the first
  correctness failure or a failed single-core limit.
- Timed rows: SymPy `end_to_end:dsolve_8`, `end_to_end:dsolve_10`, `solution_entry_doit` (constituent); Lark
  `end_to_end:parse` only (70-74 operands). Lark forest rows were dropped (cannot scale in pure Python); correctness
  still covers forest operations. Selection is baked in private `tests/config.json`; evidence in each `AUTHOR.md`.
- Verifier: trusted parent owns generation, references, comparison, clocks; the worker runs as uid 65534 with seccomp.
  Residual risks: series README.

## State

- Oracles exist (`solution/solve.sh`): SymPy `oracle.patch`; Lark patched `lark/parsers/*.py` (pure Python; the ctypes
  trick was removed). On mi60 (user's 20-core Core Ultra 7 265K, P-cores; timing runs under `~/rl-timing`, since local
  load distorts timing): oracle 1.0, nop 0.0 for both (`jobs/mi60/sympy-oracle-v3`, `sympy-nop-v3`, `lark-oracle-v4`,
  `lark-nop-v4`). A SymPy confirmation run (`sympy-oracle-final`/`-nop-final`) was in progress.
- Margins: SymPy single core 0.84-0.90, steps 1.23-1.40; Lark single core 0.46, steps 1.19 / 1.12.
- `harbor check` (2026-11-03 17:31/17:34, jobs under the workspace-root `jobs/`): only `test_deps_in_image` fails
  (pytest/hypothesis are deliberate agent tooling; accepted); a Lark prompt/row mismatch was fixed.
- Agent image has pytest (and hypothesis for SymPy) in `/opt/devtools`.
- Not done: Haiku k=3 headroom trials (user decides), final report.

## Rules

- Never launch model runs unless asked; run harbor controls/builds through Haiku subagents and relay summaries.
- Key lives in the repo-root `.env`; harbor claude-code needs `--env-file`.
- Never modify tests or workloads to fake an outcome; keep verifier inputs and selection out of the agent image.
- Python via `uv`; no commits unless asked (no `Co-authored-by` or tool mentions in commits).

## Known verifier limitation: race detection (accepted 2026-11-03)

Correctness runs every case once per mode (GIL, free-threaded on 1, 2 and 4 cores) and every timed input on
2 and 4 cores, exactly compared with the original. This catches frequent races (e.g. the `manualintegrate`
in-progress-marker race a pilot hit), not rare ones, and never calls the library from several user threads at once.
Possible hardening: shuffled repeats of the 4-core pass; a concurrent-caller test (needs a prompt requirement).
