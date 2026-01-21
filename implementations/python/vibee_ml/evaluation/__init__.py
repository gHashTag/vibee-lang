"""
Evaluation Module
=================

Benchmarking and evaluation for LLM models.
"""

from .benchmark import Benchmark, BenchmarkSuite, run_benchmark
from .metrics import MetricsCollector, compute_perplexity

__all__ = [
    "Benchmark",
    "BenchmarkSuite",
    "run_benchmark",
    "MetricsCollector",
    "compute_perplexity",
]
