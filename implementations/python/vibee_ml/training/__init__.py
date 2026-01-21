"""
Training Acceleration Module
============================

Implements training optimizations from VIBEE v2100-v2199.

Key Features:
    - Flash Attention integration
    - Mixed precision training (BF16/FP16)
    - Gradient checkpointing
    - Distributed training wrappers (ZeRO, FSDP)
"""

from .accelerator import TrainingAccelerator
from .flash_attention import enable_flash_attention, FlashAttentionConfig
from .mixed_precision import enable_mixed_precision, MixedPrecisionConfig
from .checkpointing import gradient_checkpointing, CheckpointConfig
from .distributed import setup_distributed, DistributedConfig

__all__ = [
    "TrainingAccelerator",
    "enable_flash_attention",
    "FlashAttentionConfig",
    "enable_mixed_precision", 
    "MixedPrecisionConfig",
    "gradient_checkpointing",
    "CheckpointConfig",
    "setup_distributed",
    "DistributedConfig",
]
