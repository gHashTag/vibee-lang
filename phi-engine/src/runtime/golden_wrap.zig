//! VIBEE Φ-ENGINE - GOLDEN WRAP (Solution #4)
//!
//! Golden Wrap - O(1) Lookup for Balanced Ternary
//!
//! Scientific Basis: Setun (1958) - Nikolai Brusentsov
//! Balanced Ternary Computer
//!
//! Sacred Formula: 27 = 3³ = (φ² + 1/φ²)³

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

/// Trit (balanced ternary digit): {-13, -12, ..., 12, 13}
pub const Trit = i8;

/// Golden Wrap lookup table (O(1)) for range -26..+26
pub const GOLDEN_WRAP_TABLE: [53]Trit = blk: {
    var table: [53]Trit = undefined;
    for (0..53) |i| {
        const val: i16 = @as(i16, @intCast(i)) - 26;
        var wrapped: i16 = val;
        while (wrapped > 13) wrapped -= 27;
        while (wrapped < -13) wrapped += 27;
        table[i] = @intCast(wrapped);
    }
    break :blk table;
};

/// Golden Wrap - O(1) lookup for trit wrap-around
pub inline fn goldenWrap(sum: i16) Trit {
    const idx: i32 = @as(i32, sum) + 26;
    if (idx >= 0 and idx < 53) {
        return GOLDEN_WRAP_TABLE[@as(usize, idx)];
    }
    var result: i16 = sum;
    while (result > 13) result -= 27;
    while (result < -13) result += 27;
    return @intCast(result);
}

/// Trit addition with golden wrap
pub inline fn tritAdd(a: Trit, b: Trit) Trit {
    const sum: i16 = @as(i16, a) + @as(i16, b);
    return goldenWrap(sum);
}

/// Trit subtraction with golden wrap
pub inline fn tritSub(a: Trit, b: Trit) Trit {
    const diff: i16 = @as(i16, a) - @as(i16, b);
    return goldenWrap(diff);
}

/// Trit negation with golden wrap
pub inline fn tritNeg(a: Trit) Trit {
    const neg: i16 = -@as(i16, a);
    return goldenWrap(neg);
}

/// Trit max (32× parallelism ready)
pub inline fn tritMax(a: Trit, b: Trit) Trit {
    return if (a > b) a else b;
}

/// Trit min (32× parallelism ready)
pub inline fn tritMin(a: Trit, b: Trit) Trit {
    return if (a < b) a else b;
}

// ═══════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═════════════════════════════════════════════════════════════════════╝

test "Golden Wrap: identity zero" {
    const result = goldenWrap(0);
    try std.testing.expectEqual(@as(Trit, 0), result);
}

test "Golden Wrap: positive max" {
    const result = goldenWrap(13);
    try std.testing.expectEqual(@as(Trit, 13), result);
}

test "Golden Wrap: negative min" {
    const result = goldenWrap(-13);
    try std.testing.expectEqual(@as(Trit, -13), result);
}

test "Golden Wrap: wrap positive" {
    const result = goldenWrap(20);
    try std.testing.expectEqual(@as(Trit, -7), result);
}

test "Golden Wrap: wrap negative" {
    const result = goldenWrap(-20);
    try std.testing.expectEqual(@as(Trit, 7), result);
}

test "Golden Wrap: wrap multiple times" {
    const result = goldenWrap(50);
    try std.testing.expectEqual(@as(Trit, -4), result);
}

test "Golden Wrap: tritAdd identity" {
    const result = tritAdd(0, 0);
    try std.testing.expectEqual(@as(Trit, 0), result);
}

test "Golden Wrap: tritAdd positive" {
    const result = tritAdd(10, 5);
    try std.testing.expectEqual(@as(Trit, 15), result);
}

test "Golden Wrap: tritAdd wrap positive" {
    const result = tritAdd(10, 10);
    try std.testing.expectEqual(@as(Trit, -7), result);
}

test "Golden Wrap: tritSub identity" {
    const result = tritSub(10, 10);
    try std.testing.expectEqual(@as(Trit, 0), result);
}

test "Golden Wrap: tritSub positive" {
    const result = tritSub(15, 5);
    try std.testing.expectEqual(@as(Trit, 10), result);
}

test "Golden Wrap: tritSub wrap positive" {
    const result = tritSub(0, 13);
    try std.testing.expectEqual(@as(Trit, -13), result);
}

test "Golden Wrap: tritNeg identity" {
    const result = tritNeg(0);
    try std.testing.expectEqual(@as(Trit, 0), result);
}

test "Golden Wrap: tritNeg positive" {
    const result = tritNeg(10);
    try std.testing.expectEqual(@as(Trit, -10), result);
}

test "Golden Wrap: tritMax identity" {
    const result = tritMax(10, 10);
    try std.testing.expectEqual(@as(Trit, 10), result);
}

test "Golden Wrap: tritMax a > b" {
    const result = tritMax(10, 5);
    try std.testing.expectEqual(@as(Trit, 10), result);
}

test "Golden Wrap: tritMax b > a" {
    const result = tritMax(5, 10);
    try std.testing.expectEqual(@as(Trit, 10), result);
}

test "Golden Wrap: tritMin identity" {
    const result = tritMin(10, 10);
    try std.testing.expectEqual(@as(Trit, 10), result);
}

test "Golden Wrap: tritMin a > b" {
    const result = tritMin(10, 5);
    try std.testing.expectEqual(@as(Trit, 5), result);
}

test "Golden Wrap: tritMin b > a" {
    const result = tritMin(5, 10);
    try std.testing.expectEqual(@as(Trit, 5), result);
}

test "Golden Wrap: golden identity verification" {
    // φ² + 1/φ² = 3 (EXACT!)
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
