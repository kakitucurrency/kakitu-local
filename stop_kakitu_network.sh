#!/bin/bash
# stop_kakitu_network.sh - Stop and clean up the Kakitu network

# Configuration
NETWORK_NAME="kakitu_network"
NODE_COUNT=4  # Should match the number in deploy_kakitu_network.sh
BASE_DATA_DIR="/tmp/kakitu_network_data"

# Stop and remove containers
echo "Stopping Kakitu network containers..."
for ((i=0; i<NODE_COUNT; i++)); do
    CONTAINER_NAME="${NETWORK_NAME}_node${i}"
    echo "Stopping $CONTAINER_NAME..."
    docker stop $CONTAINER_NAME 2>/dev/null || echo "Container $CONTAINER_NAME not running"
    docker rm $CONTAINER_NAME 2>/dev/null || echo "Container $CONTAINER_NAME not found"
done

# Ask to remove data directories
read -p "Do you want to remove data directories? (y/n): " REMOVE_DATA
if [[ $REMOVE_DATA == "y" || $REMOVE_DATA == "Y" ]]; then
    echo "Removing data directories..."
    rm -rf $BASE_DATA_DIR
    echo "Data directories removed."
else
    echo "Data directories preserved at $BASE_DATA_DIR"
fi

echo "Kakitu network has been stopped."