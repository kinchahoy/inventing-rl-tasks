# Three headroom regimes behind pass@3 = 0

Per-check pass counts over the 3 final Haiku trials (node17 = the v2 final run). Rows: `check-regimes.csv`; checks not listed there passed 3/3.

| Task | Checks | Always pass | Sometimes | Never | Union of 3 trials | Best trial | Regime |
|---|---|---|---|---|---|---|---|
| node17 | 35 | 19 | 10 | 6 | 29/35 | 0.83 | Breadth/attention: whole mechanisms never inspected (limits, DB catalogs, logrotate, CGI identity) |
| node31 | 27 | 25 | 1 | 1 | 26/27 | 0.96 | Capability: one item no trial, nudge or Sonnet fixed |
| node37 | 18 | 14 | 4 | 0 | 18/18 | 0.94 | Reliability: every item solved by some trial, never all in one |

node17 never-pass (v2): slice_limits, postgres_isolation, cgi_identity, login_limits, log_rotation, db_role_limits.
For contrast, the earlier v1 node17 trials (re-graded with v2) had 13 / 13 / 9 always / sometimes / never.
