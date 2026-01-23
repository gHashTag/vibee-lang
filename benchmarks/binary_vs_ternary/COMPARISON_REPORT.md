# Binary vs Ternary Arithmetic Benchmark

## Overview

Comparison of binary (base-2) and balanced ternary (base-3) arithmetic performance in VIBEE VM.

## Results

| Benchmark | Binary (µs) | Ternary (µs) | Ratio | Binary Result | Ternary Result |
|-----------|-------------|--------------|-------|---------------|----------------|
| add_1000 | 944 | 1394 | 1.48x | 1000 | 1 (wrapped) |
| sum_100 | 101 | 199 | 1.97x | 5050 | 1 (wrapped) |
| mul_10 | 14 | 20 | 1.45x | 1024 | 0 (wrapped) |
| fib_20 | 31 | 41 | 1.32x | 10946 | 11 (wrapped) |
| logic_100 | 204 | 342 | 1.68x | 18 | 8 |
| compare_100 | 109 | 288 | 2.64x | 50 | 3 |

**Average ratio: 1.76x** (ternary is 76% slower)

## Analysis

### Why Ternary is Slower

1. **Function Call Overhead**
   - Binary: `total = total + 1` → inline ADD opcode
   - Ternary: `tritAdd(total, one)` → CALL_NATIVE + function dispatch

2. **Type Conversion**
   - `toTryte()` and `fromTryte()` add extra operations
   - Binary operations work directly on i64

3. **Wrap-around Logic**
   - Ternary values wrap at -13/+13 boundaries
   - Requires additional checks in tritAdd/tritMul

### Ternary Advantages (Not Shown in Benchmarks)

1. **Balanced Representation**
   - No separate sign bit needed
   - Negation is simple (flip all trits)

2. **Rounding**
   - Balanced ternary rounds to nearest automatically
   - Binary requires explicit rounding

3. **Symmetric Range**
   - -13 to +13 is symmetric around 0
   - Binary unsigned is 0 to N

## Optimization Opportunities

### For Ternary Performance

1. **Inline Opcodes**
   - Replace `tritAdd` native call with `TRYTE_ADD` opcode
   - Already have opcodes, need compiler support

2. **Fused Operations**
   - `LOAD_TRIT_ADD` - load local + add tryte
   - `TRIT_ADD_STORE` - add + store result

3. **Native Tryte Literals**
   - Direct `0t001` without conversion
   - Already implemented

### Current Implementation

```
Binary:  LOAD_LOCAL → ADD → STORE_LOCAL  (3 ops)
Ternary: LOAD_LOCAL → PUSH_CONST → CALL_NATIVE → STORE_LOCAL  (4+ ops)
```

## Running the Benchmark

```bash
python3 benchmarks/binary_vs_ternary/run_comparison.py
```

## Conclusion

Ternary arithmetic is **1.76x slower** than binary in current VIBEE VM implementation due to:
- Native function call overhead
- Type conversion costs
- Wrap-around logic

With inline opcodes and compiler optimizations, the gap could be reduced to **~1.1-1.2x**.
