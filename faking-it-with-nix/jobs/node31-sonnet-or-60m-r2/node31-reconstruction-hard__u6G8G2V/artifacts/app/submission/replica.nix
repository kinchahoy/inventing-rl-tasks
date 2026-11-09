{ config, lib, pkgs, ... }:
let
  f = ./files;

  alertSink = pkgs.writeScript "alert-sink"
    ("#!${pkgs.python3}/bin/python3\n" + builtins.readFile (f + "/alert-sink.py"));

  inventory = pkgs.writeScript "node31-inventory"
    ("#!${pkgs.runtimeShell}\nPATH=${lib.makeBinPath [ pkgs.gawk pkgs.coreutils ]}:$PATH\n"
      + lib.removePrefix "#!/bin/sh\n" (builtins.readFile (f + "/node31-inventory.sh")));

  promArgs = {
    prometheus = lib.concatStringsSep " " [
      "--config.file=/etc/prometheus/prometheus.yml"
      "--storage.tsdb.path=/var/lib/prometheus/metrics2"
      "--web.listen-address=127.0.0.1:9090"
      "--web.external-url=https://node31.n31.test/prometheus/"
      "--web.route-prefix=/"
      "--storage.tsdb.retention.time=730h"
      "--query.timeout=90s"
    ];
    alertmanager = lib.concatStringsSep " " [
      "--config.file=/etc/prometheus/alertmanager.yml"
      "--storage.path=/var/lib/prometheus/alertmanager"
      "--web.listen-address=127.0.0.1:9093"
      "--web.external-url=https://node31.n31.test/alertmanager/"
      "--web.route-prefix=/"
      "--cluster.listen-address="
      "--data.retention=730h"
    ];
    blackbox = lib.concatStringsSep " " [
      "--config.file=/etc/prometheus/blackbox.yml"
      "--web.listen-address=127.0.0.1:9115"
    ];
    node = lib.concatStringsSep " " [
      "--web.listen-address=127.0.0.1:9100"
      "--collector.textfile.directory=/var/lib/prometheus/node-exporter"
      "--collector.systemd"
      "--collector.processes"
      "--no-collector.timex"
    ];
  };

  promService = desc: exe: args: extra: {
    description = desc;
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      ExecStart = "${exe} ${args}";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = false;
    } // extra;
  };

  etcFile = src: { source = src; };
  rulesDir = f + "/prometheus/rules";
  targetsDir = f + "/prometheus/targets";
