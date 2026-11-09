# archive/evidence

Files the report links to. Generated from the runs and notes; numbers are authoritative in `final-scores.md`.

| File | What it is |
|---|---|
| `model-summary.md` | Scores per task × model; hard checks run by run (start here) |
| `final-scores.md` | Scoring ledger: every run, incl. superseded v1, re-grades, ablations, side runs |
| `core-run-stats.md` | Per-trial steps, LLM/tool calls, builds, tokens, minutes, cost |
| `missed-items.md` | Every missed check: why fair, failure mode, one-command discovery step, who missed it |
| `missed-items.csv` | Same as CSV |
| `miss-map.md` | All 80 core checks grouped by who solves them |
| `miss-map.csv` | Same as CSV |
| `check-results-haiku.csv` | Every check × final Haiku trial (P/F) |
| `check-regimes.md` | Three headroom regimes behind pass@3 = 0 |
| `check-regimes.csv` | Same as CSV |
| `opus-vs-haiku-node17.csv` | node17 check by check: Opus vs Haiku vs Sonnet |
| `trajectory-review.md` | Per-trial failure analysis of the final runs |
| `verifier-fixes-all-attacks.md` | Every verifier fix across the three efforts, why, and what caught it |
| `problem-map.csv` | Problems hit: verifier / task framing / difficulty surprises / infra |
| `complexify.md` | The complexifier library and design rule |
| `methods.md` | Verification methods and rules (deny+allow, probe daemons, controls) |
| `pipeline-map.md` | How boxes were found/filtered/complexified; how to find many more |
| `new-box-recipe.md` | Mechanical recipe for a new box (script / Haiku / human per step) |
| `proxy-vs-grader.md` | Why agents stop on green (cross-effort) |
| `provenance/node17.md` | node17: upstream source, commit, what was kept / simplified / renamed |
| `provenance/node23.md` | node23: upstream source, commit, what was kept / simplified / renamed |
| `provenance/node31.md` | node31: upstream source, commit, what was kept / simplified / renamed |
| `provenance/node37.md` | node37: upstream source, commit, what was kept / simplified / renamed |
| `provenance/node41.md` | node41: upstream source, commit, what was kept / simplified / renamed |
