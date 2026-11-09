"""File-server verifier: recipe checks only; see author/methods.md and verification.md.

Checks run inside the guest with its own Samba tools (`testparm`, `smbclient`, `smbpasswd`) as the
share users. Values come from the recipe; `# CONFIRM` marks anything to confirm on the frozen
reference. Not yet run (first draft): run `mise run check-reference node41-reconstruction-easy` first.
"""

import json
import os
import re
import secrets
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

LOG = Path("/logs/verifier")
PW = "lab-secret-1"  # fixture password; the verifier sets it, the replica never needs it
SHARES = {"fast": "/srv/fast", "docs": "/srv/docs", "vault": "/srv/docs/vault"}
ALL_SHARES = {**SHARES, "bulk": "/mnt/pool/bulk"}  # bulk lives on the USB array


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



def testparm(g):
    """Effective Samba config including defaults: {section: {key: value}}, keys lowercased."""
    sections, current = {}, None
    for line in g.out("testparm -sv 2>/dev/null").splitlines():
        if m := re.fullmatch(r"\[(.+)\]", line.strip()):
            current = sections.setdefault(m[1].lower(), {})
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            current[key.strip().lower()] = value.strip()
    return sections


def words(value):
    return [w for w in re.split(r"[\s,]+", value) if w]


def boolean(value):
    return {"true": "yes", "1": "yes", "false": "no", "0": "no"}.get(value.lower(), value.lower())


def smb_users(g):
    """Gives the share accounts a Samba password; accounts must already exist as Unix users."""
    if getattr(g, "smb_ready", False):
        return
    for user in ("rowan", "sage", "visitor"):
        g.ssh(f"printf '{PW}\\n{PW}\\n' | smbpasswd -s -a {user}")
    g.smb_ready = True


def smb(g, share, user, cmd, password=PW):
    auth = f"-U {user}%{password}" if user else "-N"
    return g.out(f"smbclient //127.0.0.1/{share} {auth} -c {shlex.quote(cmd)} 2>&1; true")


def listed(output, name):
    return re.search(rf"^\s*{re.escape(name)}\s", output, re.M) is not None


def usable(output):
    return "blocks available" in output  # printed by a successful `ls`


