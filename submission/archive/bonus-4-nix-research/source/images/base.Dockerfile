FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 qemu-utils cloud-image-utils openssh-client curl ca-certificates \
    nix-bin xz-utils python3 rsync openssl git jq procps iproute2 \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/nix /nix/var/nix/profiles /root/.ssh \
    && printf 'experimental-features = nix-command flakes\nsandbox = false\nbuild-users-group =\n' > /etc/nix/nix.conf
ENV NIX_REMOTE=local
WORKDIR /app
