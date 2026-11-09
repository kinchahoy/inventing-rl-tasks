---
name: node31-nixos-replica
description: Status and gotchas for the node31 Ubuntu->NixOS 26.05 replica task (/app/submission/replica.nix)
metadata:
  node_type: memory
  type: project
  originSessionId: c260c340-19b0-45da-84ab-0e735b2527ed
  modified: 2026-11-04T07:41:28.761Z
---

Reference `node31` is Ubuntu 22.04 monitoring host: nginx (80 -> 443 redirect, TLS 1.2/1.3, basic auth realm "node31", user pine), Prometheus 2.31 / Alertmanager 0.23 / blackbox 0.19 / node_exporter 1.3 with Debian-style units and /etc/default/* ARGS, a Python alert webhook sink on 127.0.0.1:19190, and a 60s node31-inventory textfile timer. Users reed (1401) and sage (1402) have locked passwords.

**Why:** the verifier builds offline from /nix/store, so only packages already realized there are safe (prometheus 3.12.0 + -cli, alertmanager 0.31.1, blackbox 0.28.0, node_exporter 1.11.1, nginx 1.30.6, openssh 10.6p1, python3 3.13). Procps, gawk, chef/cinc are NOT realized.

**How to apply / gotchas found:**
- nixpkgs `dialout` defaults to gid 27 and clashes with `sudo`; `lp` is 20 — don't force gids for system groups.
- NixOS nginx vhost needs `onlySSL = true` for `ssl_certificate` to render; `http2 = false` to match reference (HTTP/1.1).
- NixOS nginx runs the whole unit as `services.nginx.user`, so the 0600 root key fails; fix with `User=root`, `prependConfig = "user www-data;"`, drop SystemCallFilter, and set both CapabilityBoundingSet and AmbientCapabilities (empty string means *no* caps, and CAP_SETUID must be in ambient too).
- `systemctl ssh` alias: `systemd.services.sshd.aliases = ["ssh.service"]`.
- Not replicated on purpose: Cinc omnibus (/opt/cinc), apt textfile timer, SSH host keys (generated per boot), snapd/lxd/cloud-init/ufw noise.

**Status:** final module passes check-replica and build-replica; booted replica matches reference on HTTP/TLS/auth, sshd settings, users, Prometheus targets/probes/rules, Alertmanager routing, and the alert sink.

