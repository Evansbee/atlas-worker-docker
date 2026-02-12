#!/bin/bash
set -e

echo "============================================"
echo "  Atlas GPU Worker"
echo "  Gateway: ${ATLAS_GATEWAY_HOST}:${ATLAS_GATEWAY_PORT}"
echo "  Worker:  ${WORKER_NAME}"
echo "============================================"

# Store node config persistently
export OPENCLAW_STATE_DIR=/data/config
export OPENCLAW_GATEWAY_TOKEN="${ATLAS_GATEWAY_TOKEN:-}"

# Set exec approvals to allow all commands
mkdir -p /data/config /root/.openclaw

APPROVALS_JSON='{
  "version": 1,
  "defaults": {
    "security": "full"
  },
  "agents": {}
}'

echo "$APPROVALS_JSON" > /data/config/exec-approvals.json
echo "$APPROVALS_JSON" > /root/.openclaw/exec-approvals.json

echo "[atlas-worker] Exec approvals set to full mode"
echo "[atlas-worker] Starting OpenClaw node host..."
exec openclaw node run \
    --host "${ATLAS_GATEWAY_HOST}" \
    --port "${ATLAS_GATEWAY_PORT}" \
    --display-name "${WORKER_NAME}"
