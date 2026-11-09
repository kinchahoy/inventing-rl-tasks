# Author provenance: node23-reconstruction-hard

Status: first draft, 2026-11-03. Nothing has been provisioned, built or run.

Upstream: https://github.com/wikimedia/operations-puppet (Wikimedia production Puppet; default branch `production`)
Commit: acae00a0ae474ad6d00f42b7255e5f53dde9e352 (2026-11-03)
License: majority Apache-2.0 (repo `LICENSE` states this; per-file SPDX headers apply; `hieradata/` has no explicit license). `LICENSE` in this directory is the Apache-2.0 text. Only module code (not hieradata) was read.

Upstream host role: a Wikimedia recursive resolver: `modules/dnsrecursor` (PowerDNS Recursor, also used for Wikidough)
fronted by `modules/dnsdist`; Wikimedia's authoritative tier is gdnsd (`modules/gdnsd`).

Elements kept (adapted into `cookbooks/resolver/recipes/default.rb`), from the dnsrecursor class parameters and
`recursor.conf.erb`:
- `forward-zones` to the authoritative tier for internal and reverse zones, `auth-zones` served by the recursor itself,
  `export-etc-hosts` with an `extrarecursorhosts` file (`extra_records`), `allow-from`, listen address/port,
  `dont-query` with a negation, `dnssec=off`, `threads=4`, `max-negative-ttl=3600`, `max-tcp-clients=128`,
  `max-tcp-per-client=100`, `client-tcp-timeout=2`, no QNAME minimisation, `version-string`,
  `webserver` + `api-key` on loopback, `max-cache-entries`, `include-dir`.
- dnsdist front end in the Wikidough pattern: ACL, packet cache, DNS-over-TLS listener, ANY/CHAOS refusal,
  per-client QPS cap, a suffix sinkhole, loopback web API.

Scope changes (not upstream):
- gdnsd is replaced by NSD serving two small zones (`a23.test`, reverse `2.0.192.in-addr.arpa`) on 127.0.0.1:5301:
  both ship as Ubuntu packages and NixOS modules; gdnsd's availability in nixpkgs 26.05 was not confirmed.
- The recursor listens on 127.0.0.1:5353 behind dnsdist (upstream recursors listen directly); one backend, no health
  routing, no DoH, no anycast/BGP, no Prometheus exporters.
- Two operator accounts with narrow `rec_control` sudo grants were added (upstream grants come from admin groups).
- Zone data, addresses and the web/API keys are synthetic lab values.
- Ubuntu's systemd-resolved stub (127.0.0.53:53) is disabled in the base recipe because dnsdist owns port 53.

Renaming: Wikimedia names -> `node23`, `n23.test`, `a23.test`, `i23.test`.

Complexifiers (not upstream): `cookbooks/resolver/recipes/complexify.rb`, run after `default`.
- CX-negative-ttl-override: `recursor.d/50-ttl.conf` lowers `max-negative-ttl` to 1800 over `recursor.conf`'s 3600;
  `60-legacy.conf.dpkg-old` (forward, allow-from and a 60 s cap) is inert because only `*.conf` is read.
- CX-local-resolver: the host uses its own resolver (`/etc/resolv.conf` -> 127.0.0.1, search `n23.test`) with
  systemd-resolved stopped, so short names resolve through the recursor's exported hosts.
- CX-socket-tuning: `sysctl.d/90-dns.conf` (rmem/wmem max 8 MiB, ephemeral range 10240-65535) and `LimitNOFILE=65536`
  drop-ins for pdns-recursor and dnsdist. Standard resolver-host advice.

Host: Ubuntu 22.04, CINC 18.11.11, pdns-recursor 4.6, dnsdist 1.6, nsd 4.3 (jammy). nixpkgs 26.05 ships newer majors
(recursor 5 uses YAML settings, dnsdist 2.x), so setting names differ between reference and replica.

Version-gap policy: nixpkgs 26.05 has pdns-recursor 5.4.6 and dnsdist 2.0.7 against the reference's 4.6 and 1.6. Checks assert
behavior both generations share (answers, flags, TTL caps, refusals, listeners); none reads setting names or API layouts. The
web/API checks use only status codes and the `cache-hits` counter.
