# Proposed verifier checks (not yet implemented)

Proposals only. Each follows `methods.md`: inside first, daemon-reported state, exact reference values, every denial paired with the allowed path. "Oracle" = `solution/submission`. Quick = under 50 ms by estimate. All values must be probed once on the reference before coding.

## node17-reconstruction-hard

| Check | Property and who relies on it | Recipe source | Method and assertion | Oracle | Cost | Brittleness |
| --- | --- | --- | --- | --- | --- | --- |
| `tenant_htaccess_options` | Tenants' `.htaccess` and directory behavior: `AllowOverride AuthConfig FileInfo Indexes` (no `Options`), `Options Indexes`. A tenant `Options -Indexes` gets a 500 on the reference; a listing is served for an index-less directory. Promotes the "Directory listing / AllowOverride" row in methods.md extensions. | `tenant.erb:29-30` | Plant (random dir, as amber): `a.txt`, `secret.txt`, `.htaccess` = `IndexIgnore secret.txt`. GET `/<dir>/` on amber.node.test: 200, body has `a.txt`, lacks `secret.txt` (allowed override). Plant second dir with `.htaccess` = `Options +ExecCGI`: GET gives 500 (disallowed override). | Oracle `tenant.conf:29-30` copies the same lines, so likely passes | 5 requests, not <50 ms; the other planting checks cost the same | Low. Assert status and substring only, not listing markup |
| `tenant_error_log_sudo` | The sudo grant has two commands (access and error log); only access is tested. Tenants debug 500s by reading `<user>-error.log`. | `default.rb:50`, `:62-69`, `tenant.erb:14` | Per tenant, via `runuser`: `sudo -n -g adm /bin/cat /var/log/web/<u>-error.log` exits 0; the same for the other tenant's error log exits non-zero; plain `cat` of own error log is denied. Content is not asserted (AH00128 is info-level). | Oracle sudoers `replica.nix:127` has both commands; log file existence unverified | Quick | Low |
| `unmatched_host_default` | Requests that match no vhost (by IP, stale DNS, monitoring probes) get the first vhost. `a2ensite node amber cobalt` sorts as `amber`, `cobalt`, `node`, so a stray Host header returns amber's site, not `node service`. | `default.rb:80`, `a2dissite 000-default` | Outside: HTTPS with `Host: stray-<tok>.example` returns exactly the amber body (`amber workspace\n`); HTTP with the same Host returns 301 to `https://amber.node.test/`. Probe the reference first to confirm. | Unknown: oracle `replica.nix:45-80` defines vhost order itself; may need to put amber first | 2 requests | Medium: a reference accident, not a stated policy. Drop if it is judged unfair to ask |

Top pick: `tenant_htaccess_options`.

## node23-reconstruction-hard

| Check | Property and who relies on it | Recipe source | Method and assertion | Oracle | Cost | Brittleness |
| --- | --- | --- | --- | --- | --- | --- |
| `acl_client_networks` | Front-end ACL admits `10.0.0.0/8` and `192.168.0.0/16`, the real client networks. `acl_inside` only tests loopback (allowed) and 198.51.100.7 (denied), so an ACL of just `127.0.0.0/8` passes. | `default.rb:193` | Like `acl_inside`: add `10.200.1.7/32` and `192.168.77.7/32` to `lo`, send UDP to 127.0.0.1:53 from each source, expect `rcode 0` with the `app1` answer. Remove the addresses in `finally`. The existing denied-source case stays the pair. | Oracle `replica.nix:126` has the same ACL; passes | Quick (two answered queries, no timeout waits) | Low: same mechanism as the existing check |
| `dnsdist_web_password` | The operators' dnsdist web console uses basic auth with password `lab-web-pass` (distinct from the API key). `monitoring_api` only tests the key. | `default.rb:203` | Inside: `curl -s -o /dev/null -w %{http_code} -u :lab-web-pass http://127.0.0.1:8083/jsonstat?command=stats` is 200; `-u :wrong` is 401. Keep to `/jsonstat`, which both dnsdist 1.6 and 2.x serve. | Oracle `replica.nix:137` sets the password | Quick | Low-medium: dnsdist 2.x may require the API key for `/api`; confirm `/jsonstat` still accepts the web password |
| `client_rate_limit` | `MaxQPSIPRule(50)` drops a client above 50 qps; abusive or looping clients are cut off, others unaffected. The one unchecked deliberate policy. Asking first, since methods.md lists it under "needs load". | `default.rb:202` | Add `10.77.0.9/32` to `lo` (inside ACL, own bucket). Fire 400 UDP queries from it in a tight loop without waiting, then collect replies for 1 s: expect fewer than 400 replies and at least 1. Pair: a query from 127.0.0.1 is still answered. | Oracle `replica.nix:135` has the rule | About 1.5 s, not quick; needs human approval | Medium: timing-dependent, packet cache must not bypass the rule (rule order) |

Top pick: `acl_client_networks`.

## node31-reconstruction-hard

