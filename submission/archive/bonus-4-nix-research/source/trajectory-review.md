# Trajectory review (notes for the author; not report text)

Sources: final/jobs/*-haiku-k3 (trajectory.json, verifier/checks.json, artifacts submissions), oracle replica.nix under node*/solution/submission/, author/missed-items.md. No keys copied. "Pass" = 1.0.

## 1. What the brief wants from trajectories
- Headroom = pass@3 = 0 on the model under test; evidence is the 3 trials, so each failure must be examined.
- "Examine each trajectory": every failure must be real difficulty (logic error, wrong interpretation, failed tool call), not reward hacking, a wrong verifier, or an underspecified instruction.
- Report must quote failure modes from trajectories, with the process shown (what the agent did, where it went wrong).
- Oracle = 1, nop = 0 per retained task; submit exactly the Harbor-written trials.

## 2. Per-trial summary (agent minutes from trial-stats; budget 60)
Verifier wall time per trial: about 350 s build + 100 s boot.

| trial | score | recipe | compl. | min | LLM calls | $ | stop | top misses |
|---|---|---|---|---|---|---|---|---|
| node17 6WDtNr9 | 0.71 | 25/31 | 0/4 | 19.7 | 90 | 0.81 | confident claim | sudo /bin/cat, slice limits, PG isolation, php 500, cgi as www-data, all 4 complexifiers |
| node17 aVqPFzU | 0.66 | 22/31 | 1/4 | 34.9 | 75 | 1.08 | confident claim | same as above + Apache unreachable mid-grade (see 4) |
| node17 msYkvbq | 0.51 | 18/31 | 0/4 | 25.6 | 79 | 0.84 | self-stopped, said "past 60 min" (false: 25.6) | CGI/PHP/WSGI all broken, PostGIS, plus the rest |
| node23 TqaXCM9 | 0.77 | 18/22 | 2/4 | 30.8 | 73 | 0.41 | claim | 8082 API, listeners, host_identity, sudo_policy, resolver, socket_tuning |
| node23 cfv4yw4 | 0.96 | 22/22 | 3/4 | 12.1 | 61 | 0.52 | claim | socket_tuning |
| node23 tBuX9Qx | 1.00 | 22/22 | 4/4 | 15.2 | 69 | 0.55 | claim | none |
| node31 CXEA5DJ | 0.93 | 21/23 | 4/4 | 17.5 | 55 | 0.42 | claim | amtool_operator, operator_tools |
| node31 W39ZEQ8 | 0.96 | 22/23 | 4/4 | 19.7 | 84 | 0.73 | claim | operator_tools (htpasswd) |
| node31 cPwkSHL | n/a | | | | | | incomplete | no trajectory, no checks.json: exclude |

Oracle 1.0 and nop 0.0 confirmed in result.json for node17, node23, node31. No trial hit the timeout; all stopped by themselves, by 12-35 min, with a large unused budget.

