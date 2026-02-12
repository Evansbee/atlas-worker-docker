# ============================================================
# Atlas GPU Worker — Slim image (OpenClaw node host only)
# llama.cpp is downloaded at runtime, not compiled in the image
# ============================================================
FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/evansbee/atlas-worker-docker"
LABEL org.opencontainers.image.description="Atlas GPU Worker - OpenClaw inference node"

# Install runtime deps + Node.js 22
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates jq git xz-utils \
    && NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.version | startswith("v22")) | select(.lts != false)][0].version') \
    && curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz" | tar -xJ -C /usr/local --strip-components=1 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw
RUN npm install -g openclaw

# Create data directories
RUN mkdir -p /data/models /data/config /data/bin

# Copy entrypoint and health check
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh

ENV ATLAS_GATEWAY_HOST=atlas \
    ATLAS_GATEWAY_PORT=18789 \
    WORKER_NAME="GPU Worker"

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh

VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]
