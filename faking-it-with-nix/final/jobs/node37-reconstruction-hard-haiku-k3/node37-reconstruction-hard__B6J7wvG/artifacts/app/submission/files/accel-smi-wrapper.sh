#!/bin/sh
# wrapper, not symlink: the tool finds its bindings relative to its real path
exec /home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin/accel-smi "$@"
