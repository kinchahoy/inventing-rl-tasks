# Report figures and tables

| # | What | File |
|---|---|---|
| ★ | **Start here: one-page model summary (scores per task × model; hard checks run by run)** | `model-summary.md` |
| 1 | How we found and complexified the boxes, and how to find many more (Mermaid funnel + scale flow) | `pipeline-map.md` |
| 2 | Repeatable, mechanical recipe for a new box (script / Haiku / human per step) | `new-box-recipe.md` |
| 3a | Every missed item: why it's fair, failure mode, discovery step, ever missed by Haiku/Sonnet, final k=3 passes | `missed-items.csv` (source: `../missed-items.md`) |
| 3b | Every check × final Haiku trial (P/F), with origin recipe/complexifier | `check-results-haiku.csv` |
| 4 | Problem map: verifier / task framing / difficulty surprises / harness & infra | `problem-map.csv` + mindmap in `../verifier-fixes-all-attacks.md` |
| 5 | Three headroom regimes behind pass@3 = 0 (always / sometimes / never per task) | `check-regimes.md` + `check-regimes.csv` |
| 6 | Proxy vs grader: why agents stop on green (Mermaid + cross-effort table) | `proxy-vs-grader.md` |
| 7 | Opus vs Haiku vs Sonnet on node17, check by check | `opus-vs-haiku-node17.csv` |
| 8 | Map of all checks by who solves them (reliable / sometimes / only no-clock / nobody) | `miss-map.md` + `miss-map.csv` |
| – | Per-trial steps, tool calls, cost | `../core-run-stats.md` |

Mermaid renders on GitHub and in most Markdown viewers. For a PDF report, paste the blocks into mermaid.live and export SVG.
`check-results-haiku.csv` uses node17's v1 trials re-graded with v2 until the v2 run finishes; it's regenerated then.
