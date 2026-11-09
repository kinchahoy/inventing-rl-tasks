#!/bin/bash
# Re-grade a finished trial's saved submission with the task's currently pinned verifier and builder,
# mirroring tests/docker-compose.yaml. Output goes to <out-dir> (reward.txt, checks.json, logs).
#   author/regrade.sh <task-id> <trial-dir> <out-dir>
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id> <trial-dir> <out-dir>}; TRIAL=${2:?trial dir}; OUT=${3:?out dir}
SUB="$TRIAL/artifacts/app/submission"
[ -f "$SUB/replica.nix" ] || { echo "no submission at $SUB" >&2; exit 1; }
VERIFIER=$(sed -n '/^\[verifier.environment\]/,/^\[/s/^docker_image = "\(.*\)"/\1/p' "$TASK/task.toml")
BUILDER=$(sed -n 's/^ *image: \(.*-builder@.*\)/\1/p' "$TASK/tests/docker-compose.yaml")
SPEC=$(sed -n 's/^ *REPLICA_REMOTE_BUILDER: "\(.*\)"/\1/p' "$TASK/tests/docker-compose.yaml")
[ -n "$VERIFIER" ] && [ -n "$BUILDER" ] && [ -n "$SPEC" ] || { echo "could not read pins for $TASK" >&2; exit 1; }
NAME=regrade-$$; mkdir -p "$OUT"; OUT=$(realpath "$OUT"); SUB=$(realpath "$SUB")
trap 'docker rm -f $NAME-builder >/dev/null 2>&1; docker network rm $NAME >/dev/null 2>&1' EXIT
docker network create "$NAME" >/dev/null
docker run -d --name "$NAME-builder" --network "$NAME" --network-alias builder \
    --cap-add SYS_ADMIN --security-opt seccomp=unconfined --security-opt apparmor=unconfined "$BUILDER" >/dev/null
for _ in $(seq 60); do docker exec "$NAME-builder" sh -c 'test -S /nix/var/nix/daemon-socket/socket && kill -0 $(cat /run/sshd/replica.pid)' 2>/dev/null && break; sleep 2; done
docker run --rm --network "$NAME" --device /dev/kvm -e REPLICA_REMOTE_BUILDER="$SPEC" \
    -v "$SUB:/app/submission:ro" -v "$OUT:/logs/verifier" "$VERIFIER" bash /tests/test.sh
echo "$TASK $(basename "$TRIAL"): reward $(cat "$OUT/reward.txt")"
