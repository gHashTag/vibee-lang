"""
VIBEE ML - Reference Implementation Library
============================================

Production-ready implementations of LLM training and inference optimizations.

Modules:
    - training: Training acceleration (Flash Attention, Mixed Precision, ZeRO)
    - inference: Inference optimization (Quantization, KV Cache, Batching)
    - safety: Safety and alignment (Guardrails, Content Filtering)
    - evaluation: Benchmarking and evaluation
    - deployment: Production deployment utilities
    - optimizers: Custom optimizers (Lion, Sophia, Schedule-Free)
    - data: Data processing (Deduplication, Filtering, Packing)

Sacred Constants:
    φ (phi) = 1.618033988749895
    φ² + 1/φ² = 3 (Golden Identity)
    PHOENIX = 999
"""

__version__ = "2.6.0"
__author__ = "VIBEE Contributors"

# Sacred constants
PHI = 1.618033988749895
PHI_SQUARED = PHI * PHI
GOLDEN_IDENTITY = PHI_SQUARED + 1.0 / PHI_SQUARED  # ≈ 3.0
PHOENIX = 999

# Verify golden identity
assert abs(GOLDEN_IDENTITY - 3.0) < 1e-10, "Golden identity violated!"

from .training import (
    enable_flash_attention,
    enable_mixed_precision,
    gradient_checkpointing,
    TrainingAccelerator,
)

from .inference import (
    quantize_model,
    setup_kv_cache,
    InferenceEngine,
)

from .optimizers import (
    Lion,
    Sophia,
    ScheduleFreeAdamW,
)

from .safety import (
    ContentFilter,
    Guardrails,
    SafetyEvaluator,
)

from .evaluation import (
    run_benchmark,
    BenchmarkSuite,
)

from .deployment import (
    serve_model,
    DeploymentConfig,
)

from .data import (
    deduplicate,
    filter_quality,
    pack_sequences,
)

__all__ = [
    # Constants
    "PHI",
    "PHI_SQUARED", 
    "GOLDEN_IDENTITY",
    "PHOENIX",
    # Training
    "enable_flash_attention",
    "enable_mixed_precision",
    "gradient_checkpointing",
    "TrainingAccelerator",
    # Inference
    "quantize_model",
    "setup_kv_cache",
    "InferenceEngine",
    # Optimizers
    "Lion",
    "Sophia",
    "ScheduleFreeAdamW",
    # Safety
    "ContentFilter",
    "Guardrails",
    "SafetyEvaluator",
    # Evaluation
    "run_benchmark",
    "BenchmarkSuite",
    # Deployment
    "serve_model",
    "DeploymentConfig",
    # Data
    "deduplicate",
    "filter_quality",
    "pack_sequences",
]
