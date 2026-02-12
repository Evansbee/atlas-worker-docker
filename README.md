# Atlas Worker Docker

A lean, simple Docker setup for running OpenClaw node host with llama.cpp server in a single container.

## Quick Start

```bash
git clone <this-repo>
cd atlas-worker-docker
docker compose build
docker compose up -d
```

## Prerequisites

- **Docker** with compose plugin
- **NVIDIA drivers** (for GPU support)
- **NVIDIA Container Toolkit** ([installation guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html))
- **Tailscale** running on host (container uses `network_mode: host`)

## Architecture

- **Single container** with OpenClaw node host + llama.cpp server
- **Persistent volumes** for models and OpenClaw config
- **Host networking** to use host's Tailscale connection
- **GPU acceleration** via CUDA

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ATLAS_GATEWAY_HOST` | `atlas` | OpenClaw gateway hostname |
| `ATLAS_GATEWAY_PORT` | `18789` | OpenClaw gateway port |
| `WORKER_NAME` | `atlas-worker-<hostname>` | Worker identification name |
| `ATLAS_GATEWAY_TOKEN` | _(empty)_ | Authentication token for gateway |
| `MODEL_NAME` | _(empty)_ | Specific model filename to use |
| `LLAMA_GPU_LAYERS` | `99` | GPU layers for offloading |
| `LLAMA_CTX_SIZE` | `8192` | Context window size |
| `LLAMA_PORT` | `8080` | llama-server port |

Create a `.env` file to customize:

```bash
ATLAS_GATEWAY_HOST=your-gateway-host
ATLAS_GATEWAY_TOKEN=your-token
WORKER_NAME=my-worker
MODEL_NAME=Qwen3-30B-A3B-Q4_K_M.gguf
```

## Downloading Models

Use the provided script to download models into the persistent volume:

```bash
./download-model.sh https://huggingface.co/Qwen/Qwen3-30B-A3B-GGUF/resolve/main/Qwen3-30B-A3B-Q4_K_M.gguf
```

Models are stored in the `models` Docker volume and persist across container rebuilds.

## Updating

To update the worker (models persist):

```bash
git pull
docker compose build --no-cache
docker compose up -d
```

## Troubleshooting

### Container Status
```bash
docker compose logs atlas-worker     # View logs
docker compose ps                    # Check status
```

### GPU Issues
```bash
nvidia-smi                          # Check GPU availability
docker run --rm --gpus all nvidia/cuda:12.4.0-runtime-ubuntu22.04 nvidia-smi
```

### Network Connectivity
```bash
# From host, check Tailscale
tailscale status

# Test gateway connection
telnet <gateway-host> 18789
```

### Model Issues
```bash
# List downloaded models
docker compose exec atlas-worker ls -la /models/

# Download a test model
./download-model.sh https://huggingface.co/microsoft/DialoGPT-small/resolve/main/pytorch_model.bin
```

### OpenClaw Node Issues
```bash
# Check OpenClaw logs
docker compose exec atlas-worker openclaw node status

# Restart just the worker
docker compose restart atlas-worker
```

## Volumes

- `models:/models` - Persistent model storage
- `openclaw-config:/root/.openclaw` - OpenClaw configuration and state

## Ports

- `8080` - llama-server (configurable via `LLAMA_PORT`)
- OpenClaw uses dynamic ports through the gateway connection

## Development

### Building Locally
```bash
docker compose build
```

### Running in Development Mode
```bash
# With custom environment
WORKER_NAME=dev-worker docker compose up
```

### Accessing the Container
```bash
docker compose exec atlas-worker bash
```

## License

This project follows the same license as OpenClaw and llama.cpp.