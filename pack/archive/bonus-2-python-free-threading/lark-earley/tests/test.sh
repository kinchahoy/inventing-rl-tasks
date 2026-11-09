#!/bin/sh
set -eu
mkdir -p /logs/verifier
chmod 700 /tests /logs/verifier
exec python-gil -B /tests/verify.py
