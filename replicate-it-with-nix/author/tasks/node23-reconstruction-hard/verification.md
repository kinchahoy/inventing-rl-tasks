# node23 verifier: coverage and cost

2026-11-03. Controls: reference 26/26; oracle 26/26 (`jobs/2026-11-03__17-10-27`); empty submission 0 (`jobs/2026-11-03__17-06-13`).

26 checks (22 recipe, 4 complexifier). The verifier carries a small stdlib DNS client (UDP, TCP, DoT); the same source runs
outside through the forwarded ports and inside the guest.

## Version gap policy

The reference runs PowerDNS Recursor 4.6 and dnsdist 1.6 (Ubuntu 22.04); nixpkgs 26.05 has only recursor 5.4.6 and dnsdist 2.0.7.
Checks assert behavior both generations share: answers, flags, TTL caps, refusals, listeners and owners. No check reads a
setting name or an API layout. The only API uses are the HTTP status codes of the two keyed endpoints and dnsdist's `cache-hits`
counter. Remaining gap: the oracle must still be written in each daemon's new configuration form.

## How we check

| # | Method | How | Checks |
| --- | --- | --- | --- |
| 1 | Live state, root SSH | `pwd`/`grp`, `ss -lntup` with owners, `findmnt`, `systemd-tmpfiles`, `/proc/sys`, `/proc/<pid>/limits`, `getent` | host_identity, accounts, listeners, persistent_storage; CX: local_resolver, socket_tuning |
| 2 | DNS from outside | UDP, TCP and DoT through forwarded ports; DoT verified against the lab CA | forwarded_answers, record_types, nxdomain_negative, internal_auth_zone, extra_hosts, any_chaos_refused, sinkhole, tcp_truncation, dot_service, positive_ttl_cap, wildcard_and_cname; CX: negative_ttl_override |
| 3 | DNS from inside | other source address on `lo` (ACL), direct queries to the recursor and to the authoritative daemon | acl_inside, recursor_version_string, nsd_identity_xfr, zone_content; CX: nsd_secondary |
| 4 | Operator sessions | `runuser -u birch/cedar -- sudo -n ...` | sudo_policy |
| 5 | Keyed HTTP endpoints, counters | status codes without and with the key; dnsdist `cache-hits` after repeated queries | monitoring_api, dnsdist_cache |

Every denial is paired with an allowed path (ACL: unlisted source silent, loopback answered; sinkhole: sibling name answered; ANY
refused, A answered; API 401 without key, 200 with).

## What is covered

| Area | Recipe sets | Checks |
| --- | --- | --- |
| Identity, accounts | `node23`; birch 1301, cedar 1302; narrow `rec_control` sudo grants | host_identity, accounts, sudo_policy |
| Listeners | front end 53/853 public; recursor 5353, authoritative 5301, APIs 8082/8083 on loopback | listeners |
| Resolution chain | front end -> recursor -> authoritative; RA set, AA clear | forwarded_answers, record_types, nxdomain_negative, wildcard_and_cname |
| Local data | recursor-served zone `i23.test` (AA), exported hosts file incl. PTR | internal_auth_zone, extra_hosts |
| Policy | ANY and CHAOS refused, sinkhole suffix, ACL, packet cache | any_chaos_refused, sinkhole, acl_inside, dnsdist_cache |
| Transports | UDP truncation (TC) then TCP; DoT >= TLS 1.2 | tcp_truncation, dot_service |
| Recursor behavior | `max-cache-ttl` 3600 cap on a 7200 TTL; version string | positive_ttl_cap, recursor_version_string |
| Authoritative | identity, hidden version, AXFR refused, zone and reverse data, SOA serial | nsd_identity_xfr, zone_content |
| APIs | keys required, key accepted | monitoring_api |
| Persistence | `/var/lib` and homes on disk, not cleaned | persistent_storage |
| CX-negative-ttl-override | include-dir drop-in lowers the negative TTL cap to 1800; `.dpkg-old` ignored | negative_ttl_override |
| CX-local-resolver | own resolver, search domain, no resolved stub | local_resolver |
| CX-socket-tuning | rmem/wmem/port range; LimitNOFILE on both daemons | socket_tuning |
| CX-nsd-secondary | AXFR of `a23.test` succeeds only from 198.51.100.7 (`provide-xfr`, SOA..SOA); the same request from loopback stays REFUSED | nsd_secondary (3) |

## Not checked

| Item | Why |
| --- | --- |
| Recursion to the Internet, DNSSEC validation | no network; setting not observable offline |
| Thread count, TCP client limits, IPv6, QNAME minimisation | not observable without load or network |
| QPS rate limit (50/s), DoH, anycast | needs load or extra stacks |
| Daemon versions and setting syntax | version-neutral behavior only |
| Log paths, statistics export | distro/low impact |
| Reboot | settings cover the common causes |

## Cost

Estimates only: most checks are one UDP/TCP exchange or one `curl`; `acl_inside` waits up to 4 s for two silent drops. No reboot.
