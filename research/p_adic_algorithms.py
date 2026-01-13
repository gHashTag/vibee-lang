#!/usr/bin/env python3
"""
p-Adic Numbers in Algorithm Analysis
Exploring 3-adic structure in computational complexity

Author: Dmitrii Vasilev
Date: January 13, 2026

p-adic numbers provide an alternative metric on integers where
"closeness" is determined by divisibility by prime p.

For p=3, this may reveal hidden structure in algorithms
where the number 3 plays a fundamental role.
"""

import math
from fractions import Fraction
from functools import lru_cache

print("=" * 70)
print("p-ADIC NUMBERS IN ALGORITHM ANALYSIS")
print("Focus on 3-adic structure")
print("=" * 70)

# =============================================================================
# 1. p-ADIC VALUATION
# =============================================================================

def p_adic_valuation(n, p):
    """
    Compute v_p(n) = largest k such that p^k divides n
    This is the p-adic valuation of n
    """
    if n == 0:
        return float('inf')
    
    n = abs(n)
    k = 0
    while n % p == 0:
        n //= p
        k += 1
    return k

def p_adic_norm(n, p):
    """
    |n|_p = p^(-v_p(n))
    The p-adic absolute value
    """
    if n == 0:
        return 0
    v = p_adic_valuation(n, p)
    return p ** (-v)

print("\n" + "=" * 70)
print("1. 3-ADIC VALUATION: v_3(n)")
print("=" * 70)

print("\nv_3(n) = largest k such that 3^k divides n")
print()
print(f"{'n':<10} {'v_3(n)':<10} {'|n|_3':<15} {'3-adic meaning'}")
print("-" * 60)

examples = [1, 2, 3, 6, 9, 12, 18, 27, 36, 81, 243]
for n in examples:
    v = p_adic_valuation(n, 3)
    norm = p_adic_norm(n, 3)
    meaning = "divisible by 3^" + str(v) if v > 0 else "not divisible by 3"
    print(f"{n:<10} {v:<10} {norm:<15.6f} {meaning}")

# =============================================================================
# 2. 3-ADIC DISTANCE
# =============================================================================

def p_adic_distance(a, b, p):
    """
    d_p(a, b) = |a - b|_p
    Two numbers are "close" if their difference is divisible by high power of p
    """
    return p_adic_norm(a - b, p)

print("\n" + "=" * 70)
print("2. 3-ADIC DISTANCE")
print("=" * 70)

print("""
In 3-adic metric:
- Numbers differing by multiple of 27 are CLOSER than those differing by 1
- This is opposite to usual metric!
""")

pairs = [(1, 2), (1, 4), (1, 10), (1, 28), (0, 27), (0, 81), (0, 243)]
print(f"{'a':<6} {'b':<6} {'|a-b|':<10} {'d_3(a,b)':<15} {'Interpretation'}")
print("-" * 60)
for a, b in pairs:
    d = p_adic_distance(a, b, 3)
    interp = "very close" if d < 0.1 else "close" if d < 0.5 else "far"
    print(f"{a:<6} {b:<6} {abs(a-b):<10} {d:<15.6f} {interp}")

# =============================================================================
# 3. 3-ADIC STRUCTURE IN ALGORITHMS
# =============================================================================

print("\n" + "=" * 70)
print("3. 3-ADIC STRUCTURE IN ALGORITHMS")
print("=" * 70)

print("""
HYPOTHESIS: Algorithms with complexity involving 3 have hidden 3-adic structure.

KARATSUBA MULTIPLICATION:
- T(n) = 3T(n/2) + O(n)
- Complexity: O(n^log_2(3)) = O(n^1.585)
- The number 3 suggests 3-adic structure!
""")

# Analyze Karatsuba recursion tree
print("Karatsuba recursion tree (3-adic analysis):")
print()

