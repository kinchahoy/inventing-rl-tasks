{ config, lib, pkgs, ... }:
let
  node37 = ./node37;
  pciRoot = "/var/lib/node37/pci";

  # Operator scripts, copied verbatim from the reference host (see node37/).
  # Shebangs point at store paths so they run without PATH or /usr/bin.
  fixShebang = lib.replaceStrings
    [ "#!/usr/bin/env bash" "#!/usr/bin/env python3" ]
    [ "#!${pkgs.bashInteractive}/bin/bash" "#!${pkgs.python3}/bin/python3" ];
  script = name: file: pkgs.writeScript name (fixShebang (builtins.readFile (node37 + "/${file}")));
  accelInit = script "accel-init.sh" "accel-init.sh";
  accelSleepCleanup = script "accel-sleep-cleanup.sh" "accel-sleep-cleanup.sh";
  idleSuspend = script "idle-suspend.sh" "idle-suspend.sh";
  labSuspend = script "lab-suspend" "lab-suspend";
  accelSmiSdk = script "accel-smi" "accel-smi";
  accelSmi = pkgs.writeShellScript "accel-smi-wrapper" ''
    exec /home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin/accel-smi "$@"
  '';
  metricsAgent = script "metrics-agent" "metrics-agent";
  inferServer = script "infer-server" "infer-server";

  mac = "52:54:00:12:34:56";

  emberBashrc = pkgs.writeText "ember-bashrc" ''
    # ~/.bashrc: executed by bash(1) for non-login shells.
    case $- in *i*) ;; *) return;; esac
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
    if [ -d "$HOME/.local/bin" ] ; then
        PATH="$HOME/.local/bin:$PATH"
    fi
  '';
