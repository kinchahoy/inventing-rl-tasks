# Making a new box mechanically (Haiku-level work, no frontier model)

Extends `author/tasks/README.md` ("Adding a task") with who does each step. **Script** = deterministic tooling that exists in this repo; **Haiku** = a cheap model doing bounded, checkable work; **Human** = judgement we still need.

| # | Step | Who | Tool / command | Done when |
|---|---|---|---|---|
| 1 | Pick a host role from a corpus (Puppet role, Chef run-list, Ansible play) | Haiku | Reads the role and lists its packages, services and files | Inventory row: packages, services, ports, users |
| 2 | Filter: offline, VM-observable, 6-10 subsystems, no real hardware | Haiku + rule | Checklist (`pipeline-map.md`) | pass / drop |
| 3 | Port the role to a CINC/Chef recipe for Ubuntu 22.04 | Haiku | Templated cookbook; iterate until `provision` succeeds | `mise run prepare <id>` builds a frozen qcow2 |
| 4 | Neutral naming (nodeNN, neutral users/domains) | Script | rename map | No upstream names in agent-facing files |
| 5 | Probe the reference: dump the facts each daemon reports | Script | per-daemon probe list (`author/methods.md` table: `sshd -T`, `php-fpm -tt`, `systemctl show`, `ss -ltnp`, `psql`, `sudo -l -U`) | facts.json |
| 6 | Instantiate checks from templates with the exact reference values | Haiku | check templates per daemon; values from facts.json | `verify.py --reference` passes every check |
| 7 | Write the oracle NixOS module | Haiku (+ retries) | the build/boot loop (`check-replica`, `build-replica`) | oracle 1.0 |
| 8 | Controls | Script | `mise run check-reference`, `harbor run -a oracle`, `-a nop` | ref all-pass, oracle 1.0, nop 0.0 |
| 9 | Fixed-checklist verifier audit (literal paths, unit/process names, output formats, fixed globs, fail-open denials, readiness) | Haiku/Sonnet, read-only | prompt from `author/verifier-fixes-all-attacks.md` takeaways | no findings, or fixes + re-run of step 8 |
| 10 | Calibrate: Haiku k=3 | Script | `author/final-runs.sh <id>` | scores recorded in the ledger |
| 11 | If solved: add complexifiers from the library, then back to step 6 | Haiku | `complexify.rb` + `complexify.nix` + check, origin-tagged | Haiku k=3 = 0, and the new items are fair |
| 12 | Trajectory + fairness review of every miss | Haiku/Sonnet, read-only | `author/missed-items.md` columns | each miss: fair, with a minimal discovery step |
| 13 | Sign-off | **Human** | review the missed-items rows + controls | ship |
| 14 | Publish | Script | `mise run publish <id> --push` | images pinned by digest |

**What still needs a human:** step 13 (is each miss fair?), new check *templates* (not new instances), and new complexifier *kinds*. Everything per-task is script or Haiku work.

**Cost per task (measured):**
- first prepare ~35 min;
- controls ~15 min;
- Haiku k=3 ~45 min and ~$2-3;
- audits a few dollars.

The dominant cost is KVM compute, not model spend.
