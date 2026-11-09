"""Mailhost verifier: recipe and complexifier checks; see author/methods.md and verification.md."""

import imaplib
import json
import os
import secrets
import shlex
import smtplib
import ssl
import subprocess
import sys
import tempfile
import time
from pathlib import Path

LOG = Path("/logs/verifier")
HOST = "node29.n29.test"
PASSWORDS = {"fern": "fern-pass", "moss": "moss-pass"}
EXIM = "$(command -v exim || command -v exim4)"


def run(args, *, check=True, timeout=30, **kwargs):
    result = subprocess.run(args, check=False, capture_output=True, timeout=timeout, **kwargs)
    if check and result.returncode:
        detail = (result.stdout + result.stderr).decode(errors="replace")
        raise RuntimeError(f"Command {shlex.join(args)} exited {result.returncode}:\n{detail}")
    return result


def require(condition, detail):
    if not condition:
        raise AssertionError(str(detail))


class Imaps(imaplib.IMAP4_SSL):
    """IMAPS to the forwarded loopback port, verifying the certificate against the service name."""

    def _create_socket(self, timeout):
        sock = imaplib.IMAP4._create_socket(self, timeout)
        return self.ssl_context.wrap_socket(sock, server_hostname=HOST)


class Guest:
    def __init__(self, candidate=False):
        self.ssh_port = 3222 if candidate else 2222
        self.smtp_port = 3525 if candidate else 2525
        self.sub_port = 3587 if candidate else 2587
        self.imap_port = 3143 if candidate else 2143
        self.imaps_port = 3993 if candidate else 2993
        self.ctx = ssl.create_default_context(cafile="/opt/contract/ca.crt")

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

    def exim(self, args):
        result = self.ssh(f"{EXIM} {args} 2>&1", check=False)
        return result.stdout.decode(errors="replace")

    def smtp(self, port, *, tls=False):
        client = smtplib.SMTP(timeout=15)
        client.connect("127.0.0.1", port)
        client._host = HOST  # certificate name for STARTTLS verification
        client.ehlo("probe.test")
        if tls:
            client.starttls(context=self.ctx)
            client.ehlo("probe.test")
        return client

    def imap(self, user, password=None):
        client = Imaps("127.0.0.1", self.imaps_port, ssl_context=self.ctx, timeout=15)
        client.login(user, password or PASSWORDS[user])
        return client

    def send(self, to, subject, sender="probe@external.test"):
        client = self.smtp(self.smtp_port)
        try:
            body = f"From: {sender}\r\nTo: {to}\r\nSubject: {subject}\r\n\r\nbody\r\n"
            client.sendmail(sender, [to] if isinstance(to, str) else to, body)
        finally:
            client.quit()

    def has_subject(self, user, subject, *, wait=15):
        deadline = time.monotonic() + wait
        while True:
            client = self.imap(user)
            try:
                client.select("INBOX", readonly=True)
                _, data = client.search(None, "SUBJECT", f'"{subject}"')
                if data[0].split():
                    return True
            finally:
                client.logout()
            if time.monotonic() >= deadline:
                return False
            time.sleep(1)

    def ready(self):
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            result = self.ssh("systemctl is-active --quiet multi-user.target", check=False)
            if result.returncode == 0:
                return
            time.sleep(2)
        raise RuntimeError("Guest did not reach multi-user.target within 180 seconds")


def size(text):
    """Exim prints sizes as bytes or with a K/M suffix."""
    text = text.strip()
    scale = {"K": 1024, "M": 1024 * 1024}
    return int(text[:-1]) * scale[text[-1]] if text[-1] in scale else int(text)


def exim_options(guest, names):
    out = guest.exim("-bP " + " ".join(names))
    values = {}
    for line in out.splitlines():
        if " = " in line:
            key, value = line.split(" = ", 1)
            values[key.strip()] = value.strip()
    return values


