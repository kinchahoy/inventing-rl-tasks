"""Resolver verifier: recipe and complexifier checks; see author/methods.md and verification.md."""

import json
import os
import secrets
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

LOG = Path("/logs/verifier")
HOST = "node23.n23.test"
API_KEY = "lab-api-key"

# Minimal stdlib DNS client. The same source runs here (through the forwarded ports) and inside
# the guest (for ACL and direct-backend checks), so both sides parse answers identically.
DNS_LIB = r'''
import random, socket, ssl, struct

TYPES = {"A": 1, "NS": 2, "CNAME": 5, "SOA": 6, "PTR": 12, "MX": 15, "TXT": 16, "AAAA": 28, "SRV": 33, "AXFR": 252, "ANY": 255}


def make_query(name, qtype, qclass=1):
    labels = b"".join(bytes([len(part)]) + part.encode() for part in name.rstrip(".").split(".") if part)
    return struct.pack(">HHHHHH", random.randrange(65536), 0x0100, 1, 0, 0, 0) + labels + b"\0" + struct.pack(">HH", TYPES[qtype], qclass)


def read_name(msg, off):
    labels, end = [], None
    while True:
        length = msg[off]
        if length == 0:
            off += 1
            break
        if length & 0xC0 == 0xC0:
            if end is None:
                end = off + 2
            off = ((length & 0x3F) << 8) | msg[off + 1]
            continue
        labels.append(msg[off + 1 : off + 1 + length].decode())
        off += 1 + length
    return ".".join(labels) + ".", (off if end is None else end)


def read_records(msg, count, off):
    records = []
    for _ in range(count):
        name, off = read_name(msg, off)
        rtype, _, ttl, rdlen = struct.unpack(">HHIH", msg[off : off + 10])
        off += 10
        rdata = msg[off : off + rdlen]
        if rtype == 1:
            data = socket.inet_ntoa(rdata)
        elif rtype in (2, 5, 12):
            data = read_name(msg, off)[0]
        elif rtype == 15:
            data = (struct.unpack(">H", rdata[:2])[0], read_name(msg, off + 2)[0])
        elif rtype == 16:
            data, i = "", 0
            while i < len(rdata):
                data += rdata[i + 1 : i + 1 + rdata[i]].decode()
                i += 1 + rdata[i]
        elif rtype == 33:
            data = struct.unpack(">3H", rdata[:6]) + (read_name(msg, off + 6)[0],)
        elif rtype == 6:
            mname, pos = read_name(msg, off)
            rname, pos = read_name(msg, pos)
            data = (mname, rname) + struct.unpack(">5I", msg[pos : pos + 20])
        else:
            data = rdata
        records.append((name, rtype, ttl, data))
        off += rdlen
    return records, off


def parse(msg):
    ident, flags, qd, an, ns, ar = struct.unpack(">6H", msg[:12])
    off = 12
    for _ in range(qd):
        off = read_name(msg, off)[1] + 4
    answers, off = read_records(msg, an, off)
    authority, off = read_records(msg, ns, off)
    return {"rcode": flags & 15, "aa": bool(flags & 0x400), "tc": bool(flags & 0x200), "ra": bool(flags & 0x80),
            "answers": answers, "authority": authority}


def udp(host, port, name, qtype, qclass=1, source=None, timeout=3):
    """Returns the parsed response, or None when nothing answers."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    if source:
        sock.bind((source, 0))
    try:
        sock.sendto(make_query(name, qtype, qclass), (host, port))
        return parse(sock.recvfrom(4096)[0])
    except socket.timeout:
        return None
    finally:
        sock.close()


def stream(sock, name, qtype):
    packet = make_query(name, qtype)
    sock.sendall(struct.pack(">H", len(packet)) + packet)
    size = struct.unpack(">H", recv_exact(sock, 2))[0]
    return parse(recv_exact(sock, size))


def recv_exact(sock, count):
    data = b""
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            raise OSError("connection closed")
        data += chunk
    return data


def tcp(host, port, name, qtype):
    with socket.create_connection((host, port), timeout=5) as sock:
        return stream(sock, name, qtype)


def axfr(host, port, name, source=None):
    """Transfers a zone; returns the first message's rcode and every record received until the closing SOA."""
    with socket.create_connection((host, port), timeout=5, source_address=(source, 0) if source else None) as sock:
        packet = make_query(name, "AXFR")
        sock.sendall(struct.pack(">H", len(packet)) + packet)
        records, rcode = [], None
        while True:
            size = struct.unpack(">H", recv_exact(sock, 2))[0]
            message = parse(recv_exact(sock, size))
            rcode = message["rcode"] if rcode is None else rcode
            records += message["answers"]
            if rcode != 0 or sum(1 for record in records if record[1] == 6) >= 2:
                return rcode, records


def dot(host, port, name, qtype, cafile, server_name):
    context = ssl.create_default_context(cafile=cafile)
    with socket.create_connection((host, port), timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname=server_name) as sock:
            return stream(sock, name, qtype), sock.version()
'''
exec(DNS_LIB)


