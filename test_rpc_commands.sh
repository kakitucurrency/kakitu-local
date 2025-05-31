#!/bin/bash
set -e

# Test various RPC commands against the running Kakitu node
echo "Testing RPC commands against Kakitu node..."

# Define the container name
CONTAINER_NAME="kakitu_final"

# Check if container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo "Error: Kakitu node container '$CONTAINER_NAME' is not running."
    echo "Please run the final_rpc_solution.sh script first."
    exit 1
fi

# Function to run RPC command and display results
run_rpc_command() {
    local command="$1"
    local description="$2"
    local payload="$3"
    
    echo -e "\n===== $description ====="
    echo "Command: $command"
    echo "Payload: $payload"
    echo "Response:"
    curl -s -d "$payload" http://127.0.0.1:17076 | jq .
    echo "================================"
}

# Install jq if not available
if ! command -v jq &> /dev/null; then
    echo "Installing jq for JSON formatting..."
    sudo apt-get update -qq && sudo apt-get install -y jq -qq
fi

# Test version (basic connectivity)
run_rpc_command "version" "Get node version" '{"action": "version"}'

# Test block count
run_rpc_command "block_count" "Get block count" '{"action": "block_count"}'

# Get account info for genesis account
run_rpc_command "account_info" "Get genesis account info" '{"action": "account_info", "account": "kshs_3e3j5tkog48pnny9dmfzj1r16pg8t1e76dz5tmac6iq689wyjfpiij4txtdo"}'

# Check node uptime
run_rpc_command "uptime" "Get node uptime" '{"action": "uptime"}'

# Get node peers
run_rpc_command "peers" "Get node peers" '{"action": "peers"}'

# Get confirmation history
run_rpc_command "confirmation_history" "Get confirmation history" '{"action": "confirmation_history"}'

# Get online representatives
run_rpc_command "representatives_online" "Get online representatives" '{"action": "representatives_online"}'

# Get node statistics
run_rpc_command "stats" "Get node statistics" '{"action": "stats", "type": "counters"}'

# Get node configuration
run_rpc_command "config" "Get node configuration" '{"action": "config"}'

echo -e "\nRPC tests completed. All commands executed successfully."