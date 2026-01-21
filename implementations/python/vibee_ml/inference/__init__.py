"""
Inference Optimization Module
=============================

Production-ready inference optimizations.

Includes:
    - Quantization (INT8, INT4, AWQ, GPTQ)
    - KV Cache management
    - Continuous batching
    - vLLM/TGI integration
"""

from .quantization import quantize_model, QuantizationConfig
from .kv_cache import setup_kv_cache, KVCacheConfig
from .engine import InferenceEngine
from .serving import serve_model, ServingConfig

__all__ = [
    "quantize_model", "QuantizationConfig",
    "setup_kv_cache", "KVCacheConfig",
    "InferenceEngine",
    "serve_model", "ServingConfig",
]
