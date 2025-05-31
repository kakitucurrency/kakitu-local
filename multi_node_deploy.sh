#!/bin/bash
# multi_node_deploy.sh - Deploy multiple Kakitu nodes with working RPC
# This script uses different ports for each node to avoid conflicts

set -e

# Configuration
NETWORK_NAME="kakitu_network"
DOCKER_NETWORK="kakitu_net"
KAKITU_TAG="ubuntu22"  # Using Ubuntu 22.04 image
NODE_COUNT=3  # Number of nodes to deploy (3 is recommended for testing)
BASE_DATA_DIR="/tmp/kakitu_multi_data"

# Port configurations (each node gets its own set of ports)
# Node 0
RPC_PORT_0=17076
PEERING_PORT_0=17075
WEBSOCKET_PORT_0=17078

# Node 1
RPC_PORT_1=17176
PEERING_PORT_1=17175
WEBSOCKET_PORT_1=17178

# Node 2
RPC_PORT_2=17276
PEERING_PORT_2=17275
WEBSOCKET_PORT_2=17278

# First, clean up any existing containers
echo "Cleaning up any existing containers and data..."
for ((i=0; i<NODE_COUNT; i++)); do
    CONTAINER_NAME="${NETWORK_NAME}_node${i}"
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
done

# Remove any existing Docker network
docker network rm $DOCKER_NETWORK 2>/dev/null || true

# Create Docker network
echo "Creating Docker network: $DOCKER_NETWORK"
docker network create $DOCKER_NETWORK

# Clean up data directories
rm -rf $BASE_DATA_DIR
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
    
    # Set ports based on node index
    if [ $i -eq 0 ]; then
        RPC_PORT=$RPC_PORT_0
        PEERING_PORT=$PEERING_PORT_0
        WEBSOCKET_PORT=$WEBSOCKET_PORT_0
    elif [ $i -eq 1 ]; then
        RPC_PORT=$RPC_PORT_1
        PEERING_PORT=$PEERING_PORT_1
        WEBSOCKET_PORT=$WEBSOCKET_PORT_1
    elif [ $i -eq 2 ]; then
        RPC_PORT=$RPC_PORT_2
        PEERING_PORT=$PEERING_PORT_2
        WEBSOCKET_PORT=$WEBSOCKET_PORT_2
    fi
    
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
    
    # Set ports based on node index
    if [ $i -eq 0 ]; then
        RPC_PORT=$RPC_PORT_0
        PEERING_PORT=$PEERING_PORT_0
        WEBSOCKET_PORT=$WEBSOCKET_PORT_0
    elif [ $i -eq 1 ]; then
        RPC_PORT=$RPC_PORT_1
        PEERING_PORT=$PEERING_PORT_1
        WEBSOCKET_PORT=$WEBSOCKET_PORT_1
    elif [ $i -eq 2 ]; then
        RPC_PORT=$RPC_PORT_2
        PEERING_PORT=$PEERING_PORT_2
        WEBSOCKET_PORT=$WEBSOCKET_PORT_2
    fi
    
    echo "Starting node $i (RPC port $RPC_PORT, Peering port $PEERING_PORT)..."
    docker run --restart=unless-stopped -d \
      -p $RPC_PORT:$RPC_PORT \
      -p $PEERING_PORT:$PEERING_PORT \
      -p $WEBSOCKET_PORT:$WEBSOCKET_PORT \
      -v $NODE_DIR:/root \
      --name ${NETWORK_NAME}_node${i} \
      --entrypoint /root/entrypoint.sh \
      --network=$DOCKER_NETWORK \
      kakitucurrency/kakitu-node:$KAKITU_TAG
done

# Wait for nodes to start
echo "Waiting for nodes to start..."
sleep 15

# Install curl for RPC testing
echo "Installing curl for RPC tests..."
docker exec -u root ${NETWORK_NAME}_node0 apt-get update -qq && docker exec -u root ${NETWORK_NAME}_node0 apt-get install -y curl jq -qq

# Test RPC on each node
echo "Testing RPC on all nodes..."
docker exec ${NETWORK_NAME}_node0 curl -s -d '{"action": "version"}' http://127.0.0.1:$RPC_PORT_0 | docker exec -i ${NETWORK_NAME}_node0 jq .
docker exec ${NETWORK_NAME}_node0 curl -s -d '{"action": "version"}' http://${NETWORK_NAME}_node1:$RPC_PORT_1 | docker exec -i ${NETWORK_NAME}_node0 jq .
docker exec ${NETWORK_NAME}_node0 curl -s -d '{"action": "version"}' http://${NETWORK_NAME}_node2:$RPC_PORT_2 | docker exec -i ${NETWORK_NAME}_node0 jq .

# Create a wallet on the genesis node
echo "Creating a wallet on genesis node..."
WALLET=$(docker exec ${NETWORK_NAME}_node0 curl -s -d '{"action": "wallet_create"}' http://127.0.0.1:$RPC_PORT_0 | grep -o '"wallet":"[^"]*"' | cut -d'"' -f4)
echo "Created wallet: $WALLET"

# Create an account in the wallet
echo "Creating an account in the wallet..."
ACCOUNT=$(docker exec ${NETWORK_NAME}_node0 curl -s -d "{\"action\": \"account_create\", \"wallet\": \"$WALLET\"}" http://127.0.0.1:$RPC_PORT_0 | grep -o '"account":"[^"]*"' | cut -d'"' -f4)
echo "Created account: $ACCOUNT"

# Summary
echo "============================="
echo "Kakitu Multi-Node Summary:"
echo "============================="
echo "Number of nodes: $NODE_COUNT"
echo "Network data directory: $BASE_DATA_DIR"
echo "Docker network: $DOCKER_NETWORK"
echo ""
echo "Node details:"
echo "  Node 0 (genesis):"
echo "    Container: ${NETWORK_NAME}_node0"
echo "    RPC: http://127.0.0.1:$RPC_PORT_0"
echo "    Peering port: $PEERING_PORT_0"
echo "    WebSocket: ws://127.0.0.1:$WEBSOCKET_PORT_0"
echo "    Wallet: $WALLET"
echo "    Account: $ACCOUNT"
echo ""
echo "  Node 1:"
echo "    Container: ${NETWORK_NAME}_node1"
echo "    RPC: http://127.0.0.1:$RPC_PORT_1"
echo "    Peering port: $PEERING_PORT_1"
echo "    WebSocket: ws://127.0.0.1:$WEBSOCKET_PORT_1"
echo ""
echo "  Node 2:"
echo "    Container: ${NETWORK_NAME}_node2"
echo "    RPC: http://127.0.0.1:$RPC_PORT_2"
echo "    Peering port: $PEERING_PORT_2"
echo "    WebSocket: ws://127.0.0.1:$WEBSOCKET_PORT_2"
echo ""
echo "To check logs: docker logs ${NETWORK_NAME}_node0"
echo "To stop the network: docker stop ${NETWORK_NAME}_node0 ${NETWORK_NAME}_node1 ${NETWORK_NAME}_node2"
echo "=============================="