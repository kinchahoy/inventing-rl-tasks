Reconstruct the running machine as a NixOS 26.05 VM.

Start the reference with `/opt/runtime/reference start` and get a root shell
with `/opt/runtime/guest`. Ports: SSH 2222, HTTP 8080, HTTPS 8443. Its
configuration and behavior are the specification. Changes to it are disposable.

Graded: everything that affects how this machine is used by its tenants,
clients and operator. The goal is a drop-in replacement. Differences that come
only from the OS don't matter: kernel and version strings, package names, where system config files live, stock utilities nobody here is likely to need. Paths, names, identities, credentials, defaults and the commands people are likely to use for this machine's job do. No data migration: recreate what the server was
provisioned with (accounts, empty databases, seeded files), not data its users
added later.

Submit /app/submission/replica.nix, a plain NixOS module, plus local supporting
files. A minimal module is supplied. The harness imports it against the pinned
nixpkgs 26.05 at /opt/nixpkgs (revision in /opt/contract/flake.lock) with
Nix 2.35.4 on x86_64-linux and system.stateVersion = "26.05". No flake or lock
file is needed; use the normal pkgs/lib/config arguments. The build has no
network access.

The harness provides boot resources, port forwarding, root SSH and TLS: the server
certificate and key are installed at /etc/node/server.{crt,key}, and clients
trust /opt/contract/ca.crt.

Tools:
- `/opt/contract/check-replica [--syntax-only]` parses your Nix files and
  evaluates the full VM configuration without building or booting.
- `/opt/contract/build-replica` builds it. From a fresh writable directory, run
  /app/replica-vm/bin/run-*-vm. Candidate ports: SSH 3222, HTTP 9080,
  HTTPS 9443; `GUEST_SSH_PORT=3222 /opt/runtime/guest` opens its root shell.

The verifier boots a fresh disk from your submission, adds small programs and
data as the existing users, uses ordinary clients, and inspects effective
configuration. Passwords and fixture TLS keys on this lab machine are public.

Only /app/submission transfers to the verifier. Use real services. Do not copy
or embed the reference OS, fetch a remote answer, import paths outside your
submission and /opt/contract, or contact the reference at verification time.
