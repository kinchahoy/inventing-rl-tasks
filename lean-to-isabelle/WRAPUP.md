# Wrap-up: lean-to-isabelle (2026-11-03)

Attack: write a structured Isabelle/Isar proof of a substantial theorem from a minimal trusted base, given a
reference proof (Lean 4, or a human-written paper for the `-paper` variant). Three active tasks.

## What's here

| Task | Theorem | Line cap (oracle) | Oracle | nop |
| --- | --- | --- | --- | --- |
| `haiku-hard-cauchy` | Cauchy's theorem from left-identity/left-inverse group axioms | 600 (497) | 1.0 | 0.0 |
| `sonnet-hard-candidate-shor-general` | Shor's algorithm, general period: factor step, peak bound, success probability | 700 (602) | 1.0 | 0.0 |
| `sonnet-hard-candidate-shor-general-paper` | Same theorems; reference is Lin (McGill 2013) PDF instead of Lean | 700 (602) | 1.0 | 0.0 |

The `-paper` variant exists because `harbor check` flagged the shipped Lean file as an answer key; the paper's
statements, constants and rigour differ. Redistribution rights for the PDF are unverified (no licence stated). Its `harbor check` passes all 11 items
(`jobs/2026-11-03__18-10-56`); the answer-key flag does not apply to it.
Controls (paper: `jobs/lean-paper-oracle`, `jobs/lean-paper-nop`): `jobs/lean-oracle-final`, `jobs/lean-nop-final` (workspace-root `jobs/`). 60-minute agent budget;
grader build limit 8 minutes. `metis`/`meson` allowed; `smt`, sledgehammer, apply-scripts, `sorry`, axioms and
ML/syntax commands banned (listed in full in the prompt). Verifier: static gates (imports, banned words, line cap,
>= 4 Isar steps) plus a clean Isabelle build; each theorem compared term by term against a trusted canonical
statement, and oracle-based proofs rejected at kernel level. Retired tasks are in `../lean-to-isabelle-archive/`.

Evidence for the report (controls, old model trials, failure quotes): [EVIDENCE.md](EVIDENCE.md).

## What's not done

- **Haiku 5.5 headroom (k=3, 60 min, job `jobs/lean-haiku-k3`, 2026-11-03): no task meets pass@3 = 0.**
  Cauchy 1/3 (fails: line cap at timeout; build error), Shor-general 2/3 (fail: `sorry` left in),
  Shor-paper 1/3 (fails: `sorry` left in twice; one also an unfinished `abs` arithmetic goal). Passing trials took
  35-53 min and 164-273 model calls, $0.69-2.97. Older evidence (metis banned, 30 min, no Lean reference) was
  Cauchy 0/3 and Shor-general 0/1. The passing proofs barely use metis/meson (Cauchy 0; Shor 1-7 metis, at most 1 meson; mostly simp/auto/blast/linarith), so the longer budget and looser line caps (Cauchy 600 -> 750), not metis, removed the headroom. Passing proofs sit at the caps: Cauchy 720/750, Shor 689-900/900.
- `harbor check` has not been rerun since the caps became 600/700 (a cap-only change; earlier status in the table below).
- Every rule the verifier enforces is in the prompt; the grader is the Isabelle kernel plus trusted statements.
- Statements cannot be weakened (term-by-term check) and `sorry`/oracles cannot slip through.
- metis/meson allowed: no artificial method bans. Line caps are ~1.5x a careful human proof.

## Unfair or weak spots

- A complete Lean proof of the same theorems ships with each task: the task is translation, which lowers
  difficulty (intended premise, but state it).
- Line caps still bound proof length; verbose but correct proofs can fail.
- The ">= 4 Isar steps" gate is easy to pad and is only a weak style check.
- Open web access: the agent can look up proofs (soundness unaffected; difficulty measurement is).
- Weak fit to "software engineering"; frame as long-horizon proof engineering.
- Past failures were dominated by hung builds and timeouts; long silent `isabelle build` runs make episodes costly.

## `harbor check` status (2026-11-03)