def run(args, *, check=True, timeout=30, **kwargs):
    result = subprocess.run(args, check=False, capture_output=True, timeout=timeout, **kwargs)
    if check and result.returncode:
        detail = (result.stdout + result.stderr).decode(errors="replace")
        raise RuntimeError(f"Command {shlex.join(args)} exited {result.returncode}:\n{detail}")
    return result


def require(condition, detail):
    if not condition:
        raise AssertionError(str(detail))


class Guest:
    def __init__(self, candidate=False):
        self.ssh_port = 3222 if candidate else 2222
        self.dns_port = 9353 if candidate else 5353
        self.dot_port = 9853 if candidate else 8853

    def ssh(self, command, *, check=True, timeout=30):
        return run(
            ["/opt/runtime/guest", command],
            env=dict(os.environ, GUEST_SSH_PORT=str(self.ssh_port)),
            check=check,
            timeout=timeout,
        )

    def as_user(self, user, command, *, check=True):
        return self.ssh(f"runuser -u {user} -- sh -c {shlex.quote(command)}", check=check)

    def python(self, code):
        """Runs code in the guest with the DNS client preloaded."""
        return self.ssh("python3 -c " + shlex.quote(DNS_LIB + "\n" + code))

    def query(self, name, qtype="A"):
        response = udp("127.0.0.1", self.dns_port, name, qtype)
        require(response is not None, f"no UDP answer for {name} {qtype}")
        return response

    def api(self, port, path, *, key=API_KEY):
        header = f"-H 'X-API-Key: {key}'" if key else ""
        result = self.ssh(f"curl -s -o /dev/null -w '%{{http_code}}' {header} http://127.0.0.1:{port}{path}")
        return int(result.stdout)

    def api_json(self, port, path):
        return json.loads(self.ssh(f"curl -sf -H 'X-API-Key: {API_KEY}' http://127.0.0.1:{port}{path}").stdout)

    def ready(self):
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            if self.ssh("systemctl is-active --quiet multi-user.target", check=False).returncode == 0:
                probe = udp("127.0.0.1", self.dns_port, "app1.a23.test", "A", timeout=2)
                if probe is not None:
                    return
            time.sleep(2)
        raise RuntimeError("Guest did not reach multi-user.target with DNS answering within 180 seconds")


def answers(response, rtype):
    return [data for _, kind, _, data in response["answers"] if kind == rtype]


