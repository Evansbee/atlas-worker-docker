ARG GPU_BACKEND=cuda

# Use CUDA base for NVIDIA, regular Ubuntu for Metal
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04 AS cuda-base
FROM ubuntu:22.04 AS metal-base

FROM ${GPU_BACKEND}-base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    git \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs

# Install OpenClaw globally
RUN npm install -g openclaw

# Build llama.cpp from source with GPU support
ARG GPU_BACKEND=cuda
WORKDIR /tmp
RUN git clone https://github.com/ggerganov/llama.cpp.git \
    && cd llama.cpp \
    && mkdir build \
    && cd build \
    && if [ "$GPU_BACKEND" = "cuda" ]; then \
        cmake .. -DGGML_CUDA=ON; \
    elif [ "$GPU_BACKEND" = "metal" ]; then \
        cmake .. -DGGML_METAL=ON; \
    else \
        cmake ..; \
    fi \
    && make -j$(nproc) \
    && cp bin/* /usr/local/bin/ \
    && cd / \
    && rm -rf /tmp/llama.cpp

# Create workspace
WORKDIR /app

# Copy entrypoint and healthcheck scripts
COPY entrypoint.sh /app/entrypoint.sh
COPY healthcheck.sh /app/healthcheck.sh
RUN chmod +x /app/entrypoint.sh /app/healthcheck.sh

# Create volume mount points
RUN mkdir -p /models /root/.openclaw

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /app/healthcheck.sh

ENTRYPOINT ["/app/entrypoint.sh"]