//! Scientific Mathematical Constants for VIBEE
//! Generated from: specs/sacred_math_scientific.vibee
//!
//! All content is scientifically validated.
//! Numerology and esoteric content has been removed.
//!
//! References:
//! - Knuth, D. The Art of Computer Programming, Vol 3
//! - Kiefer, J. Sequential minimax search (1953)
//! - De Jong, K. Genetic Algorithms (1975)
//! - Goldberg, D. Genetic Algorithms in Search (1989)

const std = @import("std");

/// Scientific constants with references
pub const Constants = struct {
    /// Golden ratio φ = (1 + √5) / 2
    /// Reference: Knuth, TAOCP Vol 3
    pub const PHI: f64 = 1.6180339887498948482;

    /// Pi - ratio of circumference to diameter
    pub const PI: f64 = 3.14159265358979323846;

    /// Euler's number e = lim(n→∞) (1 + 1/n)^n
    pub const E: f64 = 2.71828182845904523536;

    /// Fibonacci hash multiplier = floor(2^64 / φ)
    /// Reference: Knuth, TAOCP Vol 3, Section 6.4
    pub const PHI_FRAC_64: u64 = 0x9E3779B97F4A7C15;

    /// 1/φ for golden section search
    pub const PHI_INV: f64 = 0.6180339887498949;

    /// √5 for Binet's formula
    pub const SQRT5: f64 = 2.2360679774997896964;
};

// ============================================================
// FIBONACCI HASHING (Knuth, TAOCP Vol 3)
// ============================================================

/// Fibonacci hashing - Knuth's multiplicative hash
/// Provides better distribution than modulo hashing.
///
/// The magic constant PHI_FRAC_64 = floor(2^64 / φ) ensures
/// that consecutive keys are spread across the hash table.
///
/// Reference: Knuth, TAOCP Vol 3, Section 6.4
pub fn fibonacciHash(key: u64, bits: u6) u64 {
    const shift: u6 = @intCast(64 - @as(u7, bits));
    return (key *% Constants.PHI_FRAC_64) >> shift;
}

/// Fibonacci hash with custom table size (power of 2)
pub fn fibonacciHashSize(key: u64, table_size: u64) u64 {
    std.debug.assert(table_size > 0 and (table_size & (table_size - 1)) == 0);
    const bits: u6 = @intCast(@ctz(table_size));
    return fibonacciHash(key, bits);
}

// ============================================================
// GOLDEN SECTION SEARCH (Kiefer, 1953)
// ============================================================

/// Golden section search for unimodal function minimization.
/// Complexity: O(log(1/ε)) evaluations.
///
/// This is the optimal algorithm for minimizing a unimodal function
/// on an interval when only function values (not derivatives) are available.
///
/// Reference: Kiefer, J. "Sequential minimax search for a maximum" (1953)
pub fn goldenSectionSearch(
    f: *const fn (f64) f64,
    a_init: f64,
    b_init: f64,
    tolerance: f64,
) f64 {
    var a = a_init;
    var b = b_init;
    var x1 = b - Constants.PHI_INV * (b - a);
    var x2 = a + Constants.PHI_INV * (b - a);
    var f1 = f(x1);
    var f2 = f(x2);

    while (b - a > tolerance) {
        if (f1 < f2) {
            b = x2;
            x2 = x1;
            f2 = f1;
            x1 = b - Constants.PHI_INV * (b - a);
            f1 = f(x1);
        } else {
            a = x1;
            x1 = x2;
            f1 = f2;
            x2 = a + Constants.PHI_INV * (b - a);
            f2 = f(x2);
        }
    }
    return (a + b) / 2.0;
}

