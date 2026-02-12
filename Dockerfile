# ============================================================
# Stage 1: Build llama.cpp with CUDA support
# ============================================================
FROM nvidia/cuda:12.4.0-devel-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LIBRARY_PATH}
RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git && \
    cd llama.cpp && \
    cmake -B build -DGGML_CUDA=ON -DLLAMA_CURL=ON -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --config Release -j$(nproc) && \
    mkdir -p /out/bin && \
    cp build/bin/llama-server /out/bin/ && \
    cp build/bin/llama-cli /out/bin/

# ============================================================
# Stage 2: Runtime image
# ============================================================
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

LABEL org.opencontainers.image.source="https://github.com/evansbee/atlas-worker-docker"
LABEL org.opencontainers.image.description="Atlas GPU Worker - OpenClaw inference node"

# Install runtime deps + Node.js 22 (latest)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates libcurl4 jq git xz-utils \
    && NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.version | startswith("v22")) | select(.lts != false)][0].version') \
    && curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz" | tar -xJ -C /usr/local --strip-components=1 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw
RUN npm install -g openclaw

# Copy llama.cpp binaries from builder
COPY --from=builder /out/bin/ /usr/local/bin/

# Create data directories
RUN mkdir -p /data/models /data/config

# Copy entrypoint and health check
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh

ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    ATLAS_GATEWAY_HOST=atlas \
    ATLAS_GATEWAY_PORT=18789 \
    WORKER_NAME="GPU Worker" \
    LLAMA_PORT=8080 \
    LLAMA_THREADS=4 \
    LLAMA_GPU_LAYERS=99 \
    LLAMA_CTX_SIZE=8192 \
    MODEL_NAME=""

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /healthcheck.sh

ENTRYPOINT ["/entrypoint.sh"]
