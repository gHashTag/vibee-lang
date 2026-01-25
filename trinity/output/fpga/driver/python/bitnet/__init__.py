"""
VIBEE BitNet Python Bindings

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

from .core import BitNet, BitNetError, BitNetStatus, BitNetPerformance, BitNetModelInfo
from .numpy_api import bitnet_inference, bitnet_batch_inference

__version__ = "1.0.0"
__all__ = [
    "BitNet",
    "BitNetError",
    "BitNetStatus",
    "BitNetPerformance",
    "BitNetModelInfo",
    "bitnet_inference",
    "bitnet_batch_inference",
]

# Optional PyTorch integration
try:
    from .torch_api import BitNetModule
    __all__.append("BitNetModule")
except ImportError:
    pass
