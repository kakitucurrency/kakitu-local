#!/bin/bash
set -ex

# Clean up any existing containers
docker stop kakitu_node 2>/dev/null || true
docker rm kakitu_node 2>/dev/null || true

# Remove any existing volume
docker volume rm kakitu_data 2>/dev/null || true

# Create fresh volume
docker volume create kakitu_data

# Initialize the node
echo "Initializing data directory..."
docker run --rm -v kakitu_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev

# Start the node with bash to keep it running
echo "Starting Kakitu node..."
docker run -d --name kakitu_node \
  -p 44000:17075 -p 45000:17076 -p 47000:17078 \
  -v kakitu_data:/home/nanocurrency/KakituDev \
  --user nanocurrency \
  kakitucurrency/kakitu-node:latest \
  /bin/bash -c "kakitu_node --daemon --rpc.enable=true --rpc.address=::ffff:0.0.0.0 --network=dev --data_path=/home/nanocurrency/KakituDev & tail -f /dev/null"

# Wait for the node to start
echo "Waiting for node to start..."
sleep 10

# Check if the node is running
echo "Checking node status..."
docker ps | grep kakitu_node
docker exec kakitu_node ps aux | grep kakitu

# Skip installing curl due to permission issues
echo "Skipping curl installation due to permission issues..."

# Skip internal RPC test
echo "Skipping internal RPC test..."

# Test RPC from host
echo "Testing RPC from host..."
curl -s -d '{"action": "block_count"}' http://127.0.0.1:45000 | grep -v libcuda

echo "Kakitu network setup complete!"