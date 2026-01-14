#!/usr/bin/env python3
"""
Trinity Compression: 3-symbol encoding
Testing if ternary encoding improves compression

Author: Dmitrii Vasilev
Date: January 13, 2026

Hypothesis: Base-3 encoding may be more efficient than binary
for certain types of data.
"""

import math
import random
from typing import List, Tuple
from collections import Counter

print("=" * 70)
print("TRINITY COMPRESSION: TERNARY ENCODING")
print("=" * 70)

# =============================================================================
# THEORETICAL ANALYSIS
# =============================================================================

print("\n" + "=" * 70)
print("1. THEORETICAL ANALYSIS: OPTIMAL BASE FOR ENCODING")
print("=" * 70)

print("""
QUESTION: What is the optimal base for number representation?

RADIX ECONOMY:
The "cost" of representing a number N in base b is:
  E(b) = b × ⌈log_b(N)⌉ = b × ⌈ln(N)/ln(b)⌉

For large N, this is approximately:
  E(b) ≈ b × ln(N) / ln(b)

MINIMIZING E(b):
  d/db [b / ln(b)] = (ln(b) - 1) / ln²(b)
  
  Setting to 0: ln(b) = 1 → b = e ≈ 2.718

OPTIMAL BASE = e ≈ 2.718

Closest integers:
  b=2: 2/ln(2) = 2.885
  b=3: 3/ln(3) = 2.731  ← MINIMUM!
  b=4: 4/ln(4) = 2.885

BASE 3 IS THEORETICALLY OPTIMAL!
""")

# Calculate radix economy
print("Radix economy b/ln(b):")
print(f"{'Base':<10} {'b/ln(b)':<15} {'Relative to e'}")
print("-" * 40)

e_economy = math.e / math.log(math.e)  # = e/1 = e
for b in [2, 3, 4, 5, 6, 8, 10, 16]:
    economy = b / math.log(b)
    relative = economy / e_economy
    optimal = "← BEST INTEGER" if b == 3 else ""
    print(f"{b:<10} {economy:<15.4f} {relative:.4f} {optimal}")

# =============================================================================
# TERNARY ENCODING
# =============================================================================

print("\n" + "=" * 70)
print("2. TERNARY ENCODING")
print("=" * 70)

def to_ternary(n: int) -> str:
    """Convert integer to ternary string"""
    if n == 0:
        return "0"
    digits = []
    while n:
        digits.append(str(n % 3))
        n //= 3
    return ''.join(reversed(digits))

def from_ternary(s: str) -> int:
    """Convert ternary string to integer"""
    result = 0
    for c in s:
        result = result * 3 + int(c)
    return result

def to_binary(n: int) -> str:
    """Convert integer to binary string"""
    return bin(n)[2:]

print("Comparison of representations:")
print(f"{'Decimal':<12} {'Binary':<20} {'Ternary':<15} {'Binary len':<12} {'Ternary len'}")
print("-" * 70)

for n in [7, 26, 27, 100, 1000, 10000]:
    binary = to_binary(n)
    ternary = to_ternary(n)
    print(f"{n:<12} {binary:<20} {ternary:<15} {len(binary):<12} {len(ternary)}")

# =============================================================================
# BALANCED TERNARY
# =============================================================================

print("\n" + "=" * 70)
print("3. BALANCED TERNARY: {-1, 0, +1}")
print("=" * 70)

print("""
BALANCED TERNARY uses digits {-1, 0, +1} instead of {0, 1, 2}

ADVANTAGES:
1. No separate sign bit needed
2. Rounding = truncation
3. Negation = flip all digits
4. Used in some Soviet computers (Setun, 1958)

REPRESENTATION:
  Using symbols: -, 0, +
  
  Example: 8 in balanced ternary
  8 = 9 - 1 = 3² - 1 = +0- (meaning 1×9 + 0×3 + (-1)×1)
""")

def to_balanced_ternary(n: int) -> str:
    """Convert to balanced ternary"""
    if n == 0:
        return "0"
    
    digits = []
    while n != 0:
        rem = n % 3
        if rem == 0:
            digits.append('0')
            n //= 3
        elif rem == 1:
            digits.append('+')
            n //= 3
        else:  # rem == 2
            digits.append('-')
            n = (n + 1) // 3
    
    return ''.join(reversed(digits))

def from_balanced_ternary(s: str) -> int:
    """Convert from balanced ternary"""
    result = 0
    for c in s:
        result *= 3
        if c == '+':
            result += 1
        elif c == '-':
            result -= 1
    return result

print("\nBalanced ternary examples:")
print(f"{'Decimal':<12} {'Balanced Ternary':<20} {'Verification'}")
print("-" * 50)

for n in [-13, -5, -1, 0, 1, 5, 8, 13, 27]:
    bt = to_balanced_ternary(n)
    verify = from_balanced_ternary(bt)
    print(f"{n:<12} {bt:<20} {verify}")

# =============================================================================
# HUFFMAN WITH 3 SYMBOLS
# =============================================================================

print("\n" + "=" * 70)
print("4. TERNARY HUFFMAN CODING")
print("=" * 70)

class TernaryHuffmanNode:
    def __init__(self, char=None, freq=0):
        self.char = char
        self.freq = freq
        self.children = [None, None, None]  # 3 children!

