# How we found the boxes, complexified them, and how to find many more

## The funnel (what we actually did)

```mermaid
flowchart TD
    A["Sources of real server roles<br/>public IaC: OSM Chef, Wikimedia Puppet<br/>owner's own machines (neutralised)"] --> B
    B{"Filter: is it a good box?<br/>one host role · provisionable offline on Ubuntu 22.04<br/>behaviour observable from inside the VM<br/>6-10 interacting subsystems<br/>Ubuntu defaults that NixOS expresses differently"}
    B -- "no: needs real hardware / network / external services" --> X1["dropped<br/>(e.g. mail host drafted, not built)"]
    B -- yes --> C["Freeze a reference VM<br/>recipe → CINC/Chef on Ubuntu 22.04 → frozen qcow2"]
    C --> D["Oracle module (NixOS) + checks<br/>exact values taken from the reference"]
    D --> E{"Controls<br/>reference all-pass · oracle 1.0 · nop 0.0"}
    E -- fail --> D
    E -- pass --> F{"Calibrate on Haiku<br/>(1 trial, then k=3)"}
    F -- "solved / too easy" --> G["Complexify<br/>add traps where copying the obvious file is wrong:<br/>precedence · inert decoys · settings outside the tree<br/>interacting limits · Ubuntu-natural, odd in Nix"]
    G --> D
    F -- "fails, and every miss is fair<br/>(trajectory + fairness review)" --> H["Keep: core pack<br/>node17 · node31 · node37 (pass@3 = 0)"]
    F -- "solved even after complexifying" --> I["Keep as bonus<br/>node23 solved · node41 easy control"]
```

## What came out

| Box | Source | Subsystems | Checks (recipe + complexifier) | Haiku final k=3 | Where |
|---|---|---|---|---|---|
| node17 | OSM Chef dev/tenant host | web, PHP-FPM, CGI/WSGI, Postgres+PostGIS, MariaDB, cache, sudo, limits | 31 + 4 | 0/3 | core |
| node31 | Wikimedia Puppet monitoring role | Prometheus, Alertmanager, exporters, nginx, operator tools | 23 + 4 | 0/3 | core |
| node37 | owner's GPU box (neutralised) | kernel cmdline, sysctl, modprobe, udev, sleep, timers, pam_env | 14 + 4 | 0/3 | core |
| node23 | Wikimedia Puppet DNS role | dnsdist, pdns-recursor, nsd, DoT, sudo | 22 + 4 | 1/3 solved | bonus |
| node41 | owner's home file server | Samba, Btrfs RAID1 on USB disks, automount | 16 | 0.94 (k=1) | bonus |

**The pattern:** boxes whose state lives in a few config files (node23, node41) get solved. Boxes with state spread across mechanisms (limits, DB catalogs, per-tenant identity, kernel/udev, operator PATH) don't.

## How we'd find a lot more (the story for the scale plan)

```mermaid
flowchart LR
    S1["Public IaC corpora<br/>Wikimedia operations/puppet roles<br/>OSM chef · Fedora infra Ansible<br/>Ansible Galaxy / Chef Supermarket"] --> P
    S2["Docker official images<br/>(single-service seeds)"] --> P
    S3["Consenting real machines<br/>(neutralised, small volume)"] --> P
    P["Role inventory<br/>one row per host role"] --> Q{"Mechanical filter<br/>(script + Haiku)"}
    Q --> R["Reference builds<br/>(pipeline above)"]
    R --> L["Difficulty ladder per role<br/>base → +k complexifiers → multi-role hosts"]
    L --> K["Calibrated pack<br/>keep the rung just past where Haiku fails"]
    W["Debian popcon<br/>weights which services to cover"] -.-> P
```

- **Where the volume comes from:** one public Puppet/Chef/Ansible repo holds hundreds of host roles. Each role gives several tasks: a different complexifier mix, source distro, or nixpkgs pin. Rough sizing (to verify): ~200 roles × 5 variants ≈ 1,000 tasks.
- **Why it scales:** the recipe *is* the ground truth. The reference VM is built from it, so the spec never has to be written by hand. Checks are templated per daemon and filled from the running reference.
- **Where difficulty comes from:** not from making boxes bigger, but from the ladder. Add complexifiers until Haiku k=3 falls to 0, then keep that rung. The complexifier library is reusable across roles (7 implemented, 9 drafted; `author/complexify.md`).
- **What doesn't scale (be honest):**
  - the per-trial cost (KVM, a 4-8 min verifier build, large images);
  - the human fairness sign-off on new check templates;
  - roles that need real hardware or external services, which get filtered out.
