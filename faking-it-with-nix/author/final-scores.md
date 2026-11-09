# Final-run scoring ledger

Every score from the submission runs, including superseded ones. pass = reward 1.0; headroom = pass@3 = 0.
Brief's command: `harbor run -p <task> -a claude-code -m claude-haiku-5-5 --ak reasoning_effort=high -k 3`.

## Submitted runs (final/jobs)

| Task | Set | Verifier | Oracle | Nop | Haiku k=3 | pass@3 |
|---|---|---|---|---|---|---|
| node17 | samples | v2 (settle wait) | 1.0 | 0.0 | 0.60, 0.77, 0.83 | 0 |
| node23 | solved/ | v1 | 1.0 | 0.0 | 0.77, 0.96, 1.0 | 1 (solved) |
| node31 | samples | v1 | 1.0 | 0.0 | 0.93, 0.96, 0.96 | 0 |
| node37 | samples | v1 | 1.0 | 0.0 | 0.89, 0.94, 0.89 | 0 |

## Superseded: node17 v1 (unsettled boot) — final/superseded/node17-v1-boot-race

v1 `Guest.ready()` returned as soon as `multi-user.target` was active, so checks could run while boot
jobs were still in flight. Fix (v2): also wait until `systemctl list-jobs` is empty. node23/node31
already waited for their service; node37 uses `is-system-running --wait`; only node17 was affected.

Suspected first as a race that *understated* scores (trajectory review: trial aVqPFzU failed 7 web checks
at 0.8-3.3 s, passed every web check from 3.6 s). The v2 re-grade showed the opposite: v1 *overstated*
that trial. The agent's own httpd.conf sets `PidFile /run/apache2/apache2.pid`, while the NixOS
`services.httpd` unit (Type=forking) waits for its own PID file, so the unit never reaches "Started"
(console shows only "Starting Apache HTTPD") and systemd kills Apache at the start timeout. v1 probed
inside that window and credited a web server that does not survive boot; v2 waits for the job to end and
every web check fails. A lenient-verifier bug, found by re-grading, not a flaky one.

| Trial | v1 score (as run) | v2 re-grade of same submission | Change |
|---|---|---|---|
| 6WDtNr9 | 0.71 | 0.71 | none |
| aVqPFzU | 0.66 | 0.43 | -8 checks: php_environment, php_open_basedir, php_pool_limits, php_postgres, php_mysql, cgi_identity, wsgi_identity, proxy_header |
| msYkvbq | 0.51 | 0.51 | none |
| oracle | 1.0 | (re-run in final/jobs) | |
| nop | 0.0 | (re-run in final/jobs) | |

Re-grades: final/regrade-v2/<trial>/ (author/regrade.sh: same submission, v2 verifier and builder
images by digest). The v2 reference check passed every check. v1 pass@3 was 0 and stays 0.

## Side runs (development jobs/, not submitted)

| Run | Model / harness | Route | Verifier | Score | Note |
|---|---|---|---|---|---|
| node17-sol61-or-60m | gpt-6.1-sol / claude-code | OpenRouter | v1 | n/a | OpenRouter Anthropic endpoint returned non-Message replies; stopped after 2 turns |
| node17-sol61-codex-60m | gpt-6.1-sol / codex | OpenRouter | v1 | n/a | upstream rate limit after 3 min |
| node17-sol61-codex-r2 | gpt-6.1-sol / codex | OpenRouter | v1 | n/a | upstream rate limit after 4 min |
| node17-opus55-or-60m | claude-opus-5.5 / claude-code | OpenRouter only (env verified in container) | v1 | 0.40 (invalid) | OpenRouter credits exhausted ~20 min in (HTTP 402), then idled to AgentTimeoutError |

## Ablation and side runs after the final runs (development jobs/, n=1 each)

| Run | What changed | Score | Agent min | LLM calls | Missed | Note |
|---|---|---|---|---|---|---|
| node17-haiku-no-clock-60m | "You have 60 minutes." removed (Harbor still stops at 60) | 0.91 | 52.2 | 179 | slice_limits, postgres_isolation, db_role_limits | vs timed v2 trials 0.60-0.83 at 16-30 min, 87-105 calls |
| node31-haiku-no-clock-60m | same | 0.93 | 19.8 | 101 | host_identity, amtool_operator | vs timed 0.93-0.96 at 17-35 min: no change |
| node17-opus55-or-60m-v2 | Opus 5.5 via OpenRouter (own key), verifier v2 | 0.80 | 19.5 | 71 | slice_limits, postgres_isolation, postgis, cgi_identity, login_limits, log_rotation, db_role_limits | stops early like Haiku; $5.46 |

Neither no-clock run reached 1.0 and no task's pass@3 changes. On node17 the stated budget appears to shorten work (n=1).
