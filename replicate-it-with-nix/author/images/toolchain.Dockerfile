FROM base
COPY install-nix /tmp/install-nix
RUN bash /tmp/install-nix && rm /tmp/install-nix
ENV PATH="/opt/nix-current/bin:${PATH}"
RUN test "$(nix --version)" = 'nix (Nix) 2.35.4'
