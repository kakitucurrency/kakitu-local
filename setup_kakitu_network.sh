#!/bin/bash

echo "Setting up Kakitu Local Network..."

# Copy Kakitu configuration as the main config
cp nanolocal/kakitu_config.toml nanolocal/nl_config.toml

# Create Python virtual environment if it doesn't exist
if [ ! -d "venv_nanolocal" ]; then
    echo "Creating Python virtual environment..."
    ./setup_python_venv.sh
fi

# Check if Kakitu Docker image exists
if ! docker images | grep -q "kakitucurrency/kakitu-node"; then
    echo "Kakitu Docker image not found. Building it now..."
    ./build_kakitu_image.sh
fi

echo "Kakitu network setup completed!"
echo ""
echo "Available commands:"
echo "  ./nl_run.py create     - Create network configuration"
echo "  ./nl_run.py start      - Start all nodes"
echo "  ./nl_run.py init       - Initialize network with genesis and epochs"
echo "  ./nl_run.py test       - Run network tests"
echo "  ./nl_run.py stop       - Stop all nodes"
echo "  ./nl_run.py destroy    - Remove all network data"
echo ""
echo "Network endpoints (after starting):"
echo "  Genesis Node RPC:     http://127.0.0.1:45000"
echo "  Representative 1 RPC: http://127.0.0.1:45001"
echo "  Representative 2 RPC: http://127.0.0.1:45002"
echo "  Representative 3 RPC: http://127.0.0.1:45003"