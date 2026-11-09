"""Node17 verifier: recipe and complexifier checks; see author/methods.md and verification.md."""

import base64
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
USERS = ("amber", "cobalt")


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
        self.http_port = 9080 if candidate else 8080
        self.https_port = 9443 if candidate else 8443

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

    def install(self, user, relative, content, *, executable=False):
        path = f"/home/{user}/public_html/{relative}"
        payload = base64.b64encode(content.encode()).decode()
        self.ssh(
            f"install -d -m 0755 -o {user} -g {user} {shlex.quote(str(Path(path).parent))}; "
            f"printf %s {payload} | base64 -d > {shlex.quote(path)}; "
            f"chown {user}:{user} {shlex.quote(path)}; chmod {'0755' if executable else '0644'} {shlex.quote(path)}"
        )

    def http(self, path="/", *, host="node.test", tls=True, headers=None):
        scheme, guest_port, port = ("https", 443, self.https_port) if tls else ("http", 80, self.http_port)
        with tempfile.TemporaryDirectory() as directory:
            header_file = Path(directory) / "headers"
            args = [
                "curl",
                "--silent",
                "--show-error",
                "--noproxy",
                "*",
                "--max-time",
                "15",
                "--cacert",
                "/opt/contract/ca.crt",
                "--connect-to",
                f"{host}:{guest_port}:127.0.0.1:{port}",
                "-D",
                str(header_file),
            ]
            for key, value in (headers or {}).items():
                args.extend(["-H", f"{key}: {value}"])
            response = run([*args, f"{scheme}://{host}{path}"])
            lines = header_file.read_text().splitlines()
            status = int(lines[0].split()[1])
            parsed = {
                key.lower(): value.strip() for line in lines[1:] if ":" in line for key, value in [line.split(":", 1)]
            }
            return status, parsed, response.stdout

    def php(self, user, token, code, *, headers=None):
        name = f"probe-{token}.php"
        self.install(user, name, '<?php header("Content-Type: application/json"); ' + code)
        status, _, body = self.http("/" + name, host=f"{user}.node.test", headers=headers)
        require(status == 200, (status, body.decode(errors="replace")))
        return json.loads(body)

    def ready(self):
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            result = self.ssh("systemctl is-active --quiet multi-user.target", check=False)
            # multi-user.target can be active while units such as httpd are still starting;
            # wait until no boot jobs remain so checks see the settled system.
            if result.returncode == 0 and not self.ssh("systemctl list-jobs --no-legend", check=False).stdout.strip():
                return
            time.sleep(2)
        raise RuntimeError("Guest did not settle (multi-user.target active, no pending jobs) within 180 seconds")


