#!/bin/bash
set -euo pipefail

# ============================================================
# Atlas GPU Worker Setup Script
# Run this on any GPU-equipped PC to join Atlas's network
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  Atlas GPU Worker Setup"
echo "=========================================="
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
    echo -e "${RED}ERROR: Docker is not installed.${NC}"
    echo "Install Docker Desktop: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker found: $(docker --version)"

# Check Docker Compose
if ! docker compose version &>/dev/null; then
    echo -e "${RED}ERROR: Docker Compose not found.${NC}"
    echo "Install Docker Desktop (includes Compose) or install the compose plugin."
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker Compose found"

# Check NVIDIA Container Toolkit
if ! docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi &>/dev/null 2>&1; then
    echo -e "${RED}ERROR: NVIDIA Container Toolkit not working.${NC}"
    echo ""
    echo "Install instructions:"
    echo ""
    echo "  Linux:"
    echo "    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
    echo "    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \\"
    echo "      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \\"
    echo "      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
    echo "    sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
    echo "    sudo nvidia-ctk runtime configure --runtime=docker"
    echo "    sudo systemctl restart docker"
    echo ""
    echo "  Windows (Docker Desktop):"
    echo "    1. Install latest NVIDIA GPU drivers"
    echo "    2. Docker Desktop → Settings → Resources → WSL Integration → Enable"
    echo "    3. GPU support is built into Docker Desktop with WSL2 backend"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓${NC} NVIDIA Container Toolkit working"

# Check Tailscale
if ! command -v tailscale &>/dev/null; then
    echo -e "${YELLOW}WARNING: Tailscale not found on host.${NC}"
    echo "The container uses host networking and needs Tailscale to reach atlas."
    echo "Install Tailscale: https://tailscale.com/download"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
else
    echo -e "${GREEN}✓${NC} Tailscale found"
    # Check if atlas is reachable
    if tailscale ping atlas --timeout 3s &>/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Atlas is reachable via Tailscale"
    else
        echo -e "${YELLOW}!${NC} Cannot reach 'atlas' via Tailscale — make sure it's online"
    fi
fi

echo ""

# Prompt for worker name
DEFAULT_NAME=$(hostname)
read -p "Worker name [${DEFAULT_NAME}]: " WORKER_NAME
WORKER_NAME="${WORKER_NAME:-$DEFAULT_NAME}"

# Prompt for gateway host
read -p "Atlas gateway host [atlas]: " GW_HOST
GW_HOST="${GW_HOST:-atlas}"

# Create working directory
WORKDIR="$HOME/atlas-worker"
mkdir -p "$WORKDIR"

# Write docker-compose.yml
cat > "$WORKDIR/docker-compose.yml" <<EOF
services:
  atlas-worker:
    image: ghcr.io/evansbee/atlas-worker:latest
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - ATLAS_GATEWAY_HOST=${GW_HOST}
      - ATLAS_GATEWAY_PORT=18789
      - WORKER_NAME=${WORKER_NAME}
    volumes:
      - atlas-worker-data:/data
    restart: unless-stopped
    network_mode: host

volumes:
  atlas-worker-data:
EOF

echo ""
echo "Created $WORKDIR/docker-compose.yml"
echo ""

# Start it up
cd "$WORKDIR"
echo "Pulling image and starting worker..."
docker compose up -d

echo ""
echo -e "${GREEN}=========================================="
echo "  Worker started!"
echo "==========================================${NC}"
echo ""
echo "  Name:     ${WORKER_NAME}"
echo "  Gateway:  ${GW_HOST}:18789"
echo "  Data:     Docker volume 'atlas-worker-data'"
echo ""
echo "  Next step: Ask Atlas to approve the pairing."
echo ""
echo "  Commands:"
echo "    cd $WORKDIR"
echo "    docker compose logs -f    # View logs"
echo "    docker compose down       # Stop"
echo "    docker compose up -d      # Start"
echo "    docker compose pull       # Update image"
echo ""
