{ config, lib, pkgs, ... }:
let
  files = ./files;

  # The operator scripts were written against Ubuntu's /usr/bin layout. NixOS has no
  # /usr/bin tools, so point the absolute paths at the store copies of the same tools.
  # Shebangs are pinned too: `env bash` cannot resolve under systemd's minimal PATH.
  rewrite = text: builtins.replaceStrings
    [ "#!/usr/bin/env bash" "#!/usr/bin/env python3"
      "/usr/bin/logger" "/usr/bin/sleep" "/usr/bin/systemctl" "/usr/bin/kill" "/usr/bin/ss" "/usr/bin/awk" ]
    [ "#!${pkgs.bash}/bin/bash"
      "#!${pkgs.python3}/bin/python3"
      "${pkgs.util-linux}/bin/logger"
      "${pkgs.coreutils}/bin/sleep"
      "${config.systemd.package}/bin/systemctl"
      "${pkgs.procps}/bin/kill"
      "${pkgs.iproute2}/bin/ss"
      "${pkgs.gawk}/bin/awk" ]
    text;

  mkScript = file: pkgs.writeTextFile {
    name = builtins.baseNameOf (toString file);
    executable = true;
    text = rewrite (builtins.readFile file);
  };

  accelInit = mkScript (files + "/accel-init.sh");
  accelSleepCleanup = mkScript (files + "/accel-sleep-cleanup.sh");
  idleSuspend = mkScript (files + "/idle-suspend.sh");
  labSuspend = mkScript (files + "/lab-suspend.sh");
  accelSmiTool = mkScript (files + "/accel-smi.sh");
  accelSmiWrapper = mkScript (files + "/accel-smi-wrapper.sh");
  accelActivate = mkScript (files + "/accel-activate.sh");
  accelPyproject = files + "/accel-pyproject.toml";
  metricsAgent = mkScript (files + "/metrics-agent.py");
  inferServer = mkScript (files + "/infer-server.sh");

  accelVenvBin = "/home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin";

  devices = {
    "0000:03:00.0" = "210000000";
    "0000:87:00.0" = "170000000";
  };
  devState = lib.concatStringsSep "\n" (lib.mapAttrsToList (addr: cap: ''
    dev=/var/lib/node37/pci/${addr}
    install -d -m 0755 "$dev/hwmon/hwmon0" "$dev/power"
    [ -e "$dev/gpu_busy_percent" ] || printf '0\n' > "$dev/gpu_busy_percent"
    [ -e "$dev/hwmon/hwmon0/power1_cap" ] || printf '%s\n' '${cap}' > "$dev/hwmon/hwmon0/power1_cap"
    [ -e "$dev/power/control" ] || printf 'auto\n' > "$dev/power/control"
  '') devices);
