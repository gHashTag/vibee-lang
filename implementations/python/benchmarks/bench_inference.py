"""
Inference Benchmarks
====================

Benchmark inference performance with various optimizations.
"""

import torch
import torch.nn as nn
import time
from typing import Dict, Any, List
from dataclasses import dataclass


@dataclass
class BenchmarkConfig:
    batch_sizes: List[int] = None
    sequence_lengths: List[int] = None
    num_warmup: int = 3
    num_iterations: int = 10
    
    def __post_init__(self):
        if self.batch_sizes is None:
            self.batch_sizes = [1, 4, 8, 16]
        if self.sequence_lengths is None:
            self.sequence_lengths = [128, 512, 1024, 2048]


class SimpleTransformer(nn.Module):
    """Simple transformer for benchmarking."""
    
    def __init__(self, vocab_size: int = 32000, hidden_size: int = 768, num_layers: int = 6):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, hidden_size)
        self.layers = nn.ModuleList([
            nn.TransformerEncoderLayer(
                d_model=hidden_size,
                nhead=12,
                dim_feedforward=hidden_size * 4,
                batch_first=True,
            )
            for _ in range(num_layers)
        ])
        self.output = nn.Linear(hidden_size, vocab_size)
    
    def forward(self, x):
        x = self.embedding(x)
        for layer in self.layers:
            x = layer(x)
        return self.output(x)


def benchmark_inference(
    model: nn.Module,
    config: BenchmarkConfig,
    device: torch.device,
    use_compile: bool = False,
    use_fp16: bool = False,
) -> List[Dict[str, Any]]:
    """Benchmark inference across configurations."""
    model = model.to(device)
    model.eval()
    
    if use_fp16:
        model = model.half()
    
    if use_compile and hasattr(torch, "compile"):
        model = torch.compile(model, mode="reduce-overhead")
    
    results = []
    
    for batch_size in config.batch_sizes:
        for seq_length in config.sequence_lengths:
            try:
                result = _benchmark_single(
                    model, batch_size, seq_length, config, device, use_fp16
                )
                results.append(result)
            except RuntimeError as e:
                results.append({
                    "batch_size": batch_size,
                    "sequence_length": seq_length,
                    "error": str(e),
                })
    
    return results


def _benchmark_single(
    model: nn.Module,
    batch_size: int,
    seq_length: int,
    config: BenchmarkConfig,
    device: torch.device,
    use_fp16: bool,
) -> Dict[str, Any]:
    """Benchmark single configuration."""
    # Create input
    input_ids = torch.randint(0, 32000, (batch_size, seq_length), device=device)
    
    # Warmup
    with torch.no_grad():
        for _ in range(config.num_warmup):
            _ = model(input_ids)
    
    if device.type == "cuda":
        torch.cuda.synchronize()
        torch.cuda.reset_peak_memory_stats()
    
    # Benchmark
    start = time.perf_counter()
    
    with torch.no_grad():
        for _ in range(config.num_iterations):
            _ = model(input_ids)
    
    if device.type == "cuda":
        torch.cuda.synchronize()
    
    elapsed = time.perf_counter() - start
    
    # Calculate metrics
    latency_ms = (elapsed / config.num_iterations) * 1000
    total_tokens = batch_size * seq_length * config.num_iterations
    throughput = total_tokens / elapsed
    
    memory_mb = 0
    if device.type == "cuda":
        memory_mb = torch.cuda.max_memory_allocated() / 1024 / 1024
    
    return {
        "batch_size": batch_size,
        "sequence_length": seq_length,
        "latency_ms": latency_ms,
        "throughput_tokens_per_sec": throughput,
        "memory_mb": memory_mb,
    }


def run_inference_benchmarks():
    """Run all inference benchmarks."""
    print("=" * 70)
    print("VIBEE ML Inference Benchmarks")
    print("=" * 70)
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}")
    
    config = BenchmarkConfig()
    model = SimpleTransformer()
    
    # Baseline (FP32)
    print("\n--- Baseline (FP32) ---")
    results_fp32 = benchmark_inference(model, config, device)
    
    # FP16
    print("\n--- FP16 ---")
    model_fp16 = SimpleTransformer()
    results_fp16 = benchmark_inference(model_fp16, config, device, use_fp16=True)
    
    # Compiled
    if hasattr(torch, "compile"):
        print("\n--- torch.compile ---")
        model_compiled = SimpleTransformer()
        results_compiled = benchmark_inference(model_compiled, config, device, use_compile=True)
    
    # Print results
    print("\n" + "=" * 70)
    print("Results Summary")
    print("=" * 70)
    print(f"{'Config':<20} {'FP32 (ms)':<15} {'FP16 (ms)':<15} {'Speedup':<10}")
    print("-" * 60)
    
    for r32, r16 in zip(results_fp32, results_fp16):
        if "error" in r32 or "error" in r16:
            continue
        config_str = f"{r32['batch_size']}x{r32['sequence_length']}"
        speedup = r32["latency_ms"] / r16["latency_ms"]
        print(f"{config_str:<20} {r32['latency_ms']:<15.2f} {r16['latency_ms']:<15.2f} {speedup:<10.2f}x")


if __name__ == "__main__":
    run_inference_benchmarks()
