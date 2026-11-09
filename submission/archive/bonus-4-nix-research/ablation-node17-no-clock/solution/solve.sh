#!/bin/bash
set -euo pipefail
mkdir -p /app/submission
cp -a /solution/submission/. /app/submission/
# Write the oracle source only; do not build or run it here.
