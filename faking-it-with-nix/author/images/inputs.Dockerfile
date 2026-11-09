FROM toolchain
# Package cache only: the shared nixpkgs pin plus the task's prewarm closures.
COPY --from=pins flake.nix flake.lock /opt/nix-inputs/
RUN nix flake archive --json --no-write-lock-file /opt/nix-inputs > /opt/nix-inputs.json
COPY prewarm-roots.nix /opt/prewarm-roots.nix
COPY --from=recipe prewarm.nix /opt/prewarm.nix
RUN nix build --no-link --impure --file /opt/prewarm-roots.nix
