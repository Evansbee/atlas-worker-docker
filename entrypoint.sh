#!/bin/bash
set -euo pipefail

# ============================================================
# Atlas GPU Worker Entrypoint
# ============================================================

LLAMA_PID=""
OPENCLAW_PID=""

cleanup() {
    echo "[entrypoint] Shutting down..."
    [ -n "$OPENCLAW_PID" ] && kill "$OPENCLAW_PID" 2>/dev/null && wait "$OPENCLAW_PID" 2>/dev/null
    [ -n "$LLAMA_PID" ] && kill "$LLAMA_PID" 2>/dev/null && wait "$LLAMA_PID" 2>/dev/null
    echo "[entrypoint] Clean shutdown complete."
    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================
# Wait for atlas gateway to be reachable
# ============================================================
echo "[entrypoint] Waiting for atlas gateway at ${ATLAS_GATEWAY_HOST}:${ATLAS_GATEWAY_PORT}..."
for i in $(seq 1 60); do
    if curl -sf "http://${ATLAS_GATEWAY_HOST}:${ATLAS_GATEWAY_PORT}" >/dev/null 2>&1 || \
       nc -z "$ATLAS_GATEWAY_HOST" "$ATLAS_GATEWAY_PORT" 2>/dev/null; then
        echo "[entrypoint] Gateway reachable."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[entrypoint] WARNING: Could not reach gateway after 60s, proceeding anyway..."
    fi
    sleep 1
done

# ============================================================
# Find model file
# ============================================================
MODEL_PATH=""
if [ -n "${MODEL_NAME}" ] && [ -f "/data/models/${MODEL_NAME}" ]; then
    MODEL_PATH="/data/models/${MODEL_NAME}"
else
    # Find first .gguf file
    MODEL_PATH=$(find /data/models -name '*.gguf' -type f 2>/dev/null | head -1)
fi

# ============================================================
# Start llama.cpp server if model available
# ============================================================
if [ -n "$MODEL_PATH" ]; then
    echo "[entrypoint] Starting llama-server with model: $(basename "$MODEL_PATH")"
    llama-server \
        --model "$MODEL_PATH" \
        --host 0.0.0.0 \
        --port "${LLAMA_PORT}" \
        --n-gpu-layers "${LLAMA_GPU_LAYERS}" \
        --ctx-size "${LLAMA_CTX_SIZE}" \
        --threads "${LLAMA_THREADS}" \
        2>&1 | sed 's/^/[llama] /' &
    LLAMA_PID=$!
    echo "[entrypoint] llama-server started (PID: $LLAMA_PID)"

    # Wait for llama server to be ready
    echo "[entrypoint] Waiting for llama-server to be ready..."
    for i in $(seq 1 120); do
        if curl -sf "http://localhost:${LLAMA_PORT}/health" >/dev/null 2>&1; then
            echo "[entrypoint] llama-server is ready."
            break
        fi
        if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
            echo "[entrypoint] ERROR: llama-server exited unexpectedly"
            LLAMA_PID=""
            break
        fi
        sleep 1
    done
else
    echo "[entrypoint] No model found in /data/models/. llama-server not started."
    echo "[entrypoint] Download a model: atlas can trigger this via 'run' command."
fi

# ============================================================
# Start OpenClaw node host
# ============================================================
echo "[entrypoint] Starting OpenClaw node host as '${WORKER_NAME}'..."

# Use persistent config directory
export OPENCLAW_CONFIG_DIR=/data/config

openclaw node run \
    --host "${ATLAS_GATEWAY_HOST}" \
    --port "${ATLAS_GATEWAY_PORT}" \
    --display-name "${WORKER_NAME}" \
    2>&1 | sed 's/^/[openclaw] /' &
OPENCLAW_PID=$!
echo "[entrypoint] OpenClaw node host started (PID: $OPENCLAW_PID)"

# ============================================================
# Monitor processes
# ============================================================
while true; do
    # Check OpenClaw
    if ! kill -0 "$OPENCLAW_PID" 2>/dev/null; then
        echo "[entrypoint] OpenClaw node host exited, restarting in 5s..."
        sleep 5
        openclaw node run \
            --host "${ATLAS_GATEWAY_HOST}" \
            --port "${ATLAS_GATEWAY_PORT}" \
            --display-name "${WORKER_NAME}" \
            2>&1 | sed 's/^/[openclaw] /' &
        OPENCLAW_PID=$!
    fi

    # Check llama-server (only if it was started)
    if [ -n "$LLAMA_PID" ] && ! kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo "[entrypoint] llama-server exited, restarting in 5s..."
        sleep 5
        if [ -n "$MODEL_PATH" ] && [ -f "$MODEL_PATH" ]; then
            llama-server \
                --model "$MODEL_PATH" \
                --host 0.0.0.0 \
                --port "${LLAMA_PORT}" \
                --n-gpu-layers "${LLAMA_GPU_LAYERS}" \
                --ctx-size "${LLAMA_CTX_SIZE}" \
                --threads "${LLAMA_THREADS}" \
                2>&1 | sed 's/^/[llama] /' &
            LLAMA_PID=$!
        fi
    fi

    sleep 5
done
