{ config, lib, pkgs, ... }:
let
  # Source trees copied verbatim from the inspected machine's /etc/prometheus.
  promFiles = dir: prefix:
    lib.concatLists (lib.mapAttrsToList (name: type:
      if type == "directory" then promFiles (dir + "/${name}") "${prefix}/${name}"
      else [ (lib.nameValuePair "${prefix}/${name}" { source = dir + "/${name}"; }) ]
    ) (builtins.readDir dir));

  alertSink = pkgs.writeTextFile {
    name = "alert-sink";
    executable = true;
    destination = "/bin/alert-sink";
    text = "#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./files/alert-sink.py;
  };

  inventory = pkgs.writeTextFile {
    name = "node31-inventory";
    executable = true;
    destination = "/bin/node31-inventory";
    text = "#!${pkgs.runtimeShell}\nexport PATH=${lib.makeBinPath [ pkgs.gawk pkgs.coreutils ]}\n"
      + builtins.readFile ./files/node31-inventory.sh;
  };

  promEnvFile = name: text: {
    "default/${name}".text = text;
  };

  promService = { description, envFile, exec, extra ? {} }: {
    inherit description;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "on-failure";
      User = "prometheus";
      EnvironmentFile = "/etc/default/${envFile}";
      ExecStart = exec;
      ExecReload = "${pkgs.procps}/bin/kill -HUP $MAINPID";
      TimeoutStopSec = "20s";
      SendSIGKILL = "no";
    } // extra;
  };
