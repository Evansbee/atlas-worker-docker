#!/bin/bash
# Download a GGUF model into the shared models volume
# Usage: ./download-model.sh [url] [filename]
#
# Default: Qwen3-30B-A3B (18GB, fast MoE model)

MODEL_URL="${1:-https://huggingface.co/unsloth/Qwen3-30B-A3B-GGUF/resolve/main/Qwen3-30B-A3B-Q4_K_M.gguf}"
MODEL_FILE="${2:-current.gguf}"

echo "Downloading model to shared volume..."
docker exec atlas-worker bash -c "
  curl -L -o /models/${MODEL_FILE} '${MODEL_URL}' && \
  ls -lh /models/${MODEL_FILE} && \
  echo 'Download complete!'
"
