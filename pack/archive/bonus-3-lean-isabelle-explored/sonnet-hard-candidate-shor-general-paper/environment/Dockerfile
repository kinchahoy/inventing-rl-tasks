FROM makarius/isabelle:Isabelle2025
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends poppler-utils tmux git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV USER_HOME=/home/isabelle \
    PATH=/home/isabelle/Isabelle/bin:$PATH
RUN isabelle build -b HOL
WORKDIR /app
COPY Lin_Shor_QFT_2013.pdf Quantum_Basics.thy Shor_General.thy ROOT /app/
ENTRYPOINT []
