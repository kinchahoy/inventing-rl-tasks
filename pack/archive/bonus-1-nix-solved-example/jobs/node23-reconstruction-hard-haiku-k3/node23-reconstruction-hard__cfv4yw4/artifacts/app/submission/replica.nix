{ lib, pkgs, ... }:
let
  # dnsdist's Lua policy is carried over verbatim from the reference node.
  dnsdistConf = pkgs.writeText "dnsdist.conf" (builtins.readFile ./dnsdist/dnsdist.conf);

  # Hosts exported through the recursor (export-etc-hosts).
  recursorHosts = pkgs.writeText "extrarecursorhosts" (builtins.readFile ./powerdns/extrarecursorhosts);

  recControl = "/run/current-system/sw/bin/rec_control";
in
{
  networking = {
    hostName = "node23";
    search = [ "n23.test" ];
    nameservers = [ "127.0.0.1" ];
    hosts = lib.mkForce {
      "127.0.0.1" = [ "node23" "node23.n23.test" ];
    };
    # Only the local recursor is listed in resolv.conf.
    resolvconf.useLocalResolver = false;
    # The reference exposes DNS on 53/tcp+udp, DoT on 853 and SSH on 22.
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 53 853 ];
      allowedUDPPorts = [ 53 ];
    };
  };

  i18n.defaultLocale = "C.UTF-8";
  time.timeZone = "Etc/UTC";

  # ---- Accounts -----------------------------------------------------------
  users.groups = {
    birch.gid = 1301;
    cedar.gid = 1302;
    _dnsdist.gid = 122;
    nsd.gid = lib.mkForce 120;
    pdns.gid = 121;
  };

  users.users = {
    root.shell = "/bin/bash";
    birch = {
      isNormalUser = true;
      uid = 1301;
      group = "birch";
      home = "/home/birch";
      homeMode = "750";
      shell = "/bin/bash";
      hashedPassword = "!";
      description = "";
    };
    cedar = {
      isNormalUser = true;
      uid = 1302;
      group = "cedar";
      home = "/home/cedar";
      homeMode = "750";
      shell = "/bin/bash";
      hashedPassword = "!";
      description = "";
    };
    _dnsdist = {
      isSystemUser = true;
      uid = 114;
      group = "_dnsdist";
      home = "/nonexistent";
      description = "";
      shell = lib.mkForce "/usr/sbin/nologin";
    };
    nsd.uid = lib.mkForce 112;
    nsd.shell = lib.mkForce "/usr/sbin/nologin";
    pdns = {
      isSystemUser = true;
      uid = 113;
      group = "pdns";
      home = "/var/spool/powerdns";
      description = "PowerDNS";
      shell = "/bin/false";
    };
  };

  # Operators: root (key only) plus the sudo rules for the rec_control helpers.
  security.sudo.extraRules = [
    {
      users = [ "birch" ];
      runAs = "root";
      commands = [
        { command = "${recControl} wipe-cache *"; options = [ "NOPASSWD" ]; }
        { command = "${recControl} get *"; options = [ "NOPASSWD" ]; }
        { command = "/usr/bin/rec_control wipe-cache *"; options = [ "NOPASSWD" ]; }
        { command = "/usr/bin/rec_control get *"; options = [ "NOPASSWD" ]; }
      ];
    }
    {
      users = [ "cedar" ];
      runAs = "root";
      commands = [
        { command = "${recControl} get *"; options = [ "NOPASSWD" ]; }
        { command = "/usr/bin/rec_control get *"; options = [ "NOPASSWD" ]; }
      ];
    }
    {
      groups = [ "sudo" ];
      runAs = "ALL:ALL";
      commands = [ "ALL" ];
    }
    {
      groups = [ "admin" ];
      runAs = "ALL";
      commands = [ "ALL" ];
    }
  ];

  # Stock Debian/Ubuntu paths that operators and scripts rely on.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/rec_control - - - - ${recControl}"
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /bin/false - - - - ${pkgs.coreutils}/bin/false"
    "L+ /usr/sbin/nologin - - - - ${pkgs.shadow}/bin/nologin"
  ];

  # ---- SSH ----------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkForce "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
    };
  };

  # ---- TLS material (provided by the harness) -----------------------------
  # dnsdist runs as _dnsdist and must read the key, as on the reference.
  environment.etc."node23/server.key" = {
    group = "_dnsdist";
    mode = lib.mkForce "0640";
  };

  environment.systemPackages = with pkgs; [
    bind.dnsutils
    openssl
    dnsdist
    nsd
    pdns-recursor
  ];

  # ---- Authoritative: NSD on 127.0.0.1:5301 -------------------------------
  services.nsd = {
    enable = true;
    interfaces = [ "127.0.0.1@5301" ];
    ipv4 = true;
    ipv6 = false;
    hideVersion = true;
    identity = "node23-auth";
    verbosity = 0;
    remoteControl.enable = false;
    zones = {
      "a23.test" = {
        data = builtins.readFile ./zones/a23.test.zone;
        provideXFR = [ "198.51.100.7 NOKEY" ];
      };
      "2.0.192.in-addr.arpa" = {
        data = builtins.readFile ./zones/192.0.2.rev.zone;
      };
    };
  };

  # ---- Recursor: PowerDNS Recursor on 127.0.0.1:5353 ----------------------
  services.pdns-recursor = {
    enable = true;
    dns.address = [ "127.0.0.1" ];
    dns.port = 5353;
    dns.allowFrom = [ "127.0.0.0/8" ];
    api.address = "127.0.0.1";
    api.port = 8082;
    api.allowFrom = [ "127.0.0.1" ];
    dnssecValidation = "off";
    exportHosts = true;
    forwardZones = {
      "a23.test" = "127.0.0.1:5301";
      "2.0.192.in-addr.arpa" = "127.0.0.1:5301";
    };
    settings = {
      recursor = {
        threads = 4;
        qname_minimization = false;
        version_string = "anonymous";
        etc_hosts_file = "${recursorHosts}";
        auth_zones = [
          {
            zone = "i23.test";
            file = "${./powerdns/i23.test.zone}";
          }
        ];
      };
      recordcache = {
        max_entries = 1000000;
        max_ttl = 3600;
        max_negative_ttl = 1800;
      };
      incoming = {
        reuseport = true;
        max_tcp_clients = 128;
        max_tcp_per_client = 100;
        tcp_timeout = 2;
      };
      webservice = {
        webserver = true;
        api_key = "lab-api-key";
      };
      logging.quiet = true;
    };
  };

  systemd.services.pdns-recursor.serviceConfig = {
    User = lib.mkForce "pdns";
    Group = lib.mkForce "pdns";
  };

  # ---- Load balancer / policy: dnsdist on 0.0.0.0:53 and :853 -------------
  systemd.services.dnsdist = {
    description = "DNS Loadbalancer";
    documentation = [ "man:dnsdist(1)" "https://dnsdist.org" ];
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "notify";
      ExecStartPre = "${pkgs.dnsdist}/bin/dnsdist --check-config --config ${dnsdistConf}";
      ExecStart = "${pkgs.dnsdist}/bin/dnsdist --supervised --disable-syslog --config ${dnsdistConf}";
      User = "_dnsdist";
      Group = "_dnsdist";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 5;
      StartLimitIntervalSec = 0;
      LimitNOFILE = 65536;
      TasksMax = 8192;
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      NoNewPrivileges = true;
      PrivateDevices = true;
    };
  };
}
