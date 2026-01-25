"""
VIBEE BitNet Benchmark Suite

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

from .runner import BenchmarkRunner, BenchmarkResult
from .latency import LatencyBenchmark
from .throughput import ThroughputBenchmark
from .memory import MemoryBenchmark
from .report import ReportGenerator
from .comparison import (
    BenchmarkComparator,
    ComparisonResult,
    ComparisonStatus,
    RegressionReport,
    compare_metric,
    compare_files,
    ComparisonVisualizer,
    visualize_comparison,
)

# Visualization (optional - requires matplotlib)
try:
    from .visualization import BenchmarkVisualizer, visualize_results
    HAS_VISUALIZATION = True
except ImportError:
    HAS_VISUALIZATION = False
    BenchmarkVisualizer = None
    visualize_results = None

__all__ = [
    "BenchmarkRunner",
    "BenchmarkResult",
    "LatencyBenchmark",
    "ThroughputBenchmark",
    "MemoryBenchmark",
    "ReportGenerator",
    "BenchmarkComparator",
    "ComparisonResult",
    "ComparisonStatus",
    "RegressionReport",
    "compare_metric",
    "compare_files",
    "ComparisonVisualizer",
    "visualize_comparison",
    "BenchmarkVisualizer",
    "visualize_results",
    "HAS_VISUALIZATION",
]
