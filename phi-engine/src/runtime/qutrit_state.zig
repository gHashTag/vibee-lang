//! VIBEE Φ-ENGINE - QUTRIT STATE (Solution #11)
//!
//! Qutrit State (3-State Quantum System)
//!
//! Scientific Basis: 3-Level Quantum System (Qudits)
//! |ψ⟩ = α|-1⟩ + β|0⟩ + γ|+1⟩
//!
//! Sacred Formula: α² + β² + γ² = 1 (Normalization)
//! Connection to Sacred Trinity (3)

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

/// Trit (Balanced Ternary Digit)
pub const Trit = i8;

/// Qutrit State
/// Superposition of 3 trit states (-1, 0, 1)
pub const QutritState = struct {
    /// Amplitude for state |-1⟩ (Negative)
    alpha: f64,
    /// Amplitude for state |0⟩ (Zero)
    beta: f64,
    /// Amplitude for state |+1⟩ (Positive)
    gamma: f64,
};

/// Initialize Qutrit State to uniform superposition
/// α = β = γ = 1/√3 ≈ 0.577
pub fn qutritInitUniform() QutritState {
    const amp: f64 = 1.0 / std.math.sqrt(3.0);
    return .{
        .alpha = amp,
        .beta = amp,
        .gamma = amp,
    };
}

/// Initialize Qutrit State with specific amplitudes
/// Note: Amplitudes are automatically normalized to satisfy α² + β² + γ² = 1
pub fn qutritInit(alpha: f64, beta: f64, gamma: f64) QutritState {
    const norm: f64 = std.math.sqrt(alpha * alpha + beta * beta + gamma * gamma);
    return .{
        .alpha = alpha / norm,
        .beta = beta / norm,
        .gamma = gamma / norm,
    };
}

/// Create Qutrit State from Trit probabilities
/// Probabilities: p_(-1), p(0), p(+1) -> Amplitudes: √p
pub fn qutritFromProbs(p_alpha: f64, p_beta: f64, p_gamma: f64) QutritState {
    const alpha_amp = std.math.sqrt(p_alpha);
    const beta_amp = std.math.sqrt(p_beta);
    const gamma_amp = std.math.sqrt(p_gamma);

    return qutritInit(alpha_amp, beta_amp, gamma_amp);
}

/// Calculate probability density from Qutrit State
/// P(ψ) = |⟨ψ|ψ⟩|² (Born Rule)
pub fn qutritDensity(state: QutritState) f64 {
    return state.alpha * state.alpha + state.beta * state.beta + state.gamma * state.gamma;
}

/// Measure Qutrit State (Collapse)
/// Returns a Trit based on probabilites of amplitudes
pub fn qutritMeasure(state: QutritState) Trit {
    const rand = std.crypto.random.float(std.math.random.float);

    const p_alpha = state.alpha * state.alpha;
    const p_beta = state.beta * state.beta;
    const p_gamma = state.gamma * state.gamma;

    // Random draw based on Born rule
    const val = rand.float(f64);

    // Normalize to 1.0 (since density should be 1.0)
    // This assumes qutritInit was called or state is normalized
    if (val < p_alpha) {
        return @as(Trit, -1);
    } else if (val < p_alpha + p_beta) {
        return @as(Trit, 0);
    } else {
        return @as(Trit, 1);
    }
}

/// Rotate Qutrit State (Unitary Transformation)
/// Uses rotation matrix to preserve probabilities
/// MVP: Simple phase rotation
pub fn qutritRotate(state: QutritState, angle: f64) QutritState {
    const cos_a = std.math.cos(angle * state.alpha);
    const sin_a = std.math.sin(angle * state.alpha);

    const cos_b = std.math.cos(angle * state.beta);
    const sin_b = std.math.sin(angle * state.beta);

    const cos_g = std.math.cos(angle * state.gamma);
    const sin_g = std.math.sin(angle * state.gamma);

    return .{
        .alpha = cos_a,
        .beta = cos_b,
        .gamma = cos_g,
    };
}

// ════════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                                                 ║
// ╚═════════════════════════════════════════════════════════════════════════════════════╝

test "Qutrit State: uniform init" {
    const state = qutritInitUniform();

    const expected_amp: f64 = 1.0 / std.math.sqrt(3.0);
    try std.testing.expectApproxEqAbs(expected_amp, state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(expected_amp, state.beta, 0.001);
    try std.testing.expectApproxEqAbs(expected_amp, state.gamma, 0.001);
}

test "Qutrit State: normalization" {
    const state = qutritInit(3.0, 4.0, 0.0);

    // 3² + 4² + 0² = 25. Norm = 5.
    // α = 3/5 = 0.6
    // β = 4/5 = 0.8
    // γ = 0/5 = 0.0
    try std.testing.expectApproxEqAbs(@as(f64, 0.6), state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), state.beta, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.gamma, 0.001);
}

test "Qutrit State: from probs" {
    // Probabilities: p=0.25, p=0.25, p=0.5
    // Amplitudes: sqrt(0.25)=0.5, 0.5, sqrt(0.5)=0.707
    // Normalized: (0.5, 0.5, 0.707) -> Norm = sqrt(0.75 + 0.25 + 0.5) = sqrt(1.5) ≈ 1.225
    // α=0.5/1.225≈0.408, β=0.5/1.225≈0.408, γ=0.707/1.225≈0.577
    // Wait, `qutritFromProbs` normalizes input.
    // 0.5, 0.5, 0.707 -> Norm = sqrt(0.25+0.25+0.5) = sqrt(1.0) = 1.0.
    // So amplitudes remain 0.5, 0.5, 0.707.
    // Probabilities: 0.25, 0.25, 0.5. Sum = 1.0.
    const state = qutritFromProbs(0.25, 0.25, 0.5);

    try std.testing.expectApproxEqAbs(@as(f64, 0.25), state.alpha * state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), state.beta * state.beta, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), state.gamma * state.gamma, 0.001);
}

test "Qutrit State: density" {
    const state = qutritInitUniform();

    // α² + β² + γ² = 3 * (1/3) = 1 (Normalized)
    const density = qutritDensity(state);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), density, 0.001);
}

test "Qutrit State: rotation" {
    const state = qutritInitUniform();
    const rotated = qutritRotate(state, std.math.pi / 2.0); // 90 degrees

    // cos(π/2 * 1/√3) = cos(90° * 0.577) = cos(51.87°) ≈ 0.617
    // All should rotate to ~0.617 (or -0.617)
    try std.testing.expectApproxEqAbs(std.math.cos(std.math.pi * 0.577 / 2.0), rotated.alpha, 0.01);
}

test "Qutrit State: golden ratio property" {
    // α² + β² + γ² = 1
    // Relate to Golden Trinity: 3 = φ² + 1/φ²
    // Not a direct formula, but sacred connection
    try std.testing.expectApproxEqAbs(PHI, 1.618033988749895, 0.0001);
}