def check(name, guest, token):
    if name == "host_identity":
        require(guest.ssh("hostname").stdout.strip() == b"node23", "hostname")
        result = guest.ssh("getent ahostsv4 node23.n23.test").stdout.decode().splitlines()
        require(result and all(line.split()[0] == "127.0.0.1" for line in result), result)
    elif name == "accounts":
        guest.python(
            "import grp,os,pwd\nfor u,uid in [('birch',1301),('cedar',1302)]:\n"
            " p=pwd.getpwnam(u); assert (p.pw_uid,p.pw_gid,p.pw_dir,os.path.basename(p.pw_shell),grp.getgrgid(uid).gr_name)==(uid,uid,'/home/'+u,'bash',u),p"
        )
    elif name == "sudo_policy":
        rec = "/usr/bin/rec_control"
        for user, command, allowed in [
            ("birch", f"sudo -n {rec} wipe-cache {token}.a23.test$", True),
            ("birch", f"sudo -n {rec} get cache-entries", True),
            ("birch", "sudo -n /bin/sh -c true", False),
            ("cedar", f"sudo -n {rec} get cache-entries", True),
            ("cedar", f"sudo -n {rec} wipe-cache {token}.a23.test$", False),
        ]:
            result = guest.as_user(user, command, check=False)
            require((result.returncode == 0) == allowed, (user, command, result.stdout, result.stderr))
    elif name == "listeners":
        rows = [line.split() for line in guest.ssh("ss -H -lntup").stdout.decode().splitlines()]
        found = {}
        for row in rows:
            address, port = row[4].rsplit(":", 1)
            found.setdefault((row[0], port), []).append((address, row[-1]))
        expected = [
            ("udp", "53", "dnsdist", False),
            ("tcp", "53", "dnsdist", False),
            ("tcp", "853", "dnsdist", False),
            ("udp", "5353", "pdns_recursor", True),
            ("tcp", "5353", "pdns_recursor", True),
            ("udp", "5301", "nsd", True),
            ("tcp", "5301", "nsd", True),
            ("tcp", "8082", "pdns_recursor", True),
            ("tcp", "8083", "dnsdist", True),
        ]
        for proto, port, process, loopback in expected:
            sockets = found.get((proto, port), [])
            require(sockets, (proto, port, found))
            for _, owner in sockets:
                # NSD's TCP listener is held by its xfrd helper process.
                require(process in owner or (process == "nsd" and "xfrd" in owner), (proto, port, found))
            # Loopback services may also bind ::1; public ones must not be loopback-only.
            addresses = {address for address, _ in sockets}
            if loopback:
                require("127.0.0.1" in addresses and addresses <= {"127.0.0.1", "[::1]"}, (proto, port, addresses))
            else:
                require(addresses - {"127.0.0.1", "[::1]"}, (proto, port, addresses))
    elif name == "forwarded_answers":
        for host, address in [("app1", "192.0.2.11"), ("app2", "192.0.2.12"), ("ns1", "192.0.2.10")]:
            response = guest.query(f"{host}.a23.test")
            require(response["rcode"] == 0 and answers(response, 1) == [address], (host, response))
            require(response["ra"] and not response["aa"], response)
    elif name == "record_types":
        response = guest.query("www.a23.test")
        require(answers(response, 5) == ["app1.a23.test."] and answers(response, 1) == ["192.0.2.11"], response)
        require(answers(guest.query("a23.test", "MX"), 15) == [(10, "app1.a23.test.")], "MX")
        require(answers(guest.query("a23.test", "TXT"), 16) == ["v=spf1 mx -all"], "TXT")
        require(answers(guest.query("_svc._tcp.a23.test", "SRV"), 33) == [(10, 5, 8443, "app1.a23.test.")], "SRV")
        require(answers(guest.query("11.2.0.192.in-addr.arpa", "PTR"), 12) == ["app1.a23.test."], "PTR")
    elif name == "nxdomain_negative":
        response = guest.query(f"{token}.a23.test")
        require(response["rcode"] == 3 and not response["answers"], response)
        soa = [record for record in response["authority"] if record[1] == 6]
        require(soa and soa[0][0] == "a23.test.", response)
        nodata = guest.query("app1.a23.test", "AAAA")
        require(nodata["rcode"] == 0 and not nodata["answers"], nodata)
    elif name == "internal_auth_zone":
        response = guest.query("host1.i23.test")
        require(answers(response, 1) == ["10.9.0.5"], response)
        missing = guest.query(f"{token}.i23.test")
        soa = [record for record in missing["authority"] if record[1] == 6]
        require(missing["rcode"] == 3 and soa and soa[0][0] == "i23.test.", missing)  # answered from the local zone
    elif name == "extra_hosts":
        require(answers(guest.query("svc.n23.test"), 1) == ["10.20.30.40"], "svc")
        require(answers(guest.query("db.n23.test"), 1) == ["10.20.30.41"], "db")
        require(answers(guest.query("40.30.20.10.in-addr.arpa", "PTR"), 12) == ["svc.n23.test."], "PTR")
    elif name == "any_chaos_refused":
        require(guest.query("app1.a23.test", "ANY")["rcode"] == 5, "ANY not refused")
        require(udp("127.0.0.1", guest.dns_port, "version.bind", "TXT", qclass=3)["rcode"] == 5, "CHAOS not refused")
        require(guest.query("app1.a23.test")["rcode"] == 0, "plain query broken")
    elif name == "sinkhole":
        response = guest.query("blocked.a23.test")
        require(response["rcode"] == 3 and not response["answers"], response)
        require(guest.query("www.blocked.a23.test")["rcode"] == 3, "suffix not matched")
        require(answers(guest.query("app1.a23.test"), 1) == ["192.0.2.11"], "sibling name broken")
    elif name == "tcp_truncation":
        truncated = guest.query("big.a23.test", "TXT")
        require(truncated["tc"], "no TC bit for an oversized UDP answer")
        full = tcp("127.0.0.1", guest.dns_port, "big.a23.test", "TXT")
        require(not full["tc"] and sorted(answers(full, 16)) == [str(i) * 100 for i in range(1, 9)], full)
    elif name == "dot_service":
        response, version = dot("127.0.0.1", guest.dot_port, "app1.a23.test", "A", "/opt/contract/ca.crt", HOST)
        require(answers(response, 1) == ["192.0.2.11"], response)
        require(version in ("TLSv1.2", "TLSv1.3"), version)
    elif name == "acl_inside":
        out = guest.python(
            "import subprocess\n"
            "subprocess.run(['ip','addr','add','198.51.100.7/32','dev','lo'],check=True)\n"
            "try:\n"
            " for port in (53,5353):\n"
            "  denied=udp('127.0.0.1',port,'app1.a23.test','A',source='198.51.100.7',timeout=2)\n"
            "  assert denied is None or denied['rcode']==5,(port,denied)\n"
            "  ok=udp('127.0.0.1',port,'app1.a23.test','A',source='127.0.0.1',timeout=3)\n"
            "  assert ok and ok['rcode']==0 and ok['answers'],(port,ok)\n"
            "finally:\n"
            " subprocess.run(['ip','addr','del','198.51.100.7/32','dev','lo'])"
        )
        require(out.returncode == 0, out.stderr)
    elif name == "recursor_version_string":
        # Asked of the recursor itself (not through the front end): its configured version string.
        guest.python(
            "r=udp('127.0.0.1',5353,'version.bind','TXT',qclass=3)\n"
            "assert r and [d for _,k,_,d in r['answers']]==['anonymous'],r"
        )  # CONFIRM: 4.6 and 5.x both answer from version-string
    elif name == "positive_ttl_cap":
        # The authoritative TTL is 7200; the resolver caps what it hands out.
        response = guest.query("long.a23.test")
        ttl = response["answers"][0][2]
        require(
            answers(response, 1) == ["192.0.2.77"] and 3000 < ttl <= 3600, response
        )  # CONFIRM cap is applied to the first answer
        require(guest.query("app1.a23.test")["answers"][0][2] <= 300, "short TTLs must stay as is")
    elif name == "wildcard_and_cname":
        require(answers(guest.query(f"{token}.wild.a23.test"), 1) == ["192.0.2.99"], "wildcard")
        response = guest.query("ext.a23.test")
        require(answers(response, 5) == ["app2.a23.test."] and answers(response, 1) == ["192.0.2.12"], response)
    elif name == "dnsdist_cache":
        before = int(guest.api_json(8083, "/jsonstat?command=stats")["cache-hits"])
        for _ in range(2):
            guest.query(f"{token}.a23.test")
        after = int(guest.api_json(8083, "/jsonstat?command=stats")["cache-hits"])
        require(after > before, (before, after))
    elif name == "monitoring_api":
        for port, path in [(8082, "/api/v1/servers/localhost/config"), (8083, "/api/v1/servers/localhost")]:
            require(guest.api(port, path, key=None) in (401, 403), f"{port} open without credentials")
            require(guest.api(port, path) == 200, f"{port} rejects the key")
    elif name == "nsd_identity_xfr":
        guest.python(
            "ident=udp('127.0.0.1',5301,'id.server','TXT',qclass=3)\n"
            "assert ident and ident['answers'] and ident['answers'][0][3]=='node23-auth',ident\n"
            "ver=udp('127.0.0.1',5301,'version.bind','TXT',qclass=3)\n"
            "assert ver is None or not ver['answers'],ver\n"
            "assert tcp('127.0.0.1',5301,'a23.test','AXFR')['rcode']==5\n"
            "soa=udp('127.0.0.1',5301,'a23.test','SOA')\n"
            "assert soa['aa'] and soa['answers'][0][3][:3]==('ns1.a23.test.','hostmaster.a23.test.',2026110301),soa"
        )
    elif name == "zone_content":
        guest.python(
            "def a(n,t='A'): r=udp('127.0.0.1',5301,n,t); assert r and r['aa'] and r['rcode']==0,(n,r); return [d for _,k,_,d in r['answers']]\n"
            "assert a('app1.a23.test')==['192.0.2.11'] and a('app2.a23.test')==['192.0.2.12'] and a('ns1.a23.test')==['192.0.2.10']\n"
            "assert a('blocked.a23.test')==['192.0.2.66']\n"
            "assert a('a23.test','NS')==['ns1.a23.test.'] and a('11.2.0.192.in-addr.arpa','PTR')==['app1.a23.test.']\n"
            "assert a('12.2.0.192.in-addr.arpa','PTR')==['app2.a23.test.']"
        )
    elif name == "persistent_storage":
        guest.python(
            r"""import subprocess
run=lambda *a: subprocess.run(a,capture_output=True,text=True,check=True).stdout.strip()
paths=['/home/birch','/home/cedar']
for path in paths+['/var/lib']:
    fstype=run('findmnt','-n','-o','FSTYPE','-T',path)
    assert fstype not in ('tmpfs','ramfs'),(path,fstype)
covers=lambda rule,path: rule.rstrip('/')==path or path.startswith(rule.rstrip('/')+'/') or rule.startswith(path+'/')
for line in run('systemd-tmpfiles','--cat-config').splitlines():
    f=line.split()
    if len(f)<2 or f[0].startswith('#'): continue
    age=f[5] if len(f)>5 else '-'
    cleans=f[0].rstrip('!+-=~^')[:1] in 'DRre' or age not in ('-','')
    bad=[p for p in paths if cleans and covers(f[1],p)]
    assert not bad,(line,bad)"""
        )
    # Complexifier checks (CX-*, author/complexify.md); everything above comes from the original recipe.
    elif name == "negative_ttl_override":
        # The authoritative SOA TTL/minimum is 7200; the effective cap is the drop-in's 1800, not 3600
        # and not the inert leftover's 60. An open-access leftover must not have been applied either.
        response = guest.query(f"{token}.a23.test")
        ttl = [record[2] for record in response["authority"] if record[1] == 6][0]
        require(response["rcode"] == 3 and 1500 < ttl <= 1800, response)
        require(answers(guest.query("app1.a23.test"), 1) == ["192.0.2.11"], "forwarding broken")
    elif name == "local_resolver":
        for query, address in [("svc.n23.test", "10.20.30.40"), ("svc", "10.20.30.40"), ("host1.i23.test", "10.9.0.5")]:
            line = guest.ssh(f"getent ahostsv4 {query}").stdout.decode().split()
            require(line and line[0] == address, (query, line))
        resolv = guest.ssh("cat /etc/resolv.conf").stdout.decode().splitlines()
        nameservers = [line.split()[1] for line in resolv if line.startswith("nameserver")]
        require(
            nameservers[:1] == ["127.0.0.1"] and any(l.startswith("search") and "n23.test" in l for l in resolv), resolv
        )
        require(b"127.0.0.53" not in guest.ssh("ss -H -lnu").stdout, "stub listener present")
    elif name == "nsd_secondary":
        # Only the secondary's address may transfer the zone; the same request from loopback stays refused.
        guest.python(
            "import subprocess\n"
            "subprocess.run(['ip','addr','add','198.51.100.7/32','dev','lo'],check=True)\n"
            "try:\n"
            " rcode,records=axfr('127.0.0.1',5301,'a23.test',source='198.51.100.7')\n"
            " assert rcode==0 and records[0][1]==6 and records[-1][1]==6 and len(records)>2,(rcode,records[:3])\n"
            " names={r[0] for r in records}\n"
            " assert {'app1.a23.test.','app2.a23.test.','ns1.a23.test.'}<=names,names\n"
            " refused,_=axfr('127.0.0.1',5301,'a23.test')\n"
            " assert refused==5,refused\n"
            "finally:\n"
            " subprocess.run(['ip','addr','del','198.51.100.7/32','dev','lo'])"
        )
    elif name == "socket_tuning":
        values = guest.ssh(
            "cat /proc/sys/net/core/rmem_max /proc/sys/net/core/wmem_max /proc/sys/net/ipv4/ip_local_port_range"
        ).stdout.split()
        require(values == [b"8388608", b"8388608", b"10240", b"65535"], values)
        for process in ("pdns_recursor", "dnsdist"):
            limits = guest.ssh(f"grep 'Max open files' /proc/$(pgrep -xo {process})/limits").stdout.split()
            require(limits[3:5] == [b"65536", b"65536"], (process, limits))
    else:
        raise ValueError(name)


