#!/bin/bash
# Health check for Atlas GPU Worker

ERRORS=0

# Check GPU accessible
if ! nvidia-smi >/dev/null 2>&1; then
    echo "UNHEALTHY: GPU not accessible"
    ERRORS=$((ERRORS + 1))
fi

# Check llama-server (only if a model exists)
if find /data/models -name '*.gguf' -type f 2>/dev/null | head -1 | grep -q .; then
    if ! curl -sf "http://localhost:${LLAMA_PORT:-8080}/health" >/dev/null 2>&1; then
        echo "UNHEALTHY: llama-server not responding"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check OpenClaw node host is running
if ! pgrep -f "openclaw node run" >/dev/null 2>&1; then
    echo "UNHEALTHY: OpenClaw node host not running"
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

echo "HEALTHY"
exit 0
