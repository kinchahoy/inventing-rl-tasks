#!/usr/bin/env bash
set -euo pipefail

PCI_SYSFS_ROOT="${PCI_SYSFS_ROOT:-/sys/bus/pci/devices}"
CPU_SYSFS_ROOT="${CPU_SYSFS_ROOT:-/sys/devices/system/cpu}"

write_checked() {
  local value="$1"
  local target="$2"

  printf '%s\n' "$value" >"$target"
  local actual
  actual="$(<"$target")"
  if [[ "$actual" != "$value" ]]; then
    printf 'failed to set %s to %s (read back %s)\n' "$target" "$value" "$actual" >&2
    return 1
  fi
}

configure_dev() {
  local pci_address="$1"
  local power_cap_microwatts="$2"
  local device="$PCI_SYSFS_ROOT/$pci_address"
  local cap_files=("$device"/hwmon/hwmon*/power1_cap)

  if [[ ! -e "${cap_files[0]}" ]]; then
    printf 'power cap file not found for device %s\n' "$pci_address" >&2
    return 1
  fi

  write_checked on "$device/power/control"
  for cap_file in "${cap_files[@]}"; do
    write_checked "$power_cap_microwatts" "$cap_file"
  done
}

# Operator-selected caps, addressed by PCI slot so enumeration order cannot swap them.
configure_dev 0000:03:00.0 210000000
configure_dev 0000:87:00.0 170000000

for epp_file in "$CPU_SYSFS_ROOT"/cpu*/cpufreq/energy_performance_preference; do
  if [[ -e "$epp_file" ]]; then
    write_checked power "$epp_file"
  fi
done
