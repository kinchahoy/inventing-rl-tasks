{ config, lib, pkgs, ... }:

# node31: monitoring host. Reference: Ubuntu 22.04 with nginx (TLS + basic auth
# front for Prometheus/Alertmanager), Prometheus, Alertmanager, blackbox and
# node exporters, a local alert webhook sink, and a 60s inventory textfile
# timer. Config files live under ./files and are copied verbatim from the
# reference; the service units, users and ports mirror the reference layout.

let
  # Prometheus stack packages, all realized in the pinned nixpkgs closure.
  prometheus = pkgs.prometheus;
  promtool = pkgs.prometheus.cli;
  alertmanager = pkgs.prometheus-alertmanager;
  blackbox = pkgs.prometheus-blackbox-exporter;
  nodeExporter = pkgs.prometheus-node-exporter;

  # Local alert webhook sink (same behaviour as the reference's Python service).
  alertSink = pkgs.writeScriptBin "alert-sink" (
    "#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./files/bin/alert-sink.py
  );

  # Writes node31 inventory metrics into the node exporter textfile directory.
  inventory = pkgs.writeScriptBin "node31-inventory" ''
    #!${pkgs.bash}/bin/bash
    out=/var/lib/prometheus/node-exporter
    users=$(${pkgs.busybox}/bin/awk -F: '$3 >= 1000 && $7 ~ /bash$/ {n++} END {print n+0}' /etc/passwd)
    {
      echo '# TYPE node31_inventory_users gauge'
      echo "node31_inventory_users $users"
      echo '# TYPE node31_inventory_info gauge'
      echo 'node31_inventory_info{role="monitor"} 1'
    } > "$out/node31_inventory.prom.tmp"
    ${pkgs.coreutils}/bin/mv "$out/node31_inventory.prom.tmp" "$out/node31_inventory.prom"
  '';

  # ExecReload sends SIGHUP; busybox is already in the closure.
  kill = "${pkgs.busybox}/bin/kill";
  nginxCaps = [
    "CAP_CHOWN" "CAP_DAC_OVERRIDE" "CAP_FOWNER" "CAP_SETGID" "CAP_SETUID"
    "CAP_NET_BIND_SERVICE" "CAP_SYS_RESOURCE"
  ];
