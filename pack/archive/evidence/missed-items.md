Items model agents missed in at least one graded run (Haiku: 7 runs incl. node31 ablations; Sonnet 5.5: node17 and node31 only). Last column: Haiku passes in the final k=3 runs (node17: v1 trials re-graded with v2; node23 is bonus), from `report-figures/check-results-haiku.csv`.

| Task | Item | Why it's fair to probe | Failure mode | Minimal discovery step | Ever missed (Haiku) | Ever missed (Sonnet) | Check | Final k=3 Haiku passes |
|---|---|---|---|---|---|---|---|---|
| node17 | Tenant sudo log read (`/bin/cat` rule) | Tenants read own web logs via `sudo -g adm /bin/cat`; path is what users type. Rule must keep that literal path | Ubuntu default NixOS lacks | `sudo -l -U amber` | Y | N | `sudo_log_policy` | 0/3 |
| node17 | CGI runs as tenant | Tenant scripts must act as the tenant (suexec on Ubuntu); file ownership and isolation depend on it | Ubuntu package default, NixOS service omits it | `apachectl -M \| grep -E 'suexec\|cgid'`; request a `whoami`-style CGI | Y | Y | `cgi_identity` | 0/3 |
| node17 | WSGI runs as tenant | Tenant apps must run as the tenant; recipe sets `WSGIDaemonProcess user=` per vhost | Ubuntu package default, NixOS service omits it | `grep -r WSGIDaemonProcess /etc/apache2`; `ps -o user,cmd -C apache2` | N | Y | `wsgi_identity` | 1/3 |
| node17 | Tenant DB isolation (`REVOKE CONNECT`) | Tenants share one Postgres; cross-tenant connect is a data leak. Deliberate recipe step | stored in database | `psql -c '\l'` (database ACLs) | Y | N | `postgres_isolation` | 0/3 |
| node17 | PostGIS in tenant DBs | Tenant apps call `ST_*`; extension created in each tenant DB by recipe | stored in database | `psql -d amber -c '\dx'` | N | Y | `postgis` | 2/3 |
| node17 | Inactive cobalt sudoers decoy | Staged grant must stay inactive; copying it as live grants unapproved root restart | decoy (inactive) | `ls -la /etc/sudoers.d` (dotted `*.disabled` is skipped by `#includedir`) | Y | N | `sudo_decoy` | 1/3 |
| node17 | Tenant slice memory limits | Noisy-neighbour guard for all logins; deliberate drop-in with no Ubuntu default | Ubuntu mechanism NixOS expresses elsewhere | `systemctl show user-1101.slice -p MemoryHigh -p MemoryMax` | Y | Y | `slice_limits` | 0/3 |
| node17 | Tenant login limits (pam_limits) | Fork-bomb/descriptor guard on tenant sessions | Ubuntu mechanism NixOS expresses elsewhere | `ls /etc/security/limits.d`; `runuser -l amber -c 'ulimit -n -u'` | Y | N | `login_limits` | 0/3 |
| node17 | Log rotation keeps `root:adm 0640` | Sudo log access must survive rotation; deliberate `su root adm` | Ubuntu mechanism NixOS expresses elsewhere | `cat /etc/logrotate.d/*`; `systemctl cat logrotate` | Y | N | `log_rotation` | 0/3 |
| node23 | Recursor web API on 127.0.0.1:8082 | Operators/monitoring query recursor stats; recipe turns it on with API key | Nix module default differs | `ss -ltnp` | Y | — | `monitoring_api` | 2/3 |
| node23 | Recursor `version-string=anonymous` | Hides software version from clients; deliberate recipe line | Nix module default differs | `dig +short chaos txt version.bind @127.0.0.1 -p 5353` | Y | — | `recursor_version_string` | 3/3 |
| node23 | Socket tuning (sysctl, `LimitNOFILE`) | Resolver under load needs larger UDP buffers/ports/fds; deliberate files | Ubuntu mechanism NixOS expresses elsewhere | `sysctl net.core.rmem_max net.ipv4.ip_local_port_range`; `systemctl show pdns-recursor -p LimitNOFILE` | Y | — | `socket_tuning` | 1/3 |
| node31 | `amtool` + client config | Needed by operators to see/mute alerts. On all users' PATH; client config set by recipe | Ubuntu package default, NixOS service omits it | `apt-mark showmanual` → `dpkg -L prometheus-alertmanager`; `runuser -u reed -- amtool alert query` | Y | Y | `amtool_operator` | 2/3 |
| node31 | Inventory textfile timer | Feeds node_exporter textfile metrics on a schedule; deliberate unit pair | runtime only | `systemctl list-timers`; `ls /var/lib/prometheus/node-exporter` | Y | N | `textfile_timer` | 3/3 |
| node37 | i2c udev rule | `ember` is in group `i2c` and needs device access; deliberate rule | Ubuntu mechanism NixOS expresses elsewhere | `ls /etc/udev/rules.d`; `udevadm test /sys/class/i2c-dev/i2c-0` | Y | — | `udev_i2c` | 2/3 |
| node17 | PHP runs as the tenant | Tenant PHP must act as the tenant (per-tenant FPM pool user); ownership and isolation depend on it | Ubuntu package default, NixOS service omits it | `ls /etc/php/*/fpm/pool.d`; `ps -o user,cmd -C php-fpm8.1` | Y | – | `php_identity` | 0/3 |
| node17 | Per-tenant PHP limits | Tenants get different upload/memory/time limits; deliberate pool settings | Ubuntu mechanism NixOS expresses elsewhere | `grep -r php_admin_value /etc/php/*/fpm/pool.d` | Y | – | `php_pool_limits` | 0/3 |
| node17 | Per-tenant DB connection limits | Noisy-neighbour guard in Postgres; set by the recipe in the catalog | stored in database | `psql -c "SELECT rolname,rolconnlimit FROM pg_roles"` | Y | – | `db_role_limits` | 0/3 |
| node31 | Operator CLIs (`promtool`, `htpasswd`) | Operators validate rules and manage web auth from their login shell; packages put them on PATH on Ubuntu | Ubuntu package default, NixOS service omits it | `apt-mark showmanual`; `runuser -l reed -c 'command -v promtool htpasswd'` | Y | N | `operator_tools` | 0/3 |
| node37 | Operator Python tool environment | The operator's project env (`pyproject.toml` deps) is what they run daily | Ubuntu default NixOS lacks | `cat /home/ember/accel-env/pyproject.toml` | Y | – | `tool_env` | 1/3 |
| node37 | `/etc/environment` variables | Device/thread variables must reach ssh and login sessions (pam_env only) | Ubuntu mechanism NixOS expresses elsewhere | `cat /etc/environment`; `ssh … printenv` | Y | – | `etc_environment` | 2/3 |
| node37 | Sleep policy (masked targets) | Hibernate masked, suspend allowed: the box must not hibernate | Ubuntu mechanism NixOS expresses elsewhere | `systemctl is-enabled hibernate.target suspend.target` | Y | – | `sleep_policy` | 2/3 |

