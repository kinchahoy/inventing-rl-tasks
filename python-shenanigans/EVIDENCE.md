# python-shenanigans: evidence sheet

Generated from job artifacts on 2026-11-03. All model trials predate the current task configuration (the only model trial is a 15-minute pilot run before most changes; the current limits, input sizes and oracles are newer). Data only, no report prose.

Notes on sources:
- Controls use the `*-final2` jobs under `python-shenanigans/jobs/mi60/`. The WRAPUP lists the older `*-v3` / `*-v4` jobs; those were not used.
- The pilot job is `jobs/sympy-state-space-15m-20261103-150339` (in the workspace-root `jobs/`). Its figures match `author/trial-stats.py` output.
- Harbor `check_report.json` files for the 2026-11-03 checks contain no criteria (`DownloadVerifierDirError`). Verdicts below come from each check agent's written result, as narrated in `agent/claude-code.txt`. Harbor job dirs are in the workspace-root `jobs/`.

## 1. Controls

| task | oracle job + reward | nop job + reward | harbor check job + flagged items |
| --- | --- | --- | --- |
| `sympy-state-space` | `sympy-oracle-final2` 1.0 (47/47 correctness cases; performance pass) | `sympy-nop-final2` 0.0 (correctness pass; performance FAIL) | `2026-11-03__18-25-55` FLAGGED: `test_deps_in_image` (pytest, hypothesis in `/opt/devtools`; accepted by author) |
| `lark-earley` | `lark-oracle-final2` 1.0 (29 correctness cases; performance pass) | `lark-nop-final2` 0.0 (correctness pass; performance FAIL) | `2026-11-03__18-28-09` FLAGGED: `test_deps_in_image` (pytest in `/opt/devtools`; accepted by author) |

Oracle metrics (`verifier/checks.json`, `performance.rows[].metrics`). Gate limits (per WRAPUP): serial_regression <= 1.05; step_speedup per core doubling >= 1.10 for `end_to_end` rows and >= 1.05 for constituent operations.

| task | operation | serial_regression | step_speedup 2 | step_speedup 4 | overall 2 | overall 4 |
| --- | --- | --- | --- | --- | --- | --- |
| sympy-state-space | end_to_end:dsolve_8 | 0.891 | 1.281 | 1.365 | 1.438 | 1.957 |
| sympy-state-space | end_to_end:dsolve_10 | 0.914 | 1.318 | 1.369 | 1.448 | 1.963 |
| sympy-state-space | solution_entry_doit | 0.901 | 1.235 | 1.300 | 1.370 | 1.781 |
| lark-earley | end_to_end:parse | 0.458 | 1.183 | 1.133 | 2.585 | 2.975 |

## 2. Model trials

Only one model trial: the 15-minute SymPy pilot (before most current changes). Its verifier correctness passed, performance failed on every row.

| job | task | trial | reward | exception | agent s | llm | tools | peak prompt tok | cost $ | failing gates | config at run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sympy-state-space-15m-20261103-150339 | sympy-state-space | `sh4btsb` | 0.0 | - | 595 | 40 | 39 | 66,422 | 0.025 | performance (serial_regression 1.108 / 1.109 / 1.117 vs 1.05 on dsolve_8, dsolve_10, solution_entry_doit; 2- and 4-core gates false, no speedup) | pre-config pilot |

Failed trial quotes (`step_id` from `agent/trajectory.json`):

- **sympy-state-space `sh4btsb`** (performance fail; agent stopped on its own, no timeout)
  - step 12: "`Dummy._count += 1` is not atomic under free threading, so two threads could mint duplicate dummy indices."
  - step 37: "The free-threaded run fails with `Invalid limits given: ((0,),)`, but the same test passed on the untouched reference package. So my change caused it."
  - step 38: "I'm out of time budget to find which of the three call sites causes it. I'll revert the `systems.py` change and remove the helper module so `linodesolve` is back to the original code."
  - Note: the verifier still measured serial_regression about 1.11 after the revert. The retained `Dummy` lock is the only remaining change, so it is the likely cause, but this sheet does not establish that.

### Current-config headroom (2026-11-03, mi60, one trial at a time, k=3, 60 min)

| Task | Trial | Agent min | Correctness | Performance | Reward |
| --- | --- | --- | --- | --- | --- |
| SymPy | `CMuVNu4` | 38 | 47/47 | single-core limit failed on all 3 rows | 0 |
| SymPy | `FKbSGLy` | 35 | 47/47 | single-core limit failed on `solution_entry_doit` | 0 |
| SymPy | `Qz6iFMK` | 11 | 47/47 | single-core limit failed on all 3 rows | 0 |
| Lark | `8syd6cm` | 5 | 29/29 | serial 1.00, steps 1.00 / 1.00 (no change) | 0 |
| Lark | `ZztjxJL` | 8 | 29/29 | serial 1.01, steps 1.00 / 1.00 (no change) | 0 |
| Lark | `fXVi2NM` | - | - | harness failure: `AgentSetupTimeoutError` (360 s); excluded | - |
| Lark | `9aRoMUM` (replacement) | 7 | 29/29 | single-core limit failed | 0 |

pass@3: SymPy 0/3, Lark 0/3 valid. Jobs: `jobs/mi60/sympy-state-space-haiku-k3`, `jobs/mi60/lark-earley-haiku-k3`,
`jobs/mi60/lark-earley-haiku-k3-replacement`. Every failure is performance only; no trial broke correctness. Lark
agents stopped early (5-8 min of 60).

## 3. Lark and SymPy harbor-check status

- Both flagged items are `test_deps_in_image`, and the author accepted both (per WRAPUP). Earlier checks (`2026-11-03__14-50-30`, `14-52-45` in `python-shenanigans/jobs/`) also returned no criteria.
