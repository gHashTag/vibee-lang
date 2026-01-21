"""Distributed Training Module (ZeRO, FSDP wrappers)."""

import torch
import torch.nn as nn
import torch.distributed as dist
from dataclasses import dataclass
from typing import Optional
import os


@dataclass
class DistributedConfig:
    """Configuration for distributed training."""
    strategy: str = "fsdp"  # "ddp", "fsdp", "deepspeed"
    zero_stage: int = 3  # For DeepSpeed: 0, 1, 2, 3
    sharding_strategy: str = "FULL_SHARD"  # For FSDP
    mixed_precision: bool = True
    cpu_offload: bool = False


def setup_distributed(config: Optional[DistributedConfig] = None) -> bool:
    """Initialize distributed training."""
    config = config or DistributedConfig()
    
    if not dist.is_initialized():
        if "RANK" in os.environ:
            dist.init_process_group(backend="nccl")
            return True
    return dist.is_initialized()


def wrap_fsdp(model: nn.Module, config: Optional[DistributedConfig] = None) -> nn.Module:
    """Wrap model with FSDP."""
    config = config or DistributedConfig()
    
    try:
        from torch.distributed.fsdp import FullyShardedDataParallel as FSDP, ShardingStrategy, MixedPrecision
        
        sharding_map = {
            "FULL_SHARD": ShardingStrategy.FULL_SHARD,
            "SHARD_GRAD_OP": ShardingStrategy.SHARD_GRAD_OP,
            "NO_SHARD": ShardingStrategy.NO_SHARD,
        }
        
        mp_policy = None
        if config.mixed_precision:
            mp_policy = MixedPrecision(
                param_dtype=torch.bfloat16,
                reduce_dtype=torch.bfloat16,
                buffer_dtype=torch.bfloat16,
            )
        
        model = FSDP(
            model,
            sharding_strategy=sharding_map.get(config.sharding_strategy, ShardingStrategy.FULL_SHARD),
            mixed_precision=mp_policy,
            device_id=torch.cuda.current_device() if torch.cuda.is_available() else None,
        )
    except ImportError:
        pass
    
    return model


def get_deepspeed_config(config: DistributedConfig) -> dict:
    """Generate DeepSpeed configuration."""
    return {
        "train_batch_size": "auto",
        "gradient_accumulation_steps": "auto",
        "fp16": {"enabled": False},
        "bf16": {"enabled": config.mixed_precision},
        "zero_optimization": {
            "stage": config.zero_stage,
            "offload_optimizer": {"device": "cpu"} if config.cpu_offload else {"device": "none"},
            "offload_param": {"device": "cpu"} if config.cpu_offload else {"device": "none"},
            "overlap_comm": True,
            "contiguous_gradients": True,
            "reduce_bucket_size": 5e8,
        },
    }
