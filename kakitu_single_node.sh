#!/bin/bash
# kakitu_single_node.sh - Deploy a single Kakitu node with RPC
# This is a simplified version of our final RPC solution

set -e

# Variables for Kakitu node
KAKITU_NAME="kakitu_node"
KAKITU_TAG="ubuntu22"  # Using Ubuntu 22.04 image
KAKITU_HOST_DIR="/tmp/kakitu_data"
RPC_PORT=17076
PEERING_PORT=17075
WEBSOCKET_PORT=17078

# Stop any running containers and clean up
echo "Cleaning up any existing containers..."
docker stop $KAKITU_NAME 2>/dev/null || true
docker rm $KAKITU_NAME 2>/dev/null || true
rm -rf $KAKITU_HOST_DIR
mkdir -p $KAKITU_HOST_DIR

# Create config-node.toml with correct IPC settings
cat > $KAKITU_HOST_DIR/config-node.toml << EOL
[node]
# Logging
logging.log_to_cerr = true
logging.max_size = 134217728
logging.rotation_size = 4194304
logging.flush = true

# Node identity
peering_port = $PEERING_PORT
enable_voting = true

# Enable WebSocket server
websocket.enable = true
websocket.address = "::ffff:0.0.0.0"
websocket.port = $WEBSOCKET_PORT

# RPC settings
enable_control = true

[rpc]
enable = true
enable_sign_hash = true

[node.ipc]
tcp_server_enabled = true
tcp_server_port = 7076
tcp_server_address = "::1"
EOL

# Create config-rpc.toml
cat > $KAKITU_HOST_DIR/config-rpc.toml << EOL
address = "::ffff:0.0.0.0"
enable_control = true
enable_sign_hash = true
port = $RPC_PORT

[node.ipc]
tcp_server_enabled = true
tcp_server_address = "::1"
tcp_server_port = 7076

[logging]
log_rpc = true
EOL

# Create a simple entrypoint script
cat > $KAKITU_HOST_DIR/entrypoint.sh << EOL
#!/bin/bash
set -e

# Initialize node data if needed
kakitu_node --initialize --network=dev --data_path=/root

# Start the node with data_path
kakitu_node --daemon --network=dev --data_path=/root &
NODE_PID=\$!

# Wait for the node to initialize
echo "Waiting for node to initialize..."
sleep 5

# Start the RPC service
echo "Starting RPC service..."
kakitu_rpc --daemon --network=dev --data_path=/root &
RPC_PID=\$!

# Monitor processes
echo "Node process (PID: \$NODE_PID) and RPC process (PID: \$RPC_PID) started"
echo "Node config: /root/config-node.toml"
echo "RPC config: /root/config-rpc.toml"

# Keep the container running
tail -f /dev/null
EOL

# Make the script executable
chmod +x $KAKITU_HOST_DIR/entrypoint.sh

# Start the node container with our custom entrypoint
echo "Starting Kakitu node with RPC..."
docker run --restart=unless-stopped -d \
  -p $PEERING_PORT:$PEERING_PORT \
  -p $RPC_PORT:$RPC_PORT \
  -p $WEBSOCKET_PORT:$WEBSOCKET_PORT \
  -v $KAKITU_HOST_DIR:/root \
  --name $KAKITU_NAME \
  --entrypoint /root/entrypoint.sh \
  kakitucurrency/kakitu-node:$KAKITU_TAG

# Wait for the node to start
echo "Waiting for node to start..."
sleep 15

# Check container status
echo "Container status:"
docker ps | grep $KAKITU_NAME

# Install tools for RPC testing
echo "Installing curl for RPC tests..."
docker exec -u root $KAKITU_NAME apt-get update -qq && docker exec -u root $KAKITU_NAME apt-get install -y curl -qq

# Test RPC functionality
echo "Testing RPC functionality..."
docker exec $KAKITU_NAME curl -s -d '{"action": "version"}' http://127.0.0.1:$RPC_PORT | jq . || echo "Version check failed"
docker exec $KAKITU_NAME curl -s -d '{"action": "block_count"}' http://127.0.0.1:$RPC_PORT | jq . || echo "Block count check failed"

# Create a wallet and account
echo "Creating a wallet and account..."
WALLET=$(docker exec $KAKITU_NAME curl -s -d '{"action": "wallet_create"}' http://127.0.0.1:$RPC_PORT | grep -o '"wallet":"[^"]*"' | cut -d'"' -f4)
ACCOUNT=$(docker exec $KAKITU_NAME curl -s -d "{\"action\": \"account_create\", \"wallet\": \"$WALLET\"}" http://127.0.0.1:$RPC_PORT | grep -o '"account":"[^"]*"' | cut -d'"' -f4)

echo "=============================="
echo "Kakitu Node Setup Complete!"
echo "=============================="
echo "Node container: $KAKITU_NAME"
echo "Data directory: $KAKITU_HOST_DIR"
echo "RPC port: $RPC_PORT"
echo "Peering port: $PEERING_PORT"
echo "WebSocket port: $WEBSOCKET_PORT"
echo "Wallet: $WALLET"
echo "Account: $ACCOUNT"
echo ""
echo "RPC endpoint: http://127.0.0.1:$RPC_PORT"
echo "To check logs: docker logs $KAKITU_NAME"
echo "To stop the node: docker stop $KAKITU_NAME"
echo "To remove the container: docker rm $KAKITU_NAME"
echo "=============================="