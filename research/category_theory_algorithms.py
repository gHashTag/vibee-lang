#!/usr/bin/env python3
"""
Category Theory for Physics of Algorithms
Formalizing the connection between physics and computation

Author: Dmitrii Vasilev
Date: January 13, 2026

Category theory provides the mathematical language to express
the deep connection between physics and algorithms.
"""

import math
from typing import TypeVar, Generic, Callable, List, Tuple
from dataclasses import dataclass
from abc import ABC, abstractmethod

print("=" * 70)
print("CATEGORY THEORY FOR PHYSICS OF ALGORITHMS")
print("=" * 70)

# =============================================================================
# 1. WHAT IS CATEGORY THEORY?
# =============================================================================

print("\n" + "=" * 70)
print("1. WHAT IS CATEGORY THEORY?")
print("=" * 70)

print("""
CATEGORY THEORY is the "mathematics of mathematics"
It studies structure-preserving transformations.

A CATEGORY consists of:
1. OBJECTS (things)
2. MORPHISMS (arrows between things)
3. COMPOSITION (combining arrows)
4. IDENTITY (doing nothing)

EXAMPLES:
- Set: objects = sets, morphisms = functions
- Vect: objects = vector spaces, morphisms = linear maps
- Hask: objects = types, morphisms = functions (Haskell)

WHY CATEGORY THEORY?
It reveals DEEP STRUCTURAL SIMILARITIES between
seemingly different areas of mathematics!
""")

# =============================================================================
# 2. CATEGORIES IN PHYSICS AND ALGORITHMS
# =============================================================================

print("\n" + "=" * 70)
print("2. CATEGORIES IN PHYSICS AND ALGORITHMS")
print("=" * 70)

print("""
PHYSICS CATEGORIES:

1. Hilb (Quantum Mechanics)
   - Objects: Hilbert spaces
   - Morphisms: Linear operators
   - Composition: Operator multiplication

2. Cob (Topological QFT)
   - Objects: Manifolds
   - Morphisms: Cobordisms
   - Composition: Gluing

3. Symp (Classical Mechanics)
   - Objects: Symplectic manifolds
   - Morphisms: Symplectomorphisms
   - Composition: Function composition

ALGORITHM CATEGORIES:

1. Alg (Algorithms)
   - Objects: Data types
   - Morphisms: Algorithms
   - Composition: Algorithm composition

2. Comp (Complexity Classes)
   - Objects: Complexity classes (P, NP, etc.)
   - Morphisms: Reductions
   - Composition: Reduction composition

3. Sort (Sorting)
   - Objects: Permutations
   - Morphisms: Comparison operations
   - Composition: Sequence of comparisons
""")

# =============================================================================
# 3. FUNCTORS: STRUCTURE-PRESERVING MAPS
# =============================================================================

print("\n" + "=" * 70)
print("3. FUNCTORS: PHYSICS ↔ ALGORITHMS")
print("=" * 70)

print("""
A FUNCTOR F: C → D maps:
- Objects in C to objects in D
- Morphisms in C to morphisms in D
- Preserves composition and identity

THE PHYSICS-ALGORITHM FUNCTOR:

F: Phys → Alg

Maps physical systems to algorithms:
- Quantum states → Data structures
- Unitary evolution → Reversible algorithms
- Measurement → Output
- Entropy → Complexity

EXAMPLES:
1. Quantum circuit → Classical simulation
2. Thermodynamic process → Sorting algorithm
3. Phase transition → Complexity class boundary
""")

# =============================================================================
# 4. NATURAL TRANSFORMATIONS
# =============================================================================

print("\n" + "=" * 70)
print("4. NATURAL TRANSFORMATIONS")
print("=" * 70)

print("""
A NATURAL TRANSFORMATION η: F ⇒ G
connects two functors F, G: C → D

It's a "morphism between functors"

THE OPTIMIZATION NATURAL TRANSFORMATION:

η: Naive ⇒ Optimal

Maps naive algorithms to optimal ones:
- Naive sort O(n²) → Optimal sort O(n log n)
- Naive multiply O(n³) → Strassen O(n^2.8)
- Naive search O(n) → Binary search O(log n)

NATURALITY CONDITION:
The optimization must be "natural" - 
it works uniformly across all inputs.
""")

