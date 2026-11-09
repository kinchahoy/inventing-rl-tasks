#!/bin/sh
# Applies solution/oracle.patch to the SymPy package in /app/sympy (idempotent).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
cd /app/sympy
if git apply -p1 --reverse --check "$here/oracle.patch" >/dev/null 2>&1; then
    echo "oracle patch already applied"
    exit 0
fi
git apply -p1 "$here/oracle.patch"
python-gil -B -c "import sys; sys.path.insert(0, '/app'); import sympy.core._parallel"
echo "oracle patch applied"
