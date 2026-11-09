---
name: node31-nixos-replica
description: Task state for rebuilding the node31 Ubuntu monitoring box as /app/submission/replica.nix (NixOS 26.05); key decisions and gotchas.
metadata:
  node_type: memory
  type: project
  originSessionId: d7c7ae4b-3805-429e-9bc3-479d1b59f120
  modified: 2026-11-04T08:34:33.403Z
---

Goal: NixOS module replicating the Ubuntu 22.04 "node31" reference (/opt/runtime/reference). Monitoring front end: nginx 80->443 (TLS, basic auth realm node31, user pine), /healthz, / (index.txt), /prometheus/ and /alertmanager/ proxies; Prometheus 2.31 (Ubuntu) and Alertmanager, blackbox, node exporter, alert-sink webhook on 127.0.0.1:19190, node31-inventory timer; users reed (1401) and sage (1402) with locked passwords.

**Why:** drop-in replacement graded on client-visible behaviour, users, operator commands and effective config.

**How to apply:**
- Seeded configs were copied byte-for-byte from the reference into /app/submission/files (prometheus/, htpasswd, index.txt, alert-sink.py, node31-inventory.sh). Re-copy with `/opt/runtime/guest 'cat PATH'` if they need to be checked.
- SSH host keys (ed25519/rsa/ecdsa) were copied from the reference so clients keep the pinned identity. Flag this to the user; it is a judgement call.
- gid 27 is NixOS's dialout, so the `sudo` group takes an auto gid (reference had 27). Not client-visible.
- Reference packages use Prometheus 2.31, Alertmanager 0.23, node_exporter 1.3; the replica uses the store's 3.12 / 0.31.1 / 1.11.1, and promtool/amtool/blackbox validate the seeded configs.
- Not replicated: apt/smartmon/ipmi textfile collectors, snapd/lxd, unattended-upgrades, cinc, nginx echo/geoip2 modules (loaded but unused), Ubuntu .bashrc.
- Port 80/443 forward from the host; `/opt/runtime/reference` must be stopped before using 2222/2080/2443 for comparison runs.