Failure modes: "Ubuntu package default, NixOS service omits it" = package ships a CLI/module/setting the NixOS service module does not; "Ubuntu default NixOS lacks" = path or file Ubuntu has (e.g. `/bin/cat`) that NixOS does not.
"Ubuntu mechanism NixOS expresses elsewhere" = limits.d, logrotate.d, sysctl.d, drop-ins, udev rules; "Nix module default differs" = NixOS option leaves the feature off or different; "stored in database" / "decoy (inactive)" / "runtime only" = not visible in a config-tree diff.

Verifier bugs (ours, fixed)

| Task | Item | What was wrong | Runs affected |
|---|---|---|---|
| node17 | Build parity (root vs build users) | Solving image built as root, so read-only `/etc` store link passed locally but failed in verifier | node17-haiku-120m-r2 (reward 0, not a result) |
| node37 | `module_policy` | Required literal `/bin/false`; NixOS has none | node37-haiku-60m (0.875, re-graded 0.941) |
| node37 | `udev_i2c` | Read only `/etc/udev/rules.d`, one exact rule line | None observed (Haiku had no rule) |
| node23 | `listeners` | One `ss` row per (proto, port); `[::1]` row could overwrite `127.0.0.1` | None observed (Haiku failure was the missing 8082) |
| node23 | `sudo_policy` | Denial used `/usr/bin/id`, absent on NixOS, so fail-open | None observed (too permissive) |
| node31 | `listeners` | Same overwrite as node23 | None observed |
| node31 | `textfile_timer` | Required timer name `node31-inventory` | None observed (Haiku failed on metrics) |
