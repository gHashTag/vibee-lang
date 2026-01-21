// v6767_differential_attention.zig - Differential Attention
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const DiffAttnConfig = struct {
    num_heads: usize = 8,
    lambda_init: f32 = 0.8,
};

// Differential softmax: A1 - λ * A2
pub fn differentialSoftmax(
    scores1: []const f32,
    scores2: []const f32,
    lambda: f32,
    output: []f32,
) void {
    const n = @min(@min(scores1.len, scores2.len), output.len);

    // Softmax for both
    var max1: f32 = scores1[0];
    var max2: f32 = scores2[0];
    for (0..n) |i| {
        max1 = @max(max1, scores1[i]);
        max2 = @max(max2, scores2[i]);
    }

    var sum1: f32 = 0;
    var sum2: f32 = 0;
    var attn1: [256]f32 = undefined;
    var attn2: [256]f32 = undefined;

    for (0..n) |i| {
        attn1[i] = @exp(scores1[i] - max1);
        attn2[i] = @exp(scores2[i] - max2);
        sum1 += attn1[i];
        sum2 += attn2[i];
    }

    // Differential: A1 - λ * A2
    for (0..n) |i| {
        output[i] = (attn1[i] / sum1) - lambda * (attn2[i] / sum2);
    }
}

// Compute learnable lambda per layer
pub fn computeLambda(layer_idx: usize, num_layers: usize, lambda_init: f32) f32 {
    // Lambda increases with depth
    const progress = @as(f32, @floatFromInt(layer_idx)) / @as(f32, @floatFromInt(num_layers));
    return lambda_init * (1.0 + progress * 0.5);
}

// Noise cancellation effect
pub fn noiseCancellation(attention: []const f32, noise_estimate: []const f32, output: []f32) void {
    const n = @min(@min(attention.len, noise_estimate.len), output.len);
    for (0..n) |i| {
        output[i] = @max(0, attention[i] - noise_estimate[i]);
    }
}

// PHI-based lambda
pub fn phiLambda(layer_idx: usize, num_layers: usize) f32 {
    const progress = @as(f64, @floatFromInt(layer_idx)) / @as(f64, @floatFromInt(num_layers));
    return @floatCast(PHI_INV * (1.0 + progress));
}

// Attention sparsity after differential
pub fn computeSparsity(attention: []const f32, threshold: f32) f32 {
    var zeros: usize = 0;
    for (attention) |a| {
        if (@abs(a) < threshold) {
            zeros += 1;
        }
    }
    return @as(f32, @floatFromInt(zeros)) / @as(f32, @floatFromInt(attention.len));
}

// Tests
test "differential softmax" {
    const scores1 = [_]f32{ 1.0, 2.0, 3.0 };
    const scores2 = [_]f32{ 3.0, 2.0, 1.0 };
    var output: [3]f32 = undefined;
    differentialSoftmax(&scores1, &scores2, 0.5, &output);
    // First element should be negative (high in scores2)
    try testing.expect(output[0] < output[2]);
}

test "compute lambda" {
    const l0 = computeLambda(0, 12, 0.8);
    const l11 = computeLambda(11, 12, 0.8);
    try testing.expect(l11 > l0);
}

test "noise cancellation" {
    const attn = [_]f32{ 0.5, 0.3, 0.2 };
    const noise = [_]f32{ 0.1, 0.1, 0.1 };
    var output: [3]f32 = undefined;
    noiseCancellation(&attn, &noise, &output);
    try testing.expectEqual(@as(f32, 0.4), output[0]);
}

test "phi lambda" {
    const l = phiLambda(6, 12);
    try testing.expect(l > 0.6);
    try testing.expect(l < 1.0);
}

test "compute sparsity" {
    const attn = [_]f32{ 0.0, 0.5, 0.0, 0.3 };
    const sparsity = computeSparsity(&attn, 0.1);
    try testing.expectEqual(@as(f32, 0.5), sparsity);
}

test "config defaults" {
    const config = DiffAttnConfig{};
    try testing.expectEqual(@as(f32, 0.8), config.lambda_init);
}
