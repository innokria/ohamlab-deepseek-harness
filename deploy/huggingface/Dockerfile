FROM node:22-bookworm
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/ohamlab-venv
ENV PATH="/opt/ohamlab-venv/bin:${PATH}" \
    OHAM_PYTHON=/opt/ohamlab-venv/bin/python \
    PYTHONUNBUFFERED=1 \
    OHAMLAB_HARNESS_HOME=/opt/ohamlab-harness \
    DSH_HOME=/data/dsh \
    DSH_HOST=0.0.0.0 \
    DSH_PORT=7860 \
    PORT=7860
RUN corepack enable && corepack prepare pnpm@11.7.0 --activate
ARG OHAMLAB_PYPI_VERSION=0.1.0b2
RUN python -m pip install --no-cache-dir "ohamlab-harness==${OHAMLAB_PYPI_VERSION}"
RUN ohamlab-harness install
RUN mkdir -p /data/dsh
EXPOSE 7860
CMD ["ohamlab-harness", "start", "--host", "0.0.0.0", "--port", "7860"]
