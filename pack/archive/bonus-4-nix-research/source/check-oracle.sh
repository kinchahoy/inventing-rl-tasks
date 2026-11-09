#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id>}
docker run --rm \
    -v "$PWD/$TASK/solution/submission:/app/submission:ro" \
    "$TASK:v1" /opt/contract/check-replica
