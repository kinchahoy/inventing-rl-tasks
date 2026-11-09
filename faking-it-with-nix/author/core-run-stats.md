# Core runs: agent steps, tool calls, cost (final Haiku k=3)

Source: `uv run author/trial-stats.py <job>` and each trial's `agent/trajectory.json` (ATIF).
Model claude-haiku-5-5, claude-code, reasoning_effort=high, 60-minute budget. Every trial stopped on its own (no timeouts).

| Task | Trial | Reward | Recipe / CX | Agent min | ATIF steps | LLM calls | Tool calls (Bash / Edit / Write / Read) | check / build / boot | Ref shell / cand shell | Peak prompt tok | Output tok | Cost $ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| node17 (v1)† | 6WDtNr9 | 0.71 | 25/31 · 0/4 | 19.7 | 91 | 90 | 96 (79 / 16 / 1 / 0) | 4 / 9 / 6 | 40 / 25 | 198k | 114k | 0.81 |
| node17 (v1)† | aVqPFzU | 0.66 (v2: 0.43) | 22/31 · 1/4 | 34.9 | 76 | 75 | 74 (73 / 0 / 1 / 0) | 17 / 17 / 11 | 46 / 34 | 272k | 162k | 1.08 |
| node17 (v1)† | msYkvbq | 0.51 | 18/31 · 0/4 | 25.6 | 80 | 79 | 80 (78 / 0 / 2 / 0) | 9 / 9 / 1 | 33 / 21 | 211k | 123k | 0.84 |
| node31 | CXEA5DJ | 0.93 | 21/23 · 4/4 | 17.5 | 56 | 55 | 59 (50 / 6 / 3 / 0) | 7 / 7 / 0* | 29 / 14 | 158k | 78k | 0.42 |
| node31 | W39ZEQ8 | 0.96 | 22/23 · 4/4 | 19.7 | 85 | 84 | 83 (82 / 0 / 1 / 0) | 12 / 9 / 0* | 47 / 26 | 190k | 105k | 0.73 |
| node31 | cPwkSHL | 0.96 | 22/23 · 4/4 | 34.7 | 111 | 110 | 110 (90 / 17 / 2 / 1) | 15 / 12 / 0* | 51 / 30 | 279k | 148k | 1.59 |
| node37 | H734HNG | 0.94 | 13/14 · 4/4 | 18.3 | 66 | 65 | 73 (68 / 4 / 1 / 0) | 11 / 7 / 10 | 42 / 22 | 227k | 118k | 0.77 |
| node37 | kDEWSoi | 0.89 | 12/14 · 4/4 | 15.6 | 65 | 63 | 72 (55 / 3 / 12 / 0) | 11 / 9 / 1 | 37 / 20 | 213k | 110k | 0.40 |
| node37 | B6J7wvG | 0.89 | 13/14 · 3/4 | 19.4 | 55 | 53 | 59 (49 / 7 / 1 / 0) | 11 / 10 / 5 | 25 / 11 | 190k | 88k | 0.38 |
| node17 (v2) | YGbwZxB | 0.60 | 20/31 · 1/4 | 29.8 | 93 | 91 | 91 (73 / 14 / 1 / 0) | 12 / 12 / 0* | 32 / 14 | 214k | 109k | 0.56 |
| node17 (v2) | abX3r9G | 0.77 | 27/31 · 0/4 | 20.1 | 89 | 87 | 85 (77 / 5 / 1 / 0) | 11 / 7 / 7 | 41 / 25 | 214k | 110k | 0.45 |
| node17 (v2) | kLthoPm | 0.83 | 28/31 · 1/4 | 15.7 | 107 | 105 | 104 (80 / 0 / 1 / 0; +20 Monitor) | 16 / 13 / 3 | 34 / 18 | 219k | 103k | 1.00 |

Ranges (9 submitted core trials: node17 v2, node31, node37; the v1 rows are kept for reference): 15.6-34.9 agent minutes of 60; 53-110 LLM calls; 59-110 tool calls,
almost all Bash; 7-34 build/check cycles; 158k-279k peak context; $0.38-1.59 per trial.
node37 misses: tool_env, etc_environment, udev_i2c, sleep_policy.

- **check / build / boot** counts `check-replica`, `build-replica` and candidate-VM boots the agent ran itself.
- **Ref shell / cand shell** counts commands run in the reference VM and in the agent's own candidate VM.
- \* Rows showing 0 boots are a counter quirk: these agents ran commands in the candidate (cand shell > 0), so they did boot it, just by another command. Fix trial-stats or footnote it before quoting.
- † node17's v1 runs were superseded by v2 (see `author/final-scores.md`). Its step and tool counts don't depend on the verifier.
