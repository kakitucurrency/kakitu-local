# Kakitu Node with RPC Setup Guide

This guide explains how to set up a Kakitu cryptocurrency node with working RPC functionality.

## Prerequisites

- Docker installed
- Access to Kakitu node executables (`nano_node` and `nano_rpc`)
- Ubuntu 22.04 based Docker image for Kakitu

## Key Components

The Kakitu node setup consists of two main components:

1. **Node Service**: Manages the blockchain and maintains the ledger
2. **RPC Service**: Provides an HTTP API for interacting with the node

## Quick Setup

Use the `final_rpc_solution.sh` script to set up a working Kakitu node with RPC:

```bash
./final_rpc_solution.sh
```

This script will:
1. Create a data directory at `/tmp/kakitu_final_data`
2. Set up proper configuration files
3. Start a Docker container with the Kakitu node and RPC service
4. Test RPC connectivity

## Configuration Files

### Node Configuration (`config-node.toml`)

The key settings for RPC functionality are:

```toml
[node]
# Enable RPC control
enable_control = true

[rpc]
enable = true
enable_sign_hash = true

[node.ipc]
tcp_server_enabled = true
tcp_server_port = 7076
tcp_server_address = "::1"
```

### RPC Configuration (`config-rpc.toml`)

The key settings for RPC functionality are:

```toml
address = "::ffff:0.0.0.0"
enable_control = true
enable_sign_hash = true
port = 17076

[node.ipc]
tcp_server_enabled = true
tcp_server_address = "::1"
tcp_server_port = 7076
```

## Important Notes

1. **Configuration File Location**: Configuration files must be placed in the data directory
2. **IPC Settings**: The node and RPC service must use the same IPC settings to communicate
3. **GLIBC Version**: Kakitu requires newer GLIBC versions, so use Ubuntu 22.04 as the base image

## Testing RPC Functionality

Use the `test_rpc_commands.sh` script to test various RPC commands:

```bash
./test_rpc_commands.sh
```

This will run several RPC commands to verify functionality.

## Manual RPC Testing

You can test RPC commands manually using curl:

```bash
# Check node version
curl -s -d '{"action": "version"}' http://127.0.0.1:17076

# Check block count
curl -s -d '{"action": "block_count"}' http://127.0.0.1:17076

# Get account information
curl -s -d '{"action": "account_info", "account": "kshs_3e3j5tkog48pnny9dmfzj1r16pg8t1e76dz5tmac6iq689wyjfpiij4txtdo"}' http://127.0.0.1:17076
```

## Troubleshooting

### Common Issues

1. **RPC Connection Errors**: Ensure IPC settings are consistent between node and RPC configuration files
2. **GLIBC Version Errors**: Use Ubuntu 22.04 as the base Docker image
3. **Node Not Starting**: Check container logs with `docker logs kakitu_final`
4. **Command Line Arguments**: Kakitu may not support all command line options like `--config`

### Checking Logs

To check logs for the node and RPC service:

```bash
# View container logs
docker logs kakitu_final

# View logs in the data directory
ls -la /tmp/kakitu_final_data/log/
```

## Advanced Configuration

For more advanced node configuration, refer to the standard Nano documentation as Kakitu is a fork of Nano.