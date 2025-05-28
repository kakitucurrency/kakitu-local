#!/bin/bash

# Stop and remove any existing containers
echo "Stopping and removing existing containers..."
docker stop kakitu_genesis kakitu_node1 kakitu_node2 2>/dev/null || true
docker rm kakitu_genesis kakitu_node1 kakitu_node2 2>/dev/null || true

# Create a Docker network for the nodes
echo "Creating Docker network..."
docker network create kakitu_net || true

# Start the genesis node
echo "Starting genesis node..."
docker run -d --name kakitu_genesis \
  --user nanocurrency \
  --network kakitu_net \
  -p 45000:17076 -p 44000:17075 -p 47000:17078 \
  -v kakitu_genesis_data:/home/nanocurrency/KakituDev \
  kakitucurrency/kakitu-node:latest \
  /bin/bash -c "kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev && \
                kakitu_node daemon --network=dev --data_path=/home/nanocurrency/KakituDev & \
                sleep 5 && \
                kakitu_rpc --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & \
                tail -f /dev/null"

# Wait for genesis node to start
echo "Waiting for genesis node to initialize..."
sleep 10

# Get the genesis node's IP address
GENESIS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kakitu_genesis)
echo "Genesis node IP: $GENESIS_IP"

# Start node 1
echo "Starting node 1..."
docker run -d --name kakitu_node1 \
  --user nanocurrency \
  --network kakitu_net \
  -p 45001:17076 -p 44001:17075 -p 47001:17078 \
  -v kakitu_node1_data:/home/nanocurrency/KakituDev \
  kakitucurrency/kakitu-node:latest \
  /bin/bash -c "kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev && \
                kakitu_node daemon --network=dev --data_path=/home/nanocurrency/KakituDev --config=node.peers=[\"::ffff:$GENESIS_IP\"] & \
                sleep 5 && \
                kakitu_rpc --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & \
                tail -f /dev/null"

# Start node 2
echo "Starting node 2..."
docker run -d --name kakitu_node2 \
  --user nanocurrency \
  --network kakitu_net \
  -p 45002:17076 -p 44002:17075 -p 47002:17078 \
  -v kakitu_node2_data:/home/nanocurrency/KakituDev \
  kakitucurrency/kakitu-node:latest \
  /bin/bash -c "kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev && \
                kakitu_node daemon --network=dev --data_path=/home/nanocurrency/KakituDev --config=node.peers=[\"::ffff:$GENESIS_IP\"] & \
                sleep 5 && \
                kakitu_rpc --daemon --network=dev --data_path=/home/nanocurrency/KakituDev & \
                tail -f /dev/null"

echo "Kakitu network is starting up..."
echo "Genesis Node RPC: http://127.0.0.1:45000"
echo "Node 1 RPC: http://127.0.0.1:45001"
echo "Node 2 RPC: http://127.0.0.1:45002"
echo ""
echo "Waiting for nodes to complete initialization..."
sleep 10

# Create a wallet on the genesis node and get an address
echo "Creating a wallet on the genesis node..."
WALLET_ID=$(curl -s -d '{"action": "wallet_create"}' http://127.0.0.1:45000 | grep -o '"wallet": "[^"]*"' | cut -d'"' -f4)

if [ -n "$WALLET_ID" ]; then
  echo "Created wallet: $WALLET_ID"
  
  # Create an account in the wallet
  echo "Creating an account in the wallet..."
  ACCOUNT=$(curl -s -d "{\"action\": \"account_create\", \"wallet\": \"$WALLET_ID\"}" http://127.0.0.1:45000 | grep -o '"account": "[^"]*"' | cut -d'"' -f4)
  
  if [ -n "$ACCOUNT" ]; then
    echo "Created account: $ACCOUNT"
    echo "Network is ready for use!"
  else
    echo "Failed to create account. RPC service may not be fully ready."
  fi
else
  echo "Failed to create wallet. RPC service may not be fully ready."
  echo "Try again in a few moments by running:"
  echo "curl -s -d '{\"action\": \"version\"}' http://127.0.0.1:45000"
fi

echo "All nodes started. Network is initializing."