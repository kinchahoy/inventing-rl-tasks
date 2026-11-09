#!/usr/bin/env bash
set -u

HOLD_DEVICE="${HOLD_DEVICE:-/dev/accel-compute}"
PROC_ROOT="${PROC_ROOT:-/proc}"
TERM_GRACE_SEC="${TERM_GRACE_SEC:-10}"

log() { /usr/bin/logger -t accel-sleep-cleanup -- "$*"; }

get_holder_pids() {
  local fd pid
  shopt -s nullglob
  for fd in "$PROC_ROOT"/[0-9]*/fd/*; do
    if [[ "$(readlink "$fd" 2>/dev/null || true)" == "$HOLD_DEVICE" ]]; then
      pid="${fd#"$PROC_ROOT"/}"; pid="${pid%%/*}"
      if [[ "$pid" =~ ^[0-9]+$ && "$pid" -ne 1 && "$pid" -ne $$ ]]; then printf '%s\n' "$pid"; fi
    fi
  done | sort -nu
  shopt -u nullglob
}

wait_for_clear() {
  local attempt
  for ((attempt = 0; attempt < $1; attempt++)); do
    [[ -z "$(get_holder_pids)" ]] && return 0
    /usr/bin/sleep 1
  done
  return 1
}

if [[ ! -e "$HOLD_DEVICE" ]]; then
  log "$HOLD_DEVICE is absent; no holders to clean up"
  exit 0
fi
mapfile -t pids < <(get_holder_pids)
if [[ "${#pids[@]}" -eq 0 ]]; then
  log "no $HOLD_DEVICE holders; suspend is safe"
  exit 0
fi
declare -A units=()
for pid in "${pids[@]}"; do
  unit="$(sed -nE 's#^[^:]*:[^:]*:/system[.]slice/([^/]+[.]service)(/.*)?$#\1#p' "$PROC_ROOT/$pid/cgroup" | head -n 1)"
  if [[ -n "$unit" ]]; then units["$unit"]=1; fi
done
for unit in "${!units[@]}"; do
  log "stopping system service $unit before suspend"
  /usr/bin/systemctl --no-block stop "$unit" || true
done
mapfile -t pids < <(get_holder_pids)
if [[ "${#pids[@]}" -gt 0 ]]; then
  log "sending SIGTERM to holders: ${pids[*]}"
  /usr/bin/kill -TERM "${pids[@]}" 2>/dev/null || true
  wait_for_clear "$TERM_GRACE_SEC" || true
fi
mapfile -t pids < <(get_holder_pids)
if [[ "${#pids[@]}" -gt 0 ]]; then
  log "sending SIGKILL to remaining holders: ${pids[*]}"
  /usr/bin/kill -KILL "${pids[@]}" 2>/dev/null || true
  wait_for_clear 2 || true
fi
mapfile -t pids < <(get_holder_pids)
if [[ "${#pids[@]}" -gt 0 ]]; then
  log "refusing suspend: $HOLD_DEVICE is still held by PIDs ${pids[*]}"
  exit 1
fi
log "all $HOLD_DEVICE holders stopped; suspend is safe"