in
{
  ###### identity, locale, time

  networking.hostName = "node37";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.firewall.enable = false;
  services.resolved.enable = true;
  systemd.network.wait-online.enable = lib.mkForce true;

  systemd.network.links."10-ens3" = {
    matchConfig.PermanentMACAddress = mac;
    linkConfig.Name = "ens3";
  };
  systemd.network.networks."10-ens3" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      LinkLocalAddressing = "ipv6";
    };
    dhcpV4Config = {
      RouteMetric = 100;
      UseMTU = true;
    };
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "C.UTF-8";
  services.timesyncd.enable = lib.mkForce true;

  # /etc/environment on the reference; pam_env delivers these to ssh sessions.
  environment.sessionVariables = {
    ACCEL_VISIBLE_DEVICES = "0,1";
    OMP_NUM_THREADS = "8";
  };
  environment.localBinInPath = true;

  ###### ssh

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
  };
  systemd.services.sshd.aliases = [ "ssh.service" ];
  systemd.services.syslog.aliases = [ "rsyslog.service" ];
  services.dbus.implementation = "dbus";
  systemd.oomd.enable = false;

  ###### users and groups

  users.groups = lib.mapAttrs (_: gid: { gid = lib.mkForce gid; }) {
    admin = 117;
    adm = 4;
    sudo = 27;
    accel = 992;
    i2c = 998;
    probe = 997;
    ember = 1000;
    messagebus = 105;
    dialout = 20;
    lp = 7;
    video = 44;
  };
  users.users.messagebus.uid = lib.mkForce 102;

  users.users.ember = {
    isNormalUser = true;
    uid = 1000;
    group = "ember";
    home = "/home/ember";
    homeMode = "750";
    shell = pkgs.bashInteractive;
    hashedPassword = "!";
    extraGroups = [ "sudo" "adm" "video" "accel" "i2c" ];
  };

  users.users.probe = {
    isSystemUser = true;
    uid = 997;
    group = "probe";
    home = "/var/lib/metrics-agent";
    createHome = false;
    shell = "/run/current-system/sw/bin/nologin";
    hashedPassword = "!";
  };

  users.users.root.hashedPassword = "!";

  security.sudo.extraConfig = ''
    Defaults use_pty
    Defaults mail_badpass
    %admin ALL=(ALL) ALL
    %sudo ALL=(ALL:ALL) ALL
  '';

  ###### kernel

  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "pcie_aspm=off"
    "crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M"
  ];

  boot.kernel.sysctl = lib.mapAttrs (_: lib.mkForce) {
    "kernel.printk" = "4 4 1 7";
    "kernel.sysrq" = 176;
    "kernel.kptr_restrict" = 1;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.perf_event_paranoid" = 4;
    "kernel.unprivileged_bpf_disabled" = 2;
    "kernel.nmi_watchdog" = 0;
    "vm.mmap_min_addr" = 65536;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
    "net.ipv6.conf.all.use_tempaddr" = 0;
    "net.ipv6.conf.default.use_tempaddr" = 0;
    # idle-freeze mitigation: NMI hardlockup escalates to panic, then auto-reboot after 30 s
    "kernel.hardlockup_panic" = 1;
    "kernel.panic" = 30;
    "kernel.hung_task_timeout_secs" = 300;
    "kernel.hung_task_all_cpu_backtrace" = 1;
    "kernel.hung_task_panic" = 1;
    "fs.inotify.max_user_watches" = 20345;
    "fs.inotify.max_user_instances" = 128;
    "fs.protected_regular" = 2;
  };

  boot.extraModprobeConfig = ''
    blacklist iTCO_vendor_support
    blacklist iTCO_wdt
    blacklist joydev
    install algif_aead ${pkgs.coreutils}/bin/false
    options iTCO_wdt heartbeat=90
    options md_mod start_ro=1
  '';

  ###### sleep: systemctl suspend goes through the lab stand-in, never the kernel

  systemd.targets.hibernate.enable = false;
  systemd.targets."hybrid-sleep".enable = false;
  systemd.services.systemd-suspend.serviceConfig.ExecStart = [ "" "${labSuspend}" ];

  services.logind.settings.Login = {
    IdleAction = "suspend";
    IdleActionSec = "4h";
  };

  ###### accelerator state

  systemd.services.accel-setup = {
    description = "Initialize accelerator power state and cap";
    wantedBy = [ "multi-user.target" ];
    environment.PCI_SYSFS_ROOT = pciRoot;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${accelInit}";
    };
  };

  systemd.services.accel-sleep-cleanup = {
    description = "Stop compute workloads before system sleep";
    unitConfig.DefaultDependencies = "no";
    before = [ "sleep.target" ];
    partOf = [ "sleep.target" ];
    environment.PCI_SYSFS_ROOT = pciRoot;
    path = with pkgs; [ coreutils gnused gnugrep util-linux procps systemd ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${accelSleepCleanup}";
      ExecStop = "${accelInit}";
      TimeoutStartSec = "90s";
      TimeoutStopSec = "30s";
    };
  };

  systemd.targets.sleep = {
    requires = [ "accel-sleep-cleanup.service" ];
    after = [ "accel-sleep-cleanup.service" ];
  };

  systemd.services.idle-check = {
    description = "Network and device idle monitor";
    after = [ "network.target" ];
    environment = {
      PCI_SYSFS_ROOT = pciRoot;
      SUSPEND_CMD = "/usr/local/bin/lab-suspend";
    };
    path = with pkgs; [ coreutils gnugrep gnused gawk util-linux iproute2 systemd ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/usr/local/bin/idle-suspend.sh";
    };
  };

  systemd.timers.idle-check = {
    description = "Run idle monitor every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      Unit = "idle-check.service";
    };
  };

  services.sysstat = {
    enable = true;
    collect-frequency = "*-*-* *:*:00";
  };

  ###### inference server (installed, not enabled)

  systemd.services.infer-server = {
    description = "Inference server";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "ember";
      Group = "ember";
      EnvironmentFile = "/etc/default/infer-server";
      ExecStart = "${pkgs.bashInteractive}/bin/bash -lc 'cd \"$INFER_WORKDIR\" && exec \"$INFER_BIN\" $INFER_ARGS'";
      Restart = "on-failure";
      RestartSec = 5;
      LimitNOFILE = 1048576;
    };
  };

  environment.etc."default/infer-server".text = ''
    INFER_WORKDIR=/home/ember/infer
    INFER_BIN=/opt/node37/bin/infer-server
    INFER_ARGS='--model lab-model --ctx 100000 --split 55,45 --host 192.0.2.83'
  '';

  ###### metrics agent

  systemd.services.metrics-agent = {
    description = "Metrics agent";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      PORT = "45876";
      HUB_URL = "https://hub.lab.invalid";
    };
    path = [ pkgs.python3 ];
    serviceConfig = {
      ExecStart = "/opt/metrics-agent/metrics-agent";
      User = "probe";
      Restart = "on-failure";
      RestartSec = 5;
      StateDirectory = "metrics-agent";
      KeyringMode = "private";
      LockPersonality = true;
      ProtectClock = true;
      ProtectHome = "read-only";
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictSUIDSGID = true;
    };
  };

  systemd.services.metrics-agent-update = {
    description = "Update metrics agent if needed";
    wants = [ "metrics-agent.service" ];
    path = [ pkgs.python3 ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/opt/metrics-agent/metrics-agent update";
    };
  };

  systemd.timers.metrics-agent-update = {
    description = "Run metrics agent update daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "4h";
    };
  };

  ###### services kept from the base host

  services.cron.enable = true;
  services.irqbalance.enable = true;
  services.fstrim.enable = true;
  services.logrotate.enable = true;
  services.rsyslogd = {
    enable = true;
    extraConfig = ''
      *.*;auth,authpriv.none -/var/log/syslog
      auth,authpriv.* /var/log/auth.log
      kern.* -/var/log/kern.log
    '';
  };

  # Operator commands on the system PATH (ssh sessions do not get /usr/local/bin).
  environment.systemPackages = [
    (pkgs.runCommand "node37-operator-tools" { } ''
      mkdir -p $out/bin
      ln -s ${accelSmi} $out/bin/accel-smi
      ln -s ${accelInit} $out/bin/accel-init.sh
      ln -s ${accelSleepCleanup} $out/bin/accel-sleep-cleanup.sh
      ln -s ${idleSuspend} $out/bin/idle-suspend.sh
      ln -s ${labSuspend} $out/bin/lab-suspend
    '')
  ] ++ (with pkgs; [
    sysstat
    iproute2
    procps
    util-linux
    nftables
    python3
    curl
    jq
    vim
    git
  ]);

  ###### files and directories provisioned on the host

  systemd.tmpfiles.rules = [
    # Operator commands in /usr/local/bin and the accelerator SDK wrapper.
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/accel-init.sh - - - - ${accelInit}"
    "L+ /usr/local/bin/accel-sleep-cleanup.sh - - - - ${accelSleepCleanup}"
    "L+ /usr/local/bin/idle-suspend.sh - - - - ${idleSuspend}"
    "L+ /usr/local/bin/lab-suspend - - - - ${labSuspend}"
    "L+ /usr/local/bin/accel-smi - - - - ${accelSmi}"

    # Legacy paths used by the scripts.
    "L+ /usr/bin/ss - - - - ${pkgs.iproute2}/bin/ss"
    "L+ /usr/bin/awk - - - - ${pkgs.gawk}/bin/awk"
    "L+ /usr/bin/logger - - - - ${pkgs.util-linux}/bin/logger"
    "L+ /usr/bin/sleep - - - - ${pkgs.coreutils}/bin/sleep"
    "L+ /usr/bin/kill - - - - ${pkgs.procps}/bin/kill"
    "L+ /usr/bin/systemctl - - - - /run/current-system/sw/bin/systemctl"
    "L+ /var/log/sysstat - - - - /var/log/sa"

    # /opt layout.
    "d /opt/metrics-agent 0755 root root -"
    "L+ /opt/metrics-agent/metrics-agent - - - - ${metricsAgent}"
    "d /opt/node37 0755 root root -"
    "d /opt/node37/bin 0755 root root -"
    "L+ /opt/node37/bin/infer-server - - - - ${inferServer}"

    # Accelerator fixture tree (device state; created once, then left alone).
    "d /var/lib/node37 0755 root root -"
    "d /var/lib/node37/pci 0755 root root -"
    "d /var/lib/node37/pci/0000:03:00.0 0755 root root -"
    "d /var/lib/node37/pci/0000:03:00.0/hwmon 0755 root root -"
    "d /var/lib/node37/pci/0000:03:00.0/hwmon/hwmon0 0755 root root -"
    "d /var/lib/node37/pci/0000:03:00.0/power 0755 root root -"
    "f /var/lib/node37/pci/0000:03:00.0/power/control 0644 root root - auto"
    "f /var/lib/node37/pci/0000:03:00.0/hwmon/hwmon0/power1_cap 0644 root root - 250000000"
    "f /var/lib/node37/pci/0000:03:00.0/gpu_busy_percent 0644 root root - 0"
    "d /var/lib/node37/pci/0000:87:00.0 0755 root root -"
    "d /var/lib/node37/pci/0000:87:00.0/hwmon 0755 root root -"
    "d /var/lib/node37/pci/0000:87:00.0/hwmon/hwmon0 0755 root root -"
    "d /var/lib/node37/pci/0000:87:00.0/power 0755 root root -"
    "f /var/lib/node37/pci/0000:87:00.0/power/control 0644 root root - auto"
    "f /var/lib/node37/pci/0000:87:00.0/hwmon/hwmon0/power1_cap 0644 root root - 250000000"
    "f /var/lib/node37/pci/0000:87:00.0/gpu_busy_percent 0644 root root - 0"

    # Operator home and accelerator environment.
    "C /home/ember/.bashrc 0644 ember ember - ${emberBashrc}"
    "d /home/ember/accel-env 0755 ember ember -"
    "d /home/ember/accel-env/env 0755 ember ember -"
    "C /home/ember/accel-env/pyproject.toml 0644 ember ember - ${node37 + "/ember/accel-env/pyproject.toml"}"
    "C /home/ember/accel-env/env/activate.sh 0644 ember ember - ${node37 + "/ember/accel-env/env/activate.sh"}"
    "d /home/ember/accel-env/.venv 0755 ember ember -"
    "d /home/ember/accel-env/.venv/lib 0755 ember ember -"
    "d /home/ember/accel-env/.venv/lib/python3 0755 ember ember -"
    "d /home/ember/accel-env/.venv/lib/python3/site-packages 0755 ember ember -"
    "d /home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel 0755 ember ember -"
    "d /home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin 0755 ember ember -"
    "L+ /home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin/accel-smi - - - - ${accelSmiSdk}"
    "d /home/ember/infer 0755 ember ember -"

    # Metrics agent state and the cinc client directory layout.
    "d /var/lib/metrics-agent 0755 probe probe -"
    "d /etc/cinc 0755 root root -"
  ];

  environment.etc."cinc/client.rb".source = node37 + "/client.rb";
}
