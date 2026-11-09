## What to notice

1. Best of the three submitted node17 Haiku trials (0.83, 29/35), and the fastest: it stopped on its own at 15.7 of 60 minutes.
2. Reconnaissance is front-loaded: services, vhosts, pools, sudoers, DBs in the first ~3.5 min (steps 5-15); it writes the module at 04:01 (step 18).
3. Half the steps (34-63) are Monitor/"check build progress" polling while the first VM build substitutes ~300 paths. The horizon is spent waiting, not exploring.
4. Good catches: the `cobalt-deploy.disabled` sudo decoy (steps 10, 76), `(:adm)` runAs semantics, `/bin/cat` + `/usr/bin/python3` compat links, NixOS `ProtectHome` on PHP-FPM (step 98), MariaDB anonymous users.
5. It never typed `slice`, `limits.d`, `logrotate`, `statement_timeout`, `REVOKE` or `suexec` in any command. Every one of the 6 misses is a surface it never queried.
6. `cgi_identity`: its plan (step 16) chose `mod_cgid`; it checked that CGI *output* matched, not *which uid* ran it. Output parity hid an identity difference.
7. `db_role_limits` is a half-hit: it copied `CONNECTION LIMIT 20/40` (visible in `pg_roles`) but not the per-role `statement_timeout`, which lives in `pg_db_role_setting`.
8. Last reference query at ~12:53 (step 91, `/etc/hosts`); the final 3 minutes are candidate-only.
9. Parity claim at the end (step 104): "passes check-replica, builds, boots ... all services active" plus a list of what it verified. It verified what it built, not what it hadn't looked at. Classic stop-on-green (`07-evidence/proxy-vs-grader.md`).
10. Step 105 is Claude Code's autonomous-loop wakeup prompt (an injected "user" turn); the agent correctly ends. Not part of the task.
