#!/usr/bin/env python3
"""
VIBEE vs Zig vs Python Benchmark Comparison
"""

import time
import subprocess
import os
import re

def measure_python(func, iterations=1000):
    """Measure pure Python execution time"""
    for _ in range(10):
        func()
    
    times = []
    for _ in range(iterations):
        start = time.perf_counter_ns()
        result = func()
        end = time.perf_counter_ns()
        times.append(end - start)
    
    return {
        'result': result,
        'avg_us': sum(times) / len(times) / 1000,
        'min_us': min(times) / 1000,
    }

# Python implementations
def fib_iter(n):
    if n < 2:
        return n
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b

def factorial(n):
    result = 1
    for i in range(2, n + 1):
        result *= i
    return result

def sum_to(n):
    total = 0
    for i in range(1, n + 1):
        total += i
    return total

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
    """Run VIBEE benchmark"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    vibee = os.path.join(script_dir, '..', 'bin', 'vibee')
    bench_path = os.path.join(script_dir, bench_file)
    
    result = subprocess.run(
        [vibee, 'bench', bench_path, str(iterations)],
        capture_output=True, text=True
    )
    
    output = result.stdout + result.stderr
    
    avg_match = re.search(r'Avg time:\s+([\d.]+)\s*µs', output)
    avg_time = float(avg_match.group(1)) if avg_match else 0
    
    instr_match = re.search(r'Instructions:\s+(\d+)', output)
    instructions = int(instr_match.group(1)) if instr_match else 0
    
    return {'avg_us': avg_time, 'instructions': instructions}

def run_zig_bench():
    """Run Zig native benchmark and parse results"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    zig_bench = os.path.join(script_dir, 'zig', 'bench_zig')
    
    result = subprocess.run([zig_bench], capture_output=True, text=True)
    output = result.stdout + result.stderr
    
    results = {}
    for line in output.split('\n'):
        if 'fib(30)' in line:
            match = re.search(r'([\d.]+)\s*µs', line)
            if match:
                results['fib'] = float(match.group(1))
        elif 'factorial(20)' in line:
            match = re.search(r'([\d.]+)\s*µs', line)
            if match:
                results['factorial'] = float(match.group(1))
        elif 'sum(10000)' in line:
            match = re.search(r'([\d.]+)\s*µs', line)
            if match:
                results['sum'] = float(match.group(1))
        elif 'primes(1000)' in line:
            match = re.search(r'([\d.]+)\s*µs', line)
            if match:
                results['primes'] = float(match.group(1))
        elif 'ternary(1000)' in line:
            match = re.search(r'([\d.]+)\s*µs', line)
            if match:
                results['ternary'] = float(match.group(1))
    
    return results

def main():
    print()
    print("=" * 80)
    print("           VIBEE VM vs ZIG NATIVE vs PYTHON COMPARISON")
    print("=" * 80)
    print()
    
    # Get Zig results
    zig_results = run_zig_bench()
    
    benchmarks = [
        ('fib_iter.vb', 'fib(30)', lambda: fib_iter(30), 'fib', 1000),
        ('factorial.vb', 'factorial(20)', lambda: factorial(20), 'factorial', 1000),
        ('sum_loop.vb', 'sum(10000)', lambda: sum_to(10000), 'sum', 100),
        ('primes_sieve.vb', 'primes(1000)', lambda: count_primes(1000), 'primes', 100),
    ]
    
    print(f"{'Benchmark':<15} {'Zig (µs)':<12} {'Python (µs)':<12} {'VIBEE (µs)':<12} {'Zig/VIBEE':<10} {'Py/VIBEE':<10}")
    print("-" * 80)
    
    for vb_file, name, py_func, zig_key, iters in benchmarks:
        # Run all benchmarks
        vibee = run_vibee_bench(vb_file, iters)
        python = measure_python(py_func, iters)
        zig_us = zig_results.get(zig_key, 0)
        
        # Calculate ratios
        zig_ratio = vibee['avg_us'] / zig_us if zig_us > 0 else 0
        py_ratio = vibee['avg_us'] / python['avg_us'] if python['avg_us'] > 0 else 0
        
        print(f"{name:<15} {zig_us:<12.3f} {python['avg_us']:<12.3f} {vibee['avg_us']:<12.2f} {zig_ratio:<10.0f}x {py_ratio:<10.1f}x")
    
    print("-" * 80)
    print()
    print("INTERPRETATION:")
    print("  - Zig native: Compiled to machine code, maximum performance")
    print("  - Python: Interpreted, but highly optimized C implementation")
    print("  - VIBEE VM: Bytecode interpreter written in Zig")
    print()
    print("  Zig/VIBEE ratio shows the cost of interpretation vs native code")
    print("  Py/VIBEE ratio shows VIBEE performance relative to Python")
    print()

if __name__ == '__main__':
    main()
