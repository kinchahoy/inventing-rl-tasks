# Complexifiers layered on the original recipe (default.rb). Catalogue: author/complexify.md.

# CX-rules-glob: staged rule files that the rule_files globs (rules_*.yml, alerts_*.yml) do not match.
# The hyphenated name and the .disabled suffix keep them out; copying them would add an always-firing page.
file '/etc/prometheus/rules/alerts-staged.yml' do
  content "groups:\n  - name: staged_alerts\n    rules:\n      - alert: StagedNoisy\n        expr: vector(1)\n        labels: {severity: page, team: ops}\n"
end
file '/etc/prometheus/rules/rules_old.yml.disabled' do
  content "groups:\n  - name: old_recording\n    rules:\n      - record: old:up:sum\n        expr: sum(up)\n"
end

# CX-sd-drop: a decommissioned host stays in the target list for the inventory, and a relabel rule
# drops it before scraping.
file '/etc/prometheus/targets/node_decom.yml' do
  content "- targets: ['127.0.0.1:9102']\n  labels: {cluster: lab, role: retired, decommissioned: 'true'}\n"
end
edit_resource!(:template, '/etc/prometheus/prometheus.yml') do
  variables(drop_decommissioned: true, icmp_probe: true)
end

# CX-textfile-timer: a timer writes inventory gauges into node_exporter's textfile directory.
file '/usr/local/bin/node31-inventory' do
  mode '0755'
  content <<~'SH'
    #!/bin/sh
    out=/var/lib/prometheus/node-exporter
    users=$(awk -F: '$3 >= 1000 && $7 ~ /bash$/ {n++} END {print n+0}' /etc/passwd)
    {
      echo '# TYPE node31_inventory_users gauge'
      echo "node31_inventory_users $users"
      echo '# TYPE node31_inventory_info gauge'
      echo 'node31_inventory_info{role="monitor"} 1'
    } > "$out/node31_inventory.prom.tmp"
    mv "$out/node31_inventory.prom.tmp" "$out/node31_inventory.prom"
  SH
end
file '/etc/systemd/system/node31-inventory.service' do
  content "[Unit]\nDescription=Write inventory metrics\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/node31-inventory\n"
end
file '/etc/systemd/system/node31-inventory.timer' do
  content "[Unit]\nDescription=Inventory metrics\n[Timer]\nOnBootSec=5s\nOnUnitActiveSec=60s\n[Install]\nWantedBy=timers.target\n"
end
execute('systemctl daemon-reload && systemctl enable --now node31-inventory.timer && systemctl start node31-inventory.service')

# CX-icmp-probe: reachability of the loopback gateway without TCP. A blackbox 'icmp' module plus a probe_icmp
# job. Ubuntu pings through ping sockets (ping_group_range is open to every group), so the exporter needs no file capability.
edit_resource!(:file, '/etc/prometheus/blackbox.yml') do
  content(content + "  icmp:\n    prober: icmp\n    timeout: 5s\n    icmp: {preferred_ip_protocol: ip4}\n")
end
file '/etc/prometheus/targets/probe_icmp_main.yml' do
  content "- targets: ['127.0.0.1']\n  labels: {cluster: lab}\n"
end
