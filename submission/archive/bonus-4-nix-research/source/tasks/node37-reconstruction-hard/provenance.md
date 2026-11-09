# Author provenance: node37-reconstruction-hard

Status: first draft, 2026-11-03. Not built, not run, no checks validated (author had no permission to run builds/VMs).

Upstream: a REAL private machine, explored read-only on 2026-11-03 (inventory: `author/real/gpu-workstation/inventory.md`).
Ubuntu 26.04 inference workstation with two datacenter accelerators, headless, suspended when idle. No public source; no licence
issue except `LICENSE` copied from node31 for the repo's convention (Apache-2.0 text, not applicable to the original material).

Neutralisation map (agent-facing names -> real):
- host `node37` -> real hostname; operator `ember` (uid 1000) -> real operator; `probe` -> the metrics agent's service user.
- unit `accel-setup` / `accel-sleep-cleanup` / `idle-check.{service,timer}` / `infer-server` / `metrics-agent{,-update}` -> the real `VR-gpu-setup`, `VR-gpu-sleep-cleanup`, `VR-idle-check`, `VR-llama-server`, `beszel-agent{,-update}`.
- `accel-env` uv project -> `~/amd-clean/therock-venv`; `/usr/local/bin/accel-smi` -> the `rocm-smi` wrapper; `activate.sh` -> `env/therock.sh`.
- groups `accel` (992) / `i2c` (113) -> `render` (992) / `i2c` (113); real also has kvm/docker (omitted).
- Device PCI addresses `0000:03:00.0` / `0000:87:00.0` and caps 210 W / 170 W kept verbatim (not sensitive), as the asymmetry is the trap.

Kept (adapted into `cookbooks/host/`):
- Kernel params via late `/etc/default/grub.d/*.cfg` appends + crashkernel; inert `*.cfg.disabled` experiment profile.
- modprobe: `options iTCO_wdt heartbeat=90`, `install algif_aead /bin/false`, one blacklist (real: `radeon`, here `joydev`).
- sysctl: hardlockup_panic, kernel.panic=30, hung-task triple; softlockup_panic deliberately unset.
- logind `IdleAction=suspend`, `IdleActionSec=4h` in the main file; hibernate/hybrid-sleep masked; sleep.target drop-in `Requires`+`After` the cleanup unit.
- Cleanup unit: `DefaultDependencies=no`, `Before`/`PartOf=sleep.target`, `RemainAfterExit`, `ExecStop` = the init script (resume re-applies caps).
- Idle monitor: timer 5 min/5 min, oneshot service, script logic (established non-loopback TCP excluding ports 67/68 and two process names, device busy %, load threshold 2.0, `IDLE_LIMIT=2`).
- Inference unit installed but NOT enabled; `LimitNOFILE=1048576`, `EnvironmentFile`, `bash -lc` launcher.
- uv project with an explicit custom index; env script exporting SDK paths; wrapper script (not symlink).
- Sandboxed metrics agent + daily update timer (`Persistent`, `RandomizedDelaySec=4h`); udev i2c rule; sysstat collect-timer reset.

Scope changes (not real):
- No accelerators: sysfs is replaced by a fixture tree `/var/lib/node37/pci/<addr>/{hwmon/hwmon0/power1_cap,power/control,gpu_busy_percent}`, and the compute device node by `/dev/accel-compute` (absent unless created). Env var `PCI_SYSFS_ROOT` points the scripts at it.
- Real suspend replaced: the idle unit sets `SUSPEND_CMD=/usr/local/bin/lab-suspend`, which only records a timestamp. A VM must not sleep during grading; this is a lab deviation that the agent must reproduce (visible in `systemctl cat idle-check`).
- The real boot race (setup service failed on a missing hwmon file) is not reproduced; fixture files exist before boot.
- The real cleanup script also stops Docker containers; that branch was removed (no Docker). OpenRGB LED blanking, CPU EPP write kept only where `/sys/.../energy_performance_preference` exists.
- Real `uv.lock`, venv contents, ROCm packages, kdump, DKMS, coolercontrol, Tailscale, ufw, Docker: omitted (hardware, network or secrets). The venv is not materialised.
- Distro: Ubuntu 22.04 (CINC 18.11.11 as in node17/31) instead of 26.04; the reference reboots once at provision time so `/proc/cmdline` is real.

Secrets deliberately left out: the lab-access sudoers drop-in and its control script, coolercontrol credentials/TLS key, the metrics agent's hub key/token, shell histories, `.env`/`.secrets`/`.ssh`/`.gnupg`/API-token dotfiles, Tailscale identity, the real stats-hub URL, LAN addresses.

Known risks to resolve when first validated:
1. `kernel.hardlockup_panic` may not exist in the Jammy or NixOS VM kernel (needs hardlockup detector). If absent on either, drop it from the recipe, oracle and `lockup_sysctl`.
2. `systemd.targets.<x>.enable = false` must yield `masked` on NixOS; `UnitFileState` of a disabled unit on NixOS may read `linked` (the check uses `multi-user.target` Wants instead).
3. Jammy's systemd 249 shows `TimeoutStartUSec=1min 30s`; confirm formatting matches on NixOS's newer systemd.
4. `sysstat-collect.timer` unit naming and `services.sysstat.collect-frequency` on 26.05.
5. The grub path: `update-grub` on the cloud image honours `/etc/default/grub.d/60-*.cfg` only after `50-cloudimg-settings.cfg` (alphabetical); verified by the reference reboot gate in `provision`.
