FROM inputs
# Large frozen disk first so contract/runtime edits do not recopy it.
COPY --from=reference base.qcow2 /opt/reference/base.qcow2
COPY --from=recipe reference-manifest.json /opt/reference/manifest.json
COPY --from=recipe runtime /opt/runtime
COPY --from=contract . /opt/contract/
COPY --from=pins flake.lock /opt/contract/flake.lock
COPY --from=recipe public/ /opt/contract/
COPY --from=creds . /opt/contract/
RUN nixpkgs_source=$(jq -er '.inputs.nixpkgs.path' /opt/nix-inputs.json) \
    && ln -s "$nixpkgs_source" /opt/nixpkgs \
    && rm -rf /app/submission /opt/nix-inputs /opt/nix-inputs.json /opt/prewarm-roots.nix /opt/prewarm.nix \
    && mkdir -p /app/submission \
    && cp /opt/contract/replica.nix /app/submission/
# Local builds run as unprivileged build users, like the verifier's builder: root would
# otherwise ignore read-only store permissions and accept modules the verifier rejects.
# (A real sandbox needs user namespaces, which unprivileged containers lack.)
RUN groupadd -g 30000 nixbld \
    && for i in 1 2 3 4; do useradd -u $((30000+i)) -g nixbld -G nixbld -M -s /usr/sbin/nologin nixbld$i; done \
    && sed -i 's/^build-users-group =.*/build-users-group = nixbld/' /etc/nix/nix.conf \
    && chown root:nixbld /nix/store && chmod 1775 /nix/store
ENTRYPOINT []
CMD ["sleep", "infinity"]
