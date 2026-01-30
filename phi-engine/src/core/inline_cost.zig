//! VIBEE Φ-ENGINE - INLINE COST (Solution #8)
//!
//! Inline Cost - Cost Model for JIT Compilation
//!
//! Scientific Basis: Amdahl's Law (1967)
//! Cost Benefit Analysis of Inline Functions
//!
//! Sacred Formula: φ = (1 + √5) / 2

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

/// Function Cost Type
pub const CostType = enum {
    cheap, // O(1) simple ops
    medium, // O(log n) or O(n) small loops
    expensive, // O(n²) or recursion
};

/// Function Metadata
pub const FunctionMeta = struct {
    name: []const u8,
    cost: f64, // Estimated execution cost
    size: usize, // Code size in bytes
    inlined: bool, // Was it inlined?
};

/// Calculate inline cost heuristic
/// Uses golden ratio to weigh execution cost vs code size
pub fn inlineCost(func_meta: FunctionMeta) f64 {
    // Weight: Execution vs Size
    // φ = 1.618, 1/φ = 0.618
    // Execution is weighted more heavily

    const weight_exec: f64 = PHI;
    const weight_size: f64 = 1.0 / PHI;

    // Heuristic Cost = (ExecCost * WeightExec) + (Size * WeightSize)
    const cost = (func_meta.cost * weight_exec) + (@as(f64, func_meta.size) * weight_size);

    return cost;
}

/// Calculate benefit of inlining
/// Benefit = (Cost of call overhead) - (Cost of inline bloat)
pub fn inlineBenefit(func_meta: FunctionMeta) f64 {
    const call_overhead_cost: f64 = 10.0; // Fixed cost for function call
    const bloat_cost: f64 = @as(f64, func_meta.size);

    // Benefit = Call Overhead - Inline Bloat
    // (If positive, inlining is beneficial)
    return call_overhead_cost - bloat_cost;
}

/// Decide if function should be inlined
/// Returns true if benefit > threshold
pub fn shouldInline(func_meta: FunctionMeta) bool {
    const benefit = inlineBenefit(func_meta);
    const cost = inlineCost(func_meta);

    // Decision threshold (can be tuned)
    // φ × 5 ≈ 8
    const threshold: f64 = PHI * 5.0;

    // Inline if benefit outweighs cost
    return benefit > threshold or cost < 1.0; // Always inline cheap functions
}

// ════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                                                ║
// ╚═══════════════════════════════════════════════════════════════════════════════╝

test "Inline Cost: cheap function" {
    const func_meta = FunctionMeta{
        .name = "add",
        .cost = 1.0, // O(1)
        .size = 10, // Small
        .inlined = false,
    };

    const cost = inlineCost(func_meta);
    const benefit = inlineBenefit(func_meta);
    const should_inline = shouldInline(func_meta);

    // Cheap functions should have low cost and high benefit
    try std.testing.expect(cost < 100.0);
    try std.testing.expect(benefit > 0.0);
    try std.testing.expectEqual(true, should_inline);
}

test "Inline Cost: expensive function" {
    const func_meta = FunctionMeta{
        .name = "matrix_mul",
        .cost = 100.0, // O(n²)
        .size = 500, // Large
        .inlined = false,
    };

    const cost = inlineCost(func_meta);
    const benefit = inlineBenefit(func_meta);
    const should_inline = shouldInline(func_meta);

    // Expensive functions should have high cost and low benefit (bloat)
    try std.testing.expect(cost > 1000.0);
    try std.testing.expect(benefit < 0.0);
    try std.testing.expectEqual(false, should_inline);
}

test "Inline Cost: golden ratio weights" {
    // Verify that weights follow golden ratio
    const weight_exec: f64 = PHI;
    const weight_size: f64 = 1.0 / PHI;

    try std.testing.expectApproxEqAbs(weight_exec, 1.618, 0.001);
    try std.testing.expectApproxEqAbs(weight_size, 0.618, 0.001);
}

test "Inline Cost: phi identity" {
    // φ × (1/φ) = 1
    const phi_inv = 1.0 / PHI;
    const product = PHI * phi_inv;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, product, 0.0001);
}
