// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZED SIMD TERNARY OPERATIONS
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// 
// KEY OPTIMIZATIONS:
// 1. Avoid widening when possible (stay in i8)
// 2. Use lookup tables for wrap-around
// 3. Minimize SIMD operations per tryte operation
// 4. Use @Vector intrinsics directly
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// SIMD vector types
pub const Vec32i8 = @Vector(32, i8);
pub const Vec32i16 = @Vector(32, i16);
pub const Vec32u8 = @Vector(32, u8);
pub const Vec64i8 = @Vector(64, i8);

// Constants
pub const TRYTE_MIN: i8 = -13;
pub const TRYTE_MAX: i8 = 13;
pub const TRYTE_RANGE: i8 = 27;

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION 1: PRECOMPUTED WRAP TABLE
// Instead of SIMD operations, use lookup table for wrap-around
// ═══════════════════════════════════════════════════════════════════════════════

/// Precomputed wrap table for range -26..+26 → -13..+13
/// Index = value + 26, Result = wrapped value
pub const WRAP_TABLE: [53]i8 = blk: {
    var table: [53]i8 = undefined;
    for (0..53) |i| {
        const val: i16 = @as(i16, @intCast(i)) - 26;
        var wrapped: i16 = val;
        if (wrapped > 13) wrapped -= 27;
        if (wrapped < -13) wrapped += 27;
        table[i] = @intCast(wrapped);
    }
    break :blk table;
};

