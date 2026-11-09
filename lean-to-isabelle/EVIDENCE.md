# lean-to-isabelle: evidence sheet

Generated from job artifacts on 2026-11-03. All model trials predate the current task configuration (metis/meson now allowed; Cauchy cap now 750, was 600; Shor-exact retired; the `withmetis` variant is a pre-current task). Data only, no report prose.

Notes on sources:
- Every model trial, including the `sonnet-*` task names, has `config.json` model `anthropic/claude-haiku-5-5`.
- Lean figures were read directly from the job files; the shared `tools/trial-stats.py` now handles Lean's dict-shaped `checks.json` too (the older copy in faking-it-with-nix/author crashed on it). Totals: 25 trials, 18 passed, 7 failed (most passes are on since-archived tasks).
- Harbor `check_report.json` files for all 2026-11-03 checks contain no criteria (`DownloadVerifierDirError`). Verdicts below are taken from each check agent's written result (`check-result.json` content and final message in `agent/claude-code.txt`).
- The WRAPUP does not name the Cauchy harbor check job. Used `2026-11-03__17-26-23`, the latest Cauchy check.

## 1. Controls

| task | oracle job + reward | nop job + reward | harbor check job + flagged items |
| --- | --- | --- | --- |
| `haiku-hard-cauchy` | `lean-oracle-final` 1.0 (495 lines) | `lean-nop-final` 0.0 (10 lines; fails no_forbidden_tokens, structured_isar_proof, isabelle_build_and_check) | `2026-11-03__17-26-23` clean (10 pass, structured_data_schema n/a) |
| `sonnet-hard-candidate-shor-general` | `lean-oracle-final` 1.0 (602 lines) | `lean-nop-final` 0.0 (24 lines; same 3 gates fail) | `2026-11-03__18-30-46` FLAGGED: `anti_cheating_measures` (full 540-line Lean proof shipped), `hardcoded_solution` (oracle is one heredoc) |
| `sonnet-hard-candidate-shor-general-paper` | `lean-paper-oracle` 1.0 (602 lines) | `lean-paper-nop` 0.0 (24 lines; same 3 gates fail) | `2026-11-03__18-10-56` clean (11/11 per WRAPUP; no items flagged in agent output) |

## 2. Model trials

Columns: agent_seconds, llm_calls, tool_calls, peak_prompt_tokens, cost_usd as recorded in `result.json` / `trajectory.json`. Exception `AgentTimeoutError` = 1800 s budget reached. Gates listed are the failing `checks.json` entries.