| Check | Property and who relies on it | Recipe source | Method and assertion | Oracle | Cost | Brittleness |
| --- | --- | --- | --- | --- | --- | --- |
| `alert_timing` | `resolve_timeout: 20m` (how long a source-less alert lives) and Prometheus `evaluation_interval 5s`. A default 5 m or 1 m differs and nothing tests it. | `default.rb:134`, `prometheus.yml.erb:2-4` | POST an alert with `startsAt` only (no `endsAt`) to the Alertmanager v2 API; GET `/api/v2/alerts` filtered by name: `endsAt - now` is 1200 s +/- 10. Prometheus: `/api/v1/rules` shows `interval == 5` for both groups. | Oracle `replica.nix:85` and `:26` set both | Quick (2 HTTP calls) | Low. API fields stable across 0.23 to current. Delete the test alert afterwards via a silence or let it expire |
| `notification_links` | Paged people click links in notifications. Alertmanager `externalURL` and each alert's `generatorURL` carry the proxy path (`https://node31.n31.test/alertmanager/`, `/prometheus/`). Only the Prometheus flag is checked today. | `default.rb:127,174` | In `alert_pipeline`'s delivered `/pager` payload: `externalURL == "https://node31.n31.test/alertmanager/"`, `alerts[0].generatorURL.startswith("https://node31.n31.test/prometheus/")`. No new wait; reuse the payload already polled. | Oracle `replica.nix:186,195` set both URLs | Quick | Low. Assert the prefix only, since the UI path after it changed in Prometheus 3 |
| `am_repeat_intervals` | `repeat_interval` 4 h default, 5 m watchdog, 72 h tickets. Not checked because behavior needs hours; the daemon reports its parsed config. | `default.rb:140-152` | `GET /api/v2/status` (`config.original`), parse with the verifier-side YAML loader (JSON is valid YAML, so the Nix-written file parses too): `route.repeat_interval` 4h, child route `receiver=watchdog` 5m, `ticket` 72h, `group_wait` 3s, `group_interval` 5s. Normalise durations, as `seconds()` does. | Oracle `replica.nix:91-96` | Quick | Medium: methods.md/verification.md currently say "no check reads `original`"; this one would, so needs a policy decision. Parse semantics only, never text |

Top pick: `alert_timing`.

## node37-reconstruction-hard

| Check | Property and who relies on it | Recipe source | Method and assertion | Oracle | Cost | Brittleness |
| --- | --- | --- | --- | --- | --- | --- |
| `operator_sudo` | `ember` is in the `sudo` group and is the machine's operator; on the reference group `sudo` grants full sudo. `accounts` checks only group names; NixOS has no `%sudo` rule, so the operator cannot run `sudo systemctl start infer-server`. | `default.rb:55-61` (ember in `sudo`) | `sudo -l -U ember` as root contains a rule matching `\(ALL(?: ?: ?ALL)?\) +ALL`. Probe the exact output on the reference first. | Needs an oracle change: `security.sudo.extraRules` for `%sudo` (or `wheel`) with `ALL` | Quick | Low: regex on the rule line only; no dependence on password policy |
| `infer_service_start` | Operators edit `/etc/default/infer-server` and start the unit; the current check reads only properties. Starting it must run as `ember` in `/home/ember/infer` with the file's args. The unit is the deliberately disabled one, so start then stop. | `default.rb:225-249` | `systemctl start infer-server`; poll `MainPID`; assert `/proc/<pid>/status` Uid is 1000, `readlink /proc/<pid>/cwd == /home/ember/infer`, `/proc/<pid>/limits` Max open files 1048576, `journalctl -u infer-server -o cat` has `infer-server --model lab-model --ctx 100000 --split 55,45 --host 192.0.2.83`; `systemctl stop` after. Placeholder `exec sleep` hides args from cmdline, so use the journal. | Oracle `replica.nix:143` mirrors the unit; likely passes | About 0.3 s (service start, poll), not strictly <50 ms | Low-medium: journal timing, poll rather than sleep |
| `hosts_file` | The recipe writes `/etc/hosts` as `127.0.0.1 localhost node37`, `::1 localhost ip6-localhost`. NixOS adds `127.0.0.2 node37` by default, so tools and clients resolve the host name differently. | `default.rb:72-74` | `getent ahostsv4 node37` first address is 127.0.0.1; `getent hosts ip6-localhost` is `::1`; `getent hosts 127.0.0.2` returns nothing. Same shape as node17's `host_resolution`. | Needs an oracle change: `networking.hosts` / `networking.hostFiles` override | Quick | Low |

Top pick: `operator_sudo`.

## Also noted (not new checks)

- node37 `udev_i2c` does `cat /etc/udev/rules.d/*.rules`, which breaks methods.md ("never grep distro paths"); the NixOS rule lives in the store. Replace it with a `udevadm` query when a fake device can be made, or accept `udevadm verify`/`udevadm test` output.
- Rejected as low value: node17 memcached `logfile`; node23 `client-tcp-timeout`, `threads`, `dnssec=off` (unobservable offline); node31 nginx `ssl_protocols` (the client library cannot offer TLS 1.1); node37 sysstat `ENABLED` (timer already checked).