/// Fast scalar wrap using lookup table
pub inline fn wrapTryteFast(sum: i16) i8 {
    // For values in -26..+26, use lookup
    const idx: i32 = @as(i32, sum) + 26;
    if (idx >= 0 and idx < 53) {
        return WRAP_TABLE[@intCast(idx)];
    }
    // Fallback for out-of-range (shouldn't happen in normal use)
    var result: i16 = sum;
    while (result > 13) result -= 27;
    while (result < -13) result += 27;
    return @intCast(result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION 2: BRANCHLESS SIMD WRAP
// Single-pass wrap using arithmetic instead of conditionals
// ═══════════════════════════════════════════════════════════════════════════════

/// Optimized SIMD wrap using branchless arithmetic
/// Key insight: For sum in -26..+26, we need at most one wrap
pub fn simdWrapTryte32Fast(values: Vec32i16) Vec32i8 {
    // Branchless wrap: use sign-based selection
    // if (v > 13) v -= 27
    // if (v < -13) v += 27
    
    const thirteen: Vec32i16 = @splat(13);
    const neg_thirteen: Vec32i16 = @splat(-13);
    const twenty_seven: Vec32i16 = @splat(27);
    
    // Compute masks
    const too_high = values > thirteen;
    const too_low = values < neg_thirteen;
    
    // Apply corrections using select (branchless)
    var result = @select(i16, too_high, values - twenty_seven, values);
    result = @select(i16, too_low, result + twenty_seven, result);
    
    // Direct truncation using @intCast on each element
    // This is the bottleneck - Zig doesn't have direct vector truncation
    var output: Vec32i8 = undefined;
    inline for (0..32) |i| {
        output[i] = @intCast(result[i]);
    }
    return output;
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION 3: STAY IN i8 WHEN POSSIBLE
// For small values, we can avoid widening entirely
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if all values are in safe range for i8 addition
/// Safe range: -6..+6 (so sum is -12..+12, within tryte range)
pub fn simdIsSafeRange(a: Vec32i8, b: Vec32i8) bool {
    const six: Vec32i8 = @splat(6);
    const neg_six: Vec32i8 = @splat(-6);
    
    const a_ge = a >= neg_six;
    const a_le = a <= six;
    const b_ge = b >= neg_six;
    const b_le = b <= six;
    
    // Check if all elements are safe using @reduce
    const a_safe = @reduce(.And, a_ge) and @reduce(.And, a_le);
    const b_safe = @reduce(.And, b_ge) and @reduce(.And, b_le);
    
    return a_safe and b_safe;
}

/// Fast tryte add for safe range (no wrap needed)
pub inline fn simdTryteAddSafe(a: Vec32i8, b: Vec32i8) Vec32i8 {
    return a + b; // Direct add, no wrap needed!
}

/// Optimized tryte add with fast path
pub fn simdTryteAdd32Fast(a: Vec32i8, b: Vec32i8) Vec32i8 {
    // Fast path: if both operands are in safe range, skip wrap
    if (simdIsSafeRange(a, b)) {
        return simdTryteAddSafe(a, b);
    }
    
    // Slow path: widen, add, wrap
    var a_wide: Vec32i16 = undefined;
    var b_wide: Vec32i16 = undefined;
    inline for (0..32) |i| {
        a_wide[i] = a[i];
        b_wide[i] = b[i];
    }
    return simdWrapTryte32Fast(a_wide + b_wide);
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION 4: BATCH PROCESSING
// Process multiple operations before wrapping
// ═══════════════════════════════════════════════════════════════════════════════

/// Accumulator for batch tryte operations
/// Stays in i16 to avoid repeated wrap operations
pub const TryteAccumulator = struct {
    values: Vec32i16,
    
    pub fn init() TryteAccumulator {
        return .{ .values = @splat(0) };
    }
    
    pub fn initFrom(trytes: Vec32i8) TryteAccumulator {
        var wide: Vec32i16 = undefined;
        inline for (0..32) |i| {
            wide[i] = trytes[i];
        }
        return .{ .values = wide };
    }
    
    /// Add trytes without wrapping (accumulate)
    pub fn add(self: *TryteAccumulator, trytes: Vec32i8) void {
        var wide: Vec32i16 = undefined;
        inline for (0..32) |i| {
            wide[i] = trytes[i];
        }
        self.values += wide;
    }
    
    /// Subtract trytes without wrapping (accumulate)
    pub fn sub(self: *TryteAccumulator, trytes: Vec32i8) void {
        var wide: Vec32i16 = undefined;
        inline for (0..32) |i| {
            wide[i] = trytes[i];
        }
        self.values -= wide;
    }
    
    /// Finalize: wrap accumulated values to tryte range
    pub fn finalize(self: TryteAccumulator) Vec32i8 {
        return simdWrapTryte32Fast(self.values);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION 5: MULTIPLICATION TRICK FOR MODULO
// x mod 27 ≈ x - 27 * floor(x * M / 2^N) where M = ceil(2^N / 27)
// ═══════════════════════════════════════════════════════════════════════════════

/// Magic number for division by 27: ceil(2^16 / 27) = 2427
const MAGIC_DIV_27: i32 = 2427;

/// Fast modulo 27 using multiplication
pub inline fn fastMod27(x: i16) i8 {
    // x mod 27 = x - 27 * floor(x / 27)
    // floor(x / 27) ≈ (x * 2427) >> 16
    const x32: i32 = x;
    const q = @divTrunc(x32 * MAGIC_DIV_27, 65536);
    const r = x32 - q * 27;
    return @intCast(r - 13); // Shift to balanced range
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION 6: PARALLEL TRIT OPERATIONS (stay in i8)
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit NOT: negate each element
pub inline fn simdTritNot32(t: Vec32i8) Vec32i8 {
    return -t; // Simple negation, no wrap needed
}

/// Trit AND: min(a, b) - branchless
pub fn simdTritAnd32(a: Vec32i8, b: Vec32i8) Vec32i8 {
    return @min(a, b);
}

/// Trit OR: max(a, b) - branchless
pub fn simdTritOr32(a: Vec32i8, b: Vec32i8) Vec32i8 {
    return @max(a, b);
}

/// Trit comparison: returns -1, 0, or +1 for each pair
pub fn simdTritCmp32(a: Vec32i8, b: Vec32i8) Vec32i8 {
    const lt = a < b;
    const gt = a > b;
    const lt_val: Vec32i8 = @select(i8, lt, @as(Vec32i8, @splat(-1)), @as(Vec32i8, @splat(0)));
    const gt_val: Vec32i8 = @select(i8, gt, @as(Vec32i8, @splat(1)), @as(Vec32i8, @splat(0)));
    return lt_val + gt_val;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "wrap table correctness" {
    // Test all values in range
    for (0..53) |i| {
        const val: i16 = @as(i16, @intCast(i)) - 26;
        const wrapped = wrapTryteFast(val);
        try std.testing.expect(wrapped >= -13 and wrapped <= 13);
        
        // Verify wrap is correct
        var expected: i16 = val;
        if (expected > 13) expected -= 27;
        if (expected < -13) expected += 27;
        try std.testing.expectEqual(@as(i8, @intCast(expected)), wrapped);
    }
}

test "simd wrap fast correctness" {
    const values: Vec32i16 = .{
        -26, -20, -14, -13, -12, -6, 0, 6, 12, 13, 14, 20, 26,
        -26, -20, -14, -13, -12, -6, 0, 6, 12, 13, 14, 20, 26,
        0, 0, 0, 0, 0, 0,
    };
    const result = simdWrapTryte32Fast(values);
    
    // Check each result
    inline for (0..32) |i| {
        try std.testing.expect(result[i] >= -13 and result[i] <= 13);
    }
}

test "simd tryte add fast" {
    const a: Vec32i8 = @splat(5);
    const b: Vec32i8 = @splat(10);
    const result = simdTryteAdd32Fast(a, b);
    
    // 5 + 10 = 15 → 15 - 27 = -12
    inline for (0..32) |i| {
        try std.testing.expectEqual(@as(i8, -12), result[i]);
    }
}

test "simd safe range" {
    const safe_a: Vec32i8 = @splat(3);
    const safe_b: Vec32i8 = @splat(-3);
    try std.testing.expect(simdIsSafeRange(safe_a, safe_b));
    
    const unsafe_a: Vec32i8 = @splat(10);
    const unsafe_b: Vec32i8 = @splat(10);
    try std.testing.expect(!simdIsSafeRange(unsafe_a, unsafe_b));
}

test "accumulator batch operations" {
    var acc = TryteAccumulator.init();
    
    const a: Vec32i8 = @splat(5);
    const b: Vec32i8 = @splat(5);
    const c: Vec32i8 = @splat(5);
    
    acc.add(a);
    acc.add(b);
    acc.add(c);
    
    const result = acc.finalize();
    // 5 + 5 + 5 = 15 → -12
    inline for (0..32) |i| {
        try std.testing.expectEqual(@as(i8, -12), result[i]);
    }
}

test "trit operations" {
    const a: Vec32i8 = @splat(1);
    const b: Vec32i8 = @splat(-1);
    
    // NOT
    const not_a = simdTritNot32(a);
    try std.testing.expectEqual(@as(i8, -1), not_a[0]);
    
    // AND (min)
    const and_ab = simdTritAnd32(a, b);
    try std.testing.expectEqual(@as(i8, -1), and_ab[0]);
    
    // OR (max)
    const or_ab = simdTritOr32(a, b);
    try std.testing.expectEqual(@as(i8, 1), or_ab[0]);
}
