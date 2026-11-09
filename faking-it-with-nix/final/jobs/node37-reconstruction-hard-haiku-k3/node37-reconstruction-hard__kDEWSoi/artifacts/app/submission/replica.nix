{ config, lib, pkgs, ... }:
let
  f = name: builtins.readFile (./files + "/${name}");
  # The reference runs these via /usr/bin/env bash; systemd unit PATHs have no bash,
  # so point the shebang at the store's bash.
  fb = name: lib.replaceStrings [ "#!/usr/bin/env bash" ] [ "#!${pkgs.bashInteractive}/bin/bash" ] (f name);

  # Operator scripts, kept verbatim. Executable copies live in the store and are
  # exposed at their original paths with tmpfiles symlinks/copies below.
  accelInit = pkgs.writeScript "accel-init.sh" (fb "accel-init.sh");
  accelInitOld = pkgs.writeScript "accel-init.sh.pre-200w-20260815" (fb "accel-init.sh.pre-200w-20260815");
  accelSleepCleanup = pkgs.writeScript "accel-sleep-cleanup.sh" (fb "accel-sleep-cleanup.sh");
  idleSuspend = pkgs.writeScript "idle-suspend.sh" (fb "idle-suspend.sh");
  labSuspend = pkgs.writeScript "lab-suspend" (f "lab-suspend");
  accelSmi = pkgs.writeScript "accel-smi" (f "accel-smi");
  accelSmiSdk = pkgs.writeScript "accel-smi-sdk" (f "accel-smi-sdk");
  inferServer = pkgs.writeScript "infer-server" (f "infer-server");
  metricsAgent = pkgs.writeScript "metrics-agent" ("#!${pkgs.python3}/bin/python3\n" + f "metrics-agent.py");
  accelActivate = pkgs.writeScript "accel-env-activate.sh" (fb "accel-env-activate.sh");
  accelPyproject = pkgs.writeText "accel-env-pyproject.toml" (f "accel-env-pyproject.toml");

  sdkDir = "/home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel";

  # Scripts call these by absolute /usr/bin paths, as on the reference host.
  usrBinLinks = {
    ss = "${pkgs.iproute2}/bin/ss";
    awk = "${pkgs.gawk}/bin/awk";
    logger = "${pkgs.util-linux}/bin/logger";
    sleep = "${pkgs.coreutils}/bin/sleep";
    kill = "${pkgs.procps}/bin/kill";
    systemctl = "${config.systemd.package}/bin/systemctl";
  };
