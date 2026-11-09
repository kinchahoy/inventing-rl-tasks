{ config, lib, pkgs, ... }:
let
  files = ./files;

  # Small operator-facing helpers, installed at the same paths as on the reference.
  alertSink = pkgs.writeScript "alert-sink"
    ("#!${pkgs.python3}/bin/python3\n" + builtins.readFile (files + "/bin/alert-sink.py"));
  inventory = pkgs.writeScript "node31-inventory"
    (builtins.readFile (files + "/bin/node31-inventory.sh"));

  bashrc = files + "/home/bashrc";

  # nginx.conf is the verbatim reference configuration; only the MIME types path
  # is resolved to the store, since /etc/nginx/mime.types does not exist here.
  nginxConf = builtins.replaceStrings
    [ "@MIME_TYPES@" ]
    [ "${pkgs.nginx}/conf/mime.types" ]
    (builtins.readFile (files + "/nginx/nginx.conf"));

  promHardening = {
    AmbientCapabilities = "";
    CapabilityBoundingSet = "";
    LimitNOFILE = 8192;
    LimitMEMLOCK = 0;
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateTmp = true;
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

  promService = { description, documentation ? null, binary, envFile, extra ? {}, after ? [ ] }: {
    inherit description after;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      Group = "prometheus";
      EnvironmentFile = envFile;
      ExecStart = "${binary} $ARGS";
      ExecReload = "/bin/kill -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = false;
    } // extra;
  } // lib.optionalAttrs (documentation != null) { inherit documentation; };
