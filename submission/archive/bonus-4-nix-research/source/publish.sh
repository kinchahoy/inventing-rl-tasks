#!/bin/bash
# Make a prepared task publishable: GHCR-named task/verifier/builder images, a per-trial sandboxed
# builder sidecar (fixture keys), no external network, gateway env block.
#   author/publish.sh <task-id>            build images + rewrite task files (no push)
#   author/publish.sh <task-id> --push     also push and pin images by digest
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id> [--push]}
REG=${REPLICA_REGISTRY:-ghcr.io/kinchahoy}
[ -d "$TASK" ] && docker image inspect "$TASK:v1" "$TASK-inputs:v1" >/dev/null || {
    echo "Prepare first: mise run prepare $TASK" >&2; exit 1; }

cp author/fixtures/builder/client_key "$TASK/tests/builder_key"
docker buildx build --load -q -f author/images/builder-pub.Dockerfile \
    --build-context inputs="docker-image://$TASK-inputs:v1" \
    --build-context fixtures=author/fixtures/builder --build-context builder=author/builder \
    -t "$REG/$TASK-builder:v1" author/images >/dev/null
docker buildx build --load -q -f author/images/verifier-pub.Dockerfile \
    --build-context task="docker-image://$TASK:v1" --build-context tests="$TASK/tests" \
    -t "$REG/$TASK-verifier:v1" author/images >/dev/null
docker tag "$TASK:v1" "$REG/$TASK:v1"

ref() { # image reference written into task files: digest once pushed, tag before
    local digest
    digest=$(docker image inspect "$REG/$1:v1" --format '{{range .RepoDigests}}{{.}}{{"\n"}}{{end}}' | grep "^$REG/$1@" | head -1 || true)
    echo "${digest:-$REG/$1:v1}"
}
if [ "${2:-}" = --push ]; then
    for i in "$TASK" "$TASK-verifier" "$TASK-builder"; do docker push -q "$REG/$i:v1" >/dev/null; done
fi

HOSTKEY=$(base64 -w0 author/fixtures/builder/host_key.pub)
cat > "$TASK/environment/docker-compose.yaml" <<'EOF'
services:
  main:
    devices:
      - /dev/kvm:/dev/kvm
EOF
cat > "$TASK/tests/docker-compose.yaml" <<EOF
# Verifier plus a per-trial sandboxed Nix builder. The builder lives only in this compose project;
# its SSH keys are published fixtures (see author/fixtures/builder/README.md).
services:
  main:
    devices:
      - /dev/kvm:/dev/kvm
    environment:
      REPLICA_REMOTE_BUILDER: "ssh-ng://buildclient@builder x86_64-linux /tests/builder_key 2 1 - - $HOSTKEY"
    depends_on:
      builder:
        condition: service_healthy
  builder:
    image: $(ref "$TASK-builder")
    cap_add:
      - SYS_ADMIN
    security_opt:
      - seccomp=unconfined
      - apparmor=unconfined
    healthcheck:
      test: ["CMD-SHELL", "test -S /nix/var/nix/daemon-socket/socket && kill -0 \$\$(cat /run/sshd/replica.pid)"]
      interval: 2s
      timeout: 2s
      retries: 60
EOF
python3 - "$TASK" "$(ref "$TASK")" "$(ref "$TASK-verifier")" <<'PY'
import re, sys
from pathlib import Path
task, image, verifier = sys.argv[1:]
p = Path(task) / "task.toml"; s = p.read_text()
s = re.sub(r"(?m)^# Prebuilt by .*\n", "", s)
s = re.sub(r'(\[verifier\.environment\]\n(?:[^\[]*\n)*?)docker_image = "[^"]*"', rf'\1docker_image = "{verifier}"', s, count=1)
s = re.sub(r'(\[environment\]\n(?:[^\[]*\n)*?)docker_image = "[^"]*"', rf'\1docker_image = "{image}"', s, count=1)
if "[environment.env]" not in s:
    s = s.rstrip("\n") + ('\n[environment.env]\n# Route model calls through the take-home gateway (required by the brief).\n'
        'ANTHROPIC_BASE_URL = "https://take-home-automation.vercel.app"\n'
        'ANTHROPIC_API_BASE = "https://take-home-automation.vercel.app"\n')
p.write_text(s)
PY
grep -n 'docker_image' "$TASK/task.toml"
echo "Published layout for $TASK (push: ${2:-no})."
