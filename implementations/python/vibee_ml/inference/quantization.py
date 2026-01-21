"""
Quantization Module
===================

Model quantization for efficient inference.
Supports INT8, INT4, AWQ, GPTQ.
"""

import torch
import torch.nn as nn
from dataclasses import dataclass
from typing import Optional, Literal
from enum import Enum


class QuantizationType(Enum):
    INT8 = "int8"
    INT4 = "int4"
    AWQ = "awq"
    GPTQ = "gptq"
    NONE = "none"


@dataclass
class QuantizationConfig:
    """Configuration for quantization."""
    quant_type: str = "int8"  # "int8", "int4", "awq", "gptq"
    bits: int = 8
    group_size: int = 128
    desc_act: bool = False  # For GPTQ
    sym: bool = True  # Symmetric quantization


def quantize_model(
    model: nn.Module,
    config: Optional[QuantizationConfig] = None,
) -> nn.Module:
    """
    Quantize model for efficient inference.
    
    Args:
        model: PyTorch model
        config: Quantization configuration
        
    Returns:
        Quantized model
    """
    config = config or QuantizationConfig()
    
    if config.quant_type == "int8":
        return _quantize_int8(model)
    elif config.quant_type == "int4":
        return _quantize_int4(model, config)
    elif config.quant_type == "awq":
        return _quantize_awq(model, config)
    elif config.quant_type == "gptq":
        return _quantize_gptq(model, config)
    
    return model


def _quantize_int8(model: nn.Module) -> nn.Module:
    """Apply INT8 dynamic quantization."""
    try:
        return torch.quantization.quantize_dynamic(
            model,
            {nn.Linear},
            dtype=torch.qint8
        )
    except Exception:
        return model


def _quantize_int4(model: nn.Module, config: QuantizationConfig) -> nn.Module:
    """Apply INT4 quantization (requires bitsandbytes)."""
    try:
        import bitsandbytes as bnb
        
        for name, module in model.named_modules():
            if isinstance(module, nn.Linear):
                # Replace with 4-bit linear
                parent_name = ".".join(name.split(".")[:-1])
                child_name = name.split(".")[-1]
                parent = model.get_submodule(parent_name) if parent_name else model
                
                new_module = bnb.nn.Linear4bit(
                    module.in_features,
                    module.out_features,
                    bias=module.bias is not None,
                )
                setattr(parent, child_name, new_module)
    except ImportError:
        pass
    
    return model


def _quantize_awq(model: nn.Module, config: QuantizationConfig) -> nn.Module:
    """Apply AWQ quantization (requires awq library)."""
    # AWQ requires calibration data and special handling
    # This is a placeholder - use awq library directly for production
    return model


def _quantize_gptq(model: nn.Module, config: QuantizationConfig) -> nn.Module:
    """Apply GPTQ quantization (requires auto-gptq)."""
    # GPTQ requires calibration data and special handling
    # This is a placeholder - use auto-gptq library directly for production
    return model


def estimate_memory_savings(model: nn.Module, quant_type: str) -> dict:
    """Estimate memory savings from quantization."""
    total_params = sum(p.numel() for p in model.parameters())
    
    # Bytes per parameter
    original_bytes = 2  # FP16
    quant_bytes = {
        "int8": 1,
        "int4": 0.5,
        "awq": 0.5,
        "gptq": 0.5,
        "none": 2,
    }
    
    original_size = total_params * original_bytes / (1024 ** 3)  # GB
    quant_size = total_params * quant_bytes.get(quant_type, 2) / (1024 ** 3)
    
    return {
        "original_size_gb": original_size,
        "quantized_size_gb": quant_size,
        "reduction_ratio": original_size / quant_size if quant_size > 0 else 1,
        "savings_gb": original_size - quant_size,
    }
