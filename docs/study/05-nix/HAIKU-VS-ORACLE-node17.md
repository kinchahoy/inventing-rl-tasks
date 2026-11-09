# node17: Haiku (kLthoPm, 0.83) vs oracle (1.0)

Sources: `node17-oracle/{replica,complexify}.nix`, `node17-haiku-kLthoPm/replica.nix`,
`node17-haiku-kLthoPm.checks.json` (the trial's `verifier/checks.json`), checks in
`../04-harness/task/node17-reconstruction-hard/tests/verify.py`. 29/35 passed; 6 failed.

## Differences that map to failed checks

| Check (origin) | Verifier detail | Oracle has | Haiku has | Discovery step it skipped |
|---|---|---|---|---|
| `slice_limits` (recipe) | `ValueError: invalid literal for int(): b'infinity'` (MemoryHigh unset) | `systemd.slices."user-" = { overrideStrategy = "asDropin"; sliceConfig = { MemoryHigh = "80%"; MemoryMax = "90%"; }; };` | nothing | `systemctl cat user-1101.slice` or `ls /etc/systemd/system/user-.slice.d` |
| `postgres_isolation` (recipe) | `cross-database connect` | `REVOKE CONNECT ON DATABASE ${user} FROM PUBLIC;` in `initialScript` | `ensureDatabases` + `ensureDBOwnership`, no REVOKE; PUBLIC keeps CONNECT | `psql -c '\l'` (Access privileges column) |
| `cgi_identity` (recipe) | `(200, b'www-data\n')` | per-tenant `systemd.sockets.cgi-<u>` + `cgi-<u>.service` running `fcgiwrap` as the tenant; vhost `SetHandler "proxy:unix:/run/cgi-<u>.sock|fcgi://localhost"` | `LoadModule cgid_module`, `User www-data`: CGI runs as www-data | `a2query -m suexec` / `apachectl -M`; or a CGI that prints `id -un` |
| `login_limits` (CX) | `('amber', [b'11765', b'524288'])` = defaults | `security.pam.loginLimits` for `@tenants` nproc/nofile | group `tenants` (gid 1002) only | `ls /etc/security/limits.d`; `runuser -l amber -c 'ulimit -Hu'` |
| `log_rotation` (CX) | logrotate debug output shows only stock logs (`wtmp`), no `/var/log/web/*.log` stanza | `services.logrotate.settings.web = { ...; su = "root adm"; create = "0640 root adm"; }` | nothing | `cat /etc/logrotate.d/web` |
| `db_role_limits` (CX) | `('amber', b'0')`: role caps OK, `statement_timeout` = 0 | `ALTER ROLE amber CONNECTION LIMIT 20; ALTER ROLE amber SET statement_timeout = '30s';` (+ cobalt 40/1min; MariaDB MAX_USER_CONNECTIONS) | `CONNECTION LIMIT 20/40` and MariaDB `MAX_USER_CONNECTIONS` (correct), no `SET statement_timeout` | `psql -c '\drds'` (per-role settings) |

Pattern: 5 of 6 are "mechanism never inspected" (no command in the trace mentions slice, limits.d,
logrotate, REVOKE, statement_timeout; see `../06-traces/node17-haiku-kLthoPm.md`). One (`cgi_identity`)
was inspected for output but not identity. 3 of the 6 are complexifiers; 3 are original recipe items.

## Differences that did NOT cost a check (valid alternative implementations)

| Area | Oracle | Haiku | Why both pass |
|---|---|---|---|
| Apache | hand-rolled `httpd` unit, generated conf with `${pkgs.apacheHttpd}` LoadModule paths, user `web` | hand-rolled `apache2` unit, conf in `environment.etc."apache2/..."`, user `www-data`, vhost files copied from reference | checks probe behaviour (redirects, TLS, identity), not unit names or config paths |
| PHP | `pkgs.php.buildEnv` with pgsql/mysql/mbstring | `pkgs.php84` (its default extension set evidently covers them: the PDO and mbstring checks passed) | `php_pool_limits` checks `extension_loaded("mbstring")`; `php_postgres`/`php_mysql` use PDO |
| PHP env | `"env[NODE_LABEL]" = user` in `settings` | `phpEnv = { NODE_LABEL = ...; }` | both render `env[...]` lines in the pool config |
| PostgreSQL roles | `initialScript` with plain passwords | `ensureUsers` + oneshot `postgresql-tenants` setting the reference's SCRAM verifiers verbatim | `postgres_password` checks login works and `pg_authid` starts with `SCRAM-SHA-256$` |
| PostGIS | `extensions = ps: [ ps.postgis ]` + `CREATE EXTENSION postgis` per DB | `postgresql_17.withPackages` + `CREATE EXTENSION IF NOT EXISTS postgis` in the oneshot | same effect (Opus did the first half only and failed `postgis`) |
| memcached | raw unit, DynamicUser | `services.memcached` with `user = "memcache"` | `cache_protocol` + `server_tuning` read `stats settings` |
| Firewall | `allowedTCPPorts = [22 80 443]` | `networking.firewall.enable = false` (reference had ufw inactive) | checks go through the forwarded ports either way |
| Seeding | oneshot `node-state.service` | `system.activationScripts.node17Compat` + tmpfiles | both create the tree on first boot, idempotently |
| Compat paths | tmpfiles `L+ /usr/bin/python3`, `L+ /bin/cat` | activation script `ln -sfn` (after creating `/usr/bin`; trace step 71) | same symlinks |
| Sudo | raw `extraConfig` lines | `extraRules` listing both `/bin/cat` and `/run/current-system/sw/bin/cat` | sudo resolves the typed `cat`; both rule sets match |

## Talking points

- The oracle is not "the" answer; it's one implementation. The checks accept any behaviourally equivalent
  one (several verifier fixes were exactly about this: `07-evidence/verifier-fixes-all-attacks.md`).
- Haiku's Nix was competent where it looked (ProtectHome, `(:adm)` runAs, decoy, PostgreSQL ordering).
  The loss is entirely in breadth of inspection, which is the headroom claim
  (`07-evidence/check-regimes.md`: node17 = "breadth/attention" regime).
