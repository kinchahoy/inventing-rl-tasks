#!/bin/bash
# Build the zip layout from author/submission-manifest.tsv. Never deletes: the output dir must not exist.
#   author/make-submission.sh            stage final/proposed/ as symlinks (review; no copies)
#   author/make-submission.sh --copy     real copy into final/submission/ (dereferenced)
#   author/make-submission.sh --zip      --copy, then final/submission.zip
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(realpath ..)
MODE=${1:-stage}
case $MODE in stage) OUT=final/proposed ;; --copy | --zip) OUT=final/submission ;; *) echo "usage: $0 [--copy|--zip]" >&2; exit 2 ;; esac
[ ! -e "$OUT" ] || { echo "$OUT exists; move it aside first (this script never deletes)" >&2; exit 1; }
IDENT='raistlin|inferencing\.net|mi50|nuc-?fileserver|nuc10|macbook|192\.168\.0\.(52|66|83)|tailscale|amd-clean|VR[-_](idle|gpu|llama)|coolercontrol|beszel'

mkdir -p "$OUT"/{samples,jobs,archive,report}
pending=0
index="$OUT/archive/README.md"
{
    printf '# archive/: bonus material\n\nSubmitted alongside the core pack (samples/ + jobs/). Each bonus-N set is laid out like the core pack: task dirs plus jobs/<job>/<trial>/.\n'
    printf 'Task directory names are unchanged so each job config still matches its task.\n\n'
    printf '| Path | What it is |\n|---|---|\n'
} > "$index"
while IFS=$'\t' read -r dest src label; do
    [[ -z "$dest" || "$dest" == \#* ]] && continue
    if [ ! -e "$ROOT/$src" ]; then echo "PENDING  $dest  (missing $src)"; pending=$((pending + 1)); continue; fi
    mkdir -p "$(dirname "$OUT/$dest")"
    if [ "$MODE" = stage ]; then
        ln -s "$ROOT/$src" "$OUT/$dest"
    elif [[ "$dest" == archive/bonus-4-nix-research/source ]]; then
        mkdir -p "$OUT/$dest" && tar -C "$ROOT/$src" --exclude=./real -cf - . | tar -C "$OUT/$dest" -xf -
    else
        cp -rL "$ROOT/$src" "$OUT/$dest"
    fi
    [[ "$dest" == archive/* ]] && printf '| `%s` | %s |\n' "${dest#archive/}" "$label" >> "$index"
done < author/submission-manifest.tsv
printf 'Put the human-written report here (single file).\n' > "$OUT/report/PLACEHOLDER.txt"

echo "--- samples: $(ls "$OUT/samples" | tr '\n' ' ')"
echo "--- ls jobs/*/*/result.json: $(cd "$OUT" && ls jobs/*/*/result.json 2>/dev/null | wc -l) trials"
echo "--- pending: $pending"
if [ "$MODE" != stage ]; then
    hits=$(grep -rlIE -i "$IDENT" "$OUT/samples" "$OUT/archive" 2>/dev/null || true)
    [ -z "$hits" ] || { echo "real-machine mentions (review):"; echo "$hits" | sed "s#^$OUT/#  #"; }
    [ "$pending" = 0 ] || { echo "refusing: $pending pending entries" >&2; exit 1; }
fi
if [ "$MODE" = --zip ]; then (cd "$OUT" && zip -qr ../submission.zip samples jobs archive report) && ls -la final/submission.zip; fi
