#!/bin/bash
# Harbor run for one Nix task, with the reference VM either baked (default) or rebuilt fresh.
#   author/run-task.sh <task-id> [harbor run args...]           use the images pinned in task.toml (baked VM)
#   author/run-task.sh <task-id> --fresh [harbor run args...]   rebuild the reference VM from the recipe,
#                                                               build local images, run on a temporary copy
# --fresh leaves task.toml untouched (the rewrite happens in a temp copy) and does not push anything.
# Example: author/run-task.sh node17-reconstruction-hard --fresh -a oracle -y
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id> [--fresh] [harbor run args...]}
shift
if [ "${1:-}" != --fresh ]; then
    exec harbor run -p "$TASK" "$@"
fi
shift
# Forcing the reprovision: the recipe skips it while base.qcow2 matches its input digest.
rm -f ".cache/tasks/$TASK/reference/base.qcow2"
bash author/prepare.sh "$TASK"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -r "$TASK" "$WORK/$TASK"
PUBLISH_DEST="$WORK/$TASK" REPLICA_REGISTRY=fresh bash author/publish.sh "$TASK"
harbor run -p "$WORK/$TASK" "$@"
