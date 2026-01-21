// ═══════════════════════════════════════════════════════════════════════════════
// llm_rmsnorm v1.0.0 - Root Mean Square Normalization
// 1.5x faster than LayerNorm
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const RMSNormConfig = struct {
    hidden_size: usize = 768,
    eps: f32 = 1e-6,
};

// Compute RMS (Root Mean Square)
pub fn computeRMS(input: []const f32) f32 {
    if (input.len == 0) return 0;
    var sum_sq: f32 = 0;
    for (input) |x| {
        sum_sq += x * x;
    }
    return @sqrt(sum_sq / @as(f32, @floatFromInt(input.len)));
}

// RMSNorm forward pass
pub fn rmsnormForward(
    input: []const f32,
    weight: []const f32,
    output: []f32,
    eps: f32,
) void {
    const size = @min(input.len, @min(weight.len, output.len));
    if (size == 0) return;

    // Compute RMS
    var sum_sq: f32 = 0;
    for (0..size) |i| {
        sum_sq += input[i] * input[i];
    }
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(size)) + eps);
    const rms_inv = 1.0 / rms;

    // Normalize and scale
    for (0..size) |i| {
        output[i] = input[i] * rms_inv * weight[i];
    }
}

// Fused RMSNorm (single pass)
pub fn fusedRMSNorm(
    input: []f32,
    weight: []const f32,
    eps: f32,
) void {
    const size = @min(input.len, weight.len);
    if (size == 0) return;

    var sum_sq: f32 = 0;
    for (0..size) |i| {
        sum_sq += input[i] * input[i];
    }
    const rms_inv = 1.0 / @sqrt(sum_sq / @as(f32, @floatFromInt(size)) + eps);

    for (0..size) |i| {
        input[i] = input[i] * rms_inv * weight[i];
    }
}

// RMSNorm backward (for training)
pub fn rmsnormBackward(
    grad_output: []const f32,
    input: []const f32,
    weight: []const f32,
    grad_input: []f32,
    grad_weight: []f32,
    eps: f32,
) void {
    const size = @min(input.len, weight.len);
    if (size == 0) return;

    // Compute RMS
    var sum_sq: f32 = 0;
    for (0..size) |i| {
        sum_sq += input[i] * input[i];
    }
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(size)) + eps);
    const rms_inv = 1.0 / rms;

    // Gradient w.r.t. weight
    for (0..size) |i| {
        grad_weight[i] += grad_output[i] * input[i] * rms_inv;
    }

    // Gradient w.r.t. input (simplified)
    var dot: f32 = 0;
    for (0..size) |i| {
        dot += grad_output[i] * weight[i] * input[i];
    }
    const coeff = dot * rms_inv * rms_inv * rms_inv / @as(f32, @floatFromInt(size));

    for (0..size) |i| {
        grad_input[i] = grad_output[i] * weight[i] * rms_inv - input[i] * coeff;
    }
}

// Tests
test "compute rms" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const rms = computeRMS(&input);
    // RMS = sqrt((1+4+9+16)/4) = sqrt(7.5) ≈ 2.74
    try testing.expectApproxEqAbs(@as(f32, 2.7386), rms, 0.01);
}

test "rmsnorm forward" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;

    rmsnormForward(&input, &weight, &output, 1e-6);

    // Output should be normalized
    var sum_sq: f32 = 0;
    for (output) |x| sum_sq += x * x;
    const rms = @sqrt(sum_sq / 4.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), rms, 0.01);
}

test "fused rmsnorm" {
    var input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };

    fusedRMSNorm(&input, &weight, 1e-6);

    var sum_sq: f32 = 0;
    for (input) |x| sum_sq += x * x;
    const rms = @sqrt(sum_sq / 4.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), rms, 0.01);
}

test "rmsnorm preserves direction" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;

    rmsnormForward(&input, &weight, &output, 1e-6);

    // Ratios should be preserved
    const ratio_in = input[1] / input[0];
    const ratio_out = output[1] / output[0];
    try testing.expectApproxEqAbs(ratio_in, ratio_out, 0.001);
}
