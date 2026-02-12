FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl wget git build-essential cmake \
    python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs

# Install OpenClaw globally
RUN npm install -g openclaw

# Build llama.cpp with CUDA
WORKDIR /opt
RUN git clone https://github.com/ggerganov/llama.cpp.git \
    && cd llama.cpp \
    && mkdir build && cd build \
    && cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89 \
    && make -j$(nproc) \
    && cp bin/llama-server bin/llama-cli /usr/local/bin/ \
    && cp bin/libggml*.so bin/libllama*.so /usr/local/lib/ \
    && ldconfig

# Models directory
RUN mkdir -p /models

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]
