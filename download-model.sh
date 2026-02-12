#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <huggingface-url>"
    echo ""
    echo "Examples:"
    echo "  $0 https://huggingface.co/Qwen/Qwen3-30B-A3B-GGUF/resolve/main/Qwen3-30B-A3B-Q4_K_M.gguf"
    echo "  $0 https://huggingface.co/microsoft/DialoGPT-medium/resolve/main/pytorch_model.bin"
    exit 1
fi

URL="$1"
FILENAME=$(basename "$URL")

echo "Downloading model: $FILENAME"
echo "From: $URL"

# Create a temporary container to download the model
# Auto-detect compose setup (Metal vs CUDA)
if [ -f "docker-compose.metal.yml" ] && [[ "$OSTYPE" == "darwin"* ]]; then
    COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.metal.yml"
else
    COMPOSE_CMD="docker compose"
fi

$COMPOSE_CMD run --rm -v models:/models atlas-worker bash -c "
    cd /models
    echo 'Downloading $FILENAME...'
    wget -O '$FILENAME.tmp' '$URL'
    mv '$FILENAME.tmp' '$FILENAME'
    echo 'Download complete: $FILENAME'
    ls -lh '$FILENAME'
"

echo "Model downloaded successfully to models volume: $FILENAME"