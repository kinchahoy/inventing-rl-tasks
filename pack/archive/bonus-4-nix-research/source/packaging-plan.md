# Packaging plan: make the replica tasks runnable by graders

Status: proposed, not implemented (2026-11-03). Reviewer: please check the risks and the acceptance tests.

## Goal

A grader unzips the submission and runs, with no access to our machine:

```
harbor run -p samples/<task> -a oracle        # must score 1
harbor run -p samples/<task> -a nop           # must score 0
harbor run -p samples/<task> -a claude-code -m claude-haiku-5-5 --ak reasoning_effort=high -k 3
harbor check samples/<task> -m claude-haiku-5-5
```

The brief requires Harbor-format tasks, the `[environment.env]` gateway block in every `task.toml`, and verifiers that can't be gamed.

## Current state (why it fails today)

- `task.toml` names **local** images (`<id>:v1`, `<id>-verifier:v1`) built by our `docker-bake.hcl`; they exist only here.
- The verifier sends the agent's Nix build to a **persistent shared builder container** (`replica-builder`) over SSH, on an **external** Docker network `replica-build` declared in `tests/docker-compose.yaml`. A grader has neither, so compose fails before the verifier runs.
- The verifier image contains the builder's SSH client key.
- No `[environment.env]` block in any `task.toml`; we passed `--env-file` instead.

## Target design

Per task (`node17/23/31/37-reconstruction-hard`, `node41-reconstruction-easy`):

1. **Task image** `ghcr.io/kinchahoy/<id>@sha256:…` (public). Same contents as today's `<id>:v1`: Ubuntu base, QEMU, pinned Nix 2.35.4, pinned nixpkgs, prewarmed closures, frozen reference disk, contract tools, runtime scripts, fixture keys (lab SSH key, test TLS CA; they must match the frozen disk and are not secrets). `task.toml [environment] docker_image` pins it by digest.
2. **Verifier**: keep `environment_mode = "separate"` with an explicit verifier image `ghcr.io/kinchahoy/<id>-verifier@sha256:…` = task image + `tests/` (Harbor requires bundled tests for explicit verifier images) + a **fixture** builder client key (not a secret; see 3). Hidden tests stay out of the agent's image.
3. **Sandboxed builder as a sidecar**: one image `ghcr.io/kinchahoy/replica-builder@sha256:…` with every task's prewarmed closures **baked into its store** (today they are imported into a volume by `prepare`). Same daemon policy as today: `sandbox = true`, `sandbox-fallback = false`, build users, signature checks, forced-command SSH account. `tests/docker-compose.yaml` adds a `builder` service with that image, on a compose-internal network; the external `replica-build` network is removed. Each trial gets a fresh builder, so nothing persists between trials. The fixture client/host key pair is baked into both images; the builder is reachable only inside that trial's compose project.
4. **`task.toml`** gets the gateway block, copied from the brief's example task (base URL only, no key):
   ```
   [environment.env]
   ANTHROPIC_BASE_URL = "https://take-home-automation.vercel.app"
   ANTHROPIC_API_BASE = "https://take-home-automation.vercel.app"
   ```
   The API key comes from the grader's environment through Harbor's credential mapping; nothing secret is baked into an image.
5. **Recipes ship for transparency**: each task's provisioning recipe (`author/tasks/<id>/`) and `reference-manifest.json` (disk checksum) go in the submission (in `archive/` or next to the samples), so the frozen reference can be audited and rebuilt with `mise run prepare <id>`. The reference is **not** rebuilt at grade time: a rebuild pulls newer Ubuntu packages and could change graded values, and Docker builds have no KVM.

## Steps

1. **Spike on node41** (cheapest): sidecar builder service in `tests/docker-compose.yaml`; confirm Harbor starts it for the separate verifier and that the verifier can reach it by service name. Stop and redesign if Harbor doesn't support it.
2. Bake the prewarmed closures into the builder image (`author/images/builder.Dockerfile`), with the fixture keys; build-time check that `sandbox = true` is in effect.
3. Verifier images: replace the real client key with the fixture key; point `REPLICA_REMOTE_BUILDER` at `builder` (service name).
4. Add the `[environment.env]` block to all five `task.toml`.
5. Push task, verifier and builder images to GHCR; make the packages public; pin digests in `task.toml` and `tests/docker-compose.yaml`.
6. Acceptance tests (below) on every task.
7. `harbor check` on every task; fix findings.
8. Only then: the final runs (`-k 3` model, oracle, nop) into a clean `jobs/`.