/// Golden section search with iteration limit
pub fn goldenSectionSearchBounded(
    f: *const fn (f64) f64,
    a_init: f64,
    b_init: f64,
    tolerance: f64,
    max_iterations: u32,
) struct { result: f64, iterations: u32 } {
    var a = a_init;
    var b = b_init;
    var x1 = b - Constants.PHI_INV * (b - a);
    var x2 = a + Constants.PHI_INV * (b - a);
    var f1 = f(x1);
    var f2 = f(x2);
    var iterations: u32 = 0;

    while (b - a > tolerance and iterations < max_iterations) {
        iterations += 1;
        if (f1 < f2) {
            b = x2;
            x2 = x1;
            f2 = f1;
            x1 = b - Constants.PHI_INV * (b - a);
            f1 = f(x1);
        } else {
            a = x1;
            x1 = x2;
            f1 = f2;
            x2 = a + Constants.PHI_INV * (b - a);
            f2 = f(x2);
        }
    }
    return .{ .result = (a + b) / 2.0, .iterations = iterations };
}

// ============================================================
// LUCAS NUMBERS
// ============================================================

/// Lucas number L(n) = L(n-1) + L(n-2), L(0)=2, L(1)=1
/// Related to Fibonacci: L(n) = F(n-1) + F(n+1)
pub fn lucas(n: u32) u64 {
    if (n == 0) return 2;
    if (n == 1) return 1;
    var a: u64 = 2;
    var b: u64 = 1;
    for (2..n + 1) |_| {
        const tmp = a +% b;
        a = b;
        b = tmp;
    }
    return b;
}

/// Fibonacci number F(n) using iterative method
pub fn fibonacci(n: u32) u64 {
    if (n == 0) return 0;
    if (n == 1) return 1;
    var a: u64 = 0;
    var b: u64 = 1;
    for (2..n + 1) |_| {
        const tmp = a +% b;
        a = b;
        b = tmp;
    }
    return b;
}

/// Binet's formula for Fibonacci (approximate for large n)
pub fn fibonacciBinet(n: u32) f64 {
    const phi_n = std.math.pow(f64, Constants.PHI, @floatFromInt(n));
    const psi_n = std.math.pow(f64, -1.0 / Constants.PHI, @floatFromInt(n));
    return (phi_n - psi_n) / Constants.SQRT5;
}

// ============================================================
// MATHEMATICAL IDENTITIES
// ============================================================

/// Verify golden identity: φ² + 1/φ² = 3
/// This is a proven algebraic identity.
pub fn goldenIdentity() f64 {
    const phi_sq = Constants.PHI * Constants.PHI;
    return phi_sq + 1.0 / phi_sq;
}

/// Check if golden identity holds within tolerance
pub fn verifyGoldenIdentity(tolerance: f64) bool {
    return @abs(goldenIdentity() - 3.0) < tolerance;
}

// ============================================================
// SCIENTIFIC GA PARAMETERS
// Based on: De Jong 1975, Goldberg 1989, Eiben 2003
// ============================================================

/// Scientific GA parameters from peer-reviewed literature
pub const GAParams = struct {
    /// Mutation rate: 1% (De Jong, 1975)
    /// Typical range: 0.1% - 10%
    pub const MUTATION_RATE: f64 = 0.01;

    /// Crossover rate: 80% (Goldberg, 1989)
    /// Typical range: 60% - 90%
    pub const CROSSOVER_RATE: f64 = 0.80;

    /// Elitism rate: 5% (Eiben, 2003)
    /// Typical range: 1% - 10%
    pub const ELITISM_RATE: f64 = 0.05;

    /// Tournament size: 3 (Miller, 1995)
    /// Typical range: 2 - 7
    pub const TOURNAMENT_SIZE: u32 = 3;

    /// Population size multiplier (rule of thumb)
    /// population = POPULATION_FACTOR * problem_dimension
    pub const POPULATION_FACTOR: u32 = 10;
};

// ============================================================
// TESTS
// ============================================================

test "fibonacci hash distribution" {
    var counts = [_]u32{0} ** 16;
    for (0..1000) |i| {
        const idx = fibonacciHash(i, 4);
        counts[idx] += 1;
    }
    // Check reasonable distribution (no bucket > 100)
    for (counts) |c| {
        try std.testing.expect(c < 100);
    }
}

