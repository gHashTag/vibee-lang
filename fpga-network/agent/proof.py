"""
FPGA.Network Proof of Inference

Cryptographic proof system to verify that inference was actually performed.
"""

import hashlib
import hmac
import time
import json
from dataclasses import dataclass
from typing import Optional, Tuple
from enum import Enum


class ProofType(Enum):
    """Types of proof"""
    HASH = "hash"           # Simple hash proof
    MERKLE = "merkle"       # Merkle tree proof
    ZK = "zk"               # Zero-knowledge proof (future)


@dataclass
class InferenceProof:
    """Proof of inference execution"""
    proof_type: ProofType
    request_hash: str       # Hash of original request
    output_hash: str        # Hash of output
    timestamp: float        # When inference was performed
    provider_id: str        # Provider who performed inference
    signature: str          # Provider's signature
    nonce: str              # Random nonce for uniqueness
    
    # Optional: intermediate hashes for verification
    intermediate_hashes: Optional[list] = None
    
    def to_dict(self) -> dict:
        return {
            "proof_type": self.proof_type.value,
            "request_hash": self.request_hash,
            "output_hash": self.output_hash,
            "timestamp": self.timestamp,
            "provider_id": self.provider_id,
            "signature": self.signature,
            "nonce": self.nonce,
            "intermediate_hashes": self.intermediate_hashes
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> "InferenceProof":
        return cls(
            proof_type=ProofType(data["proof_type"]),
            request_hash=data["request_hash"],
            output_hash=data["output_hash"],
            timestamp=data["timestamp"],
            provider_id=data["provider_id"],
            signature=data["signature"],
            nonce=data["nonce"],
            intermediate_hashes=data.get("intermediate_hashes")
        )


class ProofGenerator:
    """Generates proofs of inference"""
    
    def __init__(self, provider_id: str, secret_key: str):
        self.provider_id = provider_id
        self.secret_key = secret_key.encode() if isinstance(secret_key, str) else secret_key
    
    def generate_proof(
        self,
        request_data: dict,
        output: str,
        nonce: str,
        intermediate_states: Optional[list] = None
    ) -> InferenceProof:
        """Generate proof of inference"""
        
        timestamp = time.time()
        
        # Hash the request
        request_json = json.dumps(request_data, sort_keys=True)
        request_hash = hashlib.sha256(request_json.encode()).hexdigest()
        
        # Hash the output
        output_hash = hashlib.sha256(output.encode()).hexdigest()
        
        # Generate intermediate hashes if states provided
        intermediate_hashes = None
        if intermediate_states:
            intermediate_hashes = [
                hashlib.sha256(str(state).encode()).hexdigest()
                for state in intermediate_states
            ]
        
        # Create signature
        signature_data = f"{request_hash}|{output_hash}|{timestamp}|{nonce}|{self.provider_id}"
        signature = hmac.new(
            self.secret_key,
            signature_data.encode(),
            hashlib.sha256
        ).hexdigest()
        
        return InferenceProof(
            proof_type=ProofType.HASH,
            request_hash=request_hash,
            output_hash=output_hash,
            timestamp=timestamp,
            provider_id=self.provider_id,
            signature=signature,
            nonce=nonce,
            intermediate_hashes=intermediate_hashes
        )
    
    def generate_compact_proof(self, request_data: dict, output: str, nonce: str) -> str:
        """Generate compact proof string for simple verification"""
        proof = self.generate_proof(request_data, output, nonce)
        
        # Compact format: request_hash:output_hash:timestamp:signature
        return f"{proof.request_hash[:16]}:{proof.output_hash[:16]}:{int(proof.timestamp)}:{proof.signature[:32]}"


class ProofVerifier:
    """Verifies proofs of inference"""
    
    def __init__(self, provider_registry: dict = None):
        """
        Args:
            provider_registry: Dict mapping provider_id to their public key/info
        """
        self.provider_registry = provider_registry or {}
    
    def verify_proof(
        self,
        proof: InferenceProof,
        request_data: dict,
        output: str,
        provider_secret: Optional[str] = None
    ) -> Tuple[bool, str]:
        """
        Verify a proof of inference.
        
        Returns:
            Tuple of (is_valid, reason)
        """
        
        # 1. Verify request hash
        request_json = json.dumps(request_data, sort_keys=True)
        expected_request_hash = hashlib.sha256(request_json.encode()).hexdigest()
        
        if proof.request_hash != expected_request_hash:
            return False, "Request hash mismatch"
        
        # 2. Verify output hash
        expected_output_hash = hashlib.sha256(output.encode()).hexdigest()
        
        if proof.output_hash != expected_output_hash:
            return False, "Output hash mismatch"
        
        # 3. Verify timestamp is reasonable (within last hour)
        current_time = time.time()
        if proof.timestamp > current_time + 60:  # Allow 1 minute clock skew
            return False, "Timestamp in future"
        if proof.timestamp < current_time - 3600:  # Within last hour
            return False, "Timestamp too old"
        
        # 4. Verify signature (if we have the secret)
        if provider_secret:
            secret_key = provider_secret.encode() if isinstance(provider_secret, str) else provider_secret
            signature_data = f"{proof.request_hash}|{proof.output_hash}|{proof.timestamp}|{proof.nonce}|{proof.provider_id}"
            expected_signature = hmac.new(
                secret_key,
                signature_data.encode(),
                hashlib.sha256
            ).hexdigest()
            
            if proof.signature != expected_signature:
                return False, "Invalid signature"
        
        # 5. Verify provider is registered (if registry available)
        if self.provider_registry and proof.provider_id not in self.provider_registry:
            return False, "Unknown provider"
        
        return True, "Valid proof"
    
    def verify_compact_proof(
        self,
        compact_proof: str,
        request_data: dict,
        output: str
    ) -> Tuple[bool, str]:
        """Verify a compact proof string"""
        
        try:
            parts = compact_proof.split(":")
            if len(parts) != 4:
                return False, "Invalid proof format"
            
            request_hash_prefix, output_hash_prefix, timestamp_str, signature_prefix = parts
            
            # Verify request hash prefix
            request_json = json.dumps(request_data, sort_keys=True)
            expected_request_hash = hashlib.sha256(request_json.encode()).hexdigest()
            
            if not expected_request_hash.startswith(request_hash_prefix):
                return False, "Request hash mismatch"
            
            # Verify output hash prefix
            expected_output_hash = hashlib.sha256(output.encode()).hexdigest()
            
            if not expected_output_hash.startswith(output_hash_prefix):
                return False, "Output hash mismatch"
            
            # Verify timestamp
            timestamp = int(timestamp_str)
            current_time = time.time()
            if timestamp > current_time + 60 or timestamp < current_time - 3600:
                return False, "Invalid timestamp"
            
            return True, "Valid proof (compact verification)"
            
        except Exception as e:
            return False, f"Verification error: {e}"


class MerkleProofGenerator:
    """Generate Merkle tree proofs for batch inference verification"""
    
    @staticmethod
    def build_merkle_tree(hashes: list) -> Tuple[str, list]:
        """
        Build Merkle tree from list of hashes.
        
        Returns:
            Tuple of (root_hash, tree_levels)
        """
        if not hashes:
            return "", []
        
        # Ensure even number of leaves
        if len(hashes) % 2 == 1:
            hashes = hashes + [hashes[-1]]
        
        tree = [hashes]
        current_level = hashes
        
        while len(current_level) > 1:
            next_level = []
            for i in range(0, len(current_level), 2):
                combined = current_level[i] + current_level[i + 1]
                next_level.append(hashlib.sha256(combined.encode()).hexdigest())
            tree.append(next_level)
            current_level = next_level
        
        return current_level[0], tree
    
    @staticmethod
    def get_proof_path(tree: list, index: int) -> list:
        """Get Merkle proof path for a specific leaf"""
        proof_path = []
        
        for level in tree[:-1]:
            if index % 2 == 0:
                sibling_index = index + 1
            else:
                sibling_index = index - 1
            
            if sibling_index < len(level):
                proof_path.append({
                    "hash": level[sibling_index],
                    "position": "right" if index % 2 == 0 else "left"
                })
            
            index = index // 2
        
        return proof_path
    
    @staticmethod
    def verify_merkle_proof(leaf_hash: str, proof_path: list, root_hash: str) -> bool:
        """Verify a Merkle proof"""
        current_hash = leaf_hash
        
        for step in proof_path:
            if step["position"] == "right":
                combined = current_hash + step["hash"]
            else:
                combined = step["hash"] + current_hash
            current_hash = hashlib.sha256(combined.encode()).hexdigest()
        
        return current_hash == root_hash


# Utility functions
def generate_nonce() -> str:
    """Generate random nonce"""
    import secrets
    return secrets.token_hex(16)


def hash_inference_result(prompt: str, output: str, model: str) -> str:
    """Generate deterministic hash of inference result"""
    data = f"{prompt}|{output}|{model}"
    return hashlib.sha256(data.encode()).hexdigest()
