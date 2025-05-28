#!/bin/bash
set -ex

# Clean up any existing containers
docker stop kakitu_genesis kakitu_node1 kakitu_node2 2>/dev/null || true
docker rm kakitu_genesis kakitu_node1 kakitu_node2 2>/dev/null || true

# Create a Docker network for the nodes to communicate
docker network create --driver bridge kakitu_network

# Initialize genesis node
echo "Initializing and starting genesis node..."
docker volume rm kakitu_genesis_data 2>/dev/null || true
docker volume create kakitu_genesis_data

# Initialize genesis data
docker run --rm -v kakitu_genesis_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev

# Start genesis node with bash to keep it running, including RPC service
docker run -d --name kakitu_genesis \
  --network kakitu_network \
  -p 44000:17075 -p 45000:17076 -p 47000:17078 \
  -v kakitu_genesis_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  /bin/bash -c "kakitu_node --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & sleep 5 && kakitu_rpc --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & tail -f /dev/null"

# Get genesis node ID
sleep 5
GENESIS_NODE_ID=$(docker exec kakitu_genesis cat /home/nanocurrency/KakituDev/log/log_*.log | grep "Node ID:" | tail -1 | awk '{print $4}')
GENESIS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kakitu_genesis)

echo "Genesis node ID: $GENESIS_NODE_ID"
echo "Genesis node IP: $GENESIS_IP"

# Initialize and start node 1
echo "Initializing and starting node 1..."
docker volume rm kakitu_node1_data 2>/dev/null || true
docker volume create kakitu_node1_data

# Initialize node 1 data
docker run --rm -v kakitu_node1_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev

# Start node 1 with bash to keep it running, including RPC service
docker run -d --name kakitu_node1 \
  --network kakitu_network \
  -p 44001:17075 -p 45001:17076 -p 47001:17078 \
  -v kakitu_node1_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  /bin/bash -c "kakitu_node --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & sleep 5 && kakitu_rpc --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & tail -f /dev/null"

# Initialize and start node 2
echo "Initializing and starting node 2..."
docker volume rm kakitu_node2_data 2>/dev/null || true
docker volume create kakitu_node2_data

# Initialize node 2 data
docker run --rm -v kakitu_node2_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev

# Start node 2 with bash to keep it running, including RPC service
docker run -d --name kakitu_node2 \
  --network kakitu_network \
  -p 44002:17075 -p 45002:17076 -p 47002:17078 \
  -v kakitu_node2_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  /bin/bash -c "kakitu_node --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & sleep 5 && kakitu_rpc --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & tail -f /dev/null"

# Wait for nodes to start
sleep 5

# Display running containers
echo "Running nodes:"
docker ps | grep kakitu

echo "Multi-node Kakitu network setup complete!"
echo "Genesis node accessible at: 127.0.0.1:45000"
echo "Node 1 accessible at: 127.0.0.1:45001"
echo "Node 2 accessible at: 127.0.0.1:45002"