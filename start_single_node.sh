#!/bin/bash

# Clean up any existing containers
docker stop kakitu_single 2>/dev/null || true
docker rm kakitu_single 2>/dev/null || true

# Create a configuration file for the RPC server
mkdir -p config
cat > config/rpc-config.toml << EOF
enable_control = true
address = "0.0.0.0"
port = 17076
EOF

# Create a script to run inside the container
cat > config/start.sh << EOF
#!/bin/bash
set -e

# Initialize the data directory
echo "Initializing data directory..."
kakitu_node --initialize --network=dev --data_path=/home/nanocurrency/KakituDev

# Start the node daemon in the background
echo "Starting node daemon..."
kakitu_node daemon --network=dev --data_path=/home/nanocurrency/KakituDev &
NODE_PID=\$!

# Wait for the node to start
sleep 5

# Write RPC config
mkdir -p /home/nanocurrency/KakituDev
# No config file for RPC, use command line options instead

# Start the RPC server
echo "Starting RPC server..."
kakitu_rpc --daemon --network=dev --data_path=/home/nanocurrency/KakituDev &
RPC_PID=\$!

echo "Node started with PID: \$NODE_PID"
echo "RPC started with PID: \$RPC_PID"

# Keep the container running
tail -f /dev/null
EOF

chmod +x config/start.sh

# Run the container
docker run -d --name kakitu_single \
  --user nanocurrency \
  -p 45000:17076 -p 44000:17075 -p 47000:17078 \
  -v $(pwd)/config:/home/nanocurrency/config \
  -v kakitu_single_data:/home/nanocurrency/KakituDev \
  kakitucurrency/kakitu-node:latest \
  /home/nanocurrency/config/start.sh

echo "Kakitu node starting..."
echo "RPC endpoint: http://127.0.0.1:45000"
echo "Waiting for initialization..."
sleep 20

# Test if the node is responding
echo "Testing node connectivity..."
curl -s -d '{"action": "version"}' http://127.0.0.1:45000

echo ""
echo "Try creating a wallet with:"
echo "curl -s -d '{\"action\": \"wallet_create\"}' http://127.0.0.1:45000"