# =============================================================================
# 5. MONOIDAL CATEGORIES AND TENSOR PRODUCTS
# =============================================================================

print("\n" + "=" * 70)
print("5. MONOIDAL CATEGORIES")
print("=" * 70)

print("""
A MONOIDAL CATEGORY has:
- Tensor product ⊗
- Unit object I
- Associativity and unit laws

PHYSICS:
- Hilb is monoidal: ⊗ = tensor product of Hilbert spaces
- Describes composite quantum systems

ALGORITHMS:
- Alg is monoidal: ⊗ = parallel composition
- Describes parallel algorithms

THE CONNECTION:
Quantum parallelism (superposition) corresponds to
classical parallelism (concurrent execution)!

TRINITY SORT:
3-way partition = 3-fold tensor product
A ⊗ B ⊗ C = (less than) ⊗ (equal) ⊗ (greater than)
""")

# =============================================================================
# 6. ADJUNCTIONS
# =============================================================================

print("\n" + "=" * 70)
print("6. ADJUNCTIONS: THE HEART OF CATEGORY THEORY")
print("=" * 70)

print("""
An ADJUNCTION F ⊣ G between categories C and D:
- F: C → D (left adjoint)
- G: D → C (right adjoint)
- Hom_D(F(A), B) ≅ Hom_C(A, G(B))

PHYSICS-ALGORITHM ADJUNCTION:

Encode ⊣ Decode

- Encode: Phys → Alg (encode physics as algorithm)
- Decode: Alg → Phys (interpret algorithm as physics)

EXAMPLES:
1. Fourier transform ⊣ Inverse Fourier
2. Compression ⊣ Decompression
3. Encryption ⊣ Decryption

THE ADJUNCTION CAPTURES:
The fundamental duality between
physical processes and computational processes!
""")

# =============================================================================
# 7. THE CURRY-HOWARD-LAMBEK CORRESPONDENCE
# =============================================================================

print("\n" + "=" * 70)
print("7. CURRY-HOWARD-LAMBEK CORRESPONDENCE")
print("=" * 70)

print("""
THREE-WAY CORRESPONDENCE:

LOGIC          TYPES           CATEGORIES
─────────────────────────────────────────────
Proposition    Type            Object
Proof          Program         Morphism
Implication    Function type   Exponential
Conjunction    Product type    Product
Disjunction    Sum type        Coproduct
True           Unit type       Terminal object
False          Empty type      Initial object

EXTENDED TO PHYSICS:

LOGIC     TYPES      CATEGORIES    PHYSICS
────────────────────────────────────────────────
Prop      Type       Object        State space
Proof     Program    Morphism      Evolution
∧         ×          ×             Tensor product
∨         +          +             Direct sum
⊤         Unit       1             Vacuum
⊥         Void       0             Impossible state

THE TRINITY:
Logic = Types = Categories = Physics
All are the SAME mathematical structure!
""")

# =============================================================================
# 8. CATEGORICAL SEMANTICS OF TRINITY SORT
# =============================================================================

print("\n" + "=" * 70)
print("8. CATEGORICAL SEMANTICS OF TRINITY SORT")
print("=" * 70)

print("""
TRINITY SORT IN CATEGORY THEORY:

OBJECTS:
- List[A]: lists of comparable elements
- Sorted[A]: sorted lists
- Perm: permutations

MORPHISMS:
- partition: List[A] → List[A] × List[A] × List[A]
- merge: List[A] × List[A] × List[A] → List[A]
- sort: List[A] → Sorted[A]

FUNCTOR:
Trinity: List → Sorted

NATURAL TRANSFORMATION:
η: Id ⇒ Trinity ∘ Forget

where Forget: Sorted → List forgets the sorted property.

3-WAY PARTITION AS COPRODUCT:
List[A] → A<p + A=p + A>p

This is a COPRODUCT (sum type) with 3 components!
The number 3 is categorically natural.
""")

# =============================================================================
# 9. TOPOS THEORY AND COMPUTATION
# =============================================================================

print("\n" + "=" * 70)
print("9. TOPOS THEORY AND COMPUTATION")
print("=" * 70)

