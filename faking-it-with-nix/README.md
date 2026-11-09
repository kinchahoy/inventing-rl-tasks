# Linux server reconstruction with Nix

Hard Harbor tasks: an agent inspects a running Ubuntu reference VM as root and rebuilds it as a
NixOS 26.05 drop-in replacement (`replica.nix` plus local files). Agent-facing names are neutral;
real sources live author-side in each recipe's `provenance.md`.

| Task | Derived from (author-side) | State |
|---|---|---|
| `node17-reconstruction-hard` | OSM Chef faffy/dev: multi-tenant web/PHP/PostgreSQL/MariaDB host | Validated (35 checks: ref 35/35, oracle 1.0, nop 0); Haiku 0.82 / 0.85 (120 min), Sonnet 0.88 (30 min) |
| `node23-reconstruction-hard` | Wikimedia puppet: DNS resolver stack | Validated (26 checks: ref 26/26, oracle 1.0, nop 0); Haiku 0.84 |
| `node31-reconstruction-hard` | Wikimedia puppet: monitoring host | Validated (27 checks: ref 27/27, oracle 1.0, nop 0); Haiku 0.92, Sonnet 0.96 |
| `node37-reconstruction-hard` | A real GPU inference box (kernel params, sleep, custom units) | Validated (18 checks: ref 18/18, oracle 1.0, nop 0); Haiku 0.94 (re-grade) |
| `node41-reconstruction-easy` | A real home file server: Samba shares + USB Btrfs RAID1 (easy control) | Drafted; controls in progress |

Model-trial results: [author/results.md](author/results.md). What agents missed and how they could have found it: [author/missed-items.md](author/missed-items.md). `ablations/` holds prompt-variant copies for capability-vs-attention tests (see `author/timeline.md`). `backup/` holds a drafted mail-host task (node29); `old/` holds the earlier easy archive task with
its original flake contract. Neither is in `TASKS`.

The Node17 agent sees neutral host/user names. Its upstream mapping and scoped
changes are recorded in [author provenance](author/tasks/node17-reconstruction-hard/provenance.md), outside
the solving image. The existing Ubuntu reference is frozen and reused.

## Node17 contract

The solver submits `/app/submission/replica.nix`, a normal NixOS module, and any
local files it imports. No submission flake, lock file or dependency resolution.
The harness owns the exact nixpkgs **26.05** revision recorded in
`/opt/contract/flake.lock`, imports the downloaded source locally, and provides
Nix **2.35.4**, VM plumbing, SSH, and public lab TLS credentials. The module gets
normal `pkgs`, `lib`, `config`, and `modulesPath` arguments.

Inside the solving workspace:

```sh
/opt/runtime/reference start
/opt/runtime/guest
/opt/contract/check-replica                 # syntax + configuration evaluation
/opt/contract/check-replica --syntax-only   # parsing only
/opt/contract/build-replica                 # actual VM build
```

Checking and building use the same `build.nix` entry point and pinned source.
The checker disables import-from-derivation: it does not build or boot anything.
It detects Nix syntax errors, missing options, type conflicts and failed NixOS
assertions. It cannot validate service configuration strings or runtime behavior.
The agent instructions explicitly recommend running it after edits.

The reference has per-user PHP-FPM, CGI and WSGI execution, Apache virtual hosts,
PostgreSQL/PostGIS, MariaDB, memcached, private directories, local host aliases,
restricted log sudo, and systemd limits, plus three deliberate complexifiers
(`CX-*`). The agent gets one plain prompt, `node17-reconstruction-hard/instruction.md`
(60 minutes, drop-in replacement, no surfaces list); `/opt/contract` holds only
tools, the pin, the harness module and a skeleton.

## Verification

- [author/methods.md](author/methods.md): how checks are chosen (inside and deterministic first, ask the daemon, exact reference values, controls).
- [verification.md](author/tasks/node17-reconstruction-hard/verification.md): Node17's 34 checks, coverage and cost.
- [author/complexify.md](author/complexify.md): complexifier catalogue, status and how origin is marked (`complexify.rb`, `complexify.nix`, `COMPLEXIFIER_CHECKS`).

## Build layout

Tasks share one image graph (`docker-bake.hcl`) and one builder; each task adds
a recipe under `author/tasks/<id>/`. The recipe interface and the steps for
adding a task are in [author/tasks/README.md](author/tasks/README.md).

```
replica-base ─ replica-toolchain ─┬─ <id>-inputs ─ <id> ─ <id>-verifier
 (qemu, tools)   (Nix 2.35.4)     │   pin + prewarm   + reference, contract   + tests, builder key
                                  └─ replica-builder  (volume replica-nix-store-v1)
```

