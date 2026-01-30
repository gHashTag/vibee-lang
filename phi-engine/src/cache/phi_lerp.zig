//! VIBEE Φ-ENGINE - PHI LERP (Solution #6)
//!
//! Phi Lerp - Golden Interpolation for Smooth Transitions

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PHI_INV: f64 = 1.0 / PHI; // 0.618

pub inline fn phiLerp(a: f64, b: f64, t: f64) f64 {
    const phi_t: f64 = std.math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

pub const Vector2D = struct {
    x: f64,
    y: f64,
};

pub const Vector3D = struct {
    x: f64,
    y: f64,
    z: f64,
};

pub inline fn phiLerp2D(a: Vector2D, b: Vector2D, t: f64) Vector2D {
    return .{
        .x = phiLerp(a.x, b.x, t),
        .y = phiLerp(a.y, b.y, t),
    };
}

pub inline fn phiLerp3D(a: Vector3D, b: Vector3D, t: f64) Vector3D {
    return .{
        .x = phiLerp(a.x, b.x, t),
        .y = phiLerp(a.y, b.y, t),
        .z = phiLerp(a.z, b.z, t),
    };
}

// ════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═══════════════════════════════════════════════════════════════════╝

test "Phi Lerp: start" {
    const a = Vector2D{ .x = 0, .y = 0 };
    const b = Vector2D{ .x = 10, .y = 0 };
    const result = phiLerp2D(a, b, 0.0);
    try std.testing.expectEqual(@as(f64, 0.0), result.x);
    try std.testing.expectEqual(@as(f64, 0.0), result.y);
}

test "Phi Lerp: end" {
    const a = Vector2D{ .x = 0, .y = 0 };
    const b = Vector2D{ .x = 10, .y = 0 };
    const result = phiLerp2D(a, b, 1.0);
    try std.testing.expectEqual(@as(f64, 10.0), result.x);
    try std.testing.expectEqual(@as(f64, 0.0), result.y);
}

test "Phi Lerp: mid" {
    const a = Vector2D{ .x = 0, .y = 0 };
    const b = Vector2D{ .x = 10, .y = 0 };
    const result = phiLerp2D(a, b, 0.618);
    try std.testing.expectApproxEqAbs(@as(f64, 6.18), result.x, 0.01);
    try std.testing.expectEqual(@as(f64, 0.0), result.y);
}

test "Phi Lerp: smoothness" {
    const a = Vector2D{ .x = 0, .y = 0 };
    const b = Vector2D{ .x = 10, .y = 0 };
    const t_linear: f64 = 0.5;
    const t_phi: f64 = 0.5;

    const result_linear = phiLerp(a.x, b.x, t_linear);
    const result_phi = phiLerp(a.x, b.x, t_phi);

    try std.testing.expect(result_phi > result_linear);
}

test "Phi Lerp: 3D" {
    const a = Vector3D{ .x = 0, .y = 0, .z = 0 };
    const b = Vector3D{ .x = 10, .y = 10, .z = 10 };
    const result = phiLerp3D(a, b, 0.618);
    try std.testing.expectApproxEqAbs(@as(f64, 6.18), result.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 6.18), result.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 6.18), result.z, 0.01);
}

test "Phi Lerp: golden ratio property" {
    const ratio = PHI * PHI_INV;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), ratio, 0.001);
}

test "Phi Lerp: t^PHI_INV" {
    const t: f64 = 0.5;
    const phi_t = std.math.pow(f64, t, PHI_INV);
    try std.testing.expectApproxEqAbs(@as(f64, 0.653), phi_t, 0.001);
}

test "Phi Lerp: golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
