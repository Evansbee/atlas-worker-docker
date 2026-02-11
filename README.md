# Atlas GPU Worker

Run ONE command on any GPU-equipped PC to join Atlas's inference network.

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/evansbee/atlas-worker-docker/main/setup-worker.sh | bash
```

Or manually:

```bash
git clone https://github.com/evansbee/atlas-worker-docker.git
cd atlas-worker-docker
docker compose up -d
```

## Prerequisites

1. **Docker** (Docker Desktop on Windows/Mac, or Docker Engine on Linux)
2. **NVIDIA GPU** with recent drivers
3. **NVIDIA Container Toolkit**
4. **Tailscale** running on the host (so the container can reach `atlas`)

## NVIDIA Container Toolkit Installation

### Linux

```bash
# Add NVIDIA repo
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Windows (Docker Desktop)

1. Install latest [NVIDIA GPU drivers](https://www.nvidia.com/drivers)
2. Install [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/) with WSL2 backend
3. GPU support is automatic with WSL2 — no extra toolkit needed
4. Verify: `docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi`

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `ATLAS_GATEWAY_HOST` | `atlas` | Hostname of the Atlas gateway |
| `ATLAS_GATEWAY_PORT` | `18789` | Gateway port |
| `WORKER_NAME` | `GPU Worker` | Display name in Atlas |
| `LLAMA_PORT` | `8080` | Internal llama.cpp server port |
| `LLAMA_GPU_LAYERS` | `99` | GPU layers (99 = offload all) |
| `LLAMA_CTX_SIZE` | `8192` | Context window size |
| `LLAMA_THREADS` | `4` | CPU threads for llama.cpp |
| `MODEL_NAME` | (auto) | Specific .gguf filename to load |

## Model Management

Models are stored in the Docker volume at `/data/models/`. Atlas can trigger downloads via the node's `run` command:

```bash
# Manual model download into the volume
docker compose exec atlas-worker \
  wget -P /data/models/ "https://huggingface.co/Qwen/Qwen3-30B-A3B-GGUF/resolve/main/Qwen3-30B-A3B-Q4_K_M.gguf"
```

The container auto-detects `.gguf` files and starts llama-server with the first one found (or the one specified by `MODEL_NAME`).

## Networking

**Recommended:** Host network mode + Tailscale on the host.

The container runs with `network_mode: host`, meaning it shares the host's network stack. If the host has Tailscale connected to your tailnet, the container can reach `atlas` directly. No Tailscale inside the container needed.

## Commands

```bash
docker compose up -d          # Start
docker compose down            # Stop
docker compose logs -f         # View logs
docker compose pull && docker compose up -d  # Update
docker compose exec atlas-worker nvidia-smi  # Check GPU
```

## Troubleshooting

**"Cannot reach atlas gateway"**
- Ensure Tailscale is running on the host: `tailscale status`
- Verify: `ping atlas` from the host
- Check gateway is running on atlas

**"GPU not accessible"**
- Run `nvidia-smi` on the host — drivers must work first
- Check NVIDIA Container Toolkit: `docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi`

**"llama-server not started"**
- No model in `/data/models/`. Download one (see Model Management above).
- Check logs: `docker compose logs -f`

**"OpenClaw node not connecting"**
- Gateway may not be running. Check atlas.
- Worker may need pairing approval. Ask Atlas.

**Container keeps restarting**
- Check logs: `docker compose logs --tail 50`
- GPU memory issue? Try reducing `LLAMA_CTX_SIZE` or use a smaller model.