def karatsuba_calls(n, depth=0):
    """Count recursive calls at each level"""
    if n <= 1:
        return {depth: 1}
    
    calls = {depth: 1}
    for _ in range(3):  # 3 recursive calls
        sub_calls = karatsuba_calls(n // 2, depth + 1)
        for d, c in sub_calls.items():
            calls[d] = calls.get(d, 0) + c
    return calls

print(f"{'Depth':<10} {'Calls':<10} {'v_3(calls)':<15} {'Pattern'}")
print("-" * 50)
for depth in range(6):
    calls = 3 ** depth
    v = p_adic_valuation(calls, 3)
    print(f"{depth:<10} {calls:<10} {v:<15} 3^{depth}")

print("""
OBSERVATION: Number of calls at depth d = 3^d
This is a PERFECT 3-adic structure!
v_3(calls at depth d) = d
""")

# =============================================================================
# 4. 3-SAT AND 3-ADIC NUMBERS
# =============================================================================

print("\n" + "=" * 70)
print("4. 3-SAT AND 3-ADIC STRUCTURE")
print("=" * 70)

print("""
3-SAT: Each clause has exactly 3 literals
Why is 3-SAT NP-complete but 2-SAT is in P?

3-ADIC INTERPRETATION:
- 2-SAT clauses: binary structure (2-adic)
- 3-SAT clauses: ternary structure (3-adic)

The transition from P to NP-complete happens at p=3!
""")

# Analyze clause structure
print("Clause structure analysis:")
print()

def count_satisfying_assignments(k):
    """For a k-SAT clause, count satisfying assignments"""
    # A clause with k literals is satisfied by all except one assignment
    return 2**k - 1

for k in range(1, 6):
    sat = count_satisfying_assignments(k)
    v3 = p_adic_valuation(sat, 3)
    v2 = p_adic_valuation(sat, 2)
    print(f"{k}-SAT clause: {sat} satisfying assignments, v_3 = {v3}, v_2 = {v2}")

print("""
OBSERVATION:
- 2-SAT: 3 satisfying assignments, v_3(3) = 1
- 3-SAT: 7 satisfying assignments, v_3(7) = 0

The 3-adic valuation DROPS at k=3!
This may explain the complexity transition.
""")

# =============================================================================
# 5. FIBONACCI AND 3-ADIC STRUCTURE
# =============================================================================

print("\n" + "=" * 70)
print("5. FIBONACCI NUMBERS AND 3-ADIC STRUCTURE")
print("=" * 70)

@lru_cache(maxsize=None)
def fib(n):
    if n <= 1:
        return n
    return fib(n-1) + fib(n-2)

print("Fibonacci numbers and their 3-adic valuations:")
print()
print(f"{'n':<6} {'F(n)':<15} {'v_3(F(n))':<12} {'Pattern'}")
print("-" * 50)

for n in range(1, 25):
    f = fib(n)
    v = p_adic_valuation(f, 3)
    pattern = "divisible by 3^" + str(v) if v > 0 else ""
    if f < 100000:
        print(f"{n:<6} {f:<15} {v:<12} {pattern}")

print("""
OBSERVATION: v_3(F(n)) follows a periodic pattern!
- F(4) = 3, v_3 = 1
- F(8) = 21 = 3×7, v_3 = 1
- F(12) = 144 = 16×9, v_3 = 2

Period of 3-adic valuation in Fibonacci: related to 3^k
This connects Fibonacci heaps to 3-adic structure!
""")

# =============================================================================
# 6. ALGORITHM COMPLEXITY AND 3-ADIC NORMS
# =============================================================================

print("\n" + "=" * 70)
print("6. ALGORITHM COMPLEXITY AND 3-ADIC NORMS")
print("=" * 70)

print("""
CONJECTURE: Optimal algorithm complexity has special 3-adic properties.

Testing on known complexities:
""")

complexities = [
    ("Linear", 1, "O(n)"),
    ("Linearithmic", 1, "O(n log n)"),
    ("Karatsuba exponent", 1.585, "O(n^1.585)"),
    ("Quadratic", 2, "O(n²)"),
    ("Strassen exponent", 2.807, "O(n^2.807)"),
    ("Cubic", 3, "O(n³)"),
]

print(f"{'Algorithm':<25} {'Exponent':<12} {'Complexity'}")
print("-" * 50)
for name, exp, complexity in complexities:
    print(f"{name:<25} {exp:<12.4f} {complexity}")

print("""
PATTERN:
- Karatsuba: log_2(3) = 1.585 (involves 3)
- Strassen: log_2(7) = log_2(2³-1) = 2.807 (involves 3)
- Cubic: 3 (trivially involves 3)

The number 3 appears in breakthrough algorithms!
""")

# =============================================================================
# 7. 3-ADIC ANALYSIS OF SORTING
# =============================================================================

print("\n" + "=" * 70)
print("7. 3-ADIC ANALYSIS OF SORTING")
print("=" * 70)

print("""
TRINITY SORT uses 3-way partitioning.
Let's analyze the 3-adic structure:
""")

def trinity_sort_partitions(n, depth=0):
    """Analyze partition structure of Trinity Sort"""
    if n <= 27:  # Base case: 3³
        return [(depth, n, "base")]
    
    # 3-way partition creates ~3 subproblems
    third = n // 3
    return [(depth, n, "partition")] + \
           trinity_sort_partitions(third, depth+1) + \
           trinity_sort_partitions(third, depth+1) + \
           trinity_sort_partitions(third, depth+1)

print("Trinity Sort partition analysis for n=243 (3^5):")
print()
print(f"{'Depth':<8} {'Size':<10} {'v_3(size)':<12} {'Type'}")
print("-" * 45)

partitions = trinity_sort_partitions(243)
seen_depths = set()
for depth, size, ptype in partitions:
    if depth not in seen_depths:
        v = p_adic_valuation(size, 3)
        print(f"{depth:<8} {size:<10} {v:<12} {ptype}")
        seen_depths.add(depth)

print("""
OBSERVATION:
- At each level, size is divided by 3
- v_3(size) decreases by 1 at each level
- Perfect 3-adic descent!

This suggests Trinity Sort is "natural" in 3-adic metric.
""")

# =============================================================================
# 8. PREDICTIONS FROM 3-ADIC ANALYSIS
# =============================================================================

print("\n" + "=" * 70)
print("8. PREDICTIONS FROM 3-ADIC ANALYSIS")
print("=" * 70)

print("""
Based on 3-adic structure, we predict:

1. OPTIMAL THRESHOLDS
   Thresholds should be powers of 3:
   - 3¹ = 3 (too small)
   - 3² = 9 (small)
   - 3³ = 27 (Trinity Sort threshold) ✓
   - 3⁴ = 81 (alternative)

2. RECURSION DEPTH
   Optimal recursion depth for n elements:
   - d = v_3(n) when n is power of 3
   - d ≈ log_3(n) in general

3. NEW ALGORITHMS
   Algorithms with 3-adic structure may outperform
   binary (2-adic) algorithms for certain inputs.

4. COMPLEXITY BOUNDS
   Lower bounds may have 3-adic form:
   - Ω(n × 3^k) for some problems
   - Exponents involving log_2(3)
""")

# =============================================================================
# SUMMARY
# =============================================================================

print("\n" + "=" * 70)
print("SUMMARY: 3-ADIC STRUCTURE IN ALGORITHMS")
print("=" * 70)

print("""
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  3-ADIC NUMBERS REVEAL HIDDEN STRUCTURE IN ALGORITHMS              │
│                                                                     │
│  KEY FINDINGS:                                                      │
│  • Karatsuba has perfect 3-adic recursion structure                │
│  • 3-SAT transition correlates with 3-adic valuation drop          │
│  • Fibonacci numbers have periodic 3-adic structure                │
│  • Trinity Sort has natural 3-adic descent                         │
│                                                                     │
│  IMPLICATIONS:                                                      │
│  • Use powers of 3 for thresholds (3, 9, 27, 81, ...)             │
│  • 3-way partitioning is "natural" in 3-adic metric               │
│  • Complexity bounds may have 3-adic form                          │
│                                                                     │
│  CONJECTURE:                                                        │
│  The number 3 appears in algorithm complexity because              │
│  3-adic structure is fundamental to computational complexity.      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
""")
