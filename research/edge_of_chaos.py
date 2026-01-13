#!/usr/bin/env python3
"""
Edge of Chaos: Neural Networks and Phase Transitions
Based on "Deep Information Propagation" (Schoenholz et al., 2016)

Author: Dmitrii Vasilev
Date: January 13, 2026

Key insight: Neural networks can only be trained at the "edge of chaos"
- the critical point between ordered and chaotic phases.
This connects to physics phase transitions!
"""

import math
import random
from typing import List, Tuple

print("=" * 70)
print("EDGE OF CHAOS: NEURAL NETWORKS AND PHASE TRANSITIONS")
print("=" * 70)

# =============================================================================
# 1. THE EDGE OF CHAOS CONCEPT
# =============================================================================

print("\n" + "=" * 70)
print("1. THE EDGE OF CHAOS")
print("=" * 70)

print("""
DISCOVERY (Schoenholz et al., 2016):
Neural networks have TWO phases:

1. ORDERED PHASE (σ_w² × σ_b² < 1)
   - Information collapses
   - All inputs map to same output
   - Gradients vanish
   - CANNOT TRAIN

2. CHAOTIC PHASE (σ_w² × σ_b² > 1)
   - Information explodes
   - Tiny input changes → huge output changes
   - Gradients explode
   - CANNOT TRAIN

3. EDGE OF CHAOS (σ_w² × σ_b² = 1)
   - Information preserved
   - Gradients stable
   - CAN TRAIN!

This is exactly like a PHASE TRANSITION in physics!
""")

# =============================================================================
# 2. MATHEMATICAL FRAMEWORK
# =============================================================================

print("\n" + "=" * 70)
print("2. MATHEMATICAL FRAMEWORK")
print("=" * 70)

print("""
For a neural network with:
- Weight variance: σ_w²
- Bias variance: σ_b²
- Activation function: φ(x)

The variance of activations at layer l evolves as:
q^l = σ_w² × E[φ(√(q^(l-1)) × z)²] + σ_b²

where z ~ N(0, 1)

CRITICAL CONDITION:
At the edge of chaos, the Jacobian has eigenvalue 1:
χ = σ_w² × E[φ'(√q* × z)²] = 1

where q* is the fixed point of the variance recursion.
""")

def tanh_variance_map(q, sigma_w, sigma_b):
    """Variance map for tanh activation"""
    # E[tanh²(√q × z)] ≈ 2/π × arctan(√(2q))  for large q
    # Simplified approximation
    if q < 0.01:
        return sigma_w**2 * q + sigma_b**2
    return sigma_w**2 * (2/math.pi) * math.atan(math.sqrt(2*q)) + sigma_b**2

def relu_variance_map(q, sigma_w, sigma_b):
    """Variance map for ReLU activation"""
    # E[ReLU²(√q × z)] = q/2
    return sigma_w**2 * q / 2 + sigma_b**2

def find_fixed_point(variance_map, sigma_w, sigma_b, tol=1e-6, max_iter=1000):
    """Find fixed point q* where q* = variance_map(q*)"""
    q = 1.0
    for _ in range(max_iter):
        q_new = variance_map(q, sigma_w, sigma_b)
        if abs(q_new - q) < tol:
            return q_new
        q = q_new
    return q

print("\nFixed points for different initializations:")
print(f"{'σ_w':<10} {'σ_b':<10} {'q* (tanh)':<15} {'q* (ReLU)':<15} {'Phase'}")
print("-" * 60)

for sigma_w in [0.5, 1.0, 1.414, 2.0]:
    for sigma_b in [0.0, 0.1]:
        q_tanh = find_fixed_point(tanh_variance_map, sigma_w, sigma_b)
        q_relu = find_fixed_point(relu_variance_map, sigma_w, sigma_b)
        
        # Determine phase
        chi = sigma_w**2 / 2  # Simplified for ReLU
        if chi < 0.9:
            phase = "Ordered"
        elif chi > 1.1:
            phase = "Chaotic"
        else:
            phase = "CRITICAL"
        
        print(f"{sigma_w:<10.3f} {sigma_b:<10.3f} {q_tanh:<15.4f} {q_relu:<15.4f} {phase}")

# =============================================================================
# 3. DEPTH SCALES
# =============================================================================

