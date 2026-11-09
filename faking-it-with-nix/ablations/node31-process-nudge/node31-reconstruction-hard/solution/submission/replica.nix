{ config, lib, pkgs, cx, ... }:
let
  yaml = pkgs.formats.yaml { };
  operators = { reed = 1401; sage = 1402; };

  selfJob = job: port: {
    job_name = job;
    static_configs = [ { targets = [ "127.0.0.1:${toString port}" ]; } ];
    relabel_configs = [ { target_label = "instance"; replacement = "node31:${toString port}"; } ];
  };
  probeJob = job: module: targets: {
    job_name = job;
    metrics_path = "/probe";
    params.module = [ module ];
    static_configs = [ { inherit targets; labels.cluster = "lab"; } ];
    relabel_configs = [
      { source_labels = [ "__address__" ]; target_label = "__param_target"; }
      { source_labels = [ "__param_target" ]; target_label = "instance"; }
      { target_label = "__address__"; replacement = "127.0.0.1:9115"; }
    ];
  };

  prometheusConfig = {
    global = {
      scrape_interval = "5s";
      evaluation_interval = "5s";
      external_labels.site = "node31";
    };
    rule_files = [ recordingRules alertRules ];
    alerting = {
      alert_relabel_configs = [
        { regex = "replica"; action = "labeldrop"; }
        { target_label = "source"; replacement = "prometheus"; }
      ];
      alertmanagers = [ { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; } ];
    };
    scrape_configs = [
      (selfJob "prometheus" 9090)
      (selfJob "alertmanager" 9093)
      (selfJob "blackbox_exporter" 9115)
      {
        job_name = "node";
        static_configs = [
          { targets = [ "127.0.0.1:9100" ]; labels = { cluster = "lab"; role = "self"; }; }
          { targets = [ "127.0.0.1:9101" ]; labels = { cluster = "lab"; role = "spare"; }; }
        ] ++ cx.nodeTargets;
        relabel_configs = [
          { source_labels = [ "__address__" ]; regex = "([^:]+):\\d+"; target_label = "hostname"; replacement = "$1"; }
        ] ++ cx.nodeRelabel;
      }
      (probeJob "probe_http" "http_2xx" [ "http://127.0.0.1:19190/received" "https://127.0.0.1/healthz" ])
      (probeJob "probe_auth" "http_auth_required" [ "https://127.0.0.1/" ])
      (probeJob "probe_tcp" "tcp_connect" [ "127.0.0.1:443" "127.0.0.1:9090" ])
    ];
  };

  recordingRules = yaml.generate "rules_recording.yml" {
    groups = [ {
      name = "node_recording";
      rules = [
        { record = "job:up:count"; expr = "count by (job) (up)"; labels.tier = "lab"; }
        { record = "job:up:sum"; expr = "sum by (job) (up)"; labels.tier = "lab"; }
      ];
    } ];
  };
  alertRules = yaml.generate "alerts_default.yml" {
    groups = [ {
      name = "default_alerts";
      rules = [
        { alert = "InstanceDown"; expr = "up == 0"; for = "10s";
          labels = { severity = "page"; team = "ops"; };
          annotations.summary = "{{ $labels.instance }} is down"; }
        { alert = "ProbeFailed"; expr = "probe_success == 0"; for = "30s";
          labels = { severity = "warning"; team = "ops"; };
          annotations.summary = "probe of {{ $labels.instance }} failed"; }
        { alert = "DeadMansSwitch"; expr = "vector(1)";
          labels = { severity = "info"; team = "ops"; };
          annotations.summary = "pipeline watchdog"; }
      ];
    } ];
  };

  hook = name: [ { url = "http://127.0.0.1:19190/${name}"; send_resolved = true; } ];
  alertmanagerConfig = {
    global.resolve_timeout = "20m";
    route = {
      receiver = "default";
      group_by = [ "alertname" "cluster" ];
      group_wait = "3s";
      group_interval = "5s";
      repeat_interval = "4h";
      routes = [
        { receiver = "logger"; continue = true; matchers = [ ''alertname=~".+"'' ]; }
        { receiver = "watchdog"; matchers = [ ''alertname="DeadMansSwitch"'' ]; repeat_interval = "5m"; }
        { receiver = "pager"; matchers = [ ''severity="page"'' ]; }
        { receiver = "ticket"; matchers = [ ''severity="warning"'' ]; repeat_interval = "72h"; }
      ];
    };
    inhibit_rules = [ {
      source_matchers = [ ''severity="page"'' ];
      target_matchers = [ ''severity=~"warning|critical"'' ];
      equal = [ "instance" ];
    } ];
    receivers = map (name: { inherit name; webhook_configs = hook name; })
      [ "default" "logger" "watchdog" "pager" "ticket" ];
  };

  blackboxConfig = {
    modules = {
      http_2xx = { prober = "http"; timeout = "5s";
        http = { preferred_ip_protocol = "ip4"; tls_config.insecure_skip_verify = true; }; };
      http_auth_required = { prober = "http"; timeout = "5s";
        http = { preferred_ip_protocol = "ip4"; valid_status_codes = [ 401 ]; tls_config.insecure_skip_verify = true; }; };
      tcp_connect = { prober = "tcp"; timeout = "5s"; tcp.preferred_ip_protocol = "ip4"; };
      tcp_tls = { prober = "tcp"; timeout = "5s";
        tcp = { preferred_ip_protocol = "ip4"; tls = true; tls_config.insecure_skip_verify = true; }; };
    };
  };

  htpasswd = pkgs.runCommand "htpasswd" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    echo "pine:$(openssl passwd -apr1 -salt abcdefgh pine-pass)" > $out
  '';
  sink = pkgs.writeText "alert-sink.py" ''
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
  '';
