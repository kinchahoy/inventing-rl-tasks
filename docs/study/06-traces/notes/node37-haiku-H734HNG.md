## What to notice

1. 0.94 (17/18); single miss `udev_i2c`: no udev rule giving `i2c-*` nodes `GROUP="i2c", MODE="0660"`.
2. It saw the `i2c` group (steps 12, 22-28: identities and GID fixes) but no command ever mentions `udev` or `/etc/udev/rules.d`. The group was copied; the rule that gives the group meaning was not.
3. Good catches: kernel cmdline params, lockup/hung-task sysctls, `algif_aead` install rule, logind idle suspend, masked hibernate/hybrid-sleep, sleep-cleanup ordering, `lab-suspend` stand-in (step 59 tests `systemctl suspend` safely), `/etc/environment` variables for SSH sessions (CX-etc-environment), uv tool env and `accel-smi` wrapper.
4. Distinctive good method: step 39 runs an identical probe script on both machines and diffs the output (sysctl, units, identities, device files). That diff is what found the PATH, env and GID gaps at step 41.
5. The diff's probe list did not include udev rules, so the diff could not find the miss. A comparison is only as good as its probe list.
6. Harness hygiene again costs ~5 min: wrong VM script name (`run-node37-vm`, step 34), `pkill` killing itself (step 37), stale VMs answering on 3222 twice (steps 52, 57). It once debugged a stale VM as if it were the new build.
7. Nix-specific trap handled: `#!/usr/bin/env bash` shebangs fail in units (no bash on unit PATH), fixed by store-path shebangs (step 36). tmpfiles refusing root-owned dirs under a user-owned parent (step 56).
8. The header's "last reference query" (18:11) is the end-of-run "stop VMs" step. Real recon ended ~13:40.
9. It honestly lists guesses at the end (initial fixture values) — useful calibration signal.
10. Stopped at 18.3 min with 42 minutes left, claiming parity.
