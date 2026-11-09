FROM ghcr.io/astral-sh/uv:0.13.7 AS uv
FROM debian:bookworm-slim
COPY --from=uv /uv /uvx /usr/local/bin/
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libseccomp2 libstdc++6 libgcc-s1 git procps curl bash \
    && rm -rf /var/lib/apt/lists/*
ENV UV_PYTHON_INSTALL_DIR=/opt/python UV_PYTHON_INSTALL_BIN=0
RUN uv python install 3.15.2 3.15.2t --no-bin \
    && ln -s "$(uv python find --managed-python 3.15.2)" /usr/local/bin/python-gil \
    && ln -s "$(uv python find --managed-python 3.15.2t)" /usr/local/bin/python-ft \
    && ln -s /usr/local/bin/python-gil /usr/local/bin/python3 \
    && ln -s /usr/local/bin/python-gil /usr/local/bin/python
RUN uv pip install --python python-gil --target /opt/reference lark==1.3.1
# Agent tooling, not verifier test dependencies (deliberate; see WRAPUP.md "Accepted harbor check findings"):
# pytest lets the agent run the library's upstream test
# suite while it works, like git or tmux. The verifier (tests/) never uses it: it runs only the standard
# library, and its submission worker's PYTHONPATH is the staged submission alone, so it cannot affect grading.
RUN uv pip install --python python-gil --target /opt/devtools pytest==8.4.2
WORKDIR /app
RUN cp -a /opt/reference/lark /app/lark
ENV PYTHONPATH=/app:/opt/reference:/opt/devtools PYTHON_JIT=0 \
    PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0
COPY public_check.py /app/public_check.py
ENTRYPOINT []
