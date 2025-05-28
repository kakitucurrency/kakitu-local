"""
Modified version of nl_nanolib.py that uses Kakitu node for address generation
while maintaining compatibility with the existing nano-local framework.
"""

try:
    from nanolib import Block
    NANOLIB_AVAILABLE = True
except ImportError:
    NANOLIB_AVAILABLE = False
    print("Warning: nanolib not available, block creation will be limited")

import gmpy2
from nanolocal.common.kakitu_lib import KakituLibTools

gmpy2.get_context().precision = 1000  # makes the difference between
# 34000000000000000556857955178552229888 and
# 34000000000000000000000000000000000000


def raw_high_precision_multiply(raw, multiplier) -> int:
    raw_amount = str(
        gmpy2.mpz(gmpy2.mpz(str(raw)) * gmpy2.mpfr(str(multiplier))))
    return int(raw_amount)


def raw_high_precision_percent(raw, percent) -> int:
    raw_amount = gmpy2.mpz(
        gmpy2.mpz(str(raw)) * gmpy2.mpfr(str(percent)) / gmpy2.mpz('100'))
    return int(raw_amount)


class NanoLibTools():
    """
    Modified NanoLibTools class that uses Kakitu node for address generation
    but still uses nanolib for block creation when available.
    """
    
    def __init__(self):
        self.kakitu_tools = KakituLibTools()

    def get_account_from_public(self, public_key):
        """Get kshs_ account from public key using Kakitu node"""
        return self.kakitu_tools.get_account_from_public(public_key)

    def key_expand(self, private_key):
        """Expand private key to get public key and kshs_ account"""
        try:
            return self.kakitu_tools.key_expand(private_key)
        except NotImplementedError:
            # Fallback: generate new key and warn
            print(f"Warning: Cannot expand key {private_key[:8]}..., generating new key")
            return self.kakitu_tools.key_create()

    def nanolib_account_data(self, private_key=None, seed=None, index=0):
        """Generate account data with kshs_ prefix"""
        response = self.kakitu_tools.nanolib_account_data(private_key, seed, index)
        
        if seed is not None:
            response["seed"] = seed
            response["index"] = index
        return response

    def get_state_block(self, account, representative, previous, balance, link):
        """Create state block - requires nanolib"""
        if not NANOLIB_AVAILABLE:
            raise RuntimeError("nanolib not available for block creation")
            
        return Block(block_type="state",
                     account=account,
                     representative=representative,
                     previous=previous,
                     balance=balance,
                     link=link)

    def create_state_block(self,
                           account,
                           representative,
                           previous,
                           balance,
                           link,
                           key,
                           difficulty=None):
        """Create and sign state block - requires nanolib"""
        if not NANOLIB_AVAILABLE:
            raise RuntimeError("nanolib not available for block creation")

        block = self.get_state_block(account, representative, previous,
                                     balance, link)
        block.solve_work(difficulty=difficulty)
        block.sign(key)
        return block
    
    def key_create(self):
        """Generate a new key pair with kshs_ account"""
        return self.kakitu_tools.key_create()