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
    HARNESS_VERSION=1.0 \
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
# 4. Install published OhamLab Harness PyPI package
# ------------------------------------------------------------
RUN python -m pip install --upgrade pip \
&& python -m pip install --pre ohamlab-harness \
&& python -m pip show ohamlab-harness

# ------------------------------------------------------------
# 5. Copy OhamLab plugins from main (brand + voice)
# ------------------------------------------------------------
RUN git clone --depth 1 --branch main \
https://github.com/innokria/ohamlab-deepseek-harness.git \
/tmp/ohamlab-integration \
&& mkdir -p /app/ohamlab/plugins \
&& test -f /tmp/ohamlab-integration/vendor/ohamlab/plugins/harness-brand/package.json \
&& cp -a /tmp/ohamlab-integration/vendor/ohamlab/plugins/. \
/app/ohamlab/plugins/ \
&& test -f /app/ohamlab/plugins/harness-brand/package.json \
&& echo "[OHAMLAB] Branding source installed successfully" \
&& rm -rf /tmp/ohamlab-integration

# ------------------------------------------------------------
# 6. Create persistent data directories
# ------------------------------------------------------------
RUN mkdir -p \
/data/dsh/sessions \
/data/dsh/session-backup \
/data/dsh/plugins \
/data/dsh/skills \
/data/dsh/profiles \
/data/dsh/cache \
/data/dsh/logs \
/tmp/ohamlab-dsh-sessions

# ------------------------------------------------------------
# 7. Verify branding source
# ------------------------------------------------------------
RUN test -f /app/ohamlab/plugins/harness-brand/package.json \
&& echo "[OHAMLAB] Branding source verified"

# ------------------------------------------------------------
# 8. Nginx configuration
# ------------------------------------------------------------
COPY nginx.conf /etc/nginx/nginx.conf

# ------------------------------------------------------------
# 9. Startup script
# ------------------------------------------------------------
COPY start.sh /usr/local/bin/start.sh

RUN chmod +x /usr/local/bin/start.sh \
&& bash -n /usr/local/bin/start.sh \
&& nginx -t

# ------------------------------------------------------------
# 10. Install branding plugin
# ------------------------------------------------------------
# ------------------------------------------------------------
# 10. Install branding plugin
# ------------------------------------------------------------
# RUN cd /app/ohamlab-harness/app \
#     && pnpm dsh plugin --profile web add \
#        /app/ohamlab/plugins/harness-brand

# ------------------------------------------------------------
# 11. Hugging Face Spaces port
# ------------------------------------------------------------
EXPOSE 7860

CMD ["/usr/local/bin/start.sh"]
