# lean-to-isabelle

**Status summary:** see [WRAPUP.md](WRAPUP.md) (what is here, what is not, what is fair or unfair).

Harbor tasks for theorem proving in Isabelle/Isar from a small trusted base. The agent gets
definitions or axioms, a theorem statement ending in `sorry`, and a Lean 4 proof as a reference (not
a template). It must write a structured, readable Isar proof. Reward is binary.

## Tasks

| Task | Theorem | Trusted base | Line cap |
| --- | --- | --- | --- |
| `haiku-hard-cauchy/` | Cauchy: if a prime p divides \|G\|, some element has order p | `Main` + `Group_Axioms` (left identity and left inverses only) | 600 |
| `sonnet-hard-candidate-shor-general/` | Shor, general period: for 0 < r < N each outcome within r/2 of a multiple of N/r has probability ≥ 4/(π²r)(1 − r/N)³; if r² < N, `recover` returns r with probability ≥ 4/π² · φ(r)/r · (1 − r/N)³ | `Complex_Main` + `Quantum_Basics` | 700 |
| `sonnet-hard-candidate-shor-general-paper/` | Same theorems as shor-general, but the reference is a human-written paper (PDF, `pdftotext` installed) instead of a Lean proof | `Complex_Main` + `Quantum_Basics` | 700 |

Provenance: the paper is Fang Xi Lin, "Shor's Algorithm and the Quantum Fourier Transform" (McGill, 2013),
https://www.math.mcgill.ca/darmon/courses/12-13/nt/projects/Fangxi-Lin.pdf, stored as
`quantum-src/references/Lin_Shor_QFT_2013.pdf`. It uses different constants and a looser argument than our theorems.
`quantum-src/Shor_General_sketch.md` is an unshipped author-written outline of the same route. The variant exists
because `harbor check` flagged the shipped Lean file as a full answer key.

Directory names carry the original aspirational tier labels (`haiku-hard`, `sonnet-hard`,
`-candidate`). They are not measured; measured results go in each `task.toml`
(`difficulty_evidence`) and in `handoff.md`.

Solved and retired tasks are frozen in [`../lean-to-isabelle-archive/`](../lean-to-isabelle-archive/README.md).

`Group_Axioms.thy` and `Quantum_Basics.thy` are the trusted bases; [`Group_Axioms.md`](Group_Axioms.md)
and [`quantum-src/Quantum_Basics.md`](quantum-src/Quantum_Basics.md) explain them. HOL-Algebra,
HOL-Analysis, HOL-Library and the AFP are not allowed. Each task ships a Lean 4 file
(`environment/*.lean`) as a reference, not a template.

Sandbox: open web access (Harbor default `network_mode = "public"`) and the Isabelle2025 sources.
Each `task.toml` has the take-home gateway block `[environment.env]` (`ANTHROPIC_BASE_URL`,
`ANTHROPIC_API_BASE` = `https://take-home-automation.vercel.app`), required by the brief. Agent budget
60 minutes (`3600 s`), verifier 600 s, grader build limit 8 minutes, 2 CPUs, 6 GB. Instructions say
to wrap builds in `timeout`, use `-o threads=2`, and that `isabelle process` may hang.

## Permitted proof methods

- **Banned for soundness:** `sorry`, `oops`, `axiomatization`/`axioms`, `oracle`, `skip_proofs`,
  `quick_and_dirty`, every `ML`/`setup`/syntax-translation command.
- **Banned for structure:** `apply`-style scripts (`apply`, `done`, `back`, `defer`, `prefer`), `smt`,
  `sledgehammer`, `nitpick`, `nunchaku`, `quickcheck`. `smt` also depends on the bundled solver version.
- **Allowed:** `metis` and `meson` (reconstructed in the kernel) and ordinary methods: `rule`, `simp`,
  `auto`, `blast`, `fastforce`, `force`, `linarith`, `arith`, `algebra`, `induction`, `cases`.

