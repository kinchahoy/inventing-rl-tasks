FROM makarius/isabelle:Isabelle2025
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends tmux git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV USER_HOME=/home/isabelle \
    PATH=/home/isabelle/Isabelle/bin:$PATH
RUN isabelle build -b HOL
WORKDIR /app
# The complete Lean proof is the task's intended input, not a leaked answer: this is a proof-translation task
# (Lean 4 -> structured Isabelle/Isar). Translating it is the work being measured; the grader re-checks every
# statement in the Isabelle kernel against a trusted copy. See WRAPUP.md for the paper-reference variant.
COPY Shor_General.lean Quantum_Basics.thy Shor_General.thy ROOT /app/
ENTRYPOINT []
