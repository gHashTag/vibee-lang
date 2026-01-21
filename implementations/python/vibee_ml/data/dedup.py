"""
Data Deduplication
==================

MinHash and exact deduplication for training data.
"""

from dataclasses import dataclass
from typing import List, Set, Iterator, Optional, Callable
import hashlib
import re


@dataclass
class DedupConfig:
    """Configuration for deduplication."""
    method: str = "minhash"  # "exact", "minhash", "simhash"
    num_perm: int = 128  # MinHash permutations
    threshold: float = 0.8  # Similarity threshold
    ngram_size: int = 5  # N-gram size for shingling


class Deduplicator:
    """
    Data deduplication using MinHash LSH.
    
    Example:
        >>> dedup = Deduplicator()
        >>> unique_texts = dedup.deduplicate(texts)
    """
    
    def __init__(self, config: Optional[DedupConfig] = None):
        self.config = config or DedupConfig()
        self._seen_hashes: Set[str] = set()
    
    def deduplicate(self, texts: List[str]) -> List[str]:
        """Remove duplicate texts."""
        if self.config.method == "exact":
            return self._exact_dedup(texts)
        elif self.config.method == "minhash":
            return self._minhash_dedup(texts)
        return texts
    
    def _exact_dedup(self, texts: List[str]) -> List[str]:
        """Exact hash-based deduplication."""
        seen = set()
        unique = []
        
        for text in texts:
            h = hashlib.md5(text.encode()).hexdigest()
            if h not in seen:
                seen.add(h)
                unique.append(text)
        
        return unique
    
    def _minhash_dedup(self, texts: List[str]) -> List[str]:
        """MinHash-based near-duplicate detection."""
        unique = []
        signatures = []
        
        for text in texts:
            sig = self._compute_minhash(text)
            
            # Check similarity with existing signatures
            is_duplicate = False
            for existing_sig in signatures:
                similarity = self._jaccard_from_minhash(sig, existing_sig)
                if similarity >= self.config.threshold:
                    is_duplicate = True
                    break
            
            if not is_duplicate:
                unique.append(text)
                signatures.append(sig)
        
        return unique
    
    def _compute_minhash(self, text: str) -> List[int]:
        """Compute MinHash signature."""
        # Create shingles
        shingles = self._get_shingles(text)
        
        # Compute MinHash
        signature = []
        for i in range(self.config.num_perm):
            min_hash = float('inf')
            for shingle in shingles:
                h = hash((shingle, i)) & 0xFFFFFFFF
                min_hash = min(min_hash, h)
            signature.append(min_hash)
        
        return signature
    
    def _get_shingles(self, text: str) -> Set[str]:
        """Get n-gram shingles from text."""
        # Normalize text
        text = re.sub(r'\s+', ' ', text.lower().strip())
        
        # Create shingles
        shingles = set()
        for i in range(len(text) - self.config.ngram_size + 1):
            shingles.add(text[i:i + self.config.ngram_size])
        
        return shingles
    
    def _jaccard_from_minhash(self, sig1: List[int], sig2: List[int]) -> float:
        """Estimate Jaccard similarity from MinHash signatures."""
        matches = sum(1 for a, b in zip(sig1, sig2) if a == b)
        return matches / len(sig1)
    
    def stream_deduplicate(self, texts: Iterator[str]) -> Iterator[str]:
        """Stream-based deduplication."""
        for text in texts:
            h = hashlib.md5(text.encode()).hexdigest()
            if h not in self._seen_hashes:
                self._seen_hashes.add(h)
                yield text
    
    def reset(self):
        """Reset seen hashes for streaming."""
        self._seen_hashes.clear()


def deduplicate(texts: List[str], method: str = "minhash") -> List[str]:
    """Convenience function for deduplication."""
    dedup = Deduplicator(DedupConfig(method=method))
    return dedup.deduplicate(texts)
