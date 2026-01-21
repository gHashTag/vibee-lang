"""
Flash Attention Implementation
==============================

Reference implementation of Flash Attention concepts.
For production, use the native PyTorch SDPA or flash-attn library.

Based on:
    - Dao et al. (2022): FlashAttention
    - Dao (2023): FlashAttention-2
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from dataclasses import dataclass
from typing import Optional, Tuple
import math


@dataclass
class FlashAttentionConfig:
    """Configuration for Flash Attention."""
    
    # Use native PyTorch SDPA (recommended)
    use_native_sdpa: bool = True
    
    # Fallback options
    use_memory_efficient: bool = True
    use_flash_sdp: bool = True
    
    # Dropout
    dropout: float = 0.0
    
    # Causal masking
    is_causal: bool = True
    
    # Block sizes (for reference implementation)
    block_size_q: int = 64
    block_size_kv: int = 64


class FlashAttention(nn.Module):
    """
    Flash Attention module.
    
    Uses PyTorch's native scaled_dot_product_attention when available,
    which automatically selects the best implementation (Flash, Memory-Efficient, or Math).
    
    Example:
        >>> attn = FlashAttention(embed_dim=768, num_heads=12)
        >>> output = attn(query, key, value)
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        dropout: float = 0.0,
        is_causal: bool = True,
        config: Optional[FlashAttentionConfig] = None,
    ):
        super().__init__()
        
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.head_dim = embed_dim // num_heads
        self.dropout = dropout
        self.is_causal = is_causal
        self.config = config or FlashAttentionConfig()
        
        assert embed_dim % num_heads == 0, "embed_dim must be divisible by num_heads"
        
        self.scale = 1.0 / math.sqrt(self.head_dim)
        
        # Projections
        self.q_proj = nn.Linear(embed_dim, embed_dim, bias=False)
        self.k_proj = nn.Linear(embed_dim, embed_dim, bias=False)
        self.v_proj = nn.Linear(embed_dim, embed_dim, bias=False)
        self.out_proj = nn.Linear(embed_dim, embed_dim, bias=False)
    
    def forward(
        self,
        query: torch.Tensor,
        key: torch.Tensor,
        value: torch.Tensor,
        attention_mask: Optional[torch.Tensor] = None,
    ) -> torch.Tensor:
        """
        Forward pass.
        
        Args:
            query: (batch, seq_len, embed_dim)
            key: (batch, seq_len, embed_dim)
            value: (batch, seq_len, embed_dim)
            attention_mask: Optional attention mask
            
        Returns:
            output: (batch, seq_len, embed_dim)
        """
        batch_size, seq_len, _ = query.shape
        
        # Project
        q = self.q_proj(query)
        k = self.k_proj(key)
        v = self.v_proj(value)
        
        # Reshape for multi-head attention
        # (batch, seq, embed) -> (batch, heads, seq, head_dim)
        q = q.view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        k = k.view(batch_size, -1, self.num_heads, self.head_dim).transpose(1, 2)
        v = v.view(batch_size, -1, self.num_heads, self.head_dim).transpose(1, 2)
        
        # Use native SDPA (automatically selects Flash/Memory-Efficient/Math)
        if self.config.use_native_sdpa and hasattr(F, "scaled_dot_product_attention"):
            output = F.scaled_dot_product_attention(
                q, k, v,
                attn_mask=attention_mask,
                dropout_p=self.dropout if self.training else 0.0,
                is_causal=self.is_causal and attention_mask is None,
            )
        else:
            # Fallback to standard attention
            output = self._standard_attention(q, k, v, attention_mask)
        
        # Reshape back
        # (batch, heads, seq, head_dim) -> (batch, seq, embed)
        output = output.transpose(1, 2).contiguous().view(batch_size, seq_len, self.embed_dim)
        
        # Output projection
        output = self.out_proj(output)
        
        return output
    
    def _standard_attention(
        self,
        q: torch.Tensor,
        k: torch.Tensor,
        v: torch.Tensor,
        mask: Optional[torch.Tensor] = None,
    ) -> torch.Tensor:
        """Standard attention implementation (fallback)."""
        # Compute attention scores
        scores = torch.matmul(q, k.transpose(-2, -1)) * self.scale
        
        # Apply causal mask
        if self.is_causal:
            seq_len = q.size(-2)
            causal_mask = torch.triu(
                torch.ones(seq_len, seq_len, device=q.device, dtype=torch.bool),
                diagonal=1
            )
            scores = scores.masked_fill(causal_mask, float("-inf"))
        
        # Apply attention mask
        if mask is not None:
            scores = scores + mask
        
        # Softmax and dropout
        attn_weights = F.softmax(scores, dim=-1)
        if self.training and self.dropout > 0:
            attn_weights = F.dropout(attn_weights, p=self.dropout)
        
        # Apply to values
        output = torch.matmul(attn_weights, v)
        
        return output


def enable_flash_attention(model: nn.Module) -> nn.Module:
    """
    Enable Flash Attention for a model.
    
    Configures PyTorch to prefer Flash Attention when available.
    
    Args:
        model: PyTorch model
        
    Returns:
        Model with Flash Attention enabled
    """
    # Enable Flash SDP
    if hasattr(torch.backends.cuda, "enable_flash_sdp"):
        torch.backends.cuda.enable_flash_sdp(True)
    
    # Enable Memory-Efficient SDP
    if hasattr(torch.backends.cuda, "enable_mem_efficient_sdp"):
        torch.backends.cuda.enable_mem_efficient_sdp(True)
    
    return model


def check_flash_attention_available() -> dict:
    """
    Check Flash Attention availability.
    
    Returns:
        Dictionary with availability status
    """
    status = {
        "sdpa_available": hasattr(F, "scaled_dot_product_attention"),
        "flash_sdp_available": False,
        "mem_efficient_sdp_available": False,
        "cuda_available": torch.cuda.is_available(),
    }
    
    if torch.cuda.is_available():
        if hasattr(torch.backends.cuda, "flash_sdp_enabled"):
            status["flash_sdp_available"] = True
        if hasattr(torch.backends.cuda, "mem_efficient_sdp_enabled"):
            status["mem_efficient_sdp_available"] = True
    
    return status
