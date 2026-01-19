# phi_core API Reference

**Core φ-computations module**

---

## Constants

### PHI
```zig
pub const PHI: f64 = 1.618033988749895;
```
The golden ratio φ = (1 + √5) / 2

### PHI_INV
```zig
pub const PHI_INV: f64 = 0.618033988749895;
```
Inverse golden ratio 1/φ = φ - 1

### PHI_SQ
```zig
pub const PHI_SQ: f64 = 2.618033988749895;
```
φ² = φ + 1

### TRINITY
```zig
pub const TRINITY: f64 = 3.0;
```
TRINITY identity: φ² + 1/φ² = 3

### SQRT5
```zig
pub const SQRT5: f64 = 2.2360679774997896;
```
√5 (used in Binet's formula)

### TAU
```zig
pub const TAU: f64 = 6.283185307179586;
```
τ = 2π

---

## Core Functions

### phi_power

Computes φⁿ using fast exponentiation.

```zig
pub export fn phi_power(n: i32) f64
```

**Parameters:**
- `n`: Exponent (can be negative)

**Returns:** φⁿ

**Complexity:** O(log |n|)

**Examples:**
```zig
phi_power(0)   // 1.0
phi_power(1)   // 1.618033988749895 (φ)
phi_power(-1)  // 0.618033988749895 (1/φ)
phi_power(2)   // 2.618033988749895 (φ²)
phi_power(10)  // 122.99186938124421
```

---

### fibonacci

Computes the n-th Fibonacci number using Binet's formula.

```zig
pub export fn fibonacci(n: u32) u64
```

**Parameters:**
- `n`: Index (0-based)

**Returns:** F(n)

**Complexity:** O(log n)

**Formula:** F(n) = (φⁿ - ψⁿ) / √5

**Examples:**
```zig
fibonacci(0)   // 0
fibonacci(1)   // 1
fibonacci(10)  // 55
fibonacci(20)  // 6765
fibonacci(40)  // 102334155
```

---

### lucas

Computes the n-th Lucas number.

```zig
export fn lucas(n: u32) u64
```

**Parameters:**
- `n`: Index (0-based)

**Returns:** L(n)

**Complexity:** O(log n)

**Formula:** L(n) = φⁿ + ψⁿ

**Examples:**
```zig
lucas(0)   // 2
lucas(1)   // 1
lucas(10)  // 123
lucas(20)  // 15127
```

---

### verify_trinity

Verifies the TRINITY identity: φ² + 1/φ² = 3

```zig
pub export fn verify_trinity() f64
```

**Returns:** φ² + 1/φ² (should be 3.0)

**Complexity:** O(1)

**Benchmark:** 236.9M ops/sec

---

### phi_lerp

φ-weighted linear interpolation.

```zig
pub export fn phi_lerp(a: f64, b: f64, t: f64) f64
```

**Parameters:**
- `a`: Start value
- `b`: End value
- `t`: Interpolation factor [0, 1]

**Returns:** a + (b - a) × t^(1/φ)

**Complexity:** O(1)

**Examples:**
```zig
phi_lerp(0.0, 100.0, 0.0)  // 0.0
phi_lerp(0.0, 100.0, 1.0)  // 100.0
phi_lerp(0.0, 100.0, 0.5)  // ~65.16 (φ-weighted)
```

---

### generate_phi_spiral

Generates points on a golden angle spiral.

```zig
pub export fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32
```

**Parameters:**
- `n`: Number of points
- `scale`: Scale factor
- `cx`, `cy`: Center coordinates

**Returns:** Number of points generated

**Output:** Points stored in `f64_buffer` as [x0, y0, x1, y1, ...]

**Complexity:** O(n)

**Benchmark:** 8.5M points/sec

---

## SIMD Functions

### simd_verify_trinity_batch

Batch verification of TRINITY identity using SIMD.

```zig
pub export fn simd_verify_trinity_batch(iterations: u32) f64
```

**Parameters:**
- `iterations`: Number of verifications (must be multiple of 4)

**Returns:** Sum of all results

**Speedup:** 6.0x over scalar

**Benchmark:** 1.42B ops/sec

---

### simd_dot_product

SIMD-accelerated dot product.

```zig
pub export fn simd_dot_product(n: u32) f64
```

**Parameters:**
- `n`: Vector length

**Input:** v1 = f64_buffer[0..n], v2 = f64_buffer[n..2n]

**Returns:** v1 · v2

**Benchmark:** 320.4M FLOPS

---

### simd_sum_squares

SIMD-accelerated sum of squares.

```zig
pub export fn simd_sum_squares(n: u32) f64
```

**Parameters:**
- `n`: Vector length

**Input:** f64_buffer[0..n]

**Returns:** Σ(x²)

---

### simd_phi_weighted_sum

φ-weighted sum with SIMD acceleration.

```zig
pub export fn simd_phi_weighted_sum(n: u32) f64
```

**Parameters:**
- `n`: Number of values

**Input:** f64_buffer[0..n]

**Returns:** Σ(xᵢ × φ⁻ⁱ) / Σ(φ⁻ⁱ)

---

## Memory Buffers

### f64_buffer

Shared buffer for bulk operations.

```zig
pub var f64_buffer: [8192]f64 align(16) = undefined;
```

**Size:** 8192 × 8 = 65,536 bytes

**Usage:**
```zig
// Get pointer (for WASM)
const ptr = get_f64_buffer_ptr();
const size = get_f64_buffer_size();
```

### global_buffer

General-purpose byte buffer.

```zig
var global_buffer: [65536]u8 = undefined;
```

**Size:** 64 KB

---

## Performance Summary

| Function | Ops/sec | Latency | Notes |
|----------|---------|---------|-------|
| phi_power | 40.5M | 24.7 ns | O(log n) |
| fibonacci | 11.05M | 90.5 ns | Binet's formula |
| verify_trinity | 236.9M | 4.2 ns | O(1) |
| simd_trinity_batch | 1.42B | 0.7 ns | 6.0x speedup |
| phi_spiral(100) | 84.8K | 11.8 μs | 8.5M pts/sec |
| simd_dot_product | 160K | 6.2 μs | 320M FLOPS |

---

*φ² + 1/φ² = 3*
