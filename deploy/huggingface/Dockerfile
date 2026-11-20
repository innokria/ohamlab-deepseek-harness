
FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# 1. System dependencies
# ------------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    curl \
    ca-certificates \
    nginx \
    python3 \
    python3-venv \
    python3-pip \
    tar \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 2. Python environment
# ------------------------------------------------------------

RUN python3 -m venv /app/ohamlab-venv

ENV PATH="/app/ohamlab-venv/bin:${PATH}" \
    OHAM_PYTHON=/app/ohamlab-venv/bin/python \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    OHAMLAB_HARNESS_HOME=/app/ohamlab-harness \
    OHAMLAB_HARNESS_TAG=1.0 \
    OHAMLAB_INTEGRATION_TAG=2.0 \
    DSH_HOME=/data/dsh \
    DSH_HOST=127.0.0.1 \
    DSH_PORT=3080 \
    PORT=7860 \
    SHELL=/bin/bash

# ------------------------------------------------------------
# 3. Install pnpm
# ------------------------------------------------------------

RUN corepack enable \
    && corepack prepare pnpm@11.7.0 --activate \
    && pnpm config set dangerouslyAllowAllBuilds true

# ------------------------------------------------------------
# 4. Get current OhamLab repository
# ------------------------------------------------------------

ARG OHAMLAB_REPO=https://github.com/innokria/ohamlab-deepseek-harness.git
ARG OHAMLAB_BRANCH=main

RUN git clone \
    --depth 1 \
    --branch "${OHAMLAB_BRANCH}" \
    "${OHAMLAB_REPO}" \
    /tmp/ohamlab-source

# ------------------------------------------------------------
# 5. Install Python package from repository source
# ------------------------------------------------------------

RUN python -m pip install --upgrade pip \
    && python -m pip install /tmp/ohamlab-source/packages/python \
    && python -m pip show ohamlab-harness \
    && ohamlab-harness --version

# Remove checkout after installing the Python package.
# Harness and integration sources are fetched by installer.py.
RUN rm -rf /tmp/ohamlab-source

# ------------------------------------------------------------
# 6. Persistent data directories
# ------------------------------------------------------------

RUN mkdir -p \
    /data/dsh/sessions \
    /data/dsh/session-backup \
    /data/dsh/plugins \
    /data/dsh/skills \
    /data/dsh/profiles \
    /data/dsh/cache \
    /data/dsh/logs \
    /tmp/ohamlab-dsh-sessions \
    /app/ohamlab-harness

# ------------------------------------------------------------
# 7. Nginx configuration
# ------------------------------------------------------------

COPY nginx.conf /etc/nginx/nginx.conf

# ------------------------------------------------------------
# 8. Startup script
# ------------------------------------------------------------

COPY start.sh /usr/local/bin/start.sh

RUN chmod +x /usr/local/bin/start.sh \
    && bash -n /usr/local/bin/start.sh \
    && nginx -t

# ------------------------------------------------------------
# 9. Hugging Face Spaces port
# ------------------------------------------------------------

EXPOSE 7860

CMD ["/usr/local/bin/start.sh"]
