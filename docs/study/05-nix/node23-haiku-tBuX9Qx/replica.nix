{ config, lib, pkgs, ... }:

# STUDY: Haiku 5.5, node23 trial tBuX9Qx, reward 1.0 (26/26). The only full solve; see ../06-traces/node23-haiku-tBuX9Qx.md.
let
  dnsdist = pkgs.dnsdist;
  recursor = pkgs.pdns-recursor;
  nsd = pkgs.nsd;

  # STUDY: sudo matches resolved paths; the module grants both /usr/bin/rec_control and this NixOS path (see sudo rules below).
  recControl = "/run/current-system/sw/bin/rec_control";
in
{
  ###########################################################################
  # Identity
  ###########################################################################

  networking.hostName = "node23";

  # The resolver is the local dnsdist listener; DHCP must not replace it.
  networking.nameservers = [ "127.0.0.1" ];
  networking.search = [ "n23.test" ];
  networking.dhcpcd.extraConfig = "nohook resolv.conf";
  networking.resolvconf.dnsExtensionMechanism = false;

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  # Ports served to clients: DNS over UDP/TCP, DNS over TLS, and SSH.
  # STUDY: NixOS enables a firewall by default; Ubuntu reference had none. Opening 53/853 is needed for the outside DNS checks.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 53 853 ];
    allowedUDPPorts = [ 53 ];
  };

  boot.kernel.sysctl = {
    "net.core.rmem_max" = 8388608;
    "net.core.wmem_max" = 8388608;
    "net.ipv4.ip_local_port_range" = "10240 65535";
  };

  ###########################################################################
  # Accounts (names, UIDs/GIDs and home layout as provisioned)
  ###########################################################################

  users.groups = {
    admin = { gid = 117; };
    sudo = { };
    birch = { gid = 1301; };
    cedar = { gid = 1302; };
    nsd = { gid = 120; };
    pdns = { gid = 121; };
    _dnsdist = { gid = 122; };
  };

  users.users = {
    birch = {
      isNormalUser = true;
      uid = 1301;
      group = "birch";
      home = "/home/birch";
      homeMode = "750";
      createHome = true;
      description = "";
      shell = "/bin/bash";
      hashedPassword = "!";
    };

    cedar = {
      isNormalUser = true;
      uid = 1302;
      group = "cedar";
      home = "/home/cedar";
      homeMode = "750";
      createHome = true;
      description = "";
      shell = "/bin/bash";
      hashedPassword = "!";
    };

    nsd = {
      isSystemUser = true;
      uid = 112;
      group = "nsd";
      home = "/var/lib/nsd";
      createHome = false;
      shell = "/usr/sbin/nologin";
    };

    pdns = {
      isSystemUser = true;
      uid = 113;
      group = "pdns";
      description = "PowerDNS,,,";
      home = "/var/spool/powerdns";
      createHome = false;
      shell = "/bin/false";
    };

    _dnsdist = {
      isSystemUser = true;
      uid = 114;
      group = "_dnsdist";
      home = "/nonexistent";
      createHome = false;
      shell = "/usr/sbin/nologin";
    };
  };

  # STUDY: lib.mkForce overrides NixOS's own root defaults (description, shell) to match the reference's passwd entry.
  users.users.root = {
    description = lib.mkForce "root";
    shell = lib.mkForce "/bin/bash";
  };

  # Login shells the provisioned accounts point at, at their usual paths.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /bin/false - - - - ${pkgs.coreutils}/bin/false"
    "L+ /usr/sbin/nologin - - - - ${pkgs.shadow}/bin/nologin"
    "L+ /usr/bin/rec_control - - - - ${recursor}/bin/rec_control"
    "d /var/lib/nsd 0755 nsd nsd -"
    "d /var/spool/powerdns 0750 pdns pdns -"
    "d /etc/nsd/zones 0750 root nsd -"
    "d /etc/nsd/nsd.conf.d 0755 root root -"
  ];

  # Operators: birch may wipe and inspect the recursor cache; cedar may inspect it.
  # STUDY: Operator rules for rec_control (check sudo_policy).
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
      groups = [ "sudo" "admin" ];
      runAs = "ALL:ALL";
      commands = [ { command = "ALL"; options = [ ]; } ];
    }
  ];

  security.sudo.extraConfig = ''
    Defaults	mail_badpass
  '';

  ###########################################################################
  # SSH
  ###########################################################################

  services.openssh = {
    enable = true;
    # Authorized keys: the provisioned per-user files, plus the harness-managed key store.
    # STUDY: Keeps the harness key path /etc/ssh/authorized_keys.d/%u, otherwise the verifier's root SSH would break.
    authorizedKeysFiles = lib.mkForce [ ".ssh/authorized_keys" ".ssh/authorized_keys2" "/etc/ssh/authorized_keys.d/%u" ];
    settings = {
      PermitRootLogin = lib.mkForce "without-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
    };
    hostKeys = [
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
      { type = "rsa"; bits = 3072; path = "/etc/ssh/ssh_host_rsa_key"; }
      { type = "ecdsa"; path = "/etc/ssh/ssh_host_ecdsa_key"; }
    ];
  };

  ###########################################################################
  # Provisioned TLS credentials: dnsdist runs as _dnsdist and must read the key.
  ###########################################################################

  environment.etc."node23/server.crt".mode = "0644";
  environment.etc."node23/server.key" = {
    group = "_dnsdist";
    mode = lib.mkForce "0640";
  };

  ###########################################################################
  # Configuration files
  ###########################################################################

  environment.etc = {
    # Same name-to-address mapping as the provisioned host file.
    hosts.text = lib.mkForce ''
      127.0.0.1 localhost node23 node23.n23.test
      ::1 localhost ip6-localhost
    '';

    "dnsdist/dnsdist.conf" = {
      source = ./files/dnsdist/dnsdist.conf;
      user = "root";
      group = "_dnsdist";
      mode = "0640";
    };

    "nsd/nsd.conf" = { source = ./files/nsd/nsd.conf; mode = "0644"; };
    "nsd/zones/a23.test.zone" = {
      source = ./files/nsd/zones/a23.test.zone;
      user = "root";
      group = "nsd";
      mode = "0640";
    };
    "nsd/zones/192.0.2.rev.zone" = {
      source = ./files/nsd/zones/192.0.2.rev.zone;
      user = "root";
      group = "nsd";
      mode = "0640";
    };

    "powerdns/recursor.conf" = { source = ./files/powerdns/recursor.conf; mode = "0644"; };
    "powerdns/recursor.d/40-compat.conf" = { source = ./files/powerdns/recursor.d/40-compat.conf; mode = "0644"; };
    "powerdns/recursor.d/50-ttl.conf" = { source = ./files/powerdns/recursor.d/50-ttl.conf; mode = "0644"; };
    "powerdns/recursor.d/60-legacy.conf.dpkg-old" = { source = ./files/powerdns/recursor.d/60-legacy.conf.dpkg-old; mode = "0644"; };
    "powerdns/extrarecursorhosts" = { source = ./files/powerdns/extrarecursorhosts; mode = "0644"; };
    "powerdns/zones/i23.test.zone" = { source = ./files/powerdns/zones/i23.test.zone; mode = "0644"; };
  };

  ###########################################################################
  # Services
  ###########################################################################

  # Front door: UDP/TCP 53 and DNS-over-TLS 853, forwarding to the recursor.
  # STUDY: Custom units instead of services.dnsdist / services.pdns-recursor / services.nsd: the modules hard-code users and config
  # STUDY: formats (recursor module is YAML-only), so the agent runs the daemons against the reference's own config files.
  systemd.services.dnsdist = {
    description = "DNS Loadbalancer";
    documentation = [ "man:dnsdist(1)" "https://dnsdist.org" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      ExecStartPre = "${dnsdist}/bin/dnsdist --check-config --config /etc/dnsdist/dnsdist.conf";
      ExecStart = "${dnsdist}/bin/dnsdist --supervised --disable-syslog --config /etc/dnsdist/dnsdist.conf";
      User = "_dnsdist";
      Group = "_dnsdist";
      Type = "notify";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 5;
      LimitNOFILE = 65536;
      TasksMax = 8192;
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      LockPersonality = true;
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
    };
  };

  # Recursive resolver on 127.0.0.1:5353, behind dnsdist.
  systemd.services.pdns-recursor = {
    description = "PowerDNS Recursor";
    documentation = [ "man:pdns_recursor(1)" "man:rec_control(1)" "https://doc.powerdns.com" ];
    wants = [ "network-online.target" "nss-lookup.target" ];
    before = [ "nss-lookup.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      # Configuration is the provisioned recursor.conf (legacy syntax).
      # STUDY: pdns-recursor 5.x refuses the legacy 4.6 config format unless this flag is passed: version gap handled by a flag.
      ExecStart = "${recursor}/bin/pdns_recursor --config-dir=/etc/powerdns --enable-old-settings --daemon=no --write-pid=no --disable-syslog --log-timestamp=no";
      User = "pdns";
      Group = "pdns";
      Type = "notify";
      Restart = "on-failure";
      RuntimeDirectory = "pdns-recursor";
      SyslogIdentifier = "pdns-recursor";
      LimitNOFILE = 65536;
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE CAP_CHOWN";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE CAP_CHOWN";
      LockPersonality = true;
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
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
    };
  };

  # Authoritative server for a23.test and the 2.0.192.in-addr.arpa reverse zone,
  # on 127.0.0.1:5301 (reached through the recursor's forward-zones).
  systemd.services.nsd = {
    description = "Name Server Daemon";
    documentation = [ "man:nsd(8)" ];
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "notify";
      Restart = "always";
      ExecStart = "${nsd}/sbin/nsd -d -c /etc/nsd/nsd.conf -P \"\"";
      ExecReload = "+${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      CapabilityBoundingSet = "CAP_CHOWN CAP_IPC_LOCK CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW CAP_SETGID CAP_SETUID CAP_SYS_CHROOT";
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/nsd" "/etc/nsd" "/run" ];
      RuntimeDirectory = "nsd";
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      # STUDY: systemd sandboxing copied/added; the `~@group` syntax denies syscall groups.
      SystemCallFilter = [ "~@clock" "~@cpu-emulation" "~@debug" "~@keyring" "~@module" "~@mount" "~@obsolete" "~@resources" ];
    };
  };

  ###########################################################################
  # Operator tooling
  ###########################################################################

  environment.systemPackages = [
    dnsdist
    recursor
    nsd
    pkgs.bind.dnsutils
    pkgs.openssl
  ];
}
