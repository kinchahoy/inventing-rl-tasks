## What to notice

1. 0.96 (26/27); single miss `operator_tools`: `htpasswd` not on the operators' PATH (`promtool` and `amtool` were).
2. Strong, systematic recon in the first 2.5 min: nginx, Prometheus/Alertmanager/blackbox configs, alert sink, inventory timer (CX), files written at provisioning time (step 19 is a neat trick: find files by mtime of the provisioning run).
3. Step 20 finds `/etc/amtool/config.yml` via that mtime scan, so it gets `amtool_operator`, the check most earlier runs missed.
4. `htpasswd` appears only as a *file* it copies (`/etc/nginx/htpasswd`, steps 8, 28-29), never as a *command* it puts on PATH. On Ubuntu `apache2-utils` was installed manually (`apt-mark showmanual`); it never ran that query.
5. Last new reference recon at ~06:44 (step 38, logrotate); the header's 19:24 is the final side-by-side diff (step 83). Minutes 9-19 are a long fight with the NixOS nginx module: duplicate `pid`, master running as `www-data` can't read the key, then seccomp (`SIGSYS` on `chown`), then `CAP_CHOWN`, then worker `setuid` failures, finally solved with `LoadCredential` (step 79).
6. That fight shows real Nix competence, but it consumed the budget the agent could have used for a tools-on-PATH diff.
7. Recurrent harness-hygiene errors: `pkill -f` matching its own shell (step 47), stale VMs holding port 3222 (step 58). Same pattern appears in every Haiku trace.
8. GID collisions (adm=4, sudo=27 vs NixOS messagebus/dialout) are solved by renumbering NixOS defaults to Ubuntu values (steps 31-36).
9. Step 83: a side-by-side diff of reference vs replica (identities, sshd -T, HTTP). Good method, but the diff list was hand-picked and omitted per-user command availability.
10. Final message claims match "on the things that matter". The miss is exactly in the class the prompt names ("the commands people are likely to use for this machine's job").
