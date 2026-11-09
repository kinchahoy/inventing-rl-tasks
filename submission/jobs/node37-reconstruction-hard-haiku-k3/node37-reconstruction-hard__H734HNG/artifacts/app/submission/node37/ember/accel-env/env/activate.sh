#!/usr/bin/env bash
set -euo pipefail

ACCEL_ENV=/home/ember/accel-env
export ACCEL_HOME="${ACCEL_ENV}/.venv/lib/python3/site-packages/_accel_sdk_devel"
export ACCEL_PLATFORM=amd
export ACCEL_ARCH=gfx906
export BLAS_BACKEND_LT=0
export PATH="${ACCEL_HOME}/bin:${ACCEL_HOME}/llvm/bin:${PATH}"
export LD_LIBRARY_PATH="${ACCEL_HOME}/lib:${ACCEL_HOME}/lib64:${ACCEL_HOME}/llvm/lib:${LD_LIBRARY_PATH:-}"