def check(name, guest, token):
    if name == "host_resolution":
        require(guest.ssh("hostname").stdout.strip() == b"node17", "hostname")
        for host in ["catalog.node.test", "sql.node.test", "cache.node.test"]:
            result = guest.ssh(f"getent ahostsv4 {host}").stdout.decode().splitlines()
            require(result and all(line.split()[0] == "127.0.0.1" for line in result), host)
    elif name == "accounts":
        guest.python(
            "import grp,os,pwd\nfor u,uid,gid in [('amber',1101,1000),('cobalt',1102,1001)]:\n p=pwd.getpwnam(u); assert (p.pw_uid,p.pw_gid,p.pw_dir,os.path.basename(p.pw_shell),grp.getgrgid(gid).gr_name)==(uid,gid,'/home/'+u,'bash',u),p"
        )
    elif name == "filesystem_ownership":
        guest.python(
            "import os,pwd,stat;\nfor u in ('amber','cobalt'):\n for sub,mode in [('',0o755),('public_html',0o755),('public_html/cgi-bin',0o755),('public_html/wsgi-bin',0o755),('private',0o700),('private/token',0o600)]:\n  p='/home/'+u+'/'+sub; s=os.stat(p); assert pwd.getpwuid(s.st_uid).pw_name==u and stat.S_IMODE(s.st_mode)==mode,p"
        )
    elif name == "private_isolation":
        for user, other in [("amber", "cobalt"), ("cobalt", "amber")]:
            require(
                guest.as_user(user, f"cat /home/{user}/private/token").stdout.strip() == f"{user}-private".encode(),
                user,
            )
            require(
                guest.as_user(user, f"cat /home/{other}/private/token", check=False).returncode != 0,
                "cross-user private read",
            )
    elif name == "sudo_log_policy":
        for user, other in [("amber", "cobalt"), ("cobalt", "amber")]:
            guest.http("/", host=f"{user}.node.test")
            allowed = guest.as_user(user, f"sudo -n -g adm /bin/cat /var/log/web/{user}-access.log")
            require(bool(allowed.stdout), "own log empty")
            denied = guest.as_user(user, f"sudo -n -g adm /bin/cat /var/log/web/{other}-access.log", check=False)
            require(denied.returncode != 0, "sudo read other log")
            require(
                guest.as_user(user, f"cat /var/log/web/{user}-access.log", check=False).returncode != 0,
                "direct log read allowed",
            )
    elif name == "slice_limits":
        guest.python(
            "import os,pwd,subprocess; uid=pwd.getpwnam('amber').pw_uid; unit=f'user-{uid}.slice'; subprocess.run(['systemctl','start',unit],check=True); total=os.sysconf('SC_PHYS_PAGES')*os.sysconf('SC_PAGE_SIZE');\nfor prop,ratio in [('MemoryHigh',.8),('MemoryMax',.9)]:\n value=int(subprocess.check_output(['systemctl','show',unit,'--property='+prop,'--value'])); assert abs(value/total-ratio)<.01,(prop,value,total)"
        )
    elif name == "postgres_peer":
        for user in USERS:
            require(
                guest.as_user(user, f'psql -X -tAc "SELECT current_user,current_database()" {user}').stdout.strip()
                == f"{user}|{user}".encode(),
                user,
            )
    elif name == "postgres_password":
        for user in USERS:
            query = f'psql -X -h catalog.node.test -U {user} -d {user} -tAc "SELECT current_user"'
            require(guest.ssh(f"PGPASSWORD={user}-pass {query}").stdout.strip() == user.encode(), user)
            require(
                guest.ssh(f"PGPASSWORD=wrong {query}", check=False).returncode != 0, "bad postgres password accepted"
            )
        stored = guest.ssh(
            "cd / && runuser -u postgres -- psql -X -tAc \"SELECT rolname||':'||left(rolpassword,14) FROM pg_authid WHERE rolname IN ('amber','cobalt') ORDER BY 1\""
        ).stdout.split()
        require(stored == [b"amber:SCRAM-SHA-256$", b"cobalt:SCRAM-SHA-256$"], stored)
    elif name == "postgres_isolation":
        for user, other in [("amber", "cobalt"), ("cobalt", "amber")]:
            require(guest.as_user(user, f'psql -X -d {user} -tAc "SELECT 1"').stdout.strip() == b"1", "own database")
            require(
                guest.as_user(user, f'psql -X -d {other} -tAc "SELECT 1"', check=False).returncode != 0,
                "cross-database connect",
            )
    elif name == "postgis":
        for user in USERS:
            result = guest.as_user(user, f'psql -X -d {user} -tAc "SELECT ST_Distance(ST_Point(0,0),ST_Point(3,4))"')
            require(float(result.stdout) == 5, result.stdout)
    elif name == "mysql_root_socket":
        require(
            guest.ssh('mysql -Nse "SELECT CURRENT_USER()"').stdout.strip() == b"root@localhost",
            "root socket SQL identity",
        )
    elif name == "mysql_password":
        for user in USERS:
            command = f'mysql --protocol=TCP -h sql.node.test -u {user} -p{user}-pass -Nse "SELECT DATABASE()" {user}'
            require(guest.ssh(command).stdout.strip() == user.encode(), user)
            require(
                guest.ssh(command.replace(f"-p{user}-pass", "-pwrong"), check=False).returncode != 0,
                "bad SQL password accepted",
            )
    elif name == "mysql_isolation":
        for user, other in [("amber", "cobalt"), ("cobalt", "amber")]:
            guest.ssh(f'mysql --protocol=TCP -h sql.node.test -u {user} -p{user}-pass -Nse "SHOW TABLES" {user}')
            result = guest.ssh(
                f'mysql --protocol=TCP -h sql.node.test -u {user} -p{user}-pass -Nse "SHOW TABLES" {other}', check=False
            )
            require(result.returncode != 0, "cross-user SQL database access")
    elif name == "cache_protocol":
        guest.python(
            f"import socket; s=socket.create_connection(('cache.node.test',11211)); s.sendall(b'set {token} 0 30 1\\r\\n7\\r\\n'); assert s.recv(1024)==b'STORED\\r\\n'; s.sendall(b'incr {token} 2\\r\\n'); assert s.recv(1024)==b'9\\r\\n'; s.sendall(b'get {token}\\r\\n'); f=s.makefile('rb'); assert f.readline()==b'VALUE {token} 0 1\\r\\n' and f.readline()==b'9\\r\\n' and f.readline()==b'END\\r\\n'"
        )
    elif name == "loopback_services":
        listeners, _, cache_users = (
            guest.ssh("ss -H -lntup; echo; ps -o user= -C memcached").stdout.decode().partition("\n\n")
        )
        for port in (5432, 3306, 11211):
            lines = [line for line in listeners.splitlines() if f":{port} " in line]
            require(
                lines
                and all(
                    line.startswith("tcp") and line.split()[4] in (f"127.0.0.1:{port}", f"[::1]:{port}")
                    for line in lines
                ),
                (port, lines),
            )
        require(cache_users.split() and "root" not in cache_users.split(), ("memcached user", cache_users))
    elif name == "server_tuning":
        # Effective config, read through each running daemon's own binary: layout-agnostic shortcuts.
        guest.python(
            r"""import os,re,socket,subprocess
procs={}
for pid in filter(str.isdigit,os.listdir('/proc')):
    try: procs[pid]=(open(f'/proc/{pid}/cmdline','rb').read().split(b'\0'),os.readlink(f'/proc/{pid}/exe'),open(f'/proc/{pid}/stat').read().split()[3])
    except OSError: pass
pools={}
for pid,(argv,exe,ppid) in procs.items():
    m=re.match(rb'php-fpm: master process \((.+)\)',argv[0])
    if not m: continue
    pool=None
    for line in subprocess.run([exe,'-tt','-y',m.group(1).decode()],capture_output=True,text=True).stderr.splitlines():
        m=re.search(r'NOTICE\]?:?(.*)$',line)
        if not m: continue
        line=m.group(1).strip()
        if re.fullmatch(r'\[[\w-]+\]',line): pool=line[1:-1]; pools.setdefault(pool,{})
        elif pool and ' = ' in line: k,v=line.split(' = ',1); pools[pool][k.strip()]=v.strip()
pools.pop('global',None)
assert sorted(pools)==['amber','cobalt'],sorted(pools)
want={'pm':'dynamic','pm.max_children':'10','pm.start_servers':'2','pm.min_spare_servers':'1','pm.max_spare_servers':'3','pm.max_requests':'10000','request_terminate_timeout':'180s'}
for u in pools:
    got={k:pools[u].get(k) for k in want}; assert got==want,(u,got)
masters=[(pid,argv,exe) for pid,(argv,exe,ppid) in procs.items() if os.path.basename(exe) in ('apache2','httpd') and procs.get(ppid,(0,''))[1]!=exe]
assert len(masters)==1,masters
pid,argv,exe=masters[0]
args=[a.decode() for a in argv[1:] if a and a not in (b'-DFOREGROUND',b'-k',b'start')]
env=dict(e.decode().split('=',1) for e in open(f'/proc/{pid}/environ','rb').read().split(b'\0') if b'=' in e)
dump=subprocess.run([exe,*args,'-t','-D','DUMP_INCLUDES'],capture_output=True,text=True,env=env).stdout
files=re.findall(r'\)\s+(/\S+)',dump)
values=[v for f in files for v in re.findall(r'(?mi)^\s*ProxyTimeout\s+(\S+)',open(f).read())]
assert files and set(values)=={'90'},(len(files),values)
s=socket.create_connection(('127.0.0.1',11211)); s.sendall(b'stats settings\r\nquit\r\n'); data=b''
while not data.endswith(b'END\r\n'): data+=s.recv(65536)
stats=dict(l.split()[1:3] for l in data.decode().splitlines() if l.startswith('STAT '))
assert (stats['maxbytes'],stats['udpport'])==('33554432','0'),stats"""
        )
    elif name == "userdir_redirect":
        for user in USERS:
            status, headers, _ = guest.http(f"/~{user}/example?x=1")
            require(
                status == 307 and headers.get("location") == f"https://{user}.node.test/example?x=1", (status, headers)
            )
        require(guest.http("/~no-such-user/example")[0] == 404, "unknown user redirect")
    elif name == "tls_aliases":
        for host in [
            "node.test",
            "node.alt.test",
            *[f"{u}.node{suffix}.test" for u in USERS for suffix in ["", ".alt"]],
        ]:
            label = host.split(".")[0]
            want = b"node service\n" if label == "node" else f"{label} workspace\n".encode()
            status, _, body = guest.http(host=host)
            require(status == 200 and body == want, (host, status, body))
    elif name == "http_redirects":
        for host in ["node.test", *[f"{user}.node.test" for user in USERS]]:
            status, headers, _ = guest.http("/path?q=2", host=host, tls=False)
            require(status == 301 and headers.get("location") == f"https://{host}/path?q=2", headers)
            status, headers, _ = guest.http("/.well-known/acme-challenge/x", host=host, tls=False)
            require(
                status == 301 and headers.get("location") == "http://acme.node.test/.well-known/acme-challenge/x",
                headers,
            )
    elif name == "static_range":
        guest.install("amber", f"{token}.txt", token)
        status, headers, body = guest.http(f"/{token}.txt", host="amber.node.test", headers={"Range": "bytes=2-5"})
        require(
            status == 206 and body == token[2:6].encode() and headers.get("content-range") == "bytes 2-5/16",
            (status, headers, body),
        )
    elif name == "php_identity":
        for user in USERS:
            value = guest.php(user, token, 'echo json_encode(posix_getpwuid(posix_geteuid())["name"]);')
            require(value == user, value)
    elif name == "php_environment":
        for user in USERS:
            value = guest.php(user, token, 'echo json_encode([getenv("NODE_LABEL"),getenv("HOME"),getenv("TMPDIR")]);')
            require(value == [user, f"/home/{user}", "/tmp"], value)
    elif name == "php_open_basedir":
        for user, other in [("amber", "cobalt"), ("cobalt", "amber")]:
            # Other user's public file is Unix-readable: this isolates PHP's restriction.
            value = guest.php(
                user,
                token,
                f'echo json_encode([file_get_contents("/home/{user}/private/token"), @file_get_contents("/home/{other}/public_html/index.html"), @file_get_contents("/etc/passwd")]);',
            )
            require(value == [f"{user}-private\n", False, False], value)
    elif name == "php_pool_limits":
        for user, limit in [("amber", "2M"), ("cobalt", "8M")]:
            value = guest.php(
                user,
                token,
                'echo json_encode([ini_get("upload_max_filesize"),ini_get("post_max_size"),ini_get("memory_limit"),ini_get("max_execution_time"),filter_var(ini_get("display_errors"),FILTER_VALIDATE_BOOLEAN),extension_loaded("mbstring")]);',
            )
            require(value == [limit, limit, "128M", "120", False, True], value)
    elif name == "php_postgres":
        for user in USERS:
            value = guest.php(
                user,
                token,
                f'$d=new PDO("pgsql:host=catalog.node.test;dbname={user}","{user}","{user}-pass"); echo json_encode($d->query("SELECT current_user")->fetchColumn());',
            )
            require(value == user, value)
    elif name == "php_mysql":
        for user in USERS:
            value = guest.php(
                user,
                token,
                f'$d=new PDO("mysql:host=sql.node.test;dbname={user}","{user}","{user}-pass"); echo json_encode($d->query("SELECT DATABASE()")->fetchColumn());',
            )
            require(value == user, value)
    elif name == "cgi_identity":
        for user in USERS:
            name = f"cgi-bin/{token}.py"
            guest.install(
                user,
                name,
                '#!/usr/bin/python3\nimport os,pwd\nprint("Content-Type: text/plain\\n")\nprint(pwd.getpwuid(os.getuid()).pw_name)\n',
                executable=True,
            )
            status, _, body = guest.http("/" + name, host=f"{user}.node.test")
            require(status == 200 and body.strip() == user.encode(), (status, body))
    elif name == "wsgi_identity":
        for user in USERS:
            name = f"wsgi-bin/{token}.wsgi"
            guest.install(
                user,
                name,
                'import os,pwd\ndef application(environ,start_response):\n start_response("200 OK",[("Content-Type","text/plain")])\n return [pwd.getpwuid(os.getuid()).pw_name.encode()]\n',
            )
            status, _, body = guest.http("/" + name, host=f"{user}.node.test")
            require(status == 200 and body == user.encode(), (status, body))
    elif name == "proxy_header":
        value = guest.php(
            "amber",
            token,
            'echo json_encode(isset($_SERVER["HTTP_PROXY"]));',
            headers={"Proxy": "http://example.invalid:9"},
        )
        require(value is False, value)
    elif name == "htaccess_and_symlinks":
        directory = f"case-{token}"
        guest.install("amber", f"{directory}/value.txt", token)
        guest.install("amber", f"{directory}/.htaccess", "RewriteEngine On\nRewriteRule ^alias$ value.txt [L]\n")
        require(guest.http(f"/{directory}/alias", host="amber.node.test")[2] == token.encode(), "htaccess rewrite")
        guest.install("cobalt", f"{token}.txt", token)
        guest.ssh(
            f"ln -s /home/amber/public_html/{directory}/value.txt /home/amber/public_html/{directory}/same; chown -h amber:amber /home/amber/public_html/{directory}/same; ln -s /home/cobalt/public_html/{token}.txt /home/amber/public_html/{directory}/other; chown -h amber:amber /home/amber/public_html/{directory}/other"
        )
        require(guest.http(f"/{directory}/same", host="amber.node.test")[2] == token.encode(), "same-owner link")
        require(guest.http(f"/{directory}/other", host="amber.node.test")[0] == 403, "cross-owner link")
    elif name == "persistent_storage":
        # Persistence from settings, no reboot: data on a real disk and no boot-time cleanup of it.
        guest.python(
            r"""import subprocess
run=lambda *a,**k: subprocess.run(a,capture_output=True,text=True,check=True,**k).stdout.strip()
paths=['/home/amber/public_html','/home/cobalt/public_html',
 run('runuser','-u','postgres','--','psql','-X','-tAc','SHOW data_directory',cwd='/'),
 run('mysql','-Nse','SELECT @@datadir').rstrip('/')]
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
    assert not bad,(line,bad)"""
        )
    # Complexifier checks (CX-*, author/complexify.md); everything above comes from the original recipe.
    elif name == "sudo_decoy":
        listing = guest.ssh("sudo -l -U cobalt").stdout.decode()
        require("cobalt-access.log" in listing and "systemctl" not in listing, listing)
    elif name == "login_limits":
        for user in USERS:
            limits = guest.ssh(f"runuser -l {user} -c 'ulimit -Hu; ulimit -Hn'").stdout.split()
            require(limits == [b"200", b"4096"], (user, limits))
    elif name == "db_role_limits":
        # Per-tenant limits live in the database catalogs; each tenant reaches its own database with them applied.
        caps = guest.ssh(
            "cd / && runuser -u postgres -- psql -X -tAc \"SELECT rolname||':'||rolconnlimit FROM pg_roles WHERE rolname IN ('amber','cobalt') ORDER BY 1\""
        ).stdout.split()
        require(caps == [b"amber:20", b"cobalt:40"], caps)
        for user, timeout, limit in [("amber", b"30s", b"20"), ("cobalt", b"1min", b"40")]:
            shown = guest.as_user(user, f'psql -X -d {user} -tAc "SHOW statement_timeout"').stdout.strip()
            require(shown == timeout, (user, shown))
            grants = guest.ssh(
                f'mysql --protocol=TCP -h sql.node.test -u {user} -p{user}-pass -Nse "SHOW GRANTS" {user}'
            ).stdout
            require(f"MAX_USER_CONNECTIONS {limit.decode()}".encode() in grants, (user, grants))
    elif name == "log_rotation":
        guest.http("/", host="amber.node.test")
        guest.python(
            r"""import grp,re,subprocess
show=subprocess.run(['systemctl','show','logrotate.service','-p','ExecStart','--value'],capture_output=True,text=True,check=True).stdout
argv=re.search(r'argv\[\]=([^;]+)',show).group(1).split()
out=subprocess.run([argv[0],'-d','-f',*argv[1:]],capture_output=True,text=True)
out=out.stdout+out.stderr; adm=grp.getgrnam('adm').gr_gid; log='/var/log/web/amber-access.log'
assert f'rotating log {log}, log->rotateCount is 14' in out,out[-1500:]
# Either recreate as root:adm 0640 and reopen logs, or copytruncate (same file, perms kept).
recreate=f'creating new {log} mode = 0640 uid = 0 gid = {adm}' in out and 'running postrotate script' in out
assert recreate or 'copying' in out and 'truncating' in out,out[-1500:]"""
        )
    else:
        raise ValueError(name)


RECIPE_CHECKS = [
    "host_resolution",
    "accounts",
    "filesystem_ownership",
    "private_isolation",
    "sudo_log_policy",
    "slice_limits",
    "postgres_peer",
    "postgres_password",
    "postgres_isolation",
    "postgis",
    "mysql_root_socket",
    "mysql_password",
    "mysql_isolation",
    "cache_protocol",
    "loopback_services",
    "server_tuning",
    "userdir_redirect",
    "tls_aliases",
    "http_redirects",
    "static_range",
    "php_identity",
    "php_environment",
    "php_open_basedir",
    "php_pool_limits",
    "php_postgres",
    "php_mysql",
    "cgi_identity",
    "wsgi_identity",
    "proxy_header",
    "htaccess_and_symlinks",
    "persistent_storage",
]
COMPLEXIFIER_CHECKS = ["sudo_decoy", "login_limits", "log_rotation", "db_role_limits"]
CHECKS = RECIPE_CHECKS + COMPLEXIFIER_CHECKS
ERRORS = (AssertionError, OSError, KeyError, ValueError, subprocess.SubprocessError, RuntimeError)


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
    with tempfile.TemporaryDirectory(prefix="node17-candidate-") as state, (LOG / "candidate.log").open("wb") as output:
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
