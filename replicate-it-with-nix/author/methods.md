# Verification methods

How replica tasks check that a submission is a drop-in for the reference. Worked example: `node17-reconstruction-hard/tests/verify.py` and `author/tasks/node17-reconstruction-hard/verification.md`.

The goal is a fast, deterministic, roughly 90%-right signal for each property, not proof. Pick the cheapest check that a wrong replica would fail.

## Ranking

1. **Inside, deterministic.** One SSH command that reads live state or asks a running daemon. Quick (under 50 ms). The default.
2. **Quick external call.** One client request through the forwarded port. Use it when the property is the network contract itself: listeners, firewall, certificates, redirects.
3. **Anything else** (reboots, load, timeouts, fill-until-full, second VMs): ask the human first, with a rough time and effort estimate.

Estimate a check's cost; don't time it. The oracle control catches any bad estimate.

## Rules

**Ask the running daemon, not the distro's files.** The replica writes different files at different paths. Have the live process report its effective config through its own binary:

| Daemon | How to read effective config |
| --- | --- |
| PHP-FPM | master title in `/proc/<pid>/cmdline` names its config → `<exe> -tt -y <config>` prints every parsed pool value |
| Apache | master's `/proc/<pid>/exe`, argv and environ → rerun with `-t -D DUMP_INCLUDES` → grep only the files it loaded |
| sshd | `sshd -T` (add `-C user=…` for `Match` blocks) |
| memcached | `stats settings` over the socket |
| PostgreSQL / MariaDB | `SHOW <setting>`, `SHOW data_directory`, `pg_authid`, `pg_hba_file_rules`, `SELECT @@datadir` |
| systemd | `systemctl show <unit> -p <Property>`; `systemd-tmpfiles --cat-config`; `systemd-analyze cat-config <file>` |
| Kernel and network | `/proc/cmdline`, `/proc/sys/...`, `ss -lntup`, `ps -o user=`, `findmnt -T`, `getent` |

This is how `server_tuning` checks FPM `pm.*`, `request_terminate_timeout`, the deleted `www` pool, `ProxyTimeout 90`, the 32 MB memcached cap and UDP-off in one quick call on either Ubuntu or NixOS. Load-testing the same settings would take minutes and still be flaky.

**Prefer settings to rehearsals.** `persistent_storage` replaces a full reboot. Data paths, including each database's live data directory, must not be on tmpfs, and no `systemd-tmpfiles` rule may remove or age-clean them. The first boot already shows that services start at boot. What a real reboot would add (a custom boot script that wipes data) is listed under extensions.

**Take exact values from the reference.** Probe the reference once (uids, gids, modes, setting values), then assert equality. Do not use ranges, "non-empty" or "differs from". `accounts` used to accept any two distinct uids; it now requires 1101/1102.

**Every denial check also asserts the allowed path.** A check that only expects "permission denied" passes when the service is missing. `postgres_isolation` failed open this way until it also required each tenant to reach its own database. The `nop` control found it.

**Outside only for the network contract.** An inside `curl` misses a closed firewall port or a broken forward, so web checks go through the port forward.

**Plant fresh state only when the check reads back something a submission could pre-stage**, such as served files or executed scripts. Use a random name per run. Read-only state checks (modes, settings, listeners) don't need it.

**Shared SSH is for speed only.** `runtime/guest` multiplexes connections, so a check costs one command, not one handshake. Correctness doesn't depend on it; leave it on.

**Never** grep fixed distro config paths, list packages, diff file trees, `sleep` for readiness (poll instead), or check how a property is implemented (suEXEC vs FastCGI) when what matters is the result (the uid).

## Controls

| Control | Command | Expected |
| --- | --- | --- |
| Reference (author time, not per trial) | `mise run check-reference <task>` | every check passes |
| Oracle | `harbor run -p <task> -a oracle -y` | reward 1.0 |
| Empty submission | `harbor run -p <task> -a nop -y` | reward 0.0; any pass is a check that fails open |

`checks.json` records build, boot and per-check seconds.

## Adding a check

- [ ] Names a property a client, tenant or operator would notice if it changed.
- [ ] Uses the highest-ranked method that a wrong replica would fail.
- [ ] Asserts exact reference values; denials are paired with the allowed path.
- [ ] Reads config through the running daemon, never a distro path.
- [ ] Passes on the reference, passes on the oracle, fails on `nop`.
- [ ] Is quick by estimate, or the human approved its cost.

## Extensions for tighter validation

Not worth it by default, either because of cost or because they'd constrain valid solutions. A stricter variant of a task can opt in.

| Extension | Adds | Cost | Why not by default |
| --- | --- | --- | --- |
| Major-version match (PostgreSQL 14, MariaDB 10.6) via `SHOW server_version_num` | Data dirs and physical backups interchangeable | quick | Forbids valid upgrades (PG 14 is EOL 2026-11-12); PHP 8.1 isn't in nixpkgs 26.05 |
| Directory listing (`Options Indexes`) and `AllowOverride` boundary | Two more tenant-site behaviors | 2 requests | Low client impact; cheap enough to promote |
| Access-log format (`combined`) | Log parsers keep working | quick | Low client impact |
| Strict listener allowlist (nothing public except 22/80/443) | No new exposure | quick | Brittle: legitimate NixOS helpers may listen |
| Full reboot with written state read back | Catches custom boot scripts that wipe data | ~20 s | `persistent_storage` covers the common causes from settings |
| Restart each service, then re-probe | Units recover without a reboot | 5–10 s | Low yield |
| FPM limits under load (`max_children`, kill at 180 s) | Behavior, not just config | minutes | `server_tuning` reads the same values |
| Slice enforcement (allocate to 90% RAM, expect OOM) | Limit enforced, not just set | 10–30 s, can destabilize the VM | `slice_limits` reads the live property |
| memcached fill to the 32 MB cap | Cap enforced | ~32 MB writes | `stats settings` reports it |
| Differential HTTP against the reference | Catches unknown unknowns | second VM per trial | Brittle (`Server`, `Date`, versions) |
| Dump-and-restore from the reference | Real data migration | 30 s+, second VM | Exact uid/gid plus SQL checks give most of it |
