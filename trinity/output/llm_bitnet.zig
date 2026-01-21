// ═══════════════════════════════════════════════════════════════════════════════
// llm_bitnet v1.0.0 - 1-bit/1.58-bit Quantization
// 32x compression, 71x energy reduction
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Papers: arXiv:2310.11453, arXiv:2402.17764
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const BitNetMode = enum {
    bit1, // {-1, +1}
    bit158, // {-1, 0, +1}
};

pub const TernaryWeight = struct {
    signs: []i8, // Packed ternary values
    scale: f32,
    mode: BitNetMode,
};

// Quantize to 1-bit: sign(W - mean(W))
pub fn quantize1Bit(weights: []const f32, output: []i8, scale: *f32) void {
    if (weights.len == 0) return;

    // Compute mean
    var mean: f32 = 0;
    for (weights) |w| mean += w;
    mean /= @as(f32, @floatFromInt(weights.len));

    // Compute scale (mean absolute value)
    var abs_sum: f32 = 0;
    for (weights) |w| abs_sum += @abs(w - mean);
    scale.* = abs_sum / @as(f32, @floatFromInt(weights.len));

    // Quantize to {-1, +1}
    for (0..weights.len) |i| {
        output[i] = if (weights[i] >= mean) @as(i8, 1) else @as(i8, -1);
    }
}

// Quantize to 1.58-bit: round(W / scale) clipped to {-1, 0, +1}
pub fn quantize158Bit(weights: []const f32, output: []i8, scale: *f32) void {
    if (weights.len == 0) return;

    // Compute scale using absmax
    var abs_max: f32 = 0;
    for (weights) |w| {
        const abs_w = @abs(w);
        if (abs_w > abs_max) abs_max = abs_w;
    }
    scale.* = abs_max;
    if (scale.* == 0) scale.* = 1.0;

    // Quantize to {-1, 0, +1}
    for (0..weights.len) |i| {
        const scaled = weights[i] / scale.*;
        if (scaled > 0.5) {
            output[i] = 1;
        } else if (scaled < -0.5) {
            output[i] = -1;
        } else {
            output[i] = 0;
        }
    }
}

// Dequantize ternary weights
pub fn dequantizeTernary(quantized: []const i8, output: []f32, scale: f32) void {
    for (0..quantized.len) |i| {
        output[i] = @as(f32, @floatFromInt(quantized[i])) * scale;
    }
}

// BitLinear forward: no FP multiply, only add/sub
pub fn bitLinearForward(
    input: []const f32,
    weights: []const i8,
    output: []f32,
    scale: f32,
    in_features: usize,
    out_features: usize,
) void {
    for (0..out_features) |o| {
        var sum: f32 = 0;
        for (0..in_features) |i| {
            const w = weights[o * in_features + i];
            if (w == 1) {
                sum += input[i];
            } else if (w == -1) {
                sum -= input[i];
            }
            // w == 0: no operation
        }
        output[o] = sum * scale;
    }
}

// Absmax quantize activations to INT8
pub fn quantizeActivationsInt8(input: []const f32, output: []i8, scale: *f32) void {
    if (input.len == 0) return;

    var abs_max: f32 = 0;
    for (input) |x| {
        const abs_x = @abs(x);
        if (abs_x > abs_max) abs_max = abs_x;
    }
    scale.* = abs_max / 127.0;
    if (scale.* == 0) scale.* = 1.0;

    for (0..input.len) |i| {
        const q = @round(input[i] / scale.*);
        output[i] = @intFromFloat(@max(-127.0, @min(127.0, q)));
    }
}

// Calculate compression ratio
pub fn compressionRatio(mode: BitNetMode) f32 {
    return switch (mode) {
        .bit1 => 32.0, // FP32 -> 1 bit
        .bit158 => 20.0, // FP32 -> 1.58 bits (log2(3) ≈ 1.58)
    };
}

// Calculate energy savings (from BitNet paper)
pub fn energySavings(mode: BitNetMode) f32 {
    return switch (mode) {
        .bit1 => 71.0, // 71x energy reduction
        .bit158 => 50.0, // Estimated
    };
}

// Count ternary distribution
pub fn countTernaryDistribution(weights: []const i8) struct { neg: usize, zero: usize, pos: usize } {
    var neg: usize = 0;
    var zero: usize = 0;
    var pos: usize = 0;

    for (weights) |w| {
        if (w < 0) neg += 1 else if (w > 0) pos += 1 else zero += 1;
    }

    return .{ .neg = neg, .zero = zero, .pos = pos };
}

// Tests
test "quantize 1-bit" {
    const weights = [_]f32{ -1.0, -0.5, 0.5, 1.0 };
    var quantized: [4]i8 = undefined;
    var scale: f32 = undefined;

    quantize1Bit(&weights, &quantized, &scale);

    try testing.expectEqual(@as(i8, -1), quantized[0]);
    try testing.expectEqual(@as(i8, -1), quantized[1]);
    try testing.expectEqual(@as(i8, 1), quantized[2]);
    try testing.expectEqual(@as(i8, 1), quantized[3]);
}

test "quantize 1.58-bit" {
    const weights = [_]f32{ -1.0, -0.2, 0.2, 1.0 };
    var quantized: [4]i8 = undefined;
    var scale: f32 = undefined;

    quantize158Bit(&weights, &quantized, &scale);

    try testing.expectEqual(@as(i8, -1), quantized[0]);
    try testing.expectEqual(@as(i8, 0), quantized[1]);
    try testing.expectEqual(@as(i8, 0), quantized[2]);
    try testing.expectEqual(@as(i8, 1), quantized[3]);
}

test "bitlinear forward" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weights = [_]i8{ 1, -1, 1, -1, -1, 1, -1, 1 }; // 2x4
    var output: [2]f32 = undefined;

    bitLinearForward(&input, &weights, &output, 1.0, 4, 2);

    // output[0] = 1 - 2 + 3 - 4 = -2
    // output[1] = -1 + 2 - 3 + 4 = 2
    try testing.expectApproxEqAbs(@as(f32, -2.0), output[0], 0.001);
    try testing.expectApproxEqAbs(@as(f32, 2.0), output[1], 0.001);
}

test "compression ratio" {
    try testing.expectApproxEqAbs(@as(f32, 32.0), compressionRatio(.bit1), 0.001);
    try testing.expectApproxEqAbs(@as(f32, 20.0), compressionRatio(.bit158), 0.001);
}

test "ternary distribution" {
    const weights = [_]i8{ -1, 0, 1, 0, -1, 1 };
    const dist = countTernaryDistribution(&weights);

    try testing.expectEqual(@as(usize, 2), dist.neg);
    try testing.expectEqual(@as(usize, 2), dist.zero);
    try testing.expectEqual(@as(usize, 2), dist.pos);
}
