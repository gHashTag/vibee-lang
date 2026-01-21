"""
Benchmarking
============

LLM benchmarking utilities.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional, Callable
import time
import torch
import torch.nn as nn


@dataclass
class BenchmarkConfig:
    """Configuration for benchmarking."""
    num_warmup: int = 3
    num_iterations: int = 10
    batch_sizes: List[int] = field(default_factory=lambda: [1, 4, 8, 16, 32])
    sequence_lengths: List[int] = field(default_factory=lambda: [128, 512, 1024, 2048])
    measure_memory: bool = True


@dataclass
class BenchmarkResult:
    """Result of a benchmark run."""
    name: str
    batch_size: int
    sequence_length: int
    latency_ms: float
    throughput_tokens_per_sec: float
    memory_mb: float = 0.0
    metadata: Dict[str, Any] = field(default_factory=dict)


class Benchmark:
    """
    Single benchmark for a model.
    
    Example:
        >>> benchmark = Benchmark(model, tokenizer)
        >>> results = benchmark.run()
    """
    
    def __init__(
        self,
        model: nn.Module,
        tokenizer: Any,
        config: Optional[BenchmarkConfig] = None,
    ):
        self.model = model
        self.tokenizer = tokenizer
        self.config = config or BenchmarkConfig()
        self.device = next(model.parameters()).device
    
    def run(self, name: str = "benchmark") -> List[BenchmarkResult]:
        """Run benchmark across all configurations."""
        results = []
        
        for batch_size in self.config.batch_sizes:
            for seq_length in self.config.sequence_lengths:
                try:
                    result = self._run_single(name, batch_size, seq_length)
                    results.append(result)
                except RuntimeError as e:
                    # OOM or other error
                    results.append(BenchmarkResult(
                        name=name,
                        batch_size=batch_size,
                        sequence_length=seq_length,
                        latency_ms=-1,
                        throughput_tokens_per_sec=0,
                        metadata={"error": str(e)},
                    ))
        
        return results
    
    def _run_single(
        self,
        name: str,
        batch_size: int,
        seq_length: int,
    ) -> BenchmarkResult:
        """Run single benchmark configuration."""
        # Create dummy input
        input_ids = torch.randint(
            0, self.tokenizer.vocab_size,
            (batch_size, seq_length),
            device=self.device,
        )
        
        # Warmup
        for _ in range(self.config.num_warmup):
            with torch.no_grad():
                _ = self.model(input_ids)
        
        # Synchronize
        if self.device.type == "cuda":
            torch.cuda.synchronize()
        
        # Measure memory before
        memory_before = 0
        if self.config.measure_memory and self.device.type == "cuda":
            torch.cuda.reset_peak_memory_stats()
            memory_before = torch.cuda.memory_allocated() / 1024 / 1024
        
        # Benchmark
        start = time.perf_counter()
        for _ in range(self.config.num_iterations):
            with torch.no_grad():
                _ = self.model(input_ids)
        
        if self.device.type == "cuda":
            torch.cuda.synchronize()
        
        elapsed = time.perf_counter() - start
        
        # Measure memory after
        memory_peak = 0
        if self.config.measure_memory and self.device.type == "cuda":
            memory_peak = torch.cuda.max_memory_allocated() / 1024 / 1024
        
        # Calculate metrics
        latency_ms = (elapsed / self.config.num_iterations) * 1000
        total_tokens = batch_size * seq_length * self.config.num_iterations
        throughput = total_tokens / elapsed
        
        return BenchmarkResult(
            name=name,
            batch_size=batch_size,
            sequence_length=seq_length,
            latency_ms=latency_ms,
            throughput_tokens_per_sec=throughput,
            memory_mb=memory_peak - memory_before,
        )


class BenchmarkSuite:
    """
    Suite of benchmarks for comparing models.
    
    Example:
        >>> suite = BenchmarkSuite()
        >>> suite.add("baseline", model1, tokenizer)
        >>> suite.add("optimized", model2, tokenizer)
        >>> results = suite.run_all()
    """
    
    def __init__(self, config: Optional[BenchmarkConfig] = None):
        self.config = config or BenchmarkConfig()
        self.benchmarks: Dict[str, Benchmark] = {}
    
    def add(self, name: str, model: nn.Module, tokenizer: Any):
        """Add a model to the benchmark suite."""
        self.benchmarks[name] = Benchmark(model, tokenizer, self.config)
    
    def run_all(self) -> Dict[str, List[BenchmarkResult]]:
        """Run all benchmarks."""
        results = {}
        for name, benchmark in self.benchmarks.items():
            results[name] = benchmark.run(name)
        return results
    
    def compare(self, results: Dict[str, List[BenchmarkResult]]) -> Dict[str, Any]:
        """Compare benchmark results."""
        comparison = {}
        
        # Get baseline (first model)
        baseline_name = list(results.keys())[0]
        baseline_results = {
            (r.batch_size, r.sequence_length): r
            for r in results[baseline_name]
        }
        
        for name, model_results in results.items():
            if name == baseline_name:
                continue
            
            speedups = []
            for r in model_results:
                key = (r.batch_size, r.sequence_length)
                if key in baseline_results and r.latency_ms > 0:
                    baseline = baseline_results[key]
                    if baseline.latency_ms > 0:
                        speedups.append(baseline.latency_ms / r.latency_ms)
            
            comparison[name] = {
                "avg_speedup": sum(speedups) / len(speedups) if speedups else 0,
                "max_speedup": max(speedups) if speedups else 0,
                "min_speedup": min(speedups) if speedups else 0,
            }
        
        return comparison


def run_benchmark(
    model: nn.Module,
    tokenizer: Any,
    **kwargs
) -> List[BenchmarkResult]:
    """Convenience function for running benchmarks."""
    config = BenchmarkConfig(**kwargs)
    benchmark = Benchmark(model, tokenizer, config)
    return benchmark.run()
