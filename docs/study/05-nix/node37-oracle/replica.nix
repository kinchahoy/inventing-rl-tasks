{ config, lib, pkgs, ... }:
let
  # The reference scripts hard-code Debian paths; map them to store paths.
  # STUDY: The reference shell scripts hard-code Debian paths (/usr/bin/ss, ...). Rewrite them to store paths at build time.
  fix = text: builtins.replaceStrings
    [ "/usr/bin/logger" "/usr/bin/ss" "/usr/bin/awk" "/usr/bin/systemctl" "/usr/bin/sleep" "/usr/bin/kill" ]
    [ "${pkgs.util-linux}/bin/logger" "${pkgs.iproute2}/bin/ss" "${pkgs.gawk}/bin/awk" "${config.systemd.package}/bin/systemctl"
      "${pkgs.coreutils}/bin/sleep" "${pkgs.util-linux}/bin/kill" ] text;
  # STUDY: writeScript = file in the store with mode 0555; used directly as ExecStart.
  script = name: pkgs.writeScript name (fix (builtins.readFile (./files + "/${name}")));
  accelInit = script "accel-init.sh";
  cleanup = script "accel-sleep-cleanup.sh";
  idle = script "idle-suspend.sh";
  labSuspend = script "lab-suspend";
  tools = with pkgs; [ coreutils gnugrep gnused gawk util-linux iproute2 bash procps systemd ];
  fixtures = "/var/lib/node37/pci";
  addrs = [ "0000:03:00.0" "0000:87:00.0" ];
  home = "/home/ember";
  venvBin = "${home}/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin";
