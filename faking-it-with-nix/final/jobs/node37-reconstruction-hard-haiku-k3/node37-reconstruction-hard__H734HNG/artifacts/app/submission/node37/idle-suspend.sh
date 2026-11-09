#!/usr/bin/env bash
set -u

IDLE_LIMIT="${IDLE_LIMIT:-2}"
LOAD_THRESHOLD="${LOAD_THRESHOLD:-2.0}"
IDLE_FILE="${IDLE_FILE:-/tmp/network_idle_counter}"
LOCK_FILE="${LOCK_FILE:-/tmp/network_idle_counter.lock}"
PCI_SYSFS_ROOT="${PCI_SYSFS_ROOT:-/sys/bus/pci/devices}"
DEV_PCI_ADDRESSES="${DEV_PCI_ADDRESSES:-0000:03:00.0 0000:87:00.0}"
SUSPEND_CMD="${SUSPEND_CMD:-/usr/bin/systemctl suspend}"

IGNORE_PORTS_REGEX='(:67|:68)([[:space:]]|$)'
IGNORE_PROCS_REGEX='\("(vpnd|metrics-agent)",'

log() { /usr/bin/logger -t idle-suspend -- "$*"; }
reset_idle() { printf '0\n' >"$IDLE_FILE"; }
idle_check_failed() { log "Not idle: idle check failed: $1"; reset_idle; exit 0; }

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

if ! ALL_CONNS="$(/usr/bin/ss -Htnp state established 2>/dev/null)"; then
  idle_check_failed "cannot read established TCP connections"
fi
FILTERED_CONNS="$(printf '%s\n' "$ALL_CONNS" | grep -vE '(^|[[:space:]])(127\.0\.0\.1|\[?::1\]?):' | grep -vE "$IGNORE_PROCS_REGEX" | grep -vE "$IGNORE_PORTS_REGEX" || true)"
CONN_COUNT="$(printf '%s\n' "$FILTERED_CONNS" | sed '/^$/d' | wc -l | tr -d ' ')"

DEV_UTIL=0
for pci_address in $DEV_PCI_ADDRESSES; do
  busy_file="$PCI_SYSFS_ROOT/$pci_address/gpu_busy_percent"
  [[ -r "$busy_file" ]] || idle_check_failed "cannot read $busy_file"
  busy_value="$(<"$busy_file")"
  [[ "$busy_value" =~ ^[0-9]+$ ]] || idle_check_failed "invalid utilization in $busy_file: $busy_value"
  DEV_UTIL=$((DEV_UTIL + busy_value))
done

read -r LOAD_1M _ </proc/loadavg
LOAD_BUSY=0
if /usr/bin/awk -v current_load="$LOAD_1M" -v threshold="$LOAD_THRESHOLD" 'BEGIN { exit !(current_load > threshold) }'; then
  LOAD_BUSY=1
fi

if [[ "$CONN_COUNT" -gt 0 || "$DEV_UTIL" -gt 0 || "$LOAD_BUSY" -eq 1 ]]; then
  LOG_CONNS="$(printf '%s' "$FILTERED_CONNS" | tr '\n' ';' | sed 's/;*$//')"
  log "Not idle: CONN_COUNT=$CONN_COUNT DEV_UTIL=${DEV_UTIL}% LOAD_1M=$LOAD_1M Blocking Conns: [${LOG_CONNS}]"
  reset_idle
  exit 0
fi

[[ -f "$IDLE_FILE" ]] || reset_idle
CURRENT_IDLE="$(<"$IDLE_FILE")"
[[ "$CURRENT_IDLE" =~ ^[0-9]+$ ]] || CURRENT_IDLE=0
NEW_IDLE=$((CURRENT_IDLE + 1))
printf '%s\n' "$NEW_IDLE" >"$IDLE_FILE"

if [[ "$NEW_IDLE" -ge "$IDLE_LIMIT" ]]; then
  rm -f "$IDLE_FILE"
  log "System idle for $IDLE_LIMIT consecutive checks (Network: $CONN_COUNT, Dev: ${DEV_UTIL}%, Load: $LOAD_1M). Suspending."
  $SUSPEND_CMD || log "suspend failed with exit=$?"
fi
