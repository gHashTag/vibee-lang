#!/usr/bin/env python3
"""
Binary vs Ternary Benchmark Comparison
Compares performance of binary and ternary arithmetic in VIBEE VM
"""

import subprocess
import os
import re

def run_bench(file_path, iterations=100):
    """Run VIBEE benchmark and extract metrics"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    vibee = os.path.join(script_dir, '..', '..', 'bin', 'vibee')
    
    result = subprocess.run(
        [vibee, 'bench', file_path, str(iterations)],
        capture_output=True, text=True
    )
    
    output = result.stdout + result.stderr
    
    avg_match = re.search(r'Avg time:\s+([\d.]+)\s*µs', output)
    avg_time = float(avg_match.group(1)) if avg_match else 0
    
    instr_match = re.search(r'Instructions:\s+(\d+)', output)
    instructions = int(instr_match.group(1)) if instr_match else 0
    
    ops_match = re.search(r'Ops/sec:\s+(\d+)', output)
    ops_sec = int(ops_match.group(1)) if ops_match else 0
    
    result_match = re.search(r'Result:\s+(-?\d+)', output)
    bench_result = result_match.group(1) if result_match else "?"
    
    return {
        'time_us': avg_time,
        'instructions': instructions,
        'ops_sec': ops_sec,
        'result': bench_result
    }

def create_bench_file(name, code):
    """Create a temporary benchmark file"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(script_dir, f'_temp_{name}.vb')
    with open(path, 'w') as f:
        f.write(code)
    return path

def cleanup_temp_files():
    """Remove temporary benchmark files"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    for f in os.listdir(script_dir):
        if f.startswith('_temp_'):
            os.remove(os.path.join(script_dir, f))

# Benchmark definitions
BENCHMARKS = {
    'add_1000': {
        'binary': '''
fn add_loop(n) {
    let total = 0
    let i = 0
    while i < n {
        total = total + 1
        i = i + 1
    }
    return total
}
add_loop(1000)
''',
        'ternary': '''
fn add_loop(n) {
    let total = 0t000
    let one = 0t001
    let i = 0
    while i < n {
        total = tritAdd(total, one)
        i = i + 1
    }
    return fromTryte(total)
}
add_loop(1000)
'''
    },
    'sum_100': {
        'binary': '''
fn sum_seq(n) {
    let total = 0
    let i = 1
    while i <= n {
        total = total + i
        i = i + 1
    }
    return total
}
sum_seq(100)
''',
        'ternary': '''
fn sum_seq(n) {
    let total = 0t000
    let i = 1
    while i <= n {
        let t = toTryte(i)
        total = tritAdd(total, t)
        i = i + 1
    }
    return fromTryte(total)
}
sum_seq(100)
'''
    },
    'mul_10': {
        'binary': '''
fn mul_powers(n) {
    let result = 1
    let i = 0
    while i < n {
        result = result * 2
        i = i + 1
    }
    return result
}
mul_powers(10)
''',
        'ternary': '''
fn mul_powers(n) {
    let result = 0t001
    let three = 0t010
    let i = 0
    while i < n {
        result = tritMul(result, three)
        i = i + 1
    }
    return fromTryte(result)
}
mul_powers(10)
'''
    },
    'fib_20': {
        'binary': '''
fn fib(n) {
    let a = 0
    let b = 1
    let i = 0
    while i < n {
        let t = a + b
        a = b
        b = t
        i = i + 1
    }
    return b
}
fib(20)
''',
        'ternary': '''
fn fib(n) {
    let a = 0t000
    let b = 0t001
    let i = 0
    while i < n {
        let t = tritAdd(a, b)
        a = b
        b = t
        i = i + 1
    }
    return fromTryte(b)
}
fib(20)
'''
    },
    'logic_100': {
        'binary': '''
fn logic_chain(n) {
    let result = 1
    let i = 0
    while i < n {
        let a = i % 2
        let b = i % 3
        if a == 0 and b == 0 {
            result = result + 1
        }
        i = i + 1
    }
    return result
}
logic_chain(100)
''',
        'ternary': '''
fn logic_chain(n) {
    let result = 0t001
    let one = 0t001
    let i = 0
    while i < n {
        let a = toTryte(i % 3)
        let b = toTryte(i % 3)
        let c = tritMul(a, b)
        if fromTryte(c) == 0 {
            result = tritAdd(result, one)
        }
        i = i + 1
    }
    return fromTryte(result)
}
logic_chain(100)
'''
    },
    'compare_100': {
        'binary': '''
fn compare_loop(n) {
    let count = 0
    let i = 0
    while i < n {
        if i < 50 {
            count = count + 1
        }
        i = i + 1
    }
    return count
}
compare_loop(100)
''',
        'ternary': '''
fn compare_loop(n) {
    let count = 0t000
    let one = 0t001
    let threshold = toTryte(10)
    let i = 0
    while i < n {
        let t = toTryte(i % 27)
        if fromTryte(t) < fromTryte(threshold) {
            count = tritAdd(count, one)
        }
        i = i + 1
    }
    return fromTryte(count)
}
compare_loop(100)
'''
    }
}

def main():
    print()
    print("=" * 75)
    print("           BINARY vs TERNARY ARITHMETIC BENCHMARK")
    print("           VIBEE VM - Same algorithms, different number systems")
    print("=" * 75)
    print()
    
    print(f"{'Benchmark':<15} {'Binary (µs)':<15} {'Ternary (µs)':<15} {'Ratio':<10} {'Binary':<12} {'Ternary'}")
    print("-" * 75)
    
    results = []
    
    for name, codes in BENCHMARKS.items():
        # Create temp files
        bin_file = create_bench_file(f'{name}_bin', codes['binary'])
        ter_file = create_bench_file(f'{name}_ter', codes['ternary'])
        
        # Run benchmarks
        bin_result = run_bench(bin_file, 100)
        ter_result = run_bench(ter_file, 100)
        
        # Calculate ratio
        ratio = ter_result['time_us'] / bin_result['time_us'] if bin_result['time_us'] > 0 else 0
        
        print(f"{name:<15} {bin_result['time_us']:<15.2f} {ter_result['time_us']:<15.2f} {ratio:<10.2f}x {bin_result['result']:<12} {ter_result['result']}")
        
        results.append({
            'name': name,
            'binary': bin_result,
            'ternary': ter_result,
            'ratio': ratio
        })
    
    print("-" * 75)
    print()
    
    # Summary
    avg_ratio = sum(r['ratio'] for r in results) / len(results)
    
    print("SUMMARY:")
    print(f"  Average ternary/binary ratio: {avg_ratio:.2f}x")
    print()
    print("INTERPRETATION:")
    print("  - Ratio > 1: Ternary is slower than binary")
    print("  - Ratio < 1: Ternary is faster than binary")
    print()
    print("  Ternary operations use native functions (tritAdd, tritMul)")
    print("  which have function call overhead vs inline binary ops.")
    print()
    print("  Ternary results wrap around (-13 to +13 range)")
    print()
    
    # Cleanup
    cleanup_temp_files()

if __name__ == '__main__':
    main()
