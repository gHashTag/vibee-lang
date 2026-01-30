// SIMD Ternary Operations
// Vectorized balanced ternary arithmetic for 32 trytes in parallel
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD VECTOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

// 32-byte vector for AVX2 (or 16-byte for SSE)
pub const Vec32i8 = @Vector(32, i8);
pub const Vec16i8 = @Vector(16, i8);
pub const Vec32i16 = @Vector(32, i16);
pub const Vec16i16 = @Vector(16, i16);
pub const Vec32bool = @Vector(32, bool);
pub const Vec16bool = @Vector(16, bool);

// Tryte range constants
pub const TRYTE_MIN: i8 = -13;
pub const TRYTE_MAX: i8 = 13;
pub const TRYTE_RANGE: i8 = 27;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD WRAP-AROUND (Balanced Ternary)
// ═══════════════════════════════════════════════════════════════════════════════

/// Wrap 32 i16 values to tryte range (-13..+13) using SIMD
/// This is the core operation for balanced ternary arithmetic
pub fn simdWrapTryte32(values: Vec32i16) Vec32i8 {
    // Step 1: Add 13 to shift range from -26..+26 to -13..+39
    const shifted = values + @as(Vec32i16, @splat(13));
    
    // Step 2: Modulo 27 using multiplication trick
    // For small values, we can use conditional subtraction
    var result = shifted;
    
    // Subtract 27 where value >= 27
    const high_mask = result >= @as(Vec32i16, @splat(27));
    result = @select(i16, high_mask, result - @as(Vec32i16, @splat(27)), result);
    
    // Add 27 where value < 0
    const low_mask = result < @as(Vec32i16, @splat(0));
    result = @select(i16, low_mask, result + @as(Vec32i16, @splat(27)), result);
    
    // Step 3: Subtract 13 to shift back to -13..+13
    const final = result - @as(Vec32i16, @splat(13));
    
    // Step 4: Truncate to i8
    var output: Vec32i8 = undefined;
    inline for (0..32) |i| {
        output[i] = @intCast(final[i]);
    }
    return output;
}

