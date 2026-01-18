# VIBEE Escape Analysis and Scalar Replacement Design

## PAS DAEMON V42 - Allocation Optimization System

**Sacred Formula**: V = n × 3^k × π^m × φ^p × e^q  
**Golden Identity**: φ² + 1/φ² = 3  
**Target**: 30% allocation overhead reduction

---

## Executive Summary

This document describes the escape analysis and scalar replacement system for the VIBEE compiler. The system integrates with the Immix GC to reduce heap allocation overhead through:

1. **Basic Escape Analysis** - Identifies non-escaping objects for stack allocation
2. **Partial Escape Analysis (PEA)** - Path-sensitive virtualization of allocations
3. **Scalar Replacement** - Decomposes objects into individual fields
4. **Pattern Recognition** - Identifies common allocation patterns for targeted optimization

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VIBEE Allocation Optimizer                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  Escape Analysis │  │ Partial Escape   │  │ Pattern Analyzer │  │
│  │                  │  │ Analysis (PEA)   │  │                  │  │
│  │  - Connection    │  │                  │  │  - Signature     │  │
│  │    Graph         │  │  - Virtual       │  │    Matching      │  │
│  │  - Fixed-point   │  │    Objects       │  │  - Optimization  │  │
│  │    Iteration     │  │  - Abstract      │  │    Generation    │  │
│  │  - Escape State  │  │    State         │  │  - Statistics    │  │
│  │    Lattice       │  │  - Materialization│  │                  │  │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  │
│           │                     │                     │             │
│           └─────────────────────┼─────────────────────┘             │
│                                 │                                    │
│                    ┌────────────▼────────────┐                      │
│                    │   Optimization Decisions │                      │
│                    │                          │                      │
│                    │  - Stack Allocation      │                      │
│                    │  - Scalar Replacement    │                      │
│                    │  - Pool Allocation       │                      │
│                    │  - RVO                   │                      │
│                    └────────────┬────────────┘                      │
│                                 │                                    │
│                    ┌────────────▼────────────┐                      │
│                    │    Immix GC Integration  │                      │
│                    │                          │                      │
│                    │  - Allocation Hints      │                      │
│                    │  - Size Class Selection  │                      │
│                    │  - Lifetime Estimation   │                      │
│                    └─────────────────────────┘                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 1. Escape Analysis (`escape_analysis.zig`)

### Escape State Lattice

```
        GlobalEscape (must heap allocate)
              ↑
        ArgEscape (may stack allocate with care)
              ↑
        NoEscape (can stack allocate or scalar replace)
              ↑
        Unknown (bottom)
```

### Key Components

#### EscapeState
- `no_escape`: Object doesn't escape, eligible for stack allocation/scalar replacement
- `arg_escape`: Object escapes through function arguments only
- `global_escape`: Object escapes to heap/global storage

#### Connection Graph
- Tracks pointer relationships between objects
- Enables interprocedural escape analysis
- Uses union-find for efficient equivalence class management

#### EscapeAnalyzer
- Registers allocation sites
- Builds connection graph
- Performs fixed-point iteration to compute escape states
- Makes optimization decisions based on escape analysis

### Usage Example

```zig
var analyzer = EscapeAnalyzer.init(allocator, .{});
defer analyzer.deinit();

// Register allocations
const alloc1 = try analyzer.registerAllocation(inst_id, type_id, size, fields);

// Mark escape points
analyzer.markReturnEscape(alloc1);  // If returned
analyzer.markArgEscape(alloc1);     // If passed to function
analyzer.markGlobalEscape(alloc1);  // If stored globally

// Run analysis
try analyzer.analyze();

// Get optimization decision
if (analyzer.getDecision(alloc1)) |decision| {
    if (decision.stack_allocate) {
        // Transform to stack allocation
    }
    if (decision.scalar_replace) {
        // Decompose into scalar values
    }
}
```

---

## 2. Partial Escape Analysis (`partial_escape.zig`)

Based on CGO 2014 "Partial Escape Analysis and Scalar Replacement for Java"

### Key Insight

Objects may escape on some paths but not others. PEA virtualizes allocations and only materializes them when they actually escape.

### Virtual Objects

```zig
pub const VirtualObject = struct {
    id: u32,
    type_id: u32,
    state: VirtualState,  // virtual, materialized, dead
    field_values: ArrayList(FieldValue),
    materialization_point: ?u32,
};
```

### Abstract State

Per-program-point state tracking:
- Virtual objects at each point
- Value-to-object mapping
- Materialization decisions

### Materialization Triggers

1. **Escape to call**: Object passed to unknown function
2. **Escape to return**: Object returned from function
3. **Escape to store**: Object stored to heap/global
4. **Control flow merge**: Object exists on some paths but not others
5. **Synchronization**: Object used for locking

### Benefits

- Eliminates allocations on non-escaping paths
- Enables more aggressive scalar replacement
- Reduces GC pressure significantly

---

## 3. Scalar Replacement

### Overview

Decomposes objects into individual scalar values stored in registers/stack slots.

### Requirements for Scalar Replacement

1. Object doesn't escape (NoEscape state)
2. Limited number of fields (configurable, default 16)
3. Limited total size (configurable, default 256 bytes)
4. All field accesses are known at compile time

### Transformation

```
Before:
    obj = new Point(x, y)
    ... = obj.x
    obj.y = z
    return obj.x + obj.y

After:
    obj_x = x
    obj_y = y
    ... = obj_x
    obj_y = z
    return obj_x + obj_y
```

