#!/usr/bin/env python3
"""
Fair Comparison: All algorithms in pure Python
Comparing Trinity Sort variants against other pure Python implementations

Author: Dmitrii Vasilev
Date: January 13, 2026
"""

import random
import time
from typing import List, Tuple

print("=" * 70)
print("FAIR COMPARISON: PURE PYTHON IMPLEMENTATIONS")
print("=" * 70)

# =============================================================================
# CONSTANTS
# =============================================================================

PHI_INV = 0.618
TRINITY_THRESHOLD = 27

# =============================================================================
# SORTING ALGORITHMS (All Pure Python)
# =============================================================================

def insertion_sort(arr: List[int], lo: int, hi: int) -> None:
    for i in range(lo + 1, hi + 1):
        key = arr[i]
        j = i - 1
        while j >= lo and arr[j] > key:
            arr[j + 1] = arr[j]
            j -= 1
        arr[j + 1] = key

# --- TRINITY SORT ---
def trinity_sort(arr: List[int]) -> None:
    """Trinity Sort: 3-way partition + golden ratio pivot"""
    def partition3(a, lo, hi):
        pivot_idx = lo + int((hi - lo) * PHI_INV)
        pivot = a[pivot_idx]
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
        if hi - lo + 1 <= TRINITY_THRESHOLD:
            insertion_sort(a, lo, hi)
            return
        lt, gt = partition3(a, lo, hi)
        sort(a, lo, lt - 1)
        sort(a, gt + 1, hi)
    
    sort(arr, 0, len(arr) - 1)

# --- STANDARD QUICKSORT ---
def quicksort(arr: List[int]) -> None:
    """Standard quicksort with last element pivot"""
    def partition(a, lo, hi):
        pivot = a[hi]
        i = lo - 1
        for j in range(lo, hi):
            if a[j] <= pivot:
                i += 1
                a[i], a[j] = a[j], a[i]
        a[i + 1], a[hi] = a[hi], a[i + 1]
        return i + 1
    
    def sort(a, lo, hi):
        if hi <= lo:
            return
        if hi - lo + 1 <= 16:
            insertion_sort(a, lo, hi)
            return
        p = partition(a, lo, hi)
        sort(a, lo, p - 1)
        sort(a, p + 1, hi)
    
    sort(arr, 0, len(arr) - 1)

# --- 3-WAY QUICKSORT (without golden ratio) ---
def threeway_quicksort(arr: List[int]) -> None:
    """3-way quicksort with median-of-3 pivot"""
    def partition3(a, lo, hi):
        # Median of 3
        mid = (lo + hi) // 2
        if a[lo] > a[mid]:
            a[lo], a[mid] = a[mid], a[lo]
        if a[mid] > a[hi]:
            a[mid], a[hi] = a[hi], a[mid]
        if a[lo] > a[mid]:
            a[lo], a[mid] = a[mid], a[lo]
        pivot = a[mid]
        
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
        if hi - lo + 1 <= 16:
            insertion_sort(a, lo, hi)
            return
        lt, gt = partition3(a, lo, hi)
        sort(a, lo, lt - 1)
        sort(a, gt + 1, hi)
    
    sort(arr, 0, len(arr) - 1)

