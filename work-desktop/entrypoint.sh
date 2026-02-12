#!/bin/bash
set -e

echo "=== Atlas Worker Node ==="
echo "GPU:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "No GPU detected"
echo ""

# Start OpenClaw node in background
echo "Starting OpenClaw node..."
openclaw node start &

# If a model exists, start llama-server
MODEL=$(find /models -name "*.gguf" -type f | head -1)
if [ -n "$MODEL" ]; then
    echo "Starting llama-server with: $MODEL"
    llama-server \
        -m "$MODEL" \
        -ngl 99 \
        -c 4096 \
        --port 8081 \
        --host 0.0.0.0 &
else
    echo "No model found in /models/ — llama-server not started"
    echo "Download a model: docker exec atlas-worker bash -c 'curl -L <url> -o /models/model.gguf'"
fi

# Keep container running
wait
