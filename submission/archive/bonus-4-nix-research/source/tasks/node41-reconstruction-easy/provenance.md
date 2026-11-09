# Author provenance: node41-reconstruction-easy

Status: first draft, 2026-11-03. Not built, not run, no checks validated (author had no permission to run builds/VMs).

Purpose: a deliberately small companion to the hard tasks, to show that agents can solve an easier version of the benchmark.

Upstream: a REAL private machine, explored read-only on 2026-11-03 (redacted inventory: `author/real/fileserver-nuc/inventory.md`).
Debian 13 fanless mini-PC home file server (Samba, Time Machine target). No public source; `LICENSE` copied from node37 for the repo's convention.

Neutralisation map (agent-facing -> real):
- host `node41` -> real hostname.
- operator `quill` (uid 1000) -> the real operator, forced identity of every share (`force user`).
- group `shared` (gid 1003) -> `samba-users` (gid 1003, kept); `rowan` (1001) / `sage` (1002) -> service accounts `samba-v` / `samba-d` (uids kept); `visitor` (1004) -> invented non-member account for the denial path.
- shares `fast` -> `fastdrive`; `docs` -> `simpleshare` (`veto files=/timemachine/`); `vault` -> `timemachine` (nested inside `simpleshare`'s tree, `fruit:time machine=yes`). Real `backedupshare` and `open-share` omitted; new neutral share `bulk` stands for the share(s) on the array.
- unit `powertop.service` kept verbatim (`Type=oneshot`, `ExecStart=/usr/sbin/powertop --auto-tune`, `RemainAfterExit=true`).
- LAN network `<lan>/24` -> 192.0.2.0/24 (documentation range); `100.64.0.0/10` kept (CGNAT, not sensitive).

Kept (in `cookbooks/host/recipes/default.rb`): standalone `security=user`, `server min protocol=SMB3`, `server signing=auto`,
multi channel, `map to guest=never`, `usershare max shares=0`, `hosts allow/deny`, `vfs objects = catia fruit streams_xattr`
with the `fruit:*` set; per share `valid users=@group`, `force user/group`, create mask 0660 / directory mask 02770 with force modes,
`read only=no`; setgid share roots; sysctl forwarding (from the real Tailscale drop-in, renamed `99-forwarding.conf`); the powertop oneshot.

Left out and why:
- md leftovers, SMART, the stale exFAT mount unit: hardware or decoys.
- Docker + Syncthing, Tailscale, fail2ban, UFW, Cockpit, Avahi, exim, libvirt, NetworkManager: not replicable offline or too large for an easy task.
- Inert decoys (`.next` units, stale mount unit, `AllowUsers` naming a missing user, staged smb.conf): complexifiers, excluded by design.
- sshd hardening: the harness needs root key SSH.
- POSIX ACLs on share roots (the `+` in `ls -l`), `wsdd`, `winbind`, printing settings, share comments (personal wording).
- Samba passwords: not replicable by design; the verifier sets them itself with `smbpasswd` inside the guest.

Deviations: Ubuntu 22.04 + CINC 18.11.11 instead of Debian 13 (Samba 4.15 on the reference, newer on NixOS 26.05); no reboot at provision time (nothing depends on boot); timezone America/Los_Angeles kept (real).

Secrets: none in the inventory or here. The fixture Samba password in `tests/verify.py` is verifier-only and set at check time.

Known risks to resolve when first validated: see the `# CONFIRM` lines in `tests/verify.py` and `verification.md`.

Added (coordinator-approved) emulated storage: the real two 12 TB USB-attached Btrfs RAID1 disks become two 512 MiB raw images attached to the VM as USB mass storage (`qemu-xhci` + `usb-storage`). `provision` creates and attaches them, the recipe runs `mkfs.btrfs -m raid1 -d raid1 -L pool`, creates subvolume `data` and appends the real fstab semantics (`LABEL=ARRAY` -> `LABEL=pool`, `/mnt/array` -> `/mnt/pool`, `nofail,noatime,compress=zstd:3,x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.mount-timeout=30s`, plus `subvol=data`, which the real line lacks). The formatted images are copied to `$OUT/creds` (-> `/opt/contract/usb-{a,b}.img`); `runtime/reference` copies them into its state dir on first start, `tests/verify.py` copies fresh ones next to each candidate VM, and `public/harness.nix` attaches them from relative paths. The share tree `/mnt/pool/bulk` exists only on the image, so a replica must not create it (tmpfiles would trigger the automount at boot).
