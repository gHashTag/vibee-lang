"""KV Cache Management."""

import torch
from dataclasses import dataclass
from typing import Optional, Tuple


@dataclass
class KVCacheConfig:
    """Configuration for KV cache."""
    max_batch_size: int = 32
    max_sequence_length: int = 4096
    num_layers: int = 32
    num_heads: int = 32
    head_dim: int = 128
    dtype: torch.dtype = torch.bfloat16


class KVCache:
    """Key-Value cache for efficient autoregressive generation."""
    
    def __init__(self, config: KVCacheConfig):
        self.config = config
        self.cache: Optional[Tuple[torch.Tensor, torch.Tensor]] = None
        self.position = 0
    
    def allocate(self, device: torch.device):
        """Allocate cache memory."""
        shape = (
            self.config.num_layers,
            2,  # K and V
            self.config.max_batch_size,
            self.config.num_heads,
            self.config.max_sequence_length,
            self.config.head_dim,
        )
        self.cache = torch.zeros(shape, dtype=self.config.dtype, device=device)
        self.position = 0
    
    def update(self, layer_idx: int, key: torch.Tensor, value: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        """Update cache with new key-value pairs."""
        if self.cache is None:
            raise RuntimeError("Cache not allocated")
        
        seq_len = key.shape[2]
        self.cache[layer_idx, 0, :, :, self.position:self.position + seq_len, :] = key
        self.cache[layer_idx, 1, :, :, self.position:self.position + seq_len, :] = value
        
        # Return full cache up to current position
        return (
            self.cache[layer_idx, 0, :, :, :self.position + seq_len, :],
            self.cache[layer_idx, 1, :, :, :self.position + seq_len, :],
        )
    
    def advance(self, num_tokens: int = 1):
        """Advance position in cache."""
        self.position += num_tokens
    
    def reset(self):
        """Reset cache position."""
        self.position = 0
        if self.cache is not None:
            self.cache.zero_()
    
    def memory_usage_gb(self) -> float:
        """Calculate memory usage in GB."""
        if self.cache is None:
            return 0.0
        return self.cache.numel() * self.cache.element_size() / (1024 ** 3)


def setup_kv_cache(model, config: Optional[KVCacheConfig] = None) -> KVCache:
    """Setup KV cache for model."""
    config = config or KVCacheConfig()
    cache = KVCache(config)
    device = next(model.parameters()).device
    cache.allocate(device)
    return cache
