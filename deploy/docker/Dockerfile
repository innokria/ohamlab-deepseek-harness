# Build with repository root as context:
# docker build -f deploy/docker/Dockerfile .
FROM node:22-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN corepack enable && corepack prepare pnpm@11.7.0 --activate
WORKDIR /app/harness
COPY . /app/harness
RUN test -f package.json && test -d vendor/ohamlab && pnpm install && pnpm run build
RUN python3 -m venv /opt/ohamlab-venv && /opt/ohamlab-venv/bin/pip install -r vendor/ohamlab/gateway/requirements.txt
ENV PATH=/opt/ohamlab-venv/bin:$PATH DSH_HOME=/data/dsh DSH_HOST=0.0.0.0 DSH_PORT=3080
EXPOSE 3080
# Override with your tested Harness command at deployment time.
CMD ["sh", "-c", "exec ${HARNESS_START_CMD:?Set HARNESS_START_CMD}"]
