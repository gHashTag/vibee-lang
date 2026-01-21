"""Gradient Checkpointing Module."""

import torch
import torch.nn as nn
from torch.utils.checkpoint import checkpoint
from dataclasses import dataclass
from typing import Optional, List


@dataclass
class CheckpointConfig:
    """Configuration for gradient checkpointing."""
    enabled: bool = True
    checkpoint_ratio: float = 1.0  # 1.0 = all layers, 0.5 = every other
    use_reentrant: bool = False


def gradient_checkpointing(model: nn.Module, config: Optional[CheckpointConfig] = None) -> nn.Module:
    """Enable gradient checkpointing for model."""
    config = config or CheckpointConfig()
    if not config.enabled:
        return model
    
    if hasattr(model, "gradient_checkpointing_enable"):
        model.gradient_checkpointing_enable(gradient_checkpointing_kwargs={"use_reentrant": config.use_reentrant})
    return model


class CheckpointedModule(nn.Module):
    """Wrapper for checkpointed forward pass."""
    
    def __init__(self, module: nn.Module, use_reentrant: bool = False):
        super().__init__()
        self.module = module
        self.use_reentrant = use_reentrant
    
    def forward(self, *args, **kwargs):
        return checkpoint(self.module, *args, use_reentrant=self.use_reentrant, **kwargs)
