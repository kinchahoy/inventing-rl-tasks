#!/bin/bash
# Build only: no reference boot or behavioral checks. Outputs remain cached.
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id>}
mkdir -p .cache/tasks/$TASK/oracle-build
echo "Building oracle VM; live log: .cache/tasks/$TASK/oracle-build/build.log"
START=$SECONDS
if ! docker run --rm --network replica-build \
    -v "$PWD/$TASK/solution/submission:/app/submission:ro" \
    "$TASK-verifier:v1" /opt/contract/build-replica \
    > .cache/tasks/$TASK/oracle-build/result.json \
    2> >(tee .cache/tasks/$TASK/oracle-build/build.log >&2); then
    echo "Build failed or interrupted; log retained in .cache/tasks/$TASK/oracle-build/build.log" >&2
    exit 1
fi
cat .cache/tasks/$TASK/oracle-build/result.json
echo "Oracle VM built and cached in $((SECONDS - START)) seconds. No VM was booted and no behavior checks ran."
