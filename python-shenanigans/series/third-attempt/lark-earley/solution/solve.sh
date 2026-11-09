#!/bin/sh
# Oracle: overlay the patched Earley modules onto the pristine Lark 1.3.1 copy in /app/lark. Idempotent.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
cp -f "$here"/lark/parsers/*.py /app/lark/parsers/
