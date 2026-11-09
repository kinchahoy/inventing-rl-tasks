FROM toolchain
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 30000 nixbld \
    && for i in 1 2 3 4; do useradd -u $((30000+i)) -g nixbld -G nixbld -M -s /usr/sbin/nologin nixbld$i; done \
    && useradd -m -u 20000 -s /bin/sh buildclient \
    && passwd -d buildclient \
    && mkdir -p /home/buildclient/.ssh /run/sshd
COPY --from=keys client_key.pub /home/buildclient/.ssh/authorized_keys
COPY --from=keys host_key /etc/ssh/replica_host_key
COPY --from=builder nix.conf /etc/nix/nix.conf
COPY --from=builder sshd_config /etc/ssh/replica_sshd_config
COPY --from=builder start /usr/local/sbin/start-builder
RUN chown -R buildclient:buildclient /home/buildclient/.ssh \
    && chmod 0700 /home/buildclient/.ssh \
    && chmod 0600 /home/buildclient/.ssh/authorized_keys /etc/ssh/replica_host_key
ENV NIX_REMOTE=daemon
ENTRYPOINT ["/usr/local/sbin/start-builder"]
