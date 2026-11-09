# Author provenance: node31-reconstruction-hard

Status: first draft, 2026-11-03.

Upstream: https://github.com/wikimedia/operations-puppet (default branch `production`)
Commit: acae00a0ae474ad6d00f42b7255e5f53dde9e352 (2026-11-03)
License: majority Apache-2.0 (repo `LICENSE`); per-file SPDX headers apply; `hieradata/` has no explicit license and was not used. `LICENSE` here is the Apache-2.0 text.

Upstream host role: a Wikimedia Prometheus/Alertmanager host: `modules/prometheus` (`prometheus::server` define, `profile::prometheus::*`)
and `modules/alertmanager` (class, `alertmanager.yml.erb`, `amtool.yml.erb`), with the blackbox exporter templates under
`modules/prometheus/templates/blackbox_exporter`.

Elements kept (adapted into `cookbooks/monitor/`):
- `prometheus::server` layout: a `prometheus.yml` with `rule_files` globs `rules_*.yml` and `alerts_*.yml`, a `prometheus` self job whose
  `instance` is relabelled to `host:port`, a `node` job with `file_sd_configs` over `node_*.yml`, `alerting.alert_relabel_configs`
  (drop `replica`, add `source: prometheus`), `--storage.tsdb.retention.time` (730h), reload instead of the lifecycle API.
- Alertmanager: `resolve_timeout`, `group_by [alertname, cluster]`, a first `continue: true` route to a `logger` receiver, a `DeadManSwitch`
  route with `repeat_interval: 5m`, severity routes (`page`, `warning` with a long repeat interval), an inhibit rule where `page`
  suppresses `warning|critical` for the same instance, webhook receivers, `--data.retention=730h`, `amtool.yml`.
- Blackbox exporter jobs with per-module `probe_*` jobs and the `__param_target` relabel pattern.

Scope changes (not upstream):
- One host, no Thanos/replicas/cluster peers (`--cluster.listen-address=` is empty); static lab targets instead of generated inventories.
- Webhook receivers all point at a local sink (`/usr/local/bin/alert-sink`, ~30 lines, stands in for Wikimedia's alertmanager-webhook-logger)
  on 127.0.0.1:19190; it records POSTs and serves them back at `GET /received`. Email/Slack/VictorOps receivers dropped.
- Timings shortened for the lab (scrape/evaluation 5 s, `group_wait` 3 s, `group_interval` 5 s, alert `for` 10 s).
- nginx with TLS and HTTP basic auth (realm and user synthetic) replaces Wikimedia's Apache vhosts; `/prometheus/` and `/alertmanager/`
  are proxied, `/healthz` is open. Grafana omitted.
- node_exporter collectors `systemd` and `processes` on, `timex` off; textfile directory enabled. A deliberately dead `node` target
  (`127.0.0.1:9101`, role `spare`) makes `InstanceDown` fire so the full alert path is exercised.
- Two synthetic operator accounts (reed, sage) use amtool through `/etc/amtool/config.yml`.

Renaming: Wikimedia hosts/sites/teams -> `node31`, `n31.test`, `site: node31`, `team: ops`.

Complexifiers (not upstream): `cookbooks/monitor/recipes/complexify.rb`, run after `default`.
- CX-rules-glob: `alerts-staged.yml` and `rules_old.yml.disabled` sit in the rules directory but do not match the globs. Rationale: alerts staged
  for review. Copying them adds an always-firing page.
- CX-sd-drop: `node_decom.yml` lists a retired host with `decommissioned: "true"` and the `node` job drops it by relabel. Rationale: the
  inventory file keeps retired hosts. Needs the template flag `drop_decommissioned` (base: false).
- CX-textfile-timer: `node31-inventory.timer` (every 60 s) writes `node31_inventory_users` and `node31_inventory_info` into node_exporter's
  textfile directory. Rationale: inventory gauges without an agent.

Host: Ubuntu 22.04, CINC 18.11.11; jammy packages Prometheus 2.31, Alertmanager 0.23, node_exporter 1.3, blackbox_exporter 0.19, nginx 1.18
(from memory; confirm in `.cache/tasks/node31-reconstruction-hard/work/packages.txt`). nixpkgs 26.05 ships newer majors (Prometheus 3).
Checks therefore use only behavior and values both generations expose identically.