in
{
  networking.hostName = "node31";
  # The reference applies no packet filtering (all iptables policies ACCEPT).
  networking.firewall.enable = false;
  networking.hosts."127.0.0.1" = [ "node31" "node31.n31.test" ];
  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  # ---------------------------------------------------------------- accounts
  users.groups = {
    reed = { gid = 1401; };
    sage = { gid = 1402; };
    prometheus = { gid = 120; };
    www-data = { gid = 33; };
  };

  users.users = {
    reed = {
      isNormalUser = true;
      uid = 1401;
      group = "reed";
      home = "/home/reed";
      homeMode = "750";
      shell = "/bin/bash";
      hashedPassword = "!";
    };
    sage = {
      isNormalUser = true;
      uid = 1402;
      group = "sage";
      home = "/home/sage";
      homeMode = "750";
      shell = "/bin/bash";
      hashedPassword = "!";
    };
    prometheus = {
      isSystemUser = true;
      uid = 112;
      group = "prometheus";
      home = "/var/lib/prometheus";
      createHome = false;
      description = "Prometheus daemon,,,";
      shell = "/run/current-system/sw/bin/nologin";
    };
    www-data = {
      isSystemUser = true;
      uid = 33;
      group = "www-data";
      home = "/var/www";
      createHome = false;
      description = "www-data";
      shell = "/run/current-system/sw/bin/nologin";
    };
  };

  environment.shells = [ "/bin/bash" ];

  system.activationScripts = {
    binbash = {
      deps = [ ];
      text = ''
        ln -sfn ${pkgs.bashInteractive}/bin/bash /bin/bash
      '';
    };
    operatorHomes = {
      deps = [ "users" ];
      text = ''
        for u in reed sage; do
          install -m 0644 -o "$u" -g "$u" ${bashrc} "/home/$u/.bashrc"
        done
      '';
    };
  };

  # ---------------------------------------------------------------- SSH
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    X11Forwarding = true;
    PrintMotd = false;
    AcceptEnv = [ "LANG" "LC_*" ];
  };

  # ---------------------------------------------------------------- HTTP / TLS
  services.nginx = {
    enable = true;
    user = "www-data";
    group = "www-data";
    validateConfigFile = false;
    config = nginxConf;
  };
  # The NixOS nginx unit runs the master as www-data, so the TLS key is made
  # readable by that group (0640). The reference keeps it root-only (0600);
  # this is the one deliberate permission difference.
  environment.etc."node31/server.key" = {
    group = lib.mkForce "www-data";
    mode = lib.mkForce "0640";
  };

  # ---------------------------------------------------------------- Prometheus stack
  environment.systemPackages = [
    pkgs.prometheus.cli # promtool
    pkgs.prometheus-alertmanager # amtool
  ];
  # Ubuntu's default PATH includes /usr/local/bin, where the operator helpers live.
  environment.localBinInPath = true;

  environment.etc = {
    "prometheus/prometheus.yml".source = files + "/prometheus/prometheus.yml";
    "prometheus/alertmanager.yml" = {
      source = files + "/prometheus/alertmanager.yml";
      user = "root";
      group = "prometheus";
      mode = "0640";
    };
    "prometheus/blackbox.yml".source = files + "/prometheus/blackbox.yml";
    "prometheus/rules/alerts_default.yml".source = files + "/prometheus/rules/alerts_default.yml";
    "prometheus/rules/alerts-staged.yml".source = files + "/prometheus/rules/alerts-staged.yml";
    "prometheus/rules/rules_recording.yml".source = files + "/prometheus/rules/rules_recording.yml";
    "prometheus/rules/rules_old.yml.disabled".source = files + "/prometheus/rules/rules_old.yml.disabled";
    "prometheus/targets/node_main.yml".source = files + "/prometheus/targets/node_main.yml";
    "prometheus/targets/node_decom.yml".source = files + "/prometheus/targets/node_decom.yml";
    "prometheus/targets/probe_http_main.yml".source = files + "/prometheus/targets/probe_http_main.yml";
    "prometheus/targets/probe_auth_main.yml".source = files + "/prometheus/targets/probe_auth_main.yml";
    "prometheus/targets/probe_tcp_main.yml".source = files + "/prometheus/targets/probe_tcp_main.yml";
    "default/prometheus".source = files + "/default/prometheus";
    "default/prometheus-alertmanager".source = files + "/default/prometheus-alertmanager";
    "default/prometheus-blackbox-exporter".source = files + "/default/prometheus-blackbox-exporter";
    "default/prometheus-node-exporter".source = files + "/default/prometheus-node-exporter";
    "nginx/htpasswd" = {
      source = files + "/nginx/htpasswd";
      user = "root";
      group = "www-data";
      mode = "0640";
    };
  };

  systemd.services = {
    prometheus = promService {
      description = "Monitoring system and time series database";
      documentation = [ "https://prometheus.io/docs/introduction/overview/" ];
      binary = "${pkgs.prometheus}/bin/prometheus";
      envFile = "/etc/default/prometheus";
      after = [ "time-sync.target" ];
      extra = promHardening;
    };

    prometheus-alertmanager = promService {
      description = "Alertmanager for prometheus";
      documentation = [ "https://prometheus.io/docs/alerting/alertmanager/" ];
      binary = "${pkgs.prometheus-alertmanager}/bin/alertmanager";
      envFile = "/etc/default/prometheus-alertmanager";
    };

    prometheus-blackbox-exporter = promService {
      description = "Blackbox exporter for Prometheus";
      documentation = [ "https://prometheus.io/docs/introduction/overview/" ];
      binary = "${pkgs.prometheus-blackbox-exporter}/bin/blackbox_exporter";
      envFile = "/etc/default/prometheus-blackbox-exporter";
    };

    prometheus-node-exporter = promService {
      description = "Prometheus exporter for machine metrics";
      documentation = [ "https://github.com/prometheus/node_exporter" ];
      binary = "${pkgs.prometheus-node-exporter}/bin/node_exporter";
      envFile = "/etc/default/prometheus-node-exporter";
    };

    alert-sink = {
      description = "Local alert webhook sink";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${alertSink}";
        StateDirectory = "alert-sink";
        DynamicUser = true;
        Restart = "on-failure";
      };
    };

    node31-inventory = {
      description = "Write inventory metrics";
      path = [ pkgs.gawk pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${inventory}";
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

  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus 0755 112 120 -"
    "d /var/lib/prometheus/alertmanager 0755 112 120 -"
    "d /var/lib/prometheus/metrics2 0755 112 120 -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"
    "d /var/www/node31 0755 root root -"
    "C /var/www/node31/index.txt 0644 root root - ${files + "/www/index.txt"}"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/alert-sink - - - - ${alertSink}"
    "L+ /usr/local/bin/node31-inventory - - - - ${inventory}"
  ];
}
