# Gotchas: recipe departures from Ubuntu 22.04 defaults

Evidence: recipes in `author/tasks/<id>/cookbooks`, latest Haiku submissions (node17 `-120m-r3`, node23/31/37 `-60m`), Sonnet node31 `-or-60m-r2`, their `verifier/checks.json`. "Haiku" column: reproduced / missed / partial. "Verifier" = already asserted in `tests/verify.py`. Rows marked (?) are inferred from the submission text, not from a failing check. Existing candidates in `complexify.md` / `check-proposals.md` are not repeated.

## node17-reconstruction-hard (Apache, FPM, PostgreSQL, MariaDB)

| Deviation / Ubuntu reliance | Recipe source | Haiku | Verifier |
| --- | --- | --- | --- |
| Tenant homes 0755 (adduser/useradd on 22.04 gives 0750, NixOS 0700) | `default.rb:49-53` | reproduced (`homeMode = "755"`, replica:443) | `filesystem_ownership` |
| `REVOKE CONNECT ON DATABASE ... FROM PUBLIC` (Postgres default lets every role connect) | `default.rb:154` | missed | `postgres_isolation` (failed) |
| `user-.slice.d` MemoryHigh 80% / MemoryMax 90% (no Ubuntu default) | `default.rb:133-135` | missed | `slice_limits` (failed) |
| `limits.d/50-tenants.conf`, `logrotate.d/web` `su root adm`, `.disabled` sudoers | `complexify.rb:9-38` | all three missed/mis-copied | `login_limits`, `log_rotation`, `sudo_decoy` (all failed) |
| FPM `www` pool deleted, `clear_env`, `env[PATH]`, `open_basedir` | `default.rb:92`, `pool.erb` | reproduced | `server_tuning`, `php_*` |
| `a2dissite 000-default`, vhost order `amber cobalt node` | `default.rb:119` | reproduced (?) | only via `unmatched_host_default` proposal |
| memcached `-l 127.0.0.1 -U 0 -m 32` replaces Ubuntu's `-m 64` | `default.rb:122` | reproduced | `server_tuning`, `cache_protocol` |
| `pg_hba` replaced: no `host replication`, scram on loopback | `default.rb:125` | reproduced | `postgres_*` |

Gotchas:
- Per-database state set by `psql`/`mysql` in the recipe (`REVOKE`, grants) is invisible to anyone copying config trees; Haiku lost `postgres_isolation` on exactly this.
- Everything under `complexify.rb` was missed in the one Haiku run: pam_limits, logrotate `su root adm`, sudoers `.disabled`. All are Ubuntu mechanisms (`/etc/security/limits.d`, `/etc/logrotate.d`, `#includedir`) that NixOS expresses elsewhere.
- Ubuntu ships `skel` (`.profile`, `.bashrc`) and `cron` in the base image; nothing in the verifier looks at tenant login-shell environment.

Proposed complexifiers:

| CX id | Rationale | Recipe sketch | NixOS | Check | Why missed |
| --- | --- | --- | --- | --- | --- |
| CX-db-role-limits | Noisy-neighbour guard on the shared DBs | `ALTER ROLE amber CONNECTION LIMIT 20 / SET statement_timeout='30s'`; `ALTER USER 'amber'@'localhost' WITH MAX_USER_CONNECTIONS 20` (cobalt: 40) | postStart SQL / `initialScript`, `ensureUsers` | `SELECT rolconnlimit, rolconfig FROM pg_roles`; `SHOW GRANTS` / `mysql.global_priv` | State lives in the database, not in any file the agent would diff |
| CX-cron-allow | Only amber is a paying scheduler tenant; cobalt must not run background jobs | `/etc/cron.allow` containing `amber` | `services.cron.enable` + `environment.etc."cron.allow"` | `runuser -u cobalt -- crontab -l` is refused; amber gets "no crontab" | Cron is a base-image default on Ubuntu, absent on NixOS, and not in `packages.txt` |

## node23-reconstruction-hard (dnsdist -> pdns-recursor -> nsd)