in
{
  # ---- identity, locale, time --------------------------------------------
  networking.hostName = "node37";
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "C.UTF-8";
  environment.localBinInPath = true;

  # ---- accounts ----------------------------------------------------------
  users.groups = {
    ember.gid = 1000;
    sudo = { };
    accel.gid = 992;
    i2c.gid = 998;
    probe.gid = 997;
  };
  users.users.ember = {
    isNormalUser = true;
    uid = 1000;
    group = "ember";
    home = "/home/ember";
    homeMode = "750";
    shell = pkgs.bashInteractive;
    extraGroups = [ "adm" "sudo" "video" "accel" "i2c" ];
  };
  users.users.probe = {
    isSystemUser = true;
    uid = 997;
    group = "probe";
    home = "/var/lib/metrics-agent";
    shell = "${pkgs.shadow}/bin/nologin";
  };
  # Members of the sudo group may run anything, with their own password (as on the reference).
  security.sudo.extraConfig = ''
    %sudo ALL=(ALL:ALL) ALL
  '';

  # ---- ssh ---------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      Compression = "yes";
      PrintMotd = false;
    };
    hostKeys = [
      { type = "rsa"; bits = 3072; path = "/etc/ssh/ssh_host_rsa_key"; }
      { type = "ecdsa"; path = "/etc/ssh/ssh_host_ecdsa_key"; }
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
    ];
  };
  # The reference's ufw is present but ENABLED=no, and its iptables policies are all ACCEPT.
  networking.firewall.enable = false;

  # ---- base services -----------------------------------------------------
  services.cron.enable = true;
  services.irqbalance.enable = true;
  services.rsyslogd = {
    enable = true;
    defaultConfig = ''
      $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
      $FileGroup adm
      $FileCreateMode 0640
      $DirCreateMode 0755
      $Umask 0022
      auth,authpriv.*                 /var/log/auth.log
      *.*;auth,authpriv.none          -/var/log/syslog
      kern.*                          -/var/log/kern.log
      mail.*                          -/var/log/mail.log
      *.emerg                         :omusrmsg:*
    '';
  };
  services.sysstat = {
    enable = true;
    collect-frequency = "*-*-* *:*:00";
  };
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';

  # ---- power, sleep, kernel ---------------------------------------------
  services.logind.settings.Login = {
    IdleAction = "suspend";
    IdleActionSec = "4h";
  };
  # hibernate and hybrid-sleep are masked on this host.
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  # Before any sleep, stop accelerator holders (see accel-sleep-cleanup.sh).
  systemd.targets.sleep = {
    requires = [ "accel-sleep-cleanup.service" ];
    after = [ "accel-sleep-cleanup.service" ];
  };

  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "pcie_aspm=off"
    "crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M"
  ];

  boot.kernel.sysctl = lib.mapAttrs (_: lib.mkForce) {
    "kernel.hardlockup_panic" = 1;
    "kernel.panic" = 30;
    "kernel.panic_on_oops" = 0;
    "kernel.hung_task_timeout_secs" = 300;
    "kernel.hung_task_all_cpu_backtrace" = 1;
    "kernel.hung_task_panic" = 1;
    "kernel.softlockup_panic" = 0;
    "kernel.nmi_watchdog" = 0;
    "kernel.sysrq" = 176;
    "kernel.kptr_restrict" = 1;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.printk" = "4 4 1 7";
    "kernel.sched_autogroup_enabled" = 1;
    "vm.swappiness" = 60;
    "vm.max_map_count" = 65530;
    "vm.mmap_min_addr" = 65536;
    "net.core.somaxconn" = 4096;
    "net.ipv4.ip_forward" = 0;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
    "net.ipv6.conf.all.use_tempaddr" = 0;
    "net.ipv6.conf.default.use_tempaddr" = 0;
  };

  boot.extraModprobeConfig = ''
    blacklist joydev
    blacklist pcspkr
    blacklist snd_pcsp
    install algif_aead ${pkgs.coreutils}/bin/false
    options iTCO_wdt heartbeat=90
    alias net-pf-3 off
    alias net-pf-6 off
    alias net-pf-9 off
    alias net-pf-11 off
    alias net-pf-12 off
    alias net-pf-19 off
    alias net-pf-21 off
    alias net-pf-36 off
  '';

  # ---- accelerator power state and idle monitor -------------------------
  systemd.services.accel-setup = {
    description = "Initialize accelerator power state and cap";
    wantedBy = [ "multi-user.target" ];
    environment.PCI_SYSFS_ROOT = "/var/lib/node37/pci";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${accelInit}";
      RemainAfterExit = true;
    };
  };

  systemd.services.accel-sleep-cleanup = {
    description = "Stop compute workloads before system sleep";
    unitConfig.DefaultDependencies = false;
    before = [ "sleep.target" ];
    partOf = [ "sleep.target" ];
    environment.PCI_SYSFS_ROOT = "/var/lib/node37/pci";
    path = [ pkgs.coreutils pkgs.util-linux pkgs.procps pkgs.gnused config.systemd.package ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${accelSleepCleanup}";
      ExecStop = "${accelInit}";
      RemainAfterExit = true;
      TimeoutStartSec = "90s";
      TimeoutStopSec = "30s";
    };
  };

  systemd.services.idle-check = {
    description = "Network and device idle monitor";
    after = [ "network.target" ];
    path = [ pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.util-linux pkgs.iproute2 pkgs.gawk pkgs.procps ];
    environment = {
      PCI_SYSFS_ROOT = "/var/lib/node37/pci";
      SUSPEND_CMD = "/usr/local/bin/lab-suspend";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${idleSuspend}";
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
      ExecStart = "${pkgs.bash}/bin/bash -lc 'cd \"$INFER_WORKDIR\" && exec \"$INFER_BIN\" $INFER_ARGS'";
      Restart = "on-failure";
      RestartSec = 5;
      LimitNOFILE = 1048576;
    };
  };

  # ---- metrics agent -----------------------------------------------------
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
      ExecStart = "${metricsAgent}";
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

  # ---- files -------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d /opt/metrics-agent 0755 root root -"
    "L+ /opt/metrics-agent/metrics-agent - - - - ${metricsAgent}"
    "d /opt/node37/bin 0755 root root -"
    "L+ /opt/node37/bin/infer-server - - - - ${inferServer}"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/accel-init.sh - - - - ${accelInit}"
    "L+ /usr/local/bin/accel-sleep-cleanup.sh - - - - ${accelSleepCleanup}"
    "L+ /usr/local/bin/idle-suspend.sh - - - - ${idleSuspend}"
    "L+ /usr/local/bin/lab-suspend - - - - ${labSuspend}"
    "L+ /usr/local/bin/accel-smi - - - - ${accelSmiWrapper}"
    "d /var/lib/node37 0755 root root -"
    "d /etc/default 0755 root root -"
  ];
  environment.etc."default/infer-server".text = ''
    INFER_WORKDIR=/home/ember/infer
    INFER_BIN=/opt/node37/bin/infer-server
    INFER_ARGS='--model lab-model --ctx 100000 --split 55,45 --host 192.0.2.83'
  '';

  system.activationScripts.node37 = {
    deps = [ "users" ];
    text = ''
      ${devState}
      install -d -m 0750 -o ember -g ember /home/ember
      install -d -m 0755 -o ember -g ember /home/ember/infer
      install -d -m 0755 -o ember -g ember /home/ember/accel-env/env
      install -d -m 0755 -o ember -g ember ${accelVenvBin}
      install -m 0644 -o ember -g ember ${accelPyproject} /home/ember/accel-env/pyproject.toml
      install -m 0755 -o ember -g ember ${accelActivate} /home/ember/accel-env/env/activate.sh
      install -m 0755 -o ember -g ember ${accelSmiTool} ${accelVenvBin}/accel-smi
      install -d -m 0755 /var/log/sysstat
    '';
  };

  environment.systemPackages = with pkgs; [
    python3
    curl
    jq
    util-linux
  ];

  system.stateVersion = "26.05";
}