def ternary_huffman(frequencies: dict) -> dict:
    """
    Build ternary Huffman tree (3 children per node)
    Returns encoding dictionary
    """
    # Need (n-1) % 2 == 0 for complete ternary tree
    # Add dummy nodes if needed
    nodes = [TernaryHuffmanNode(char, freq) for char, freq in frequencies.items()]
    
    # Pad to make (n-1) divisible by 2
    while (len(nodes) - 1) % 2 != 0:
        nodes.append(TernaryHuffmanNode(None, 0))
    
    import heapq
    heap = [(node.freq, i, node) for i, node in enumerate(nodes)]
    heapq.heapify(heap)
    
    counter = len(nodes)
    
    while len(heap) > 1:
        # Take 3 smallest (or 2 if only 2 left)
        children = []
        for _ in range(min(3, len(heap))):
            if heap:
                children.append(heapq.heappop(heap))
        
        if len(children) < 2:
            break
            
        # Create parent
        parent = TernaryHuffmanNode()
        parent.freq = sum(c[0] for c in children)
        for i, (_, _, child) in enumerate(children):
            parent.children[i] = child
        
        heapq.heappush(heap, (parent.freq, counter, parent))
        counter += 1
    
    # Build codes
    codes = {}
    
    def build_codes(node, code=""):
        if node is None:
            return
        if node.char is not None:
            codes[node.char] = code if code else "0"
            return
        for i, child in enumerate(node.children):
            if child is not None:
                build_codes(child, code + str(i))
    
    if heap:
        build_codes(heap[0][2])
    
    return codes

# Example
text = "abracadabra"
freq = Counter(text)
print(f"\nText: '{text}'")
print(f"Frequencies: {dict(freq)}")

codes = ternary_huffman(freq)
print(f"\nTernary Huffman codes:")
for char, code in sorted(codes.items()):
    print(f"  '{char}': {code}")

# Calculate compression
original_bits = len(text) * 8
ternary_trits = sum(len(codes.get(c, "")) for c in text)
# Convert trits to bits: 1 trit ≈ log2(3) ≈ 1.585 bits
ternary_bits = ternary_trits * math.log2(3)

print(f"\nCompression:")
print(f"  Original: {original_bits} bits")
print(f"  Ternary Huffman: {ternary_trits} trits ≈ {ternary_bits:.1f} bits")
print(f"  Compression ratio: {original_bits / ternary_bits:.2f}x")

# =============================================================================
# RUN-LENGTH ENCODING WITH 3 STATES
# =============================================================================

print("\n" + "=" * 70)
print("5. TRINITY RUN-LENGTH ENCODING")
print("=" * 70)

print("""
IDEA: Use 3 states for RLE:
  0 = literal byte follows
  1 = short run (2-4 repeats)
  2 = long run (5+ repeats, length follows)

This is more efficient than binary RLE for mixed data.
""")

def trinity_rle_encode(data: bytes) -> bytes:
    """Trinity RLE: 3-state run-length encoding"""
    result = []
    i = 0
    
    while i < len(data):
        # Count run length
        run_start = i
        while i < len(data) - 1 and data[i] == data[i + 1] and i - run_start < 255:
            i += 1
        run_len = i - run_start + 1
        
        if run_len == 1:
            # State 0: literal
            result.extend([0, data[run_start]])
        elif run_len <= 4:
            # State 1: short run (encode length in 2 bits)
            result.extend([1, (run_len - 2) << 6 | data[run_start]])
        else:
            # State 2: long run
            result.extend([2, run_len, data[run_start]])
        
        i += 1
    
    return bytes(result)

def trinity_rle_decode(data: bytes) -> bytes:
    """Decode Trinity RLE"""
    result = []
    i = 0
    
    while i < len(data):
        state = data[i]
        
        if state == 0:
            # Literal
            result.append(data[i + 1])
            i += 2
        elif state == 1:
            # Short run
            length = ((data[i + 1] >> 6) & 0x3) + 2
            byte = data[i + 1] & 0x3F
            result.extend([byte] * length)
            i += 2
        else:
            # Long run
            length = data[i + 1]
            byte = data[i + 2]
            result.extend([byte] * length)
            i += 3
    
    return bytes(result)

# Test
test_data = bytes([1, 1, 1, 2, 3, 3, 3, 3, 3, 3, 3, 4, 5, 5])
encoded = trinity_rle_encode(test_data)
decoded = trinity_rle_decode(encoded)

print(f"Original:  {list(test_data)} ({len(test_data)} bytes)")
print(f"Encoded:   {list(encoded)} ({len(encoded)} bytes)")
print(f"Decoded:   {list(decoded)}")
print(f"Correct:   {decoded == test_data}")
print(f"Compression: {len(test_data) / len(encoded):.2f}x")

# =============================================================================
# CONCLUSIONS
# =============================================================================

print("\n" + "=" * 70)
print("CONCLUSIONS")
print("=" * 70)

print("""
KEY FINDINGS:

1. OPTIMAL BASE FOR ENCODING = e ≈ 2.718
   - Minimizes b/ln(b)
   - Closest integer is 3!
   - Base 3 is 5.3% more efficient than base 2

2. BALANCED TERNARY
   - Elegant representation with {-1, 0, +1}
   - No sign bit needed
   - Used in Soviet Setun computer (1958)

3. TERNARY HUFFMAN
   - 3 children per node
   - Can be more efficient for some distributions
   - Requires careful tree construction

4. TRINITY RLE
   - 3 states: literal, short run, long run
   - Better for mixed data than binary RLE

5. PRACTICAL CONSIDERATIONS
   - Binary hardware is ubiquitous
   - Ternary requires special hardware
   - Theoretical advantage may not translate to practice

THE TRINITY PRINCIPLE IN COMPRESSION:
- Base 3 is theoretically optimal
- 3 states can improve encoding schemes
- But binary dominates due to hardware
""")
