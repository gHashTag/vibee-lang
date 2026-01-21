// v6786_gradient_accumulation.zig - Gradient Accumulation
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const GradAccumConfig = struct {
    accumulation_steps: usize = 4,
    max_grad_norm: f32 = 1.0,
};

// Accumulate gradients
pub fn accumulateGradients(
    current_grads: []const f32,
    accumulated: []f32,
    scale: f32,
) void {
    const n = @min(current_grads.len, accumulated.len);
    for (0..n) |i| {
        accumulated[i] += current_grads[i] * scale;
    }
}

// Average accumulated gradients
pub fn averageGradients(accumulated: []f32, num_steps: usize) void {
    const scale = 1.0 / @as(f32, @floatFromInt(num_steps));
    for (accumulated) |*g| {
        g.* *= scale;
    }
}

// Reset accumulated gradients
pub fn resetGradients(accumulated: []f32) void {
    for (accumulated) |*g| {
        g.* = 0;
    }
}

// Should update weights
pub fn shouldUpdate(step: usize, accumulation_steps: usize) bool {
    return (step + 1) % accumulation_steps == 0;
}

// Effective batch size
pub fn effectiveBatchSize(micro_batch: usize, accumulation_steps: usize) usize {
    return micro_batch * accumulation_steps;
}

// PHI-based accumulation steps
pub fn phiAccumulationSteps(target_batch: usize, micro_batch: usize) usize {
    const base = target_batch / micro_batch;
    return @max(1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(base)) * PHI_INV)));
}

// Gradient norm
pub fn gradientNorm(gradients: []const f32) f32 {
    var sum_sq: f64 = 0;
    for (gradients) |g| {
        sum_sq += @as(f64, g) * @as(f64, g);
    }
    return @floatCast(@sqrt(sum_sq));
}

// Clip gradients by norm
pub fn clipGradientsByNorm(gradients: []f32, max_norm: f32) f32 {
    const norm = gradientNorm(gradients);
    if (norm > max_norm) {
        const scale = max_norm / norm;
        for (gradients) |*g| {
            g.* *= scale;
        }
    }
    return norm;
}

// Tests
test "accumulate gradients" {
    const current = [_]f32{ 1.0, 2.0 };
    var accumulated = [_]f32{ 0.5, 0.5 };
    accumulateGradients(&current, &accumulated, 1.0);
    try testing.expectEqual(@as(f32, 1.5), accumulated[0]);
}

test "average gradients" {
    var accumulated = [_]f32{ 4.0, 8.0 };
    averageGradients(&accumulated, 4);
    try testing.expectEqual(@as(f32, 1.0), accumulated[0]);
}

test "reset gradients" {
    var accumulated = [_]f32{ 1.0, 2.0 };
    resetGradients(&accumulated);
    try testing.expectEqual(@as(f32, 0.0), accumulated[0]);
}

test "should update" {
    try testing.expect(shouldUpdate(3, 4));
    try testing.expect(!shouldUpdate(2, 4));
}

test "effective batch size" {
    try testing.expectEqual(@as(usize, 128), effectiveBatchSize(32, 4));
}

test "gradient norm" {
    const grads = [_]f32{ 3.0, 4.0 };
    const norm = gradientNorm(&grads);
    try testing.expectEqual(@as(f32, 5.0), norm);
}

test "clip gradients" {
    var grads = [_]f32{ 3.0, 4.0 };
    const norm = clipGradientsByNorm(&grads, 2.5);
    try testing.expectEqual(@as(f32, 5.0), norm);
    try testing.expect(gradientNorm(&grads) <= 2.51);
}
