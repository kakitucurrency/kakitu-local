import subprocess
import os
import json
import re
from pathlib import Path

class KakituLibTools():
    """
    Replacement for NanoLibTools that uses the Kakitu node directly for address generation
    instead of the nanolib Python library. This ensures we get kshs_ prefixed addresses.
    """
    
    def __init__(self):
        # Find the kakitu_node executable
        self.kakitu_node_path = self._find_kakitu_node()
    
    def _find_kakitu_node(self):
        """Find the kakitu_node executable"""
        # Try different possible locations
        possible_paths = [
            "../nano_node",  # Built executable in parent directory
            "./nano_node",   # In current directory
            "/usr/local/bin/kakitu_node",  # If installed globally
            "kakitu_node"    # In PATH
        ]
        
        for path in possible_paths:
            if os.path.exists(path) or subprocess.run(["which", path], 
                                                   capture_output=True).returncode == 0:
                return path
        
        raise FileNotFoundError("kakitu_node executable not found. Please ensure it's built and available.")
    
    def _run_kakitu_command(self, args):
        """Run a kakitu_node command and return the output"""
        try:
            result = subprocess.run([self.kakitu_node_path] + args, 
                                  capture_output=True, text=True, timeout=30)
            if result.returncode != 0:
                raise RuntimeError(f"kakitu_node command failed: {result.stderr}")
            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            raise RuntimeError("kakitu_node command timed out")
    
    def key_create(self):
        """Generate a new key pair using kakitu_node --key_create"""
        output = self._run_kakitu_command(["--key_create"])
        
        # Parse the output to extract private, public, and account
        lines = output.split('\n')
        data = {}
        
        for line in lines:
            if line.startswith('Private:'):
                data['private'] = line.split(':', 1)[1].strip()
            elif line.startswith('Public:'):
                data['public'] = line.split(':', 1)[1].strip()
            elif line.startswith('Account:'):
                data['account'] = line.split(':', 1)[1].strip()
        
        if not all(key in data for key in ['private', 'public', 'account']):
            raise RuntimeError(f"Failed to parse kakitu_node output: {output}")
        
        return data
    
    def get_account_from_public(self, public_key):
        """Convert public key to kshs_ account using kakitu_node --account_get"""
        output = self._run_kakitu_command(["--account_get", "--key", public_key])
        
        # Extract account address from output
        account_match = re.search(r'(kshs_[a-z0-9]+)', output)
        if account_match:
            return account_match.group(1)
        else:
            raise RuntimeError(f"Failed to extract account from output: {output}")
    
    def key_expand(self, private_key):
        """Get public key and account from private key"""
        # Use key_expand functionality of kakitu_node if available,
        # otherwise derive public key and then get account
        try:
            # Try to get public key from private key
            output = self._run_kakitu_command(["--key_expand", "--key", private_key])
            
            # Parse output for public key and account
            lines = output.split('\n')
            data = {'private': private_key}
            
            for line in lines:
                if 'Public:' in line:
                    data['public'] = line.split(':', 1)[1].strip()
                elif 'Account:' in line:
                    data['account'] = line.split(':', 1)[1].strip()
            
            if 'public' not in data or 'account' not in data:
                raise RuntimeError("Failed to expand key")
                
            return data
            
        except RuntimeError:
            # Fallback: This is more complex and would require implementing
            # the key derivation ourselves or finding another way
            raise NotImplementedError("Key expansion not available, use key_create instead")
    
    def nanolib_account_data(self, private_key=None, seed=None, index=0):
        """
        Generate account data similar to nanolib format
        For now, if private_key is provided, try to expand it
        If seed is provided, we'd need to implement seed-based generation
        """
        if private_key:
            return self.key_expand(private_key)
        elif seed:
            # For seed-based generation, we'd need to implement the derivation
            # For now, just generate a new key
            print(f"Warning: Seed-based generation not implemented, generating new key instead")
            return self.key_create()
        else:
            return self.key_create()
    
    def validate_address(self, address):
        """Validate that an address is properly formatted"""
        # Check if it's a kshs_ address or legacy xrb_ address
        if address.startswith('kshs_') or address.startswith('xrb_'):
            # Basic length and character validation
            if len(address) >= 60 and all(c in '13456789abcdefghijkmnopqrstuwxyz_' for c in address):
                return True
        return False


# For backward compatibility, create functions that match the original nanolib interface
def raw_high_precision_multiply(raw, multiplier) -> int:
    """High precision multiplication for raw amounts"""
    import gmpy2
    gmpy2.get_context().precision = 1000
    raw_amount = str(gmpy2.mpz(gmpy2.mpz(str(raw)) * gmpy2.mpfr(str(multiplier))))
    return int(raw_amount)

def raw_high_precision_percent(raw, percent) -> int:
    """Calculate percentage of raw amount with high precision"""
    import gmpy2
    gmpy2.get_context().precision = 1000
    raw_amount = gmpy2.mpz(gmpy2.mpz(str(raw)) * gmpy2.mpfr(str(percent)) / gmpy2.mpz('100'))
    return int(raw_amount)

def get_account_public_key(account_id):
    """Get public key from kshs_ account address using kakitu_node"""
    tools = KakituLibTools()
    output = tools._run_kakitu_command(["--account_key", "--account", account_id])
    
    # Extract hex public key from output
    hex_match = re.search(r'Hex:\s*([A-F0-9]{64})', output)
    if hex_match:
        return hex_match.group(1)
    else:
        raise RuntimeError(f"Failed to extract public key from output: {output}")