in
{
  networking.hostName = "node37";
  networking.useNetworkd = true;
  services.resolved.enable = true;
  services.timesyncd.enable = lib.mkForce true;
  networking.firewall.enable = false;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "C.UTF-8";

  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "pcie_aspm=off"
    "crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M"
  ];
  boot.blacklistedKernelModules = [ "joydev" ];
  boot.extraModprobeConfig = ''
    install algif_aead ${pkgs.coreutils}/bin/false
    options iTCO_wdt heartbeat=90
    options md_mod start_ro=1
  '';

  # Effective values read from the reference host (drop-ins in /etc/sysctl.d).
  boot.kernel.sysctl = {
    "kernel.printk" = lib.mkForce "4 4 1 7";
    "net.ipv6.conf.all.use_tempaddr" = lib.mkForce 0;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 0;
    "kernel.kptr_restrict" = lib.mkForce 1;
    "kernel.sysrq" = lib.mkForce 176;
    "net.ipv4.conf.all.rp_filter" = lib.mkForce 2;
    "net.ipv4.conf.default.rp_filter" = lib.mkForce 2;
    "kernel.yama.ptrace_scope" = lib.mkForce 1;
    "vm.mmap_min_addr" = lib.mkForce 65536;
    "kernel.hardlockup_panic" = lib.mkForce 1;
    "kernel.panic" = lib.mkForce 30;
    "kernel.hung_task_timeout_secs" = lib.mkForce 300;
    "kernel.hung_task_all_cpu_backtrace" = lib.mkForce 1;
    "kernel.hung_task_panic" = lib.mkForce 1;
    "vm.swappiness" = lib.mkForce 60;
    "kernel.dmesg_restrict" = lib.mkForce 1;
    "kernel.unprivileged_bpf_disabled" = lib.mkForce 2;
    "fs.protected_regular" = lib.mkForce 2;
    "kernel.nmi_watchdog" = lib.mkForce 0;
    "net.ipv4.conf.all.accept_redirects" = lib.mkForce 1;
    "net.ipv4.tcp_syncookies" = lib.mkForce 1;
  };

  # Sleep: never actually suspend. Idle suspend goes through lab-suspend; the
  # sleep-family targets are masked so logind's IdleAction cannot sleep the VM.
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  services.logind.settings.Login = {
    IdleAction = "suspend";
    IdleActionSec = "4h";
  };
  systemd.targets.sleep = {
    overrideStrategy = "asDropin";
    requires = [ "accel-sleep-cleanup.service" ];
    after = [ "accel-sleep-cleanup.service" ];
  };

  services.openssh = {
    enable = true;
    hostKeys = [
      { type = "rsa"; bits = 4096; path = "/etc/ssh/ssh_host_rsa_key"; }
      { type = "ecdsa"; path = "/etc/ssh/ssh_host_ecdsa_key"; }
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
    ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      UseDns = false;
      PrintMotd = false;
      Compression = "yes";
    };
  };

  # Ubuntu names these ssh.service and rsyslog.service; keep those names working.
  systemd.services.sshd.aliases = [ "ssh.service" ];
  systemd.services.syslog.aliases = [ "rsyslog.service" ];

  services.cron.enable = true;
  services.irqbalance.enable = true;
  services.fstrim.enable = true;
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

  services.sysstat = {
    enable = true;
    collect-frequency = "*-*-* *:*:00";
    collect-args = "1 1";
  };
  environment.etc."default/sysstat".text = ''
    ENABLED="true"
  '';

  environment.etc."default/infer-server".text = ''
    INFER_WORKDIR=/home/ember/infer
    INFER_BIN=/opt/node37/bin/infer-server
    INFER_ARGS='--model lab-model --ctx 100000 --split 55,45 --host 192.0.2.83'
  '';

  environment.systemPackages = with pkgs; [
    git
    tmux
    vim
    nano
    htop
    curl
    jq
    python3
    pciutils
    ethtool
    hdparm
    dmidecode
    lsof
    strace
    rsync
    bc
    tcpdump
    lshw
    screen
    mtr
    netcat-openbsd
  ];

  environment.variables = {
    ACCEL_VISIBLE_DEVICES = "0,1";
    OMP_NUM_THREADS = "8";
  };

  users.groups = {
    ember.gid = 1000;
    probe.gid = 997;
    sudo = { };
    accel = {
      gid = 992;
      members = [ "ember" ];
    };
    i2c = {
      gid = 998;
      members = [ "ember" ];
    };
  };

  users.users.ember = {
    isNormalUser = true;
    uid = 1000;
    group = "ember";
    home = "/home/ember";
    homeMode = "750";
    extraGroups = [ "sudo" "adm" "video" ];
  };

  users.users.probe = {
    isSystemUser = true;
    uid = 997;
    group = "probe";
    home = "/var/lib/metrics-agent";
    createHome = false;
    description = "";
  };

  security.sudo.extraConfig = ''
    %sudo ALL=(ALL:ALL) ALL
  '';

  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';

  # Units. Paths and unit names match the reference host.
  systemd.services.accel-setup = {
    description = "Initialize accelerator power state and cap";
    wantedBy = [ "multi-user.target" ];
    environment.PCI_SYSFS_ROOT = "/var/lib/node37/pci";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/usr/local/bin/accel-init.sh";
      RemainAfterExit = true;
    };
  };

  systemd.services.accel-sleep-cleanup = {
    description = "Stop compute workloads before system sleep";
    unitConfig.DefaultDependencies = false;
    before = [ "sleep.target" ];
    partOf = [ "sleep.target" ];
    environment.PCI_SYSFS_ROOT = "/var/lib/node37/pci";
    path = with pkgs; [ coreutils gnused gnugrep procps util-linux systemd ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/usr/local/bin/accel-sleep-cleanup.sh";
      ExecStop = "/usr/local/bin/accel-init.sh";
      RemainAfterExit = true;
      TimeoutStartSec = "90s";
      TimeoutStopSec = "30s";
    };
  };

  systemd.services.idle-check = {
    description = "Network and device idle monitor";
    after = [ "network.target" ];
    path = with pkgs; [ coreutils gnugrep gnused gawk util-linux iproute2 procps systemd ];
    environment = {
      PCI_SYSFS_ROOT = "/var/lib/node37/pci";
      SUSPEND_CMD = "/usr/local/bin/lab-suspend";
    };
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

  systemd.services.infer-server = {
    description = "Inference server";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "ember";
      Group = "ember";
      EnvironmentFile = "/etc/default/infer-server";
      ExecStart = "/bin/bash -lc 'cd \"$INFER_WORKDIR\" && exec \"$INFER_BIN\" $INFER_ARGS'";
      Restart = "on-failure";
      RestartSec = 5;
      LimitNOFILE = 1048576;
    };
  };

  systemd.services.metrics-agent = {
    description = "Metrics agent";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      PORT = "45876";
      HUB_URL = "https://hub.lab.invalid";
    };
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

  systemd.tmpfiles.rules =
    [
      # Compatibility paths used by the operator's units and scripts.
      "d /bin 0755 root root -"
      "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
      "L+ /bin/false - - - - ${pkgs.coreutils}/bin/false"

      "d /usr/local/bin 0755 root root -"
      "d /usr/local/sbin 0755 root root -"
      "L+ /usr/local/bin/accel-init.sh - - - - ${accelInit}"
      "L+ /usr/local/bin/accel-init.sh.pre-200w-20260815 - - - - ${accelInitOld}"
      "L+ /usr/local/bin/accel-sleep-cleanup.sh - - - - ${accelSleepCleanup}"
      "L+ /usr/local/bin/idle-suspend.sh - - - - ${idleSuspend}"
      "L+ /usr/local/bin/lab-suspend - - - - ${labSuspend}"
      "L+ /usr/local/bin/accel-smi - - - - ${accelSmi}"

      "d /usr/bin 0755 root root -"
    ]
    ++ lib.mapAttrsToList (name: target: "L+ /usr/bin/${name} - - - - ${target}") usrBinLinks
    ++ [
      "d /opt/node37 0755 root root -"
      "d /opt/node37/bin 0755 root root -"
      "L+ /opt/node37/bin/infer-server - - - - ${inferServer}"
      "d /opt/metrics-agent 0755 root root -"
      "L+ /opt/metrics-agent/metrics-agent - - - - ${metricsAgent}"

      # Accelerator device state. accel-init.sh rewrites these at every boot.
      "d /var/lib/node37 0755 root root -"
      "d /var/lib/node37/pci 0755 root root -"
      "d /var/lib/node37/pci/0000:03:00.0 0755 root root -"
      "d /var/lib/node37/pci/0000:03:00.0/hwmon 0755 root root -"
      "d /var/lib/node37/pci/0000:03:00.0/hwmon/hwmon0 0755 root root -"
      "d /var/lib/node37/pci/0000:03:00.0/power 0755 root root -"
      "f /var/lib/node37/pci/0000:03:00.0/gpu_busy_percent 0644 root root - 0"
      "f /var/lib/node37/pci/0000:03:00.0/hwmon/hwmon0/power1_cap 0644 root root - 200000000"
      "f /var/lib/node37/pci/0000:03:00.0/power/control 0644 root root - auto"
      "d /var/lib/node37/pci/0000:87:00.0 0755 root root -"
      "d /var/lib/node37/pci/0000:87:00.0/hwmon 0755 root root -"
      "d /var/lib/node37/pci/0000:87:00.0/hwmon/hwmon0 0755 root root -"
      "d /var/lib/node37/pci/0000:87:00.0/power 0755 root root -"
      "f /var/lib/node37/pci/0000:87:00.0/gpu_busy_percent 0644 root root - 0"
      "f /var/lib/node37/pci/0000:87:00.0/hwmon/hwmon0/power1_cap 0644 root root - 200000000"
      "f /var/lib/node37/pci/0000:87:00.0/power/control 0644 root root - auto"
      "f /var/lib/host-ready 0644 root root - -"

      # Operator home: ember's accelerator environment and the inference workdir.
      "d /home/ember 0750 ember ember -"
      "d /home/ember/infer 0755 ember ember -"
      "d /home/ember/accel-env 0755 ember ember -"
      "d /home/ember/accel-env/env 0755 ember ember -"
      "C /home/ember/accel-env/env/activate.sh 0644 ember ember - ${accelActivate}"
      "C /home/ember/accel-env/pyproject.toml 0644 ember ember - ${accelPyproject}"
      "d /home/ember/accel-env/.venv 0755 ember ember -"
      "d /home/ember/accel-env/.venv/lib 0755 ember ember -"
      "d /home/ember/accel-env/.venv/lib/python3 0755 ember ember -"
      "d /home/ember/accel-env/.venv/lib/python3/site-packages 0755 ember ember -"
      "d ${sdkDir} 0755 ember ember -"
      "d ${sdkDir}/bin 0755 ember ember -"
      "C ${sdkDir}/bin/accel-smi 0755 ember ember - ${accelSmiSdk}"
    ];
}
