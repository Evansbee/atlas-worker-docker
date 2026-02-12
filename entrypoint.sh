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
mkdir -p /data/config
mkdir -p /root/.openclaw
cat > /root/.openclaw/exec-approvals.json << 'APPROVALS'
{
  "version": 1,
  "defaults": {
    "mode": "full"
  },
  "agents": {}
}
APPROVALS

echo "[atlas-worker] Starting OpenClaw node host..."
exec openclaw node run \
    --host "${ATLAS_GATEWAY_HOST}" \
    --port "${ATLAS_GATEWAY_PORT}" \
    --display-name "${WORKER_NAME}"
