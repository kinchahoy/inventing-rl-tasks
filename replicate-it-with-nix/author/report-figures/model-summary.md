# Model summary: every run on the core tasks

**Pass = reward 1.0 (every check).** No run of any model passed any core task.

## Table 1: scores per task and model

| Task | Haiku 5.5, final k=3 (submitted) | Haiku, no stated time limit* | Sonnet 5.5† | Opus 5.5‡ |
|---|---|---|---|---|
| node17 (35 checks) | 0.60 · 0.77 · 0.83 | 0.91 | 0.88 | 0.80 |
| node31 (27 checks) | 0.93 · 0.96 · 0.96 | 0.93 | 0.96 | – |
| node37 (18 checks) | 0.89 · 0.94 · 0.89 | – | – | – |
| **Passed (1.0)?** | **0 of 9** | **0 of 2** | **0 of 2** | **0 of 1** |
| Agent minutes (of 60) | 16-35 | 52 (node17) · 20 (node31) | 8 (node17) · 14 (node31) | 20 |
| Cost per trial | $0.38-1.59 | $3.49 · $1.30 | $0.85 · $0.82 | $5.46 |

- \* **Haiku, no stated time limit:** the same task with "You have 60 minutes." removed from the prompt; Harbor still stopped it at 60 min. n=1 per task.
- † **Sonnet:** n=1 per task, on an earlier verifier revision with fewer checks (node17 34, node31 25) and a slightly earlier prompt. Sonnet's node17 run had a 30-min budget.
- ‡ **Opus:** n=1, node17 only, same verifier as the submitted Haiku runs.
- Sonnet and Opus ran through the author's own OpenRouter key; Haiku through the take-home gateway.

## Table 2: the hard checks, run by run

✓ pass · ✗ fail · n/c = check not in that verifier revision · – = not run. Every other check is passed by essentially every run.

| Task | Check | Haiku k=3 | Haiku no-limit* | Sonnet† | Opus‡ | Who gets it |
|---|---|---|---|---|---|---|
| node17 | `slice_limits` (tenant memory slices) | 0/3 | ✗ | ✗ | ✗ | **nobody** |
| node17 | `db_role_limits` (Postgres per-role connection caps) | 0/3 | ✗ | n/c | ✗ | **nobody** |
| node17 | `postgres_isolation` (`REVOKE CONNECT`) | 0/3 | ✗ | ✓ | ✗ | Sonnet only |
| node17 | `cgi_identity` (CGI runs as tenant) | 0/3 | ✓ | ✗ | ✗ | no-limit Haiku only |
| node17 | `login_limits` (pam_limits) | 0/3 | ✓ | ✓ | ✗ | Sonnet, no-limit Haiku |
| node17 | `log_rotation` (`root:adm 0640`) | 0/3 | ✓ | ✓ | ✗ | Sonnet, no-limit Haiku |
| node17 | `postgis` | 3/3 | ✓ | ✗ | ✗ | Haiku only |
| node17 | `wsgi_identity` | 2/3 | ✓ | ✗ | ✓ | most |
| node17 | `sudo_decoy` (inactive grant left inactive) | 2/3 | ✓ | ✓ | ✓ | most |
| node31 | `operator_tools` (`promtool`, `htpasswd` on PATH) | 0/3 | ✓ | n/c | – | no-limit Haiku only |
| node31 | `amtool_operator` (`amtool` + client config) | 2/3 | ✗ | ✗ | – | some Haiku trials |
| node31 | `host_identity` | 3/3 | ✗ | ✓ | – | most (no-limit Haiku slipped) |
| node37 | `tool_env` (operator Python env) | 1/3 | – | – | – | one Haiku trial |
| node37 | `sleep_policy`, `udev_i2c`, `etc_environment` | 2/3 each | – | – | – | most Haiku trials |

## How to read it
- **No model passes any core task,** including the two stronger models and the longer-working Haiku variant.
- **Bigger models don't win on the hard checks.** Opus fails all 6 of node17's hardest checks; Sonnet gets 3. The no-limit Haiku, which simply kept working (52 min), gets 3 different ones. Each run solves a *different* subset.
- **Two checks no run of any model got:** `slice_limits` and `db_role_limits`. Both are visible only by querying the running system (systemd slice properties, `pg_roles`), not by reading config files.
- **node31 and node37 are near misses** (best 0.96 and 0.94), but every run still misses something, and the misses differ from run to run.
