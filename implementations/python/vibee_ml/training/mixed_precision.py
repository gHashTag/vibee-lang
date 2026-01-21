"""Mixed Precision Training Module."""

import torch
import torch.nn as nn
from dataclasses import dataclass
from typing import Optional
from contextlib import contextmanager


@dataclass
class MixedPrecisionConfig:
    """Configuration for mixed precision training."""
    dtype: str = "bf16"  # "fp16", "bf16", "fp32"
    use_autocast: bool = True
    use_grad_scaler: bool = True  # Only for fp16


class MixedPrecisionTrainer:
    """Mixed precision training wrapper."""
    
    def __init__(self, config: Optional[MixedPrecisionConfig] = None):
        self.config = config or MixedPrecisionConfig()
        self.dtype = {"fp16": torch.float16, "bf16": torch.bfloat16, "fp32": torch.float32}[self.config.dtype]
        self.scaler = torch.cuda.amp.GradScaler() if self.config.dtype == "fp16" else None
    
    @contextmanager
    def autocast(self, device_type: str = "cuda"):
        if self.config.use_autocast and self.config.dtype != "fp32":
            with torch.autocast(device_type=device_type, dtype=self.dtype):
                yield
        else:
            yield
    
    def backward(self, loss: torch.Tensor):
        if self.scaler:
            self.scaler.scale(loss).backward()
        else:
            loss.backward()
    
    def step(self, optimizer: torch.optim.Optimizer):
        if self.scaler:
            self.scaler.step(optimizer)
            self.scaler.update()
        else:
            optimizer.step()


def enable_mixed_precision(model: nn.Module, dtype: str = "bf16") -> nn.Module:
    """Enable mixed precision for model."""
    dtype_map = {"fp16": torch.float16, "bf16": torch.bfloat16}
    if dtype in dtype_map:
        model = model.to(dtype_map[dtype])
    return model
