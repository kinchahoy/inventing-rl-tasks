# Handoff: lean-to-isabelle (2026-11-03)

## Goal

Hard, fair RL problems: the agent translates a Lean 4 reference into a structured Isar proof over a
small trusted base. No leaked tricks, no misleading hints; plain sandbox facts are fine. Active set is
three tasks (the third, `sonnet-hard-candidate-shor-general-paper`, ships a human-written paper instead of Lean; see README): `haiku-hard-cauchy` (hand-written) and `sonnet-hard-candidate-shor-general` (generated).
Directory names are the original aspirational tier labels, not measurements. Don't rename them.

## Current contract

- 60-minute agent budget (`task.toml` 3600 s, instructions say 60 minutes); verifier 600 s; grader
  build limit 8 minutes.
- `metis` and `meson` are allowed in every task (banning them was artificial difficulty). Still
  banned: `smt`, `sledgehammer`, `nitpick`, `nunchaku`, `quickcheck`, apply-style scripts,
  `sorry`/`oops`, axiomatization, ML/setup commands. The `-withmetis` variants are gone from `gen.py`.
- Every `task.toml` has the take-home gateway block `[environment.env]` (`ANTHROPIC_BASE_URL`,
  `ANTHROPIC_API_BASE` = `https://take-home-automation.vercel.app`), required by the brief.
- Quantum instructions state the Isar step gate (at least 4 `have`/`show`/`thus`/`hence`/`obtain`
  steps from the first required theorem to EOF, plus a `qed`), matching the verifier.
- Line caps are about 1.5× the oracle: Cauchy 750 (oracle 497; was 600 until 2026-11-03), Shor-general 900 (oracle 602).
- Archive `../lean-to-isabelle-archive/` is frozen as evaluated: solved-every-attempt tasks,
  retired-solved-once (`sonnet-hard-candidate-shor-exact` 2/3, `haiku-hard-candidate-cauchy-openbook`
  1/3) and superseded `-withmetis` tasks.

## Verification state

- Evidence predates the current config (metis then banned for Cauchy, 30-minute budget, no Lean
  references, older verifier):
  - Cauchy closed book 0/3 (`jobs/haiku-k3`): line cap (613 and 656 lines vs 600), build timeouts,
    and one attempt that never saved its work (submitted the 10-line `sorry` skeleton).
  - Shor-general with metis 0/1 (`jobs/2026-11-03__00-52-43`): gave up at 14.6 minutes with `sorry`
    in `shor_peak` and `shor_general_success`.
- Not yet re-run after the changes above: oracle/nop controls, `harbor check`, model trials.
- Line caps loosened to about 1.5× the oracle (user decision 2026-11-03), since the old Cauchy cap drove most measured failures.

- `sonnet-hard-candidate-shor-general-paper`: added because `harbor check` flagged the Lean file as an answer key. Reference
  is Lin (McGill 2013) PDF; `poppler-utils` installed in that image only. Controls: oracle 1.0 (`jobs/lean-paper-oracle`),
  nop 0.0 (`jobs/lean-paper-nop`). No model trial or `harbor check` yet.

## Resume

From `lean-to-isabelle/`, rerun `python3 quantum-src/gen.py` if sources changed. Then, from the repo
root, via cheap (Haiku) subagents:

1. Oracle and nop controls on both tasks (expect 1.0 and 0.0): `harbor run -p lean-to-isabelle -a oracle|nop -n 2`.
2. `harbor check lean-to-isabelle/<task> -m claude-haiku-5-5`.
3. Model trials only when the user asks:
   `harbor run -p lean-to-isabelle -a claude-code -m anthropic/claude-haiku-5-5 --ak reasoning_effort=high --env-file ../.env -k 1`
   (the key is in the repo-root `.env`, not the shell). Stats: `uv run lean-to-isabelle/job_stats.py jobs/<job>`.

Then update `DIFFICULTY` in `gen.py` and the Cauchy `task.toml` evidence with measured results.

Possible future task: Artin's fixed-field theorem (any card G + 1 elements of K are linearly
dependent over the fixed field), over a new `Field_Basics.thy`.

Tools: Docker image `cauchy-openbook:latest` has Lean, Mathlib and Isabelle (compile Lean with
`cd /opt/mathlib4 && lake env lean /w/X.lean`). Quick Isabelle builds go through a dir holding a `ROOT`.

## Rules

- Never launch model runs unless asked. Run controls and builds through Haiku subagents and relay a summary.
- Always wrap Isabelle builds in `timeout`; a looping tactic hangs `isabelle build` silently.
- Never modify tests or oracles to fake an outcome; don't touch task dirs while evals run.
- The tree is untracked in git: copy anything before deleting it.
- Unused sources (No_Cloning, Shor_Core, Shor_Gcd, Shor_Exact) are in `quantum-src/old/`; the superseded
  `lean-drafts/` is in `../old/`.
