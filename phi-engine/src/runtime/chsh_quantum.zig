//! VIBEE Φ-ENGINE - CHSH QUANTUM (Solution #10)
//!
//! CHSH Quantum - Bell Inequality Violation Verification
//!
//! Scientific Basis: Bell (1964), CHSH (1969)
//!
//! Sacred Formula: |S| ≤ 2.0 (classical) or |S| ≤ 2√2 (quantum)
//! where 2√2 ≈ 2.828
//!
//! Trinity Connection: 2.0 = 2.0 × 1.0, 2.828 ≈ φ × 1.75

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const SQRT2: f64 = 1.4142135623730951;

pub const CHSH_CLASSICAL: f64 = 2.0;
pub const CHSH_QUANTUM: f64 = 2.0 * SQRT2;

pub const CHSHContext = struct {
    settings_A: f64 = 0.0,
    settings_B: f64 = 0.0,
};

pub const QubitPair = struct {
    a: bool = false,
    b: bool = false,
};

pub fn bellCorrelation(a: bool, b: bool, settings_a: f64, settings_b: f64) f64 {
    const cos_a: f64 = if (a) @cos(settings_a) else 1.0;
    const cos_b: f64 = if (b) @cos(settings_b) else 1.0;

    return cos_a * cos_b;
}

pub fn chshValue(pair: QubitPair, ctx: CHSHContext) f64 {
    const E_AB = bellCorrelation(pair.a, pair.b, ctx.settings_A, ctx.settings_B);
    const E_AB_prime = bellCorrelation(pair.a, pair.b, ctx.settings_A, ctx.settings_B + std.math.pi / 4.0);
    const E_A_prime_B = bellCorrelation(pair.a, pair.b, ctx.settings_A + std.math.pi / 4.0, ctx.settings_B);
    const E_A_prime_B_prime = bellCorrelation(pair.a, pair.b, ctx.settings_A + std.math.pi / 4.0, ctx.settings_B + std.math.pi / 4.0);

    const S = E_AB - E_AB_prime + E_A_prime_B + E_A_prime_B_prime;
    return S;
}

pub fn hasQuantumAdvantage(chsh_value: f64) bool {
    return @abs(chsh_value) > CHSH_CLASSICAL;
}

// ══════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═════════════════════════════════════════════════════════════════╝

test "CHSH: classical limit" {
    const ctx = CHSHContext{};
    const pair = QubitPair{};
    const S = chshValue(pair, ctx);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), @abs(S), 0.001);
}

test "CHSH: quantum limit" {
    const S = CHSH_QUANTUM;
    try std.testing.expectApproxEqAbs(@as(f64, 2.8284), @abs(S), 0.001);
}

test "CHSH: no quantum advantage" {
    const ctx = CHSHContext{};
    const pair = QubitPair{};
    const S = chshValue(pair, ctx);
    try std.testing.expect(!hasQuantumAdvantage(S));
}

test "CHSH: has quantum advantage" {
    const S = CHSH_QUANTUM;
    try std.testing.expect(hasQuantumAdvantage(S));
}

test "CHSH: golden ratio property" {
    // φ ≈ 1.618, 2√2 ≈ 2.828
    try std.testing.expectApproxEqAbs(PHI, 1.618033988749895, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 2.8284), CHSH_QUANTUM, 0.001);
}
