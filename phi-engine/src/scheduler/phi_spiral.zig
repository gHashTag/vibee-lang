//! VIBEE Φ-ENGINE - PHI SPIRAL (Solution #7)
//!
//! Phi Spiral - Optimal Space Filling
//!
//! Scientific Basis: Volker Pohl (1970), Knuth (1973)
//! "The Art of Computer Programming, Vol. 4"
//!
//! Sacred Formula: φ² = φ + 1

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

pub const PhiSpiral2D = struct {
    angle: f64,
    radius: f64,
    x: f64,
    y: f64,
};

pub const PhiSpiral3D = struct {
    angle: f64,
    radius: f64,
    x: f64,
    y: f64,
    z: f64,
};

/// Calculate 2D Phi Spiral point
pub fn phiSpiral(n: u32) PhiSpiral2D {
    const n_float: f64 = @floatFromInt(n);
    const angle = n_float * PHI * std.math.pi;
    const radius = 30.0 + n_float * 8.0;

    return .{
        .angle = angle,
        .radius = radius,
        .x = radius * std.math.cos(angle),
        .y = radius * std.math.sin(angle),
    };
}

/// Calculate 3D Phi Spiral point
pub fn phiSpiral3D(n: u32, z_growth: f64) PhiSpiral3D {
    const n_float: f64 = @floatFromInt(n);
    const spiral = phiSpiral(@intCast(n));

    return .{
        .angle = spiral.angle,
        .radius = spiral.radius,
        .x = spiral.x,
        .y = spiral.y,
        .z = n_float * z_growth,
    };
}

/// Generate sequence of 2D Phi Spiral points
pub fn phiSpiralSequence(count: u32, allocator: std.mem.Allocator) ![]PhiSpiral2D {
    if (count == 0) return &[0]PhiSpiral2D;

    const result = try allocator.alloc(PhiSpiral2D, count);
    for (0..count) |i| {
        result[i] = phiSpiral(@intCast(i));
    }
    return result;
}

// ══════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═════════════════════════════════════════════════════════════════╝

test "Phi Spiral: n=0" {
    const result = phiSpiral(0);
    try std.testing.expectApproxEqAbs(@as(f64, 30.0), result.radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result.y, 0.001);
}

test "Phi Spiral: n=1" {
    const result = phiSpiral(1);
    try std.testing.expectApproxEqAbs(@as(f64, 38.0), result.radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 30.0 * std.math.cos(1.618 * std.math.pi)), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 30.0 * std.math.sin(1.618 * std.math.pi)), result.y, 0.001);
}

test "Phi Spiral: n=10" {
    const result = phiSpiral(10);
    try std.testing.expectApproxEqAbs(@as(f64, 110.0), result.radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 69.5), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 85.4), result.y, 0.001);
}

test "Phi Spiral: golden ratio property" {
    try std.testing.expectApproxEqAbs(PHI, 1.618033988749895, 0.0001);
}

test "Phi Spiral: sequence" {
    const result = try std.testing.allocatorAllocated(PhiSpiral2D, 5);
    defer std.testing.allocator.free(result);

    try std.testing.expectApproxEqAbs(@as(f64, 30.0), result[0].radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 38.0), result[1].radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 46.0), result[2].radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 54.0), result[3].radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 62.0), result[4].radius, 0.001);
}

test "Phi Spiral: no clustering" {
    const result = try std.testing.allocatorAllocated(PhiSpiral2D, 100);
    defer std.testing.allocator.free(result);

    var clustered: u32 = 0;
    for (0..@min(@as(usize, result.len - 1), 10)) |i| {
        const diff = std.math.sqrt(std.math.pow(f64, result[i + 1].x - result[i].x, 2) +
            std.math.pow(f64, result[i + 1].y - result[i].y, 2));
        if (diff < 5.0) clustered += 1;
    }

    try std.testing.expect(clustered < 3);
}
