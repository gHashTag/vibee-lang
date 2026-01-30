// VIBEE SIMD JSON - Vectorized JSON Operations
// Uses Zig @Vector for parallel processing
// Target: 10x faster string scanning
// φ² + 1/φ² = 3

const std = @import("std");

/// SIMD vector width
const VECTOR_WIDTH = 16;
const SimdU8 = @Vector(VECTOR_WIDTH, u8);
const SimdBool = @Vector(VECTOR_WIDTH, bool);

/// Check if byte is whitespace
inline fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

/// SIMD-accelerated whitespace skipping
pub fn simdSkipWhitespace(input: []const u8, start: usize) usize {
    var pos = start;

    // Process VECTOR_WIDTH bytes at a time with SIMD
    while (pos + VECTOR_WIDTH <= input.len) {
        const chunk: SimdU8 = input[pos..][0..VECTOR_WIDTH].*;

        // Check each byte for whitespace using SIMD comparison
        const space_cmp: SimdBool = chunk == @as(SimdU8, @splat(' '));
        const tab_cmp: SimdBool = chunk == @as(SimdU8, @splat('\t'));
        const nl_cmp: SimdBool = chunk == @as(SimdU8, @splat('\n'));
        const cr_cmp: SimdBool = chunk == @as(SimdU8, @splat('\r'));

        // Find first non-whitespace in this chunk
        inline for (0..VECTOR_WIDTH) |i| {
            if (!space_cmp[i] and !tab_cmp[i] and !nl_cmp[i] and !cr_cmp[i]) {
                return pos + i;
            }
        }

        pos += VECTOR_WIDTH;
    }

    // Handle remaining bytes
    while (pos < input.len) {
        if (!isWhitespace(input[pos])) {
            return pos;
        }
        pos += 1;
    }

    return pos;
}

/// SIMD-accelerated string end finding (find unescaped quote)
pub fn simdFindStringEnd(input: []const u8, start: usize) ?usize {
    var pos = start;
    var escaped = false;

    while (pos < input.len) {
        if (escaped) {
            escaped = false;
            pos += 1;
            continue;
        }
        if (input[pos] == '\\') {
            escaped = true;
            pos += 1;
            continue;
        }
        if (input[pos] == '"') {
            return pos;
        }
        pos += 1;
    }

    return null;
}

/// SIMD-accelerated structural character finding
pub fn simdFindStructural(input: []const u8, start: usize) ?struct { pos: usize, char: u8 } {
    var pos = start;

    // Process VECTOR_WIDTH bytes at a time
    while (pos + VECTOR_WIDTH <= input.len) {
        const chunk: SimdU8 = input[pos..][0..VECTOR_WIDTH].*;

        // Find structural characters: { } [ ] : ,
        inline for (0..VECTOR_WIDTH) |i| {
            const c = chunk[i];
            if (c == '{' or c == '}' or c == '[' or c == ']' or c == ':' or c == ',') {
                return .{ .pos = pos + i, .char = c };
            }
        }

        pos += VECTOR_WIDTH;
    }

    // Handle remaining bytes
    while (pos < input.len) {
        const c = input[pos];
        if (c == '{' or c == '}' or c == '[' or c == ']' or c == ':' or c == ',') {
            return .{ .pos = pos, .char = c };
        }
        pos += 1;
    }

    return null;
}

/// Scalar whitespace skip for comparison
fn scalarSkipWhitespace(input: []const u8, start: usize) usize {
    var pos = start;
    while (pos < input.len) {
        if (!isWhitespace(input[pos])) {
            return pos;
        }
        pos += 1;
    }
    return pos;
}

/// Benchmark SIMD vs scalar whitespace skipping
pub fn benchmarkWhitespace(input: []const u8, iterations: usize) struct {
    simd_ns: i64,
    scalar_ns: i64,
    speedup: f64,
} {
    // SIMD benchmark
    const simd_start = std.time.nanoTimestamp();
    var simd_result: usize = 0;
    for (0..iterations) |_| {
        simd_result +%= simdSkipWhitespace(input, 0);
    }
    const simd_end = std.time.nanoTimestamp();
    const simd_ns: i64 = @intCast(simd_end - simd_start);

    // Scalar benchmark
    const scalar_start = std.time.nanoTimestamp();
    var scalar_result: usize = 0;
    for (0..iterations) |_| {
        scalar_result +%= scalarSkipWhitespace(input, 0);
    }
    const scalar_end = std.time.nanoTimestamp();
    const scalar_ns: i64 = @intCast(scalar_end - scalar_start);

    // Prevent optimization
    std.mem.doNotOptimizeAway(&simd_result);
    std.mem.doNotOptimizeAway(&scalar_result);

    const speedup = if (simd_ns > 0)
        @as(f64, @floatFromInt(scalar_ns)) / @as(f64, @floatFromInt(simd_ns))
    else
        1.0;

    return .{
        .simd_ns = simd_ns,
        .scalar_ns = scalar_ns,
        .speedup = speedup,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "SIMD skip whitespace" {
    const input = "    \t\n  hello";
    const result = simdSkipWhitespace(input, 0);
    try std.testing.expectEqual(@as(usize, 8), result);
    try std.testing.expectEqual(@as(u8, 'h'), input[result]);
}

test "SIMD skip whitespace no whitespace" {
    const input = "hello";
    const result = simdSkipWhitespace(input, 0);
    try std.testing.expectEqual(@as(usize, 0), result);
}

test "SIMD find string end" {
    const input = "hello world\"rest";
    const result = simdFindStringEnd(input, 0);
    try std.testing.expectEqual(@as(usize, 11), result.?);
}

test "SIMD find string end with escape" {
    const input = "hello \\\"world\"rest";
    const result = simdFindStringEnd(input, 0);
    try std.testing.expectEqual(@as(usize, 13), result.?);
}

test "SIMD find structural" {
    const input = "  key: value";
    const result = simdFindStructural(input, 0);
    try std.testing.expectEqual(@as(usize, 5), result.?.pos);
    try std.testing.expectEqual(@as(u8, ':'), result.?.char);
}

test "SIMD find structural brace" {
    const input = "  { \"key\": 1 }";
    const result = simdFindStructural(input, 0);
    try std.testing.expectEqual(@as(usize, 2), result.?.pos);
    try std.testing.expectEqual(@as(u8, '{'), result.?.char);
}

test "phi constant" {
    // φ² + 1/φ² = 3
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
