#!/usr/bin/env python3
"""
VIBEE vs Python Benchmark Comparison
Measures pure execution time (no I/O, no startup)
"""

import time
import subprocess
import os

def measure_python(func, iterations=1000):
    """Measure pure Python execution time"""
    # Warmup
    for _ in range(10):
        func()
    
    # Measure
    times = []
    for _ in range(iterations):
        start = time.perf_counter_ns()
        result = func()
        end = time.perf_counter_ns()
        times.append(end - start)
    
    avg_ns = sum(times) / len(times)
    min_ns = min(times)
    max_ns = max(times)
    
    return {
        'result': result,
        'avg_us': avg_ns / 1000,
        'min_us': min_ns / 1000,
        'max_us': max_ns / 1000,
    }

# Python implementations
def fib_iter(n):
    if n < 2:
        return n
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b

def sum_to(n):
    total = 0
    for i in range(1, n + 1):
        total += i
    return total

def factorial(n):
    result = 1
    for i in range(2, n + 1):
        result *= i
    return result

def is_prime(n):
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    i = 3
    while i * i <= n:
        if n % i == 0:
            return False
        i += 2
    return True

def count_primes(limit):
    count = 0
    for n in range(2, limit + 1):
        if is_prime(n):
            count += 1
    return count

def run_vibee_bench(bench_file, iterations=100):
    """Run VIBEE benchmark and parse results"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    vibee = os.path.join(script_dir, '..', 'bin', 'vibee')
    bench_path = os.path.join(script_dir, bench_file)
    
    result = subprocess.run(
        [vibee, 'bench', bench_path, str(iterations)],
        capture_output=True, text=True
    )
    
    output = result.stdout + result.stderr
    
    # Parse output - look for patterns like "43.588 µs"
    import re
    
    avg_time = 0
    instructions = 0
    ops_sec = 0
    bench_result = None
    
    # Match "Avg time:            43.588 µs"
    avg_match = re.search(r'Avg time:\s+([\d.]+)\s*µs', output)
    if avg_match:
        avg_time = float(avg_match.group(1))
    
    # Match "Instructions:           544"
    instr_match = re.search(r'Instructions:\s+(\d+)', output)
    if instr_match:
        instructions = int(instr_match.group(1))
    
    # Match "Ops/sec:           12480499"
    ops_match = re.search(r'Ops/sec:\s+(\d+)', output)
    if ops_match:
        ops_sec = int(ops_match.group(1))
    
    # Match "Result: 832040"
    result_match = re.search(r'Result:\s+(\S+)', output)
    if result_match:
        bench_result = result_match.group(1)
    
    return {
        'avg_us': avg_time,
        'instructions': instructions,
        'ops_sec': ops_sec,
        'result': bench_result
    }

def main():
    print("=" * 70)
    print("           VIBEE vs PYTHON BENCHMARK COMPARISON")
    print("           (Pure execution time, no I/O overhead)")
    print("=" * 70)
    print()
    
    benchmarks = [
        ('fib_iter.vb', 'fib(30)', lambda: fib_iter(30), 1000),
        ('factorial.vb', 'factorial(20)', lambda: factorial(20), 1000),
        ('sum_loop.vb', 'sum(10000)', lambda: sum_to(10000), 1000),
        ('primes_sieve.vb', 'primes(1000)', lambda: count_primes(1000), 100),
    ]
    
    print(f"{'Benchmark':<20} {'VIBEE (µs)':<15} {'Python (µs)':<15} {'Ratio':<10} {'Result'}")
    print("-" * 70)
    
    for vb_file, name, py_func, iters in benchmarks:
        # Run VIBEE
        vibee_result = run_vibee_bench(vb_file, iters)
        
        # Run Python
        py_result = measure_python(py_func, iters)
        
        # Calculate ratio
        if py_result['avg_us'] > 0:
            ratio = vibee_result['avg_us'] / py_result['avg_us']
        else:
            ratio = float('inf')
        
        print(f"{name:<20} {vibee_result['avg_us']:<15.2f} {py_result['avg_us']:<15.2f} {ratio:<10.1f}x {py_result['result']}")
    
    print("-" * 70)
    print()
    print("VIBEE VM Performance:")
    print(f"  Average: ~10-14 million ops/sec")
    print()
    print("Note: Python uses highly optimized C implementation.")
    print("VIBEE is a bytecode interpreter written in Zig.")

if __name__ == '__main__':
    main()
