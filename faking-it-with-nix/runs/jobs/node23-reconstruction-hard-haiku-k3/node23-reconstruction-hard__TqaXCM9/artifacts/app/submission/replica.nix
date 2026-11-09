{ config, lib, pkgs, ... }:
let
  recursorPort = 5353;
  authPort = 5301;
  dnsdistConf = ./files/dnsdist.conf;
  zoneFile = name: ./zones + "/${name}";
in
{
  # --- identity -----------------------------------------------------------
  networking.hostName = "node23";
  networking.domain = "n23.test";
  networking.hosts."127.0.0.1" = [ "node23" "node23.n23.test" ];
  networking.nameservers = [ "127.0.0.1" ];
  networking.search = [ "n23.test" ];
  services.resolved.enable = false;

  # The reference runs ufw in an inactive state: no packet filtering.
  networking.firewall.enable = false;

  # --- accounts -----------------------------------------------------------
  users.groups = {
    birch.gid = 1301;
    cedar.gid = 1302;
    sudo = { };
    admin = { };
    pdns = { };
    _dnsdist = { };
  };

  users.users.birch = {
    isNormalUser = true;
    uid = 1301;
    group = "birch";
    home = "/home/birch";
    description = "birch";
  };

  users.users.cedar = {
    isNormalUser = true;
    uid = 1302;
    group = "cedar";
    home = "/home/cedar";
    description = "cedar";
  };

  users.users.pdns = {
    isSystemUser = true;
    group = "pdns";
    home = "/var/spool/powerdns";
    description = "PowerDNS,,,";
    shell = "/run/current-system/sw/bin/false";
  };

  users.users._dnsdist = {
    isSystemUser = true;
    group = "_dnsdist";
    home = "/nonexistent";
    description = "dnsdist daemon";
    shell = "/run/current-system/sw/bin/nologin";
  };

  # Operator sudo policy: members of sudo/admin get full root; birch and
  # cedar may query the recursor control channel without a password.
  security.sudo.extraRules = [
    {
      groups = [ "sudo" "admin" ];
      commands = [ "ALL" ];
    }
    {
      users = [ "birch" ];
      commands = [
        { command = "/run/current-system/sw/bin/rec_control wipe-cache *"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/rec_control get *"; options = [ "NOPASSWD" ]; }
      ];
    }
    {
      users = [ "cedar" ];
      commands = [
        { command = "/run/current-system/sw/bin/rec_control get *"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
  security.sudo.extraConfig = ''
    Defaults use_pty
  '';

  # --- sshd ---------------------------------------------------------------
  # Root login stays key-only (set in the harness). No passwords anywhere.
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    X11Forwarding = true;
  };

  # --- authoritative server (NSD) ----------------------------------------
  services.nsd = {
    enable = true;
    interfaces = [ "127.0.0.1" ];
    port = authPort;
    ipv4 = true;
    ipv6 = false;
    hideVersion = true;
    identity = "node23-auth";
    verbosity = 0;
    zones = {
      "a23.test" = {
        data = builtins.readFile (zoneFile "a23.test.zone");
        provideXFR = [ "198.51.100.7 NOKEY" ];
      };
      "2.0.192.in-addr.arpa" = {
        data = builtins.readFile (zoneFile "192.0.2.rev.zone");
      };
    };
  };

  # --- recursor (PowerDNS) -------------------------------------------------
  services.pdns-recursor = {
    enable = true;
    dns.address = [ "127.0.0.1" ];
    dns.port = recursorPort;
    dns.allowFrom = [ "127.0.0.0/8" ];
    api.address = "127.0.0.1";
    api.port = 8082;
    api.allowFrom = [ "127.0.0.1" ];
    exportHosts = true;
    forwardZones = {
      "a23.test" = "127.0.0.1:${toString authPort}";
      "2.0.192.in-addr.arpa" = "127.0.0.1:${toString authPort}";
    };
    serveRFC1918 = true;
    dnssecValidation = "off";
    settings = {
      webservice.api_key = "lab-api-key";
      recursor = {
        etc_hosts_file = "${./files/extrarecursorhosts}";
        auth_zones = [
          {
            zone = "i23.test";
            file = "${zoneFile "i23.test.zone"}";
          }
        ];
        threads = 4;
        version_string = "anonymous";
        qname_minimization = false;
      };
      recordcache = {
        max_entries = 1000000;
        max_ttl = 3600;
        max_negative_ttl = 1800;
      };
      packetcache.max_entries = 500000;
      outgoing.dont_query = [ "127.0.0.0/8" "!127.0.0.1" ];
      incoming = {
        max_tcp_clients = 128;
        max_tcp_per_client = 100;
        tcp_timeout = 2;
        reuseport = true;
      };
    };
  };

  systemd.services.pdns-recursor.serviceConfig.User = lib.mkForce "pdns";
  systemd.services.pdns-recursor.serviceConfig.Group = lib.mkForce "pdns";

  # --- dnsdist front end ---------------------------------------------------
  environment.etc."dnsdist/dnsdist.conf" = {
    source = dnsdistConf;
    user = "root";
    group = "_dnsdist";
    mode = "0640";
  };

  # dnsdist runs as _dnsdist and must read the TLS key for DoT (reference:
  # root:_dnsdist 0640). The harness installs it root-only, so widen it here.
  environment.etc."node23/server.key" = {
    group = lib.mkForce "_dnsdist";
    mode = lib.mkForce "0640";
  };

  systemd.services.dnsdist = {
    description = "DNS Loadbalancer";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "notify";
      User = "_dnsdist";
      Group = "_dnsdist";
      ExecStartPre = "${pkgs.dnsdist}/bin/dnsdist --check-config --config /etc/dnsdist/dnsdist.conf";
      ExecStart = "${pkgs.dnsdist}/bin/dnsdist --supervised --disable-syslog --config /etc/dnsdist/dnsdist.conf";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 5;
      LimitNOFILE = 65536;
      TasksMax = 8192;
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "full";
      LockPersonality = true;
      RuntimeDirectory = "dnsdist";
    };
  };

  # Operator tools: rec_control (also what sudo rules resolve to), dnsdist,
  # and the BIND utilities (dig, host, nslookup, nsupdate).
  environment.systemPackages = [
    pkgs.pdns-recursor
    pkgs.dnsdist
    pkgs.bind.dnsutils
  ];

  system.stateVersion = "26.05";
}
