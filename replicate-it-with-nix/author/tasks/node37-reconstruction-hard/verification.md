# node37 verifier: coverage and cost

2026-11-03. 18 checks (14 recipe, 4 complexifier) in `node37-reconstruction-hard/tests/verify.py`. Controls: reference 18/18; oracle 18/18 (`jobs/2026-11-03__17-39-16`); empty submission 0/18 (`jobs/2026-11-03__17-39-19`). Everything is one or two SSH commands (methods.md rank 1); none uses the network contract (only port 22 is forwarded).

| Check | Reads | Hardware stand-in |
| --- | --- | --- |
| host_identity, accounts | hostname, timezone, getent, `id -nG` (exact uids/gids 1000/992/113) | none |
| kernel_cmdline, cmdline_decoy | `/proc/cmdline` tokens (reference rebooted at provision time); decoy tokens from the `.cfg.disabled` profile must be absent | boot.kernelParams |
| module_policy | `modprobe -c` (options, install, blacklist) + `modprobe -n -v` | module not loaded |
| lockup_sysctl, sysctl_decoy | `/proc/sys` exact values, softlockup left 0, `.dpkg-old` decoy ignored | detector may not exist (risk 1) |
| sleep_policy | `is-enabled` for four sleep targets, logind `IdleAction`/`IdleActionUSec` over D-Bus, `sleep.target` Requires/After | never sleeps |
| sleep_cleanup | unit properties; behaviour: a process holding `/dev/accel-compute` open is terminated by `start`, and `stop` (ExecStop) restores the 210 W cap | regular file in `/dev` |
| accel_setup | enabled, oneshot+RemainAfterExit, per-slot caps 210000000/170000000, `control=on` | fixture tree |
| idle_monitor | timer 5min/5min, enabled; running the service while the SSH session is up logs `Not idle: CONN_COUNT>=1`, resets the counter and never calls the suspend stand-in | `lab-suspend` |
| infer_unit | loaded, inactive, disabled (not in multi-user Wants), User, Restart, RestartUSec, LimitNOFILE, EnvironmentFile | none |
| tool_env | pyproject parsed (deps, `requires-python`, explicit custom index), env script run as the operator, wrapper output | stub tool prints fixture |
| metrics_agent | 11 sandbox properties, listener owner = `probe`, HTTP 200, StateDirectory, update timer (daily, Persistent, 4h delay) | none |
| udev_i2c | the rule files `udevadm test` reports loading; any rule giving i2c nodes group `i2c`, mode 0660 | no i2c device |
| sysstat_timer | `TimersCalendar` has the per-minute entry and not the default | none |
| etc_environment (CX-etc-environment) | `ACCEL_VISIBLE_DEVICES=0,1`, `OMP_NUM_THREADS=8` in a non-interactive ssh command and in `su -l ember` (Ubuntu applies `/etc/environment` through pam_env; `runuser -l` does not read it on Ubuntu, so it is not used) | none |

Each denial is paired with an allowed path (masked vs static targets; disabled infer unit vs enabled setup unit; decoy tokens absent vs real tokens present).

## Not checked
Actual suspend/resume, kdump, real power caps, the venv contents, Docker, firewall, Tailscale: hardware, network or secrets.
## Controls
`mise run check-reference node37-reconstruction-hard`, oracle (1.0), `nop` (0.0): done 2026-11-03, see the top.
