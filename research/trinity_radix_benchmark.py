#!/usr/bin/env python3
"""
Trinity Radix Sort: Base-3 Radix Sort
Testing if base 3 is optimal for radix sort

Author: Dmitrii Vasilev
Date: January 13, 2026

Hypothesis: Base 3 may be optimal due to 3-adic structure
"""

import random
import time
import math
from typing import List

print("=" * 70)
print("TRINITY RADIX SORT: BASE-3 vs BASE-2 vs BASE-10")
print("=" * 70)

# =============================================================================
# RADIX SORT IMPLEMENTATIONS
# =============================================================================

def counting_sort_by_digit(arr: List[int], exp: int, base: int) -> List[int]:
    """Counting sort by a specific digit"""
    n = len(arr)
    output = [0] * n
    count = [0] * base
    
    # Count occurrences
    for num in arr:
        digit = (num // exp) % base
        count[digit] += 1
    
    # Cumulative count
    for i in range(1, base):
        count[i] += count[i - 1]
    
    # Build output (stable)
    for i in range(n - 1, -1, -1):
        digit = (arr[i] // exp) % base
        output[count[digit] - 1] = arr[i]
        count[digit] -= 1
    
    return output

def radix_sort(arr: List[int], base: int = 10) -> List[int]:
    """Radix sort with configurable base"""
    if not arr:
        return arr
    
    result = arr.copy()
    max_val = max(result)
    
    exp = 1
    passes = 0
    
    while max_val // exp > 0:
        result = counting_sort_by_digit(result, exp, base)
        exp *= base
        passes += 1
    
    return result, passes

def radix_sort_base2(arr: List[int]) -> List[int]:
    """Binary radix sort (base 2)"""
    return radix_sort(arr, base=2)

def radix_sort_base3(arr: List[int]) -> List[int]:
    """Trinity radix sort (base 3)"""
    return radix_sort(arr, base=3)

def radix_sort_base10(arr: List[int]) -> List[int]:
    """Decimal radix sort (base 10)"""
    return radix_sort(arr, base=10)

def radix_sort_base256(arr: List[int]) -> List[int]:
    """Byte radix sort (base 256)"""
    return radix_sort(arr, base=256)

# =============================================================================
# THEORETICAL ANALYSIS
# =============================================================================

def theoretical_analysis():
    """Analyze optimal base for radix sort"""
    
    print("\n" + "=" * 70)
    print("THEORETICAL ANALYSIS: OPTIMAL BASE FOR RADIX SORT")
    print("=" * 70)
    
    print("""
    RADIX SORT COMPLEXITY:
    
    Time: O(d × (n + b))
    where:
      d = number of digits = log_b(max_value)
      n = array size
      b = base
    
    Total: O(log_b(M) × (n + b)) where M = max value
    
    OPTIMIZATION:
    Minimize: log_b(M) × (n + b)
    
    For large n >> b:
      Minimize: log_b(M) × n = n × ln(M) / ln(b)
      → Larger base is better (fewer passes)
    
    For small n:
      The (n + b) term matters
      → Smaller base may be better
    
    CROSSOVER POINT:
    When n ≈ b, the optimal base depends on M
    """)
    
    print("\nPasses needed for max_value = 1,000,000:")
    print(f"{'Base':<10} {'Passes':<10} {'log_b(M)':<15} {'Bucket size'}")
    print("-" * 50)
    
    M = 1000000
    for base in [2, 3, 4, 8, 10, 16, 256]:
        passes = math.ceil(math.log(M, base))
        print(f"{base:<10} {passes:<10} {math.log(M, base):<15.2f} {base}")

# =============================================================================
# BENCHMARK
# =============================================================================

def benchmark_radix():
    """Benchmark different radix bases"""
    
    print("\n" + "=" * 70)
    print("BENCHMARK: RADIX SORT WITH DIFFERENT BASES")
    print("=" * 70)
    
    sizes = [1000, 10000, 100000]
    max_values = [100, 10000, 1000000]
    
    for n in sizes:
        for max_val in max_values:
            print(f"\n--- n = {n:,}, max_value = {max_val:,} ---")
            
            random.seed(42)
            arr = [random.randint(0, max_val) for _ in range(n)]
            
            bases = [2, 3, 4, 8, 10, 16, 256]
            
            print(f"{'Base':<10} {'Passes':<10} {'Time (ms)':<15} {'Verified'}")
            print("-" * 50)
            
            results = []
            for base in bases:
                arr_copy = arr.copy()
                
                start = time.perf_counter()
                sorted_arr, passes = radix_sort(arr_copy, base)
                end = time.perf_counter()
                
                time_ms = (end - start) * 1000
                verified = sorted_arr == sorted(arr)
                
                results.append((base, passes, time_ms))
                print(f"{base:<10} {passes:<10} {time_ms:<15.3f} {'✓' if verified else '✗'}")
            
            # Find best
            best = min(results, key=lambda x: x[2])
            print(f"\n  → Best base: {best[0]} ({best[2]:.3f} ms)")

def benchmark_vs_trinity_sort():
    """Compare radix sort with Trinity Sort"""
    
    print("\n" + "=" * 70)
    print("COMPARISON: RADIX SORT vs TRINITY SORT")
    print("=" * 70)
    
    # Import Trinity Sort logic
    def trinity_sort(arr):
        """Simplified Trinity Sort"""
        if len(arr) <= 1:
            return arr
        
        result = arr.copy()
        
        def partition3(a, lo, hi):
            pivot = a[lo + (hi - lo) * 618 // 1000]  # Golden ratio
            lt, i, gt = lo, lo, hi
            
            while i <= gt:
                if a[i] < pivot:
                    a[lt], a[i] = a[i], a[lt]
                    lt += 1
                    i += 1
                elif a[i] > pivot:
                    a[i], a[gt] = a[gt], a[i]
                    gt -= 1
                else:
                    i += 1
            return lt, gt
        
        def sort(a, lo, hi):
            if hi <= lo:
                return
            if hi - lo <= 27:
                # Insertion sort
                for i in range(lo + 1, hi + 1):
                    key = a[i]
                    j = i - 1
                    while j >= lo and a[j] > key:
                        a[j + 1] = a[j]
                        j -= 1
                    a[j + 1] = key
                return
            
            lt, gt = partition3(a, lo, hi)
            sort(a, lo, lt - 1)
            sort(a, gt + 1, hi)
        
        sort(result, 0, len(result) - 1)
        return result
    
    print("\nComparing on different data distributions:")
    
    n = 100000
    
    test_cases = [
        ("Random (0-1M)", [random.randint(0, 1000000) for _ in range(n)]),
        ("Random (0-100)", [random.randint(0, 100) for _ in range(n)]),
        ("Few unique (10)", [random.randint(0, 10) for _ in range(n)]),
        ("Few unique (3)", [random.choice([1, 2, 3]) for _ in range(n)]),
    ]
    
    print(f"\n{'Distribution':<25} {'Trinity (ms)':<15} {'Radix-3 (ms)':<15} {'Radix-256 (ms)':<15} {'Best'}")
    print("-" * 85)
    
    for name, arr in test_cases:
        random.seed(42)
        
        # Trinity Sort
        arr1 = arr.copy()
        start = time.perf_counter()
        trinity_sort(arr1)
        trinity_time = (time.perf_counter() - start) * 1000
        
        # Radix base 3
        arr2 = arr.copy()
        start = time.perf_counter()
        radix_sort(arr2, base=3)
        radix3_time = (time.perf_counter() - start) * 1000
        
        # Radix base 256
        arr3 = arr.copy()
        start = time.perf_counter()
        radix_sort(arr3, base=256)
        radix256_time = (time.perf_counter() - start) * 1000
        
        best = "Trinity" if trinity_time < min(radix3_time, radix256_time) else \
               "Radix-3" if radix3_time < radix256_time else "Radix-256"
        
        print(f"{name:<25} {trinity_time:<15.2f} {radix3_time:<15.2f} {radix256_time:<15.2f} {best}")

# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    theoretical_analysis()
    benchmark_radix()
    benchmark_vs_trinity_sort()
    
    print("\n" + "=" * 70)
    print("CONCLUSIONS")
    print("=" * 70)
    
    print("""
    KEY FINDINGS:
    
    1. OPTIMAL RADIX BASE DEPENDS ON DATA
       - Small max_value: smaller base (fewer buckets)
       - Large max_value: larger base (fewer passes)
       - Base 256 often wins for general data
    
    2. BASE 3 IS NOT OPTIMAL FOR RADIX SORT
       - Too many passes (log₃ vs log₂₅₆)
       - 3-adic structure doesn't help here
       - The "3" in Trinity Sort is about PARTITIONING, not base
    
    3. TRINITY SORT vs RADIX SORT
       - Trinity Sort: O(n log k) for k unique values
       - Radix Sort: O(d × n) where d = digits
       - Trinity wins for few unique values
       - Radix wins for many unique values with bounded range
    
    4. THE REAL INSIGHT
       - Number 3 helps in COMPARISON-BASED algorithms
       - 3-way partition reduces comparisons
       - Radix sort is NOT comparison-based
       - Different optimization principles apply
    
    RECOMMENDATION:
    - Use Trinity Sort for comparison-based sorting
    - Use Radix Sort (base 256) for integer sorting with known range
    - The number 3 is powerful for PARTITIONING, not for BASES
    """)
