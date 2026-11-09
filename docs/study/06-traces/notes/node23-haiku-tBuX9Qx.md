## What to notice

1. The only 1.0 in any Nix run on the hard tasks (node23 is a bonus task; Haiku k=3 was 0.77, 0.96, 1.0, so pass@3 = 1 → node23 has no headroom by the brief's rule and was moved to `bonus-1-nix-solved-example`).
2. Small, legible stack: dnsdist (53/853) → pdns-recursor (127.0.0.1:5353) → nsd (127.0.0.1:5301). Recon finishes by ~03:34 (step 24).
3. Key decision at steps 16-19: it rejects the NixOS dnsdist/nsd/recursor modules (hard-coded users, YAML-only recursor config) and writes its own systemd units against the reference's paths and identities.
4. Version gap handled by flag, not rewrite: pdns-recursor 5.x needs `--enable-old-settings` to accept the 4.6 legacy config (step 20); dnsdist 2.0 moved web credentials into `setWebserverConfig()` (steps 33-35).
5. Behavioural diff, not file diff: a 26-query DNS battery run inside both guests and diffed (steps 47-48). It notices that host-side `dig` didn't exist and an empty-vs-empty diff "proves nothing" (step 47). That self-correction is the difference between this run and the misses elsewhere.
6. It switches off Extended DNS Errors so client-visible answers match 4.6 (step 50).
7. Same harness-hygiene stumbles as other runs (pkill matching itself, port still bound by an old VM, step 68), but they cost little here.
8. The parity claim at the end is, for once, correct.
9. Why this task was solvable: every graded property is observable through the daemon's own behaviour, which the agent's battery exercised. Compare with node17's `slice_limits`/`db_role_limits`, which only show up if you query systemd or the DB catalogs.
10. Useful as the "solved example" in an interview: it shows the checks are achievable and that the hard tasks fail on discovery, not on Nix syntax.
