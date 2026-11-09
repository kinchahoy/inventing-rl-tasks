"""Compute-host verifier: recipe and complexifier checks; see author/methods.md and verification.md.

Hardware-dependent behavior (sleep, power caps) is checked through effective state and by running the
operator's own units against the sysfs-shaped fixture tree; the VM is never suspended.
Values come from the frozen reference. Checks have not yet been run (first draft): run
`mise run check-reference node37-reconstruction-hard` and fix any reference-side mismatch first.
"""

import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path

LOG = Path("/logs/verifier")
FIX = "/var/lib/node37/pci"
DEV_A, DEV_B = "0000:03:00.0", "0000:87:00.0"
CRASH = "crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M"


def run(args, *, check=True, timeout=30, **kwargs):
    result = subprocess.run(args, check=False, capture_output=True, timeout=timeout, **kwargs)
    if check and result.returncode:
        detail = (result.stdout + result.stderr).decode(errors="replace")
        raise RuntimeError(f"Command {shlex.join(args)} exited {result.returncode}:\n{detail}")
    return result


def require(condition, detail):
    if not condition:
        raise AssertionError(str(detail))


def poll(function, *, timeout=30, interval=1):
    """Retries function until it stops raising AssertionError; returns its value."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            return function()
        except AssertionError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(interval)


class Guest:
    def __init__(self, candidate=False):
        self.ssh_port = 3222 if candidate else 2222

    def ssh(self, command, *, check=True, timeout=60):
        return run(
            ["/opt/runtime/guest", command],
            env=dict(os.environ, GUEST_SSH_PORT=str(self.ssh_port)),
            check=check,
            timeout=timeout,
        )

    def out(self, command, **kwargs):
        return self.ssh(command, **kwargs).stdout.decode(errors="replace").strip()

    def props(self, unit, *names):
        text = self.out(f"systemctl show {unit} " + " ".join(f"-p {n}" for n in names))
        return dict(line.split("=", 1) for line in text.splitlines() if "=" in line)

    def ready(self, timeout=240):
        deadline = time.monotonic() + timeout
        while True:
            try:
                self.ssh("systemctl is-system-running --wait >/dev/null 2>&1; true", timeout=60)
                return
            except (RuntimeError, subprocess.SubprocessError):
                if time.monotonic() >= deadline:
                    raise
                time.sleep(2)


def check(name, g):
    if name == "host_identity":
        out = g.out("hostname; timedatectl show -p Timezone --value; readlink -f /etc/localtime")
        host, zone, link = out.splitlines()
        require(host == "node37", host)
        require(zone == "America/Los_Angeles", zone)
        require(link.endswith("America/Los_Angeles"), link)
    elif name == "accounts":
        out = g.out("getent passwd ember; getent group ember accel i2c; id -nG ember; getent passwd probe").splitlines()
        ember = out[0].split(":")
        require(ember[2:4] == ["1000", "1000"] and ember[5] == "/home/ember" and ember[6].endswith("bash"), out[0])
        require(out[1].startswith("ember:") and out[1].split(":")[2] == "1000", out[1])
        require(out[2].split(":")[2] == "992", out[2])
        require(out[3].startswith("i2c:"), out[3])  # gid not pinned (approximation of the real host)
        require(set(out[4].split()) == {"ember", "adm", "sudo", "video", "accel", "i2c"}, out[4])
        require(out[5].split(":")[6].endswith("nologin"), out[5])
    elif name == "kernel_cmdline":
        tokens = g.out("cat /proc/cmdline").split()
        for token in ("intel_iommu=on", "iommu=pt", "pcie_aspm=off", CRASH):
            require(token in tokens, f"{token} missing from {tokens}")
    elif name == "module_policy":
        conf = g.out("modprobe -c")
        require(re.search(r"(?im)^options itco_wdt heartbeat=90$", conf), "iTCO_wdt option missing")
        # Any path to `false` disables the module; NixOS has no /bin/false.
        require(re.search(r"(?m)^install algif_aead \S*/false$", conf), "algif_aead install rule missing")
        require(re.search(r"(?m)^blacklist joydev$", conf), "joydev blacklist missing")
        dry = g.out("modprobe -n -v algif_aead 2>&1; true")
        require(re.search(r"install \S*/false", dry), dry)
    elif name == "lockup_sysctl":
        keys = [
            "hardlockup_panic",
            "panic",
            "softlockup_panic",
            "hung_task_timeout_secs",
            "hung_task_all_cpu_backtrace",
            "hung_task_panic",
        ]
        values = g.out("; ".join(f"cat /proc/sys/kernel/{k}" for k in keys)).split()
        require(values == ["1", "30", "0", "300", "1", "1"], dict(zip(keys, values, strict=False)))
    elif name == "sleep_policy":
        states = g.out(
            "for t in hibernate hybrid-sleep suspend suspend-then-hibernate; do systemctl is-enabled $t.target; done || true"
        ).split()
        require(
            states[:2] == ["masked", "masked"]
            and all(x in ("static", "linked") for x in states[2:])
            and len(states) == 4,
            states,
        )
        action = g.out(
            "busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager IdleAction IdleActionUSec"
        )
        require(action.splitlines() == ['s "suspend"', "t 14400000000"], action)
        props = g.props("sleep.target", "Requires", "After")
        require("accel-sleep-cleanup.service" in props["Requires"].split(), props)
        require("accel-sleep-cleanup.service" in props["After"].split(), props)
    elif name == "sleep_cleanup":
        p = g.props(
            "accel-sleep-cleanup.service",
            "Type",
            "RemainAfterExit",
            "DefaultDependencies",
            "PartOf",
            "Before",
            "TimeoutStartUSec",
            "TimeoutStopUSec",
            "UnitFileState",
        )
        require(p["Type"] == "oneshot" and p["RemainAfterExit"] == "yes" and p["DefaultDependencies"] == "no", p)
        require("sleep.target" in p["PartOf"].split() and "sleep.target" in p["Before"].split(), p)
        require(p["TimeoutStartUSec"] == "1min 30s" and p["TimeoutStopUSec"] == "30s", p)
        cap = f"{FIX}/{DEV_A}/hwmon/hwmon0/power1_cap"
        # A process holding the compute device open is terminated before sleep; resume re-applies caps.
        out = g.out(
            "systemctl stop accel-sleep-cleanup.service; touch /dev/accel-compute; "
            "bash -c 'exec 3<>/dev/accel-compute; exec sleep 600' >/dev/null 2>&1 & pid=$!; sleep 1; "
            f"echo 1 > {cap}; systemctl start accel-sleep-cleanup.service; "
            "for i in $(seq 1 30); do [ -e /proc/$pid ] && ! grep -q '^State:.*[ZX]' /proc/$pid/status || break; sleep 1; done; "
            "if [ -e /proc/$pid ] && ! grep -q '^State:.*[ZX]' /proc/$pid/status; then echo HOLDER_ALIVE; fi; "
            "rm -f /dev/accel-compute; systemctl is-active accel-sleep-cleanup.service; "
            f"systemctl stop accel-sleep-cleanup.service; cat {cap}"
        ).splitlines()
        require("HOLDER_ALIVE" not in out, out)
        require(out[-2:] == ["active", "210000000"], out)
    elif name == "accel_setup":
        out = g.out(
            f"systemctl is-enabled accel-setup.service; systemctl show accel-setup.service -p Type -p RemainAfterExit; "
            f"cat {FIX}/{DEV_A}/hwmon/hwmon0/power1_cap {FIX}/{DEV_B}/hwmon/hwmon0/power1_cap "
            f"{FIX}/{DEV_A}/power/control {FIX}/{DEV_B}/power/control"
        ).split()
        require(out == ["enabled", "Type=oneshot", "RemainAfterExit=yes", "210000000", "170000000", "on", "on"], out)
    elif name == "idle_monitor":
        p = g.props("idle-check.timer", "UnitFileState", "Unit")
        timers = g.out("systemctl show idle-check.timer -p TimersMonotonic")
        require("OnBootUSec=5min" in timers and "OnUnitActiveUSec=5min" in timers, timers)
        require(g.out("systemctl is-enabled idle-check.timer") == "enabled", p)
        require(p["Unit"] == "idle-check.service", p)
        out = g.out(
            "rm -f /var/lib/node37/suspend-requested; systemctl start idle-check.service; "
            "journalctl -t idle-suspend -n 1 --no-pager -o cat; cat /tmp/network_idle_counter; "
            "test -e /var/lib/node37/suspend-requested && echo SUSPENDED; true"
        )
        match = re.search(r"Not idle: CONN_COUNT=(\d+) ", out)
        require(match and int(match.group(1)) >= 1, out)
        require("SUSPENDED" not in out and out.splitlines()[-1] == "0", out)
    elif name == "infer_unit":
        p = g.props(
            "infer-server.service",
            "LoadState",
            "ActiveState",
            "User",
            "Restart",
            "RestartUSec",
            "LimitNOFILE",
            "EnvironmentFiles",
        )
        require(p["LoadState"] == "loaded" and p["ActiveState"] == "inactive" and p["User"] == "ember", p)
        require(p["Restart"] == "on-failure" and p["RestartUSec"] == "5s" and p["LimitNOFILE"] == "1048576", p)
        require(p["EnvironmentFiles"].startswith("/etc/default/infer-server"), p)
        wants = g.props("multi-user.target", "Wants")["Wants"].split()
        require("infer-server.service" not in wants and "accel-setup.service" in wants, wants)
        require("--split 55,45" in g.out("cat /etc/default/infer-server"), "env file")
    elif name == "tool_env":
        project = tomllib.loads(g.out("cat /home/ember/accel-env/pyproject.toml"))
        require(project["project"]["requires-python"] == ">=3.10", project)
        require(
            project["project"]["dependencies"]
            == [
                "accel-sdk-devel>=7.14.0a20260523",
                "accel-sdk-device-gfx906>=7.14.0a20260523",
                "accel[devel,device-gfx906,libraries]",
                "torch>=2.12",
            ],
            project["project"],
        )
        index = project["tool"]["uv"]["index"]
        require(
            index
            == [{"name": "accel-multi-arch", "url": "https://packages.lab.invalid/whl-multi-arch/", "explicit": True}],
            index,
        )
        out = g.out(
            "stat -c %U /home/ember/accel-env/pyproject.toml; "
            "runuser -u ember -- bash -c 'source ~/accel-env/env/activate.sh && "
            'echo "$ACCEL_HOME|$ACCEL_PLATFORM|$ACCEL_ARCH|$BLAS_BACKEND_LT|${PATH%%:*}|${LD_LIBRARY_PATH%%:*}"\'; '
            "runuser -l ember -c accel-smi"
        ).splitlines()
        home = "/home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel"
        require(out[0] == "ember", out)
        require(out[1] == f"{home}|amd|gfx906|0|{home}/bin|{home}/lib", out[1])
        require(out[2:] == [f"{DEV_A} cap=210000000 busy=0", f"{DEV_B} cap=170000000 busy=0"], out)
    elif name == "metrics_agent":
        p = g.props(
            "metrics-agent.service",
            "ProtectSystem",
            "ProtectHome",
            "KeyringMode",
            "RemoveIPC",
            "LockPersonality",
            "ProtectClock",
            "ProtectHostname",
            "ProtectKernelLogs",
            "RestrictSUIDSGID",
            "Restart",
            "User",
        )
        require(
            p
            == {
                "ProtectSystem": "strict",
                "ProtectHome": "read-only",
                "KeyringMode": "private",
                "RemoveIPC": "yes",
                "LockPersonality": "yes",
                "ProtectClock": "yes",
                "ProtectHostname": "yes",
                "ProtectKernelLogs": "yes",
                "RestrictSUIDSGID": "yes",
                "Restart": "on-failure",
                "User": "probe",
            },
            p,
        )
        out = g.out(
            "pid=$(ss -Hlntp 'sport = :45876' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2); "
            "awk '/^Uid:/ {print $2}' /proc/$pid/status; id -u probe; curl -fsS http://127.0.0.1:45876/; "
            "ls -d /var/lib/metrics-agent; systemctl show metrics-agent-update.timer -p TimersCalendar -p Persistent -p RandomizedDelayUSec"
        ).splitlines()
        require(out[0] == out[1], out)
        require(out[2] == "ok" and out[3] == "/var/lib/metrics-agent", out)
        timer = out[4:]
        require(
            any(re.search(r"OnCalendar=\*-\*-\* 00:00:00", line) for line in timer)
            and "Persistent=yes" in timer
            and "RandomizedDelayUSec=4h" in timer,
            out,
        )
    elif name == "operator_sudo":
        # The operator's admin rights come from the sudo group (an Ubuntu default rule); the service user has none.
        ember = g.out("sudo -l -U ember")
        require(re.search(r"^\s*\(ALL ?: ?ALL\) (?:[A-Z]+: )*ALL\s*$", ember, re.MULTILINE), ember)
        probe = g.out("sudo -l -U probe 2>&1 || true")
        require("not allowed to run sudo" in probe, probe)
    elif name == "udev_i2c":
        # The files udev itself loads (it reports them), wherever the distro keeps them; any rule that gives
        # the i2c device nodes group i2c and mode 0660 counts, whatever its key order.
        rules = g.out(
            "files=$(udevadm test /sys/class/net/lo 2>&1 | sed -n 's/.*Reading rules file: //p'); "
            r"""test -n "$files" && cat $files | sed -e ':a' -e '/\\$/N; s/\\\n//; ta'"""
        )
        require(
            any(
                re.search(r'(KERNEL=="i2c-[^"]*"|SUBSYSTEM=="i2c-dev")', line)
                and 'GROUP="i2c"' in line
                and re.search(r'MODE="0?660"', line)
                for line in rules.splitlines()
                if not line.lstrip().startswith("#")
            ),
            "no rule gives i2c device nodes group i2c, mode 0660",
        )
    elif name == "cmdline_decoy":
        tokens = g.out("cat /proc/cmdline").split()
        require("intel_iommu=on" in tokens, f"active profile missing from {tokens}")
        for token in ("pci=noats", "pci=realloc", "nomodeset"):
            require(token not in tokens, f"{token} must not be set")
    elif name == "sysctl_decoy":
        values = g.out("cat /proc/sys/vm/swappiness /proc/sys/kernel/panic").split()
        require(values == ["60", "30"], values)
    elif name == "etc_environment":
        # Non-interactive ssh (no shell profile) and a login session of the operator both see the values.
        require(g.out("printenv ACCEL_VISIBLE_DEVICES OMP_NUM_THREADS").splitlines() == ["0,1", "8"], "ssh session")
        login = g.out("su -l ember -c 'printenv ACCEL_VISIBLE_DEVICES OMP_NUM_THREADS'").splitlines()
        require(login == ["0,1", "8"], login)
    elif name == "sysstat_timer":
        p = g.props("sysstat-collect.timer", "TimersCalendar", "ActiveState")
        require("OnCalendar=*-*-* *:*:00" in p["TimersCalendar"] and p["ActiveState"] == "active", p)
        require("00/10" not in p["TimersCalendar"], p)
    else:
        raise ValueError(name)


RECIPE_CHECKS = [
    "host_identity",
    "accounts",
    "kernel_cmdline",
    "module_policy",
    "lockup_sysctl",
    "sleep_policy",
    "sleep_cleanup",
    "accel_setup",
    "idle_monitor",
    "infer_unit",
    "tool_env",
    "metrics_agent",
    "operator_sudo",
    "udev_i2c",
]
COMPLEXIFIER_CHECKS = ["cmdline_decoy", "sysctl_decoy", "sysstat_timer", "etc_environment"]
CHECKS = RECIPE_CHECKS + COMPLEXIFIER_CHECKS
ERRORS = (
    AssertionError,
    OSError,
    KeyError,
    ValueError,
    IndexError,
    TypeError,
    subprocess.SubprocessError,
    RuntimeError,
)


def run_checks(guest):
    results = []
    for name in CHECKS:
        began = time.monotonic()
        try:
            check(name, guest)
            results.append({"name": name, "passed": True})
        except ERRORS as error:
            results.append({"name": name, "passed": False, "detail": str(error)})
        results[-1]["origin"] = "complexifier" if name in COMPLEXIFIER_CHECKS else "recipe"
        results[-1]["seconds"] = round(time.monotonic() - began, 2)
    return results


def check_reference():
    """Author-time control: the frozen reference must pass every check. Not run per trial."""
    run(["/opt/runtime/reference", "start"], timeout=150)
    try:
        reference = Guest()
        reference.ready()
        results = run_checks(reference)
    finally:
        run(["/opt/runtime/reference", "stop"], timeout=90)
    print(json.dumps(results, indent=2))
    failed = [result["name"] for result in results if not result["passed"]]
    if failed:
        raise SystemExit(f"Reference failed checks: {failed}")


def main():
    LOG.mkdir(parents=True, exist_ok=True)
    began = time.monotonic()
    try:
        build = run(["/opt/contract/build-replica"], timeout=900, check=False)
    except subprocess.TimeoutExpired:
        (LOG / "build.log").write_text("Build exceeded 900 seconds\n")
        (LOG / "reward.txt").write_text("0.0\n")
        return
    (LOG / "build.log").write_bytes(build.stdout + build.stderr)
    if build.returncode:
        (LOG / "reward.txt").write_text("0.0\n")
        return
    timing = {"build": round(time.monotonic() - began, 2)}
    scripts = sorted(Path("/app/replica-vm/bin").glob("run-*-vm"))
    if len(scripts) != 1:
        (LOG / "build.log").open("a").write(f"\nExpected one run-*-vm script, found {scripts}\n")
        (LOG / "reward.txt").write_text("0.0\n")
        return
    results = []
    with tempfile.TemporaryDirectory(prefix="node37-candidate-") as state, (LOG / "candidate.log").open("wb") as output:
        process = subprocess.Popen([scripts[0]], cwd=state, stdout=output, stderr=subprocess.STDOUT)
        try:
            candidate = Guest(candidate=True)
            began = time.monotonic()
            candidate.ready()
            timing["boot"] = round(time.monotonic() - began, 2)
            results = run_checks(candidate)
        except ERRORS as error:
            results.append({"name": "boot", "passed": False, "detail": str(error)})
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    reward = sum(1 for result in results if result["passed"] is True) / len(CHECKS)
    report = {"reward": reward, "seconds": timing, "checks": results}
    (LOG / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
    (LOG / "reward.txt").write_text(f"{reward}\n")


if __name__ == "__main__":
    check_reference() if sys.argv[1:] == ["--reference"] else main()
