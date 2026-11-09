# Results

Model trials (claude-code agent, `reasoning_effort=high`, `-k 1`). Generated from `jobs/` with `author/trial-stats.py`; controls (oracle 1.0 / nop 0.0 / reference all-pass for every task) are in each task's verification.md. Prompts changed on 2026-11-03 ~16:20 (commands wording added to all four); every run below used the earlier wording except ablation #5. node23/node31 runs before ~16:30 used solving images without build-user parity (verifier builds passed, so scores stand).

| Task | Model | Job | Reward | By origin | Agent min | LLM calls | Builds / boots | Cost $ | Failed checks | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| node17 | claude-haiku-5-5 | `2026-11-03__11-36-20` | 0.824 | recipe 27/31, complexifier 1/3 | 55.9 | 78 | 12 / 4 | 0.66 | sudo_log_policy, slice_limits, postgres_isolation, cgi_identity, login_limits, log_rotation | 60 min |
| node17 | claude-haiku-5-5 | `node17-haiku-120m-r2` | 0.0 |  | 25.8 | 94 | 15 / 13 | 1.29 |  | 120 min; build failed in verifier (root-build mismatch, since fixed) — not a task result |
| node17 | claude-haiku-5-5 | `node17-haiku-120m-r3` | 0.853 | recipe 29/31, complexifier 0/3 | 46.6 | 81 | 8 / 4 | 0.55 | slice_limits, postgres_isolation, sudo_decoy, login_limits, log_rotation | 120 min via tools/pilot |
| node17 | claude-sonnet-5.5 | `node17-sonnet-or-30m` | 0.882 | recipe 27/31, complexifier 3/3 | 8.3 | 33 | 5 / 0 | 0.85 | slice_limits, postgis, cgi_identity, wsgi_identity | 30 min, OpenRouter, new prompt wording |
| node23 | claude-haiku-5-5 | `node23-haiku-60m` | 0.84 | recipe 19/22, complexifier 2/3 | 13.2 | 57 | 6 / 5 | 0.17 | listeners, recursor_version_string, monitoring_api, socket_tuning | 60 min |
| node31 | claude-haiku-5-5 | `node31-haiku-60m` | 0.92 | recipe 21/22, complexifier 2/3 | 11.2 | 75 | 9 / 5 | 0.6 | amtool_operator, textfile_timer | 60 min |
| node31 | claude-haiku-5-5 | `node31-haiku-commands-60m` | 0.96 | recipe 21/22, complexifier 3/3 | 12.9 | 81 | 10 / 7 | 0.8 | amtool_operator | ablation #5 commands wording |
| node31 | claude-haiku-5-5 | `node31-haiku-downscope-30m` | 0.96 | recipe 21/22, complexifier 3/3 | 18.5 | 78 | 10 / 1 | 0.65 | amtool_operator | ablation #3 downscope, 30 min |
| node31 | claude-haiku-5-5 | `node31-haiku-nudge-60m` | 0.96 | recipe 21/22, complexifier 3/3 | 12.7 | 69 | 9 / 5 | 0.7 | amtool_operator | ablation #1 process nudge |
| node31 | claude-sonnet-5-5 | `node31-sonnet-60m-r2` | None |  | 0.0 | 1 | None / None | 0 |  | misrouted to the Haiku-only proxy: 403, 0 tokens — not a result |
| node31 | claude-sonnet-5.5 | `node31-sonnet-or-60m-r2` | 0.96 | recipe 21/22, complexifier 3/3 | 13.5 | 46 | 7 / 6 | 0.82 | amtool_operator | 60 min |
| node37 | claude-haiku-5-5 | `node37-haiku-60m` | 0.875 | recipe 11/13, complexifier 3/3 | 15.6 | 77 | 12 / 7 | 0.65 | module_policy, udev_i2c | 60 min |
| node37 | claude-haiku-5-5 | `node37-haiku-60m-regrade` | 0.941 | 16/17 | — | — | — | — | udev_i2c | **re-grade** of the node37-haiku-60m submission after fixing `module_policy` (literal `/bin/false`) and adding `operator_sudo`; no new agent run |
| node41 | claude-haiku-5-5 | `node41-haiku-30m` | 0.938 | recipe 15/16 | 5.0 | 27 | 4 / 1 | 0.08 | power_unit | easy control, 30 min |

Interpretation lives in `author/timeline.md` ("Findings so far", "Ablations").