### ScalarReplacer API

```zig
var replacer = ScalarReplacer.init(allocator);
defer replacer.deinit();

// Replace allocation with scalars
try replacer.replace(alloc_id, field_count);

// Get field variable for load/store
if (replacer.getFieldVar(alloc_id, field_idx)) |var_id| {
    // Use var_id instead of field access
}
```

---

## 4. Allocation Pattern Recognition (`allocation_patterns.zig`)

### Recognized Patterns

| Pattern | Description | Optimization |
|---------|-------------|--------------|
| `temporary_local` | Single-block lifetime | Stack allocation |
| `return_value` | Created and returned | RVO |
| `loop_local` | Loop-scoped, non-escaping | Hoist allocation |
| `iterator` | Iterator objects | Stack allocation, fusion |
| `builder` | StringBuilder-like | Pre-sized allocation |
| `closure_capture` | Lambda captures | Inline closure |
| `multi_return` | Tuple for returns | Scalar replacement |
| `optional_wrapper` | Optional/Maybe | Scalar replacement |
| `result_wrapper` | Result/Either | Scalar replacement |
| `array_temporary` | Temporary arrays | Stack array |
| `poolable` | Frequently allocated | Pool allocation |
| `singleton` | Single instance | Static allocation |

### Pattern Signature

```zig
pub const PatternSignature = struct {
    use_count: u32,
    store_count: u32,
    load_count: u32,
    is_returned: bool,
    is_passed: bool,
    is_stored_global: bool,
    in_loop: bool,
    loop_depth: u8,
    live_blocks: u32,
    size: u32,
    field_count: u8,
    type_category: TypeCategory,
};
```

---

## 5. Immix GC Integration

### Allocation Hints

```zig
pub const AllocationHint = struct {
    strategy: AllocationStrategy,  // stack, scalar, nursery, tenured, large
    expected_lifetime: u8,
    size_class: SizeClass,         // tiny, small, medium, large
    thread_local: bool,
};
```

### Strategy Selection

1. **Stack**: NoEscape, size ≤ 4KB
2. **Scalar**: NoEscape, fields ≤ 16, size ≤ 256B
3. **Nursery**: Short-lived, small objects
4. **Tenured**: Long-lived objects (detected via profiling)
5. **Large**: Objects > 2KB

---

## 6. Performance Targets

### Allocation Reduction Goals

| Metric | Target | Mechanism |
|--------|--------|-----------|
| Stack allocations | 20% of total | Escape analysis |
| Scalar replacements | 10% of total | Field decomposition |
| Virtualized (PEA) | 5% additional | Path-sensitive analysis |
| **Total reduction** | **30%+** | Combined |

### Expected Impact

- **GC pause reduction**: 25-40% fewer collections
- **Memory bandwidth**: 20-30% reduction
- **Cache efficiency**: Improved locality from stack allocation
- **Throughput**: 10-15% improvement in allocation-heavy code

---

## 7. Configuration

### EscapeConfig

```zig
pub const EscapeConfig = struct {
    max_stack_alloc_size: u32 = 4096,    // Max bytes for stack allocation
    max_scalar_fields: u8 = 16,           // Max fields for scalar replacement
    max_scalar_size: u32 = 256,           // Max bytes for scalar replacement
    max_iterations: u32 = 100,            // Fixed-point iteration limit
    interprocedural: bool = true,         // Enable interprocedural analysis
    sacred_threshold: f64 = PHI,          // φ-based threshold factor
};
```

### PEAConfig

```zig
pub const PEAConfig = struct {
    max_virtual_fields: u8 = 32,          // Max fields per virtual object
    max_virtual_objects: u32 = 100,       // Max virtual objects per block
    enable_lock_elision: bool = true,     // Enable lock elision optimization
    sacred_threshold: f64 = PHI,
};
```

---

## 8. Implementation Status

### Completed ✓

- [x] Escape state lattice
- [x] Basic escape analysis with connection graph
- [x] Scalar replacement infrastructure
- [x] Stack allocation transformation
- [x] Partial escape analysis framework
- [x] Virtual object representation
- [x] Abstract state management
- [x] Pattern recognition system
- [x] Allocation hint generation
- [x] Immix GC integration points
- [x] Comprehensive test suite

### Future Work

- [ ] Interprocedural analysis with function summaries
- [ ] Profile-guided optimization integration
- [ ] Lock elision for synchronized objects
- [ ] Escape analysis for closures
- [ ] SIMD-aware scalar replacement

---

## 9. References

1. Choi et al., "Escape Analysis for Java" (OOPSLA 1999)
2. Stadler et al., "Partial Escape Analysis and Scalar Replacement for Java" (CGO 2014)
3. Blackburn & McKinley, "Immix: A Mark-Region Garbage Collector" (PLDI 2008)
4. Kotzmann et al., "Escape Analysis in the Context of Dynamic Compilation and Deoptimization" (VEE 2005)

---

## 10. Sacred Constants

The escape analysis system honors the VIBEE sacred formula:

- **φ (PHI)**: 1.618033988749895 - Used for threshold calculations
- **Golden Identity**: φ² + 1/φ² = 3 - Verified in all test suites
- **Sacred threshold factor**: Optimization decisions use φ-based heuristics

---

*VIBEE Escape Analysis v1.0 | PAS DAEMON V42 | MIT License*