/// Wrap 16 i16 values to tryte range (for SSE)
pub fn simdWrapTryte16(values: Vec16i16) Vec16i8 {
    const shifted = values + @as(Vec16i16, @splat(13));
    var result = shifted;
    
    const high_mask = result >= @as(Vec16i16, @splat(27));
    result = @select(i16, high_mask, result - @as(Vec16i16, @splat(27)), result);
    
    const low_mask = result < @as(Vec16i16, @splat(0));
    result = @select(i16, low_mask, result + @as(Vec16i16, @splat(27)), result);
    
    const final = result - @as(Vec16i16, @splat(13));
    
    var output: Vec16i8 = undefined;
    inline for (0..16) |i| {
        output[i] = @intCast(final[i]);
    }
    return output;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD TRYTE ADDITION
// ═══════════════════════════════════════════════════════════════════════════════

/// Add two arrays of 32 trytes using SIMD
pub fn simdTryteAdd32(a: Vec32i8, b: Vec32i8) Vec32i8 {
    // Widen to i16 for addition (prevent overflow)
    var a_wide: Vec32i16 = undefined;
    var b_wide: Vec32i16 = undefined;
    inline for (0..32) |i| {
        a_wide[i] = @as(i16, a[i]);
        b_wide[i] = @as(i16, b[i]);
    }
    
    // Add
    const sum = a_wide + b_wide;
    
    // Wrap to tryte range
    return simdWrapTryte32(sum);
}

/// Add two arrays of 16 trytes using SIMD (SSE)
pub fn simdTryteAdd16(a: Vec16i8, b: Vec16i8) Vec16i8 {
    var a_wide: Vec16i16 = undefined;
    var b_wide: Vec16i16 = undefined;
    inline for (0..16) |i| {
        a_wide[i] = @as(i16, a[i]);
        b_wide[i] = @as(i16, b[i]);
    }
    
    const sum = a_wide + b_wide;
    return simdWrapTryte16(sum);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD TRYTE SUBTRACTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Subtract two arrays of 32 trytes using SIMD
pub fn simdTryteSub32(a: Vec32i8, b: Vec32i8) Vec32i8 {
    var a_wide: Vec32i16 = undefined;
    var b_wide: Vec32i16 = undefined;
    inline for (0..32) |i| {
        a_wide[i] = @as(i16, a[i]);
        b_wide[i] = @as(i16, b[i]);
    }
    
    const diff = a_wide - b_wide;
    return simdWrapTryte32(diff);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD TRYTE COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

/// Compare 32 trytes: a < b (returns bool vector)
pub fn simdTryteLt32(a: Vec32i8, b: Vec32i8) Vec32bool {
    return a < b;
}

/// Compare 32 trytes: a == b (returns bool vector)
pub fn simdTryteEq32(a: Vec32i8, b: Vec32i8) Vec32bool {
    return a == b;
}

/// Compare 32 trytes: a > b (returns bool vector)
pub fn simdTryteGt32(a: Vec32i8, b: Vec32i8) Vec32bool {
    return a > b;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD TRYTE REDUCTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Sum all 32 trytes (horizontal reduction)
pub fn simdTryteSum32(values: Vec32i8) i8 {
    var sum: i16 = 0;
    inline for (0..32) |i| {
        sum += @as(i16, values[i]);
    }
    // Wrap result to tryte range
    while (sum > 13) sum -= 27;
    while (sum < -13) sum += 27;
    return @intCast(sum);
}

/// Find maximum tryte in 32 values
pub fn simdTryteMax32(values: Vec32i8) i8 {
    return @reduce(.Max, values);
}

/// Find minimum tryte in 32 values
pub fn simdTryteMin32(values: Vec32i8) i8 {
    return @reduce(.Min, values);
}

/// Count how many comparisons are true
pub fn simdCountTrue32(mask: Vec32bool) u32 {
    return @popCount(@as(u32, @bitCast(mask)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD BATCH OPERATIONS (for arrays)
// ═══════════════════════════════════════════════════════════════════════════════

/// Add two tryte arrays of any length using SIMD
pub fn batchTryteAdd(a: []const i8, b: []const i8, result: []i8) void {
    const len = @min(a.len, @min(b.len, result.len));
    var i: usize = 0;
    
    // Process 32 elements at a time
    while (i + 32 <= len) : (i += 32) {
        const va: Vec32i8 = a[i..][0..32].*;
        const vb: Vec32i8 = b[i..][0..32].*;
        const vr = simdTryteAdd32(va, vb);
        result[i..][0..32].* = vr;
    }
    
    // Process 16 elements at a time
    while (i + 16 <= len) : (i += 16) {
        const va: Vec16i8 = a[i..][0..16].*;
        const vb: Vec16i8 = b[i..][0..16].*;
        const vr = simdTryteAdd16(va, vb);
        result[i..][0..16].* = vr;
    }
    
    // Scalar fallback for remaining elements
    while (i < len) : (i += 1) {
        var sum: i16 = @as(i16, a[i]) + @as(i16, b[i]);
        while (sum > 13) sum -= 27;
        while (sum < -13) sum += 27;
        result[i] = @intCast(sum);
    }
}

/// Sum all trytes in an array using SIMD
pub fn batchTryteSum(values: []const i8) i8 {
    var total: i32 = 0;
    var i: usize = 0;
    
    // Process 32 elements at a time
    while (i + 32 <= values.len) : (i += 32) {
        const v: Vec32i8 = values[i..][0..32].*;
        // Horizontal sum
        inline for (0..32) |j| {
            total += @as(i32, v[j]);
        }
    }
    
    // Scalar fallback
    while (i < values.len) : (i += 1) {
        total += @as(i32, values[i]);
    }
    
    // Wrap to tryte range
    const result: i32 = @mod(total + 13, 27) - 13;
    return @intCast(result);
}

/// Find max tryte in array using SIMD
pub fn batchTryteMax(values: []const i8) i8 {
    if (values.len == 0) return TRYTE_MIN;
    
    var max_val: i8 = TRYTE_MIN;
    var i: usize = 0;
    
    // Process 32 elements at a time
    while (i + 32 <= values.len) : (i += 32) {
        const v: Vec32i8 = values[i..][0..32].*;
        const chunk_max = simdTryteMax32(v);
        if (chunk_max > max_val) max_val = chunk_max;
    }
    
    // Scalar fallback
    while (i < values.len) : (i += 1) {
        if (values[i] > max_val) max_val = values[i];
    }
    
    return max_val;
}

/// Find min tryte in array using SIMD
pub fn batchTryteMin(values: []const i8) i8 {
    if (values.len == 0) return TRYTE_MAX;
    
    var min_val: i8 = TRYTE_MAX;
    var i: usize = 0;
    
    // Process 32 elements at a time
    while (i + 32 <= values.len) : (i += 32) {
        const v: Vec32i8 = values[i..][0..32].*;
        const chunk_min = simdTryteMin32(v);
        if (chunk_min < min_val) min_val = chunk_min;
    }
    
    // Scalar fallback
    while (i < values.len) : (i += 1) {
        if (values[i] < min_val) min_val = values[i];
    }
    
    return min_val;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "simd tryte add" {
    const a: Vec32i8 = @splat(5);
    const b: Vec32i8 = @splat(3);
    const result = simdTryteAdd32(a, b);
    
    // 5 + 3 = 8
    try std.testing.expectEqual(@as(i8, 8), result[0]);
    try std.testing.expectEqual(@as(i8, 8), result[31]);
}

test "simd tryte add wrap" {
    const a: Vec32i8 = @splat(10);
    const b: Vec32i8 = @splat(10);
    const result = simdTryteAdd32(a, b);
    
    // 10 + 10 = 20, wraps to 20 - 27 = -7
    try std.testing.expectEqual(@as(i8, -7), result[0]);
}

test "simd tryte sum" {
    var values: Vec32i8 = undefined;
    inline for (0..32) |i| {
        values[i] = 1; // All ones
    }
    const sum = simdTryteSum32(values);
    
    // 32 * 1 = 32, wraps to 32 - 27 = 5
    try std.testing.expectEqual(@as(i8, 5), sum);
}

test "simd tryte max" {
    var values: Vec32i8 = @splat(-5);
    values[15] = 10;
    const max = simdTryteMax32(values);
    
    try std.testing.expectEqual(@as(i8, 10), max);
}

test "batch tryte add" {
    var a = [_]i8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, -13, -12, -11 };
    var b = [_]i8{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 };
    var result: [16]i8 = undefined;
    
    batchTryteAdd(&a, &b, &result);
    
    try std.testing.expectEqual(@as(i8, 2), result[0]);
    try std.testing.expectEqual(@as(i8, 3), result[1]);
    try std.testing.expectEqual(@as(i8, -13), result[12]); // 13 + 1 = 14, wraps to -13
}
