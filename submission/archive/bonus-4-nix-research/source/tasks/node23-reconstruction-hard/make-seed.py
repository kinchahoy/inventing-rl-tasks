"""Generate neutral cloud-init input for the node23 reference."""

import base64
import json
import sys
from pathlib import Path

RECIPE = Path(__file__).resolve().parent
COOKBOOKS = RECIPE / "cookbooks"


def main() -> None:
    public = Path(sys.argv[2])
    entries = []

    def add(path: str, content: bytes, mode: str = "0644"):
        entries.append(
            {"path": path, "encoding": "b64", "content": base64.b64encode(content).decode(), "permissions": mode}
        )

    for source in COOKBOOKS.rglob("*"):
        if source.is_file():
            add("/opt/setup/cookbooks/" + str(source.relative_to(COOKBOOKS)), source.read_bytes())
    for name in ["server.crt", "server.key"]:
        add("/etc/node23/" + name, (public / name).read_bytes(), "0600" if name.endswith("key") else "0644")
    add("/etc/hosts", b"127.0.0.1 localhost node23 node23.n23.test\n::1 localhost ip6-localhost\n")
    script = r"""#!/bin/bash
set -euo pipefail
exec > /var/log/host-setup.log 2>&1
trap 'touch /var/lib/host-failed' ERR
rm -f /var/lib/host-failed
if [ ! -x /opt/cinc/bin/cinc-solo ]; then
  curl -fL --retry 0 https://packages.cinc.sh/files/stable/cinc/18.11.11/ubuntu/22.04/cinc_18.11.11-1_amd64.deb -o /var/cache/cinc.deb
  echo 'c0657ed3a035d210e9990c049589d29714fb55d7f7f232a2b35689c8f0d8001b  /var/cache/cinc.deb' | sha256sum -c -
  dpkg -i /var/cache/cinc.deb
fi
printf "cookbook_path ['/opt/setup/cookbooks']\nfile_cache_path '/opt/setup/cache'\n" > /opt/setup/solo.rb
/opt/cinc/bin/cinc-solo -c /opt/setup/solo.rb -o 'recipe[resolver],recipe[resolver::complexify]'
dnsdist --check-config -C /etc/dnsdist/dnsdist.conf
nsd-checkconf /etc/nsd/nsd.conf
systemctl is-active dnsdist pdns-recursor nsd
touch /etc/cloud/cloud-init.disabled
touch /var/lib/host-ready
"""
    add("/usr/local/sbin/setup-host", script.encode(), "0700")
    data = {
        "hostname": "node23",
        "manage_etc_hosts": False,
        "disable_root": False,
        "users": [{"name": "root", "ssh_authorized_keys": [(public / "id_ed25519.pub").read_text().strip()]}],
        "ssh_pwauth": False,
        "package_update": True,
        "packages": (RECIPE / "packages.txt").read_text().split(),
        "write_files": entries,
        "runcmd": [["bash", "/usr/local/sbin/setup-host"]],
    }
    Path(sys.argv[1]).write_text("#cloud-config\n" + json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
