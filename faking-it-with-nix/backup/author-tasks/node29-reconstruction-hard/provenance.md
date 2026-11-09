# Author provenance: node29-reconstruction-hard

Status: first draft, 2026-11-03. Nothing has been provisioned, built or run.

Upstream: https://github.com/wikimedia/operations-puppet (Wikimedia production Puppet; default branch `production`)
Commit: acae00a0ae474ad6d00f42b7255e5f53dde9e352 (2026-11-03)
License: majority Apache-2.0 (repo `LICENSE` states this; per-file SPDX headers apply; `hieradata/` has no explicit license, `vendor_modules`/`core_modules` keep their own). Files used here are Apache-2.0 (the exim template header reads `SPDX: Apache-2.0`). `LICENSE` in this directory is the Apache-2.0 text.

Upstream host role: a Wikimedia mail host built from `modules/exim4` (the generic exim4 class) with
`modules/profile/manifests/mail/default_mail_relay.pp` and its template
`modules/profile/templates/mail/default_mail_relay/exim4.minimal.production.erb`.

Elements kept (adapted into `cookbooks/mailhost/recipes/default.rb`):
- exim4 class conventions: hand-written `/etc/exim4/exim4.conf`, `update-exim4.conf.conf` set to configtype `none`,
  `/etc/default/exim4` combined daemon + queue runner, `/etc/exim4/dkim` directory, paniclog logrotate file.
- Relay template body: `check_spool_space = 50M`, `remote_max_parallel = 10`, `smtp_connect_backlog = 40`,
  `smtp_accept_max = 40`, `ignore_bounce_errors_after = 0h`, `message_logs = false`, `add_environment`/`keep_environment`,
  the `log_selector` list, the `system_aliases` redirect router, a `manualroute` `smart_route` with `remote_smtp`
  (`hosts_avoid_tls` for all hosts), the two retry rules (`F,2h,1m` for the smarthost, default `F,2h,5m; F,1d,15m`),
  and the sender rewrite rule for the host's own name.
- The upstream `unqualified_wiki_mail` / `wiki_mail` router pair (route by `X-Mailer: MediaWiki mailer`) became
  `legacy_app_mail` (blackhole) and `app_route` (alternate smarthost), keyed on `Legacy mailer`.

Scope changes (not upstream):
- Upstream is a loopback-only outbound relay. This role is a small MX + submission host: local domain `n29.test`,
  inbound SMTP on 25, authenticated submission on 587, STARTTLS with the lab fixture certificate, a recipient-verifying
  ACL, `message_size_limit = 25M`, Maildir delivery.
- Dovecot (IMAP 143 with STARTTLS, 993) and its SASL socket for exim's `dovecot` authenticators were added so mailbox
  contents and logins are checkable by ordinary clients. Wikimedia does not run this combination.
- DKIM signing is configured on `remote_smtp` (selector `mail`); the key is generated at provisioning. Wikimedia's
  signing setup is not copied.
- SpamAssassin/ClamAV content scanning (heavy daemon) is omitted.
- The smarthosts resolve to loopback ports nothing listens on (`smarthost.n29.test` in `/etc/hosts`): routing is
  checked with `exim -bt`, never by delivery.

Renaming: Wikimedia domains and hosts -> `n29.test`, `node29`, `smarthost.n29.test`; no Wikimedia name appears in
agent-facing files.

Complexifiers (not upstream): `cookbooks/mailhost/recipes/complexify.rb`, run after `default`.
- CX-auth-after-tls: `auth_advertise_hosts` offers AUTH only inside TLS. Operator rationale: no credentials in clear text on any port.
- CX-submission-sender-match: `acl_smtp_mail` requires the envelope sender to equal `<login>@n29.test` for authenticated clients. Anti-spoofing between local users.
- CX-conf-d-decoy: `/etc/exim4/conf.d/main/*` split-config leftovers with `MAIN_RELAY_NETS = 0.0.0.0/0`. Inert because the live
  config is the single `exim4.conf`; copying them would create an open relay.
The base config reads the first two through `.include_if_exists` hooks (`local-main.conf`, `local-acl.conf`) so the
original and complexified recipes stay in separate files.

Host: Ubuntu 22.04 (shared cached jammy image), checksum-pinned CINC 18.11.11, packages in `packages.txt`
(exim4-daemon-light, dovecot 2.3 on jammy; nixpkgs 26.05 ships Dovecot 2.4, so settings differ in form).
Fixture passwords fern-pass/moss-pass are public.