def check(name, g):
    if name == "array_automount":
        # Must run first: nothing may have touched the path yet.
        p = g.props("mnt-pool.automount", "ActiveState", "Where", "TimeoutIdleUSec")
        require(p["ActiveState"] == "active" and p["Where"] == "/mnt/pool" and p["TimeoutIdleUSec"] == "10min", p)  # CONFIRM
        before = g.out("findmnt -n -o FSTYPE --mountpoint /mnt/pool").split()
        require(before == ["autofs"], f"mounted before access: {before}")
        g.ssh("ls /mnt/pool >/dev/null")  # trigger
        after = g.out("findmnt -n -o FSTYPE --mountpoint /mnt/pool").split()
        require(after[-1:] == ["btrfs"], f"access did not mount the array: {after}")
    elif name == "host_identity":
        host, zone = g.out("hostname; timedatectl show -p Timezone --value").splitlines()
        require(host == "node41", host)
        require(zone == "America/Los_Angeles", zone)
    elif name == "accounts":
        for user, uid in (("quill", 1000), ("rowan", 1001), ("sage", 1002), ("visitor", 1004)):
            f = g.out(f"getent passwd {user}").split(":")
            require(f[2:4] == [str(uid), str(uid)] and f[5] == f"/home/{user}" and f[6].endswith("bash"), f)
        group = g.out("getent group shared").split(":")
        require(group[2] == "1003" and set(group[3].split(",")) == {"quill", "rowan", "sage"}, group)
        for user, expected in (("quill", {"quill", "shared"}), ("rowan", {"rowan", "shared"}), ("visitor", {"visitor"})):
            groups = set(g.out(f"id -nG {user}").split())
            require(groups == expected, (user, groups))
    elif name == "share_dirs":
        out = g.out("stat -c '%n %U:%G:%a' " + " ".join(SHARES.values())).splitlines()
        require(out == [f"{p} quill:shared:2775" for p in SHARES.values()], out)  # CONFIRM mode on reference
        fstypes = g.out("; ".join(f"findmnt -T {p} -no FSTYPE" for p in SHARES.values())).split()
        require(len(fstypes) == 3 and "tmpfs" not in fstypes, fstypes)
    elif name == "smb_global":
        conf = testparm(g).get("global", {})
        expected = {
            "security": "user",
            "server min protocol": "smb3",
            "map to guest": "never",
            "server multi channel support": "yes",
            "usershare max shares": "0",  # compared as text, not boolean
            "fruit:aapl": "yes",
            "fruit:metadata": "stream",
            "fruit:resource": "file",
            "fruit:encoding": "native",
            "fruit:nfs_aces": "no",
            "fruit:zero_file_id": "yes",
        }
        got = {k: conf.get(k, "<unset>") if k == "usershare max shares" else boolean(conf.get(k, "<unset>")) for k in expected}
        require(got == expected, got)
        require(words(conf.get("vfs objects", "")) == ["catia", "fruit", "streams_xattr"], conf.get("vfs objects"))
        require(words(conf.get("hosts allow", "")) == ["127.0.0.1", "192.0.2.0/24", "100.64.0.0/10"], conf.get("hosts allow"))
        require(words(conf.get("hosts deny", "")) == ["0.0.0.0/0"], conf.get("hosts deny"))
    elif name == "smb_shares":
        sections = testparm(g)
        require(set(sections) - {"global"} == set(ALL_SHARES), sorted(sections))
        for share, path in ALL_SHARES.items():
            conf = sections[share]
            require(conf.get("path") == path, (share, conf.get("path")))
            require(words(conf.get("valid users", "")) == ["@shared"], (share, conf.get("valid users")))
            require(conf.get("force user") == "quill" and conf.get("force group") == "shared", share)
            require(boolean(conf.get("read only", "")) == "no", (share, conf.get("read only")))
            modes = {k: int(conf.get(k, "x") if conf.get(k, "x").isdigit() else "-1", 8)
                     for k in ("create mask", "force create mode", "directory mask", "force directory mode")}
            require(modes == {"create mask": 0o660, "force create mode": 0o660,
                              "directory mask": 0o2770, "force directory mode": 0o2770}, (share, modes))  # CONFIRM octal rendering
            require(boolean(conf.get("fruit:time machine", "no")) == ("yes" if share == "vault" else "no"), share)
        require(sections["docs"].get("veto files") == "/vault/", sections["docs"].get("veto files"))
        # testparm lists only non-default values per share; fall back to the global (default) entry.
        dvf = sections["docs"].get("delete veto files", sections["global"].get("delete veto files", ""))
        require(boolean(dvf) == "no", dvf)
    elif name == "share_list":
        smb_users(g)
        out = g.out(f"smbclient -L 127.0.0.1 -U rowan%{PW} -g 2>/dev/null; true")
        disks = {line.split("|")[1] for line in out.splitlines() if line.startswith("Disk|")}
        require(disks == set(ALL_SHARES), out)
    elif name == "share_write_ownership":
        smb_users(g)
        name_ = f"t{secrets.token_hex(4)}.txt"
        try:
            put = smb(g, "fast", "rowan", f"put /etc/os-release {name_}")
            require("NT_STATUS" not in put, put)
            # force user / force group / create mode, whoever the client is.
            owner = g.out(f"stat -c '%U:%G:%a' /srv/fast/{name_}")
            require(owner == "quill:shared:660", owner)
            got = smb(g, "fast", "sage", f"get {name_} /tmp/{name_}.out")
            require("NT_STATUS" not in got, got)
            require(g.ssh(f"cmp /etc/os-release /tmp/{name_}.out", check=False).returncode == 0, "content differs")
        finally:
            g.ssh(f"rm -f /srv/fast/{name_} /tmp/{name_}.out", check=False)
    elif name == "new_dir_modes":
        smb_users(g)
        d = f"d{secrets.token_hex(4)}"
        try:
            out = smb(g, "vault", "sage", f"mkdir {d}")
            require("NT_STATUS" not in out, out)
            stat = g.out(f"stat -c '%U:%G:%a' /srv/docs/vault/{d}")
            require(stat == "quill:shared:2770", stat)  # CONFIRM setgid bit survives force directory mode
        finally:
            g.ssh(f"rmdir /srv/docs/vault/{d}", check=False)
    elif name == "share_access":
        smb_users(g)
        require(usable(smb(g, "fast", "rowan", "ls")), "member refused")
        outsider = smb(g, "fast", "visitor", "ls")
        require("NT_STATUS_ACCESS_DENIED" in outsider and not usable(outsider), outsider)
        wrong = smb(g, "fast", "rowan", "ls", password="wrong")
        require("NT_STATUS_LOGON_FAILURE" in wrong and not usable(wrong), wrong)
        anon = smb(g, "fast", None, "ls")
        require("NT_STATUS" in anon and not usable(anon), anon)
    elif name == "veto_nested":
        smb_users(g)
        mark = f"m{secrets.token_hex(4)}.txt"
        try:
            require("NT_STATUS" not in smb(g, "vault", "rowan", f"put /etc/os-release {mark}"), "vault share write refused")
            require(g.ssh(f"test -f /srv/docs/vault/{mark}", check=False).returncode == 0, "write missing on disk")
            require(listed(smb(g, "vault", "rowan", "ls"), mark), "not listed in own share")
            top = smb(g, "docs", "rowan", "ls")
            require(usable(top), top)
            require(not listed(top, "vault"), "vault visible through docs")
            inside = smb(g, "docs", "rowan", f"ls vault\\*")
            require(not listed(inside, mark) and "NT_STATUS" in inside, inside)
        finally:
            g.ssh(f"rm -f /srv/docs/vault/{mark}", check=False)
    elif name == "smb_listeners":
        tcp = g.out("ss -H -ltnp")
        for port in (139, 445):
            require(any(f":{port} " in line and '"smbd"' in line for line in tcp.splitlines()), f"smbd not on {port}")
        udp = g.out("ss -H -lunp")
        for port in (137, 138):
            require(any(f":{port} " in line and '"nmbd"' in line for line in udp.splitlines()), f"nmbd not on {port}")
    elif name == "forwarding_sysctl":
        values = g.out("cat /proc/sys/net/ipv4/ip_forward /proc/sys/net/ipv6/conf/all/forwarding").split()
        require(values == ["1", "1"], values)
    elif name == "power_unit":
        p = g.props("powertop.service", "Type", "RemainAfterExit", "ExecStart")
        require(p["Type"] == "oneshot" and p["RemainAfterExit"] == "yes", p)
        argv = re.search(r"argv\[\]=([^;]+)", p["ExecStart"])
        require(argv is not None, p["ExecStart"])
        args = argv[1].split()
        require(Path(args[0]).name == "powertop" and args[1:] == ["--auto-tune"], args)
        wants = g.props("multi-user.target", "Wants")["Wants"].split()
        require("powertop.service" in wants, "not enabled")  # CONFIRM Wants lists enabled units on both distros
    elif name == "array_mount":
        line = g.out("findmnt -n -o FSTYPE,OPTIONS --mountpoint /mnt/pool | tail -n 1")
        fstype, options = line.split(None, 1)
        opts = options.split(",")
        require(fstype == "btrfs", line)
        for opt in ("noatime", "compress=zstd:3"):
            require(opt in opts, (opt, opts))
        require("subvol=/data" in opts or "subvol=data" in opts, opts)  # CONFIRM findmnt rendering
        mount = g.props("mnt-pool.mount", "TimeoutUSec")
        require(mount["TimeoutUSec"] == "30s", mount)  # CONFIRM
        df = g.out("btrfs filesystem df /mnt/pool")
        require(re.search(r"^Data, RAID1:", df, re.M) and re.search(r"^Metadata, RAID1:", df, re.M), df)  # CONFIRM
        show = g.out("btrfs filesystem show /mnt/pool")
        require("Total devices 2" in show and "Label: 'pool'" in show, show)
    elif name == "array_share":
        smb_users(g)
        name_ = f"a{secrets.token_hex(4)}.txt"
        try:
            require("NT_STATUS" not in smb(g, "bulk", "sage", f"put /etc/os-release {name_}"), "bulk write refused")
            out = g.out(f"stat -c '%U:%G:%a' /mnt/pool/bulk/{name_}; stat -f -c %T /mnt/pool/bulk/{name_}; stat -c %U:%G:%a /mnt/pool/bulk").splitlines()
            require(out == ["quill:shared:660", "btrfs", "quill:shared:2775"], out)
            require(boolean("yes") == "yes" and listed(smb(g, "bulk", "rowan", "ls"), name_), "not visible to another member")
            denied = smb(g, "bulk", "visitor", "ls")
            require("NT_STATUS_ACCESS_DENIED" in denied and not usable(denied), denied)
        finally:
            g.ssh(f"rm -f /mnt/pool/bulk/{name_}", check=False)
    else:
        raise AssertionError(f"unknown check {name}")


RECIPE_CHECKS = [
    "array_automount",  # first: the path must be untouched
    "host_identity",
    "accounts",
    "share_dirs",
    "smb_global",
    "smb_shares",
    "share_list",
    "share_write_ownership",
    "new_dir_modes",
    "share_access",
    "veto_nested",
    "array_mount",
    "array_share",
    "smb_listeners",
    "forwarding_sysctl",
    "power_unit",
]
COMPLEXIFIER_CHECKS = []
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
    with tempfile.TemporaryDirectory(prefix="node41-candidate-") as state, (LOG / "candidate.log").open("wb") as output:
        for disk in ("usb-a.img", "usb-b.img"):  # fresh fixture copies, attached from the working directory
            run(["cp", "--sparse=always", f"/opt/contract/{disk}", f"{state}/{disk}"])
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
