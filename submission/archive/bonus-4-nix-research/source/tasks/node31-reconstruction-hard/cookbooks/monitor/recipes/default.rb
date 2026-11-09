# Derived monitoring host: Prometheus + Alertmanager + node/blackbox exporters behind an
# authenticating TLS proxy, with a local webhook sink. Source mapping: provenance.md.

{ 'reed' => 1401, 'sage' => 1402 }.each do |name, id|
  group(name) { gid id }
  user name do
    uid id
    gid id
    home "/home/#{name}"
    manage_home true
    shell '/bin/bash'
  end
end

%w[/etc/prometheus/targets /etc/prometheus/rules /var/lib/prometheus/node-exporter /etc/amtool].each do |dir|
  directory(dir) { recursive true }
end

file '/etc/amtool/config.yml' do
  content "alertmanager.url: http://127.0.0.1:9093\n"
end

# Wikimedia prometheus::server layout: config, file_sd target lists and rules_*/alerts_* files.
template '/etc/prometheus/prometheus.yml' do
  source 'prometheus.yml.erb'
  variables(drop_decommissioned: false)
  notifies :restart, 'service[prometheus]'
end

file '/etc/prometheus/targets/node_main.yml' do
  content <<~YML
    - targets: ['127.0.0.1:9100']
      labels: {cluster: lab, role: self}
    - targets: ['127.0.0.1:9101']
      labels: {cluster: lab, role: spare}
  YML
end
file '/etc/prometheus/targets/probe_http_main.yml' do
  content "- targets: ['http://127.0.0.1:19190/received', 'https://127.0.0.1/healthz']\n  labels: {cluster: lab}\n"
end
file '/etc/prometheus/targets/probe_auth_main.yml' do
  content "- targets: ['https://127.0.0.1/']\n  labels: {cluster: lab}\n"
end
file '/etc/prometheus/targets/probe_tcp_main.yml' do
  content "- targets: ['127.0.0.1:443', '127.0.0.1:9090']\n  labels: {cluster: lab}\n"
end

file '/etc/prometheus/rules/rules_recording.yml' do
  content <<~YML
    groups:
      - name: node_recording
        rules:
          - record: job:up:count
            expr: count by (job) (up)
            labels: {tier: lab}
          - record: job:up:sum
            expr: sum by (job) (up)
            labels: {tier: lab}
  YML
end
file '/etc/prometheus/rules/alerts_default.yml' do
  content <<~YML
    groups:
      - name: default_alerts
        rules:
          - alert: InstanceDown
            expr: up == 0
            for: 10s
            labels: {severity: page, team: ops}
            annotations: {summary: "{{ $labels.instance }} is down"}
          - alert: ProbeFailed
            expr: probe_success == 0
            for: 30s
            labels: {severity: warning, team: ops}
            annotations: {summary: "probe of {{ $labels.instance }} failed"}
          - alert: DeadMansSwitch
            expr: vector(1)
            labels: {severity: info, team: ops}
            annotations: {summary: "pipeline watchdog"}
  YML
end

file '/etc/default/prometheus' do
  content "ARGS=\"--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/metrics2 --web.listen-address=127.0.0.1:9090 --web.external-url=https://node31.n31.test/prometheus/ --web.route-prefix=/ --storage.tsdb.retention.time=730h --query.timeout=90s\"\n"
  notifies :restart, 'service[prometheus]'
end

file '/etc/prometheus/alertmanager.yml' do
  content <<~YML
    global:
      resolve_timeout: 20m
    route:
      receiver: default
      group_by: [alertname, cluster]
      group_wait: 3s
      group_interval: 5s
      repeat_interval: 4h
      routes:
        - receiver: logger
          continue: true
          matchers: ['alertname=~".+"']
        - receiver: watchdog
          matchers: ['alertname="DeadMansSwitch"']
          repeat_interval: 5m
        - receiver: pager
          matchers: ['severity="page"']
        - receiver: ticket
          matchers: ['severity="warning"']
          repeat_interval: 72h
    inhibit_rules:
      - source_matchers: ['severity="page"']
        target_matchers: ['severity=~"warning|critical"']
        equal: [instance]
    receivers:
      - name: default
        webhook_configs: [{url: 'http://127.0.0.1:19190/default', send_resolved: true}]
      - name: logger
        webhook_configs: [{url: 'http://127.0.0.1:19190/logger', send_resolved: true}]
      - name: watchdog
        webhook_configs: [{url: 'http://127.0.0.1:19190/watchdog', send_resolved: true}]
      - name: pager
        webhook_configs: [{url: 'http://127.0.0.1:19190/pager', send_resolved: true}]
      - name: ticket
        webhook_configs: [{url: 'http://127.0.0.1:19190/ticket', send_resolved: true}]
  YML
  group 'prometheus'
  mode '0640'
  notifies :restart, 'service[prometheus-alertmanager]'