in
{
  imports = [ ./complexify.nix ];

  networking.hostName = "node37";
  time.timeZone = "America/Los_Angeles";

  users.groups = { ember.gid = 1000; accel.gid = 992; i2c = { }; sudo = { }; };
  # Ubuntu grants the sudo group full rights by default; NixOS only has %wheel.
  # STUDY: Ubuntu-default rule NixOS lacks (NixOS uses %wheel). Check operator_sudo.
  security.sudo.extraConfig = "%sudo ALL=(ALL:ALL) ALL\n";
  users.users.ember = {
    isNormalUser = true;
    uid = 1000;
    group = "ember";
    extraGroups = [ "adm" "sudo" "video" "accel" "i2c" ];
  };
  users.groups.probe = { };
  users.users.probe = { isSystemUser = true; group = "probe"; shell = "/run/current-system/sw/bin/nologin"; };

  # Kernel command line and modules
  # STUDY: Replaces /etc/default/grub.d/60-node37.cfg + 70-crashkernel.cfg. Checked via /proc/cmdline (kernel_cmdline).
  boot.kernelParams = [
    "intel_iommu=on" "iommu=pt" "pcie_aspm=off"
    "crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M"
  ];
  boot.blacklistedKernelModules = [ "joydev" ];
  # STUDY: modprobe.d content verbatim. `install algif_aead /bin/false`: any failing command works (verifier accepts
  # STUDY: ${pkgs.coreutils}/bin/false too, after a verifier fix).
  boot.extraModprobeConfig = ''
    options iTCO_wdt heartbeat=90
    install algif_aead /bin/false
  '';
  # STUDY: sysctl.d equivalent; checked by reading /proc/sys (lockup_sysctl).
  boot.kernel.sysctl = {
    "kernel.hardlockup_panic" = 1;
    "kernel.panic" = 30;
    "kernel.hung_task_timeout_secs" = 300;
    "kernel.hung_task_all_cpu_backtrace" = 1;
    "kernel.hung_task_panic" = 1;
  };

  # Sleep policy
  # STUDY: logind.conf [Login] section.
  services.logind.settings.Login = { IdleAction = "suspend"; IdleActionSec = "4h"; };
  # STUDY: enable = false on a unit => NixOS masks it (symlink to /dev/null), like Chef's link to /dev/null.
  systemd.targets.hibernate.enable = false;
  systemd.targets."hybrid-sleep".enable = false;
  # STUDY: Adds Requires/After to sleep.target (Chef wrote sleep.target.d/accel-cleanup.conf).
  systemd.targets.sleep = { requires = [ "accel-sleep-cleanup.service" ]; after = [ "accel-sleep-cleanup.service" ]; };

  # STUDY: Fixture sysfs tree. `f path mode user group - content` creates the file only if absent.
  # STUDY: `C+` copies a store file to a mutable location (overwriting), used for the uv-project files in ember's home.
  systemd.tmpfiles.rules =
    [ "d /var/lib/node37 0755 root root -" "d ${fixtures} 0755 root root -" ]
    ++ lib.concatMap (a: [
      "d ${fixtures}/${a} 0755 root root -"
      "d ${fixtures}/${a}/power 0755 root root -"
      "d ${fixtures}/${a}/hwmon 0755 root root -"
      "d ${fixtures}/${a}/hwmon/hwmon0 0755 root root -"
      "f ${fixtures}/${a}/hwmon/hwmon0/power1_cap 0644 root root - 300000000"
      "f ${fixtures}/${a}/power/control 0644 root root - auto"
      "f ${fixtures}/${a}/gpu_busy_percent 0644 root root - 0"
    ]) addrs
    ++ [
      "d ${home}/accel-env 0755 ember ember -"
      "d ${home}/accel-env/env 0755 ember ember -"
      "d ${home}/accel-env/.venv 0755 ember ember -"
      "d ${home}/accel-env/.venv/lib 0755 ember ember -"
      "d ${home}/accel-env/.venv/lib/python3 0755 ember ember -"
      "d ${home}/accel-env/.venv/lib/python3/site-packages 0755 ember ember -"
      "d ${home}/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel 0755 ember ember -"
      "d ${venvBin} 0755 ember ember -"
      "d ${home}/infer 0755 ember ember -"
      "C+ ${home}/accel-env/pyproject.toml 0644 ember ember - ${./files/pyproject.toml}"
      "C+ ${home}/accel-env/env/activate.sh 0755 ember ember - ${./files/activate.sh}"
      "C+ ${venvBin}/accel-smi 0755 ember ember - ${./files/accel-smi-real}"
    ];

  environment.systemPackages = [
    # STUDY: A wrapper script on PATH, not a symlink: the comment explains why (tool resolves bindings relative to its real path).
    (pkgs.writeShellScriptBin "accel-smi" ''
      # wrapper, not symlink: the tool finds its bindings relative to its real path
      exec ${venvBin}/accel-smi "$@"
    '')
  ];

  systemd.services.accel-setup = {
    description = "Initialize accelerator power state and cap";
    wantedBy = [ "multi-user.target" ];
    path = tools;
    environment.PCI_SYSFS_ROOT = fixtures;
    serviceConfig = { Type = "oneshot"; ExecStart = accelInit; RemainAfterExit = true; };
  };
  systemd.services.accel-sleep-cleanup = {
    description = "Stop compute workloads before system sleep";
    # STUDY: Options under unitConfig/serviceConfig are rendered verbatim into [Unit]/[Service]; NixOS has no first-class option for it.
    unitConfig.DefaultDependencies = false;
    before = [ "sleep.target" ];
    partOf = [ "sleep.target" ];
    path = tools;
    environment.PCI_SYSFS_ROOT = fixtures;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = cleanup;
      ExecStop = accelInit;
      RemainAfterExit = true;
      TimeoutStartSec = "90s";
      TimeoutStopSec = "30s";
    };
  };
  systemd.services.idle-check = {
    description = "Network and device idle monitor";
    after = [ "network.target" ];
    path = tools;
    environment = { PCI_SYSFS_ROOT = fixtures; SUSPEND_CMD = "${labSuspend}"; };
    serviceConfig = { Type = "oneshot"; ExecStart = idle; };
  };
  systemd.timers.idle-check = {
    description = "Run idle monitor every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "5min"; OnUnitActiveSec = "5min"; Unit = "idle-check.service"; };
  };

  # Installed, deliberately not enabled
  environment.etc."default/infer-server".text = ''
    INFER_WORKDIR=${home}/infer
    INFER_BIN=/opt/node37/bin/infer-server
    INFER_ARGS='--model lab-model --ctx 100000 --split 55,45 --host 192.0.2.83'
  '';
  systemd.services.infer-server = {
    description = "Inference server";
    after = [ "network.target" ];
    # STUDY: Installed but not enabled: no WantedBy= symlink. mkForce guards against any module adding one.
    wantedBy = lib.mkForce [ ];
    serviceConfig = {
      Type = "simple";
      User = "ember";
      Group = "ember";
      EnvironmentFile = "/etc/default/infer-server";
      ExecStart = ''${pkgs.bash}/bin/bash -lc 'cd "$INFER_WORKDIR" && exec "$INFER_BIN" $INFER_ARGS' '';
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
    environment = { PORT = "45876"; HUB_URL = "https://hub.lab.invalid"; };
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./files/metrics-agent}";
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
    serviceConfig = { Type = "oneshot"; ExecStart = "${pkgs.python3}/bin/python3 ${./files/metrics-agent} update"; };
  };
  systemd.timers.metrics-agent-update = {
    description = "Run metrics agent update daily";
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "daily"; Persistent = true; RandomizedDelaySec = "4h"; };
  };

  # STUDY: check udev_i2c. Haiku H734HNG never looked at /etc/udev/rules.d and missed only this.
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';
}
