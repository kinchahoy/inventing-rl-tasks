#!/bin/bash
# Prepare one task end to end. Idempotent: unchanged steps are cache hits.
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: prepare.sh <task-id>}
RECIPE=author/tasks/$TASK
OUT=.cache/tasks/$TASK
if [ ! -f "$RECIPE/provision" ] || [ ! -d "$TASK" ]; then
    echo "Missing $RECIPE/provision or Harbor task directory $TASK/." >&2
    exit 2
fi

# 1. Reference disk and fixture credentials (recipe decides when to reprovision).
docker buildx bake --load base
IMAGE=replica-base:v1
if [ -f "$RECIPE/provision.Dockerfile" ]; then
    IMAGE=$TASK-provision:v1
    docker build -t "$IMAGE" -f "$RECIPE/provision.Dockerfile" "$RECIPE"
fi
docker run --rm --device /dev/kvm -e RESUME="${RESUME:-0}" \
    -e RECIPE="/work/$RECIPE" -e OUT="/work/$OUT" \
    -v "$PWD:/work" -w /work "$IMAGE" bash "/work/$RECIPE/provision"
# The provision container runs as root; hand its output back to the host user.
docker run --rm -v "$PWD:/work" "$IMAGE" chown -R "$(id -u):$(id -g)" /work/.cache

# 2. Shared builder credentials. Only the verifier image receives the client key.
KEYS=.cache/builder
mkdir -p "$KEYS/client" "$KEYS/server"
if [ ! -f "$KEYS/client/client_key" ]; then
    ssh-keygen -q -t ed25519 -N '' -C replica-verifier -f "$KEYS/client/client_key"
fi
if [ ! -f "$KEYS/server/host_key" ]; then
    ssh-keygen -q -t ed25519 -N '' -C replica-builder -f "$KEYS/server/host_key"
fi
ssh-keygen -y -f "$KEYS/client/client_key" > "$KEYS/server/client_key.pub"
awk '{print "replica-builder " $1 " " $2}' "$KEYS/server/host_key.pub" > "$KEYS/client/known_hosts"

# 3. Images: builder, inputs, solving image, verifier (with current tests).
docker buildx bake --load builder "inputs-$TASK" "task-$TASK" "verifier-$TASK"

# 4. Shared builder; import this task's prewarmed closures only if missing.
docker network inspect replica-build >/dev/null 2>&1 || docker network create replica-build
# Docker fills an empty new volume from the builder image store (Nix itself).
docker volume create replica-nix-store-v1 >/dev/null
COMPOSE=(docker compose -p replica-build -f author/builder/compose.yaml)
"${COMPOSE[@]}" up -d --wait
mapfile -t ROOTS < <(docker run --rm --entrypoint /bin/bash "$TASK-inputs:v1" -c '
    set -euo pipefail
    readlink -f /opt/nix-current
    nix eval --impure --json --file /opt/prewarm-roots.nix --apply "map (d: d.outPath)" | jq -er ".[]"')
if docker exec replica-builder nix-store --check-validity "${ROOTS[@]}" 2>/dev/null; then
    echo "Builder store already holds $TASK closures."
else
    echo "Importing $TASK closures; stopping builder (do not prepare during active builds)."
    "${COMPOSE[@]}" stop builder
    # Our own trusted, prewarmed image, not an untrusted binary cache. Some local
    # outputs are unsigned; the exemption is scoped to this import, and the
    # daemon keeps require-sigs=true.
    docker run --rm -v replica-nix-store-v1:/target/nix --entrypoint /bin/bash "$TASK-inputs:v1" \
        -c 'NIX_REMOTE=local nix copy --no-check-sigs --to "local?root=/target" "$@"' _ "${ROOTS[@]}"
    "${COMPOSE[@]}" up -d --wait
fi
echo "Prepared $TASK: images $TASK:v1 and $TASK-verifier:v1."
