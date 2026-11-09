# node31 verifier: coverage and cost

2026-11-03. 27 checks (23 recipe, 4 complexifier) in `node31-reconstruction-hard/tests/verify.py`. Controls: reference 27/27; oracle 27/27 (`jobs/2026-11-03__17-39-10`); empty submission 0 (`jobs/2026-11-03__17-39-13`).

`operator_tools` runs `promtool --version`, `promtool query instant` against the local Prometheus and `htpasswd -nbB/-nbm` as `reed` and `sage` on their login PATH: Ubuntu's `prometheus` and `apache2-utils` packages put these on every user's PATH (`dpkg -S`), nixpkgs needs `prometheus.cli` and `apacheHttpd`. `icmp_probe` (CX-icmp-probe): blackbox `icmp` module on 127.0.0.1 and the `probe_icmp` job. The recipe checks (`prom_targets`, `recording_rules`, `probe_series`, `alert_pipeline`) ignore the `probe_icmp` job so a missing ICMP probe costs one check, not five.

## Version gap policy

The reference runs Ubuntu 22.04 packages (Prometheus 2.x, Alertmanager 0.23, node_exporter 1.3, blackbox_exporter 0.19); nixpkgs 26.05
ships newer majors. Checks read what the daemons report over HTTP and what flows through them: `/api/v1/targets`, `/rules`, `/alerts`,
`/query`, `/status/flags` (values normalised: durations are parsed), blackbox `/probe`, node_exporter `/metrics`, and notifications that
Alertmanager delivers to the local sink. No check reads a config file, `/api/v1/status/config` or Alertmanager's `original` config. Known
remaining gap: the oracle must express the same configuration in the new versions' module options; and Prometheus 3 differs in
range-selector semantics, so checks only use instant queries.

## How we check

| # | Method | How | Checks |
| --- | --- | --- | --- |
| 1 | Prometheus HTTP API (loopback, from inside) | flags, targets (labels, health, scrape URL, dropped), rules (type, query, duration, labels), alerts, instant queries | prom_flags, prom_targets, prom_rules, recording_rules, probe_series, alert_pipeline; CX: rules_glob, sd_drop, textfile_timer, icmp_probe |
| 2 | Alertmanager behavior | POST synthetic alerts and silences to its v2 API, read what arrives at the sink: receiver by path, grouping, inhibition, silence, resolved notice | alert_pipeline, am_routing, am_grouping, am_inhibit, am_silence, am_resolved, sink_service |
| 3 | Exporters | blackbox `/probe` per module (success and failure pairs, unknown module 400); node_exporter `/metrics` | blackbox_modules, node_collectors; CX: icmp_probe |
| 4 | Web face from outside | curl through forwarded 80/443, CA-verified with SNI; auth paired with open `/healthz` | tls_and_redirect, proxy_auth, proxy_apis |
| 5 | Live state and operator sessions | `ss`, `pwd`/`grp`, `findmnt`, `systemd-tmpfiles`, `runuser -u reed -- amtool ...`, `runuser -l <operator> -c 'promtool ...; htpasswd ...'` | host_identity, accounts, listeners, persistent_storage, amtool_operator, operator_tools |

Every denial is paired with an allowed path (401 without credentials vs 200 with, `/healthz` open; silenced alert vs unsilenced one;
inhibited warning vs warning on another instance; failing probe vs succeeding one).

## Not checked

| Item | Why |
| --- | --- |
| Config file text, rule file names | distro paths and version syntax |
| Retention enforcement, TSDB compaction | settings read from flags |
| Alertmanager `repeat_interval` values (72 h, 5 m) | needs long waits |
| Grafana, remote write, Thanos | not part of the role |
| `--web.max-connections`, other default flags | defaults differ between versions |

## Cost

Alertmanager checks wait for real timers (group_wait 3 s, group_interval 5 s): am_routing, am_grouping, am_inhibit and am_silence each need
about 12 s, am_resolved up to 20 s, alert_pipeline up to 60 s after boot. Estimated total 2-3 minutes with all other checks quick.