| Deviation / Ubuntu reliance | Recipe source | Haiku | Verifier |
| --- | --- | --- | --- |
| `webserver=yes` on 127.0.0.1:8082 with api-key (NixOS `api.address/port` does not switch the webserver on) | `default.rb:175-179` | missed: nothing on 8082 | `listeners`, `monitoring_api` (failed) |
| `version-string=anonymous` (Ubuntu default reports the package version) | `default.rb:173` | missed | `recursor_version_string` (failed) |
| `sysctl.d/90-dns.conf` (rmem/wmem 8 MiB, port range 10240-65535) | `complexify.rb:22-25` | missed (kernel defaults 4194304 / 32768-60999) | `socket_tuning` (failed) |
| `LimitNOFILE=65536` drop-ins on both units | `complexify.rb:26-31` | recursor missed; dnsdist set 16384 | `socket_tuning` |
| `allow-from=127.0.0.0/8` (Ubuntu recursor default allows RFC1918) | `default.rb:155` | reproduced | `acl_inside` |
| `dont-query=127.0.0.0/8,!127.0.0.1` (default list blocks private ranges) | `default.rb:168` | not set (?) | none |
| `max-negative-ttl` 3600 -> 1800 drop-in; `.dpkg-old` inert | `complexify.rb:5-11` | reproduced, leftover ignored | `negative_ttl_override` |
| `/usr/bin/rec_control` path in sudoers, resolved stub off, resolv.conf | `default.rb:52,58-63` | reproduced (tmpfiles symlink) | `sudo_policy`, `local_resolver` |
| NSD `AXFR` refused, `identity`, `hide-version` | `default.rb:111-116` | reproduced | `nsd_identity_xfr` |

Gotchas:
- A NixOS module option that sets only the listen address silently leaves the Ubuntu feature off (webserver). Both failures in `listeners` and `monitoring_api` come from one missing line.
- systemd drop-ins and sysctl.d files added "after" the main recipe are the first things dropped under time pressure (0/2 socket-tuning items in full).
- `dont-query` is the one recursor default the verifier cannot see: a forward-zone to a private resolver address would behave differently.

Proposed complexifiers:

| CX id | Rationale | Recipe sketch | NixOS | Check | Why missed |
| --- | --- | --- | --- | --- | --- |
| CX-nsd-secondary | A secondary NS at 198.51.100.7 pulls the zone; everyone else stays refused | `provide-xfr: 198.51.100.7 NOKEY` and `notify: 198.51.100.7 NOKEY` in the `a23.test` zone block | `services.nsd.zones."a23.test".provideXFR/notify` | reuse `acl_inside` trick (`ip addr add` on lo, bind source): AXFR from .7 returns SOA..SOA, from 127.0.0.1 still REFUSED | Existing check only asserts refusal, so "refuse everything" passes; needs the paired allow |
| CX-resolv-options | Short resolver timeouts so a stuck local daemon fails over fast | `options timeout:1 attempts:2 ndots:2` in `/etc/resolv.conf` | `networking.resolvconf.extraOptions` | glibc view: `/etc/resolv.conf` effective `options` line (probe the reference; NixOS `resolvconf` may reorder) | Models copy `nameserver`/`search` and stop |

## node31-reconstruction-hard (Prometheus, Alertmanager, exporters, nginx)

| Deviation / Ubuntu reliance | Recipe source | Haiku / Sonnet | Verifier |
| --- | --- | --- | --- |
| `amtool` on PATH (Ubuntu package) + `/etc/amtool/config.yml` | `default.rb:58-64` | missed / missed (exit 127) | `amtool_operator` (failed both) |
| `promtool` on PATH (Ubuntu `/usr/bin/promtool`), `htpasswd` (apache2-utils) | `packages.txt` | not installed (?) / not installed (?) | none |
| Retention 730h (Ubuntu 15d), `--query.timeout=90s`, AM `--data.retention=730h` (120h), `--cluster.listen-address=` | `default.rb:127,174` | reproduced / reproduced | `prom_flags` |
| Textfile collector + inventory timer | `complexify.rb:21-43` | missed / reproduced | `textfile_timer` (Haiku failed) |
| `alert_relabel_configs` (labeldrop `replica`, `source=prometheus`), `external_labels site` | `prometheus.yml.erb:2-12` | reproduced | `alert_pipeline` (line 285) |
| `htpasswd` 0640 root:www-data; `alertmanager.yml` 0640 root:prometheus | `default.rb:169-170,264` | reproduced (Sonnet replica:123) | none (modes) |
| node-exporter `--collector.systemd --collector.processes --no-collector.timex` | `default.rb:179` | reproduced | `node_collectors` |

Gotchas:
- The `amtool` case generalises: Ubuntu packages put every CLI (`amtool`, `promtool`, `htpasswd`) on every user's PATH and the verifier only tests the one that was found by accident. The NixOS service modules add none of them.
- Sonnet (0.96) and Haiku (0.92) share the same miss, so it is a systematic blind spot, not noise.
- `alert_timing`, `notification_links` (in `check-proposals.md`) remain the larger unverified surface (`resolve_timeout 20m`, `externalURL`).

Proposed complexifiers:

