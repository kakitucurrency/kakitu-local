#!/bin/bash
# build_kakitu_ubuntu22.sh - Build Kakitu Docker image based on Ubuntu 22.04
set -ex

# Set image name
IMAGE_NAME="kakitucurrency/kakitu-node:ubuntu22"

echo "Building Kakitu Docker image based on Ubuntu 22.04..."

# Check for kakitu binaries in parent directory
if [ ! -f "../nano_node" ] || [ ! -f "../nano_rpc" ]; then
    echo "Error: Kakitu binaries (nano_node and nano_rpc) not found in parent directory"
    echo "Please compile Kakitu and place the binaries in the parent directory"
    exit 1
fi

# Copy executables from parent directory
cp ../nano_node .
cp ../nano_rpc .

# Verify files exist
if [ ! -f "nano_node" ] || [ ! -f "nano_rpc" ]; then
    echo "Error: Required executable files not found"
    exit 1
fi

# Create Dockerfile for Ubuntu 22.04
cat > Dockerfile.ubuntu22 << EOL
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libboost-system1.74.0 \
    libboost-thread1.74.0 \
    libboost-log1.74.0 \
    libboost-program-options1.74.0 \
    libboost-filesystem1.74.0 \
    libgcc-s1 \
    libstdc++6 \
    libc6 \
    && rm -rf /var/lib/apt/lists/*

# Create user for running node
RUN groupadd --gid 1000 nanocurrency && \
    useradd --uid 1000 --gid nanocurrency --shell /bin/bash --create-home nanocurrency

# Copy Kakitu binaries
COPY nano_node /usr/bin/kakitu_node
COPY nano_rpc /usr/bin/kakitu_rpc

# Set permissions
RUN chmod +x /usr/bin/kakitu_node /usr/bin/kakitu_rpc && \
    chown nanocurrency:nanocurrency /usr/bin/kakitu_node /usr/bin/kakitu_rpc

USER nanocurrency
WORKDIR /home/nanocurrency

ENTRYPOINT ["kakitu_node"]
CMD ["--daemon", "--network=dev"]
EOL

# Build the Docker image
docker build -f Dockerfile.ubuntu22 -t $IMAGE_NAME .

# Clean up copied executables
rm -f nano_node nano_rpc
rm -f Dockerfile.ubuntu22

if [ $? -eq 0 ]; then
    echo "Successfully built Docker image: $IMAGE_NAME"
    echo "You can now run the Kakitu node with:"
    echo "./kakitu_single_node.sh   # for a single node"
    echo "./deploy_kakitu_network.sh # for a multi-node network"
else
    echo "Failed to build Docker image"
    exit 1
fi