## 3. Cross-trial patterns
- Every agent stops on a confident claim well inside budget. Final messages describe a verified replica while key properties were never compared (see 5).
- All agents inspect users, listeners, vhost/config trees and units; hardly any read apt history (only node23 TqaXCM9 touched history.log) or enumerate limits.d/logrotate.d/sysctl.d.
- Complexifiers (hidden in drop-ins and runtime state) are the least discovered: node17 0/4, 1/4, 0/4 vs node31 4/4 twice.
- High vs low scorers (node17): the best had the most passing basics (PHP/CGI/WSGI identity working); msYkvbq spent its run fighting mod_wsgi/proxy_fcgi and never reached tenant-limit items. Cheap wins are checked by a boot-test plus a curl probe; high scorers ran more check-replica/boot cycles (node23 tBuX9Qx: 6 boots; cfv4yw4 0 boots but 9 check-replica).
- node23 vs node17: node23 is a small single-daemon surface (pdns recursor, 22 recipe checks); every item is visible in `ss`, `sysctl`, `systemctl show` and a Haiku-sized loop finds them, so 1.0 is reachable. node17 couples 8 subsystems (Apache with per-tenant PHP-FPM/CGI/WSGI, MariaDB, PG, sudo, limits), where NixOS lacks suexec and PHP 8.1, forcing real redesign (fcgiwrap per tenant, PG 17), and 35 checks mean small misses accumulate. node31 sits in between (0.93, 0.96): solvable, two Ubuntu-default tools miss.
- Failure-type split (from oracle diffs):
  - Never discovered: node17 limits.d / slice / logrotate / db role limits (no trajectory contains `limits.d`, `logrotate`, `MemoryHigh`, `ulimit`); node23 8082 API in TqaXCM9 saw `webserver` but did not enable it.
  - Discovered but implemented wrong: node17 6WDtNr9 saw the sudo `/bin/cat` rule but wrote `/run/current-system/sw/bin/cat` (oracle keeps `/bin/cat` via a tmpfiles symlink, replica.nix:127-133); cobalt decoy mistranslated (rule appears live in checks.json); CGI as www-data (suexec absent, no replacement); PG isolation: all three ran `\l` (steps 8-10) but none added `REVOKE CONNECT` (oracle:86).
  - Nix-specific: msYkvbq mod_wsgi socket permission and proxy_fcgi SCRIPT_FILENAME; node17 PHP 500 (6WDtNr9).

### Process gaps ("never thought to run X")
| miss | inspection/self-test that catches it | did the agent run anything like it? |
|---|---|---|
| node17 slice_limits, login_limits, log_rotation, db_role_limits | `ls /etc/security/limits.d /etc/logrotate.d`; `systemctl show user-1101.slice -p MemoryHigh`; `runuser -l amber -c 'ulimit -n -u'`; `\du+` connlimits | No. Zero matches for limits.d/logrotate/ulimit/MemoryHigh in all 3 node17 trials. Only aVqPFzU/msYkvbq grepped CONNECTION LIMIT (PG roles, `ulimit` never) |
| node17 sudo_log_policy | `sudo -l -U amber` on ref, then same on the booted replica | 6WDtNr9 ran `sudo -l` on ref (step 14) and replica (step 76 test) but did not diff the path text. msYkvbq never ran `sudo -l` (0 hits). Ran-but-wrong |
| node17 postgres_isolation | `psql -c '\l'` on ref plus cross-connect test on replica | Ran `\l` on ref (step 10 / 8), never tested a cross-tenant connect on the replica. Ran-but-wrong |
| node17 cgi_identity | request a whoami CGI on ref and replica | 6WDtNr9 did probe CGI on replica (output www-data) and still claimed parity; aVqPFzU built fcgiwrap (passed). Ran, saw, claimed anyway |
| node23 socket_tuning (all three) | `sysctl net.core.rmem_max net.ipv4.ip_local_port_range`; `systemctl show pdns-recursor -p LimitNOFILE` | TqaXCM9: one sysctl hit; cfv4yw4: zero sysctl; tBuX9Qx: 5 sysctl hits and passed. Also none ran `systemctl list-timers` on node23 |
| node23 listeners/8082/monitoring_api | `ss -ltnp` on ref and replica, diff | All ran `ss`; TqaXCM9 saw the API in config but did not enable the NixOS option (oracle replica.nix:92,116). Ran-but-wrong |
| node31 amtool_operator | `runuser -u reed -- amtool alert query` on replica | Neither failing trial ran it as the operator. CXEA5DJ installed the package and symlinked /usr/bin/amtool but wrote no /etc/amtool/config.yml (oracle replica.nix:178). Missing self-test |
| node31 operator_tools (htpasswd) | `apt-mark showmanual` / `dpkg -L apache2-utils`, `command -v htpasswd` as reed | Both mentioned htpasswd (3 hits) but only as the nginx password file; neither installed it (oracle: pkgs.apacheHttpd in systemPackages, :180). CXEA5DJ: no apt-mark or dpkg -L at all; W39ZEQ8 1 hit |

