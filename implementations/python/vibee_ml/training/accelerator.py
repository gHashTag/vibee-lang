"""
Training Accelerator - Unified training optimization interface.

Usage:
    from vibee_ml.training import TrainingAccelerator
    
    accelerator = TrainingAccelerator(
        mixed_precision="bf16",
        gradient_checkpointing=True,
        flash_attention=True,
    )
    
    model = accelerator.prepare(model)
    optimizer = accelerator.prepare(optimizer)
"""

import torch
import torch.nn as nn
from dataclasses import dataclass, field
from typing import Optional, Union, List, Any
from contextlib import contextmanager
import logging

logger = logging.getLogger(__name__)


@dataclass
class TrainingConfig:
    """Configuration for training acceleration."""
    
    # Precision
    mixed_precision: str = "bf16"  # "fp32", "fp16", "bf16"
    
    # Memory optimization
    gradient_checkpointing: bool = True
    gradient_accumulation_steps: int = 1
    
    # Attention
    flash_attention: bool = True
    
    # Distributed
    distributed_strategy: str = "auto"  # "auto", "ddp", "fsdp", "deepspeed"
    zero_stage: int = 0  # 0, 1, 2, 3
    
    # Compilation
    compile_model: bool = True
    compile_mode: str = "reduce-overhead"  # "default", "reduce-overhead", "max-autotune"
    
    # Gradient clipping
    max_grad_norm: float = 1.0


