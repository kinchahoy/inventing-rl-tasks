#!/bin/sh
# Stand-in for the SDK's device query tool; reads the fixture device tree.
root=${PCI_SYSFS_ROOT:-/var/lib/node37/pci}
for d in "$root"/*; do
  printf '%s cap=%s busy=%s\n' "$(basename "$d")" "$(cat "$d"/hwmon/hwmon0/power1_cap)" "$(cat "$d"/gpu_busy_percent)"
done