| job | task | trial | reward | exception | agent s | llm | tools | peak prompt tok | cost $ | failing gates | config at run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| haiku-k3 | easy-candidate-no-cloning | `4qJaD3i` | 1.0 | - | 92 | 6 | 9 | 36,719 | 0.012 | - | pre-config |
| haiku-k3 | easy-candidate-no-cloning | `T3KLxe6` | 1.0 | - | 89 | 7 | 7 | 35,992 | 0.012 | - | pre-config |
| haiku-k3 | easy-candidate-no-cloning | `VfGsN5d` | 1.0 | - | 93 | 8 | 7 | 36,683 | 0.012 | - | pre-config |
| haiku-k3 | easy-cayley-v2 | `iemPCcD` | 1.0 | - | 125 | 6 | 6 | 49,108 | 0.019 | - | pre-config |
| haiku-k3 | easy-cayley-v2 | `q6i8jMv` | 1.0 | - | 164 | 6 | 8 | 53,005 | 0.024 | - | pre-config |
| haiku-k3 | easy-cayley-v2 | `vxfEoUd` | 1.0 | - | 167 | 8 | 7 | 55,027 | 0.027 | - | pre-config |
| haiku-k3 | haiku-hard-candidate-cauchy-openbook | `BYX3s5W` | 1.0 | - | 1689 | 60 | 65 | 367,993 | 1.516 | - | pre-config, cap 600 |
| haiku-k3 | haiku-hard-candidate-cauchy-openbook | `PEL8rJY` | 0.0 | AgentTimeoutError | 1800 | 40 | 49 | 239,124 | 0.820 | no_forbidden_tokens (`axioms`), within_line_limit (647 > 600), isabelle_build_and_check | pre-config, cap 600 |
| haiku-k3 | haiku-hard-candidate-cauchy-openbook | `nYDiWc4` | 0.0 | AgentTimeoutError | 1800 | 35 | 62 | 157,364 | 0.371 | statement_unchanged, structured_isar_proof, isabelle_build_and_check (251 lines) | pre-config, cap 600 |
| haiku-k3 | haiku-hard-candidate-shor-core | `5AsWPxN` | 1.0 | - | 508 | 30 | 35 | 150,299 | 0.317 | - | pre-config |
| haiku-k3 | haiku-hard-candidate-shor-core | `8DH9z93` | 1.0 | - | 916 | 59 | 59 | 204,712 | 0.597 | - | pre-config |
| haiku-k3 | haiku-hard-candidate-shor-core | `yGtK3Q6` | 1.0 | - | 520 | 28 | 27 | 96,736 | 0.062 | - | pre-config |
| haiku-k3 | haiku-hard-candidate-shor-gcd | `69BcHbe` | 1.0 | - | 572 | 34 | 33 | 129,720 | 0.243 | - | pre-config |
| haiku-k3 | haiku-hard-candidate-shor-gcd | `Qq2D8rx` | 1.0 | - | 779 | 38 | 38 | 138,984 | 0.265 | - | pre-config |
| haiku-k3 | haiku-hard-candidate-shor-gcd | `YtAKBgn` | 1.0 | - | 734 | 34 | 33 | 174,175 | 0.369 | - | pre-config |
| haiku-k3 | haiku-hard-cauchy | `F9dsdye` | 0.0 | AgentTimeoutError | 1800 | 59 | 58 | 151,840 | 0.355 | no_forbidden_tokens (`sorry`), statement_unchanged, structured_isar_proof, isabelle_build_and_check (final file 10 lines) | pre-config, cap 600 |
| haiku-k3 | haiku-hard-cauchy | `GDbq6yP` | 0.0 | AgentTimeoutError | 1800 | 99 | 77 | 212,628 | 0.280 | within_line_limit (613 > 600), isabelle_build_and_check | pre-config, cap 600 |
| haiku-k3 | haiku-hard-cauchy | `S8v2Jeu` | 0.0 | AgentTimeoutError | 1800 | 55 | 60 | 255,147 | 1.152 | within_line_limit (656 > 600), isabelle_build_and_check | pre-config, cap 600 |
| haiku-k3 | sonnet-hard-candidate-shor-exact-openbook | `53rwX2C` | 1.0 | - | 988 | 75 | 74 | 184,373 | 0.665 | - | pre-config, retired task |
| haiku-k3 | sonnet-hard-candidate-shor-exact | `7NiKYUR` | 0.0 | AgentTimeoutError | 1800 | 56 | 57 | 179,146 | 0.395 | isabelle_build_and_check (451 lines) | pre-config, cap 550, retired task |
| haiku-k3 | sonnet-hard-candidate-shor-exact-openbook | `7akqP8j` | 1.0 | - | 1043 | 50 | 49 | 267,086 | 0.903 | - | pre-config, retired task |
| haiku-k3 | sonnet-hard-candidate-shor-exact | `fdw9BJx` | 1.0 | - | 1103 | 55 | 55 | 270,946 | 0.956 | - | pre-config, retired task |
| haiku-k3 | sonnet-hard-candidate-shor-exact | `r3uRNLk` | 1.0 | - | 1467 | 68 | 70 | 222,016 | 0.841 | - | pre-config, retired task |
| haiku-k3 | sonnet-hard-candidate-shor-exact-openbook | `xnm2Rga` | 1.0 | - | 769 | 65 | 65 | 140,921 | 0.360 | - | pre-config, retired task |
| 2026-11-03__00-52-43 | sonnet-hard-candidate-shor-general-withmetis | `efywNku` | 0.0 | - | 877 | 47 | 46 | 122,769 | 0.237 | no_forbidden_tokens (`sorry`), isabelle_build_and_check (120 lines) | withmetis variant, cap 900, 30-min prompt |

