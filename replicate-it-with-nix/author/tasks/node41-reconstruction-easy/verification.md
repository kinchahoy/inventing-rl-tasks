# node41 verifier: coverage and cost

Run and validated (reference, oracle, nop). 16 recipe checks, no complexifiers, in `node41-reconstruction-easy/tests/verify.py`. One to three SSH commands each (methods.md rank 1); only port 22 is forwarded. Candidate VMs get fresh copies of the two USB fixture images from `/opt/contract`. Samba clients run inside the guest against 127.0.0.1.

| Check | Reads | Paired allowed/denied path |
| --- | --- | --- |
| host_identity, accounts | hostname, timezone, `getent`, `id -nG` (exact uids/gids 1000-1004) | visitor not in `shared` |
| share_dirs | `stat` owner:group:mode 2775 on three trees; not tmpfs | none |
| smb_global | `testparm -sv`: protocol, guest policy, hosts allow/deny, vfs order, fruit set | none |
| smb_shares | `testparm -sv` per share: path, valid users, force user/group, read only, four modes, veto, delete veto, time machine | exact share set |
| share_list | `smbclient -L -g` Disk entries = fast, docs, vault | none |
| share_write_ownership | member `put` to `fast`, on-disk `quill:shared:660`, a second member `get` round-trips | write allowed and force user observed |
| new_dir_modes | `mkdir` over SMB lands as `quill:shared:2770` | none |
| share_access | member ls works; non-member refused (ACCESS_DENIED); wrong password (LOGON_FAILURE); anonymous refused | member ls |
| veto_nested | file written via `vault` share is listed there and on disk, but `docs` neither lists `vault` nor serves its contents | `vault` share works, `docs` serves other files |
| smb_listeners | `ss -p`: smbd on 139/445, nmbd on UDP 137/138 (unit names differ per distro) | none |
| array_automount | first check: `mnt-pool.automount` active, Where, idle 10min; mountpoint shows only `autofs` before access; `ls` triggers a `btrfs` mount | untouched vs triggered |
| array_mount | `findmnt` options (noatime, compress=zstd:3, subvol data), mount timeout 30s, `btrfs filesystem df` Data/Metadata RAID1, `show` 2 devices, label `pool` | none |
| array_share | `bulk` put by a member lands `quill:shared:660` on btrfs; dir `2775`; second member sees it; non-member refused | write allowed, outsider denied |
| forwarding_sysctl | `/proc/sys` ip_forward and ipv6 forwarding = 1 | none |
| power_unit | `powertop.service` Type, RemainAfterExit, ExecStart argv, in `multi-user.target` Wants | none |

The verifier assigns Samba passwords itself (`smbpasswd -s -a`); the replica only has to provide the Unix accounts and the daemon. Unit activity of `powertop.service` is not asserted (powertop may not complete in a VM).

## Not checked
Time Machine behaviour (no client), multichannel, signing negotiation (`server signing = auto` not asserted: testparm may print `default`), SMART/disk errors, firewall, remaining real services.

## Controls
- Reference: `mise run check-reference node41-reconstruction-easy` passes all 16 checks (~1 s of checks after ~20 s boot; every check under 0.2 s).
- Oracle: `jobs/2026-11-03__18-10-10`, reward 1.0 (16/16; build 126 s, candidate boot ~20 s).
- nop: `jobs/2026-11-03__18-12-59`, reward 0.0 (0/16; build 117 s, boot 18 s).

## Resolved on the reference
- `testparm -sv` prints only non-default values per share section, so `delete veto files = no` is absent from `[docs]`; the check falls back to the `[global]` default. `usershare max shares = 0` is compared as text (the boolean mapper turned `0` into `no`).
- `mnt-pool.automount` (Where `/mnt/pool`, idle 10min), `findmnt` autofs-before-access, octal modes, `2775` roots, setgid on SMB-created directories, `smbclient` markers, `powertop.service` ExecStart/Wants all matched the draft expectations; USB devices appear as `sda`/`sdb` TRAN=usb with label `pool`.
- Candidate VM: the NixOS run script `cd`s into a scratch directory, so `public/harness.nix` addresses the fixtures as `$OLDPWD/usb-*.img` (the directory the script was started from).
- NixOS: `qemu-vm.nix` overrides top-level `fileSystems`; the oracle mounts the array with `virtualisation.fileSystems."/mnt/pool"`. A top-level `fileSystems` entry is silently dropped (automount unit missing). Agents must discover this.
