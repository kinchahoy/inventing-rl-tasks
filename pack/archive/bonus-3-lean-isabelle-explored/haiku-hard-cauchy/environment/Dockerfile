FROM makarius/isabelle:Isabelle2025
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends tmux git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV USER_HOME=/home/isabelle \
    PATH=/home/isabelle/Isabelle/bin:$PATH
RUN isabelle build -b HOL
WORKDIR /app
COPY Cauchy.lean Group_Axioms.thy Cauchy.thy ROOT /app/
ENTRYPOINT []
