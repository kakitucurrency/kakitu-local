#!/bin/bash
# deploy_kakitu_network.sh - Deploy a multi-node Kakitu network with RPC
# This script combines the best parts of our RPC solution with multi-node setup

set -e

# Configuration
NETWORK_NAME="kakitu_network"
KAKITU_TAG="ubuntu22"  # Using Ubuntu 22.04 image
NODE_COUNT=4  # Number of nodes to create (1 genesis + N-1 peers)
BASE_DATA_DIR="/tmp/kakitu_network_data"
BASE_RPC_PORT=17076
BASE_PEERING_PORT=17075
BASE_WEBSOCKET_PORT=17078

# Stop and remove any existing containers
echo "Cleaning up any existing containers and data..."
for ((i=0; i<NODE_COUNT; i++)); do
    CONTAINER_NAME="${NETWORK_NAME}_node${i}"
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    rm -rf $BASE_DATA_DIR/node${i}
done

# Create data directories
echo "Creating data directories..."
for ((i=0; i<NODE_COUNT; i++)); do
    mkdir -p $BASE_DATA_DIR/node${i}
done

# Generate peer names for configuration
PEER_NAMES=""
for ((i=0; i<NODE_COUNT; i++)); do
    if [ $i -gt 0 ]; then
        PEER_NAMES="${PEER_NAMES}, "
    fi
    PEER_NAMES="${PEER_NAMES}\"${NETWORK_NAME}_node${i}\""
done

# Create configuration files and entrypoint scripts for each node
echo "Creating configuration files..."
for ((i=0; i<NODE_COUNT; i++)); do
    NODE_DIR="$BASE_DATA_DIR/node${i}"
    RPC_PORT=$((BASE_RPC_PORT + i))
    PEERING_PORT=$((BASE_PEERING_PORT + i))
    WEBSOCKET_PORT=$((BASE_WEBSOCKET_PORT + i))
    
    # Create node config
    cat > $NODE_DIR/config-node.toml << EOL
[node]
# Logging
logging.log_to_cerr = true
logging.max_size = 134217728
logging.rotation_size = 4194304
logging.flush = true

# Node identity
peering_port = $PEERING_PORT
enable_voting = true
preconfigured_peers = [
    ${PEER_NAMES}
]
allow_local_peers = true

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

    # Create RPC config
    cat > $NODE_DIR/config-rpc.toml << EOL
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

    # Create entrypoint script
    cat > $NODE_DIR/entrypoint.sh << EOL
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
    chmod +x $NODE_DIR/entrypoint.sh
done

# Start Docker containers for each node
echo "Starting Kakitu network nodes..."
for ((i=0; i<NODE_COUNT; i++)); do
    NODE_DIR="$BASE_DATA_DIR/node${i}"
    RPC_PORT=$((BASE_RPC_PORT + i))
    PEERING_PORT=$((BASE_PEERING_PORT + i))
    WEBSOCKET_PORT=$((BASE_WEBSOCKET_PORT + i))
    
    echo "Starting node $i..."
    docker run --restart=unless-stopped -d \
      -p $PEERING_PORT:$PEERING_PORT \
      -p $RPC_PORT:$RPC_PORT \
      -p $WEBSOCKET_PORT:$WEBSOCKET_PORT \
      -v $NODE_DIR:/root \
      --name ${NETWORK_NAME}_node${i} \
      --entrypoint /root/entrypoint.sh \
      --network=host \
      kakitucurrency/kakitu-node:$KAKITU_TAG
done

# Wait for nodes to start
echo "Waiting for nodes to start..."
sleep 20

# Install curl for RPC testing
echo "Installing curl for RPC tests on node0..."
docker exec -u root ${NETWORK_NAME}_node0 apt-get update -qq && docker exec -u root ${NETWORK_NAME}_node0 apt-get install -y curl -qq

# Basic RPC tests on the genesis node
echo "Testing RPC on genesis node..."
docker exec ${NETWORK_NAME}_node0 curl -s -d '{"action": "version"}' http://127.0.0.1:17076 | jq . || echo "Version check failed"
docker exec ${NETWORK_NAME}_node0 curl -s -d '{"action": "block_count"}' http://127.0.0.1:17076 | jq . || echo "Block count check failed"

# Create a wallet on the genesis node
echo "Creating a wallet on genesis node..."
WALLET=$(docker exec ${NETWORK_NAME}_node0 curl -s -d '{"action": "wallet_create"}' http://127.0.0.1:17076 | grep -o '"wallet":"[^"]*"' | cut -d'"' -f4)
echo "Created wallet: $WALLET"

# Create an account in the wallet
echo "Creating an account in the wallet..."
ACCOUNT=$(docker exec ${NETWORK_NAME}_node0 curl -s -d "{\"action\": \"account_create\", \"wallet\": \"$WALLET\"}" http://127.0.0.1:17076 | grep -o '"account":"[^"]*"' | cut -d'"' -f4)
echo "Created account: $ACCOUNT"

# Summary
echo "======================="
echo "Kakitu Network Summary:"
echo "======================="
echo "Number of nodes: $NODE_COUNT"
echo "Network data directory: $BASE_DATA_DIR"
echo "Genesis node:"
echo "  Container: ${NETWORK_NAME}_node0"
echo "  RPC port: $BASE_RPC_PORT"
echo "  Peering port: $BASE_PEERING_PORT"
echo "  WebSocket port: $BASE_WEBSOCKET_PORT"
echo "  Wallet: $WALLET"
echo "  Account: $ACCOUNT"
echo ""
echo "RPC endpoints available at:"
for ((i=0; i<NODE_COUNT; i++)); do
    RPC_PORT=$((BASE_RPC_PORT + i))
    echo "  Node $i: http://127.0.0.1:$RPC_PORT"
done
echo ""
echo "To stop the network: ./stop_kakitu_network.sh"
echo "To check logs: docker logs ${NETWORK_NAME}_node0"
echo "To run RPC commands: curl -d '{\"action\": \"block_count\"}' http://127.0.0.1:$BASE_RPC_PORT"
echo "======================="