## Acceptance tests ("won't be problematic")

| # | Test | Pass condition |
|---|---|---|
| A1 | **Clean-machine run**: a Docker context with none of our local images, volumes, networks or the `replica-builder` container (another host or a fresh VM). Copy `samples/<task>`, run oracle and nop | Oracle 1.0, nop 0.0 for all five; images pulled from GHCR by digest |
| A2 | Same on this machine after `docker rmi` of the local `:v1` tags and with `replica-builder` stopped | Same results; proves no hidden dependency on local state |
| A3 | `mise run check-reference <id>` against the pushed image | All checks pass |
| A4 | Sandbox still enforced: a crafted submission whose derivation tries network access, reads `/tests`, or writes outside `$out` | Build fails in the sidecar; reward 0 |
| A5 | No secrets in published images: scan each image's filesystem and history for the gateway key, `.env` contents, real-server details (`author/real/`), and the old builder key (`gitleaks`/`trufflehog` plus grep) | No hits except the documented fixture keys |
| A6 | Agent image does not contain `tests/` or the builder key | Not present |
| A7 | `harbor lint` and `harbor check -m claude-haiku-5-5` | Clean, or findings explained |
| A8 | One Haiku trial per task through the new packaging, compared with the earlier local results | Same order of reward; no infrastructure exceptions |

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Harbor doesn't start extra compose services for a separate verifier, or doesn't apply `tests/docker-compose.yaml` | Step 1 spike on node41 before anything else; fallback: run the Nix daemon inside the verifier container with `sandbox = true` (needs user namespaces; test it) or accept unsandboxed local builds and say so in the report |
| Builder image is large (all closures baked, likely 10-20 GB) | Share layers across tasks; pull is one-time per grader machine; document the expected download |
| GHCR rate limits or private-by-default packages | Set packages public; test the anonymous pull (A1) |
| Fresh builder per trial is slower than the persistent one | Closures are baked, so only the candidate's own derivations build; measure in A1 and raise verifier timeout if needed |
| Digest drift (image rebuilt after pinning) | Pin by digest only; rebuild means re-pin and re-run A1-A3 |
| Fixture keys mistaken for secrets by a scanner or reviewer | Document them in each task's README/report as lab fixtures matching the frozen disk |
| Earlier results were produced with the local packaging | Final submitted runs are all made after the switch (step 8); earlier runs stay as development evidence in the report |

## Rollback

All changes are to `task.toml`, `tests/docker-compose.yaml`, the image Dockerfiles and the verifier's builder address. Keep the current local-image setup on a git branch; switching back is a revert of those files.

## Open questions for the reviewer

1. Is a sidecar builder per verification acceptable, or should the verifier build in-container (simpler, no sandbox)?
2. Should the recipes live in `samples/<task>/` (self-contained) or in `archive/` (keeps samples minimal)?
3. Is ~20-35 GB of public GHCR images reasonable for graders, or should we shrink the closures first?

## Implementation status (added after review)

- Review findings adopted: agent-side external network removed too (`environment/docker-compose.yaml`); no unsandboxed fallback; A3 must target the published digest (todo); full rebuild tree goes to `archive/` (todo); prerequisites (Linux x86-64, usable `/dev/kvm`, a container with `SYS_ADMIN` + unconfined seccomp/apparmor for the builder) documented in the report (todo).
- **Decided (2026-11-03): builder stays online.** Nix sandboxes ordinary builds without network; only fixed-output derivations (hash-pinned downloads) and binary-cache substitution reach the internet. The hash pins the content, the builder holds no tests or keys, so the residual risk is exfiltration of nothing secret plus grading that depends on internet access. Going offline (`internal: true`) would fail legitimate submissions that use packages we did not prewarm, which the agent's online environment builds fine — an unfair mismatch. Offline would only be consistent if the agent environment were offline too (stricter task; not done).
- Spike: node41 passed (oracle 1.0, nop 0.0) through the sidecar. Rollout tool: `author/publish.sh <id> [--push]`; per-task builder `ghcr.io/kinchahoy/<id>-builder`, built on `<id>-inputs`.
