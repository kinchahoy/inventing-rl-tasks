# archive/: bonus material

Submitted alongside the core pack (samples/ + jobs/). Each bonus-N set is laid out like the core pack: task dirs plus jobs/<job>/<trial>/.
Task directory names are unchanged so each job config still matches its task.

Paths written as `author/…` inside the evidence and source files refer to the source tree, shipped here as `bonus-4-nix-research/source/` (`author/real/` is deliberately excluded).

| Path | What it is |
|---|---|
| `bonus-1-nix-solved-example/node23-reconstruction-hard` | Nix · DNS host · Haiku solved 1 of 3 (0.77, 0.96, 1.0) |
| `bonus-1-nix-solved-example/jobs/node23-reconstruction-hard-oracle` | oracle 1.0 |
| `bonus-1-nix-solved-example/jobs/node23-reconstruction-hard-nop` | nop 0.0 |
| `bonus-1-nix-solved-example/jobs/node23-reconstruction-hard-haiku-k3` | brief's k=3 command |
| `bonus-2-python-free-threading/sympy-state-space` | Python · SymPy speedup · Haiku 0/3 |
| `bonus-2-python-free-threading/lark-earley` | Python · Lark speedup · Haiku 0/3 valid |
| `bonus-2-python-free-threading/jobs/sympy-oracle-final2` | oracle 1.0 |
| `bonus-2-python-free-threading/jobs/sympy-nop-final2` | nop 0.0 |
| `bonus-2-python-free-threading/jobs/sympy-state-space-haiku-k3` | Haiku k=3: 0, 0, 0 |
| `bonus-2-python-free-threading/jobs/lark-oracle-final2` | oracle 1.0 |
| `bonus-2-python-free-threading/jobs/lark-nop-final2` | nop 0.0 |
| `bonus-2-python-free-threading/jobs/lark-earley-haiku-k3` | Haiku k=3: 0, harness failure (excluded), 0 |
| `bonus-2-python-free-threading/jobs/lark-earley-haiku-k3-replacement` | replacement for the harness failure: 0 |
| `bonus-3-lean-isabelle-explored/haiku-hard-cauchy` | Lean→Isabelle · Haiku 1/3 |
| `bonus-3-lean-isabelle-explored/sonnet-hard-candidate-shor-general` | Lean→Isabelle · Haiku 2/3 |
| `bonus-3-lean-isabelle-explored/sonnet-hard-candidate-shor-general-paper` | Lean→Isabelle (paper reference) · Haiku 1/3 |
| `bonus-3-lean-isabelle-explored/jobs/lean-oracle-final` | oracle (Cauchy, Shor-general) |
| `bonus-3-lean-isabelle-explored/jobs/lean-nop-final` | nop |
| `bonus-3-lean-isabelle-explored/jobs/lean-paper-oracle` | oracle (paper variant) |
| `bonus-3-lean-isabelle-explored/jobs/lean-paper-nop` | nop (paper variant) |
| `bonus-3-lean-isabelle-explored/jobs/lean-haiku-k3` | Haiku k=3 at the OLD caps 750/900 (tasks here now carry 600/700): Cauchy 1/3, Shor 2/3, Shor-paper 1/3 |
| `bonus-3-lean-isabelle-explored/jobs/lean-cap600-700-r1` | Haiku at the current caps 600/700, one round only (round 2 lost to a host crash): 0/3 |
| `bonus-4-nix-research/node41-reconstruction-easy` | Nix · easy control (Haiku 0.94) |
| `bonus-4-nix-research/ablation-node31-process-nudge` | ablation · "compare systematically and fix every difference" |
| `bonus-4-nix-research/ablation-node31-downscope` | ablation · base-OS tuning declared out of scope |
| `bonus-4-nix-research/ablation-node31-commands` | ablation · commands wording (later adopted by all tasks) |
| `bonus-4-nix-research/jobs/node41-haiku-30m` | node41 · Haiku |
| `bonus-4-nix-research/jobs/node41-pull-oracle` | node41 · oracle from the published images |
| `bonus-4-nix-research/jobs/node31-haiku-nudge-60m` | ablation run · process nudge |
| `bonus-4-nix-research/jobs/node31-haiku-downscope-30m` | ablation run · downscope |
| `bonus-4-nix-research/jobs/node31-haiku-commands-60m` | ablation run · commands wording |
| `bonus-4-nix-research/jobs/node17-reconstruction-hard-oracle-v1` | node17 superseded · verifier v1 (lenient readiness) |
| `bonus-4-nix-research/jobs/node17-reconstruction-hard-nop-v1` | node17 superseded · verifier v1 |
| `bonus-4-nix-research/jobs/node17-reconstruction-hard-haiku-k3-v1` | node17 superseded · v1 0.71, 0.66, 0.51 |
| `bonus-4-nix-research/regrades/node17-v1-trials-under-v2` | v1 submissions re-graded with v2: 0.71, 0.43, 0.51 (author/regrade.sh; not Harbor output) |
| `bonus-4-nix-research/jobs/node17-haiku-120m` | 120-min budget (more time does not help) · earlier verifier revision |
| `bonus-4-nix-research/jobs/node17-sonnet-or-30m` | Sonnet 5.5 · earlier verifier revision |
| `bonus-4-nix-research/jobs/node31-sonnet-or-60m` | Sonnet 5.5 · earlier verifier revision |
| `bonus-4-nix-research/jobs/node31-sonnet-or-60m-r2` | Sonnet 5.5 · earlier verifier revision |
| `bonus-4-nix-research/source` | how the images were built: Chef recipes, Nix pins, Dockerfiles, scripts, notes (author/real/ excluded) |
| `bonus-4-nix-research/ablation-node17-no-clock` | ablation · "You have 60 minutes." removed (Harbor still stops at 60) |
| `bonus-4-nix-research/ablation-node31-no-clock` | ablation · "You have 60 minutes." removed |
| `bonus-4-nix-research/jobs/node17-haiku-no-clock-60m` | no-clock ablation run · node17 |
| `bonus-4-nix-research/jobs/node31-haiku-no-clock-60m` | no-clock ablation run · node31 |
| `evidence/` | Files the report links to (index: `evidence/README.md`) |
