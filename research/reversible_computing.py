#!/usr/bin/env python3
"""
Reversible Computing: Zero-Energy Computation
Based on Bennett's theorem and Landauer's principle

Author: Dmitrii Vasilev
Date: January 13, 2026

Key insight: Reversible operations require NO energy!
Only irreversible operations (bit erasure) have thermodynamic cost.
"""

import math
from typing import List, Tuple, Any

print("=" * 70)
print("REVERSIBLE COMPUTING: ZERO-ENERGY COMPUTATION")
print("=" * 70)

# =============================================================================
# 1. LANDAUER'S PRINCIPLE REVISITED
# =============================================================================

print("\n" + "=" * 70)
print("1. LANDAUER'S PRINCIPLE")
print("=" * 70)

k_B = 1.380649e-23  # Boltzmann constant
T = 300  # Room temperature
E_landauer = k_B * T * math.log(2)

print(f"""
LANDAUER'S PRINCIPLE (1961):
Erasing 1 bit of information requires minimum energy kT ln(2).

At T = {T}K:
E_min = {E_landauer:.3e} J per bit erased

BENNETT'S COROLLARY (1973):
Reversible operations require ZERO energy!

IMPLICATION:
If we can make all operations reversible,
we can compute with arbitrarily low energy.
""")

# =============================================================================
# 2. REVERSIBLE LOGIC GATES
# =============================================================================

print("\n" + "=" * 70)
print("2. REVERSIBLE LOGIC GATES")
print("=" * 70)

print("""
IRREVERSIBLE GATES (lose information):
- AND: 2 inputs → 1 output (loses 1 bit)
- OR:  2 inputs → 1 output (loses 1 bit)
- NOT: 1 input → 1 output (reversible!)

REVERSIBLE GATES (preserve information):
""")

def not_gate(a: int) -> int:
    """NOT gate - reversible"""
    return 1 - a

def cnot_gate(a: int, b: int) -> Tuple[int, int]:
    """Controlled-NOT: (a, b) → (a, a XOR b)"""
    return (a, a ^ b)

def toffoli_gate(a: int, b: int, c: int) -> Tuple[int, int, int]:
    """Toffoli gate: (a, b, c) → (a, b, c XOR (a AND b))"""
    return (a, b, c ^ (a & b))

def fredkin_gate(a: int, b: int, c: int) -> Tuple[int, int, int]:
    """Fredkin gate: if a=1, swap b and c"""
    if a == 1:
        return (a, c, b)
    return (a, b, c)

# Demonstrate reversibility
print("CNOT Gate (Controlled-NOT):")
print("  Input → Output → Reverse")
for a in [0, 1]:
    for b in [0, 1]:
        out = cnot_gate(a, b)
        rev = cnot_gate(out[0], out[1])
        print(f"  ({a},{b}) → {out} → {rev}")

print("\nToffoli Gate (Universal reversible gate):")
print("  Can implement ANY boolean function!")
print("  (a, b, c) → (a, b, c XOR (a AND b))")
for a in [0, 1]:
    for b in [0, 1]:
        for c in [0, 1]:
            out = toffoli_gate(a, b, c)
            print(f"  ({a},{b},{c}) → {out}")

# =============================================================================
# 3. REVERSIBLE SORTING
# =============================================================================

print("\n" + "=" * 70)
print("3. REVERSIBLE SORTING")
print("=" * 70)

print("""
Standard sorting is IRREVERSIBLE:
- Input: [3, 1, 4, 1, 5]
- Output: [1, 1, 3, 4, 5]
- We LOST the original order information!

REVERSIBLE SORTING:
- Keep track of permutation
- Output: (sorted array, permutation)
- Can reconstruct original from output
""")

def reversible_sort(arr: List[int]) -> Tuple[List[int], List[int]]:
    """
    Reversible sorting: returns (sorted_array, permutation)
    permutation[i] = original index of element now at position i
    """
    indexed = [(val, idx) for idx, val in enumerate(arr)]
    indexed.sort(key=lambda x: x[0])
    
    sorted_arr = [x[0] for x in indexed]
    permutation = [x[1] for x in indexed]
    
    return sorted_arr, permutation

def reverse_sort(sorted_arr: List[int], permutation: List[int]) -> List[int]:
    """Reverse the sorting operation"""
    original = [0] * len(sorted_arr)
    for i, orig_idx in enumerate(permutation):
        original[orig_idx] = sorted_arr[i]
    return original

# Demonstrate
arr = [3, 1, 4, 1, 5, 9, 2, 6]
print(f"Original:    {arr}")