in
{
  networking.hostName = "node31";
  networking.hosts."127.0.0.1" = [ "node31" "node31.n31.test" ];
  networking.firewall.enable = false;

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  environment.shellAliases = {
    ll = "ls -alF";
    la = "ls -A";
    l = "ls -CF";
  };

  environment.systemPackages = [
    pkgs.prometheus
    pkgs.prometheus.cli
    pkgs.prometheus-alertmanager
    pkgs.prometheus-blackbox-exporter
    pkgs.prometheus-node-exporter
  ];

  # Accounts keep the identities the reference was provisioned with.
  users.groups = {
    adm.gid = lib.mkForce 4;
    dialout.gid = lib.mkForce 20;
    lp.gid = lib.mkForce 7;
    messagebus.gid = lib.mkForce 105;
    sudo.gid = lib.mkForce 27;
    admin.gid = lib.mkForce 117;
    syslog.gid = lib.mkForce 111;
    www-data.gid = lib.mkForce 33;
    prometheus.gid = lib.mkForce 120;
    reed.gid = lib.mkForce 1401;
    sage.gid = lib.mkForce 1402;
  };

  users.users = {
    www-data = {
      uid = 33;
      group = "www-data";
      isSystemUser = true;
      home = "/var/www";
      description = "www-data";
    };
    prometheus = {
      uid = 112;
      group = "prometheus";
      isSystemUser = true;
      home = "/var/lib/prometheus";
      description = "Prometheus daemon";
    };
    reed = {
      uid = 1401;
      isNormalUser = true;
      group = "reed";
      home = "/home/reed";
      homeMode = "750";
      hashedPassword = "!";
      subUidRanges = [ { startUid = 100000; count = 65536; } ];
      subGidRanges = [ { startGid = 100000; count = 65536; } ];
    };
    sage = {
      uid = 1402;
      isNormalUser = true;
      group = "sage";
      home = "/home/sage";
      homeMode = "750";
      hashedPassword = "!";
      subUidRanges = [ { startUid = 165536; count = 65536; } ];
      subGidRanges = [ { startGid = 165536; count = 65536; } ];
    };
  };

  security.sudo.extraConfig = ''
    %sudo ALL=(ALL:ALL) ALL
    %admin ALL=(ALL) ALL
  '';

  services.openssh.settings = {
    X11Forwarding = true;
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PrintMotd = false;
  };

  services.cron.enable = true;

  services.rsyslogd = {
    enable = true;
    defaultConfig = ''
      auth,authpriv.*			/var/log/auth.log
      *.*;auth,authpriv.none		-/var/log/syslog
      kern.*				-/var/log/kern.log
      mail.*				-/var/log/mail.log
      mail.err			/var/log/mail.err
      *.emerg				:omusrmsg:*
    '';
  };

  # The TLS key is root-only; systemd hands nginx a copy readable by its www-data user.
  systemd.services.nginx.serviceConfig.LoadCredential = [ "server.key:/etc/node31/server.key" ];

  services.nginx = {
    enable = true;
    user = "www-data";
    group = "www-data";
    config = builtins.readFile ./files/nginx/nginx.conf;
  };

  environment.etc = {
    "nginx/nginx.conf".source = ./files/nginx/nginx.conf;
    "nginx/mime.types".source = "${pkgs.nginx}/conf/mime.types";
    "nginx/conf.d/node31.conf".source = ./files/nginx/node31.conf;
    "nginx/htpasswd" = {
      source = ./files/nginx/htpasswd;
      user = "root";
      group = "www-data";
      mode = "0640";
    };
    "amtool/config.yml".source = ./files/amtool-config.yml;
    "prometheus/alertmanager.yml" = {
      source = ./files/prometheus/alertmanager.yml;
      user = "root";
      group = "prometheus";
      mode = "0640";
    };
  } // builtins.listToAttrs (
    builtins.filter (e: e.name != "prometheus/alertmanager.yml")
      (promFiles ./files/prometheus "prometheus"))
    // (promEnvFile "prometheus" ''
      ARGS="--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/metrics2 --web.listen-address=127.0.0.1:9090 --web.external-url=https://node31.n31.test/prometheus/ --web.route-prefix=/ --storage.tsdb.retention.time=730h --query.timeout=90s"
    '')
    // (promEnvFile "prometheus-alertmanager" ''
      ARGS="--config.file=/etc/prometheus/alertmanager.yml --storage.path=/var/lib/prometheus/alertmanager --web.listen-address=127.0.0.1:9093 --web.external-url=https://node31.n31.test/alertmanager/ --web.route-prefix=/ --cluster.listen-address= --data.retention=730h"
    '')
    // (promEnvFile "prometheus-blackbox-exporter" ''
      ARGS="--config.file=/etc/prometheus/blackbox.yml --web.listen-address=127.0.0.1:9115"
    '')
    // (promEnvFile "prometheus-node-exporter" ''
      ARGS="--web.listen-address=127.0.0.1:9100 --collector.textfile.directory=/var/lib/prometheus/node-exporter --collector.systemd --collector.processes --no-collector.timex"
    '');

  services.logrotate.settings = {
    nginx = {
      files = "/var/log/nginx/*.log";
      frequency = "daily";
      rotate = 14;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "0640 www-data adm";
      sharedscripts = true;
      postrotate = "${pkgs.systemd}/bin/systemctl kill -s USR1 nginx.service";
    };
    prometheus = {
      files = "/var/log/prometheus/*.log";
      frequency = "weekly";
      rotate = 10;
      copytruncate = true;
      compress = true;
      delaycompress = true;
      notifempty = true;
      missingok = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/www 0755 root root -"
    "d /var/www/node31 0755 root root -"
    "C /var/www/node31/index.txt 0644 root root - ${./files/www/index.txt}"
    "d /var/log/nginx 0755 root adm -"
    "d /var/log/prometheus 0755 root root -"
    "d /etc/nginx/sites-enabled 0755 root root -"
    "d /var/lib/prometheus 0755 prometheus prometheus -"
    "d /var/lib/prometheus/alertmanager 0755 prometheus prometheus -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"
    "L+ /usr/local/bin/alert-sink - - - - ${alertSink}/bin/alert-sink"
    "L+ /usr/local/bin/node31-inventory - - - - ${inventory}/bin/node31-inventory"
  ];

  systemd.services = {
    prometheus = promService {
      description = "Monitoring system and time series database";
      envFile = "prometheus";
      exec = "${pkgs.prometheus}/bin/prometheus $ARGS";
      extra = {
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

    prometheus-alertmanager = promService {
      description = "Alertmanager for prometheus";
      envFile = "prometheus-alertmanager";
      exec = "${pkgs.prometheus-alertmanager}/bin/alertmanager $ARGS";
    };

    prometheus-blackbox-exporter = promService {
      description = "Blackbox exporter for Prometheus";
      envFile = "prometheus-blackbox-exporter";
      exec = "${pkgs.prometheus-blackbox-exporter}/bin/blackbox_exporter $ARGS";
    };

    prometheus-node-exporter = promService {
      description = "Prometheus exporter for machine metrics";
      envFile = "prometheus-node-exporter";
      exec = "${pkgs.prometheus-node-exporter}/bin/node_exporter $ARGS";
      extra = { TimeoutStopSec = "20s"; };
    };

    alert-sink = {
      description = "Local alert webhook sink";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${alertSink}/bin/alert-sink";
        DynamicUser = true;
        StateDirectory = "alert-sink";
        Restart = "on-failure";
      };
    };

    node31-inventory = {
      description = "Write inventory metrics";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/usr/local/bin/node31-inventory";
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