| Task | Result |
| --- | --- |
| `haiku-hard-cauchy` | clean |
| `sonnet-hard-candidate-shor-general` | flags `anti_cheating_measures` (complete Lean proof shipped) and `hardcoded_solution` (oracle is one heredoc). A Dockerfile comment explaining that the Lean proof is the translation input did not change the verdict (job `2026-11-03__18-30-46`, findings in `agent/claude-code.txt`; Harbor's artifact download failed). Accepted: translation is the premise; use the `-paper` variant where this matters. |
| `sonnet-hard-candidate-shor-general-paper` | clean, 11/11 (job `2026-11-03__18-10-56`) |

## Headroom runs (run 2026-11-03; results above)

From the workspace root, Lean tasks can run locally and in parallel (pass/fail, not timing-sensitive):

```sh
harbor run -p lean-to-isabelle -a claude-code -m claude-haiku-5-5 --ak reasoning_effort=high -k 3 -n 3 --env-file .env -y --job-name lean-haiku-k3
uv run tools/trial-stats.py jobs/lean-haiku-k3
```

### Results: `jobs/lean-haiku-k3` (current config: metis/meson allowed, 60 min)

| Task (cap; oracle lines) | Trial | Lines | Agent min | LLM calls | Cost $ | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Cauchy (750; 497) | `Z34V89y` | 720 | 46 | 164 | 0.69 | **pass** |
| | `2B9E8Xs` | 767 | 60 | 77 | 1.93 | fail: line cap, agent timeout |
| | `XPdJh8u` | 594 | 48 | 71 | 1.13 | fail: Isabelle build error |
| Shor-general (900; 602) | `qtwarkH` | 689 | 35 | 273 | 2.94 | **pass** |
| | `UQt525x` | 900 | 43 | 181 | 2.97 | **pass** (exactly at cap) |
| | `pyezQEb` | 775 | 34 | 188 | 2.16 | fail: `sorry` left in |
| Shor-paper (900; 602) | `b4kFBek` | 862 | 53 | 203 | 2.72 | **pass** |
| | `sEJfsKQ` | 491 | 24 | 131 | 0.91 | fail: `sorry` + unfinished `abs` goal |
| | `TNvFiQP` | 289 | 15 | 42 | 0.63 | fail: `sorry`, gave up early |

pass@3: Cauchy 1/3, Shor-general 2/3, Shor-paper 1/3, so none meets pass@3 = 0.

Proof methods in the passing proofs: metis 0 (Cauchy) and 1-7 (Shor), meson at most 1; the bulk is
simp/auto/blast/linarith. Allowing metis did not create these passes.

All passes are 1.15-1.5x the oracle's length and sit near the caps.

Line-cap thresholds, judged against these runs:

| Cap | Cauchy | Shor-general | Shor-paper | Restores pass@3 = 0? |
| --- | --- | --- | --- | --- |
| Current (750 / 900) | 1/3 | 2/3 | 1/3 | **No (observed).** |
| Cauchy 700 / Shor 800 | 0/3 | 1/3 (689) | 0/3 | **No:** `qtwarkH` (689 lines) still passes. |
| Cauchy 700 / Shor 750 | 0/3 | 1/3 (689) | 0/3 | **No:** same trial. |
| Cauchy 600 / Shor 650 | 0/3 | 0/3 | 0/3 | Yes, if agents don't adapt (below). |
| Below the oracle (< 497 / < 602) | - | - | - | Not allowed: the oracle must pass. |

Re-scoring the same proofs is weak evidence for any tighter cap. The cap is stated in the prompt, and agents
write to it: `UQt525x` finished at exactly 900/900 and `2B9E8Xs` was still over 750 when time ran out, which shows
trimming toward the limit. With a lower cap, agents may compress (fewer intermediate `have`s, longer `simp` calls)
rather than fail. Only a rerun shows whether a cap works.

The old 600-line Cauchy cap (0/3) does not settle this either: those runs also banned metis and gave 30 minutes,
so that cap was never tested on its own.

Counterfactual only; not applied.

### Tighter caps rerun: Cauchy 600, Shor 700 (2026-11-03/04, mi60, `jobs/mi60-lean/`)

Rounds of one trial per task, stopping on any pass. The caps are in the prompts, `tests/verify.py` and `gen.py`.

| Round | Cauchy | Shor-general | Shor-paper |
| --- | --- | --- | --- |
| 1 (`lean-cap600-700-r1`) | 0: 625 lines (> 600), `sorry` left in, theorem missing, build timed out; agent used all 60 min | 0 | 0: agent used all 60 min |
| 2 | lost: mi60 crashed between 00:10 and 00:34 (see `../crash-diagnosis.md`) | lost | lost |
| 3 | not run | not run | not run |

So far 0/1 per task at the tighter caps. That is consistent with restoring headroom, but it is one trial each, not pass@3.