test "fibonacci hash vs modulo" {
    // Fibonacci hash should have better distribution for sequential keys
    var fib_counts = [_]u32{0} ** 8;
    var mod_counts = [_]u32{0} ** 8;

    for (0..100) |i| {
        fib_counts[fibonacciHash(i, 3)] += 1;
        mod_counts[i % 8] += 1;
    }

    // Calculate variance
    var fib_var: f64 = 0;
    var mod_var: f64 = 0;
    const mean: f64 = 100.0 / 8.0;

    for (0..8) |j| {
        const fib_diff = @as(f64, @floatFromInt(fib_counts[j])) - mean;
        const mod_diff = @as(f64, @floatFromInt(mod_counts[j])) - mean;
        fib_var += fib_diff * fib_diff;
        mod_var += mod_diff * mod_diff;
    }

    // Fibonacci should have lower or similar variance
    try std.testing.expect(fib_var <= mod_var * 2);
}

test "golden section search quadratic" {
    const f = struct {
        fn call(x: f64) f64 {
            return x * x;
        }
    }.call;
    const result = goldenSectionSearch(&f, -10.0, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(0.0, result, 0.001);
}

test "golden section search shifted" {
    const f = struct {
        fn call(x: f64) f64 {
            return (x - 3.0) * (x - 3.0);
        }
    }.call;
    const result = goldenSectionSearch(&f, 0.0, 10.0, 0.01);
    try std.testing.expectApproxEqAbs(3.0, result, 0.01);
}

test "golden section convergence rate" {
    const f = struct {
        fn call(x: f64) f64 {
            return x * x;
        }
    }.call;
    const result = goldenSectionSearchBounded(&f, -10.0, 10.0, 0.001, 100);

    // Golden section should converge in O(log(1/ε)) iterations
    // For interval 20 and tolerance 0.001, expect ~25 iterations
    try std.testing.expect(result.iterations < 30);
    try std.testing.expectApproxEqAbs(0.0, result.result, 0.001);
}

test "lucas numbers" {
    try std.testing.expectEqual(@as(u64, 2), lucas(0));
    try std.testing.expectEqual(@as(u64, 1), lucas(1));
    try std.testing.expectEqual(@as(u64, 3), lucas(2));
    try std.testing.expectEqual(@as(u64, 4), lucas(3));
    try std.testing.expectEqual(@as(u64, 7), lucas(4));
    try std.testing.expectEqual(@as(u64, 11), lucas(5));
    try std.testing.expectEqual(@as(u64, 123), lucas(10));
}

test "fibonacci numbers" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(2));
    try std.testing.expectEqual(@as(u64, 2), fibonacci(3));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "lucas fibonacci relation" {
    // L(n) = F(n-1) + F(n+1)
    for (1..10) |n| {
        const l = lucas(@intCast(n));
        const f_prev = fibonacci(@intCast(n - 1));
        const f_next = fibonacci(@intCast(n + 1));
        try std.testing.expectEqual(l, f_prev + f_next);
    }
}

test "golden identity equals 3" {
    const result = goldenIdentity();
    try std.testing.expectApproxEqAbs(3.0, result, 1e-10);
}

test "verify golden identity" {
    try std.testing.expect(verifyGoldenIdentity(1e-10));
}

test "binet formula accuracy" {
    // Binet's formula should be accurate for small n
    for (0..20) |n| {
        const exact = fibonacci(@intCast(n));
        const binet = fibonacciBinet(@intCast(n));
        const diff = @abs(@as(f64, @floatFromInt(exact)) - binet);
        try std.testing.expect(diff < 0.5);
    }
}

test "constants are correct" {
    // φ² = φ + 1
    const phi_sq = Constants.PHI * Constants.PHI;
    try std.testing.expectApproxEqAbs(Constants.PHI + 1.0, phi_sq, 1e-10);

    // 1/φ = φ - 1
    try std.testing.expectApproxEqAbs(Constants.PHI - 1.0, 1.0 / Constants.PHI, 1e-10);

    // PHI_INV = 1/φ
    try std.testing.expectApproxEqAbs(1.0 / Constants.PHI, Constants.PHI_INV, 1e-10);
}
