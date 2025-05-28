# Kakitu Network Setup - Required Modifications to nano-local

## Overview

The `nano-local` tool is a Python-based framework for creating local Nano test networks using Docker containers. To adapt it for Kakitu, we need to make several key modifications to work with our `kshs_` address prefix and custom node.

## Current nano-local Architecture

The tool works by:
1. **Docker-based Nodes**: Uses official Nano Docker images (`nanocurrency/nano-beta:V24.0DB26`)
2. **Network Configuration**: Sets up multiple nodes (genesis + 3 voting representatives)
3. **Account Management**: Uses `nanolib` Python library for account/address generation
4. **Block Creation**: Creates epoch blocks, canary blocks, and manages vote weight distribution
5. **Testing Framework**: Includes comprehensive tests for network health and block propagation

## Required Modifications for Kakitu

### 1. **Docker Image Configuration**
**File**: `nanolocal/services/default_docker-compose.yml`
**Current**: Uses `nanocurrency/nano-beta:V24.0DB26`
**Required**: 
- Build custom Docker image with our Kakitu node executables
- Update container commands to use `kakitu_node` instead of `nano_node`
- Change network parameter from `--network=test` to `--network=dev` (or appropriate Kakitu network)

### 2. **Address Prefix Support**
**File**: `nanolocal/common/nl_nanolib.py`
**Current**: Uses `AccountIDPrefix.NANO` (generates nano_ addresses)
**Required**: 
- Modify or extend `nanolib` to support `kshs_` prefix
- Alternative: Create wrapper functions that use our Kakitu node for address generation
- Update all address generation to use `kshs_` format

### 3. **Configuration Files**
**File**: `nanolocal/nl_config.example.toml`
**Required Changes**:
- Update `docker_tag` from Nano image to custom Kakitu image
- Modify network settings to match Kakitu network parameters
- Update any hardcoded Nano-specific values

### 4. **Network Constants**
**Files**: Various configuration and initialization files
**Required Changes**:
- Update epoch constants (NANO_TEST_EPOCH_*) to Kakitu equivalents
- Modify magic numbers if different from Nano
- Update burn amounts and genesis configurations

### 5. **RPC Interface Compatibility**
**File**: `nanolocal/common/nl_rpc.py`
**Current**: Makes RPC calls expecting Nano node responses
**Required**: 
- Verify RPC compatibility with Kakitu node
- Update any Nano-specific RPC calls to work with Kakitu
- Ensure account format handling works with `kshs_` addresses

## Implementation Strategy

### Phase 1: Create Kakitu Docker Image
```bash
# Create Dockerfile for Kakitu node
FROM ubuntu:20.04
COPY kakitu_node /usr/local/bin/
COPY kakitu_rpc /usr/local/bin/
# ... additional setup
```

### Phase 2: Modify Address Generation
**Option A**: Extend nanolib
- Fork nanolib and add `AccountIDPrefix.KAKITU` support
- Update all references to use new prefix

**Option B**: Use Kakitu node directly
- Replace nanolib calls with direct calls to `./kakitu_node --key_create`
- Parse output to extract address/key information

### Phase 3: Update Configuration
- Create `kakitu_config.toml` based on `nl_config.example.toml`
- Update all service configurations
- Modify Docker compose files

### Phase 4: Network Initialization
- Ensure genesis block creation works with Kakitu network
- Verify epoch block creation compatibility
- Test vote weight distribution

## Recommended Approach

### Immediate Steps:
1. **Create Custom Docker Image**:
   ```dockerfile
   FROM ubuntu:20.04
   RUN apt-get update && apt-get install -y libboost-all-dev
   COPY nano_node /usr/local/bin/kakitu_node
   COPY nano_rpc /usr/local/bin/kakitu_rpc
   RUN chmod +x /usr/local/bin/kakitu_*
   USER 1000
   CMD ["kakitu_node", "daemon", "--network=dev", "--data_path=/home/nanocurrency/KakituDev", "-l"]
   ```

2. **Address Generation Wrapper**:
   ```python
   def kakitu_key_create():
       result = subprocess.run(['./kakitu_node', '--key_create'], 
                              capture_output=True, text=True)
       # Parse output to extract private, public, account
       return {"private": "...", "public": "...", "account": "kshs_..."}
   ```

3. **Configuration Updates**:
   - Replace all `nano_` references with `kakitu_` or `kshs_`
   - Update Docker image references
   - Modify network parameters

## Testing Plan

1. **Basic Functionality**: Verify nodes start and connect
2. **Address Generation**: Confirm `kshs_` addresses are created
3. **Block Propagation**: Test transaction creation and confirmation
4. **Network Health**: Run existing test suite with modifications
5. **RPC Compatibility**: Verify all RPC endpoints work correctly

## Files Requiring Modification

### Critical Files:
- `nanolocal/services/default_docker-compose.yml` - Docker configuration
- `nanolocal/common/nl_nanolib.py` - Address generation
- `nanolocal/nl_config.example.toml` - Network configuration
- `nanolocal/common/nl_rpc.py` - RPC interface

### Secondary Files:
- `nanolocal/services/default_config-node.toml` - Node configuration
- `nanolocal/common/nl_initialise.py` - Network initialization
- All test files in `testcases/` directory

## Expected Challenges

1. **nanolib Dependency**: May need to fork or replace nanolib for `kshs_` support
2. **RPC Compatibility**: Ensure all RPC calls work with Kakitu node
3. **Genesis Block**: May need to create custom genesis configuration
4. **Network Constants**: Verify all hardcoded values are compatible

## Timeline Estimate

- **Phase 1 (Docker Image)**: 1-2 hours
- **Phase 2 (Address Generation)**: 2-3 hours  
- **Phase 3 (Configuration)**: 1-2 hours
- **Phase 4 (Testing/Debugging)**: 2-4 hours
- **Total**: 6-11 hours

This tool will be extremely valuable for creating and testing the Kakitu network locally before launching the main network.