| CX id | Rationale | Recipe sketch | NixOS | Check | Why missed |
| --- | --- | --- | --- | --- | --- |
| CX-icmp-probe | Reachability of the gateway-class hosts without TCP | blackbox module `icmp` (`prober: icmp`, ip4); `probe_icmp_main.yml` target 127.0.0.1; job `probe_icmp` in the ERB | exporter `configFile` + file_sd job; blackbox needs `CAP_NET_RAW` (Ubuntu's postinst sets file caps; probe `getcap` on the reference) | `/probe?module=icmp&target=127.0.0.1` has `probe_success 1`; series `probe_success{job="probe_icmp"}` exists | Needs a new module, a new job and a capability the Ubuntu package supplied implicitly |
| CX-prom-unit-limits | WAL replay is slow after 730h retention; keep Prometheus alive and un-killed | `prometheus.service.d/10-ops.conf`: `LimitNOFILE=131072`, `TimeoutStopSec=300`, `OOMScoreAdjust=-500` | `systemd.services.prometheus.serviceConfig` | `systemctl show prometheus -p LimitNOFILE -p TimeoutStopUSec -p OOMScoreAdjust` | Lives in a drop-in, not `/etc/default/prometheus`; same family as node23 socket-tuning (rank lower) |

## node37-reconstruction-hard (compute host: kernel, sleep, udev, services)

| Deviation / Ubuntu reliance | Recipe source | Haiku | Verifier |
| --- | --- | --- | --- |
| `/etc/hosts` is `127.0.0.1 localhost node37` only (NixOS adds `127.0.0.2 node37`) | `default.rb:72-74` | missed | none (`hosts_file` proposed) |
| `install algif_aead /bin/false` | `default.rb:97` | reproduced semantically (`${coreutils}/bin/false`) but failed | `module_policy` regex requires literal `/bin/false`; NixOS has no `/bin/false` |
| `60-i2c.rules` (`GROUP=i2c MODE=0660`) | `default.rb:303-305` | missed | `udev_i2c` (failed; reads `cat /etc/udev/rules.d/*.rules`) |
| sysstat `ENABLED="true"` (Ubuntu default false) | `default.rb:307` | reproduced via `services.sysstat` | `sysstat_timer` |
| Grub additions appended to cloud-image defaults; `crashkernel` | `default.rb:82-87` | reproduced (replica:127-132) | `kernel_cmdline` |
| Tools on default PATH (`accel-smi`, `lab-suspend`) via `/usr/local/bin`; Ubuntu includes it in PATH | `default.rb:140-143,211` | reproduced via `localBinInPath` + tmpfiles | `tool_env` |
| TZ America/Los_Angeles; logind `IdleAction=suspend` 4h; hibernate masked | `default.rb:75,116-123` | reproduced | `host_identity`, `sleep_policy` |
| Packages the Ubuntu cloud image ships (`byobu`, `htop`, `lsof`, `strace`, `ethtool`, `pciutils`) | not in recipe | Haiku added a broad set | none |

Gotchas:
- The `install ... /bin/false` rule is a verifier-side brittleness: the replica is functionally correct (the load is refused) yet fails. Accept any `install algif_aead <path-to-false>` or test `modprobe -n -v` exit semantics.
- `udev_i2c` greps files under `/etc/udev/rules.d`; a correct NixOS rule lives in the store. Use `udevadm verify`/`udevadm test` (already noted in `check-proposals.md`).
- Raw Ubuntu behaviours (`/etc/hosts`, `cron`, `rsyslog`, `irqbalance`) are reproduced only by Haiku's generosity; nothing grades them.

Proposed complexifiers:

| CX id | Rationale | Recipe sketch | NixOS | Check | Why missed |
| --- | --- | --- | --- | --- | --- |
| CX-etc-environment | Fleet-wide device selection for every session, including non-interactive ssh | `/etc/environment`: `ACCEL_VISIBLE_DEVICES=0,1`, `OMP_NUM_THREADS=8` (Ubuntu applies it through `pam_env` for all sessions) | `environment.sessionVariables` (pam_env); `environment.variables` only reaches interactive shells | `ssh node37 'printenv ACCEL_VISIBLE_DEVICES OMP_NUM_THREADS'` and `runuser -l ember -c printenv` | `/etc/environment` is not read on NixOS; the obvious `environment.variables` fails the non-interactive case |
| CX-accel-limits | GPU/RDMA workloads need pinned memory and many descriptors | `limits.d/90-accel.conf`: `@accel - memlock unlimited`, `@accel - nofile 1048576` | `security.pam.loginLimits` | `runuser -l ember -c 'ulimit -l; ulimit -n'`; a non-member sees defaults | Same pattern as node17 `login_limits`, which Haiku missed; ember's `accel` membership is the hint |

## Overall ranking

1. node31 CX-icmp-probe (new module + job + capability; models finish node31 in ~12 min and miss `amtool` already).
2. node37 CX-etc-environment (a pure Ubuntu mechanism that NixOS silently ignores; one `printenv` check).
3. node23 CX-nsd-secondary (turns a deny-only check into a paired allow/deny; reuses `acl_inside` machinery).
4. node17 CX-db-role-limits (database-resident state, so config copying cannot find it).
Before adding any of these: add `amtool`/`promtool`/`htpasswd` PATH checks and fix the `module_policy` literal, since those already cost points.
