"""Monitoring host verifier: recipe and complexifier checks; see author/methods.md and verification.md.

Checks assert behavior and values that Prometheus 2.x/3.x, Alertmanager 0.23+ and the exporters expose
identically (HTTP APIs, series, notifications); none reads configuration syntax.
"""

import base64
import json
import os
import re
import secrets
import shlex
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

LOG = Path("/logs/verifier")
HOST = "node31.n31.test"
AUTH = "pine:pine-pass"
PROM = "http://127.0.0.1:9090"
AM = "http://127.0.0.1:9093"
SINK = "http://127.0.0.1:19190"
BASE_GROUPS = {"node_recording", "default_alerts"}


def run(args, *, check=True, timeout=30, **kwargs):
    result = subprocess.run(args, check=False, capture_output=True, timeout=timeout, **kwargs)
    if check and result.returncode:
        detail = (result.stdout + result.stderr).decode(errors="replace")
        raise RuntimeError(f"Command {shlex.join(args)} exited {result.returncode}:\n{detail}")
    return result


def require(condition, detail):
    if not condition:
        raise AssertionError(str(detail))


def poll(function, *, timeout=60, interval=2):
    """Retries function until it stops raising AssertionError; returns its value."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            return function()
        except AssertionError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(interval)


def seconds(text):
    units = {"ms": 0.001, "s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800, "y": 31536000}
    return sum(int(number) * units[unit] for number, unit in re.findall(r"(\d+)([a-z]+)", text))


def stamp(offset=0):
    return (datetime.now(timezone.utc) + timedelta(seconds=offset)).strftime("%Y-%m-%dT%H:%M:%S.000Z")


class Guest:
    def __init__(self, candidate=False):
        self.ssh_port = 3222 if candidate else 2222
        self.http_port = 3080 if candidate else 2080
        self.https_port = 3443 if candidate else 2443

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
        return self.ssh("python3 -c " + shlex.quote(code))

    def http(self, path="/", *, tls=True, auth=None, headers=None):
        scheme, guest_port, port = ("https", 443, self.https_port) if tls else ("http", 80, self.http_port)
        with tempfile.TemporaryDirectory() as directory:
            header_file = Path(directory) / "headers"
            args = ["curl", "--silent", "--show-error", "--noproxy", "*", "--max-time", "15",
                    "--cacert", "/opt/contract/ca.crt", "--connect-to", f"{HOST}:{guest_port}:127.0.0.1:{port}",
                    "-D", str(header_file)]
            if auth:
                args.extend(["-u", auth])
            for key, value in (headers or {}).items():
                args.extend(["-H", f"{key}: {value}"])
            response = run([*args, f"{scheme}://{HOST}{path}"])
            lines = header_file.read_text().splitlines()
            status = int(lines[0].split()[1])
            parsed = {k.lower(): v.strip() for line in lines[1:] if ":" in line for k, v in [line.split(":", 1)]}
            return status, parsed, response.stdout

    def get(self, url):
        return self.ssh(f"curl -sf --max-time 15 '{url}'").stdout

    def code(self, url, *, method="GET"):
        out = self.ssh(f"curl -s -o /dev/null -w '%{{http_code}}' --max-time 15 -X {method} '{url}'")
        return int(out.stdout)

    def prom(self, path):
        return json.loads(self.get(PROM + path))["data"]

    def query(self, expression):
        encoded = base64.b64encode(expression.encode()).decode()
        out = self.ssh(f"curl -sf --max-time 15 -G {PROM}/api/v1/query --data-urlencode \"query=$(echo {encoded} | base64 -d)\"")
        data = json.loads(out.stdout)["data"]["result"]
        return [(item["metric"], float(item["value"][1])) for item in data]

    def sink(self):
        return json.loads(self.get(SINK + "/received"))

    def post(self, url, payload):
        encoded = base64.b64encode(json.dumps(payload).encode()).decode()
        return self.ssh(f"echo {encoded} | base64 -d | curl -sf --max-time 15 -X POST -H 'Content-Type: application/json' --data-binary @- {url}").stdout

    def alerts(self, items):
        """Posts alerts to Alertmanager; every item is a label dict."""
        self.post(AM + "/api/v2/alerts", [{"labels": labels, "startsAt": stamp(-1)} for labels in items])

    def paths_for(self, alertname, *, status="firing"):
        found = set()
        for record in self.sink():
            body = record["body"]
            if body.get("status") == status and any(a["labels"].get("alertname") == alertname for a in body["alerts"]):
                found.add(record["path"])
        return found

    def ready(self):
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline:
            if self.ssh("systemctl is-active --quiet multi-user.target", check=False).returncode == 0:
                try:
                    status, _, _ = self.http("/healthz")
                    if status == 200:
                        return
                except (RuntimeError, ValueError, subprocess.SubprocessError):
                    pass
            time.sleep(2)
        raise RuntimeError("Guest did not reach multi-user.target with the web face up within 240 seconds")


def check(name, guest, token):
    if name == "host_identity":
        require(guest.ssh("hostname").stdout.strip() == b"node31", "hostname")
        result = guest.ssh(f"getent ahostsv4 {HOST}").stdout.decode().splitlines()
        require(result and all(line.split()[0] == "127.0.0.1" for line in result), result)
    elif name == "accounts":
        guest.python(
            "import grp,os,pwd\nfor u,uid in [('reed',1401),('sage',1402)]:\n"
            " p=pwd.getpwnam(u); assert (p.pw_uid,p.pw_gid,p.pw_dir,os.path.basename(p.pw_shell),grp.getgrgid(uid).gr_name)==(uid,uid,'/home/'+u,'bash',u),p"
        )
    elif name == "listeners":
        rows = [line.split() for line in guest.ssh("ss -H -lnt").stdout.decode().splitlines()]
        local = {row[3].rsplit(":", 1)[1]: row[3].rsplit(":", 1)[0] for row in rows}
        for port in ("9090", "9093", "9100", "9115", "19190"):
            require(local.get(port) == "127.0.0.1", (port, local))
        for port in ("80", "443"):
            require(port in local and local[port] != "127.0.0.1", (port, local))
        require("9094" not in local, "cluster listener present")
        require(b":9094" not in guest.ssh("ss -H -lnu").stdout, "cluster UDP listener present")
    elif name == "tls_and_redirect":
        status, _, body = guest.http("/healthz")  # certificate chain and name are verified by curl
        require(status == 200 and body.strip() == b"ok", (status, body))
        status, headers, _ = guest.http("/some/path?q=1", tls=False)
        require(status == 301 and headers["location"] == f"https://{HOST}/some/path?q=1", (status, headers))
    elif name == "proxy_auth":
        status, headers, _ = guest.http("/")
        require(status == 401 and headers["www-authenticate"] == 'Basic realm="node31"', (status, headers))
        require(guest.http("/", auth="pine:wrong")[0] == 401, "wrong password accepted")
        status, _, body = guest.http("/", auth=AUTH)
        require(status == 200 and body.strip() == b"node31 monitoring", (status, body))
        for path in ("/prometheus/-/healthy", "/alertmanager/-/healthy"):
            require(guest.http(path)[0] == 401, f"{path} open without credentials")
        require(guest.http("/healthz")[0] == 200, "health endpoint must stay open")
    elif name == "proxy_apis":
        status, _, body = guest.http("/prometheus/api/v1/query?query=vector(1)", auth=AUTH)
        result = json.loads(body)
        require(status == 200 and result["data"]["result"][0]["value"][1] == "1", body)
        require(guest.http("/prometheus/-/healthy", auth=AUTH)[0] == 200, "prometheus health")
        require(guest.http("/alertmanager/-/healthy", auth=AUTH)[0] == 200, "alertmanager health")
        status, _, body = guest.http("/alertmanager/api/v2/status", auth=AUTH)
        require(status == 200 and "versionInfo" in json.loads(body), body)
    elif name == "prom_flags":
        flags = guest.prom("/api/v1/status/flags")
        require(flags["web.listen-address"] == "127.0.0.1:9090", flags["web.listen-address"])
        require(seconds(flags["storage.tsdb.retention.time"]) == 730 * 3600, flags["storage.tsdb.retention.time"])
        require(flags["web.route-prefix"] == "/", flags["web.route-prefix"])
        require(flags["web.external-url"] == f"https://{HOST}/prometheus/", flags["web.external-url"])
        require(flags["web.enable-lifecycle"] == "false", flags["web.enable-lifecycle"])
        require(seconds(flags["query.timeout"]) == 90, flags["query.timeout"])
        require(guest.code(PROM + "/-/reload", method="POST") == 403, "lifecycle API must be disabled")
    elif name == "prom_targets":
        expected = {
            "prometheus": {"node31:9090": "up"},
            "alertmanager": {"node31:9093": "up"},
            "blackbox_exporter": {"node31:9115": "up"},
            "node": {"127.0.0.1:9100": "up", "127.0.0.1:9101": "down"},
            "probe_http": {"http://127.0.0.1:19190/received": "up", "https://127.0.0.1/healthz": "up"},
            "probe_auth": {"https://127.0.0.1/": "up"},
            "probe_tcp": {"127.0.0.1:443": "up", "127.0.0.1:9090": "up"},
        }

        def targets():
            active = guest.prom("/api/v1/targets?state=active")["activeTargets"]
            seen = {}
            for target in active:
                seen.setdefault(target["labels"]["job"], {})[target["labels"]["instance"]] = target
            health = {job: {i: t["health"] for i, t in instances.items()} for job, instances in seen.items()}
            require(health == expected, health)
            return seen

        seen = poll(targets, timeout=60)
        node = seen["node"]["127.0.0.1:9100"]["labels"]
        require((node["cluster"], node["role"], node["hostname"]) == ("lab", "self", "127.0.0.1"), node)
        for job, module in [("probe_http", "http_2xx"), ("probe_auth", "http_auth_required"), ("probe_tcp", "tcp_connect")]:
            for target in seen[job].values():
                require(target["scrapeUrl"].startswith(f"http://127.0.0.1:9115/probe?module={module}&target="), target["scrapeUrl"])
    elif name == "prom_rules":
        def rules():
            groups = {g["name"]: g for g in guest.prom("/api/v1/rules")["groups"]}
            require(set(groups) == BASE_GROUPS, set(groups))
            flat = {r["name"]: r for g in groups.values() for r in g["rules"]}
            require(all(r["health"] == "ok" for r in flat.values()), {n: r["health"] for n, r in flat.items()})
            return flat

        flat = poll(rules, timeout=45)
        squash = lambda text: re.sub(r"\s+", "", text)
        expected = {
            "job:up:count": ("recording", "countby(job)(up)"),
            "job:up:sum": ("recording", "sumby(job)(up)"),
            "InstanceDown": ("alerting", "up==0"),
            "ProbeFailed": ("alerting", "probe_success==0"),
            "DeadMansSwitch": ("alerting", "vector(1)"),
        }
        require({n: (r["type"], squash(r["query"])) for n, r in flat.items()} == expected, flat)
        require(flat["InstanceDown"]["duration"] == 10 and flat["ProbeFailed"]["duration"] == 30, "for durations")
        require(flat["InstanceDown"]["labels"] == {"severity": "page", "team": "ops"}, flat["InstanceDown"]["labels"])
        require(flat["ProbeFailed"]["labels"] == {"severity": "warning", "team": "ops"}, flat["ProbeFailed"]["labels"])
        require(flat["DeadMansSwitch"]["labels"] == {"severity": "info", "team": "ops"}, flat["DeadMansSwitch"]["labels"])
        require(flat["InstanceDown"]["annotations"] == {"summary": "{{ $labels.instance }} is down"}, flat["InstanceDown"])
        require(flat["job:up:count"]["labels"] == {"tier": "lab"}, flat["job:up:count"])
    elif name == "recording_rules":
        sizes = {"prometheus": 1, "alertmanager": 1, "blackbox_exporter": 1, "node": 2, "probe_http": 2, "probe_auth": 1, "probe_tcp": 2}

        def values():
            count = {m["job"]: v for m, v in guest.query("job:up:count")}
            total = {m["job"]: v for m, v in guest.query("job:up:sum")}
            require(count == {j: float(n) for j, n in sizes.items()}, count)
            require(total == {j: float(n - (1 if j == "node" else 0)) for j, n in sizes.items()}, total)
            return guest.query("job:up:count")

        require(all(m["tier"] == "lab" for m, _ in poll(values, timeout=45)), "tier label")
    elif name == "alert_pipeline":
        def firing():
            alerts = guest.prom("/api/v1/alerts")["alerts"]
            by_name = {}
            for alert in alerts:
                by_name.setdefault(alert["labels"]["alertname"], []).append(alert)
            require(set(by_name) == {"InstanceDown", "DeadMansSwitch"}, set(by_name))
            down = by_name["InstanceDown"]
            require(len(down) == 1 and down[0]["state"] == "firing", down)
            return down[0]["labels"]

        labels = poll(firing, timeout=90)
        expect = {"alertname": "InstanceDown", "instance": "127.0.0.1:9101", "job": "node", "cluster": "lab",
                  "role": "spare", "hostname": "127.0.0.1", "severity": "page", "team": "ops"}
        require(labels == expect, labels)

        def delivered():
            records = guest.sink()
            for path, alertname in [("/pager", "InstanceDown"), ("/logger", "InstanceDown"), ("/watchdog", "DeadMansSwitch")]:
                hits = [r["body"] for r in records if r["path"] == path and r["body"]["status"] == "firing"
                        and any(a["labels"]["alertname"] == alertname for a in r["body"]["alerts"])]
                require(hits, (path, [r["path"] for r in records]))
                require(hits[0]["receiver"] == path[1:], hits[0]["receiver"])
            first = next(r["body"] for r in records if r["path"] == "/pager")
            labels = first["alerts"][0]["labels"]
            require(labels["source"] == "prometheus" and labels["site"] == "node31" and "replica" not in labels, labels)
            require(not any(r["path"] in ("/ticket", "/default") for r in records), "unexpected receiver")

        poll(delivered, timeout=60)
    elif name == "sink_service":
        guest.post(f"{SINK}/probe-{token}", {"probe": token})
        records = guest.sink()
        require(any(r["path"] == f"/probe-{token}" and r["body"] == {"probe": token} for r in records), "sink did not record")
        require(guest.code(SINK + "/elsewhere") == 404, "unexpected GET path")
    elif name == "am_routing":
        names = {kind: f"Route{kind}{token}" for kind in ("warn", "page", "none")}
        guest.alerts([
            {"alertname": names["warn"], "severity": "warning", "instance": f"{token}-w"},
            {"alertname": names["page"], "severity": "page", "instance": f"{token}-p"},
            {"alertname": names["none"], "instance": f"{token}-n"},
        ])
        expected = {"warn": {"/ticket", "/logger"}, "page": {"/pager", "/logger"}, "none": {"/logger"}}
        poll(lambda: require(all(guest.paths_for(names[k]) == v for k, v in expected.items()), {k: guest.paths_for(names[k]) for k in names}), timeout=40)
        time.sleep(7)  # a full group_interval: late deliveries to other receivers would show now
        require(all(guest.paths_for(names[k]) == v for k, v in expected.items()), {k: guest.paths_for(names[k]) for k in names})
    elif name == "am_grouping":
        alert = f"Group{token}"
        guest.alerts([{"alertname": alert, "severity": "warning", "instance": f"{token}-a"},
                      {"alertname": alert, "severity": "warning", "instance": f"{token}-b"}])

        def grouped():
            hits = [r["body"] for r in guest.sink() if r["path"] == "/ticket" and r["body"]["status"] == "firing"
                    and any(a["labels"]["alertname"] == alert for a in r["body"]["alerts"])]
            require(hits, "not delivered")
            return hits

        poll(grouped, timeout=40)
        time.sleep(7)
        hits = grouped()
        require(len(hits) == 1 and sorted(a["labels"]["instance"] for a in hits[0]["alerts"]) == [f"{token}-a", f"{token}-b"], hits)
        require(hits[0]["groupLabels"] == {"alertname": alert}, hits[0]["groupLabels"])
    elif name == "am_inhibit":
        a, b, c = (f"Inh{letter}{token}" for letter in "ABC")
        guest.alerts([{"alertname": a, "severity": "page", "instance": f"{token}-x"},
                      {"alertname": b, "severity": "warning", "instance": f"{token}-x"},
                      {"alertname": c, "severity": "warning", "instance": f"{token}-y"}])
        poll(lambda: require("/pager" in guest.paths_for(a) and "/ticket" in guest.paths_for(c), "allowed paths"), timeout=40)
        time.sleep(7)
        require(guest.paths_for(b) == set(), ("inhibited warning was delivered", guest.paths_for(b)))
    elif name == "am_silence":
        silenced, other = f"SilX{token}", f"SilY{token}"
        reply = json.loads(guest.post(AM + "/api/v2/silences", {
            "matchers": [{"name": "alertname", "value": silenced, "isRegex": False, "isEqual": True}],
            "startsAt": stamp(-1), "endsAt": stamp(600), "createdBy": "probe", "comment": "verifier"}))
        guest.alerts([{"alertname": silenced, "severity": "warning", "instance": f"{token}-s"},
                      {"alertname": other, "severity": "warning", "instance": f"{token}-o"}])
        poll(lambda: require("/ticket" in guest.paths_for(other), "unsilenced alert"), timeout=40)
        time.sleep(7)
        require(guest.paths_for(silenced) == set(), "silenced alert was delivered")
        guest.code(f"{AM}/api/v2/silence/{reply['silenceID']}", method="DELETE")
    elif name == "am_resolved":
        alert = f"Res{token}"
        guest.post(AM + "/api/v2/alerts", [{"labels": {"alertname": alert, "severity": "warning", "instance": f"{token}-r"},
                                           "startsAt": stamp(-1), "endsAt": stamp(14)}])
        poll(lambda: require("/ticket" in guest.paths_for(alert), "firing notice"), timeout=30)
        poll(lambda: require("/ticket" in guest.paths_for(alert, status="resolved"), "resolved notice"), timeout=45)
    elif name == "amtool_operator":
        # Default client configuration, no flags: both operators reach the local Alertmanager.
        listing = poll(lambda: json.loads(guest.as_user("reed", "amtool alert query -o json").stdout), timeout=20)
        names = {a["labels"]["alertname"] for a in listing}
        require({"InstanceDown", "DeadMansSwitch"} <= names, names)
        silences = json.loads(guest.as_user("sage", "amtool silence query -o json").stdout or b"[]")
        require(silences is None or isinstance(silences, list), silences)
    elif name == "blackbox_modules":
        out = guest.python(
            "import json,re,urllib.parse,urllib.request,urllib.error\n"
            "def probe(target,module):\n"
            " url='http://127.0.0.1:9115/probe?'+urllib.parse.urlencode({'target':target,'module':module})\n"
            " try: text=urllib.request.urlopen(url,timeout=20).read().decode()\n"
            " except urllib.error.HTTPError as e: return [e.code,None]\n"
            " def metric(n):\n"
            "  m=re.search(r'^'+n+r' (\\S+)$',text,re.M); return m.group(1) if m else None\n"
            " return [metric('probe_success'),metric('probe_http_status_code')]\n"
            "cases=[('http://127.0.0.1:19190/received','http_2xx'),('https://127.0.0.1/healthz','http_2xx'),('https://127.0.0.1/','http_2xx'),"
            "('https://127.0.0.1/','http_auth_required'),('https://127.0.0.1/healthz','http_auth_required'),"
            "('127.0.0.1:443','tcp_connect'),('127.0.0.1:9','tcp_connect'),('127.0.0.1:443','tcp_tls'),('127.0.0.1:9090','tcp_tls'),"
            "('http://127.0.0.1/','no_such_module')]\n"
            "print(json.dumps([[t,m]+probe(t,m) for t,m in cases]))"
        )
        results = {(t, m): (s, c) for t, m, s, c in json.loads(out.stdout)}  # (probe_success or HTTP error code, status code)
        want = {
            ("http://127.0.0.1:19190/received", "http_2xx"): "1", ("https://127.0.0.1/healthz", "http_2xx"): "1",
            ("https://127.0.0.1/", "http_2xx"): "0", ("https://127.0.0.1/", "http_auth_required"): "1",
            ("https://127.0.0.1/healthz", "http_auth_required"): "0", ("127.0.0.1:443", "tcp_connect"): "1",
            ("127.0.0.1:9", "tcp_connect"): "0", ("127.0.0.1:443", "tcp_tls"): "1", ("127.0.0.1:9090", "tcp_tls"): "0",
        }
        require({k: results[k][0] for k in want} == want, results)
        require(results[("https://127.0.0.1/", "http_auth_required")][1] == "401", results)
        require(results[("http://127.0.0.1/", "no_such_module")][0] == 400, results)
    elif name == "probe_series":
        def series():
            values = {(m["job"], m["instance"]): v for m, v in guest.query("probe_success")}
            require(values == {
                ("probe_http", "http://127.0.0.1:19190/received"): 1.0, ("probe_http", "https://127.0.0.1/healthz"): 1.0,
                ("probe_auth", "https://127.0.0.1/"): 1.0, ("probe_tcp", "127.0.0.1:443"): 1.0,
                ("probe_tcp", "127.0.0.1:9090"): 1.0}, values)

        poll(series, timeout=45)
    elif name == "node_collectors":
        text = guest.get("http://127.0.0.1:9100/metrics").decode()
        for present in ("node_load1 ", "node_systemd_unit_state{", "node_processes_state{", 'node_scrape_collector_success{collector="cpu"} 1'):
            require(present in text, present)
        require("node_timex_offset_seconds" not in text, "timex collector must be disabled")
    elif name == "persistent_storage":
        path = guest.prom("/api/v1/status/flags")["storage.tsdb.path"]
        guest.python(
            r"""import subprocess