print("\n" + "=" * 70)
print("3. DEPTH SCALES")
print("=" * 70)

print("""
The edge of chaos determines MAXIMUM TRAINABLE DEPTH.

DEPTH SCALES:
1. ξ_q: Correlation length (how far information propagates)
2. ξ_c: Gradient correlation length

At criticality: ξ → ∞ (infinite depth possible)
Away from criticality: ξ is finite (depth limited)
""")

def correlation_length(chi):
    """Estimate correlation length from χ"""
    if chi >= 1:
        return float('inf')
    return -1 / math.log(chi) if chi > 0 else 0

print(f"\n{'χ':<10} {'ξ (depth scale)':<20} {'Max trainable depth'}")
print("-" * 50)

for chi in [0.5, 0.8, 0.9, 0.95, 0.99, 1.0, 1.01, 1.1]:
    xi = correlation_length(chi)
    if xi == float('inf'):
        print(f"{chi:<10.2f} {'∞':<20} {'∞'}")
    else:
        print(f"{chi:<10.2f} {xi:<20.2f} {int(xi * 2)}")

# =============================================================================
# 4. CONNECTION TO PHYSICAL PHASE TRANSITIONS
# =============================================================================

print("\n" + "=" * 70)
print("4. CONNECTION TO PHYSICAL PHASE TRANSITIONS")
print("=" * 70)

print("""
NEURAL NETWORKS ↔ STATISTICAL PHYSICS

Neural Network          Physical System
─────────────────────────────────────────────────
Weights                 Coupling constants
Activations             Spin states
Layer depth             Time evolution
Ordered phase           Ferromagnetic (aligned)
Chaotic phase           Paramagnetic (random)
Edge of chaos           Critical temperature T_c

CRITICAL EXPONENTS:
Near the critical point, quantities scale as power laws:
ξ ~ |χ - 1|^(-ν)

This is EXACTLY like magnetic phase transitions!
""")

# =============================================================================
# 5. THE NUMBER 3 AT THE EDGE OF CHAOS
# =============================================================================

print("\n" + "=" * 70)
print("5. THE NUMBER 3 AT THE EDGE OF CHAOS")
print("=" * 70)

print("""
OBSERVATION: The number 3 appears at criticality!

1. CRITICAL INITIALIZATION FOR RELU:
   σ_w² = 2/fan_in (He initialization)
   For 3-layer network: σ_w = √(2/3) ≈ 0.816

2. BATCH NORMALIZATION:
   Normalizes to 3 statistics: mean, variance, correlation

3. RESIDUAL CONNECTIONS:
   Skip connections every 2-3 layers optimal

4. ATTENTION HEADS:
   Transformer uses 3 projections: Q, K, V

HYPOTHESIS:
The number 3 appears because it's the minimum for
complex dynamics at the edge of chaos.
""")

# =============================================================================
# 6. PRACTICAL INITIALIZATION
# =============================================================================

print("\n" + "=" * 70)
print("6. PRACTICAL INITIALIZATION FOR EDGE OF CHAOS")
print("=" * 70)

print("""
INITIALIZATION SCHEMES:

1. XAVIER/GLOROT (for tanh/sigmoid):
   σ_w² = 2 / (fan_in + fan_out)
   
2. HE (for ReLU):
   σ_w² = 2 / fan_in
   
3. LECUN (for SELU):
   σ_w² = 1 / fan_in

All designed to maintain χ ≈ 1 (edge of chaos)!
""")

def xavier_init(fan_in, fan_out):
    """Xavier/Glorot initialization"""
    return math.sqrt(2 / (fan_in + fan_out))

def he_init(fan_in):
    """He initialization for ReLU"""
    return math.sqrt(2 / fan_in)

def lecun_init(fan_in):
    """LeCun initialization"""
    return math.sqrt(1 / fan_in)

print(f"\n{'fan_in':<10} {'fan_out':<10} {'Xavier σ':<12} {'He σ':<12} {'LeCun σ'}")
print("-" * 55)

for fan_in in [64, 256, 1024]:
    fan_out = fan_in
    xavier = xavier_init(fan_in, fan_out)
    he = he_init(fan_in)
    lecun = lecun_init(fan_in)
    print(f"{fan_in:<10} {fan_out:<10} {xavier:<12.4f} {he:<12.4f} {lecun:<12.4f}")