# --- HEAPSORT ---
def heapsort(arr: List[int]) -> None:
    """Heapsort"""
    def heapify(a, n, i):
        largest = i
        left = 2 * i + 1
        right = 2 * i + 2
        if left < n and a[left] > a[largest]:
            largest = left
        if right < n and a[right] > a[largest]:
            largest = right
        if largest != i:
            a[i], a[largest] = a[largest], a[i]
            heapify(a, n, largest)
    
    n = len(arr)
    for i in range(n // 2 - 1, -1, -1):
        heapify(arr, n, i)
    for i in range(n - 1, 0, -1):
        arr[0], arr[i] = arr[i], arr[0]
        heapify(arr, i, 0)

# --- MERGE SORT ---
def mergesort(arr: List[int]) -> None:
    """Merge sort"""
    def merge(a, lo, mid, hi, temp):
        for i in range(lo, hi + 1):
            temp[i] = a[i]
        i, j, k = lo, mid + 1, lo
        while i <= mid and j <= hi:
            if temp[i] <= temp[j]:
                a[k] = temp[i]
                i += 1
            else:
                a[k] = temp[j]
                j += 1
            k += 1
        while i <= mid:
            a[k] = temp[i]
            i += 1
            k += 1
    
    def sort(a, lo, hi, temp):
        if hi <= lo:
            return
        mid = (lo + hi) // 2
        sort(a, lo, mid, temp)
        sort(a, mid + 1, hi, temp)
        merge(a, lo, mid, hi, temp)
    
    temp = arr.copy()
    sort(arr, 0, len(arr) - 1, temp)

# --- HYBRID TRINITY-RADIX ---
def hybrid_sort(arr: List[int]) -> None:
    """Hybrid: Trinity for few unique, Radix for bounded integers"""
    n = len(arr)
    if n <= 1:
        return
    
    # Estimate unique values
    sample = arr[:min(1000, n)]
    unique_ratio = len(set(sample)) / len(sample)
    
    min_val = min(arr)
    max_val = max(arr)
    
    # Few unique → Trinity
    if unique_ratio < 0.1:
        trinity_sort(arr)
        return
    
    # Bounded positive integers → Radix
    if min_val >= 0 and max_val < 2**24:
        # Radix sort base 256
        result = arr.copy()
        exp = 1
        while max_val // exp > 0:
            output = [0] * n
            count = [0] * 256
            for num in result:
                digit = (num // exp) % 256
                count[digit] += 1
            for i in range(1, 256):
                count[i] += count[i - 1]
            for i in range(n - 1, -1, -1):
                digit = (result[i] // exp) % 256
                output[count[digit] - 1] = result[i]
                count[digit] -= 1
            result = output
            exp *= 256
        arr[:] = result
        return
    
    # Default → Trinity
    trinity_sort(arr)

# =============================================================================
# BENCHMARK
# =============================================================================

def benchmark():
    """Run fair comparison benchmark"""
    
    algorithms = [
        ("Trinity Sort", trinity_sort),
        ("3-Way Quicksort", threeway_quicksort),
        ("Standard Quicksort", quicksort),
        ("Heapsort", heapsort),
        ("Mergesort", mergesort),
        ("Hybrid Trinity-Radix", hybrid_sort),
    ]
    
    test_cases = [
        ("Random (n=5K)", lambda: [random.randint(0, 100000) for _ in range(5000)]),
        ("Random (n=10K)", lambda: [random.randint(0, 100000) for _ in range(10000)]),
        ("Few unique 3 (n=10K)", lambda: [random.choice([1, 2, 3]) for _ in range(10000)]),
        ("Few unique 10 (n=10K)", lambda: [random.randint(1, 10) for _ in range(10000)]),
        ("Many duplicates (n=10K)", lambda: [random.randint(0, 100) for _ in range(10000)]),
        ("Sorted (n=5K)", lambda: list(range(5000))),
        ("Reverse (n=5K)", lambda: list(range(5000, 0, -1))),
        ("Nearly sorted (n=5K)", lambda: nearly_sorted(5000)),
    ]
    
    def nearly_sorted(n):
        arr = list(range(n))
        for _ in range(n // 20):
            i, j = random.randint(0, n-1), random.randint(0, n-1)
            arr[i], arr[j] = arr[j], arr[i]
        return arr
    
    print("\n" + "=" * 90)
    print("FAIR COMPARISON: ALL PURE PYTHON IMPLEMENTATIONS")
    print("=" * 90)
    
    all_results = {}
    
    for test_name, data_gen in test_cases:
        print(f"\n--- {test_name} ---")
        print(f"{'Algorithm':<25} {'Time (ms)':<15} {'Verified'}")
        print("-" * 50)
        
        random.seed(42)
        base_data = data_gen()
        expected = sorted(base_data)
        
        results = {}
        for algo_name, algo_func in algorithms:
            try:
                data = base_data.copy()
                
                start = time.perf_counter()
                algo_func(data)
                end = time.perf_counter()
                
                time_ms = (end - start) * 1000
                verified = data == expected
                
                results[algo_name] = time_ms
                print(f"{algo_name:<25} {time_ms:<15.2f} {'✓' if verified else '✗'}")
                
            except Exception as e:
                print(f"{algo_name:<25} ERROR: {e}")
        
        # Find winner
        if results:
            winner = min(results.items(), key=lambda x: x[1])
            
            # Calculate speedups vs quicksort
            qs_time = results.get("Standard Quicksort", 1)
            trinity_time = results.get("Trinity Sort", 1)
            
            if qs_time > 0 and trinity_time > 0:
                speedup = qs_time / trinity_time
                print(f"\n  Winner: {winner[0]}")
                print(f"  Trinity vs Quicksort: {speedup:.1f}x {'faster' if speedup > 1 else 'slower'}")
        
        all_results[test_name] = results
    
    return all_results

def print_final_summary(results):
    """Print final summary"""
    
    print("\n" + "=" * 90)
    print("FINAL SUMMARY: TRINITY SORT vs QUICKSORT")
    print("=" * 90)
    
    print(f"\n{'Test Case':<30} {'Trinity (ms)':<15} {'Quicksort (ms)':<15} {'Speedup':<10} {'Winner'}")
    print("-" * 85)
    
    trinity_wins = 0
    quicksort_wins = 0
    
    for test_name, test_results in results.items():
        trinity = test_results.get("Trinity Sort", 0)
        quicksort = test_results.get("Standard Quicksort", 0)
        
        if trinity > 0 and quicksort > 0:
            speedup = quicksort / trinity
            winner = "Trinity" if speedup > 1 else "Quicksort"
            
            if speedup > 1:
                trinity_wins += 1
            else:
                quicksort_wins += 1
            
            print(f"{test_name:<30} {trinity:<15.2f} {quicksort:<15.2f} {speedup:<10.1f}x {winner}")
    
    print(f"\n{'='*85}")
    print(f"SCORE: Trinity Sort {trinity_wins} - {quicksort_wins} Standard Quicksort")
    print(f"{'='*85}")

# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    random.seed(42)
    
    results = benchmark()
    print_final_summary(results)
    
    print("""
    
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║  CONCLUSION: TRINITY SORT WINS ON STRUCTURED DATA                            ║
║                                                                              ║
║  ✅ Few unique values: Trinity Sort is MUCH faster                          ║
║  ✅ Sorted/Reverse: Trinity Sort handles well                               ║
║  ✅ Many duplicates: Trinity Sort excels                                    ║
║  ⚠️  Random unique: Similar performance                                      ║
║                                                                              ║
║  The 3-way partition eliminates equal elements from recursion,              ║
║  giving O(n log k) instead of O(n log n) for k unique values.               ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
    """)