run=lambda *a: subprocess.run(a,capture_output=True,text=True,check=True).stdout.strip()
paths=[%r,'/home/reed','/home/sage']
for path in paths:
    fstype=run('findmnt','-n','-o','FSTYPE','-T',path)
    assert fstype not in ('tmpfs','ramfs'),(path,fstype)
covers=lambda rule,path: rule.rstrip('/')==path or path.startswith(rule.rstrip('/')+'/') or rule.startswith(path+'/')
for line in run('systemd-tmpfiles','--cat-config').splitlines():
    f=line.split()
    if len(f)<2 or f[0].startswith('#'): continue
    age=f[5] if len(f)>5 else '-'
    cleans=f[0].rstrip('!+-=~^')[:1] in 'DRre' or age not in ('-','')
    bad=[p for p in paths if cleans and covers(f[1],p)]
    assert not bad,(line,bad)""" % path
        )
    # Complexifier checks (CX-*, author/complexify.md); everything above comes from the original recipe.
    elif name == "rules_glob":
        groups = {g["name"] for g in guest.prom("/api/v1/rules")["groups"]}
        require(groups == BASE_GROUPS, groups)
        require(all(a["labels"]["alertname"] != "StagedNoisy" for a in guest.prom("/api/v1/alerts")["alerts"]), "staged alert active")
        require(guest.paths_for("StagedNoisy") == set(), "staged alert delivered")
    elif name == "sd_drop":
        def dropped():
            data = guest.prom("/api/v1/targets")
            gone = [t for t in data["droppedTargets"] if t["discoveredLabels"].get("__address__") == "127.0.0.1:9102"]
            require(gone and gone[0]["discoveredLabels"]["decommissioned"] == "true", "retired target not dropped")
            require(all(t["labels"]["instance"] != "127.0.0.1:9102" for t in data["activeTargets"]), "retired target scraped")

        poll(dropped, timeout=30)
    elif name == "textfile_timer":
        def metrics():
            text = guest.get("http://127.0.0.1:9100/metrics").decode()
            require("node31_inventory_users 2\n" in text and 'node31_inventory_info{role="monitor"} 1\n' in text, "textfile metrics")

        poll(metrics, timeout=30)
        poll(lambda: require([v for _, v in guest.query('node31_inventory_users{job="node",role="self"}')] == [2.0], "not scraped"), timeout=30)
        timers = guest.ssh("systemctl list-timers --all --no-legend").stdout.decode()
        require("node31-inventory" in timers, timers)
        timer = guest.ssh("systemctl show node31-inventory.timer -p TimersMonotonic --value").stdout.decode()
        require("OnUnitActiveUSec=1min" in timer and "OnBootUSec=5s" in timer, timer)
    else:
        raise ValueError(name)


RECIPE_CHECKS = [
    "host_identity",
    "accounts",
    "listeners",
    "tls_and_redirect",
    "proxy_auth",
    "proxy_apis",
    "prom_flags",
    "prom_targets",
    "prom_rules",
    "recording_rules",
    "alert_pipeline",
    "sink_service",
    "am_routing",
    "am_grouping",
    "am_inhibit",
    "am_silence",
    "am_resolved",
    "amtool_operator",
    "blackbox_modules",
    "probe_series",
    "node_collectors",
    "persistent_storage",
]
COMPLEXIFIER_CHECKS = ["rules_glob", "sd_drop", "textfile_timer"]
CHECKS = RECIPE_CHECKS + COMPLEXIFIER_CHECKS
ERRORS = (AssertionError, OSError, KeyError, ValueError, IndexError, TypeError, subprocess.SubprocessError, RuntimeError)


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
    with tempfile.TemporaryDirectory(prefix="node31-candidate-") as state, (LOG / "candidate.log").open("wb") as output:
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