in
{
  networking.hostName = "node31";
  networking.hosts."127.0.0.1" = [ "localhost" "node31" "node31.n31.test" ];
  networking.hosts."127.0.0.2" = lib.mkForce [ ];
  networking.firewall.enable = false;
  time.timeZone = "UTC";
  i18n.defaultLocale = "C.UTF-8";

  # ---- accounts ----
  users.mutableUsers = true;
  users.groups = {
    reed.gid = 1401;
    sage.gid = 1402;
    sudo = { };
    admin = { };
    www-data.gid = 33;
    prometheus = { };
  };
  users.users = {
    reed = {
      isNormalUser = true; uid = 1401; group = "reed"; home = "/home/reed";
      shell = pkgs.bashInteractive;
    };
    sage = {
      isNormalUser = true; uid = 1402; group = "sage"; home = "/home/sage";
      shell = pkgs.bashInteractive;
    };
    www-data = {
      isSystemUser = true; uid = 33; group = "www-data"; home = "/var/www";
    };
    prometheus = {
      isSystemUser = true; group = "prometheus"; home = "/var/lib/prometheus";
      description = "Prometheus daemon";
    };
  };
  security.sudo.extraRules = [
    { groups = [ "admin" ]; commands = [ { command = "ALL"; options = [ "SETENV" ]; } ]; }
    { groups = [ "sudo" ]; runAs = "ALL:ALL"; commands = [ { command = "ALL"; } ]; }
  ];

  # ---- ssh ----
  services.openssh = {
    enable = true;
    openFirewall = false;
    hostKeys = [ ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
  };
  environment.etc = {
    "ssh/ssh_host_ed25519_key" = { source = f + "/ssh/ssh_host_ed25519_key"; mode = "0600"; };
    "ssh/ssh_host_ed25519_key.pub".source = f + "/ssh/ssh_host_ed25519_key.pub";
    "ssh/ssh_host_rsa_key" = { source = f + "/ssh/ssh_host_rsa_key"; mode = "0600"; };
    "ssh/ssh_host_rsa_key.pub".source = f + "/ssh/ssh_host_rsa_key.pub";
    "ssh/ssh_host_ecdsa_key" = { source = f + "/ssh/ssh_host_ecdsa_key"; mode = "0600"; };
    "ssh/ssh_host_ecdsa_key.pub".source = f + "/ssh/ssh_host_ecdsa_key.pub";

    "nginx/htpasswd" = { source = f + "/htpasswd"; mode = "0640"; user = "root"; group = "www-data"; };

    "prometheus/prometheus.yml".source = f + "/prometheus/prometheus.yml";
    "prometheus/blackbox.yml".source = f + "/prometheus/blackbox.yml";
    "prometheus/alertmanager.yml" = {
      source = f + "/prometheus/alertmanager.yml"; mode = "0640"; user = "root"; group = "prometheus";
    };
    "prometheus/alertmanager_templates/README.templates".text = "";
    "prometheus/consoles/README.consoles".text = "";
    "prometheus/console_libraries/README.consoles".text = "";
  }
  // lib.mapAttrs' (n: _: lib.nameValuePair "prometheus/rules/${n}" (etcFile (rulesDir + "/${n}")))
       (builtins.readDir rulesDir)
  // lib.mapAttrs' (n: _: lib.nameValuePair "prometheus/targets/${n}" (etcFile (targetsDir + "/${n}")))
       (builtins.readDir targetsDir);

  # ---- sshd host keys present in /etc/ssh before sshd starts (env.etc runs in activation) ----

  # ---- web front end ----
  services.nginx = {
    enable = true;
    user = "www-data";
    group = "www-data";
    logError = "/var/log/nginx/error.log";
    appendConfig = "user www-data www-data;";
    appendHttpConfig = ''
      gzip on;
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
    '';
  };

  # Like the reference, the nginx master runs as root (key is root:0600); workers drop to www-data.
  systemd.services.nginx.serviceConfig = {
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    SystemCallFilter = lib.mkForce [ "~@cpu-emulation @debug @keyring @mount @obsolete" ];
    NoNewPrivileges = lib.mkForce false;
    AmbientCapabilities = lib.mkForce [ ];
    CapabilityBoundingSet = lib.mkForce [
      "CAP_NET_BIND_SERVICE" "CAP_SYS_RESOURCE" "CAP_SETUID" "CAP_SETGID" "CAP_CHOWN" "CAP_DAC_OVERRIDE"
    ];
  };

  # ---- monitoring stack ----
  systemd.services.prometheus = (promService "Monitoring system and time series database"
    "${pkgs.prometheus}/bin/prometheus" promArgs.prometheus {
      LimitNOFILE = 8192;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "full";
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictRealtime = true;
      LockPersonality = true;
      RemoveIPC = true;
    }) // { after = [ "network.target" "time-sync.target" ]; };

  systemd.services.prometheus-alertmanager = promService "Alertmanager for prometheus"
    "${pkgs.prometheus-alertmanager}/bin/alertmanager" promArgs.alertmanager { };
  systemd.services.prometheus-blackbox-exporter = promService "Blackbox exporter for Prometheus"
    "${pkgs.prometheus-blackbox-exporter}/bin/blackbox_exporter" promArgs.blackbox { };
  systemd.services.prometheus-node-exporter = promService "Prometheus exporter for machine metrics"
    "${pkgs.prometheus-node-exporter}/bin/node_exporter" promArgs.node { };

  systemd.services.alert-sink = {
    description = "Local alert webhook sink";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = alertSink;
      StateDirectory = "alert-sink";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  systemd.services.node31-inventory = {
    description = "Write inventory metrics";
    serviceConfig = { Type = "oneshot"; ExecStart = inventory; };
  };
  systemd.timers.node31-inventory = {
    description = "Inventory metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "5s"; OnUnitActiveSec = "60s"; };
  };

  services.cron.enable = true;

  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus 0755 prometheus prometheus -"
    "d /var/lib/prometheus/metrics2 0755 prometheus prometheus -"
    "d /var/lib/prometheus/alertmanager 0755 prometheus prometheus -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"
    "d /var/www 0755 root root -"
    "d /var/www/html 0755 root root -"
    "d /var/www/node31 0755 root root -"
    "L+ /var/www/node31/index.txt - - - - ${f + "/index.txt"}"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/alert-sink - - - - ${alertSink}"
    "L+ /usr/local/bin/node31-inventory - - - - ${inventory}"
  ];
}
