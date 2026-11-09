# inventing-rl-tasks

::: {.ai}
_AI-drafted_ · map only; the per-family READMEs are unchanged.

| Path | What |
|---|---|
| `submission/` | The submission as shipped (`samples/`, `jobs/`, `archive/`), minus the written report. `faking-it-with-nix/author/make-submission.sh --zip` rebuilds it from `author/submission-manifest.tsv`. |
| `faking-it-with-nix/` | Nix: reconstruct a running Ubuntu VM as a NixOS 26.05 module. Tasks node17/23/31/37 (+ node41 easy control), `author/` (recipes, Chef cookbooks, builder, verifier methods, timeline, real-host inventories), `ablations/`, `harbor-check/`, `backup/` (node29 draft), final job records. Start at its `README.md`. |
| `python-shenanigans/` | Free-threaded Python speedup tasks (`series/third-attempt/`: lark-earley, sympy-state-space), the selection pipeline (`pipeline.md`) and job records. |
| `lean-to-isabelle/` | Lean to Isabelle translation tasks, their generator (`quantum-src/gen.py`) and job records. |
| `docs/study/` | Annotated Nix oracles and readable renderings of five trajectories. |
| `tools/` | `pilot`, a wrapper for runs with a different time budget. |
| `replicate-this.md` | How to regenerate everything. |

**Licence.** MIT (`LICENSE`), except the upstream-derived recipes under `faking-it-with-nix/author/tasks/<id>/`, which keep the Apache-2.0 `LICENSE` file in their directory. Source libraries inside task environments (Lark, SymPy, etc.) keep their own licences.
:::
