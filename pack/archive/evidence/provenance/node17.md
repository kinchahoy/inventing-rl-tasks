# Author provenance: node17-reconstruction-hard

Upstream: https://github.com/openstreetmap/chef
Commit: b1ef9cc4b224bc9ad6a9925974c511a5f3caca05
Actual host: roles/faffy.rb -> role[dev]. License: Apache-2.0; see ./LICENSE.

Source elements retained/adapted:
- cookbooks/dev/recipes/default.rb: multi-user web hosting, PHP pools, WSGI/CGI,
  restricted log sudo, PostgreSQL/PostGIS, MySQL-compatible database, memcached.
- cookbooks/dev/templates/default/apache.user.erb: separate WSGI identities,
  HTTP->HTTPS and ACME redirects, Proxy header removal, PHP Unix sockets,
  userdir CGI routing, .htaccess categories and SymLinksIfOwnerMatch.
- apache.dev.erb: conditional /~user redirect only for existing public_html.
- sudoers.user.erb and user-slice.conf.erb: log access and 80%/90% memory policy.
- postgresql pg_hba.conf template: peer locally, password over loopback TCP.

Renaming: faffy -> node17; dev.openstreetmap.org -> node.test;
dev.osm.org -> node.alt.test; real personal accounts -> amber/cobalt.
Agent-facing image/instructions contain no upstream repo URL or host-role name.
This removes trivial name-based lookup, not all recognizable configuration
fingerprints. Full provenance stays author-side, never in the build context.

Scope changes:
- Two synthetic users; user data is tiny. Shared TLS fixture CA, synthetic DB
  passwords. Per-user PostgreSQL/MariaDB databases replace external app datasets.
- MariaDB replaces Ubuntu MySQL; upstream supports MariaDB on other platforms.
- PHP limits differ between users (2M/8M) and NODE_LABEL identifies each pool.
- Explicit PostgreSQL cross-database CONNECT restrictions; local resolver aliases
  catalog/sql/cache.node.test are an added operational dependency.
- Lab log paths /var/log/web; NOPASSWD for the specific existing log-read rules.
- Omit Rails/Passenger/cgimap deployments, GeoIP downloads, pgBackRest/S3,
  production secrets, host hardware/network roles, phpPgAdmin and the large
  collection of unrelated compilers/libraries/tools.
- Keep Ubuntu 22.04 packages and checksum-pinned CINC 18.11.11. Source is
  reconstructed through a small derived cookbook, not the full upstream role.

The frozen image hash and input digest are in reference-manifest.json (this directory).
Installed package list and convergence log are retained under .cache/node17.
Ubuntu base bytes are shared with the easy task. Package rebuilds use apt, so
exact reproduction uses the frozen image; rebuilding without caches can change
package versions. Build scripts cache the image by content inputs.

Added for discoverability: each tenant's `cgi-bin/hello.py` placeholder (Debian
`#!/usr/bin/python3` shebang), so the interpreter path verifier scripts use is
visible on the reference.

Complexifiers (not upstream): `recipes/complexify.rb`, IDs CX-sudo-decoy,
CX-login-limits, CX-log-rotation; see author/complexify.md.

Contract: plain `replica.nix` module plus local files against the harness-owned
nixpkgs 26.05 pin and Nix 2.35.4. The single agent prompt is
`node17-reconstruction-hard/instruction.md`. Validation status: oracle 34/34,
reference 34/34, nop 0/34 (2026-11-03).
