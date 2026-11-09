{ lib, pkgs, ... }:

let
  # Seeded configuration, copied verbatim from the reference node.
  promFile = name: ./files/prometheus + "/${name}";

  promEtc = lib.listToAttrs (map
    (name: lib.nameValuePair "prometheus/${name}" { source = promFile name; })
    [
      "prometheus.yml"
      "blackbox.yml"
      "rules/rules_recording.yml"
      "rules/alerts_default.yml"
      "rules/alerts-staged.yml"
      "rules/rules_old.yml.disabled"
      "targets/node_main.yml"
      "targets/node_decom.yml"
      "targets/probe_http_main.yml"
      "targets/probe_auth_main.yml"
      "targets/probe_tcp_main.yml"
    ]);

  alertSink = pkgs.writeScriptBin "alert-sink"
    ("#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./files/alert-sink.py);

  inventory = pkgs.writeTextFile {
    name = "node31-inventory";
    executable = true;
    destination = "/bin/node31-inventory";
    text = ''
      #!${pkgs.runtimeShell}
      export PATH=${lib.makeBinPath [ pkgs.gawk pkgs.coreutils ]}
    '' + builtins.readFile ./files/node31-inventory.sh;
  };

  nginxConf = pkgs.writeText "nginx.conf" ''
    user www-data;
    worker_processes auto;
    pid /run/nginx.pid;

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
    	error_log /var/log/nginx/error.log;

    	gzip on;

    	include /etc/nginx/conf.d/*.conf;
    }
  '';

  nginxBin = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf";

  # Operator-facing nginx command: default to the node config like the reference does.
  nginxCli = pkgs.writeShellScriptBin "nginx" ''
    exec ${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf "$@"
  '';

  # Compatibility names for the binaries that the reference node exposes.
  compatBins = pkgs.runCommand "prometheus-compat-bins" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.prometheus-alertmanager}/bin/alertmanager $out/bin/prometheus-alertmanager
    ln -s ${pkgs.prometheus-blackbox-exporter}/bin/blackbox_exporter $out/bin/prometheus-blackbox-exporter
    ln -s ${pkgs.prometheus-node-exporter}/bin/node_exporter $out/bin/prometheus-node-exporter
  '';

  hardenedPrometheus = {
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
in
{
  networking.hostName = "node31";
  networking.hosts."127.0.0.1" = [ "node31.n31.test" ];
  networking.firewall.enable = false;
  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  users.groups = {
    # NixOS defaults collide with these reference GIDs; pin them to the reference values.
    messagebus.gid = lib.mkForce 105;
    dialout.gid = lib.mkForce 20;
    lp.gid = lib.mkForce 7;
    adm.gid = lib.mkForce 4;
    sudo.gid = 27;
    admin.gid = 117;
    www-data.gid = 33;
    prometheus.gid = 120;
    reed.gid = 1401;
    sage.gid = 1402;
  };

  users.users = {
    root.shell = "/bin/bash";
    www-data = {
      uid = 33;
      group = "www-data";
      isSystemUser = true;
      home = "/var/www";
      createHome = false;
      description = "www-data";
      shell = "/usr/sbin/nologin";
    };
    prometheus = {
      uid = 112;
      group = "prometheus";
      isSystemUser = true;
      home = "/var/lib/prometheus";
      createHome = false;
      description = "Prometheus daemon";
      shell = "/usr/sbin/nologin";
    };
    reed = {
      isNormalUser = true;
      uid = 1401;
      group = "reed";
      home = "/home/reed";
      createHome = true;
      homeMode = "750";
      shell = "/bin/bash";
    };
    sage = {
      isNormalUser = true;
      uid = 1402;
      group = "sage";
      home = "/home/sage";
      createHome = true;
      homeMode = "750";
      shell = "/bin/bash";
    };
  };

  # Same file routing as the reference's Ubuntu rsyslog defaults (auth.log, syslog, kern.log, mail.err).
  services.rsyslogd = {
    enable = true;
    defaultConfig = ''
      auth,authpriv.*			/var/log/auth.log
      *.*;auth,authpriv.none		-/var/log/syslog
      kern.*				-/var/log/kern.log
      mail.err			/var/log/mail.err
    '';
  };

  security.sudo.extraConfig = ''
    %sudo ALL=(ALL:ALL) ALL
    %admin ALL=(ALL) ALL
  '';

  services.openssh = {
    enable = true;
    # The reference reads ~/.ssh/authorized_keys first; keep the NixOS key directory last so the harness root key still works.
    authorizedKeysFiles = lib.mkForce [ ".ssh/authorized_keys" ".ssh/authorized_keys2" "/etc/ssh/authorized_keys.d/%u" ];
    hostKeys = [
      { type = "ecdsa"; path = "/etc/ssh/ssh_host_ecdsa_key"; }
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
      { type = "rsa"; bits = 3072; path = "/etc/ssh/ssh_host_rsa_key"; }
    ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
    };
  };

  environment.systemPackages = [
    nginxCli
    pkgs.prometheus
    pkgs.prometheus.cli
    pkgs.prometheus-alertmanager
    compatBins
  ];

  environment.etc = promEtc // {
    "prometheus/alertmanager.yml" = {
      source = ./files/prometheus/alertmanager.yml;
      user = "root";
      group = "prometheus";
      mode = "0640";
    };

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

    "nginx/nginx.conf".source = nginxConf;
    "nginx/conf.d/node31.conf".source = ./files/nginx/node31.conf;
    "nginx/htpasswd" = {
      text = "pine:$apr1$r1aohrVP$g4QcwLIdrLRryMvZbkB1t.\n";
      user = "root";
      group = "www-data";
      mode = "0640";
    };
  };

  systemd.tmpfiles.rules = [
    # Ubuntu-style shell paths so account entries match the reference.
    "d /usr/sbin 0755 root root -"
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /usr/sbin/nologin - - - - ${pkgs.shadow}/bin/nologin"
    "d /var/lib/prometheus 0755 prometheus prometheus -"
    "d /var/lib/prometheus/alertmanager 0755 prometheus prometheus -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"
    "d /var/log/nginx 0755 root adm -"
    "d /var/cache/nginx 0700 www-data www-data -"
    "d /var/www/node31 0755 root root -"
    "C /var/www/node31/index.txt 0644 root root - ${pkgs.writeText "index.txt" "node31 monitoring\n"}"
  ];

  systemd.services = {
    nginx = {
      description = "A high performance web server and a reverse proxy server";
      documentation = [ "man:nginx(8)" ];
      after = [ "network.target" "nss-lookup.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "forking";
        PIDFile = "/run/nginx.pid";
        ExecStartPre = "${nginxBin} -t -q -g 'daemon on; master_process on;'";
        ExecStart = "${nginxBin} -g 'daemon on; master_process on;'";
        ExecReload = "${nginxBin} -g 'daemon on; master_process on;' -s reload";
        ExecStop = "-${nginxBin} -s quit";
        TimeoutStopSec = 5;
        KillMode = "mixed";
      };
    };

    prometheus = {
      description = "Monitoring system and time series database";
      documentation = [ "https://prometheus.io/docs/introduction/overview/" "man:prometheus(1)" ];
      after = [ "time-sync.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = hardenedPrometheus // {
        Restart = "on-failure";
        User = "prometheus";
        EnvironmentFile = "/etc/default/prometheus";
        ExecStart = "${pkgs.prometheus}/bin/prometheus $ARGS";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        TimeoutStopSec = "20s";
        SendSIGKILL = "no";
      };
    };

    prometheus-alertmanager = {
      description = "Alertmanager for prometheus";
      documentation = [ "https://prometheus.io/docs/alerting/alertmanager/" ];
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
      documentation = [ "https://prometheus.io/docs/introduction/overview/" "man:prometheus-blackbox-exporter(1)" ];
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
      documentation = [ "https://github.com/prometheus/node_exporter" ];
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

    node31-inventory = {
      description = "Write inventory metrics";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${inventory}/bin/node31-inventory";
      };
    };

    alert-sink = {
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