sorted_arr, perm = reversible_sort(arr)
print(f"Sorted:      {sorted_arr}")
print(f"Permutation: {perm}")

recovered = reverse_sort(sorted_arr, perm)
print(f"Recovered:   {recovered}")
print(f"Match: {arr == recovered}")

# Energy analysis
n = len(arr)
irreversible_bits = math.log2(math.factorial(n))  # Information lost in standard sort
print(f"\nEnergy analysis for n={n}:")
print(f"  Standard sort erases: {irreversible_bits:.1f} bits")
print(f"  Energy cost: {irreversible_bits * E_landauer:.3e} J")
print(f"  Reversible sort erases: 0 bits")
print(f"  Energy cost: 0 J (theoretically)")

# =============================================================================
# 4. REVERSIBLE TRINITY SORT
# =============================================================================

print("\n" + "=" * 70)
print("4. REVERSIBLE TRINITY SORT")
print("=" * 70)

print("""
We can make Trinity Sort reversible by tracking all swaps.

REVERSIBLE 3-WAY PARTITION:
- Track which elements moved where
- Store swap history
- Can undo partition exactly
""")

class ReversibleTrinitySort:
    """Trinity Sort with full reversibility"""
    
    def __init__(self):
        self.swap_history = []
    
    def swap(self, arr: List[int], i: int, j: int):
        """Reversible swap - record the operation"""
        if i != j:
            arr[i], arr[j] = arr[j], arr[i]
            self.swap_history.append((i, j))
    
    def partition_3way(self, arr: List[int], lo: int, hi: int, pivot: int) -> Tuple[int, int]:
        """3-way partition with swap tracking"""
        lt = lo
        i = lo
        gt = hi
        
        while i <= gt:
            if arr[i] < pivot:
                self.swap(arr, lt, i)
                lt += 1
                i += 1
            elif arr[i] > pivot:
                self.swap(arr, i, gt)
                gt -= 1
            else:
                i += 1
        
        return lt, gt
    
    def sort(self, arr: List[int], lo: int = None, hi: int = None):
        """Reversible Trinity Sort"""
        if lo is None:
            lo = 0
        if hi is None:
            hi = len(arr) - 1
        
        if hi <= lo:
            return
        
        if hi - lo + 1 <= 27:  # Trinity threshold
            self.insertion_sort(arr, lo, hi)
            return
        
        # Golden ratio pivot
        pivot_idx = lo + int((hi - lo + 1) * 0.618)
        pivot = arr[pivot_idx]
        
        lt, gt = self.partition_3way(arr, lo, hi, pivot)
        
        self.sort(arr, lo, lt - 1)
        self.sort(arr, gt + 1, hi)
    
    def insertion_sort(self, arr: List[int], lo: int, hi: int):
        """Reversible insertion sort"""
        for i in range(lo + 1, hi + 1):
            j = i
            while j > lo and arr[j-1] > arr[j]:
                self.swap(arr, j-1, j)
                j -= 1
    
    def reverse(self, arr: List[int]):
        """Undo all swaps to recover original"""
        for i, j in reversed(self.swap_history):
            arr[i], arr[j] = arr[j], arr[i]
        self.swap_history.clear()

# Demonstrate
arr = [5, 2, 8, 1, 9, 3, 7, 4, 6, 5, 2, 8]
original = arr.copy()

sorter = ReversibleTrinitySort()
print(f"Original: {arr}")

sorter.sort(arr)
print(f"Sorted:   {arr}")
print(f"Swaps recorded: {len(sorter.swap_history)}")

sorter.reverse(arr)
print(f"Reversed: {arr}")
print(f"Match: {arr == original}")

# =============================================================================
# 5. ENERGY COMPARISON
# =============================================================================

print("\n" + "=" * 70)
print("5. ENERGY COMPARISON: REVERSIBLE vs IRREVERSIBLE")
print("=" * 70)

print("""
For sorting n elements:

IRREVERSIBLE SORTING:
- Erases log₂(n!) bits of information
- Minimum energy: kT × n ln(n) × ln(2)

REVERSIBLE SORTING:
- Erases 0 bits (keeps permutation)
- Minimum energy: 0 J (theoretically)
- Trade-off: needs O(n log n) extra space for history
""")

print(f"\n{'n':<10} {'Irreversible (J)':<20} {'Reversible (J)':<20} {'Savings'}")
print("-" * 60)

for n in [100, 1000, 10000, 100000]:
    bits_erased = n * math.log2(n) if n > 1 else 0
    irreversible_energy = bits_erased * E_landauer
    reversible_energy = 0
    
    print(f"{n:<10} {irreversible_energy:<20.3e} {reversible_energy:<20} {'∞'}")

