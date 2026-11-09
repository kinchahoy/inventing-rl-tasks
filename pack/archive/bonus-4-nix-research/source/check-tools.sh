#!/bin/bash
# Meaningful checker regressions: no VM boot and builds explicitly disabled.
set -euo pipefail
cd "$(dirname "$0")/.."
TASK=${1:?usage: $0 <task-id>}
ROOT=$PWD/.cache/tasks/$TASK/check-replica-regressions
mkdir -p "$ROOT"/{syntax,option,type,ifd}
printf '%s\n' '{ ... }: { networking.hostName = ; }' > "$ROOT/syntax/replica.nix"
printf '%s\n' '{ ... }: { services.thisOptionDoesNotExist.enable = true; }' > "$ROOT/option/replica.nix"
printf '%s\n' '{ ... }: { services.openssh.enable = "wrong"; }' > "$ROOT/type/replica.nix"
cat > "$ROOT/ifd/replica.nix" <<'NIX'
{ pkgs, ... }: {
  networking.hostName = builtins.readFile (pkgs.runCommand "checker-must-not-build" {} "echo example > $out");
}
NIX
for CASE in syntax option type ifd; do
    if docker run --rm -v "$ROOT/$CASE:/app/submission:ro" \
        "$TASK:v1" /opt/contract/check-replica > "$ROOT/$CASE.log" 2>&1; then
        echo "FAIL: checker accepted $CASE" >&2
        exit 1
    fi
    case $CASE in
      syntax) EXPECT='syntax error' ;;
      option) EXPECT='does not exist' ;;
      type) EXPECT='not of type' ;;
      ifd) EXPECT='allow-import-from-derivation' ;;
    esac
    if ! grep -q "$EXPECT" "$ROOT/$CASE.log"; then cat "$ROOT/$CASE.log"; exit 1; fi
    echo "PASS: rejected $CASE with the expected diagnostic"
done
# Build-user parity with the verifier's builder: local builds must not run as root.
OUT=$(docker run --rm "$TASK:v1" sh -c 'nix-build --no-out-link -E "derivation { name = \"build-user-probe\"; system = \"x86_64-linux\"; builder = \"/bin/sh\"; args = [ \"-c\" \"/usr/bin/id -u > \$out\" ]; }" | xargs cat')
if [ "$OUT" = 0 ] || [ -z "$OUT" ]; then
    echo "FAIL: local builds run as uid '${OUT}', not an unprivileged build user" >&2
    exit 1
fi
echo "PASS: local builds run as build user uid $OUT"
