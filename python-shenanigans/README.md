# python-shenanigans

**Status summary:** see [WRAPUP.md](WRAPUP.md) (what is here, what is not, what is fair or unfair).

Research workspace for one take-home hypothesis: can an agent migrate a substantial part of a real
pure-Python library to scale on free-threaded CPython 3.15 while keeping exact behaviour and one-core
speed? The goal is Harbor tasks where Claude Haiku 5.5 fails pass@3. The assignment is in
the take-home brief (not shipped); the task contract is [clarified-vision.md](clarified-vision.md), the
selection process is [pipeline.md](pipeline.md), and current state is [handoff.md](handoff.md).

## Active tasks

`series/third-attempt/` (see its [README](series/third-attempt/README.md) for verifier structure,
isolation, and residual risks):

| Task | Library | Anchor |
| --- | --- | --- |
| `lark-earley/` | Lark 1.3.1 | `Lark.parse` (timed); forest operations covered by correctness |
| `sympy-state-space/` | SymPy 1.14.0 | `StateSpace.dsolve` and its matrix/solver machinery |

Each task: `instruction.md`, `task.toml`, `environment/` (agent image, library only), `tests/` (private
verifier: `verify.py` parent, `worker.py`/`adapter.py`/`sandbox.py` worker side, `workloads.py` parent-only
generators, `config.json`), `AUTHOR.md` (private notes). `solution/` holds the oracle (`solve.sh`).

## Checks

Cheap, no Docker (from `python-shenanigans/`):

```sh
for t in lark-earley sympy-state-space; do python3 -m py_compile series/third-attempt/$t/tests/*.py; done
uvx ruff check --isolated --line-length 120 --select F,E,B,UP --ignore E501 series/third-attempt/*/tests
```

The root `pyproject.toml` ruff config excludes `series/`, hence `--isolated`. Remove `__pycache__` after.

Controls (Docker; run from the repo root so `jobs/` lands there; key is in the repo-root `.env`):

```sh
harbor run -p python-shenanigans/series/third-attempt/lark-earley -a nop -n 1 -o python-shenanigans/jobs/third-attempt-nop --env-file .env
harbor run -p python-shenanigans/series/third-attempt/sympy-state-space -a nop -n 1 -o python-shenanigans/jobs/third-attempt-nop --env-file .env
```

A healthy no-op `checks.json` has `correctness.passed: true`, `performance.passed: false`, reward 0.

## Layout

- `series/third-attempt/`: active tasks. `old/series-first-attempt-fail`, `old/series-second-attempt-fail`:
  earlier series and why they failed.
- `old/`: screening results, candidate notes, earlier authoring code (`author`, `sympy-polys-factorization`),
  stale tests. Reference only.
- `jobs/`: Harbor runs; third-attempt oracle/nop controls are in `jobs/mi60/` (oracle 1.0, nop 0.0 for both tasks).
- `mise.toml` tasks still point at the old `author/` layout and are stale.

## Pilot runs with a different time budget

`../tools/pilot <task-dir> <minutes> [harbor args]` copies the task, rewrites its "You have N minutes." line and
runs `harbor run` with the matching `--agent-timeout-multiplier` (default: claude-code, Haiku 5.5, reasoning_effort=high,
`-k 1`, the workspace `.env`). The task itself is never edited. Example: `../tools/pilot series/third-attempt/lark-earley 15`.
