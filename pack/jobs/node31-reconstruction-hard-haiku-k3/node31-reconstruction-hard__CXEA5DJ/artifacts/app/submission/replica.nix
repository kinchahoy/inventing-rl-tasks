{ config, lib, pkgs, ... }:
let
  inventory = pkgs.writeShellScript "node31-inventory" (builtins.readFile ./files/node31-inventory.sh);
  alertSink = ./files/alert-sink.py;
  prometheusDirs = "/var/lib/prometheus";
in {
  ##
  # Identity and locale
  ##

  networking.hostName = "node31";
  networking.hosts = lib.mkForce {
    "127.0.0.1" = [ "localhost" "node31" "node31.n31.test" ];
    "::1" = [ "localhost" "ip6-localhost" "ip6-loopback" ];
  };
  networking.firewall.enable = false;

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";


  ##
  # Accounts (uids/gids and home layout as provisioned on the reference)
  ##

  users.groups.reed.gid = 1401;
  users.groups.sage.gid = 1402;
  users.users.root.shell = "/bin/bash";
  users.users.reed = {
    isNormalUser = true;
    uid = 1401;
    group = "reed";
    home = "/home/reed";
    homeMode = "750";
    shell = "/bin/bash";
  };
  users.users.sage = {
    isNormalUser = true;
    uid = 1402;
    group = "sage";
    home = "/home/sage";
    homeMode = "750";
    shell = "/bin/bash";
  };

  users.groups.www-data.gid = 33;
  users.users.www-data = {
    uid = 33;
    group = "www-data";
    home = "/var/www";
    isSystemUser = true;
  };

  users.groups.prometheus.gid = 120;
  users.users.prometheus = {
    uid = 112;
    group = "prometheus";
    home = prometheusDirs;
    isSystemUser = true;
  };

  ##
  # SSH: root by key only, no passwords, no keyboard-interactive
  ##

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
  };

  environment.systemPackages = with pkgs; [
    python3 curl jq util-linux
    prometheus.cli          # promtool
    prometheus-alertmanager # amtool
  ];

  ##
  # Seeded configuration (same paths as the reference)
  ##

  environment.etc = {
    "prometheus/prometheus.yml".source = ./files/prometheus/prometheus.yml;
    "prometheus/blackbox.yml".source = ./files/prometheus/blackbox.yml;
    "prometheus/alertmanager.yml" = {
      source = ./files/prometheus/alertmanager.yml;
      user = "root";
      group = "prometheus";
      mode = "0640";
    };
    "prometheus/rules/alerts_default.yml".source = ./files/prometheus/rules/alerts_default.yml;
    "prometheus/rules/rules_recording.yml".source = ./files/prometheus/rules/rules_recording.yml;
    "prometheus/rules/alerts-staged.yml".source = ./files/prometheus/rules/alerts-staged.yml;
    "prometheus/rules/rules_old.yml.disabled".source = ./files/prometheus/rules/rules_old.yml.disabled;
    "prometheus/targets/node_decom.yml".source = ./files/prometheus/targets/node_decom.yml;
    "prometheus/targets/node_main.yml".source = ./files/prometheus/targets/node_main.yml;
    "prometheus/targets/probe_auth_main.yml".source = ./files/prometheus/targets/probe_auth_main.yml;
    "prometheus/targets/probe_http_main.yml".source = ./files/prometheus/targets/probe_http_main.yml;
    "prometheus/targets/probe_icmp_main.yml".source = ./files/prometheus/targets/probe_icmp_main.yml;
    "prometheus/targets/probe_tcp_main.yml".source = ./files/prometheus/targets/probe_tcp_main.yml;

    "default/prometheus".source = ./files/default/prometheus;
    "default/prometheus-alertmanager".source = ./files/default/prometheus-alertmanager;
    "default/prometheus-blackbox-exporter".source = ./files/default/prometheus-blackbox-exporter;
    "default/prometheus-node-exporter".source = ./files/default/prometheus-node-exporter;

    "nginx/nginx.conf".source = ./files/nginx/nginx.conf;
    "nginx/mime.types".source = "${pkgs.nginx}/conf/mime.types";
    "nginx/conf.d/node31.conf".source = ./files/nginx/node31.conf;
    "nginx/htpasswd" = {
      source = ./files/nginx/htpasswd;
      user = "root";
      group = "www-data";
      mode = "0640";
    };
  };

  systemd.tmpfiles.rules = [
    # Reference exposes bash at /bin/bash (login shells for root, reed, sage).
    # Created in sysinit so it exists before sshd checks the login shell.
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "d /var/log/nginx 0755 root root -"
    "d /var/cache/nginx 0750 www-data www-data -"
    "d /var/www 0755 root root -"
    "d /var/www/node31 0755 root root -"
    "C /var/www/node31/index.txt 0644 root root - ${./files/www/index.txt}"
    "d /var/lib/prometheus 0755 prometheus prometheus -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"
    # Reference installs these tools under /usr/bin as well.
    "L+ /usr/bin/python3 - - - - ${pkgs.python3}/bin/python3"
    "L+ /usr/bin/curl - - - - ${pkgs.curl}/bin/curl"
    "L+ /usr/bin/jq - - - - ${pkgs.jq}/bin/jq"
    "L+ /usr/bin/promtool - - - - ${pkgs.prometheus.cli}/bin/promtool"
    "L+ /usr/bin/amtool - - - - ${pkgs.prometheus-alertmanager}/bin/amtool"
    "L+ /usr/local/bin/node31-inventory - - - - ${inventory}"
    "L+ /usr/local/bin/alert-sink - - - - ${alertSink}"
  ];

  ##
  # Web: nginx on 80 (redirect) and 443 (TLS + basic auth)
  ##

  systemd.services.nginx = {
    description = "A high performance web server and a reverse proxy server";
    documentation = [ "man:nginx(8)" ];
    after = [ "network.target" "nss-lookup.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      PIDFile = "/run/nginx.pid";
      ExecStartPre = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf -t -q -g 'daemon on; master_process on;'";
      ExecStart = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf -g 'daemon on; master_process on;'";
      ExecReload = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf -g 'daemon on; master_process on;' -s reload";
      ExecStop = "-${pkgs.coreutils}/bin/kill -s QUIT $MAINPID";
      TimeoutStopSec = 5;
      KillMode = "mixed";
    };
  };

  ##
  # Monitoring stack (real nixpkgs binaries, ARGS read from /etc/default as on the reference)
  ##

  systemd.services.prometheus = {
    description = "Monitoring system and time series database";
    documentation = [ "https://prometheus.io/docs/introduction/overview/" ];
    after = [ "time-sync.target" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      Group = "prometheus";
      StateDirectory = "prometheus";
      EnvironmentFile = "/etc/default/prometheus";
      ExecStart = "${pkgs.prometheus}/bin/prometheus $ARGS";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = "no";
      LimitNOFILE = 8192;
      NoNewPrivileges = true;
      ProtectSystem = "full";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictRealtime = true;
    };
  };

  systemd.services.prometheus-alertmanager = {
    description = "Alertmanager for prometheus";
    documentation = [ "https://prometheus.io/docs/alerting/alertmanager/" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      Group = "prometheus";
      StateDirectory = "prometheus/alertmanager";
      EnvironmentFile = "/etc/default/prometheus-alertmanager";
      ExecStart = "${pkgs.prometheus-alertmanager}/bin/alertmanager $ARGS";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = "no";
      NoNewPrivileges = true;
      ProtectSystem = "full";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  systemd.services.prometheus-blackbox-exporter = {
    description = "Blackbox exporter for Prometheus";
    documentation = [ "https://prometheus.io/docs/introduction/overview/" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      Group = "prometheus";
      EnvironmentFile = "/etc/default/prometheus-blackbox-exporter";
      ExecStart = "${pkgs.prometheus-blackbox-exporter}/bin/blackbox_exporter $ARGS";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      # ICMP probes need raw sockets.
      AmbientCapabilities = [ "CAP_NET_RAW" ];
      CapabilityBoundingSet = [ "CAP_NET_RAW" ];
      NoNewPrivileges = true;
    };
  };

  systemd.services.prometheus-node-exporter = {
    description = "Prometheus exporter for machine metrics";
    documentation = [ "https://github.com/prometheus/node_exporter" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      Group = "prometheus";
      EnvironmentFile = "/etc/default/prometheus-node-exporter";
      ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter $ARGS";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = "no";
      NoNewPrivileges = true;
    };
  };

  ##
  # Local services
  ##

  systemd.services.alert-sink = {
    description = "Local alert webhook sink";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${alertSink}";
      StateDirectory = "alert-sink";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  systemd.services.node31-inventory = {
    description = "Write inventory metrics";
    path = [ pkgs.gawk pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${inventory}";
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
