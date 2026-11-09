Reconstruct the running machine as a NixOS 26.05 VM. You have 60 minutes.

Start the reference with `/opt/runtime/reference start` and get a root shell
with `/opt/runtime/guest`. Forwarded ports (host→guest): 2222→22, 2080→80, 2443→443. Its
configuration and behavior are the specification. Changes to it are disposable.

Graded: everything that affects how this machine is used by its clients,
users and operator. The goal is a drop-in replacement. Differences that come
only from the OS don't matter: kernel and version strings, package names, where
system config files live. Paths, names, identities, credentials and defaults
that users rely on do. No data migration: recreate what the server was
provisioned with (accounts, keys, seeded configuration data), not data its users
added later.

Submit /app/submission/replica.nix, a plain NixOS module, plus local supporting
files. A minimal module is supplied. The harness imports it against the pinned
nixpkgs 26.05 at /opt/nixpkgs (revision in /opt/contract/flake.lock) with
Nix 2.35.4 on x86_64-linux and system.stateVersion = "26.05". No flake or lock
file is needed; use the normal pkgs/lib/config arguments. The build has no
network access.

The harness provides boot resources, port forwarding, root SSH and TLS: the server
certificate and key are installed at /etc/node31/server.{crt,key}, and clients
trust /opt/contract/ca.crt.

Tools:
- `/opt/contract/check-replica [--syntax-only]` parses your Nix files and
  evaluates the full VM configuration without building or booting.
- `/opt/contract/build-replica` builds it. From a fresh writable directory, run
  /app/replica-vm/bin/run-*-vm. Candidate forwarded ports: 3222→22, 3080→80, 3443→443; `GUEST_SSH_PORT=3222 /opt/runtime/guest` opens its root shell.

The verifier boots a fresh disk from your submission, connects with ordinary
clients, runs small programs as the existing users, and inspects effective
configuration. Passwords and fixture TLS keys on this lab machine are public.

Only /app/submission transfers to the verifier. Use real services. Do not copy
or embed the reference OS, fetch a remote answer, import paths outside your
submission and /opt/contract, or contact the reference at verification time.

Before you finish, compare the reference and your replica systematically, and fix every difference you find.
