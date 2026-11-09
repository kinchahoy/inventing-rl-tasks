# Real machine inventory: fanless mini-PC file server (host label `nuc-fileserver`)

Read-only exploration, 2026-11-03, as an unprivileged user (`sudo -n` needs a password). Secrets redacted.
The macOS laptop that was originally in scope was NOT explored (user correction).

## Identity

- Debian GNU/Linux 13 (trixie); kernel `6.12.95+deb12-amd64` (a Debian 12 backports kernel on a trixie userland; the operator's own plan doc says "Debian 12 with backports 6.12", so the host was upgraded in place).
- Fanless mini-PC (N-series Intel), NVMe root (ext4, 238 GB) + eMMC (unused) + two 12 TB USB-attached SATA disks (JMicron bridge, both report the same synthetic USB serial).
- `/proc/cmdline`: `BOOT_IMAGE=... root=UUID=... ro quiet` (no custom parameters; `/etc/default/grub` is stock apart from `quiet`).
- Time zone America/Los_Angeles, RTC in local time (dual-boot leftover warning from `timedatectl`).
- Role: home file server (Samba, Time Machine target, Syncthing in Docker) plus a "warm standby" Docker host. Operator docs on the box (`~/nuc-fileserver-prep/*.md`, ~90 kB) describe intent; they are not copied here.

## Deliberate configuration

### Storage
- `/etc/fstab`: root ext4 `errors=remount-ro`, ESP `umask=0077`, swap partition, and one deliberate line:
  `LABEL=ARRAY /mnt/array btrfs nofail,noatime,compress=zstd:3,x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.mount-timeout=30s 0 0`.
  Automount: `findmnt` shows nothing at `/mnt/array` until first access (a `df`-style check passes only after touching the path).
- Btrfs RAID1 across the two whole USB disks (no partition table, no LUKS). Needs root to inspect (`btrfs filesystem show`).
- Leftover commented-out older fstab line ("Old BTRFS mount", by UUID).
- `/etc/systemd/system/mnt-raid_array.mount`: **stale/inert** unit for an exFAT stick by UUID at `/mnt/raid_array`, `Requires=systemd-fsck@dev-md0.service`; not enabled-wanted by anything real. `mdadm.conf` lists two md arrays (`/dev/md/0`, `/dev/md0`, hostnames "nuc"/"NUCNAS") but `/proc/mdstat` is empty: both are leftovers.
- `/etc/modprobe.d/mdadm.conf`: distro `options md_mod start_ro=1`.
- `smartd` via distro units; `/etc/smartd.conf`: `DEVICESCAN -d removable -n standby -m root -M exec /usr/share/smartmontools/smartd-runner` (the `-n standby` skips spun-down disks; note USB bridges often hide SMART).
- Staged but not installed (`*.next` in `/etc/systemd/system/` and `~/nuc-fileserver-prep/`, root-only readable in /etc): monthly Btrfs scrub service+timer (`Sun *-*-01..07 03:00`, `Nice=19`, idle I/O class), a rewritten fstab line (adds `x-systemd.device-timeout=30s`), a fail2ban logrotate fix. Systemd ignores the `.next` suffix: textbook inert decoys.

### Samba (`/etc/samba/smb.conf`, live, Cockpit-flavoured; the cleaned "final" version is only staged)
- `[global]`: standalone server, `security=user`, `server min protocol=SMB3`, `server signing=auto`, `server multi channel support=yes`, `map to guest=never`, `usershare max shares=0`, printing off, `hosts allow = 127.0.0.1 <lan>/24 100.64.0.0/10`, `hosts deny = 0.0.0.0/0`, `vfs objects = catia fruit streams_xattr`, `fruit:aapl=yes`, `fruit:metadata=stream`, `fruit:resource=file`, `fruit:encoding=native`, `fruit:nfs_aces=no`, `fruit:zero_file_id=yes`.
- Shares (all `valid users=@samba-users`, `force user=<operator>`, `force group=samba-users`, create 0660 / dir 02770 with `force create mode`/`force directory mode`): `fastdrive` (NVMe dir `/srv/samba-fastdrive`), `simpleshare` (`veto files=/timemachine/`, `delete veto files=no`), `backedupshare`, `open-share` (name says open, actually authenticated), `timemachine` (`fruit:time machine=yes`, nested inside `simpleshare`'s tree and vetoed from it).
- Groups: `samba-users` (gid 1003, members incl. two service accounts `samba-v`, `samba-d` uid 1001/1002, home dirs, bash) and `sambashare` (gid 995). Samba password DB is root-only.
- Units: `smbd`, `nmbd`, `winbind`, `wsdd` (dynamic user), `samba-ad-dc` (enabled but `is-configured` gate: standalone, so inactive), Avahi.
- Dir ACLs: share roots are setgid `drwxrwsr-x+` (the `+` means POSIX ACLs; `getfacl` shows details; owner = operator, group samba-users).

### Network and firewall
- `/etc/sysctl.d/99-tailscale.conf`: `net.ipv4.ip_forward=1`, `net.ipv6.conf.all.forwarding=1` (subnet router + exit node). `tailscaled` enabled, `PORT=41641`. Key expiry disabled (per operator doc), `accept-routes=false`.
- UFW installed and enabled-at-boot unit present; `/etc/default/ufw` stock (input DROP, forward DROP). Operator doc (2026-09) says UFW was `inactive` at the time; current `ufw.service` is enabled. Rules in `/etc/ufw/*.rules` are root-only: unknown.
- NetworkManager profiles (wired, USB ethernet, wifi) — Wi-Fi PSK inside, not read. `/etc/hosts` has a stale `nucn51.local` entry. DHCP reservation on router; `.52` stable address.
- fail2ban: `jail.d/defaults-debian.conf` (nftables banactions, sshd backend=systemd) and `jail.local` `ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10`. Boot-race logrotate bug on `/var/log/fail2ban.log` (postrotate runs before the daemon is up) — documented, fix staged as `.next`.
- sshd: `PermitRootLogin no`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `UsePAM no`, `X11Forwarding yes`, `AllowUsers <operator> backup-nuc10i5`, plus `Match User backup-nuc10i5` -> `ForceCommand internal-sftp`, no forwarding, no TTY. The `backup-` user does not exist in passwd (inert allowlist entry). `sshd_config.d/` empty. (Interacting detail: `AllowUsers` before `Match`, `UsePAM no` + `PasswordAuthentication no`.)
- Listeners: 22, 139, 445, 9090 (Cockpit), 25 (exim4, loopback), docker-published 8384/22000 (Syncthing) and 3553 (agent) bound to the LAN IP, WSD 5357 per bridge/iface, tailscale ports.

### Sleep / power
- No `sleep.conf.d`, `logind.conf.d`, `system-sleep` additions; `logind.conf` and `sleep.conf` are stock (empty). `sleep.target.wants/syncthing-resume.service` (package-provided).
- Distro `/usr/lib/systemd/system-sleep/hdparm` (APM resume hook) and `sysstat.sleep`.
- `powertop.service` (custom, enabled): `Type=oneshot`, `ExecStart=/usr/sbin/powertop --auto-tune`, `RemainAfterExit=true`. Interaction: powertop auto-tune turns USB autosuspend on, which is a classic cause of USB disk bridge drop-outs; the operator doc notes the USB link was fixed to SuperSpeed.
- `/sys/power/mem_sleep`: `s2idle [deep]`; `hibernate`, `hybrid-sleep`, `suspend*` targets all `static` (not masked). A headless server that is nevertheless suspendable.

### Containers, cron, misc
- Docker (docker-ce, user in `docker` group): Syncthing 2.1.7 (ports bound to LAN IP only, healthy) and an agent container. Compose project dirs under the operator's home (`~/installs`), podman also installed with auto-update timer.
- libvirt/virtlockd/virtlogd, open-iscsi, nfs-client, Cockpit socket (`/etc/cockpit/disallowed-users`), Avahi, exim4, sysstat (distro cron.d).
- No user crontab. Timers are distro ones (apt-daily*, fstrim weekly, mdcheck, e2scrub, logrotate, man-db).
- `/etc/sudoers.d/` only README (no custom grants readable; real rules are in sudo group).
- Tools in `/usr/local/bin`: ark, arkade, k3sup, micromamba, starship. No custom Python/uv env.

## Not readable
`/etc/ufw/*.rules`, Samba tdb/passwords, `/etc/systemd/system/*.next` (mode 0600 root), `/var/spool/cron`, Btrfs device layout, SMART data, NetworkManager PSKs, fail2ban state, journal beyond own user (adm not in groups).

## Assessment

Replicability in a VM: **medium for config, none for the storage story.**
- Reproducible with plain NixOS options: Samba global + five share definitions (`services.samba.settings`), groups/uids, sysctl forwarding, fail2ban jail, sshd AllowUsers/Match, powertop oneshot (`systemd.services` + `powerManagement.powertop`), fstab automount line (`fileSystems."/mnt/array"` with `options`, but needs a labelled disk; a VM can fake it with a second virtio disk labelled `ARRAY` formatted btrfs — feasible but then it is a provisioning dependency), NetworkManager/Tailscale (Tailscale cannot join a tailnet; effective config only).
- Hardware-bound: USB DAS enumeration, Btrfs RAID1 (a VM can host a 2-device btrfs raid1 on two virtio disks), SMART/spin-down, powertop effects, `mem_sleep`, Wi-Fi, Tailscale identity.
- Trickiness is **moderate, mostly Samba**: `force user` + setgid dirs + `veto files` + nested share path (timemachine inside simpleshare), `fruit:*` parameter set, `hosts allow/deny` order, `valid users=@group`. Several inert decoys (`.next` units, stale `mnt-raid_array.mount`, `AllowUsers` naming a non-existent user, staged `smb.conf.clean-final` that differs from live). Checks would use `testparm -s`, `smbclient -L`, `smbclient //127.0.0.1/share` with a fixture user, `findmnt`, `systemctl show`.
- Weak for the "kernel cmdline / modprobe / sleep" theme: the machine has almost none of it. Poor fit for that angle.
- Sensitive: lots of personal paths and the operator's private planning docs; recipe would need heavy neutralisation (share names/comments contain personal wording).

Verdict: workable second candidate (Samba + storage + Debian 13 on Debian family), but the other machine matches the requested theme (kernel params, modprobe, sysctl, custom sleep logic, uv environment) far better. Not drafted.