in
{
  networking.hostName = "node31";
  networking.hosts."127.0.0.1" = [ "node31" "node31.n31.test" ];
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  boot.kernel.sysctl."net.ipv4.ping_group_range" = "0 2147483647";

  ###########################################################################
  # Accounts (identities as provisioned on the reference).
  ###########################################################################
  users.groups = {
    reed.gid = 1401;
    sage.gid = 1402;
    prometheus.gid = 120;
    www-data.gid = 33;
    sudo = { };
    admin = { };
  };

  users.users = {
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
    prometheus = {
      isSystemUser = true;
      uid = 112;
      group = "prometheus";
      description = "Prometheus daemon,,,";
      home = "/var/lib/prometheus";
      createHome = false;
      shell = "/usr/sbin/nologin";
    };
    www-data = {
      isSystemUser = true;
      uid = 33;
      group = "www-data";
      description = "www-data";
      home = "/var/www";
      createHome = false;
      shell = "/usr/sbin/nologin";
    };
    root = {
      description = lib.mkForce "root";
      hashedPassword = "!*";
      shell = "/bin/bash";
    };
  };

  # Ubuntu-style login shell paths, so passwd entries match the reference.
  users.defaultUserShell = "/bin/bash";
  systemd.services.sshd.aliases = [ "ssh.service" ];

  security.sudo.extraConfig = ''
    %sudo ALL=(ALL:ALL) ALL
    %admin ALL=(ALL) ALL
  '';

  ###########################################################################
  # SSH: root by key only, no password or keyboard-interactive logins.
  ###########################################################################
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
    };
  };

  ###########################################################################
  # nginx: 80 redirects to 443; 443 is TLS with basic auth (realm "node31"),
  # /healthz is open, and Prometheus/Alertmanager are reverse-proxied.
  ###########################################################################
  services.nginx = {
    enable = true;
    user = "www-data";
    group = "www-data";
    # The TLS certificate lives in /etc/node31 at runtime, so skip build-time nginx -t.
    validateConfigFile = false;
    # As on the reference: the master runs as root (it reads the 0600 key) and the
    # workers drop to www-data via the main-context `user` directive.
    prependConfig = "user www-data;";
    appendHttpConfig = ''
      gzip on;
      ssl_prefer_server_ciphers on;
    '';

    virtualHosts."redirect-http" = {
      default = true;
      serverName = "_";
      listen = [ { addr = "0.0.0.0"; port = 80; } ];
      locations."/".return = "301 https://$host$request_uri";
    };

    virtualHosts."node31.n31.test" = {
      default = true;
      serverName = "node31.n31.test";
      onlySSL = true;
      http2 = false;
      listen = [ { addr = "0.0.0.0"; port = 443; ssl = true; } ];
      sslCertificate = "/etc/node31/server.crt";
      sslCertificateKey = "/etc/node31/server.key";
      extraConfig = ''
        ssl_protocols TLSv1.2 TLSv1.3;
        auth_basic "node31";
        auth_basic_user_file /etc/nginx/htpasswd;
      '';
      locations."= /healthz" = {
        extraConfig = ''
          auth_basic off;
          default_type text/plain;
          return 200 "ok\n";
        '';
      };
      locations."= /" = {
        root = "/var/www/node31";
        extraConfig = ''
          try_files /index.txt =404;
          default_type text/plain;
        '';
      };
      locations."/prometheus/" = {
        proxyPass = "http://127.0.0.1:9090/";
        extraConfig = ''
          proxy_set_header Host $host;
        '';
      };
      locations."/alertmanager/" = {
        proxyPass = "http://127.0.0.1:9093/";
        extraConfig = ''
          proxy_set_header Host $host;
        '';
      };
    };
  };

  # The master process must run as root to read /etc/node31/server.key (0600), and
  # it needs chown/setuid to start workers as www-data. The reference's unit has
  # no sandbox, so drop the NixOS nginx seccomp filter and capability limits.
  systemd.services.nginx.serviceConfig = {
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    SystemCallFilter = lib.mkForce [ ];
    CapabilityBoundingSet = lib.mkForce nginxCaps;
    AmbientCapabilities = lib.mkForce nginxCaps;
  };

  ###########################################################################
  # Prometheus stack. Units mirror the reference's Debian units; ARGS come
  # from /etc/default/* exactly as before.
  ###########################################################################
  systemd.services.prometheus = {
    description = "Monitoring system and time series database";
    documentation = [ "https://prometheus.io/docs/introduction/overview/" "man:prometheus(1)" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      EnvironmentFile = "/etc/default/prometheus";
      ExecStart = "${prometheus}/bin/prometheus --web.console.libraries=/etc/prometheus/console_libraries --web.console.templates=/etc/prometheus/consoles $ARGS";
      ExecReload = "${kill} -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = false;
      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
      DeviceAllow = "/dev/null rw";
      DevicePolicy = "strict";
      LimitMEMLOCK = 0;
      LimitNOFILE = 8192;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "full";
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
    };
  };

  systemd.services.prometheus-alertmanager = {
    description = "Alertmanager for prometheus";
    documentation = [ "https://prometheus.io/docs/alerting/alertmanager/" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      EnvironmentFile = "/etc/default/prometheus-alertmanager";
      ExecStart = "${alertmanager}/bin/alertmanager $ARGS";
      ExecReload = "${kill} -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = false;
    };
  };

  systemd.services.prometheus-blackbox-exporter = {
    description = "Blackbox exporter for Prometheus";
    documentation = [ "https://prometheus.io/docs/introduction/overview/" "man:prometheus-blackbox-exporter(1)" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      EnvironmentFile = "/etc/default/prometheus-blackbox-exporter";
      ExecStart = "${blackbox}/bin/blackbox_exporter $ARGS";
      ExecReload = "${kill} -HUP $MAINPID";
    };
  };

  systemd.services.prometheus-node-exporter = {
    description = "Prometheus exporter for machine metrics";
    documentation = [ "https://github.com/prometheus/node_exporter" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      EnvironmentFile = "/etc/default/prometheus-node-exporter";
      ExecStart = "${nodeExporter}/bin/node_exporter $ARGS";
      ExecReload = "${kill} -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = false;
    };
  };

  # Inventory textfile metrics every 60s.
  systemd.services.node31-inventory = {
    description = "Write inventory metrics";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${inventory}/bin/node31-inventory";
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

  # Local alert webhook sink on 127.0.0.1:19190.
  systemd.services.alert-sink = {
    description = "Local alert webhook sink";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${alertSink}/bin/alert-sink";
      StateDirectory = "alert-sink";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  ###########################################################################
  # Files and directories.
  ###########################################################################
  environment.systemPackages = [
    prometheus
    promtool
    alertmanager
    pkgs.openssl
  ];

  environment.etc = {
    "default/prometheus".source = ./files/default/prometheus;
    "default/prometheus-alertmanager".source = ./files/default/prometheus-alertmanager;
    "default/prometheus-blackbox-exporter".source = ./files/default/prometheus-blackbox-exporter;
    "default/prometheus-node-exporter".source = ./files/default/prometheus-node-exporter;

    "prometheus/prometheus.yml".source = ./files/prometheus/prometheus.yml;
    "prometheus/blackbox.yml".source = ./files/prometheus/blackbox.yml;
    "prometheus/alertmanager.yml" = {
      source = ./files/prometheus/alertmanager.yml;
      user = "root";
      group = "prometheus";
      mode = "0640";
    };
    "prometheus/rules/alerts-staged.yml".source = ./files/prometheus/rules/alerts-staged.yml;
    "prometheus/rules/alerts_default.yml".source = ./files/prometheus/rules/alerts_default.yml;
    "prometheus/rules/rules_old.yml.disabled".source = ./files/prometheus/rules/rules_old.yml.disabled;
    "prometheus/rules/rules_recording.yml".source = ./files/prometheus/rules/rules_recording.yml;
    "prometheus/targets/node_decom.yml".source = ./files/prometheus/targets/node_decom.yml;
    "prometheus/targets/node_main.yml".source = ./files/prometheus/targets/node_main.yml;
    "prometheus/targets/probe_auth_main.yml".source = ./files/prometheus/targets/probe_auth_main.yml;
    "prometheus/targets/probe_http_main.yml".source = ./files/prometheus/targets/probe_http_main.yml;
    "prometheus/targets/probe_icmp_main.yml".source = ./files/prometheus/targets/probe_icmp_main.yml;
    "prometheus/targets/probe_tcp_main.yml".source = ./files/prometheus/targets/probe_tcp_main.yml;
    "prometheus/alertmanager_templates/README.templates".source = ./files/prometheus/alertmanager_templates/README.templates;
    "prometheus/console_libraries/README.consoles".source = ./files/prometheus/console_libraries/README.consoles;
    "prometheus/consoles/README.consoles".source = ./files/prometheus/consoles/README.consoles;

    "amtool/config.yml".source = ./files/amtool/config.yml;

    "nginx/htpasswd" = {
      source = ./files/nginx/htpasswd;
      user = "root";
      group = "www-data";
      mode = "0640";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus 0755 prometheus prometheus -"
    "d /var/lib/prometheus/alertmanager 0755 prometheus prometheus -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"
    "d /var/www 0755 root root -"
    "d /var/www/node31 0755 root root -"
    "C /var/www/node31/index.txt 0644 root root - ${./files/www/node31/index.txt}"
    "d /bin 0755 root root -"
    "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
    "d /usr/sbin 0755 root root -"
    "L+ /usr/sbin/nologin - - - - /run/current-system/sw/bin/nologin"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/alert-sink - - - - ${alertSink}/bin/alert-sink"
    "L+ /usr/local/bin/node31-inventory - - - - ${inventory}/bin/node31-inventory"
  ];
}
