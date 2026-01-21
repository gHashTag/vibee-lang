// ═══════════════════════════════════════════════════════════════
// v6724: SPARSE ATTENTION
// O(n√n) or O(n log n) attention
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;

pub const SparsityPattern = enum {
    LOCAL_WINDOW,
    STRIDED,
    RANDOM,
    LONGFORMER,
    BIGBIRD,
    PHI_SPIRAL,
};

pub const SparseConfig = struct {
    pattern: SparsityPattern = .LOCAL_WINDOW,
    window_size: usize = 32,
    stride: usize = 8,
    num_global_tokens: usize = 2,
    num_random_tokens: usize = 3,
};

pub fn localWindowMask(seq_len: usize, window_size: usize, mask: []bool) void {
    const half_window = window_size / 2;
    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            const idx = i * seq_len + j;
            if (idx < mask.len) {
                const dist = if (i > j) i - j else j - i;
                mask[idx] = dist <= half_window;
            }
        }
    }
}

pub fn stridedMask(seq_len: usize, stride: usize, mask: []bool) void {
    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            const idx = i * seq_len + j;
            if (idx < mask.len) {
                mask[idx] = (j % stride == 0);
            }
        }
    }
}

pub fn fibonacciPositions(max_pos: usize) [12]usize {
    var fibs: [12]usize = undefined;
    fibs[0] = 0;
    fibs[1] = 1;
    var count: usize = 2;

    while (count < 12) {
        const next = fibs[count - 1] + fibs[count - 2];
        if (next >= max_pos) break;
        fibs[count] = next;
        count += 1;
    }

    // Fill rest with max_pos
    while (count < 12) {
        fibs[count] = max_pos;
        count += 1;
    }

    return fibs;
}

pub fn phiSpiralMask(seq_len: usize, mask: []bool) void {
    const fibs = fibonacciPositions(seq_len);

    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            const idx = i * seq_len + j;
            if (idx < mask.len) {
                // Attend to Fibonacci positions relative to i
                var is_fib = false;
                for (fibs) |f| {
                    if (f >= seq_len) break;
                    const pos = if (i >= f) i - f else 0;
                    if (j == pos or j == i + f) {
                        is_fib = true;
                        break;
                    }
                }
                mask[idx] = is_fib or (i == j); // Always attend to self
            }
        }
    }
}

pub fn computeDensity(mask: []const bool) f32 {
    if (mask.len == 0) return 0;
    var count: usize = 0;
    for (mask) |m| {
        if (m) count += 1;
    }
    return @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(mask.len));
}

pub fn estimateComplexity(seq_len: usize, density: f32) usize {
    return @intFromFloat(@as(f32, @floatFromInt(seq_len * seq_len)) * density);
}

// Tests
test "local window" {
    var mask: [64]bool = undefined;
    localWindowMask(8, 4, &mask);
    const density = computeDensity(&mask);
    try testing.expect(density <= 0.625); // window=4 gives ~62.5% density for seq=8
}

test "strided" {
    var mask: [64]bool = undefined;
    stridedMask(8, 4, &mask);
    const density = computeDensity(&mask);
    try testing.expect(density < 0.3);
}

test "phi spiral" {
    const fibs = fibonacciPositions(128);
    try testing.expect(fibs[0] == 0);
    try testing.expect(fibs[1] == 1);
    try testing.expect(fibs[2] == 1);
    try testing.expect(fibs[3] == 2);
    try testing.expect(fibs[4] == 3);
    try testing.expect(fibs[5] == 5);
}

test "complexity" {
    const ops = estimateComplexity(128, 0.1);
    try testing.expect(ops < 128 * 128);
}

test "density computation" {
    const mask = [_]bool{ true, false, true, false };
    const density = computeDensity(&mask);
    try testing.expectApproxEqAbs(@as(f32, 0.5), density, 0.001);
}

test "config defaults" {
    const config = SparseConfig{};
    try testing.expect(config.window_size == 32);
    try testing.expect(config.pattern == .LOCAL_WINDOW);
}