# =============================================================================
# 7. EDGE OF CHAOS IN ALGORITHMS
# =============================================================================

print("\n" + "=" * 70)
print("7. EDGE OF CHAOS IN ALGORITHMS")
print("=" * 70)

print("""
HYPOTHESIS: Optimal algorithms operate at the edge of chaos.

EXAMPLES:

1. QUICKSORT PIVOT SELECTION
   - Random pivot: chaotic (unpredictable)
   - Fixed pivot: ordered (predictable, bad worst case)
   - Median-of-3: edge of chaos (balanced)

2. HASH FUNCTIONS
   - Too regular: collisions (ordered)
   - Too random: no structure (chaotic)
   - Golden ratio: edge of chaos (optimal distribution)

3. GENETIC ALGORITHMS
   - Low mutation: stuck in local optima (ordered)
   - High mutation: random search (chaotic)
   - Optimal mutation rate: edge of chaos

4. SIMULATED ANNEALING
   - Low temperature: frozen (ordered)
   - High temperature: random (chaotic)
   - Critical temperature: edge of chaos
""")

# =============================================================================
# 8. TRINITY SORT AND EDGE OF CHAOS
# =============================================================================

print("\n" + "=" * 70)
print("8. TRINITY SORT AND EDGE OF CHAOS")
print("=" * 70)

print("""
TRINITY SORT operates at the edge of chaos:

1. 3-WAY PARTITION
   - 2-way: too ordered (bad for duplicates)
   - 4-way: too chaotic (overhead)
   - 3-way: edge of chaos (optimal)

2. GOLDEN RATIO PIVOT
   - φ is maximally irrational
   - Provides "controlled randomness"
   - Edge of chaos in pivot selection

3. THRESHOLD = 27 = 3³
   - Below: insertion sort (ordered)
   - Above: recursive partition (chaotic)
   - At 27: transition point

PREDICTION:
Trinity Sort's efficiency comes from operating
at the edge of chaos in multiple dimensions.
""")

# =============================================================================
# 9. π AND THE EDGE OF CHAOS
# =============================================================================

print("\n" + "=" * 70)
print("9. π AND THE EDGE OF CHAOS")
print("=" * 70)

print("""
π appears at the edge of chaos!

1. GAUSSIAN DISTRIBUTION
   - Critical fluctuations are Gaussian
   - Normalization: 1/√(2π)

2. FOURIER ANALYSIS
   - Critical systems have power-law spectra
   - Fourier: e^(2πi...)

3. CIRCULAR SYMMETRY
   - Critical points often have rotational symmetry
   - Rotation involves π

4. NEURAL NETWORK ACTIVATIONS
   - tanh: involves π in Taylor series
   - Softmax: involves e^x, related to π through Euler

CONCLUSION:
π appears because the edge of chaos involves
circular/periodic structures in phase space.
""")

# =============================================================================
# SUMMARY
# =============================================================================

print("\n" + "=" * 70)
print("SUMMARY: EDGE OF CHAOS")
print("=" * 70)

print("""
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  EDGE OF CHAOS: WHERE COMPUTATION HAPPENS                          │
│                                                                     │
│  KEY INSIGHTS:                                                      │
│  • Neural networks train ONLY at edge of chaos                     │
│  • This is a PHASE TRANSITION like in physics                      │
│  • Critical condition: σ_w² × σ_b² = 1                             │
│                                                                     │
│  CONNECTION TO PHYSICAL CONSTANTS:                                  │
│  • 3 appears as minimum complexity for criticality                 │
│  • π appears in Gaussian fluctuations                              │
│  • φ provides optimal "controlled randomness"                      │
│                                                                     │
│  IMPLICATIONS FOR ALGORITHMS:                                       │
│  • Optimal algorithms operate at edge of chaos                     │
│  • Trinity Sort: 3-way partition = critical point                  │
│  • Golden ratio pivot = edge of chaos selection                    │
│                                                                     │
│  UNIFIED VIEW:                                                      │
│  Physics, neural networks, and algorithms all optimize             │
│  at the edge of chaos - the boundary between order and disorder.   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
""")
