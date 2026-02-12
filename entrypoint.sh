#!/bin/bash
set -e

echo "============================================"
echo "  Atlas GPU Worker"
echo "  Gateway: ${ATLAS_GATEWAY_HOST}:${ATLAS_GATEWAY_PORT}"
echo "  Worker:  ${WORKER_NAME}"
echo "============================================"

# Store node config persistently
export OPENCLAW_STATE_DIR=/data/config

# Start OpenClaw node host (connects to atlas gateway)
echo "[atlas-worker] Starting OpenClaw node host..."
export OPENCLAW_GATEWAY_TOKEN="${ATLAS_GATEWAY_TOKEN:-}"

exec openclaw node run \
    --host "${ATLAS_GATEWAY_HOST}" \
    --port "${ATLAS_GATEWAY_PORT}" \
    --display-name "${WORKER_NAME}"
