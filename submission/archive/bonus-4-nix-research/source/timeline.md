# Development timeline

Local time (PST). Times marked ~ are approximate: the 2 Nov evening entries are
inferred from file mtimes, job directory names and the commit log, because the
sessions that did that work have no surviving transcript.

## Timeline

| When | Milestone |
|---|---|
| 11-02 12:40 | Workspace created (commit `561c58d`). |
| 11-02 ~afternoon/evening | `vision.md` plan: two tasks from the OSM Chef Planet archive, `osm-chef-planet-archive-easy` and `-hard` (30 proposed checks). Contract at that point: the agent gets a flake and a reference VM and submits a NixOS flake. |
| 11-02 ~22:55-23:15 | Easy task built: Dockerfiles, CINC-provisioned reference qcow2, fixture, harness, `verify.py`, oracle `solve.sh`. Never run, only written. |
| 11-02 ~23:30-23:50 | **Pivot: the hard task is no longer the archive.** `node17-reconstruction-hard` takes shape instead, as a renamed, scoped derivative of the OSM Chef `faffy`/dev host. That is multi-user web hosting: Apache with PHP-FPM, WSGI and CGI, PostgreSQL, a MariaDB-compatible database, memcached, restricted log sudo and per-user slice limits. Provenance moves author-side. |
| 11-02 23:53 | First Harbor oracle run: reward 0. |
| 11-03 00:18-00:26 | Four more oracle attempts: three `RewardFileNotFoundError`, one reward 0. These zeros were harness errors, not a verified oracle failure. |
| 11-03 01:22 | Commit `46d09f5` "Three attacks on the problem" (the only commit of this directory). It holds the easy task, node17, the persistent builder and `vision.md`. |
| 11-03 01:31-01:51 | Review of the build approach, then restructure into a shared graph: `author/{images,contract,pins,builder,tasks}`, one persistent builder, a Docker volume for the Nix store and a `docker-bake.hcl`. Two migration bugs (builder public key, sshd config path). Prepare plus `check-tools`, `check-oracle` and `check-builder` pass (the second prepare took ~35 min). |
| 11-03 02:18 | Waiting on the user to start the oracle VM build, which had never passed. |
| 11-03 09:11 | Session resumed from `handoff.md`. |
| 09:14-09:46 | Oracle bring-up, one fix per run: read-only `/etc` drop-in (systemd slices as drop-in), then the QEMU `-accel` vs `-machine accel=` clash (VM never booted, reward 0), then Apache `ErrorLog` and `WSGISocketPrefix` (14/30), then PHP-FPM `ProtectHome` (23/30). |
| 09:46 | **First oracle pass, 30/30** (~4 min/trial). |
| ~09:50-10:45 | Verifier audit with the owner: checks tightened to reference-exact values, shared SSH, per-check timing, `server_tuning` reads effective config from the running daemons, `persistent_storage` replaces a reboot check. The first nop control crashed the verifier (hard-coded VM name) and exposed two fail-open isolation checks; both fixed. Reference control moved to author time (`mise run check-reference`). `author/methods.md` written. |
| 10:41-10:48 | Oracle 31/31 (164 s/trial), **nop 0/31**. |
| ~10:50-11:30 | Complexifiers: `author/complexify.md` catalogue, then three added (sudo decoy, login limits, log rotation), tagged by `origin`. **Contract reached its current shape.** The published surfaces list and `/opt/contract/README.md` are gone. One plain `instruction.md` remains: drop-in replacement, graded scope as a sentence, no data migration. A read-only Sonnet fairness review led to a seeded `cgi-bin/hello.py` and a looser `log_rotation` check. Budget raised 30 to 60 min. |
| 11:11-11:35 | Final controls on 34 checks: oracle 34/34 (11:19, 11:29), reference 34/34, nop 0/34. (The 11:11 run scored 0.97 because of a `log_rotation` parser bug in the verifier, fixed before the 11:19 pass.) |
| **11:36-12:37** | **First true model run, Haiku 5.5 (reasoning effort high), 60 min: reward 0.82** (recipe 27/31, complexifiers 1/3). 56 min, 78 LLM calls, 88 tool calls, 12 builds, 4 VM boots, $0.66. Misses were genuine: sudo rule rewritten to a store path, no slice limits, no `REVOKE CONNECT`, CGI run as www-data, two complexifiers. The agent kept track of the clock but stopped believing it was done. `trial-stats.py` added. |
| ~12:00-13:00 | Further hard tasks drafted from Wikimedia puppet: node23 (resolver), node29 (mail, kept as backup because Dovecot versions and async delivery make validation costly), node31 (monitoring). Names neutralised. Version-gap policy: optional gaps are fine, forced gaps (pdns-recursor 5.x, dnsdist 2.x) are minimised. node23 oracle scored 0.92 at 13:00 (not yet 1.0). |
| 13:01-13:05 | The first 120-min Haiku run (`node17-haiku-120m`) was cancelled 16 s in by an external stop signal, before the agent started. |
| 13:03-13:30 | Rerun `node17-haiku-120m-r2`: **reward 0.0**, but not the agent's fault. It stopped after 26 min believing it was done; the verifier's build failed on `environment.etc."systemd/system/user-.slice.d/…"` (read-only store link). Locally the agent's 15 builds passed because the solving image built **as root without build users**, which ignores the read-only permission; the verifier's builder uses unprivileged build users. |
| ~13:20-13:50 | Real-machine exploration (read-only, via the user's temporary SSH control sockets): nuc-fileserver (Debian 13 Samba/Btrfs) inventoried; mi60 (Ubuntu 26.04 GPU inference box: kernel params, modprobe, lockup sysctls, logind idle suspend, sleep-hook units, power caps, uv ROCm env) drafted as **node37**. Secrets recorded by type only; agent-facing names neutral. |
| ~14:00 | Session restart; the earlier session kept running (later moved to sibling projects). **Build-parity fix:** solving image now builds with `nixbld` build users (`author/images/task.Dockerfile`; a real sandbox needs user namespaces, which the container lacks). Proven by rebuilding the r2 submission locally: now fails with the same "Permission denied" the verifier gave. `check-tools` gained a build-user probe (uid 30001). |
| 14:00-14:30 | node23 and node31 validated by the drafting subagent (reference 25/25 each, oracle 1.0, nop 0.0; node23 dropped four version-gap setting checks for behavior checks). node37's first prepare failed on a GID clash (i2c 113 taken in jammy) → GID unpinned. Cleanup: easy task to `old/`, mail (node29) to `backup/`, SSH sockets closed and removed, stale `.cache` deleted. `harbor lint` clean on all four. |
| 14:32-14:48 | **Haiku 60 min on node23: 0.84** (13 min, $0.17; missed recursor API, hidden version string, socket tuning) and **node31: 0.92** (11 min, $0.60; missed operator `amtool`, textfile-timer complexifier). Both agents stopped early believing they were done. |
| 14:50-15:20 | node37 controls: reference 14/16 and oracle 13/16 exposed four verifier faults (systemd `*USec` names, `systemctl show` property order, NixOS `linked` vs Ubuntu `static`, a fail-open decoy check) → fixed; **reference 16/16, oracle 1.0, nop 0/16**. |
| 14:54-15:25 | Model routing incident: Sonnet was first launched on the Haiku-only proxy (403 "this key may only call claude-haiku-5-5", 0 tokens), then via OpenRouter with the proxy base URL still winning (stopped in setup, no request). Correct form: `-m openrouter/anthropic/claude-sonnet-5.5 --base-url https://openrouter.ai/api`; the agent authenticated with the OpenRouter token only (`apiKeySource: none`). **Sonnet 5.5 on node31: 0.96** (recipe 21/22, CX 3/3; 13.5 min, 46 calls, $0.82) — missed the same `amtool_operator` check as Haiku. |
| 15:2x | Haiku 60 min on node37 and Haiku 120 min on node17 (first run with build parity, via `tools/pilot`) running. |
| 15:2x-15:40 | **Haiku 60 min on node37 (real mi60): 0.875** (recipe 11/13, CX 3/3; 16 min, 77 calls, 12 builds, 7 boots, $0.65). Missed the `algif_aead` modprobe install rule and the i2c udev rule; got kernel params, lockup sysctls, sleep policy, the sleep-cleanup unit, power caps and the uv env. |
| 15:2x-16:10 | **Haiku 120 min on node17** (first run with build parity, `tools/pilot`): **0.85** (recipe 29/31, CX 0/3; stopped at 47 of 120 min, 81 calls, 8 builds, 4 boots, $0.55). Build passed in the verifier this time. Fixed the 60-min run's sudo `/bin/cat` and CGI-uid misses, still missed slice limits and `REVOKE CONNECT`, and **fell for the sudo decoy** (granted cobalt the inert `systemctl restart apache2` rule) and missed both other complexifiers. |
| ~15:35 | **Ablations on node31** (Haiku, author-side copies in `ablations/`, one prompt sentence each; same images/verifier): #1 process nudge, 60 min, and #3 downscope to applications + operator tools, 30 min. Results in the Ablations table below. |

| ~16:20 | **Prompt change, all four tasks:** the graded paragraph now adds "stock utilities nobody here is likely to need" (don't matter) and "the commands people are likely to use for this machine's job" (do), after ablation #5 moved `amtool_operator`. Earlier baselines used the old wording. `difficulty_evidence` dropped from task.toml; per-run numbers now in [results.md](results.md). Sonnet 5.5 (OpenRouter) on node17, 30 min, started on the new prompt. |

| ~16:30 | `check-tools` build-user probe flagged **node23 and node31 solving images still building as root** (last rebuilt before the 14:00 parity fix). Rebuilt; all four now build as uid 30001. Their 14:32 Haiku trials ran without parity; their verifier builds passed, so scores stand. |

| ~16:40 | **Check-proposal review** (Sonnet, read-only → `author/check-proposals.md`): 12 proposals, 3 per task. **Static check against Haiku's latest submissions: 7 of 9 accepted proposals would already pass** (ACLs, passwords, timeouts, error-log sudo, even node37's `%sudo` rule), so they add coverage, not difficulty; only `hosts_file` (NixOS `127.0.0.2`) clearly fails and was judged unimportant. Kept: node37 **`operator_sudo`** (operator full sudo via the Ubuntu-default `%sudo` rule; service user denied) — implemented, oracle given `%sudo ALL=(ALL:ALL) ALL`. Second Sonnet review started: recipe-vs-Ubuntu-default gotchas and 1-2 new complexifiers per task (`author/gotchas.md`). |
| 16:2x-16:35 | **Sonnet 5.5 (OpenRouter) on node17, 30 min, new prompt: 0.88** (recipe 27/31, **CX 3/3**; 8.3 min, 33 calls, $0.85, never booted its candidate). Missed slice limits, PostGIS, CGI and WSGI identity. Haiku on node17: 0.82 / 0.85 with CX 1/3 and 0/3. |

| ~16:50 | **Verifier bug found by review:** node37 `module_policy` required the literal `/bin/false` (NixOS has none); Haiku had `${pkgs.coreutils}/bin/false`, which disables the module identically. Fixed; node37 re-validated (ref 17/17, oracle 1.0, nop 0/17 with `operator_sudo`). **Re-grade of Haiku's node37 attempt: 0.875 → 0.94** (only `udev_i2c` missed). User approved: full verifier audit for such assumptions, node31 `operator_tools` (`promtool`, `htpasswd`), and four complexifiers (db-role-limits, nsd-secondary, icmp-probe, etc-environment) — running in one Sonnet subagent with controls per task. |

| 16:50-17:45 | **Verifier audit + new checks + complexifiers** (one Sonnet subagent, `author/verifier-fixes.md`): fixed checks that tested implementation (node37 `udev_i2c` exact line/glob, node23/node31 `listeners` overwriting same-port sockets, node31 `textfile_timer` unit name) and one fail-open (node23 `sudo_policy` denial via `/usr/bin/id`, absent on NixOS). Added node31 **`operator_tools`** (`promtool`, `htpasswd`; listed by `apt-mark showmanual` + `dpkg -S`; the oracle itself first lacked `promtool` → `prometheus.cli`). Added four complexifiers: node17 **CX-db-role-limits** (limits stored in the DB catalogs), node23 **CX-nsd-secondary** (AXFR allowed only from the secondary), node31 **CX-icmp-probe** (ping-socket ICMP on Ubuntu; NixOS module grants CAP_NET_RAW), node37 **CX-etc-environment** (pam_env-only variables). All four references reprovisioned; controls: node17 35/35 · 1.0 · 0, node23 26/26 · 1.0 · 0, node31 27/27 · 1.0 · 0, node37 18/18 · 1.0 · 0. Earlier model scores were on fewer checks. |
| ~17:20 | **node41-reconstruction-easy drafted** from the file-server inventory: Samba shares (forced user/group, setgid, veto, nested share) + an emulated USB Btrfs RAID1 (two `usb-storage` disks shipped as fixtures, automount by label); 16 checks, 30 min, no complexifiers. Purpose: show agents can solve an easier version. |

| 17:50-18:30 | **node41 (easy control) validated** after two fix rounds (ref 16/16, oracle 1.0, nop 0/16); fix exposed a harness trap: the qemu-vm module replaces `fileSystems`, so the prompt now states that extra mounts go under `virtualisation.fileSystems`. **Haiku 30 min: 0.94** (15/16) in 5 min, 27 calls, $0.08, including the USB Btrfs RAID automount; missed only the powertop unit. Supports the headroom argument: the easy version is nearly solved, the hard ones are not. |

| 18:20-19:00 | **Publishable packaging** (plan `author/packaging-plan.md`, reviewed by a second model): backup tarball + `:pre-spike` tags first. **node41 spike passed**: no external network, per-trial sandboxed builder sidecar with fixture keys (`author/fixtures/builder/`), verifier image without the real builder key; oracle 1.0, nop 0.0, build log shows `on 'ssh-ng://buildclient@builder'`. Secret scan of all three images clean. Generalised as `author/publish.sh` / `mise run publish <id>` (per-task builder image on the task's own inputs image, so layers are shared); applied to all five tasks; images pushed to `ghcr.io/kinchahoy/…`. |

| ~19:00 | **Decision: verifier builder sidecar keeps internet** (parity with the agent's online environment; fixed-output downloads are hash-pinned and the builder holds nothing secret). Rationale in `packaging-plan.md` → Implementation status. |

## Ablations

Question: are the misses capability or attention? Baseline on node31 without nudge: Haiku 0.92 (missed `amtool_operator`, `textfile_timer`), Sonnet 0.96 (missed `amtool_operator`).

| Variant | Added to prompt | Budget | Job | Score | `amtool_operator` | `textfile_timer` | Time / cost |
|---|---|---|---|---|---|---|---|
| #1 process nudge | "Before you finish, compare the reference and your replica systematically, and fix every difference you find." | 60 min | `node31-haiku-nudge-60m` | **0.96** (recipe 21/22, CX 3/3) | still missed | **fixed** | 12.7 min, 69 calls, $0.70 |
| #3 downscope | "Focus on the applications and the tools their operators use; base-OS tuning is out of scope." | 30 min | `node31-haiku-downscope-30m` | **0.96** (recipe 21/22, CX 3/3) | still missed, despite naming operators' tools | fixed | 18.5 min, 78 calls, $0.65 |
| #5 commands contract | Graded paragraph: OS-only list adds "stock utilities nobody here is likely to need"; "do" list adds "the commands people are likely to use for this machine's job" | 60 min | `node31-haiku-commands-60m` | **0.96** (recipe 21/22, CX 3/3) | **half-fixed**: `amtool` now on PATH (added the package), but `/etc/amtool/config.yml` missing → "--alertmanager.url not provided" | fixed | 12.9 min, 81 calls, $0.80 |

Finding: `amtool_operator` survives every variant and Sonnet. Trajectories show the agents did inspect `apt-mark showmanual`, profile.d/dotfiles and the operators' shells; one copied `/etc/amtool/config.yml` and checked a hand-picked list of ~30 commands on PATH that omitted `amtool`. The gap is a Nix mental model, not attention: on Ubuntu the package puts the CLI on every user's PATH, while `services.prometheus.alertmanager` only runs the daemon. Only a reference-vs-replica diff of the commands available to each user catches it.

Not run: #2 perspective nudge (users' day-to-day workflows), #4 targeted hint (names operator CLI tools; too close to the answer). #3 changes the task (OS-level checks still graded), so read its OS-level failures as the scope sentence working.

## Findings so far (2026-11-03, n=1 per cell)

| Task | Haiku 60 min | Haiku 120 min | Haiku + nudge | Sonnet 60 min |
|---|---|---|---|---|
| node17 (web host) | 0.82 (56 min) | 0.85 (47 min) | — | — |
| node23 (resolver) | 0.84 (13 min) | — | — | — |
| node31 (monitoring) | 0.92 (11 min) | — | 0.96 process nudge; 0.96 downscope | 0.96 (13.5 min) |
| node37 (mi60) | 0.875 (16 min) | — | — | — |

- **More time doesn't help.** On node17 the 120-min agent stopped at 47 min believing it was done; +0.03, and it lost the one complexifier the 60-min run had passed (fell for the sudo decoy). Every agent today stopped well before its budget.
- **Prompt nudges fix attention misses, not the hard item.** Only the commands-contract wording (#5) moved `amtool_operator`: the agent then installed the CLI but still missed its client config, so the check failed one step later. On node31 a generic "compare systematically" nudge fixed the timer complexifier (Haiku 0.92 → 0.96), but no variant fixed `amtool_operator` (a Nix mental-model gap: the service module doesn't put the package's CLI on PATH). Nudges have only been tried on node31, the easiest task; untested on node17/node37.
- **Sonnet is ahead, modestly so far.** On node31 Sonnet 0.96 vs Haiku 0.92 (one more check), with fewer calls (46 vs 75) and half the peak context, at $0.82 vs $0.60. A nudged Haiku matched it. The real test is a harder task (node17), where Haiku plateaus at 0.82-0.85.
- **What the tasks measure:** methodical verification against the reference (agents stop early and skip less visible items: limits, isolation, decoys, timers) plus a few Ubuntu-to-Nix model gaps. Not time, and not Nix syntax.

Per-item view of every miss (why it's fair, failure mode, minimal discovery step, Haiku/Sonnet Y/N): [missed-items.md](missed-items.md).

## Lessons and challenges

- **Zeros are not evidence.** Every reward below 1.0 before 09:46 was a harness, VM or environment fault, and it took six runs to separate them from task failures. Run the oracle and nop controls first and believe nothing else.
- **The contract got smaller.** It went from a flake plus published surface list plus README to one plain prompt, a 60 min budget and a graded-scope sentence. Hidden checks are compared against the reference and not described to the agent. Fairness is checked by a separate read-only reviewer (it found the `/usr/bin/python3` CGI convention was undiscoverable).
- **Verifier honesty is most of the work.** Two checks failed open under nop. One hard-coded VM name crashed the verifier. A reboot check was dropped for settings-based `persistent_storage`. Config is read through the running daemons rather than files. Reference-exact values, not guessed ones, are the bar.
- **Difficulty must come from fidelity, not cost.** Complexifiers are separate, origin-tagged checks. The first Haiku run (0.82) fails on real fidelity gaps, so the task is a `hard-candidate`, with no difficulty claim until longer or stronger runs exist.
- **Infrastructure cost dominates iteration.** A ~35 min input-image prepare, a ~3-4 min VM per trial, and a shared builder holding the Nix store and the only builder key. Renames in a restructure silently broke scripts twice.
- **Local and verifier builds must behave the same.** A green local build that the verifier rejects is the most unfair failure possible; root builds hid read-only-store errors until 14:00.
- **The easy-looking tasks finish early, not perfectly.** Agents on node23/node31 stopped after ~12 min with 0.84-0.96; both Haiku and Sonnet missed operator tooling (`amtool` for the operator user). Difficulty lives in operator glue and hidden timers, not in the services' YAML.
- **Model routing is part of the experiment.** Only Haiku 5.5 may use the default proxy; everything else goes through OpenRouter with an explicit `--base-url`, verified from Harbor's "Inference credentials" line before the agent starts.
- **Sidetracks.** The endpoint is a proxy base URL (`take-home-automation.vercel.app`), not openrouter.ai. Security-classifier false positives interrupted subagent Harbor runs. `vision.md` (two-archive plan) was deleted as stale. The easy archive task remains with its own older flake contract.