class TrainingAccelerator:
    """
    Unified interface for training acceleration.
    
    Combines:
        - Mixed precision training
        - Gradient checkpointing
        - Flash Attention
        - torch.compile
        - Distributed training
    
    Example:
        >>> accelerator = TrainingAccelerator(mixed_precision="bf16")
        >>> model = accelerator.prepare(model)
        >>> 
        >>> for batch in dataloader:
        ...     with accelerator.autocast():
        ...         loss = model(batch)
        ...     accelerator.backward(loss)
        ...     accelerator.step(optimizer)
    """
    
    def __init__(
        self,
        mixed_precision: str = "bf16",
        gradient_checkpointing: bool = True,
        flash_attention: bool = True,
        compile_model: bool = True,
        max_grad_norm: float = 1.0,
        **kwargs
    ):
        self.config = TrainingConfig(
            mixed_precision=mixed_precision,
            gradient_checkpointing=gradient_checkpointing,
            flash_attention=flash_attention,
            compile_model=compile_model,
            max_grad_norm=max_grad_norm,
            **kwargs
        )
        
        self._setup_precision()
        self._setup_device()
        
        self.scaler = None
        if self.config.mixed_precision == "fp16":
            self.scaler = torch.cuda.amp.GradScaler()
        
        logger.info(f"TrainingAccelerator initialized: {self.config}")
    
    def _setup_precision(self):
        """Setup precision dtype."""
        precision_map = {
            "fp32": torch.float32,
            "fp16": torch.float16,
            "bf16": torch.bfloat16,
        }
        self.dtype = precision_map.get(self.config.mixed_precision, torch.bfloat16)
    
    def _setup_device(self):
        """Setup compute device."""
        if torch.cuda.is_available():
            self.device = torch.device("cuda")
        elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            self.device = torch.device("mps")
        else:
            self.device = torch.device("cpu")
        
        logger.info(f"Using device: {self.device}")
    
    def prepare(self, model: nn.Module) -> nn.Module:
        """
        Prepare model for accelerated training.
        
        Applies:
            1. Move to device
            2. Convert to target precision
            3. Enable gradient checkpointing
            4. Enable Flash Attention
            5. Compile with torch.compile
        """
        # Move to device
        model = model.to(self.device)
        
        # Convert precision (for parameters that support it)
        if self.dtype != torch.float32:
            model = model.to(self.dtype)
        
        # Enable gradient checkpointing
        if self.config.gradient_checkpointing:
            if hasattr(model, "gradient_checkpointing_enable"):
                model.gradient_checkpointing_enable()
                logger.info("Gradient checkpointing enabled")
            else:
                logger.warning("Model doesn't support gradient_checkpointing_enable()")
        
        # Enable Flash Attention (PyTorch 2.0+)
        if self.config.flash_attention:
            self._enable_flash_attention(model)
        
        # Compile model
        if self.config.compile_model and hasattr(torch, "compile"):
            try:
                model = torch.compile(model, mode=self.config.compile_mode)
                logger.info(f"Model compiled with mode: {self.config.compile_mode}")
            except Exception as e:
                logger.warning(f"torch.compile failed: {e}")
        
        return model
    
    def _enable_flash_attention(self, model: nn.Module):
        """Enable Flash Attention for compatible layers."""
        # PyTorch 2.0+ has Flash Attention built-in via SDPA
        if hasattr(torch.nn.functional, "scaled_dot_product_attention"):
            # Set attention implementation preference
            torch.backends.cuda.enable_flash_sdp(True)
            torch.backends.cuda.enable_mem_efficient_sdp(True)
            logger.info("Flash Attention enabled via SDPA")
    
    @contextmanager
    def autocast(self):
        """Context manager for automatic mixed precision."""
        if self.config.mixed_precision == "fp32":
            yield
        else:
            with torch.autocast(
                device_type=self.device.type,
                dtype=self.dtype
            ):
                yield
    
    def backward(self, loss: torch.Tensor):
        """Backward pass with optional gradient scaling."""
        if self.scaler is not None:
            self.scaler.scale(loss).backward()
        else:
            loss.backward()
    
    def step(self, optimizer: torch.optim.Optimizer):
        """Optimizer step with gradient clipping and scaling."""
        if self.scaler is not None:
            self.scaler.unscale_(optimizer)
        
        # Gradient clipping
        if self.config.max_grad_norm > 0:
            torch.nn.utils.clip_grad_norm_(
                self._get_parameters(optimizer),
                self.config.max_grad_norm
            )
        
        if self.scaler is not None:
            self.scaler.step(optimizer)
            self.scaler.update()
        else:
            optimizer.step()
    
    def _get_parameters(self, optimizer):
        """Extract parameters from optimizer."""
        params = []
        for group in optimizer.param_groups:
            params.extend(group["params"])
        return params
    
    def zero_grad(self, optimizer: torch.optim.Optimizer):
        """Zero gradients efficiently."""
        optimizer.zero_grad(set_to_none=True)
    
    def get_throughput(
        self,
        batch_size: int,
        seq_length: int,
        elapsed_time: float
    ) -> dict:
        """Calculate training throughput metrics."""
        tokens = batch_size * seq_length
        tokens_per_second = tokens / elapsed_time
        
        return {
            "tokens_per_second": tokens_per_second,
            "samples_per_second": batch_size / elapsed_time,
            "time_per_step": elapsed_time,
        }


def enable_flash_attention(model: nn.Module) -> nn.Module:
    """
    Enable Flash Attention for a model.
    
    Args:
        model: PyTorch model
        
    Returns:
        Model with Flash Attention enabled
    """
    if hasattr(torch.nn.functional, "scaled_dot_product_attention"):
        torch.backends.cuda.enable_flash_sdp(True)
        torch.backends.cuda.enable_mem_efficient_sdp(True)
    return model


def enable_mixed_precision(
    model: nn.Module,
    dtype: str = "bf16"
) -> nn.Module:
    """
    Enable mixed precision for a model.
    
    Args:
        model: PyTorch model
        dtype: Target dtype ("fp16" or "bf16")
        
    Returns:
        Model in target precision
    """
    dtype_map = {"fp16": torch.float16, "bf16": torch.bfloat16}
    target_dtype = dtype_map.get(dtype, torch.bfloat16)
    return model.to(target_dtype)


def gradient_checkpointing(model: nn.Module) -> nn.Module:
    """
    Enable gradient checkpointing for a model.
    
    Args:
        model: PyTorch model
        
    Returns:
        Model with gradient checkpointing enabled
    """
    if hasattr(model, "gradient_checkpointing_enable"):
        model.gradient_checkpointing_enable()
    return model
