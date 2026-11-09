# Complexifiers

Realistic changes to the reference recipe that a cursory agent misses. Each one:

- is something an operator of a shared web and database host plausibly does, for a stated reason;
- can be found by inspecting the running reference;
- is expressible in NixOS;
- has a quick check that reads effective state (see `methods.md`).

The traps are precedence, inert decoys, settings outside the obvious config tree, and settings that interact. A complexifier earns its place when copying the obvious file gives the wrong answer.

Adding one: change the recipe, `mise run prepare <task>`, add the oracle change and the check, then run the three controls. It must not break the harness (root key SSH, ports 22/80/443). It must also fall within the task's published graded surfaces (`public/README.md`). Extend that list in plain words when needed, without hints.

## Marking origin

Every complexifier has an ID `CX-<name>` and lives apart from the original recipe at each layer:

| Layer | Original | Complexifiers |
| --- | --- | --- |
| Reference recipe | `cookbooks/node/recipes/default.rb` | `cookbooks/node/recipes/complexify.rb` (run after `default`) |
| Oracle | `solution/submission/replica.nix` | `solution/submission/complexify.nix` (imported) |
| Verifier | `RECIPE_CHECKS` | `COMPLEXIFIER_CHECKS`; `checks.json` tags each result `origin` |

## Status

| ID | Status | Check |
| --- | --- | --- |
| CX-sudo-decoy | added 2026-11-03 | `sudo_decoy` |
| CX-login-limits | added 2026-11-03 | `login_limits` |
| CX-log-rotation | added 2026-11-03 | `log_rotation` |
| CX-db-role-limits | added 2026-11-03 | `db_role_limits` |
| CX-nsd-secondary | added 2026-11-03 | `nsd_secondary` |
| CX-icmp-probe | added 2026-11-03 | `icmp_probe` |
| CX-etc-environment | added 2026-11-03 | `etc_environment` |
| CX-auth-after-tls | drafted (node29-reconstruction-hard) | `auth_after_tls` |
| CX-submission-sender-match | drafted (node29-reconstruction-hard) | `sender_match` |
| CX-conf-d-decoy | drafted (node29-reconstruction-hard) | `conf_d_decoy` |
| CX-negative-ttl-override | drafted (node23-reconstruction-hard) | `negative_ttl_override` |
| CX-local-resolver | drafted (node23-reconstruction-hard) | `local_resolver` |
| CX-socket-tuning | drafted (node23-reconstruction-hard) | `socket_tuning` |
| CX-rules-glob | drafted (node31-reconstruction-hard) | `rules_glob` |
| CX-sd-drop | drafted (node31-reconstruction-hard) | `sd_drop` |
| CX-textfile-timer | drafted (node31-reconstruction-hard) | `textfile_timer` |
| CX-fpm-decoy | reserved: reads as a planted trap rather than a natural leftover | — |

Everything else below is a candidate.

## Precedence traps

| Complexifier | Why on this server | Find it on the reference | Nix | Check |
| --- | --- | --- | --- | --- |
| `sshd_config.d/00-node.conf` sets `PasswordAuthentication no`, `MaxAuthTries 3`, and `Match User amber,cobalt` with `AllowTcpForwarding no`, `X11Forwarding no`; cloud-init's `50-cloud-init.conf` still says `PasswordAuthentication yes` | Hardening on a cloud image whose vendor file enables passwords; tenants must not tunnel to the loopback-only databases | `sshd -T`, `sshd -T -C user=amber,host=x,addr=127.0.0.1`. OpenSSH takes the **first** value, so `00-` wins; reading the files last-wins gets it backwards | `services.openssh.settings`, `extraConfig` for `Match` | `sshd -T` and `-C user=amber` values |
| `sysctl.d/10-node.conf` sets `vm.swappiness=1` and `net.core.somaxconn=1024`; a later `60-node-late.conf` resets swappiness to `10` | Database host tuning, revised later by a second change | `/proc/sys/vm/swappiness` (lexically last file wins) | `boot.kernel.sysctl` | `/proc/sys` values |
| pam_limits: `limits.d/50-tenants.conf` `@tenants hard nproc 200`, `nofile 4096`; FPM pools set `rlimit_files = 1024` | Fork-bomb guard for logins, complementing the memory slice | `runuser -l amber -c 'ulimit -Hu; ulimit -Hn'`. PAM limits don't apply to FPM workers, which take `rlimit_files` from the pool; copying only one source misses the other | `security.pam.loginLimits`; pool `rlimit_files` | `runuser -l` ulimits; `/proc/<fpm worker>/limits` |

## Inert decoys

| Complexifier | Why on this server | Find it on the reference | Nix | Check |
| --- | --- | --- | --- | --- |
| `/etc/sudoers.d/cobalt-deploy.disabled` grants cobalt `systemctl restart apache2` | A grant staged for approval. sudo's `#includedir` skips files containing `.`, so it is inactive | `sudo -l -U cobalt` (ask sudo, not the directory) | Nothing; copying it is the bug | `sudo -l -U cobalt` lists only the log commands |
| `sites-available/legacy.conf` vhost for `legacy.node.test`, not in `sites-enabled` | Decommissioned tenant kept for rollback | `apache2ctl -S` lists live vhosts | Nothing | `legacy.node.test` gets the default vhost's page, not legacy content |
| A `php8.1-fpm/pool.d/staging.conf.dpkg-old` pool | Leftover from a package upgrade; FPM only includes `*.conf` | `php-fpm -tt` pool list | Nothing | `server_tuning` already asserts exactly two pools |

## Outside the obvious config tree

