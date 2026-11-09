# Verifier fixes (2026-11-03 audit)

Audit of the four `tests/verify.py` for checks that test implementation instead of behavior, or that pass on a wrong or empty replica. Deliberate contract items are kept: `/bin/cat` in node17's sudo rule, `/usr/bin/python3` CGI shebangs, `/usr/bin/rec_control` in node23's sudoers, `/etc/default/infer-server` and `/home/ember/accel-env` in node37 (paths operators use), custom unit names (`accel-sleep-cleanup`, `idle-check`, `infer-server`, `metrics-agent`).

| Task | Check | Assumption | Fix | Could a correct replica have failed before? |
| --- | --- | --- | --- | --- |
| node37 | `module_policy` (earlier fix) | required literal `/bin/false`; NixOS has no `/bin/false` | regex accepts any `*/false` | yes |
| node37 | `udev_i2c` | `cat /etc/udev/rules.d/*.rules` and one exact rule line (`KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"`, that key order) | read the files `udevadm test` reports loading; accept any rule for the i2c nodes (`KERNEL=="i2c-*"` or `SUBSYSTEM=="i2c-dev"`) with `GROUP="i2c"` and `MODE="0660"`/`"660"`, backslash continuations joined | yes (other key order, other rule directory, other split) |
| node23 | `listeners` | `ss` rows keyed by (proto, port): a second listener on the same port (`[::1]` beside `127.0.0.1`) overwrote the first, so the verdict depended on row order | collect all sockets per (proto, port); loopback services must include 127.0.0.1 and bind only loopback addresses; public services must have a non-loopback address | yes (extra `[::1]` listener) |
| node23 | `sudo_policy` | the denial used `sudo -n /usr/bin/id`; NixOS has no `/usr/bin/id`, so a replica granting birch `ALL` also "failed" the command and passed the denial (fail-open) | denial runs `/bin/sh -c true`, which exists on both systems; the allowed `rec_control` calls still pair it | no (it was too permissive, not too strict) |
| node31 | `listeners` | same overwrite as node23: one address per port in a dict | sets per port, same rule as node23 | yes |
| node31 | `textfile_timer` | `systemctl list-timers` had to contain the string `node31-inventory` (the reference's unit name) | any `.timer` unit whose `TimersMonotonic` is `OnBootUSec=5s` plus `OnUnitActiveUSec=1min`; the metric files and scraped series stay the contract | yes (a differently named timer) |
| node17 | all checks | no brittle path, ordering or fail-open found | none | n/a |
| node37 | other checks | `*USec` names, `is-enabled` states (`static`/`linked` already accepted), `sudo -l` shape (regex already tolerant) reviewed | none | n/a |

New checks added in the same pass: `operator_tools` (node31), `db_role_limits` (node17), `nsd_secondary` (node23), `icmp_probe` (node31), `etc_environment` (node37); see `complexify.md`.

Existing lint findings that are not from this audit (`F821` for names defined by `exec(DNS_LIB)`, `E741`, `RUF015`, `UP017`, `E731`, `UP031`) were left alone.
