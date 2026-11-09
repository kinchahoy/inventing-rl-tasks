{ config, lib, pkgs, ... }:
let
  # Every file under files/prometheus is installed at /etc/prometheus/<same relative path>.
  promRoot = toString ./files/prometheus;
  promEtc = builtins.listToAttrs (map
    (p: lib.nameValuePair
      "prometheus/${lib.removePrefix (promRoot + "/") (toString p)}"
      { source = p; })
    (lib.filesystem.listFilesRecursive ./files/prometheus));

  nginxConf = ''
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

  alertSink = pkgs.writeScript "alert-sink"
    ("#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./files/bin/alert-sink.py);

  inventory = pkgs.writeScript "node31-inventory"
    ("#!${pkgs.runtimeShell}\n"
      + "export PATH=${lib.makeBinPath [ pkgs.gawk pkgs.coreutils ]}\n"
      + builtins.readFile ./files/bin/node31-inventory.sh);
in
{
  networking.hostName = "node31";
  networking.hosts."127.0.0.1" = [ "node31" "node31.n31.test" ];
  networking.firewall.enable = false;

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  # Reference's system python3 carried these libraries; keep them importable.
  # User-facing tools the reference image ships with.
  environment.systemPackages = with pkgs; [
    apacheHttpd
    bind.dnsutils
    git
    htop
    inetutils
    lsof
    moreutils
    openssl
    screen
    tmux
    vim
    wget
    (lib.hiPrio (pkgs.python3.withPackages (ps: with ps; [
      babel
      certifi
      jinja2
      jsonpatch
      jsonschema
      pyserial
      pyyaml
      requests
      setuptools
      urllib3
    ])))
  ];

  # ---- accounts -------------------------------------------------------------
  users.groups = {
    reed.gid = 1401;
    sage.gid = 1402;
    prometheus.gid = 120;
    www-data.gid = 33;
    sudo = { };
    admin.gid = 117;
  };

  users.users = {
    root = {
      description = lib.mkForce "root";
      shell = "/bin/bash";
    };
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
      description = "Prometheus daemon";
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
  };

  security.sudo.extraRules = [
    {
      groups = [ "sudo" "admin" ];
      runAs = "ALL:ALL";
      commands = [ { command = "ALL"; options = [ ]; } ];
    }
  ];

  # ---- ssh ------------------------------------------------------------------
  # PermitRootLogin = prohibit-password and root's authorized key come from the harness.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
      AcceptEnv = [ "LANG" "LC_*" ];
      Compression = "yes";
    };
    authorizedKeysFiles = [ ".ssh/authorized_keys" ".ssh/authorized_keys2" ];
    hostKeys = [
      { path = "/etc/ssh/ssh_host_rsa_key"; type = "rsa"; bits = 4096; }
      { path = "/etc/ssh/ssh_host_ecdsa_key"; type = "ecdsa"; }
      { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
    ];
  };

  # ---- nginx: http->https redirect, TLS front end, basic auth, reverse proxies --
  # Run the real nginx binary against /etc/nginx/nginx.conf (same layout as the reference)
  # instead of the NixOS nginx module, which would wrap and duplicate the top-level directives.

  systemd.services.nginx = {
    description = "A high performance web server and a reverse proxy server";
    documentation = [ "man:nginx(8)" ];
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      PIDFile = "/run/nginx.pid";
      ExecStartPre = "${pkgs.nginx}/bin/nginx -t -q -c /etc/nginx/nginx.conf";
      ExecStart = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf";
      ExecReload = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf -s reload";
      ExecStop = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf -s stop";
      TimeoutStopSec = "5s";
    };
  };

  # ---- monitoring stack -----------------------------------------------------
  systemd.services = {
    prometheus = {
      description = "Monitoring system and time series database";
      documentation = [ "https://prometheus.io/docs/introduction/overview/" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        Group = "prometheus";
        EnvironmentFile = "/etc/default/prometheus";
        ExecStart = "${pkgs.prometheus}/bin/prometheus $ARGS";
        ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
        TimeoutStopSec = "20s";
        SendSIGKILL = false;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "full";
      };
    };

    prometheus-alertmanager = {
      description = "Alertmanager for prometheus";
      documentation = [ "https://prometheus.io/docs/alerting/alertmanager/" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        Group = "prometheus";
        EnvironmentFile = "/etc/default/prometheus-alertmanager";
        ExecStart = "${pkgs.prometheus-alertmanager}/bin/alertmanager $ARGS";
        ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
        TimeoutStopSec = "20s";
        SendSIGKILL = false;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "full";
      };
    };

    prometheus-blackbox-exporter = {
      description = "Blackbox exporter for Prometheus";
      documentation = [ "https://prometheus.io/docs/introduction/overview/" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        Group = "prometheus";
        EnvironmentFile = "/etc/default/prometheus-blackbox-exporter";
        ExecStart = "${pkgs.prometheus-blackbox-exporter}/bin/blackbox_exporter $ARGS";
        ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "full";
      };
    };

    prometheus-node-exporter = {
      description = "Prometheus exporter for machine metrics";
      documentation = [ "https://github.com/prometheus/node_exporter" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        User = "prometheus";
        Group = "prometheus";
        EnvironmentFile = "/etc/default/prometheus-node-exporter";
        ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter $ARGS";
        ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
        TimeoutStopSec = "20s";
        SendSIGKILL = false;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "full";
      };
    };

    # Local webhook sink on 127.0.0.1:19190 (Alertmanager receivers and probe target).
    alert-sink = {
      description = "Local alert webhook sink";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "/usr/local/bin/alert-sink";
        StateDirectory = "alert-sink";
        DynamicUser = true;
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

  # ---- files ----------------------------------------------------------------
  environment.etc = promEtc // {
    "prometheus/alertmanager.yml" = {
      source = ./files/prometheus/alertmanager.yml;
      user = "root";
      group = "prometheus";
      mode = "0640";
    };

    "default/prometheus".source = ./files/default/prometheus;
    "default/prometheus-alertmanager".source = ./files/default/prometheus-alertmanager;
    "default/prometheus-blackbox-exporter".source = ./files/default/prometheus-blackbox-exporter;
    "default/prometheus-node-exporter".source = ./files/default/prometheus-node-exporter;

    "nginx/htpasswd" = {
      source = ./files/nginx/htpasswd;
      user = "root";
      group = "www-data";
      mode = "0640";
    };
    "nginx/conf.d/node31.conf".source = ./files/nginx/node31.conf;
    "nginx/nginx.conf".text = nginxConf;

    "amtool/config.yml".source = ./files/amtool/config.yml;
    "cinc/client.rb".source = ./files/cinc/client.rb;
  };

  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "d /usr/sbin 0755 root root -"
    "L+ /usr/sbin/nologin - - - - ${pkgs.shadow}/bin/nologin"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/alert-sink - - - - ${alertSink}"
    "L+ /usr/local/bin/node31-inventory - - - - ${inventory}"

    "d /var/lib/prometheus 0755 prometheus prometheus -"
    "d /var/lib/prometheus/metrics2 0755 prometheus prometheus -"
    "d /var/lib/prometheus/alertmanager 0755 prometheus prometheus -"
    "d /var/lib/prometheus/node-exporter 0755 root root -"

    "d /var/log/nginx 0755 root root -"
    "d /var/www 0755 root root -"
    "d /var/www/node31 0755 root root -"
    "C /var/www/node31/index.txt 0644 root root - ${./files/www/index.txt}"

    "d /etc/cinc/accepted_licenses 0755 root root -"
    "d /etc/cinc/client.d 0755 root root -"
    "d /etc/cinc/ohai/plugins 0755 root root -"
    "d /etc/cinc/trusted_certs 0755 root root -"
  ];
}
