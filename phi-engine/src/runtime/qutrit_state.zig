//! VIBEE Φ-ENGINE - QUTRIT STATE (Solution #11)
//!
//! Qutrit State - Quantum-inspired 3-State System

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

pub const QutritState = struct {
    alpha: f64 = 1.0,
    beta: f64 = 0.0,
    gamma: f64 = 0.0,
};

pub const Probabilities = struct {
    p0: f64,
    p1: f64,
    p2: f64,
};

pub fn init(alpha: f64, beta: f64, gamma: f64) QutritState {
    const norm = std.math.sqrt(alpha * alpha + beta * beta + gamma * gamma);
    if (norm == 0) return QutritState{ .alpha = 1, .beta = 0, .gamma = 0 };

    return .{
        .alpha = alpha / norm,
        .beta = beta / norm,
        .gamma = gamma / norm,
    };
}

pub fn measure(state: *const QutritState, random: f64) u2 {
    const p0 = state.alpha * state.alpha;
    const p1 = state.beta * state.beta;

    if (random < p0) return 0;
    if (random < p0 + p1) return 1;
    return 2;
}

pub fn probabilities(state: *const QutritState) Probabilities {
    return .{
        .p0 = state.alpha * state.alpha,
        .p1 = state.beta * state.beta,
        .p2 = state.gamma * state.gamma,
    };
}

// ════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═══════════════════════════════════════════════════════════════════╝

test "Qutrit: init zero state" {
    const state = init(1.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.beta, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.gamma, 0.001);
}

test "Qutrit: init one state" {
    const state = init(0.0, 1.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.beta, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.gamma, 0.001);
}

test "Qutrit: init two state" {
    const state = init(0.0, 0.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.beta, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.gamma, 0.001);
}

test "Qutrit: init superposition" {
    const state = init(0.577, 0.577, 0.577);
    try std.testing.expectApproxEqAbs(@as(f64, 0.577), state.alpha, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.577), state.beta, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.577), state.gamma, 0.001);
}

test "Qutrit: measure zero state" {
    const state = init(1.0, 0.0, 0.0);
    const result = measure(&state, 0.5);
    try std.testing.expectEqual(@as(u2, 0), result);
}

test "Qutrit: measure one state" {
    const state = init(0.0, 1.0, 0.0);
    const result = measure(&state, 0.5);
    try std.testing.expectEqual(@as(u2, 1), result);
}

test "Qutrit: measure two state" {
    const state = init(0.0, 0.0, 1.0);
    const result = measure(&state, 0.5);
    try std.testing.expectEqual(@as(u2, 2), result);
}

test "Qutrit: measure superposition" {
    const state = init(0.577, 0.577, 0.577);
    const result = measure(&state, 0.333);
    try std.testing.expect(result < 3);
}

test "Qutrit: probabilities zero" {
    const state = init(1.0, 0.0, 0.0);
    const probs = probabilities(&state);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), probs.p0, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), probs.p1, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), probs.p2, 0.001);
}

test "Qutrit: probabilities superposition" {
    const state = init(0.577, 0.577, 0.577);
    const probs = probabilities(&state);
    try std.testing.expectApproxEqAbs(@as(f64, 0.333), probs.p0, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.333), probs.p1, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.333), probs.p2, 0.001);
}

test "Qutrit: golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