end
file '/etc/default/prometheus-alertmanager' do
  content "ARGS=\"--config.file=/etc/prometheus/alertmanager.yml --storage.path=/var/lib/prometheus/alertmanager --web.listen-address=127.0.0.1:9093 --web.external-url=https://node31.n31.test/alertmanager/ --web.route-prefix=/ --cluster.listen-address= --data.retention=730h\"\n"
  notifies :restart, 'service[prometheus-alertmanager]'
end

file '/etc/default/prometheus-node-exporter' do
  content "ARGS=\"--web.listen-address=127.0.0.1:9100 --collector.textfile.directory=/var/lib/prometheus/node-exporter --collector.systemd --collector.processes --no-collector.timex\"\n"
  notifies :restart, 'service[prometheus-node-exporter]'
end

file '/etc/prometheus/blackbox.yml' do
  content <<~YML
    modules:
      http_2xx:
        prober: http
        timeout: 5s
        http:
          preferred_ip_protocol: ip4
          tls_config: {insecure_skip_verify: true}
      http_auth_required:
        prober: http
        timeout: 5s
        http:
          preferred_ip_protocol: ip4
          valid_status_codes: [401]
          tls_config: {insecure_skip_verify: true}
      tcp_connect:
        prober: tcp
        timeout: 5s
        tcp: {preferred_ip_protocol: ip4}
      tcp_tls:
        prober: tcp
        timeout: 5s
        tcp:
          preferred_ip_protocol: ip4
          tls: true
          tls_config: {insecure_skip_verify: true}
  YML
  notifies :restart, 'service[prometheus-blackbox-exporter]'
end
file '/etc/default/prometheus-blackbox-exporter' do
  content "ARGS=\"--config.file=/etc/prometheus/blackbox.yml --web.listen-address=127.0.0.1:9115\"\n"
  notifies :restart, 'service[prometheus-blackbox-exporter]'
end

# Local webhook sink standing in for chat/paging receivers (Wikimedia: alertmanager-webhook-logger).
file '/usr/local/bin/alert-sink' do
  mode '0755'
  content <<~'PY'
    #!/usr/bin/python3
    import json
    from http.server import BaseHTTPRequestHandler, HTTPServer

    LOG = "/var/lib/alert-sink/received.jsonl"


    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            with open(LOG, "ab") as handle:
                handle.write(json.dumps({"path": self.path, "body": json.loads(body or b"null")}).encode() + b"\n")
            self.send_response(200)
            self.end_headers()

        def do_GET(self):
            if self.path != "/received":
                self.send_error(404)
                return
            try:
                lines = open(LOG, "rb").read().splitlines()
            except FileNotFoundError:
                lines = []
            data = json.dumps([json.loads(line) for line in lines]).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *args):
            pass


    HTTPServer(("127.0.0.1", 19190), Handler).serve_forever()
  PY
end
file '/etc/systemd/system/alert-sink.service' do
  content "[Unit]\nDescription=Local alert webhook sink\nAfter=network.target\n[Service]\nExecStart=/usr/local/bin/alert-sink\nStateDirectory=alert-sink\nDynamicUser=yes\nRestart=on-failure\n[Install]\nWantedBy=multi-user.target\n"
end
execute('systemctl daemon-reload')

execute 'tls-key-htpasswd' do
  command "openssl passwd -apr1 pine-pass | sed 's/^/pine:/' > /etc/nginx/htpasswd && chmod 0640 /etc/nginx/htpasswd && chgrp www-data /etc/nginx/htpasswd"
end
file('/etc/nginx/sites-enabled/default') { action :delete }
directory('/var/www/node31') { recursive true }
file('/var/www/node31/index.txt') { content "node31 monitoring\n" }
file '/etc/nginx/conf.d/node31.conf' do
  content <<~'NGINX'
    server {
      listen 80 default_server;
      return 301 https://$host$request_uri;
    }
    server {
      listen 443 ssl default_server;
      server_name node31.n31.test;
      ssl_certificate /etc/node31/server.crt;
      ssl_certificate_key /etc/node31/server.key;
      ssl_protocols TLSv1.2 TLSv1.3;
      auth_basic "node31";
      auth_basic_user_file /etc/nginx/htpasswd;
      location = /healthz {
        auth_basic off;
        default_type text/plain;
        return 200 "ok\n";
      }
      location = / {
        root /var/www/node31;
        try_files /index.txt =404;
        default_type text/plain;
      }
      location /prometheus/ {
        proxy_pass http://127.0.0.1:9090/;
        proxy_set_header Host $host;
      }
      location /alertmanager/ {
        proxy_pass http://127.0.0.1:9093/;
        proxy_set_header Host $host;
      }
    }
  NGINX
  notifies :restart, 'service[nginx]'
end

execute 'systemctl reset-failed'
%w[prometheus prometheus-alertmanager prometheus-node-exporter prometheus-blackbox-exporter nginx alert-sink].each do |name|
  service(name) { action %i[enable start] }
end