def check(name, guest, token):
    if name == "host_identity":
        require(guest.ssh("hostname").stdout.strip() == b"node29", "hostname")
        options = exim_options(guest, ["primary_hostname", "qualify_domain"])
        require(options == {"primary_hostname": HOST, "qualify_domain": "n29.test"}, options)
        result = guest.ssh("getent ahostsv4 smarthost.n29.test").stdout.decode().splitlines()
        require(result and all(line.split()[0] == "127.0.0.1" for line in result), result)
    elif name == "accounts":
        guest.python(
            "import grp,os,pwd,stat\nfor u,uid in [('fern',1201),('moss',1202)]:\n"
            " p=pwd.getpwnam(u); assert (p.pw_uid,p.pw_gid,p.pw_dir,os.path.basename(p.pw_shell),grp.getgrgid(uid).gr_name)==(uid,uid,'/home/'+u,'bash',u),p\n"
            " assert stat.S_IMODE(os.stat(p.pw_dir).st_mode)==0o700,u"
        )
    elif name == "listeners":
        out = guest.ssh("ss -H -lntp").stdout.decode()
        owners = {}
        for line in out.splitlines():
            fields = line.split()
            owners[fields[3].rsplit(":", 1)[1]] = line
        for port, process in [("25", "exim"), ("587", "exim"), ("143", "imap-login"), ("993", "imap-login")]:
            require(port in owners and process in owners[port], (port, out))
        for port in ("110", "995", "465", "4190"):
            require(port not in owners, (port, out))
    elif name == "smtp_banner":
        client = smtplib.SMTP(timeout=15)
        code, banner = client.connect("127.0.0.1", guest.smtp_port)
        client.close()
        require(code == 220 and banner.decode().startswith(f"{HOST} ESMTP node29"), banner)
    elif name == "ehlo_extensions":
        client = guest.smtp(guest.smtp_port)
        features = client.esmtp_features
        client.quit()
        require(features.get("size") == "26214400", features)
        require("pipelining" in features and "starttls" in features, features)
    elif name == "starttls_cert":
        for port in (guest.smtp_port, guest.sub_port):
            client = guest.smtp(port, tls=True)  # chain and name verified against the lab CA
            require(client.sock.cipher() is not None, port)
            client.quit()
    elif name == "recipient_acceptance":
        client = guest.smtp(guest.smtp_port)
        client.mail("probe@external.test")
        for rcpt in ["fern@n29.test", "moss@n29.test", "postmaster@n29.test", "abuse@n29.test", "team@n29.test"]:
            code, _ = client.rcpt(rcpt)
            require(code == 250, (rcpt, code))
        code, message = client.rcpt("nosuchuser@n29.test")
        client.quit()
        require(code == 550, (code, message))
    elif name == "relay_denied":
        for port in (guest.smtp_port, guest.sub_port):
            client = guest.smtp(port)
            client.mail("probe@external.test")
            require(client.rcpt("fern@n29.test")[0] == 250, port)
            code, message = client.rcpt("someone@external.test")
            client.quit()
            require(code == 550 and b"relay" in message, (port, code, message))
    elif name == "local_delivery":
        subject = f"delivery-{token}"
        guest.send("fern@n29.test", subject)
        require(guest.has_subject("fern", subject), "message not in fern INBOX")
        require(not guest.has_subject("moss", subject, wait=0), "message leaked to moss")
    elif name == "alias_list_delivery":
        subject = f"alias-{token}"
        guest.send(["team@n29.test", "postmaster@n29.test"], subject)
        require(guest.has_subject("fern", subject) and guest.has_subject("moss", subject), "team alias")
    elif name == "imap_tls_policy":
        client = imaplib.IMAP4("127.0.0.1", guest.imap_port, timeout=15)
        require("LOGINDISABLED" in client.capability()[1][0].decode(), "plaintext login allowed")
        try:
            client.login("fern", PASSWORDS["fern"])
            raise AssertionError("login accepted without TLS")
        except imaplib.IMAP4.error:
            pass
        client.host = HOST
        client.starttls(ssl_context=guest.ctx)
        client.login("fern", PASSWORDS["fern"])
        client.logout()
        try:
            guest.imap("fern", "wrong-password")
            raise AssertionError("wrong password accepted")
        except imaplib.IMAP4.error:
            pass
        guest.imap("moss").logout()
    elif name == "imap_folders":
        client = guest.imap("fern")
        _, listing = client.list()
        client.logout()
        text = b"\n".join(listing).decode()
        for folder, flag in [("Drafts", "\\Drafts"), ("Sent", "\\Sent"), ("Trash", "\\Trash"), ("Junk", "\\Junk")]:
            line = next((entry for entry in text.splitlines() if entry.rstrip('"').endswith(folder)), "")
            require(flag in line, (folder, text))
    elif name == "mailbox_isolation":
        for user in PASSWORDS:
            guest.imap(user).logout()
        for user, other in [("fern", "moss"), ("moss", "fern")]:
            require(guest.as_user(user, f"ls /home/{user}/Maildir/cur").returncode == 0, "own maildir")
            require(guest.as_user(user, f"ls /home/{other}/Maildir", check=False).returncode != 0, "cross read")
        guest.python(
            "import os,pwd,stat\nfor u in ('fern','moss'):\n"
            " for sub in ('Maildir','Maildir/cur','Maildir/new','Maildir/tmp'):\n"
            "  p='/home/'+u+'/'+sub; s=os.stat(p); assert pwd.getpwuid(s.st_uid).pw_name==u and stat.S_IMODE(s.st_mode)==0o700,(p,oct(s.st_mode))"
        )
    elif name == "submission_auth":
        client = guest.smtp(guest.sub_port, tls=True)
        try:
            client.login("fern", "wrong-password")
            raise AssertionError("wrong password accepted")
        except smtplib.SMTPAuthenticationError as error:
            require(error.smtp_code == 535, error)
        client.login("fern", PASSWORDS["fern"])
        client.mail("fern@n29.test")
        require(client.rcpt("someone@external.test")[0] == 250, "authenticated relay")
        require(client.rcpt("moss@n29.test")[0] == 250, "authenticated local")
        client.quit()
    elif name == "smarthost_route":
        out = guest.exim("-bt someone@external.test")
        require("router = smart_route" in out and "transport = remote_smtp" in out, out)  # CONFIRM format
        require("smarthost.n29.test" in out, out)
    elif name == "alias_resolution":
        out = guest.exim("-bt postmaster@n29.test")
        require("fern@n29.test" in out and "router = localuser" in out and "transport = local_delivery" in out, out)
        out = guest.exim("-bt team@n29.test")
        require("fern@n29.test" in out and "moss@n29.test" in out, out)
    elif name == "remote_transport":
        out = guest.exim("-bP transport remote_smtp")
        for expected in ["hosts_avoid_tls = <; 0.0.0.0/0 ; 0::0/0", "dkim_domain = n29.test", "dkim_selector = mail"]:
            require(expected in out, (expected, out))  # CONFIRM printed list form
    elif name == "sender_rewrite":
        out = guest.exim("-brw fern@node29.n29.test")
        require("fern@n29.test" in out, out)  # CONFIRM output format
    elif name == "retry_rules":
        out = guest.exim("-brt smarthost.n29.test")
        require("F,2h,1m" in out, out)
        out = guest.exim("-brt other.test")
        require("F,2h,5m" in out and "F,1d,15m" in out, out)  # CONFIRM output format
    elif name == "exim_limits":
        options = exim_options(
            guest,
            ["smtp_accept_max", "smtp_accept_max_per_host", "smtp_connect_backlog", "remote_max_parallel",
             "check_spool_space", "message_size_limit", "message_logs", "ignore_bounce_errors_after"],
        )
        require(
            [int(options[k]) for k in ("smtp_accept_max", "smtp_accept_max_per_host", "smtp_connect_backlog", "remote_max_parallel")]
            == [40, 10, 40, 10],
            options,
        )
        require(size(options["check_spool_space"]) == 50 * 1024 * 1024, options)  # CONFIRM
        require(size(options["message_size_limit"]) == 25 * 1024 * 1024, options)
        require(options["message_logs"] == "false" or "message_logs" not in options, options)
    elif name == "log_selector":
        out = guest.exim("-bP log_selector")
        for flag in ["address_rewrite", "all_parents", "delivery_size", "deliver_time", "incoming_interface",
                     "incoming_port", "smtp_confirmation", "smtp_protocol_error", "smtp_syntax_error"]:
            require(flag in out, (flag, out))  # CONFIRM
    elif name in ("local_sendmail", "legacy_app_blackhole"):
        # One flow: a legacy-mailer message is sent first and must vanish; the plain one after it must arrive.
        legacy, plain = f"legacy-{token}", f"plain-{token}"
        template = "printf 'From: fern@n29.test\\nTo: moss@n29.test\\n%sSubject: %s\\n\\nbody\\n' | sendmail -t -i"
        guest.as_user("fern", template % ("X-Mailer: Legacy mailer 2.1\\n", legacy))
        guest.as_user("fern", template % ("", plain))
        require(guest.has_subject("moss", plain), "local sendmail delivery")
        if name == "legacy_app_blackhole":
            require(not guest.has_subject("moss", legacy, wait=0), "legacy-mailer message was delivered")
        else:
            client = guest.imap("moss")
            client.select("INBOX", readonly=True)
            _, data = client.search(None, "SUBJECT", f'"{plain}"')
            _, message = client.fetch(data[0].split()[0], "(BODY.PEEK[HEADER])")
            client.logout()
            require(b"Return-path: <fern@n29.test>" in message[0][1], message[0][1])
    elif name == "persistent_storage":
        guest.python(
            r"""import subprocess
run=lambda *a: subprocess.run(a,capture_output=True,text=True,check=True).stdout.strip()
spool=run('sh','-c','$(command -v exim || command -v exim4) -bP spool_directory').split('=',1)[1].strip()
paths=[spool,'/home/fern','/home/moss']
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
    elif name == "auth_after_tls":
        for port in (guest.smtp_port, guest.sub_port):
            plain = guest.smtp(port)
            require("auth" not in plain.esmtp_features, (port, plain.esmtp_features))
            plain.quit()
            secure = guest.smtp(port, tls=True)
            mechanisms = secure.esmtp_features.get("auth", "").split()
            require("PLAIN" in mechanisms and "LOGIN" in mechanisms, (port, secure.esmtp_features))
            secure.quit()
    elif name == "conf_d_decoy":
        # Ask the daemon how it treats an unlisted client: the split-config fragments must not apply.
        script = "EHLO probe.test\\nMAIL FROM:<probe@external.test>\\nRCPT TO:<fern@n29.test>\\nRCPT TO:<z@external.test>\\nQUIT\\n"
        out = guest.ssh(f"printf '{script}' | {EXIM} -bh 10.0.2.2 2>&1", check=False).stdout.decode()
        require("250 Accepted" in out and "550 relay not permitted" in out, out)  # CONFIRM -bh transcript
    elif name == "sender_match":
        client = guest.smtp(guest.sub_port, tls=True)
        client.login("fern", PASSWORDS["fern"])
        code, message = client.mail("moss@n29.test")
        require(code >= 500, ("spoofed sender accepted", code, message))
        client.rset()
        require(client.mail("fern@n29.test")[0] == 250, "own sender rejected")
        client.quit()
    else:
        raise ValueError(name)


RECIPE_CHECKS = [
    "host_identity",
    "accounts",
    "listeners",
    "smtp_banner",
    "ehlo_extensions",
    "starttls_cert",
    "recipient_acceptance",
    "relay_denied",
    "local_delivery",
    "alias_list_delivery",
    "imap_tls_policy",
    "imap_folders",
    "mailbox_isolation",
    "submission_auth",
    "smarthost_route",
    "alias_resolution",
    "remote_transport",
    "sender_rewrite",
    "retry_rules",
    "exim_limits",
    "log_selector",
    "local_sendmail",
    "legacy_app_blackhole",
    "persistent_storage",
]
COMPLEXIFIER_CHECKS = ["auth_after_tls", "conf_d_decoy", "sender_match"]
CHECKS = RECIPE_CHECKS + COMPLEXIFIER_CHECKS
ERRORS = (AssertionError, OSError, KeyError, ValueError, subprocess.SubprocessError, RuntimeError, imaplib.IMAP4.error, smtplib.SMTPException, ssl.SSLError)


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
    with tempfile.TemporaryDirectory(prefix="mailhost-candidate-") as state, (LOG / "candidate.log").open("wb") as output:
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
