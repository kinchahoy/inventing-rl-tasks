# Inventing RL tasks

::: {.human}
_Human-drafted_

## Scalable reinforcement training (RL) tasks

Benchmarks and RL tasks are in some ways converging, and are becoming critical to training and refining models. We're finally at a juncture where we can scale up interesting real world problems in a way that generates hard challenges for models and creates meaningful train signal.

This repo inventories my explorations scaling out LLMs to solve interesting problems in a way that generates tasks that might be interesting reinforcement training or benchmarking problems.

### Replace a server with a functionally equivalent, reproducibly specified clone (e.g. using Nix)

Nix and other reproducible infrastructure tools make building infrastructure simpler and more like assembling reliable building blocks rather than handcrafting everything. However, it's really quite hard to take an existing environment and drop in a replacement that uses reproducible infra tech. Personally, I've tried at various times to take homelab and other servers that have been configured over time and turn them into clean, configurable environments, and it's quite hard! This makes them an excellent challenge for agents, and one that is both useful in the real world and has many dimensions of complexity (there are weirdly configured servers out there that would be impossible to replicate short of a VM clone).

The replicate-it-with-nix directory contains an attempt to take this idea and formalize it as a few reproducible Harbor tasks, with an eye towards scaling it up to many more tasks.

I'll write more about why this is an interesting problem space for agents in general, but at a high level, it's worth noting that none of this is particularly Nix-specific. It's probably a Turing complete problem to interact with a complex running system and specify a functional equivalent that is more compactly specified!

### Steps towards generating useful proofs for amateurs: Terse Lean -> from first principles Isabelle proofs

Lean proofs are especially hard for amateur mathematiciancs since they tend to tersely encode the proof based on other results. Isabelle/Isar is a proof system that uses more [human mathematician friendly structures](https://chatgpt.com/share/6af2227f-e1b4-83e8-9ed9-383a6188be77) in it's proof language. A fun challenge for agents is to take a tersely specificed Lean proof and translate them to an Isabelle proof (known area of research it turns out!), but also build the proof from first principles vs. networking into a broad set of existing results.

### Steps towards efficient autoparallelization of code: make python libraries efficiently use threads

[I've long hoped](https://news.ycombinator.com/item?id=49016447) that we'd be able to get a programming language that does a decent job of auto parallelizing arbirary code (without always expecting the code to be efficient, faster, or better). Agents of course significantly improve the potential to do this.

This task makes one aspect of this a challenge for agents. Can an agent take a pure python library and 1). overcome the performance loss from running it on [free threading (i.e. no gil) python](https://docs.python.org/3/howto/free-threading-python.html) 2). Obtain some multithread performance improvements?

More to come, reach out if this is interesting or fun!

:::

::: {.ai}
_AI-drafted_ · map only; the per-family READMEs are unchanged.

| Path | What |
|---|---|
| `pack/` | The submission as shipped (`samples/`, `jobs/`, `archive/`), minus the written report. `replicate-it-with-nix/author/make-pack.sh --zip` rebuilds it from `author/pack-manifest.tsv`. |
| `replicate-it-with-nix/` | Nix: reconstruct a running Ubuntu VM as a NixOS 26.05 module. Tasks node17/23/31/37 (+ node41 easy control), `author/` (recipes, Chef cookbooks, builder, verifier methods, timeline, real-host inventories), `ablations/`, `harbor-check/`, `backup/` (node29 draft), final job records. Start at its `README.md`. |
| `python-shenanigans/` | Free-threaded Python speedup tasks (`series/third-attempt/`: lark-earley, sympy-state-space), the selection pipeline (`pipeline.md`) and job records. |
| `lean-to-isabelle/` | Lean to Isabelle translation tasks, their generator (`quantum-src/gen.py`) and job records. |
| `docs/study/` | Annotated Nix oracles and readable renderings of five trajectories. |
| `tools/` | `pilot`, a wrapper for runs with a different time budget. |
| `replicate-this.md` | How to regenerate everything. |

**Licence.** MIT (`LICENSE`), except the upstream-derived recipes under `replicate-it-with-nix/author/tasks/<id>/`, which keep the Apache-2.0 `LICENSE` file in their directory. Source libraries inside task environments (Lark, SymPy, etc.) keep their own licences.
:::