print("""
A TOPOS is a category that behaves like Set.
It has:
- Products and coproducts
- Exponentials (function spaces)
- Subobject classifier (generalized truth values)

TOPOI IN PHYSICS:
- Quantum topos: describes quantum logic
- Spacetime topos: describes general relativity

TOPOI IN COMPUTATION:
- Effective topos: describes computable functions
- Realizability topos: describes programs

THE CONNECTION:
Physical theories and computational theories
can both be described as topoi!

IMPLICATION:
There may be a UNIVERSAL TOPOS that
unifies physics and computation.
""")

# =============================================================================
# 10. THE CONSTANTS 3, π, φ IN CATEGORY THEORY
# =============================================================================

print("\n" + "=" * 70)
print("10. THE CONSTANTS 3, π, φ IN CATEGORY THEORY")
print("=" * 70)

print("""
THE NUMBER 3:
- 3 = smallest non-trivial coproduct
- 3-category theory is rich but tractable
- Tricategories describe 3D physics

THE NUMBER π:
- π appears in the groupoid cardinality
- |BG| = 1/|G| for finite group G
- For circle group: |BS¹| = 2π

THE NUMBER φ:
- φ appears in Fibonacci categories
- Related to quantum groups at roots of unity
- Golden ratio in categorical dimensions

CATEGORICAL INTERPRETATION:
The constants 3, π, φ are not arbitrary -
they arise from fundamental categorical structures!
""")

# =============================================================================
# 11. PRACTICAL IMPLEMENTATION
# =============================================================================

print("\n" + "=" * 70)
print("11. PRACTICAL IMPLEMENTATION")
print("=" * 70)

# Define a simple category in Python
T = TypeVar('T')
S = TypeVar('S')
U = TypeVar('U')

@dataclass
class Morphism(Generic[T, S]):
    """A morphism from T to S"""
    source: type
    target: type
    func: Callable[[T], S]
    
    def __call__(self, x: T) -> S:
        return self.func(x)

def compose(f: Morphism[S, U], g: Morphism[T, S]) -> Morphism[T, U]:
    """Compose two morphisms"""
    return Morphism(
        source=g.source,
        target=f.target,
        func=lambda x: f(g(x))
    )

def identity(t: type) -> Morphism:
    """Identity morphism"""
    return Morphism(source=t, target=t, func=lambda x: x)

# Example: Sorting as a functor
print("Example: Sorting as a categorical morphism")
print()

# Define the sorting morphism
sort_morphism = Morphism(
    source=list,
    target=list,
    func=sorted
)

# Apply it
data = [3, 1, 4, 1, 5, 9, 2, 6]
result = sort_morphism(data)
print(f"Input:  {data}")
print(f"Output: {result}")

# Composition example
double = Morphism(source=list, target=list, func=lambda x: [2*i for i in x])
sort_then_double = compose(double, sort_morphism)
print(f"Sort then double: {sort_then_double(data)}")

# =============================================================================
# SUMMARY
# =============================================================================

print("\n" + "=" * 70)
print("SUMMARY: CATEGORY THEORY FOR PHYSICS OF ALGORITHMS")
print("=" * 70)

print("""
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  CATEGORY THEORY UNIFIES PHYSICS AND ALGORITHMS                     │
│                                                                     │
│  KEY STRUCTURES:                                                    │
│  • Categories: Objects + Morphisms + Composition                   │
│  • Functors: Structure-preserving maps                             │
│  • Natural transformations: Morphisms between functors             │
│  • Adjunctions: Fundamental dualities                              │
│                                                                     │
│  THE CORRESPONDENCE:                                                │
│  Physics ←→ Algorithms                                             │
│  States ←→ Data structures                                         │
│  Evolution ←→ Computation                                          │
│  Entropy ←→ Complexity                                             │
│                                                                     │
│  THE CONSTANTS:                                                     │
│  • 3: Smallest non-trivial coproduct                              │
│  • π: Groupoid cardinality of circle                              │
│  • φ: Fibonacci categories                                         │
│                                                                     │
│  CONCLUSION:                                                        │
│  Category theory provides the language to express                  │
│  the deep unity of physics and computation.                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
""")