RECIPE_CHECKS = [
    "host_identity",
    "accounts",
    "sudo_policy",
    "listeners",
    "forwarded_answers",
    "record_types",
    "nxdomain_negative",
    "internal_auth_zone",
    "extra_hosts",
    "any_chaos_refused",
    "sinkhole",
    "tcp_truncation",
    "dot_service",
    "acl_inside",
    "recursor_version_string",
    "positive_ttl_cap",
    "wildcard_and_cname",
    "dnsdist_cache",
    "monitoring_api",
    "nsd_identity_xfr",
    "zone_content",
    "persistent_storage",
]
COMPLEXIFIER_CHECKS = ["negative_ttl_override", "local_resolver", "socket_tuning", "nsd_secondary"]
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
            check(name, guest, secrets.token_hex(8))
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
    # NixOS names the script after networking.hostName; a wrong hostname is scored, not a crash.
    scripts = sorted(Path("/app/replica-vm/bin").glob("run-*-vm"))
    if len(scripts) != 1:
        (LOG / "build.log").open("a").write(f"\nExpected one run-*-vm script, found {scripts}\n")
        (LOG / "reward.txt").write_text("0.0\n")
        return
    results = []
    with (
        tempfile.TemporaryDirectory(prefix="resolver-candidate-") as state,
        (LOG / "candidate.log").open("wb") as output,
    ):
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
