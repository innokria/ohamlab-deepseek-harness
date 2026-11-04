
FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# 1. System dependencies
# ------------------------------------------------------------

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        git \
        curl \
        ca-certificates \
        nginx \
        python3 \
        python3-pip \
        python3-venv \
        && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 2. Python environment for OhamLab
# ------------------------------------------------------------

RUN python3 -m venv /opt/ohamlab-venv

ENV PATH="/opt/ohamlab-venv/bin:${PATH}"
ENV OHAM_PYTHON="/opt/ohamlab-venv/bin/python"

RUN "${OHAM_PYTHON}" -m pip --version && \
    "${OHAM_PYTHON}" --version

# ------------------------------------------------------------
# 3. Node / pnpm
# ------------------------------------------------------------

RUN corepack enable && \
    corepack prepare pnpm@11.7.0 --activate

WORKDIR /app

# ------------------------------------------------------------
# 4. Clone stable Harness release
# ------------------------------------------------------------

RUN git clone \
    --branch 1.0 \
    --depth 1 \
    https://github.com/innokria/ohamlab-deepseek-harness.git \
    deepseek-harness

# ------------------------------------------------------------
# 5. Clone OhamLab vendor from main
# ------------------------------------------------------------

RUN git clone \
    --branch main \
    --depth 1 \
    --filter=blob:none \
    --sparse \
    https://github.com/innokria/ohamlab-deepseek-harness.git \
    /tmp/ohamlab-source && \
    cd /tmp/ohamlab-source && \
    git sparse-checkout set vendor/ohamlab && \
    \
    mkdir -p /app/deepseek-harness/ohamlab/vendor && \
    cp -a vendor/ohamlab \
        /app/deepseek-harness/ohamlab/vendor/ && \
    \
    mkdir -p /app/ohamlab/plugins && \
    cp -a vendor/ohamlab/plugins/harness-brand \
        /app/ohamlab/plugins/ && \
    \
    rm -rf /tmp/ohamlab-source

WORKDIR /app/deepseek-harness

# ------------------------------------------------------------
# 6. Verify required OhamLab files
# ------------------------------------------------------------

RUN test -d /app/deepseek-harness/ohamlab/vendor/ohamlab/skills && \
    test -d /app/ohamlab/plugins/harness-brand && \
    test -f /app/deepseek-harness/ohamlab/vendor/ohamlab/gateway/requirements.txt

# ------------------------------------------------------------
# 7. Install OhamLab Python dependencies
# ------------------------------------------------------------

RUN "${OHAM_PYTHON}" -m pip install --no-cache-dir \
    -r /app/deepseek-harness/ohamlab/vendor/ohamlab/gateway/requirements.txt

# Ensure the required local fallback packages are installed.
# Agent Lab server extras support local API operation.

RUN "${OHAM_PYTHON}" -m pip install --no-cache-dir \
    "ohamlab-agent==0.1.2" \
    "ohamlab-agent-lab[server]==7.0.0"

# ------------------------------------------------------------
# 8. Verify installed Python packages
# ------------------------------------------------------------

RUN "${OHAM_PYTHON}" -m pip show ohamlab-agent && \
    "${OHAM_PYTHON}" -m pip show ohamlab-agent-lab && \
    command -v ohamlab && \
    "${OHAM_PYTHON}" -m pip check

# ------------------------------------------------------------
# 9. Install and build Harness
# ------------------------------------------------------------

RUN pnpm install

RUN echo "Checking Harness generated files..." && \
    ls -la lib/types || true

RUN pnpm run build

# ------------------------------------------------------------
# 10. Install branding plugin
# ------------------------------------------------------------

RUN pnpm dsh plugin --profile web add \
    /app/ohamlab/plugins/harness-brand

# ------------------------------------------------------------
# 11. Runtime configuration
# ------------------------------------------------------------

ENV DSH_HOME=/data/dsh \
    DSH_HOST=127.0.0.1 \
    DSH_PORT=3080 \
    PORT=7860 \
    OHAM_PYTHON=/opt/ohamlab-venv/bin/python

RUN mkdir -p /data/dsh

# ------------------------------------------------------------
# 12. Nginx and startup
# ------------------------------------------------------------

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE 7860

CMD ["/start.sh"]
