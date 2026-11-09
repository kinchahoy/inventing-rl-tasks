"""Explicitly apply corrected cloud-init write_files to a preserved build guest."""

import base64
import json
from pathlib import Path

seed = json.loads(Path("/tmp/archive-seed.json").read_text().split("\n", 1)[1])
for entry in seed["write_files"]:
    destination = Path(entry["path"])
    destination.parent.mkdir(parents=True, exist_ok=True)
    content = entry["content"]
    destination.write_bytes(base64.b64decode(content) if entry.get("encoding") == "b64" else content.encode())
    destination.chmod(int(entry["permissions"], 8))
