#!/bin/bash

echo "Building Kakitu Docker image..."

# Check if executables exist in parent directory
if [ ! -f "../nano_node" ] || [ ! -f "../nano_rpc" ]; then
    echo "Error: nano_node and nano_rpc executables not found in parent directory"
    echo "Please ensure the Kakitu node has been built successfully"
    exit 1
fi

# Copy executables to current directory for Docker build context
cp ../nano_node .
cp ../nano_rpc .

# Build the Docker image
docker build -f Dockerfile.kakitu -t kakitucurrency/kakitu-node:latest .

# Clean up copied executables
rm -f nano_node nano_rpc

if [ $? -eq 0 ]; then
    echo "Successfully built Docker image: kakitucurrency/kakitu-node:latest"
    echo "You can now use this image in the nano-local configuration"
else
    echo "Failed to build Docker image"
    exit 1
fi