"""
Optimizer Benchmarks
====================

Compare optimizer performance and memory usage.
"""

import torch
import torch.nn as nn
import time
from typing import Dict, Any
import sys
sys.path.insert(0, '..')

from vibee_ml.optimizers import Lion, Sophia, AdamMini, ScheduleFreeAdamW


def create_model(hidden_size: int = 1024, num_layers: int = 4) -> nn.Module:
    """Create a simple transformer-like model for benchmarking."""
    layers = []
    for _ in range(num_layers):
        layers.extend([
            nn.Linear(hidden_size, hidden_size * 4),
            nn.GELU(),
            nn.Linear(hidden_size * 4, hidden_size),
        ])
    return nn.Sequential(*layers)


def benchmark_optimizer(
    optimizer_class,
    model: nn.Module,
    num_steps: int = 100,
    batch_size: int = 32,
    seq_length: int = 512,
    hidden_size: int = 1024,
    **optimizer_kwargs
) -> Dict[str, Any]:
    """Benchmark a single optimizer."""
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    
    optimizer = optimizer_class(model.parameters(), **optimizer_kwargs)
    
    # Warmup
    for _ in range(5):
        x = torch.randn(batch_size, hidden_size, device=device)
        loss = model(x).sum()
        loss.backward()
        optimizer.step()
        optimizer.zero_grad()
    
    if device.type == "cuda":
        torch.cuda.synchronize()
        torch.cuda.reset_peak_memory_stats()
    
    # Benchmark
    start = time.perf_counter()
    
    for _ in range(num_steps):
        x = torch.randn(batch_size, hidden_size, device=device)
        loss = model(x).sum()
        loss.backward()
        optimizer.step()
        optimizer.zero_grad()
    
    if device.type == "cuda":
        torch.cuda.synchronize()
    
    elapsed = time.perf_counter() - start
    
    # Memory stats
    memory_mb = 0
    if device.type == "cuda":
        memory_mb = torch.cuda.max_memory_allocated() / 1024 / 1024
    
    return {
        "optimizer": optimizer_class.__name__,
        "total_time_s": elapsed,
        "time_per_step_ms": (elapsed / num_steps) * 1000,
        "steps_per_second": num_steps / elapsed,
        "peak_memory_mb": memory_mb,
    }


def run_all_benchmarks():
    """Run benchmarks for all optimizers."""
    print("=" * 60)
    print("VIBEE ML Optimizer Benchmarks")
    print("=" * 60)
    
    hidden_size = 1024
    model_template = lambda: create_model(hidden_size=hidden_size)
    
    optimizers = [
        (torch.optim.AdamW, {"lr": 1e-4, "weight_decay": 0.01}),
        (Lion, {"lr": 1e-5, "weight_decay": 0.1}),
        (Sophia, {"lr": 1e-4, "weight_decay": 0.1}),
        (AdamMini, {"lr": 1e-4, "weight_decay": 0.01}),
        (ScheduleFreeAdamW, {"lr": 1e-3, "weight_decay": 0.01}),
    ]
    
    results = []
    
    for opt_class, kwargs in optimizers:
        print(f"\nBenchmarking {opt_class.__name__}...")
        model = model_template()
        result = benchmark_optimizer(opt_class, model, **kwargs)
        results.append(result)
        print(f"  Time/step: {result['time_per_step_ms']:.2f} ms")
        print(f"  Memory: {result['peak_memory_mb']:.1f} MB")
    
    # Summary
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    print(f"{'Optimizer':<20} {'Time/Step (ms)':<15} {'Memory (MB)':<15}")
    print("-" * 50)
    
    baseline_time = results[0]["time_per_step_ms"]
    for r in results:
        speedup = baseline_time / r["time_per_step_ms"]
        print(f"{r['optimizer']:<20} {r['time_per_step_ms']:<15.2f} {r['peak_memory_mb']:<15.1f}")
    
    return results


if __name__ == "__main__":
    run_all_benchmarks()
