Reconstruct the running machine as a NixOS 26.05 VM. You have 30 minutes.

Start the reference with `/opt/runtime/reference start` and get a root shell
with `/opt/runtime/guest`. Forwarded port (host→guest): 2222→22. Its
configuration and behavior are the specification. Changes to it are disposable.

Graded: everything that affects how this machine is used by its operator and
its services. The goal is a drop-in replacement. Differences that come only
from the OS don't matter: kernel and version strings, package names, where system config files live, stock utilities nobody here is likely to need. Paths, names, identities, unit behavior, defaults the operator relies on, and the commands people are likely to use for this machine's job do. No data migration:
recreate what the machine was provisioned with, not data added later.

Submit /app/submission/replica.nix, a plain NixOS module, plus local supporting
files. A minimal module is supplied. The harness imports it against the pinned
nixpkgs 26.05 at /opt/nixpkgs (revision in /opt/contract/flake.lock) with
Nix 2.35.4 on x86_64-linux and system.stateVersion = "26.05". No flake or lock
file is needed; use the normal pkgs/lib/config arguments. The build has no
network access.

The harness provides boot resources, port forwarding and root SSH. It also attaches the machine's two USB data disks as fixtures, like the TLS and SSH material: images /opt/contract/usb-a.img and usb-b.img. To run a candidate, copy both into the fresh directory first; they are attached from there. The harness boots your module through NixOS's qemu-vm module, which replaces `fileSystems`: declare mounts other than the root disk under `virtualisation.fileSystems`.

Tools:
- `/opt/contract/check-replica [--syntax-only]` parses your Nix files and
  evaluates the full VM configuration without building or booting.
- `/opt/contract/build-replica` builds it. From a fresh writable directory, run
  /app/replica-vm/bin/run-*-vm. Candidate forwarded port: 3222→22; `GUEST_SSH_PORT=3222 /opt/runtime/guest` opens its root shell.

The verifier boots a fresh disk from your submission, connects over SSH, runs
the machine's own commands and units, and inspects effective configuration.

Only /app/submission transfers to the verifier. Use real services. Do not copy
or embed the reference OS, fetch a remote answer, import paths outside your
submission and /opt/contract, or contact the reference at verification time.
