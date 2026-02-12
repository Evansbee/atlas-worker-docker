#!/bin/bash

set -e

echo "🚀 Atlas Worker Docker Setup"
echo "=============================="

# Detect platform and GPU support
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - check if Apple Silicon
        if [[ $(uname -m) == "arm64" ]]; then
            echo "📱 Detected: macOS Apple Silicon"
            PLATFORM="metal"
        else
            echo "💻 Detected: macOS Intel (using CPU-only build)"
            PLATFORM="cpu"
        fi
    else
        # Linux/WSL - check for NVIDIA GPU
        if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
            echo "🖥️  Detected: Linux/WSL with NVIDIA GPU"
            PLATFORM="cuda"
        else
            echo "🖥️  Detected: Linux without NVIDIA GPU (using CPU-only build)"
            PLATFORM="cpu"
        fi
    fi
}

# Check prerequisites
check_prerequisites() {
    echo ""
    echo "🔍 Checking prerequisites..."
    
    # Docker
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker Desktop."
        exit 1
    fi
    
    # Docker Compose
    if ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose is not available. Please install Docker Desktop or docker-compose-plugin."
        exit 1
    fi
    
    echo "✅ Docker and Docker Compose are available"
    
    # Platform-specific checks
    if [[ "$PLATFORM" == "cuda" ]]; then
        # Check NVIDIA Container Toolkit
        if ! docker run --rm --gpus all nvidia/cuda:12.4.0-runtime-ubuntu22.04 nvidia-smi &> /dev/null; then
            echo "⚠️  NVIDIA Container Toolkit may not be properly installed."
            echo "   Please install it from: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
            echo ""
            read -p "Continue anyway? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            echo "✅ NVIDIA Container Toolkit is working"
        fi
    elif [[ "$PLATFORM" == "metal" ]]; then
        echo "✅ Apple Silicon Metal support will be enabled"
    else
        echo "ℹ️  CPU-only build will be used"
    fi
    
    # Tailscale check (optional)
    if ! command -v tailscale &> /dev/null; then
        echo "⚠️  Tailscale not detected. The worker needs network connectivity to the gateway."
        echo "   Install Tailscale if you plan to use it for networking."
    else
        echo "✅ Tailscale is available"
    fi
}

# Build and start
build_and_start() {
    echo ""
    echo "🔨 Building Atlas Worker..."
    
    case "$PLATFORM" in
        "cuda")
            echo "Building with CUDA support..."
            export GPU_BACKEND=cuda
            docker compose build
            ;;
        "metal")
            echo "Building with Metal support..."
            export GPU_BACKEND=metal
            docker compose -f docker-compose.yml -f docker-compose.metal.yml build
            ;;
        "cpu")
            echo "Building CPU-only version..."
            export GPU_BACKEND=cpu
            docker compose build
            ;;
    esac
    
    echo ""
    echo "🚀 Starting Atlas Worker..."
    
    case "$PLATFORM" in
        "metal")
            docker compose -f docker-compose.yml -f docker-compose.metal.yml up -d
            ;;
        *)
            docker compose up -d
            ;;
    esac
    
    echo ""
    echo "✅ Atlas Worker is starting!"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Download a model: ./download-model.sh <huggingface-url>"
    echo "   2. Check logs: docker compose logs -f atlas-worker"
    echo "   3. Check status: docker compose ps"
    echo ""
    echo "🔧 Configuration:"
    echo "   - Platform: $PLATFORM"
    echo "   - Models volume: atlas-worker-docker_models"
    echo "   - Config volume: atlas-worker-docker_openclaw-config"
    echo ""
    
    if [[ -f ".env" ]]; then
        echo "   - Using .env file for configuration"
    else
        echo "   - Create .env file to customize settings (see README.md)"
    fi
}

# Main execution
main() {
    detect_platform
    check_prerequisites
    build_and_start
}

# Handle command line args
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --force-cuda  Force CUDA build (skip detection)"
        echo "  --force-metal Force Metal build (skip detection)"
        echo "  --force-cpu   Force CPU build (skip detection)"
        echo ""
        echo "The script auto-detects your platform by default."
        exit 0
        ;;
    "--force-cuda")
        PLATFORM="cuda"
        echo "🔧 Forcing CUDA build..."
        ;;
    "--force-metal")
        PLATFORM="metal" 
        echo "🔧 Forcing Metal build..."
        ;;
    "--force-cpu")
        PLATFORM="cpu"
        echo "🔧 Forcing CPU build..."
        ;;
    "")
        # No args - run detection
        detect_platform
        ;;
    *)
        echo "Unknown argument: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
esac

if [[ -z "$PLATFORM" ]]; then
    detect_platform
fi

check_prerequisites
build_and_start