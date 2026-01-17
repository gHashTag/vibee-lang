#!/usr/bin/env python3
"""Fibonacci benchmark for comparison with VIBEE VM"""

import time

def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

def benchmark_fib(n, iterations=5):
    """Run fibonacci benchmark multiple times and report statistics"""
    times = []
    result = None
    
    for _ in range(iterations):
        start = time.perf_counter()
        result = fib(n)
        end = time.perf_counter()
        times.append((end - start) * 1000)  # Convert to ms
    
    avg = sum(times) / len(times)
    min_t = min(times)
    max_t = max(times)
    
    print(f"fib({n}) = {result}")
    print(f"  Average: {avg:.3f} ms")
    print(f"  Min:     {min_t:.3f} ms")
    print(f"  Max:     {max_t:.3f} ms")
    return avg

if __name__ == "__main__":
    print("Python Fibonacci Benchmark")
    print("=" * 40)
    print(f"Python version: {__import__('sys').version}")
    print()
    
    # Test various sizes
    for n in [10, 20, 25, 30]:
        benchmark_fib(n)
        print()
