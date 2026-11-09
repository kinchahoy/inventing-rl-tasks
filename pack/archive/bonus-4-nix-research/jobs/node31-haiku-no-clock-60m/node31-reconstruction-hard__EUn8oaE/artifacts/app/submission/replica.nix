{ lib, pkgs, ... }:

# node31: monitoring front end. nginx (80 -> 443, TLS, basic auth) reverse-proxies
# Prometheus and Alertmanager; blackbox and node exporters, a local alert webhook
# sink and an inventory timer complete the stack. Seeded configuration lives in
# ./files; nothing user-generated (alert history, TSDB data) is carried over.
let
  files = ./files;

  # Full nginx.conf. Mirrors the reference's effective configuration
  # (nginx -T): the port-80 redirect, the TLS server with basic auth, /healthz,
  # the static index and the /prometheus/ and /alertmanager/ proxies.
  nginxConf = ''
    events {
      worker_connections 768;
    }

    http {
      sendfile on;
      tcp_nopush on;
      types_hash_max_size 2048;

      include ${pkgs.nginx}/conf/mime.types;
      default_type application/octet-stream;

      ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers on;

      access_log /var/log/nginx/access.log;

      gzip on;

      server {
        listen 80 default_server;
        return 301 https://$host$request_uri;
      }

      server {
        listen 443 ssl default_server;
        server_name node31.n31.test;
        ssl_certificate /etc/node31/server.crt;
        ssl_certificate_key /run/credentials/nginx.service/server.key;
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
    }
  '';

  # alert-sink.py and node31-inventory.sh are the seeded scripts verbatim;
  # only the interpreter path is rewritten to the Nix store.
  alertSink = pkgs.writeScript "alert-sink"
    (lib.replaceStrings [ "#!/usr/bin/python3" ] [ "#!${pkgs.python3}/bin/python3" ]
      (builtins.readFile (files + "/alert-sink.py")));

  inventory = pkgs.writeScript "node31-inventory"
    (lib.replaceStrings [ "#!/bin/sh" ] [ "#!${pkgs.runtimeShell}" ]
      (builtins.readFile (files + "/node31-inventory.sh")));

  etcFile = path: { source = files + "/${path}"; };
in
{
  networking = {
    hostName = "node31";
    domain = "n31.test";
    hosts."127.0.0.1" = [ "node31" "node31.n31.test" ];
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };

  i18n.defaultLocale = "C.UTF-8";

  boot.kernel.sysctl = {
    # Unprivileged ICMP sockets for the blackbox exporter's icmp probes.
    "net.ipv4.ping_group_range" = "0 2147483647";
  };

  # Accounts and groups, with the reference's numeric ids. Passwords stay
  # locked; reed and sage have no login keys, and the nginx basic-auth user
  # lives only in the htpasswd file.
  users.groups = {
    prometheus.gid = 120;
    www-data.gid = 33;
    reed.gid = 1401;
    sage.gid = 1402;
    sudo = { };  # gid 27 is taken by NixOS's dialout group
    admin.gid = 117;
  };

  users.users = {
    prometheus = {
      uid = 112;
      group = "prometheus";
      isSystemUser = true;
      description = "Prometheus daemon";
      home = "/var/lib/prometheus";
      createHome = false;
    };
    www-data = {
      uid = 33;
      group = "www-data";
      isSystemUser = true;
      description = "www-data";
      home = "/var/www";
      createHome = false;
    };
    reed = {
      isNormalUser = true;
      uid = 1401;
      group = "reed";
      home = "/home/reed";
      homeMode = "750";
      hashedPassword = "!";
    };
    sage = {
      isNormalUser = true;
      uid = 1402;
      group = "sage";
      home = "/home/sage";
      homeMode = "750";
      hashedPassword = "!";
    };
  };

  security.sudo.extraConfig = ''
    %sudo ALL=(ALL:ALL) ALL
    %admin ALL=(ALL) ALL
  '';

  services.openssh = {
    enable = true;
    authorizedKeysFiles = [ ".ssh/authorized_keys" ".ssh/authorized_keys2" ];
    settings = {
      X11Forwarding = true;
      PrintMotd = false;
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
    # Host identity carried over from the reference so clients that pinned it
    # keep working. The keys are seeded under ./files/ssh.
    hostKeys = [
      { type = "rsa"; bits = 4096; path = "/etc/ssh/ssh_host_rsa_key"; }
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
      { type = "ecdsa"; path = "/etc/ssh/ssh_host_ecdsa_key"; }
    ];
  };

  services.nginx = {
    enable = true;
    user = "www-data";
    group = "www-data";
    logError = "/var/log/nginx/error.log";
    # Writes the live config to /etc/nginx/nginx.conf and reloads on change.
    enableReload = true;
    config = nginxConf;
  };

  # The TLS key stays root-only on disk; systemd hands the service a copy it can
  # read at $CREDENTIALS_DIRECTORY/server.key.
  systemd.services.nginx.serviceConfig.LoadCredential = [
    "server.key:/etc/node31/server.key"
  ];

  services.rsyslogd = {
    enable = true;
    defaultConfig = ''
      $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
      $RepeatedMsgReduction on
      $FileCreateMode 0640
      $Umask 0022

      auth,authpriv.*                 /var/log/auth.log
      *.*;auth,authpriv.none          -/var/log/syslog
      kern.*                          -/var/log/kern.log
      mail.*                          -/var/log/mail.log
      mail.err                        /var/log/mail.err
      *.emerg                         :omusrmsg:*
    '';
  };

  services.cron.enable = true;

  environment.systemPackages = with pkgs; [
    prometheus.cli           # promtool
    prometheus-alertmanager  # amtool
    apacheHttpd              # htpasswd
    # `nginx -t` and `nginx -s reload` act on /etc/nginx/nginx.conf, as on the
    # reference, instead of the store's built-in default configuration.
    (writeShellScriptBin "nginx" ''
      exec ${nginx}/bin/nginx -c /etc/nginx/nginx.conf "$@"
    '')
    curl
    jq
    python3
    git
    htop
    lsof
    nano
    rsync
    screen
    strace
    tcpdump
    tmux
    vim
    mtr
    netcat-openbsd
    smartmontools
    file
    less
  ];

  environment.etc = {
    "default/prometheus".text = ''
      ARGS="--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/metrics2 --web.listen-address=127.0.0.1:9090 --web.external-url=https://node31.n31.test/prometheus/ --web.route-prefix=/ --storage.tsdb.retention.time=730h --query.timeout=90s"
    '';
    "default/prometheus-alertmanager".text = ''
      ARGS="--config.file=/etc/prometheus/alertmanager.yml --storage.path=/var/lib/prometheus/alertmanager --web.listen-address=127.0.0.1:9093 --web.external-url=https://node31.n31.test/alertmanager/ --web.route-prefix=/ --cluster.listen-address= --data.retention=730h"
    '';
    "default/prometheus-blackbox-exporter".text = ''
      ARGS="--config.file=/etc/prometheus/blackbox.yml --web.listen-address=127.0.0.1:9115"
    '';
    "default/prometheus-node-exporter".text = ''
      ARGS="--web.listen-address=127.0.0.1:9100 --collector.textfile.directory=/var/lib/prometheus/node-exporter --collector.systemd --collector.processes --no-collector.timex"
    '';

    "nginx/htpasswd" = {
      source = files + "/htpasswd";
      mode = "0640";
      user = "root";
      group = "www-data";
    };

    "prometheus/prometheus.yml" = etcFile "prometheus/prometheus.yml";
    "prometheus/alertmanager.yml" = {
      source = files + "/prometheus/alertmanager.yml";
      mode = "0640";
      user = "root";
      group = "prometheus";
    };
    "prometheus/blackbox.yml" = etcFile "prometheus/blackbox.yml";
    "prometheus/rules/alerts-staged.yml" = etcFile "prometheus/rules/alerts-staged.yml";
    "prometheus/rules/alerts_default.yml" = etcFile "prometheus/rules/alerts_default.yml";
    "prometheus/rules/rules_old.yml.disabled" = etcFile "prometheus/rules/rules_old.yml.disabled";
    "prometheus/rules/rules_recording.yml" = etcFile "prometheus/rules/rules_recording.yml";
    "prometheus/targets/node_decom.yml" = etcFile "prometheus/targets/node_decom.yml";
    "prometheus/targets/node_main.yml" = etcFile "prometheus/targets/node_main.yml";
    "prometheus/targets/probe_auth_main.yml" = etcFile "prometheus/targets/probe_auth_main.yml";
    "prometheus/targets/probe_http_main.yml" = etcFile "prometheus/targets/probe_http_main.yml";
    "prometheus/targets/probe_icmp_main.yml" = etcFile "prometheus/targets/probe_icmp_main.yml";
    "prometheus/targets/probe_tcp_main.yml" = etcFile "prometheus/targets/probe_tcp_main.yml";
    "prometheus/alertmanager_templates/README.templates" =
      etcFile "prometheus/alertmanager_templates/README.templates";

    "ssh/ssh_host_rsa_key" = { source = files + "/ssh/ssh_host_rsa_key"; mode = "0600"; };
    "ssh/ssh_host_rsa_key.pub" = etcFile "ssh/ssh_host_rsa_key.pub";
    "ssh/ssh_host_ed25519_key" = { source = files + "/ssh/ssh_host_ed25519_key"; mode = "0600"; };
    "ssh/ssh_host_ed25519_key.pub" = etcFile "ssh/ssh_host_ed25519_key.pub";
    "ssh/ssh_host_ecdsa_key" = { source = files + "/ssh/ssh_host_ecdsa_key"; mode = "0600"; };
    "ssh/ssh_host_ecdsa_key.pub" = etcFile "ssh/ssh_host_ecdsa_key.pub";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus 0755 prometheus prometheus -"
    "d /var/lib/prometheus/alertmanager 0755 prometheus prometheus -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"
    "d /var/www 0755 root root -"
    "d /var/www/node31 0755 root root -"
    "C /var/www/node31/index.txt 0644 root root - ${files + "/index.txt"}"
  ];

  systemd.services = {
    prometheus = {
      description = "Monitoring system and time series database";
      after = [ "time-sync.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        EnvironmentFile = "/etc/default/prometheus";
        ExecStart = "${pkgs.prometheus}/bin/prometheus $ARGS";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        TimeoutStopSec = "20s";
        SendSIGKILL = "no";
        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        DeviceAllow = "/dev/null rw";
        DevicePolicy = "strict";
        LimitMEMLOCK = 0;
        LimitNOFILE = 8192;
        LockPersonality = "yes";
        MemoryDenyWriteExecute = "yes";
        NoNewPrivileges = "yes";
        PrivateDevices = "yes";
        PrivateTmp = "yes";
        PrivateUsers = "yes";
        ProtectControlGroups = "yes";
        ProtectHome = "yes";
        ProtectKernelModules = "yes";
        ProtectKernelTunables = "yes";
        ProtectSystem = "full";
        RemoveIPC = "yes";
        RestrictNamespaces = "yes";
        RestrictRealtime = "yes";
        SystemCallArchitectures = "native";
      };
    };

    prometheus-alertmanager = {
      description = "Alertmanager for prometheus";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        EnvironmentFile = "/etc/default/prometheus-alertmanager";
        ExecStart = "${pkgs.prometheus-alertmanager}/bin/alertmanager $ARGS";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        TimeoutStopSec = "20s";
        SendSIGKILL = "no";
      };
    };

    prometheus-blackbox-exporter = {
      description = "Blackbox exporter for Prometheus";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        EnvironmentFile = "/etc/default/prometheus-blackbox-exporter";
        ExecStart = "${pkgs.prometheus-blackbox-exporter}/bin/blackbox_exporter $ARGS";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };
    };

    prometheus-node-exporter = {
      description = "Prometheus exporter for machine metrics";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        EnvironmentFile = "/etc/default/prometheus-node-exporter";
        ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter $ARGS";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        TimeoutStopSec = "20s";
        SendSIGKILL = "no";
      };
    };

    alert-sink = {
      description = "Local alert webhook sink";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = alertSink;
        StateDirectory = "alert-sink";
        DynamicUser = "yes";
        Restart = "on-failure";
      };
    };

    node31-inventory = {
      description = "Write inventory metrics";
      path = [ pkgs.gawk pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = inventory;
      };
    };
  };

  systemd.timers.node31-inventory = {
    description = "Inventory metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5s";
      OnUnitActiveSec = "60s";
    };
  };
}