Generated state lives only in `.cache/tasks/<id>/` (reference disk, fixture
credentials, scratch) and `.cache/builder/` (builder SSH keys). Harbor task
directories hold no build inputs: `[environment].docker_image` and the verifier
image are prebuilt, so trials upload no context.

## Prepare and validate

```sh
mise run prepare node17-reconstruction-hard        # idempotent; rerun after any edit
mise run check-builder node17-reconstruction-hard  # sandboxing, subdirectory closures, cache reuse
mise run check-tools node17-reconstruction-hard    # syntax/option/type/IFD rejection regressions
mise run check-oracle node17-reconstruction-hard   # evaluate oracle without building
mise run build-oracle node17-reconstruction-hard   # build oracle without booting/probing
mise run check-reference node17-reconstruction-hard  # frozen reference passes every check (author time)
harbor run -p node17-reconstruction-hard -a oracle -y   # expect 1.0
harbor run -p node17-reconstruction-hard -a nop -y      # expect 0.0
```

Model trial (key and base URL come from the workspace `.env`):

```sh
harbor run -p node17-reconstruction-hard -a claude-code -m anthropic/claude-haiku-5-5 \
  --ak reasoning_effort=high --env-file ../.env -k 1 -y
```

Different time budget without editing the task (keeps the prompt's exact "You have 60 minutes."
sentence working): `../tools/pilot node17-reconstruction-hard 120` — same model config by default.

Summarize horizon and cost (LLM calls incl. subagents, tool calls by tool, check/build/boot
loop counts, time to first submission write, peak context, tokens, cost, score by origin):

```sh
mise run trial-stats jobs/<job>
```

`prepare` reprovisions the reference only when the recipe's guest inputs change,
rebuilds only the image layers whose sources changed (tests, contract, recipe
public files), and stops the builder only if its store lacks the task's prewarm
closures. Do not prepare while that import may be needed during active builds.

The official, checksum-checked Nix 2.35.4 release and the shared nixpkgs 26.05
lock (`author/pins/flake.lock`) are fixed; nothing resolves a new revision.
Toolchain release/hash information is in `/opt/nix-release.txt`.

## Publishing and submission

- `mise run publish <task> [--push]` (`author/publish.sh`): publishable layout — images on Docker Hub (`REPLICA_REGISTRY=beginagain`, pinned by digest), a per-trial sandboxed builder sidecar with fixture keys (`author/fixtures/builder/`), no external network, the gateway `[environment.env]` block. Design and review: `author/packaging-plan.md`.
- `mise run check-reference <task>` runs the reference control inside the verifier image the task pins.
- `author/final-runs.sh <task>`: oracle, nop and the brief's `-k 3` Haiku run into `runs/jobs/`.
- `author/make-pack.sh [--zip]`: assembles `runs/pack/` (samples, jobs, archive incl. a rebuild tree without `author/real/`, report placeholder).
- Grader prerequisites: Linux x86-64, `/dev/kvm`, and Docker allowing the builder's `SYS_ADMIN` + unconfined seccomp/apparmor (needed for the Nix sandbox).

## Persistent builder and isolation

`replica-builder` (shared by all tasks) owns named volume `replica-nix-store-v1`. It runs a multi-user
Nix daemon with `sandbox=true`, `sandbox-fallback=false`, dedicated build users,
and signature checks. An untrusted SSH account is forced into the Nix protocol.
Only the private verifier image has its client key. Solving containers get
neither a shared writable store nor a Docker socket.

The verifier evaluates locally with filesystem restrictions and no URI access,
then sends builds to the persistent builder with local fallback disabled. Each
verification still boots a fresh writable guest disk and reruns all checks.
Caches never reuse scores or mutated VM state. Build logs record the submitted
source hash and Nix output paths.

Store initialization imports only prewarmed runtime closures from our own trusted
image. That local import permits unsigned generated outputs; the running daemon
and network-download signature policy remain enabled. Preparation stops the
daemon during that import.

To independently verify an existing module directory:

```sh
mkdir -p verifier-logs
docker run --rm --device /dev/kvm --network replica-build \
  -v "$PWD/your-submission:/app/submission:ro" \
  -v "$PWD/verifier-logs:/logs/verifier" \
  node17-reconstruction-hard-verifier:v1 bash /tests/test.sh
```

The private image contains its verifier tests, as required by Harbor's explicit
verifier-image mode. It receives `/dev/kvm` and the builder network from
`node17-reconstruction-hard/tests/docker-compose.yaml`. Neither the tests nor
builder credentials are included in the solving image.

