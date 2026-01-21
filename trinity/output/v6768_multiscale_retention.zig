// v6768_multiscale_retention.zig - Multi-Scale Retention
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const MSRConfig = struct {
    num_heads: usize = 4,
    hidden_dim: usize = 256,
};

// Multi-scale decay: different gamma per head
pub fn multiScaleGamma(head_idx: usize, num_heads: usize) f32 {
    // γ_h = 1 - 2^{-5-h}
    const h: f64 = @floatFromInt(head_idx);
    const n: f64 = @floatFromInt(num_heads);
    return @floatCast(1.0 - math.pow(f64, 2.0, -5.0 - h * 4.0 / n));
}

// PHI-based multi-scale gamma
pub fn phiMultiScaleGamma(head_idx: usize, num_heads: usize) f32 {
    const progress = @as(f64, @floatFromInt(head_idx)) / @as(f64, @floatFromInt(num_heads));
    return @floatCast(PHI_INV + (1.0 - PHI_INV) * progress);
}

// Group normalization for retention
pub fn groupNormRetention(input: []const f32, num_groups: usize, output: []f32) void {
    const group_size = input.len / num_groups;

    for (0..num_groups) |g| {
        const start = g * group_size;
        const end = @min(start + group_size, input.len);

        // Compute mean and variance for group
        var mean: f64 = 0;
        for (start..end) |i| {
            mean += @as(f64, input[i]);
        }
        mean /= @as(f64, @floatFromInt(end - start));

        var variance: f64 = 0;
        for (start..end) |i| {
            const diff = @as(f64, input[i]) - mean;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(end - start));
        const std_dev = @sqrt(variance + 1e-5);

        // Normalize
        for (start..end) |i| {
            if (i < output.len) {
                output[i] = @floatCast((@as(f64, input[i]) - mean) / std_dev);
            }
        }
    }
}

// Swish gating: x * sigmoid(x)
pub fn swishGate(input: []const f32, output: []f32) void {
    for (input, 0..) |x, i| {
        if (i < output.len) {
            output[i] = x / (1.0 + @exp(-x));
        }
    }
}

// Multi-head retention with different scales
pub fn multiHeadRetention(
    input: []const f32,
    num_heads: usize,
    _: usize,
    output: []f32,
) void {
    const head_dim = input.len / num_heads;

    for (0..num_heads) |h| {
        const gamma = multiScaleGamma(h, num_heads);
        const start = h * head_dim;
        const end = @min(start + head_dim, input.len);

        var state: f32 = 0;
        for (start..end) |i| {
            state = gamma * state + input[i];
            if (i < output.len) {
                output[i] = state;
            }
        }
    }
}

// Tests
test "multi scale gamma" {
    const g0 = multiScaleGamma(0, 4);
    const g3 = multiScaleGamma(3, 4);
    try testing.expect(g3 > g0);
    try testing.expect(g0 > 0.9);
}

test "phi multi scale gamma" {
    const g0 = phiMultiScaleGamma(0, 4);
    const g3 = phiMultiScaleGamma(3, 4);
    try testing.expect(g3 > g0);
    try testing.expect(@abs(g0 - 0.618) < 0.01);
}

test "group norm retention" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;
    groupNormRetention(&input, 2, &output);
    // Normalized values should have mean ~0
    try testing.expect(@abs(output[0] + output[1]) < 0.1);
}

test "swish gate" {
    const input = [_]f32{ 0.0, 1.0, -1.0 };
    var output: [3]f32 = undefined;
    swishGate(&input, &output);
    try testing.expectEqual(@as(f32, 0.0), output[0]);
    try testing.expect(output[1] > 0.5);
}

test "multi head retention" {
    const input = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;
    multiHeadRetention(&input, 2, 2, &output);
    try testing.expect(output[1] > output[0]);
}

test "config defaults" {
    const config = MSRConfig{};
    try testing.expectEqual(@as(usize, 4), config.num_heads);
}
