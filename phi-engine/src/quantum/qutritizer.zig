//! VIBEE QUANTUM TRIT-CODE ENGINE - QUTRITIZER (MVP Week 2)
//!
//! Qutritizer: Convert Ternary Code (Trits) into Quantum Amplitudes (Qutrits)
//!
//! Concept: "Trits are Superposition"
//! Instead of just [-1, 0, 1], we have Amplitudes (α, β, γ).
//!
//! Connection to VIBEE Phi-Engine:
//! - Uses `Qutrit State` (Solution #11) for 3 amplitudes.
//! - Connection: ψ = α|−1⟩ + β|0⟩ + γ|+1⟩

const std = @import("std");

/// Trit (Balanced Ternary Digit): {-13, -12, ..., 12, 13}
/// (Using larger range for MVP - not just -1, 0, 1)
pub const Trit = i8;

/// Qutrit State (3 Amplitudes: α, β, γ)
/// Represents quantum superposition of 3 trit states (-1, 0, 1)
pub const QutritState = struct {
    /// Amplitude for state |-1⟩ (Negative)
    alpha: f64,
    /// Amplitude for state |0⟩ (Zero)
    beta: f64,
    /// Amplitude for state |+1⟩ (Positive)
    gamma: f64,
};

/// Convert trits to qutrit state
/// Input: []Trit (e.g., [-1, 0, 1])
/// Output: QutritState { α, β, γ }
/// (Simple MVP implementation: Bias amplitudes based on trit frequency)
pub fn tritsToQutrit(trits: []const Trit) QutritState {
    // Initialize with uniform superposition
    // α = β = γ = 1/√3 ≈ 0.577
    const uniform_amp: f64 = 1.0 / std.math.sqrt(3.0);
    var alpha: f64 = uniform_amp;
    var beta: f64 = uniform_amp;
    var gamma: f64 = uniform_amp;

    // Count trit frequencies
    var count_minus: i64 = 0;
    var count_zero: i64 = 0;
    var count_plus: i64 = 0;

    for (trits) |t| {
        // Use simple threshold for MVP (0 -> zero, >0 -> plus, <0 -> minus)
        if (t > 0) {
            count_plus += 1;
        } else if (t < 0) {
            count_minus += 1;
        } else {
            count_zero += 1;
        }
    }

    const total: i64 = count_minus + count_zero + count_plus;

    // Update amplitudes based on classical trit frequencies
    // (This is a "Code biasing" approach for MVP)
    if (total > 0) {
        const bias: f64 = 0.1; // 10% bias for MVP

        // Bias amplitudes towards most frequent trit type
        // (To simulate: "Code is mostly this trit, so measure this with higher prob")
        if (count_minus > count_zero and count_minus > count_plus) {
            alpha += bias; // Boost |-1⟩
        } else if (count_zero > count_minus and count_zero > count_plus) {
            beta += bias; // Boost |0⟩
        } else if (count_plus > count_minus and count_plus > count_zero) {
            gamma += bias; // Boost |+1⟩
        }

        // Normalize (ensure |α|² + |β|² + |γ|² = 1)
        const norm: f64 = std.math.sqrt(alpha * alpha + beta * beta + gamma * gamma);
        if (norm > 0.0) {
            alpha /= norm;
            beta /= norm;
            gamma /= norm;
        }
    }

    return .{ .alpha = alpha, .beta = beta, .gamma = gamma };
}

// ════════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS (MVP Week 2)                          ║
// ╚═══════════════════════════════════════════════════════════════════════════════════╝

test "Qutritizer: tritsToQutrit uniform" {
    // Empty array -> Uniform superposition (α = β = γ)
    const trits = [_]Trit{};
    const state = tritsToQutrit(&trits);

    const expected_amp: f64 = 1.0 / std.math.sqrt(3.0);
    try std.testing.expectApproxEqAbs(expected_amp, state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(expected_amp, state.beta, 0.001);
    try std.testing.expectApproxEqAbs(expected_amp, state.gamma, 0.001);
}

test "Qutritizer: tritsToQutrit all minus" {
    // All -1 -> Bias towards α
    const trits = [_]Trit{ -1, -1, -1 };
    const state = tritsToQutrit(&trits);

    // α should be larger than β and γ
    try std.testing.expect(state.alpha > state.beta);
    try std.testing.expect(state.alpha > state.gamma);

    // But all should be non-zero (superposition exists)
    try std.testing.expect(state.alpha > 0.0);
    try std.testing.expect(state.beta > 0.0);
    try std.testing.expect(state.gamma > 0.0);
}

test "Qutritizer: tritsToQutrit all zero" {
    // All 0 -> Bias towards β
    const trits = [_]Trit{ 0, 0, 0 };
    const state = tritsToQutrit(&trits);

    // β should be larger than α and γ
    try std.testing.expect(state.beta > state.alpha);
    try std.testing.expect(state.beta > state.gamma);

    // All should be non-zero
    try std.testing.expect(state.alpha > 0.0);
    try std.testing.expect(state.beta > 0.0);
    try std.testing.expect(state.gamma > 0.0);
}

test "Qutritizer: tritsToQutrit all plus" {
    // All 1 -> Bias towards γ
    const trits = [_]Trit{ 1, 1, 1 };
    const state = tritsToQutrit(&trits);

    // γ should be larger than α and β
    try std.testing.expect(state.gamma > state.alpha);
    try std.testing.expect(state.gamma > state.beta);

    // All should be non-zero
    try std.testing.expect(state.alpha > 0.0);
    try std.testing.expect(state.beta > 0.0);
    try std.testing.expect(state.gamma > 0.0);
}

test "Qutritizer: tritsToQutrit mixed" {
    // Mixed -> Balanced amplitudes (approx)
    const trits = [_]Trit{ -1, 0, 1 };
    const state = tritsToQutrit(&trits);

    // Amplitudes should be normalized (|α|² + |β|² + |γ|² ≈ 1)
    const norm: f64 = std.math.sqrt(state.alpha * state.alpha + state.beta * state.beta + state.gamma * state.gamma);
    try std.testing.expectApproxEqAbs(1.0, norm, 0.001);
}
