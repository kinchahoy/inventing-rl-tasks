#!/bin/bash
# Infrastructure only: no oracle, VM boot, reference probes or scoring suite.
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id>}
LOG=$PWD/.cache/tasks/$TASK/builder-smoke
mkdir -p "$LOG"
docker compose -p replica-build -f author/builder/compose.yaml ps
docker logs --tail 20 replica-builder
docker exec replica-builder /opt/nix-current/bin/nix --version
SMOKE_ID=$(date +%s%N)
for run in first second; do
    echo "Running $run build in a fresh client container..."
    if ! docker run --rm --network replica-build -e SMOKE_ID="$SMOKE_ID" \
        -v "$PWD/author/builder/smoke.nix:/opt/cache-smoke.nix:ro" \
        "$TASK-verifier:v1" bash -c '
            set -euo pipefail
            nix --version >&2
            nix build --impure --no-link --json --max-jobs 0 \
                --builders "$REPLICA_REMOTE_BUILDER" \
                --option builders-use-substitutes true \
                --file /opt/cache-smoke.nix > /tmp/result.json
            jq -S "map({drvPath, outputs})" /tmp/result.json
            output=$(jq -r ".[0].outputs.out" /tmp/result.json)
            cat "$output"
        ' > "$LOG/$run.txt" 2> "$LOG/$run.log"; then
        cat "$LOG/$run.log"
        exit 1
    fi
    cat "$LOG/$run.txt"
done
diff -u "$LOG/first.txt" "$LOG/second.txt"
echo "PASS: store-subdirectory closure and non-root sandbox build; unchanged output reused across fresh clients."
echo "Logs: $LOG"
