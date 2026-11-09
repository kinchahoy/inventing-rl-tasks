# Shared by check-replica and build-replica. No submission flake evaluation.
SUBMISSION=$(realpath "${1:-/app/submission}")
if [ ! -f "$SUBMISSION/replica.nix" ]; then
    echo "Missing NixOS module: $SUBMISSION/replica.nix" >&2
    exit 2
fi
NIXPKGS_SOURCE=$(readlink -f /opt/nixpkgs)
EVAL_OPTIONS=(--impure --show-trace
    --option restrict-eval true --option allowed-uris ""
    -I "$SUBMISSION" -I /opt/contract -I /nix/store
    --file /opt/contract/build.nix --argstr submission "$SUBMISSION" --argstr nixpkgs "$NIXPKGS_SOURCE")
