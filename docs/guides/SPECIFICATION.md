# VIBEE Specification Guide

**How to write .vibee specification files**

---

## Overview

VIBEE uses YAML-like specification files (`.vibee`) to define:
- Constants
- Types
- Creation patterns (algorithms)
- Behaviors (tests)

The compiler generates Zig code from these specifications.

---

## File Structure

```yaml
# Header
name: module_name
version: "1.0.0"
author: "Your Name"
license: "MIT"

# Sections
constants:
  ...

types:
  ...

creation_patterns:
  ...

behaviors:
  ...

algorithms:
  ...

wasm_exports:
  ...
```

---

## Sections

### 1. Constants

Define compile-time constants:

```yaml
constants:
  PHI:
    value: 1.618033988749895
    description: "Golden ratio"
    
  MY_CONST:
    value: 42.0
    description: "My constant"
```

**Generated Zig:**
```zig
/// Golden ratio
pub const PHI: f64 = 1.618033988749895;

/// My constant
pub const MY_CONST: f64 = 42.0;
```

---

### 2. Types

Define custom types:

```yaml
types:
  Point2D:
    description: "2D point"
    fields:
      x: f64
      y: f64
      
  Vector3D:
    description: "3D vector"
    fields:
      x: f64
      y: f64
      z: f64
    constraints:
      - "magnitude >= 0"
```

**Generated Zig:**
```zig
/// 2D point
pub const Point2D = struct {
    x: f64,
    y: f64,
};

/// 3D vector
pub const Vector3D = struct {
    x: f64,
    y: f64,
    z: f64,
};
```

---

### 3. Creation Patterns

Define algorithms using the Creation Pattern:

```yaml
creation_patterns:
  phi_power:
    source: i32
    transformer: "φ^n via fast exponentiation"
    result: f64
    
  fibonacci:
    source: u32
    transformer: "Binet's formula: (φⁿ - ψⁿ) / √5"
    result: u64
```

**Creation Pattern:**
```
Source → Transformer → Result
```

**Generated Zig:**
```zig
/// φ^n via fast exponentiation
/// Source: i32 -> Result: f64
pub export fn phi_power(n: i32) f64 {
    // Implementation
}
```

---

### 4. Behaviors

Define expected behaviors with test cases:

```yaml
behaviors:
  - name: phi_power_zero
    given: "n = 0"
    when: "compute φ^n"
    then: "result = 1.0"
    test_cases:
      - input: { n: 0 }
        expected: 1.0
        
  - name: phi_power_one
    given: "n = 1"
    when: "compute φ^n"
    then: "result = φ"
    test_cases:
      - input: { n: 1 }
        expected: 1.618033988749895
        tolerance: 1e-10
```

**Generated Zig:**
```zig
test "phi_power_zero" {
    // Given: n = 0
    // When: compute φ^n
    // Then: result = 1.0
    try std.testing.expectApproxEqAbs(phi_power(0), 1.0, 1e-10);
}

test "phi_power_one" {
    // Given: n = 1
    // When: compute φ^n
    // Then: result = φ
    try std.testing.expectApproxEqAbs(phi_power(1), 1.618033988749895, 1e-10);
}
```

---

### 5. Algorithms

Define algorithm details:

```yaml
algorithms:
  fast_exponentiation:
    description: "Compute x^n in O(log n)"
    complexity: "O(log n)"
    pattern: D&C
    steps:
      - "If n = 0, return 1"
      - "If n is odd, return x × x^(n-1)"
      - "Otherwise, return (x^(n/2))²"
```

---

### 6. WASM Exports

Define WASM module exports:

```yaml
wasm_exports:
  functions:
    - phi_power
    - fibonacci
    - verify_trinity
    
  memory:
    f64_buffer:
      size: 8192
      type: f64
      alignment: 16
```

---

## Test Cases Format

### Input Format

```yaml
input: { param1: value1, param2: value2 }
```

**Supported types:**
- Integers: `{ n: 42 }`
- Floats: `{ x: 3.14 }`
- Negative: `{ n: -1 }`

### Expected Format

```yaml
expected: 1.618033988749895
```

Or with tolerance:
```yaml
expected: 65.16
tolerance: 0.1
```

---

## Complete Example

```yaml
# phi_example.vibee
name: phi_example
version: "1.0.0"
author: "VIBEE Team"

constants:
  PHI:
    value: 1.618033988749895
    description: "Golden ratio"
  PHI_INV:
    value: 0.618033988749895
    description: "Inverse golden ratio"

types:
  PhiResult:
    fields:
      value: f64
      exponent: i32

creation_patterns:
  phi_power:
    source: i32
    transformer: "Fast exponentiation"
    result: f64

behaviors:
  - name: phi_power_basic
    given: "various exponents"
    when: "compute φ^n"
    then: "correct results"
    test_cases:
      - input: { n: 0 }
        expected: 1.0
      - input: { n: 1 }
        expected: 1.618033988749895
      - input: { n: -1 }
        expected: 0.618033988749895
      - input: { n: 2 }
        expected: 2.618033988749895

wasm_exports:
  functions:
    - phi_power
```

---

## Code Generation

```bash
# Build compiler
cd src/vibeec
zig build-exe gen_cmd.zig --name vibeec

# Generate code
./vibeec gen ../../specs/phi_example.vibee ../../generated/phi_example.zig

# Test generated code
cd ../../generated
zig test phi_example.zig
```

---

## Best Practices

1. **Always include test_cases** - They become real tests
2. **Use descriptive names** - `phi_power_negative` not `test1`
3. **Add tolerance for floats** - Floating point comparison needs tolerance
4. **Document with given/when/then** - BDD-style documentation
5. **Group related behaviors** - Keep related tests together

---

*φ² + 1/φ² = 3*