in {
  imports = [ ./complexify.nix ];
  networking.hostName = "node31";
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  networking.hosts."127.0.0.1" = [ "node31.n31.test" ];

  users.groups = lib.mapAttrs (_: gid: { inherit gid; }) operators;
  users.users = lib.mapAttrs (name: uid: {
    isNormalUser = true;
    inherit uid;
    group = name;
    home = "/home/${name}";
    shell = pkgs.bashInteractive;
  }) operators;

  # The harness installs the key root-only; nginx validates its configuration as its own user.
  environment.etc."node31/server.key" = {
    mode = lib.mkForce "0640";
    group = "nginx";
  };
  environment.etc."amtool/config.yml".text = "alertmanager.url: http://127.0.0.1:9093\n";
  environment.systemPackages = [ pkgs.prometheus-alertmanager pkgs.prometheus ];
  systemd.tmpfiles.rules = [ "d /var/lib/prometheus/node-exporter 0755 root root -" ];

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    webExternalUrl = "https://node31.n31.test/prometheus/";
    retentionTime = "730h";
    extraFlags = [ "--web.route-prefix=/" "--query.timeout=90s" ];
    configText = builtins.toJSON prometheusConfig;
    checkConfig = false;
    alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9093;
      webExternalUrl = "https://node31.n31.test/alertmanager/";
      extraFlags = [ "--web.route-prefix=/" "--cluster.listen-address=" "--data.retention=730h" ];
      configuration = alertmanagerConfig;
    };
    exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
      enabledCollectors = [ "systemd" "processes" ];
      disabledCollectors = [ "timex" ];
      extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus/node-exporter" ];
    };
    exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9115;
      configFile = yaml.generate "blackbox.yml" blackboxConfig;
    };
  };

  systemd.services.alert-sink = {
    wantedBy = [ "multi-user.target" ];
    before = [ "alertmanager.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${sink}";
      StateDirectory = "alert-sink";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  services.nginx = {
    enable = true;
    sslProtocols = "TLSv1.2 TLSv1.3";
    virtualHosts."redirect" = {
      serverName = "_";
      default = true;
      listen = [ { addr = "0.0.0.0"; port = 80; } ];
      locations."/".return = "301 https://$host$request_uri";
    };
    virtualHosts."node31.n31.test" = {
      default = true;
      onlySSL = true;
      listen = [ { addr = "0.0.0.0"; port = 443; ssl = true; } ];
      sslCertificate = "/etc/node31/server.crt";
      sslCertificateKey = "/etc/node31/server.key";
      extraConfig = ''
        auth_basic "node31";
        auth_basic_user_file ${htpasswd};
      '';
      locations."= /healthz" = {
        extraConfig = "auth_basic off; default_type text/plain;";
        return = ''200 "ok\n"'';
      };
      locations."= /" = {
        root = pkgs.writeTextDir "index.txt" "node31 monitoring\n";
        tryFiles = "/index.txt =404";
        extraConfig = "default_type text/plain;";
      };
      locations."/prometheus/" = {
        proxyPass = "http://127.0.0.1:9090/";
        extraConfig = "proxy_set_header Host $host;";
      };
      locations."/alertmanager/" = {
        proxyPass = "http://127.0.0.1:9093/";
        extraConfig = "proxy_set_header Host $host;";
      };
    };
  };
}
