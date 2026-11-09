#!/bin/bash
# Author-time control: the frozen reference must pass every check, run in the verifier image the
# task actually names (the published, digest-pinned image once `mise run publish <id> --push` ran).
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id>}
IMAGE=$(python3 -c 'import sys, tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["verifier"]["environment"]["docker_image"])' "$TASK/task.toml")
echo "check-reference $TASK in $IMAGE" >&2
exec docker run --rm --device /dev/kvm "$IMAGE" python3 /tests/verify.py --reference
