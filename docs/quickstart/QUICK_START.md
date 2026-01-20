# VIBEE Quick Start Guide

**Get started with VIBEE in 5 minutes**

---

## Prerequisites

- [Zig](https://ziglang.org/download/) 0.13.0+
- Git

## Installation

```bash
# Clone the repository
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang

# Build WASM modules
cd trinity/wasm
zig build -Doptimize=ReleaseSmall -Dsimd=true

# Verify installation
ls -la zig-out/bin/*.wasm
```

Expected output:
```
phi_core.wasm        14 KB
phi_structures.wasm  18 KB
phi_layout.wasm      18 KB
phi_crypto.wasm      24 KB
```

## Run Tests

```bash
# Run all tests
zig build test

# Run specific module tests
zig test src/phi_core.zig
zig test src/phi_structures.zig
```

## Your First φ-Computation

### 1. Using WASM in Browser

```html
<!DOCTYPE html>
<html>
<head>
    <title>VIBEE φ-Demo</title>
</head>
<body>
    <script>
        async function main() {
            // Load WASM module
            const response = await fetch('phi_core.wasm');
            const bytes = await response.arrayBuffer();
            const { instance } = await WebAssembly.instantiate(bytes);
            
            // Access exports
            const { phi_power, fibonacci, verify_trinity } = instance.exports;
            
            // Compute φ^10
            console.log('φ^10 =', phi_power(10));  // 122.99...
            
            // Compute Fibonacci(20)
            console.log('F(20) =', fibonacci(20));  // 6765
            
            // Verify TRINITY identity
            console.log('φ² + 1/φ² =', verify_trinity());  // 3.0
        }
        main();
    </script>
</body>
</html>
```

### 2. Using Native Zig

```zig
const phi_core = @import("trinity/wasm/src/phi_core.zig");

pub fn main() void {
    // φ^10
    const phi_10 = phi_core.phi_power(10);
    std.debug.print("φ^10 = {d}\n", .{phi_10});
    
    // Fibonacci(20)
    const fib_20 = phi_core.fibonacci(20);
    std.debug.print("F(20) = {d}\n", .{fib_20});
    
    // TRINITY identity
    const trinity = phi_core.verify_trinity();
    std.debug.print("φ² + 1/φ² = {d}\n", .{trinity});
}
```

## Generate Code from Specification

### 1. Write a .vibee specification

```yaml
# my_feature.vibee
name: my_feature
version: "1.0.0"

constants:
  MY_CONST:
    value: 42.0
    description: "My constant"

behaviors:
  - name: my_test
    given: "input value"
    when: "compute"
    then: "expected result"
    test_cases:
      - input: { n: 0 }
        expected: 1.0
```

### 2. Generate Zig code

```bash
cd src/vibeec
zig build-exe gen_cmd.zig --name vibeec
./vibeec gen ../../specs/my_feature.vibee ../../generated/my_feature.zig
```

### 3. Test generated code

```bash
cd generated
zig test my_feature.zig
```

## Key Concepts

### TRINITY Identity

The mathematical foundation of VIBEE:

```
φ² + 1/φ² = 3

where φ = (1 + √5) / 2 ≈ 1.618033988749895
```

### φ-Optimized Algorithms

All algorithms use golden ratio properties:

| Algorithm | Complexity | Description |
|-----------|------------|-------------|
| `phi_power(n)` | O(log n) | φⁿ via fast exponentiation |
| `fibonacci(n)` | O(log n) | Binet's formula |
| `lucas(n)` | O(log n) | Lucas numbers |
| `phi_spiral(n)` | O(n) | Golden angle spiral |
| `phi_lerp(a,b,t)` | O(1) | φ-weighted interpolation |

### SIMD Acceleration

VIBEE uses WASM SIMD128 for compute-bound operations:

```zig
// 6.0x speedup over scalar
const result = phi_core.simd_verify_trinity_batch(1000);
```

## Next Steps

- [API Reference](api/phi_core.md) - Complete function documentation
- [Specification Guide](guides/SPECIFICATION.md) - How to write .vibee files
- [WASM Integration](guides/WASM.md) - Browser and Node.js usage

---

*φ² + 1/φ² = 3*
