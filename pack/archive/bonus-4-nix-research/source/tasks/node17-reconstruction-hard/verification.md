# Node17 verifier: coverage and cost

2026-11-03

The 35 checks (31 from the recipe, 4 complexifiers) in `node17-reconstruction-hard/tests/verify.py` test every behavior the Chef recipe gives clients, tenants and data, against exact values read from the reference. The frozen reference passes 35/35 (`mise run check-reference node17-reconstruction-hard`). Every check is a quick inside command or one client request; none reboots the VM.

## How we check

| # | Method | How | Checks |
| --- | --- | --- | --- |
| 1 | Live state, root SSH | `stat`, `pwd`/`grp`, `getent`, `ss`, `ps`, `systemctl show`, `pg_authid`; effective config from the running daemons (`php-fpm -tt`, Apache `DUMP_INCLUDES`, memcached `stats settings`); `findmnt`, `systemd-tmpfiles --cat-config` | host_resolution, accounts, filesystem_ownership, slice_limits, loopback_services, server_tuning, persistent_storage; CX: sudo_decoy, log_rotation, db_role_limits |
| 2 | Act as tenant, SSH | `runuser -u <tenant>`: cat, sudo, psql; success and denial both asserted | private_isolation, sudo_log_policy, postgres_peer, postgres_isolation, postgis; CX: login_limits |
| 3 | Client sessions in guest | psql/mysql over TCP by service name, right and wrong password; raw memcached | postgres_password, mysql_password, mysql_isolation, mysql_root_socket, cache_protocol |
| 4 | HTTP(S) from outside | curl via forwarded ports, CA-verified with SNI; exact status, `Location`, body | tls_aliases, http_redirects, userdir_redirect |
| 5 | Plant and probe | SSH writes a random-named file as the tenant; one outside request runs or serves it | static_range, php_* (6), cgi_identity, wsgi_identity, proxy_header, htaccess_and_symlinks |

No check greps fixed config paths, lists packages or diffs file trees: the Nix replica writes different files. `server_tuning` reads config only through each running daemon's own binary, so it works on either layout. Every denial check also asserts the allowed path, so a missing service fails.

## What is covered

| Area | Recipe sets | Checks (method) |
| --- | --- | --- |
| Identity | hostname `node17`; `catalog`, `sql`, `cache.node.test` → 127.0.0.1 | host_resolution (1) |
| Accounts, files | amber 1101/1000, cobalt 1102/1001, bash; home, `public_html`, `cgi-bin`, `wsgi-bin` 0755; `private` 0700; token 0600 | accounts, filesystem_ownership (1); private_isolation (2) |
| Logs | each tenant reads only own logs, via `sudo -g adm cat` | sudo_log_policy (2, 5) |
| Memory | user slices: MemoryHigh 80%, MemoryMax 90% | slice_limits (1) |
| PostgreSQL, PostGIS | loopback; local peer; SCRAM over TCP; own DB, no cross-connect; PostGIS | postgres_peer, postgres_isolation, postgis (2); postgres_password (3) |
| MariaDB | own DB and password; root by socket | mysql_root_socket, mysql_password, mysql_isolation (3) |
| memcached | loopback TCP only, not root | cache_protocol (3); loopback_services (1) |
| Web routing | six TLS names; :80 → 301 https; ACME passthrough; `/~u` → 307 | tls_aliases, http_redirects, userdir_redirect (4) |
| Tenant sites | byte ranges, `.htaccess`, owner-matched symlinks, `Proxy` header stripped | static_range, htaccess_and_symlinks, proxy_header (5) |
| Tenant code | PHP, CGI, WSGI run as tenant; pool env, limits, `open_basedir`, DB access | php_* (6), cgi_identity, wsgi_identity (5) |
| Tuning | FPM `pm.*`, `max_requests`, `request_terminate_timeout`, no `www` pool; `ProxyTimeout 90`; memcached 32 MB, UDP off | server_tuning (1) |
| Persistence | tenant files and both live database data dirs on real disk; no tmpfiles rule removes or age-cleans them | persistent_storage (1) |
| CX-sudo-decoy | inert `sudoers.d/cobalt-deploy.disabled` must stay inert | sudo_decoy (1) |
| CX-login-limits | `@tenants` nproc 200, nofile 4096 for login sessions | login_limits (2) |
| CX-log-rotation | daily, 14 kept; recreate `0640 root:adm` + reload, or copytruncate | log_rotation (1) |
| CX-db-role-limits | `amber`/`cobalt` PostgreSQL `CONNECTION LIMIT` 20/40 and `statement_timeout` 30s/1min; MariaDB `MAX_USER_CONNECTIONS` 20/40 (state in the database catalogs, read through the tenants' own sessions) | db_role_limits (1, 3) |

Tightened 2026-11-03: exact uid/gid and shell, home and script-dir modes, SCRAM storage, loopback for all three backends, page bodies, main-site redirects, `display_errors` and mbstring.

## Not checked

| Item | Why |
| --- | --- |
| Package versions (PostgreSQL 14, PHP 8.1) | nixpkgs 26.05 ships newer; clients see the same APIs |
| suEXEC as the CGI mechanism | the contract is the uid, which is checked |
| Log paths and format | low client impact |
| Directory listing, `AllowOverride` boundary | open: one request each to add |

## Cost

Controls, 2026-11-03: reference 35/35; oracle 35/35 (`jobs/2026-11-03__17-13-40`); empty submission (`nop`) 0/35 (`jobs/2026-11-03__17-13-44`).

| Oracle phase | Seconds |
| --- | --- |
| Build (cached) | 108 |
| Boot | 18 |
| All 35 checks | 8 (estimate) |

- No reboot: `persistent_storage` reads the settings that make data survive one.
- SSH connections are shared; the reference control runs at author time, not per trial (was ~233 s per trial).
- `checks.json` records build, boot and per-check seconds and each check's origin.