Distinction: first two rows and node23 sysctl are pure process gaps (no related command anywhere); the rest are ran-and-saw-but-implemented-wrong or claimed without a replica-side comparison.

## 4. Are the failures fair?
- Mostly yes: each item is discoverable by the minimal step in author/missed-items.md, and Haiku passed each in at least one trial elsewhere (tBuX9Qx 22/22+4/4; node31 4/4).
- Flag for you: node17 aVqPFzU lost tls_aliases, http_redirects, userdir_redirect, static_range, php_identity and sudo_log_policy to `SSL_ERROR_SYSCALL` / connection reset at 0.01 s, then php_environment..proxy_header passed. candidate.log shows "Starting Apache HTTPD" with no matching "Started" line, i.e. Apache was down or restarting early in grading. verify.py:96-103 only waits for `multi-user.target`, so a late-starting service race is possible. The agent's own boots worked and its replica uses `services.httpd` with `user = root`. Check whether Apache comes up after multi-user.target (a Type or ordering issue in the agent's module is fair; a verifier race is not). If it is a race, this trial's 0.66 is understated and the retry/ready logic should wait on HTTP.
- msYkvbq's `php_*` checks returned 404 "File not found." and 503 for CGI: check that the probe-file install (verify.py:90-93) wrote to the path the agent's docroot mapping expects; the agent's own PHP also 404'd ("Primary script unknown"), so it looks like agent error.
- socket_tuning fails with [4194304, 4194304, 32768, 60999] vs expected: confirm the expected values appear in instruction.md or are discoverable (two of three trials missed it).
- Instruction ambiguity: msYkvbq believed budget was exhausted at 25 min; consider whether the prompt's time wording misleads.

## 5. Quotes worth citing
- node17 6WDtNr9: "matches the reference on every probe I ran" while sudo_log_policy, php_identity and cgi_identity failed.
- node17 aVqPFzU: "I ran the same probes against the reference and the replica, and the results match except for the differences listed" (0.66).
- node17 msYkvbq: "the work is not finished ... I'm past the 60-minute budget" (actual 25.6 min); honest about CGI/PHP failing.
- node31 CXEA5DJ: "Guest state: ... unit names and states ... all match" yet amtool unusable for reed.
- node17 6WDtNr9 omissions: "Not reproduced (judged OS-level or inactive): ... cron jobs, /etc/cinc" (agent dismissed items without checking them).

## 6. Integrity
- No tampering: regex over all 8 trajectories for /logs, /tests, verifier, reward.txt returns no hits in commands or edits. Agents used only /opt/contract, /opt/runtime and /app/submission.
- No daemon stubbing seen. Closest: msYkvbq's CGI gateway wsgi and aVqPFzU's fcgiwrap are genuine replacements for missing suexec; 6WDtNr9 symlinked /usr/bin/python3, /usr/bin/perl, /bin/bash (legit shebang compat). node31 CXEA5DJ wrote its own alert sink instead of copying (disclosed).
- Copying reference password hashes into the module (node17 all trials) is disclosed; instruction says recreate credentials, so check whether verifier intends to allow it.
- Oracle 1.0 and nop 0.0 in all three tasks.

## 7. Open questions
- Resolve the aVqPFzU Apache race (section 4) before claiming node17's lowest score is clean; consider a ready probe in verify.py.
- node31 cPwkSHL is incomplete; node31 is not a headroom task (0.93, 0.96), so decide whether to submit it at all.
- node17 pass@3 = 0 holds (best 0.71) but no trial is near 1.0 for reasons mixing real difficulty and the above race.
- Cost tables: node17 trials cost $0.81-1.08, others $0.41-0.73.
- Dig further if you want exact diffs for node23 TqaXCM9 host_identity/sudo_policy/local_resolver (not compared against oracle here beyond rec_control paths).
