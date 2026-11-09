#!/bin/sh
set -eu
mkdir -p /logs/verifier
python3 /tests/verify.py /app > /logs/verifier/checks.json
python3 -c 'import json; from pathlib import Path; d=json.loads(Path("/logs/verifier/checks.json").read_text()); Path("/logs/verifier/reward.txt").write_text(str(d["reward"]))'