# =============================================================================
# 6. PRACTICAL CONSIDERATIONS
# =============================================================================

print("\n" + "=" * 70)
print("6. PRACTICAL CONSIDERATIONS")
print("=" * 70)

print("""
WHY DON'T WE USE REVERSIBLE COMPUTING?

1. SPACE OVERHEAD
   - Must store history of all operations
   - O(n log n) extra space for sorting
   - Can be reduced with "uncomputation"

2. TIME OVERHEAD
   - Reversible gates are more complex
   - ~3x more gates for same function
   - But asymptotically same complexity

3. CURRENT TECHNOLOGY
   - Modern CPUs are highly irreversible
   - Transistors dissipate ~10⁶ × Landauer limit
   - Room for 10⁶× improvement!

4. QUANTUM COMPUTING
   - Quantum gates ARE reversible!
   - Quantum computers naturally reversible
   - This is why quantum computing is possible
""")

# =============================================================================
# 7. CONNECTION TO PHYSICS
# =============================================================================

print("\n" + "=" * 70)
print("7. CONNECTION TO PHYSICS")
print("=" * 70)

print("""
REVERSIBLE COMPUTING ↔ PHYSICS

1. TIME REVERSAL SYMMETRY
   - Fundamental physics is time-reversible
   - Schrödinger equation: iℏ ∂ψ/∂t = Hψ
   - Can run backwards: ψ(t) → ψ(-t)

2. ENTROPY AND INFORMATION
   - Irreversible computation increases entropy
   - Reversible computation preserves entropy
   - Second Law: ΔS ≥ 0

3. QUANTUM MECHANICS
   - Unitary evolution is reversible
   - Measurement is irreversible (collapse)
   - Quantum computing exploits reversibility

4. THE TRINITY CONNECTION
   - 3-way partition can be made reversible
   - Preserves more structure than 2-way
   - May have deeper physical significance
""")

# =============================================================================
# 8. REVERSIBLE ALGORITHMS AND CONSTANTS
# =============================================================================

print("\n" + "=" * 70)
print("8. REVERSIBLE ALGORITHMS AND PHYSICAL CONSTANTS")
print("=" * 70)

print("""
HYPOTHESIS:
Reversible algorithms may have special relationship with 3, π, φ.

EVIDENCE:
1. Toffoli gate has 3 inputs/outputs
2. Quantum gates involve π rotations
3. Optimal reversible circuits may use φ-based structures

PREDICTION:
The most efficient reversible algorithms will follow
the pattern n × 3^k × π^m in their gate counts.
""")

# Gate count analysis
print("\nReversible gate counts for common operations:")
print(f"{'Operation':<25} {'Toffoli gates':<15} {'Pattern'}")
print("-" * 55)

operations = [
    ("NOT", 0, "0 = 0"),
    ("AND (with ancilla)", 1, "1 = 3⁰"),
    ("OR (with ancilla)", 1, "1 = 3⁰"),
    ("Full adder", 2, "2"),
    ("n-bit adder", "2n", "2n"),
    ("n-bit multiplier", "O(n²)", "n²"),
    ("Sorting network (n)", "O(n log² n)", "n log² n"),
]

for op, gates, pattern in operations:
    print(f"{op:<25} {str(gates):<15} {pattern}")

# =============================================================================
# SUMMARY
# =============================================================================

print("\n" + "=" * 70)
print("SUMMARY: REVERSIBLE COMPUTING")
print("=" * 70)

print("""
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  REVERSIBLE COMPUTING: THE ULTIMATE EFFICIENCY                      │
│                                                                     │
│  KEY INSIGHTS:                                                      │
│  • Reversible operations require ZERO energy (Landauer/Bennett)    │
│  • Current computers waste 10⁶× more energy than necessary         │
│  • Quantum computers are naturally reversible                       │
│                                                                     │
│  REVERSIBLE TRINITY SORT:                                          │
│  • Track all swaps for reversibility                               │
│  • 3-way partition preserves more structure                        │
│  • Can recover original array from sorted + history                │
│                                                                     │
│  PHYSICS CONNECTION:                                                │
│  • Time-reversal symmetry in physics                               │
│  • Entropy preservation                                            │
│  • Quantum unitarity                                               │
│                                                                     │
│  FUTURE:                                                           │
│  • Reversible classical computers                                  │
│  • Zero-energy computation                                         │
│  • Quantum advantage from reversibility                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
""")
