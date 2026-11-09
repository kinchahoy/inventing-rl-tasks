## What to notice

1. Opus 5.5 via OpenRouter, n=1, verifier v2: 0.80 (28/35) in 19.5 min, $5.46. Lower than the best Haiku (0.83) at ~5x the cost.
2. Few, larger steps: 71 LLM calls, only 4 check-replica and 5 builds. It plans more and iterates less.
3. Many early steps have no visible text (steps 2-17): the reasoning is not in the ATIF `message`. Step 18 is an injected notice that a safety classifier stopped one response; the agent continues normally.
4. Hand-rolled Apache (step 24) for fidelity, like the oracle and Haiku. Explicitly decides suEXEC is "not built in stock nixpkgs" and accepts CGI-as-www-data as an "intentional divergence" (final message). So `cgi_identity` is a declared trade-off, not an oversight (the oracle solves it with per-tenant fcgiwrap sockets).
5. Fails `postgis` even though it "verified postgis availability" (step 70): the extension package is installed, but `CREATE EXTENSION postgis` was not run in each tenant DB. "Available" ≠ "enabled in the database".
6. Same four never-looked surfaces as Haiku: slice limits, `REVOKE CONNECT`, pam limits, logrotate; and the same half-hit on `db_role_limits` (connection caps yes, `statement_timeout` no).
7. Better than Haiku on sudo and all PHP checks (see `07-evidence/opus-vs-haiku-node17.csv`).
8. Verifier build took 823 s (vs ~226 s for Haiku): its choices pulled in closures not prewarmed in the builder (it claims PostgreSQL 14, not the prewarmed 17). Still under the 900 s build timeout, but close.
9. Last reference query ~16:00 (step 63, checking the Ubuntu php-fpm unit). Stops at 19.5 min.
10. Bigger model, same failure shape: stops on green after verifying what it built. Supports the claim that the headroom is discovery/attention, not model size.
