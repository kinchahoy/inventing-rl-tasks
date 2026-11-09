# Mailhost verifier: coverage and cost

2026-11-03, first draft: not yet run on the reference, oracle or `nop`. Values marked `# CONFIRM` in
`node29-reconstruction-hard/tests/verify.py` must be confirmed against the real reference.

27 checks (24 recipe, 3 complexifier) in `node29-reconstruction-hard/tests/verify.py`.

## How we check

| # | Method | How | Checks |
| --- | --- | --- | --- |
| 1 | Ask the daemon, root SSH | `exim -bP <option>`, `-bP transport`, `-bt` (routing), `-brw` (rewrite), `-brt` (retry), `-bh` (ACL as an unlisted host) | host_identity, exim_limits, log_selector, remote_transport, smarthost_route, alias_resolution, sender_rewrite, retry_rules; CX: conf_d_decoy |
| 2 | Live state, root SSH | `pwd`/`grp`, `stat`, `ss -lntp`, `findmnt`, `systemd-tmpfiles --cat-config` | accounts, listeners, mailbox_isolation, persistent_storage |
| 3 | Client sessions from outside | smtplib/imaplib through forwarded ports, CA- and name-verified: banner, EHLO, STARTTLS, RCPT codes, AUTH, LOGIN, LIST | smtp_banner, ehlo_extensions, starttls_cert, recipient_acceptance, relay_denied, imap_tls_policy, imap_folders, submission_auth; CX: auth_after_tls, sender_match |
| 4 | Plant and read back | send a random-subject message by SMTP or local `sendmail`, find it over IMAP | local_delivery, alias_list_delivery, local_sendmail, legacy_app_blackhole |

Every denial is paired with an allowed path (unknown recipient vs known; relay denied vs local accepted; plaintext
login refused vs login over TLS; cross-user read denied vs own read).

## What is covered

| Area | Recipe sets | Checks |
| --- | --- | --- |
| Identity | hostname `node29`, primary_hostname, qualify_domain, `smarthost.n29.test` -> 127.0.0.1 | host_identity |
| Accounts | fern 1201, moss 1202, bash, home 0700 | accounts |
| Listeners | exim 25/587, Dovecot 143/993, no POP/SMTPS | listeners |
| SMTP face | banner, SIZE 25M, STARTTLS, PIPELINING, fixture certificate | smtp_banner, ehlo_extensions, starttls_cert |
| Recipients, relay | local domain users and aliases accepted, unknown 550, relay denied unauthenticated | recipient_acceptance, relay_denied |
| Delivery | Maildir, mode 0700, aliases (`postmaster`, `abuse`, `team` list) | local_delivery, alias_list_delivery, alias_resolution, mailbox_isolation |
| IMAP | TLS required, plaintext login refused, special-use folders | imap_tls_policy, imap_folders |
| Submission | AUTH via Dovecot SASL, authenticated relay | submission_auth |
| Routing | smart_route, retry rules, `hosts_avoid_tls`, DKIM domain/selector, sender rewrite | smarthost_route, remote_transport, retry_rules, sender_rewrite |
| Limits, logging | accept/backlog/parallel limits, spool space, log selector | exim_limits, log_selector |
| Local submission | `sendmail` works for users; `Legacy mailer` messages blackholed | local_sendmail, legacy_app_blackhole |
| Persistence | spool and homes on disk, not cleaned at boot | persistent_storage |
| CX-auth-after-tls | AUTH only after STARTTLS on 25 and 587 | auth_after_tls |
| CX-conf-d-decoy | split-config relay net is inert | conf_d_decoy |
| CX-submission-sender-match | envelope sender must match the login | sender_match |

## Not checked

| Item | Why |
| --- | --- |
| DKIM signature on the wire, key contents | no remote MTA to receive; the key is generated at provisioning |
| Actual smarthost delivery | smarthost ports have no listener; routing is asked of `exim -bt` |
| Log file paths and format, paniclog rotation | distro paths |
| Dovecot major version, quota, sieve | 2.3 vs 2.4 differ; nothing was configured |
| Reboot, queue-runner timing | settings cover the common causes |

## Cost

Estimates only: most checks are one client exchange or one `exim -b*` call. `has_subject` polls IMAP up to 15 s but
normally returns in the first iteration. No reboot.
