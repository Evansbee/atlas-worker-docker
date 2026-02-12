#!/bin/bash

# Exit on any error
set -e

# Signal handling
trap 'echo "Received SIGTERM, shutting down gracefully..."; kill $OPENCLAW_PID $LLAMA_PID 2>/dev/null; exit 0' SIGTERM

echo "Starting Atlas Worker..."

# Start OpenClaw node host in background
echo "Starting OpenClaw node host..."
GATEWAY_HOST="${ATLAS_GATEWAY_HOST:-atlas}"
GATEWAY_PORT="${ATLAS_GATEWAY_PORT:-18789}"
GATEWAY_TOKEN="${ATLAS_GATEWAY_TOKEN:-}"
WORKER_NAME="${WORKER_NAME:-atlas-worker-$(hostname)}"

if [ -n "$GATEWAY_TOKEN" ]; then
    TOKEN_ARGS="--token $GATEWAY_TOKEN"
else
    TOKEN_ARGS=""
fi

openclaw node host \
    --gateway "${GATEWAY_HOST}:${GATEWAY_PORT}" \
    --name "$WORKER_NAME" \
    $TOKEN_ARGS &

OPENCLAW_PID=$!
echo "OpenClaw node host started with PID $OPENCLAW_PID"

# Wait a moment for OpenClaw to initialize
sleep 5

# Look for .gguf files in /models/
echo "Checking for models in /models/..."
if [ -n "$MODEL_NAME" ]; then
    MODEL_PATH="/models/$MODEL_NAME"
    if [ -f "$MODEL_PATH" ]; then
        echo "Using specified model: $MODEL_PATH"
        MODEL_FILE="$MODEL_PATH"
    else
        echo "Specified model $MODEL_NAME not found in /models/"
        MODEL_FILE=""
    fi
else
    # Use first .gguf file found
    MODEL_FILE=$(find /models -name "*.gguf" -type f | head -n 1)
fi

if [ -n "$MODEL_FILE" ] && [ -f "$MODEL_FILE" ]; then
    echo "Starting llama-server with model: $MODEL_FILE"
    echo "GPU Backend: ${GPU_BACKEND:-cuda}"
    
    # Start llama-server with appropriate GPU offload
    if [ "${GPU_BACKEND:-cuda}" = "cpu" ]; then
        echo "Using CPU-only inference (no GPU offload)"
        llama-server \
            --model "$MODEL_FILE" \
            --host 0.0.0.0 \
            --port "${LLAMA_PORT:-8080}" \
            --ctx-size "${LLAMA_CTX_SIZE:-8192}" \
            --verbose &
    else
        echo "Using GPU acceleration (${GPU_BACKEND:-cuda})"
        llama-server \
            --model "$MODEL_FILE" \
            --host 0.0.0.0 \
            --port "${LLAMA_PORT:-8080}" \
            --ctx-size "${LLAMA_CTX_SIZE:-8192}" \
            --n-gpu-layers "${LLAMA_GPU_LAYERS:-99}" \
            --verbose &
    fi
    
    LLAMA_PID=$!
    echo "llama-server started with PID $LLAMA_PID"
else
    echo "No .gguf models found in /models/. llama-server not started."
    echo "Use ./download-model.sh to download models."
    LLAMA_PID=""
fi

# Keep the container running and wait for processes
echo "Atlas Worker is running. OpenClaw PID: $OPENCLAW_PID, llama-server PID: $LLAMA_PID"

# Wait for processes to exit
wait