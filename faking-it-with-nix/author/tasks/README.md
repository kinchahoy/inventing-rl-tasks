# Replica task recipes

Each task pairs a Harbor directory `<id>/` with a recipe `author/tasks/<id>/`.
How the reference is produced is entirely the recipe's business (Ubuntu + CINC
via cloud-init, a Vagrant Debian box converted to qcow2, …). Everything after
that is shared: base image, Nix 2.35.4 toolchain, nixpkgs pin (`author/pins`),
replica contract tools (`author/contract`), image graph (`docker-bake.hcl`),
and one sandboxed builder/store (`author/builder`).

## Recipe files

| Path | Purpose |
|---|---|
| `provision` | Builds the reference and fixture credentials (contract below). |
| `provision.Dockerfile` | Optional. Image to run `provision` in, `FROM replica-base:v1`; default is `replica-base:v1` itself. |
| `prewarm.nix` | `pkgs: [ … ]` closures prefetched into images and the builder store. |
| `public/` | Task-specific files copied into `/opt/contract` (`harness.nix`, `replica.nix` skeleton). The agent prompt lives only in `<id>/instruction.md`. |
| `runtime/` | Copied to `/opt/runtime` (`reference start\|stop`, `guest`). |
| `reference-manifest.json` | Written by `provision`; records the frozen disk digest. Committed. |
| `provenance.md` | Upstream source and deviations. Never enters an image. |
| `verification.md` | Check coverage and cost; see `author/methods.md`. |
| `cookbooks/…/complexify.rb` | Optional complexifiers, kept apart from the original recipe; see `author/complexify.md`. |

## `provision` contract

`author/prepare.sh` runs it as `bash $RECIPE/provision` in a container with
`/dev/kvm`, the repo at `/work`, and environment `RECIPE` and `OUT` (absolute
paths). It must:

- write the frozen guest disk to `$OUT/reference/base.qcow2`;
- write files for `/opt/contract` (SSH key, TLS material, …) to `$OUT/creds/`;
- keep scratch state in `$OUT/work/` and exit early when its inputs are
  unchanged (digest what the guest actually receives);
- write `$RECIPE/reference-manifest.json`.

## Adding a task

1. Create `<id>/` with `task.toml` (`[environment] docker_image = "<id>:v1"`,
   `[verifier.environment] docker_image = "<id>-verifier:v1"`), `instruction.md`,
   `tests/` (incl. `docker-compose.yaml` joining network `replica-build`),
   `environment/docker-compose.yaml`, and `solution/`.
2. Create `author/tasks/<id>/` as above.
3. Add `<id>` to `TASKS` in `docker-bake.hcl`.
4. `mise run prepare <id>`, then `check-tools`, `check-oracle`, `build-oracle`.
5. Write checks per `author/methods.md`; run its three controls (reference, oracle, nop).