Failed trials, 1 to 3 quotes each (`step_id`, timestamp from `trajectory.json`):

- **haiku-hard-candidate-cauchy-openbook `PEL8rJY`** (timeout; banned token; over cap; build fail)
  - step 39: "The error persists and the build spends about 70 seconds before being killed, which points to a runaway step in the main theorem rather than a simple syntax issue."
  - step 41: "Even the earliest truncation is killed, so the fault is before Step 1 in the theorem's opening lines."
- **haiku-hard-candidate-cauchy-openbook `nYDiWc4`** (timeout; main theorem unfinished; statement_unchanged false)
  - step 16: "The `sorry` is still a placeholder for the remaining inductive step."
  - step 37: "One thing to fix before going on: `comp_apply` contains the substring `apply`, which a naive forbidden-word check would flag."
- **haiku-hard-cauchy `F9dsdye`** (timeout; final file 10 lines with `sorry` at line 8)
  - step 52: "The final part I just wrote has two placeholders (`metis` and `sorry`) that must not stay in the file."
  - step 54: "Placeholders are gone. The running build uses an out-of-date `Cauchy.thy`, so I'll stop it and build the complete file." (contradicted by the artifact copy)
- **haiku-hard-cauchy `GDbq6yP`** (timeout; over cap; build hang)
  - step 20: "The earlier build is still silent after several minutes, which suggests a slow or looping proof step. I'm stopping it and running a verbose build to a log file so I can see where it is."
  - step 121: "The lemma part without the main theorem is being checked on its own. I'll read the result when it reports back." (last agent step; run ended at the timeout)
- **haiku-hard-cauchy `S8v2Jeu`** (timeout; over cap; build hang)
  - step 19: "The build hit the 10-minute limit and moved to the background. I'll check its output file for progress."
  - step 56: "The generic section now builds. Next I'll build the full `/app` submission with a time limit so a hang shows up quickly." (last agent step)
- **sonnet-hard-candidate-shor-exact `7NiKYUR`** (timeout; Isabelle/Poly-ML crash under disk and heap pressure)
  - step 28: "The Poly/ML process itself is being SIGKILLed near the end of `HOL`, after my `ML_OPTIONS` override was also clobbered by the settings."
  - step 29: "The root overlay is nearly full (7.2 GB free) and the heap is still being killed late in the build."
- **sonnet-hard-candidate-shor-general-withmetis `efywNku`** (no timeout; ended with `sorry` in two lemmas)
  - step 48: "`shor_peak` and `shor_general_success` still end in `sorry`, so the file will fail the grader as it stands. I also went past the 30-minute budget."
  - Note: trajectory spans 08:54:10 to 09:08:43 (about 14.6 min, matching agent_seconds 877), so the 30-minute claim is not supported by the timestamps.

### Current-config headroom (2026-11-03)

`jobs/lean-haiku-k3` (k=3, 60 min, metis/meson allowed): Cauchy 1/3, Shor-general 2/3, Shor-paper 1/3. Per-trial lines, time, calls, cost and failure reasons: [WRAPUP.md](WRAPUP.md#results-jobslean-haiku-k3-current-config-metismeson-allowed-60-min). The table above is older configs.

## 3. Cross-checks

- `isabelle_build_and_check` failed in 7 of 7 failed Lean trials.
- `within_line_limit` failed in 3 (`PEL8rJY`, `GDbq6yP`, `S8v2Jeu`); `no_forbidden_tokens` in 3 (`PEL8rJY` `axioms`; `F9dsdye` and `efywNku` `sorry`).
- `statement_unchanged` failed only in `nYDiWc4` and `F9dsdye`.
- Cauchy cap at run time was 600 lines (prompt text in `verifier/test-stdout.txt`); the current task cap is 750. Shor-exact cap at run time was 550.
- The haiku-k3 prompts (checked on Cauchy and Shor-exact trials) ban metis; the current configuration allows metis/meson.
