#!/bin/bash
# Final submission runs for one task, into runs/jobs/ (kept apart from development jobs/):
# oracle, nop, then the brief's model command with three trials.
#   author/final-runs.sh <task-id>
set -uo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id>}
OUT=runs/jobs
mkdir -p "$OUT"
grep -q 'docker_image = "beginagain/' "$TASK/task.toml" || { echo "$TASK is not on the published images yet" >&2; exit 1; }
run() { echo "[$(date +%H:%M)] $TASK: $*"; harbor run -p "$TASK" -y -o "$OUT" "$@"; }
run -a oracle --job-name "$TASK-oracle"
sleep 3
run -a nop --job-name "$TASK-nop"
sleep 3
# The brief's step-4 command, plus our credentials file and output/concurrency options.
run -a claude-code -m claude-haiku-5-5 --ak reasoning_effort=high -k 3 -n 3 \
    --env-file ../.env --job-name "$TASK-haiku-k3"
echo "[$(date +%H:%M)] $TASK: done"