| Complexifier | Why on this server | Find it on the reference | Nix | Check |
| --- | --- | --- | --- | --- |
| `transparent_hugepage=never` in `/etc/default/grub.d/50-node.cfg` | Standard PostgreSQL/MariaDB latency advice | `/proc/cmdline`, `/sys/kernel/mm/transparent_hugepage/enabled` | `boot.kernelParams` (or a tmpfiles `w` on sysfs; both accepted) | sysfs shows `[never]` |
| `modprobe.d/node-cis.conf`: `install dccp /bin/false`, `install sctp /bin/false`, `blacklist usb-storage` | CIS hardening for a multi-tenant host | `modprobe -n -v dccp` | `boot.blacklistedKernelModules`, `boot.extraModprobeConfig` | `modprobe -n -v` output |
| Apache `conf-enabled/security.conf` edited to `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off` | Hardening. Ubuntu ships this distro file with `ServerTokens OS`, so it's easy to overlook | `curl -sI` `Server:` header; `TRACE` → 405 | httpd `extraConfig` | `Server: Apache` exactly; TRACE 405 |
| `journald.conf.d/50-node.conf`: `Storage=persistent`, `SystemMaxUse=200M` | Forensics on a shared host with bounded disk | `systemd-analyze cat-config systemd/journald.conf` | `services.journald.extraConfig` | merged config values |
| System timezone `Europe/London`, but pools set `date.timezone = UTC` | Operators read local-time logs; apps store UTC | `readlink /etc/localtime`; PHP `ini_get` | `time.timeZone`; pool `php_admin_value` | both values |

## Interacting settings

| Complexifier | Why on this server | Find it on the reference | Nix | Check |
| --- | --- | --- | --- | --- |
| nftables owner match: tenants' uids rejected on TCP 25 out; root allowed | Shared-hosting anti-spam: tenant code must use the local relay | `nft list ruleset` / `iptables -S` | `networking.nftables.ruleset` or `firewall.extraCommands` | root opens a listener on 127.0.0.1:25; root connects, amber gets refused |
| `systemd/system/postgresql@14-main.service.d/override.conf`: `OOMScoreAdjust=-900`, `LimitNOFILE=65536` | Tenant slices can hit MemoryMax; the kernel must kill tenant work before the database | `systemctl show <unit> -p OOMScoreAdjust` | `systemd.services.postgresql.serviceConfig` | `/proc/<5432 owner>/oom_score_adj` and `limits` |
| `logrotate.d/web`: `su root adm`, `create 0640 root adm`, `rotate 14`, `dateext`, postrotate graceful reload | Retention policy. A default rotate recreates logs as root:root and silently breaks the sudo log policy after day one | `/etc/logrotate.d/web`; `logrotate -d` | `services.logrotate.settings` | `logrotate -d` on the config the logrotate unit runs: owner, mode, rotate count |
| Default ACL on `/var/log/web`: `setfacl -d -m g:adm:r` | New log files stay adm-readable whatever creates them. The `acl` package is already installed, which hints at it | `getfacl /var/log/web` (`ls -l` shows only `+`) | tmpfiles `A+` rule | `getfacl` output |
| `loginctl enable-linger amber` | amber runs a `systemd --user` queue worker without logging in. It also keeps `user-1101.slice` active, where `MemoryMax` applies | `/var/lib/systemd/linger/`, `loginctl show-user amber -p Linger` | `users.users.amber.linger = true` | `loginctl show-user` Linger=yes |
| Nightly `pg_dump` timer per tenant into `~/private/backups`, keeping 7 | Tenant self-service backups that respect `private` 0700 | `systemctl list-timers --all` | `systemd.timers`/`services` | a timer whose service runs `pg_dump` as each tenant, `OnCalendar=daily` |

## Ubuntu-natural, not obvious in Nix

Ordinary Ubuntu operator moves whose NixOS form exists but has to be found.

| Complexifier | Why on this server | Find it on the reference | Nix | Check |
| --- | --- | --- | --- | --- |
| `UMASK 027` in `/etc/login.defs` (applied by Ubuntu's default `pam_umask`) | Tenant shell files private by default | `runuser -l amber -c umask` | `security.loginDefs.settings.UMASK` plus a pam_umask rule (NixOS doesn't enable pam_umask by default) | `runuser -l` umask |
| `/etc/apache2/envvars` `APACHE_ULIMIT_MAX_FILES='ulimit -n 65536'` | Many tenant vhosts and log files | `/proc/<apache master>/limits` | `systemd.services.httpd.serviceConfig.LimitNOFILE` | master's `Max open files` |
| PHP `conf.d/99-node.ini`: `expose_php = Off`, `session.gc_maxlifetime = 1440` | Hide the PHP banner; Ubuntu's `phpsessionclean` timer depends on the lifetime | `X-Powered-By` header; `php-fpm -i` | pool or global `php.ini` options | header absent; `ini_get` |
| `pg_ident.conf` map: OS `root` may peer-login as roles `amber`/`cobalt` | Operator maintenance without passwords | `pg_ident_file_mappings`; `psql -U amber` as root | `services.postgresql.identMap` + `authentication` | root succeeds as amber over the socket; cobalt as amber fails |
| `sudoers.d/00-defaults`: `Defaults:%tenants use_pty, logfile=/var/log/sudo-web.log` | Auditable tenant sudo | `sudo -l -U amber` "Matching Defaults" | `security.sudo.extraConfig` | Defaults lines in `sudo -l` |
| `/usr/bin/python3` shebangs in tenant CGI already work on the reference | Every tenant script assumes Debian paths | Already in the base task: CGI checks use `#!/usr/bin/python3` | a symlink or tmpfiles `L` | existing `cgi_identity` |

## Picking a set

Three to five per variant, at least one from each of the first two groups. Precedence traps and decoys test inspection skill. The others test whether the agent looks beyond the services it was told about.