## Run

From the repo root (`/home/raist/code/workshop/rl-env-explore`), so `jobs/` is created there. Needs
Docker; the first run builds the Isabelle image.

```sh
# controls: oracle must score 1.0, nop 0.0
harbor run -p lean-to-isabelle -a oracle -n 2
harbor run -p lean-to-isabelle -a nop -n 2

# lint a task
harbor check lean-to-isabelle/haiku-hard-cauchy -m claude-haiku-5-5

# model trial (key is in the repo-root .env, not the shell)
harbor run -p lean-to-isabelle -a claude-code -m anthropic/claude-haiku-5-5 \
  --ak reasoning_effort=high --env-file ../.env -k 1

# per-trial reward, minutes, turns, tool calls, tokens, exception
uv run lean-to-isabelle/job_stats.py jobs/<job>
```

Select tasks with `-i`/`-x` globs, attempts with `-k`, concurrency with `-n`. Results are in
`jobs/<job>/`: `result.json`, and per trial `artifacts/app/*.thy`, `verifier/checks.json`, `agent/`.
Browse with `harbor view jobs`.

## Verifier

`<task>/tests/verify.py` runs in a separate container; only the submitted `.thy` is carried over.

- **Static:** allowed imports only, required theorems present (`theorems_present`), line cap, no
  banned token, and `proof ... qed` with at least 4 `have`/`show`/`thus`/`hence`/`obtain` steps
  between the first required theorem and EOF, plus a `qed` (the instructions state this). `scrub()`
  removes nested comments and cartouches and blanks strings before the token scan. Statement text is
  not compared.
- **Semantic:** a clean `isabelle build -o threads=2` with the trusted base swapped in. `Canonical.thy`
  parses the canonical statements; `Check.thy` compares each submitted theorem to them (`aconv`) and
  rejects oracles such as `sorry` or `skip_proofs`.

## Layout and editing

```
<task>/
  instruction.md     what the agent is told
  task.toml          timeouts, resources, difficulty, gateway env
  environment/       Dockerfile + /app contents (trusted base, stub .thy, ROOT, .lean)
  tests/             verify.py, test.sh, trusted base copy, Canonical.thy, Check.thy, ROOT
  solution/solve.sh  reference proof (the oracle)
```

- `haiku-hard-cauchy` is hand-written; edit in place. Only `tests/verify.py` is rendered by `gen.py`.
- `sonnet-hard-candidate-shor-general` and `-paper` are fully generated (the latter ships `quantum-src/references/*.pdf`). Edit `quantum-src/Quantum_Basics.thy`,
  `Shor_General.thy`, `Shor_General.lean`, `verify_template.py` or the tables in `quantum-src/gen.py`,
  then run `python3 quantum-src/gen.py` from this directory. It overwrites the generated files in the task directories; don't edit them by hand.
- After any change rerun the controls. Don't modify task dirs while evals run.

## Pilot runs with a different time budget

`../tools/pilot <task-dir> <minutes> [harbor args]` copies the task, rewrites its "You have N minutes." line and
runs `harbor run` with the matching `--agent-timeout-multiplier` (default: claude-code, Haiku 5.5, reasoning_effort=high,
`-k 1`, the workspace `.env`). The task itself is never edited. Example: `../tools/pilot haiku-hard-cauchy 15`.

## Task quality check

`harbor check` has no `--env-file`; pass the gateway credentials with `--ae` (values are not printed):

```sh
set -a; . ./.env; set +a
harbor check lean-to-isabelle/<task> -m claude-haiku-5-5 --ae ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" --ae ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL"
```

It may end with `DownloadVerifierDirError`; the findings are still in `artifacts/check-result.json` of its job.
Last run (2026-11-03): cauchy passes all items; shor-general flagged the forbidden-word list (now stated in full),
the shipped Lean proof (intended: translation is the task) and a heredoc oracle (normal for an oracle).
