// v6772_ttt_layer.zig - Test-Time Training Layer
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const TTTConfig = struct {
    inner_dim: usize = 64,
    num_steps: usize = 1,
    learning_rate: f32 = 0.01,
};

// Inner model forward pass
pub fn innerForward(input: []const f32, weights: []const f32, output: []f32) void {
    const n = @min(input.len, output.len);
    for (0..n) |i| {
        var sum: f32 = 0;
        for (input, 0..) |x, j| {
            const w_idx = i * input.len + j;
            if (w_idx < weights.len) {
                sum += x * weights[w_idx];
            }
        }
        output[i] = sum;
    }
}

// Compute gradient for inner model
pub fn computeGradient(
    input: []const f32,
    target: []const f32,
    prediction: []const f32,
    gradient: []f32,
) void {
    const n = @min(@min(target.len, prediction.len), gradient.len);

    for (0..n) |i| {
        const err = prediction[i] - target[i];
        for (input, 0..) |x, j| {
            const g_idx = i * input.len + j;
            if (g_idx < gradient.len) {
                gradient[g_idx] = err * x;
            }
        }
    }
}

// Gradient step: w = w - lr * grad
pub fn gradientStep(weights: []f32, gradient: []const f32, learning_rate: f32) void {
    const n = @min(weights.len, gradient.len);
    for (0..n) |i| {
        weights[i] -= learning_rate * gradient[i];
    }
}

// Test-time training: adapt weights on context
pub fn testTimeTrain(
    context: []const f32,
    weights: []f32,
    num_steps: usize,
    learning_rate: f32,
    inner_dim: usize,
) void {
    var prediction: [64]f32 = undefined;
    var gradient: [256]f32 = undefined;

    const pred_len = @min(inner_dim, 64);
    const grad_len = @min(weights.len, 256);

    for (0..num_steps) |_| {
        // Forward
        innerForward(context, weights, prediction[0..pred_len]);

        // Compute gradient (self-supervised: predict next from current)
        computeGradient(context, context, prediction[0..pred_len], gradient[0..grad_len]);

        // Update
        gradientStep(weights, gradient[0..grad_len], learning_rate);
    }
}

// PHI-based learning rate
pub fn phiLearningRate(base_lr: f32, step: usize) f32 {
    const decay = math.pow(f32, @floatCast(PHI_INV), @as(f32, @floatFromInt(step)));
    return base_lr * decay;
}

// Adaptation strength based on context length
pub fn adaptationStrength(context_len: usize, max_context: usize) f32 {
    const ratio = @as(f32, @floatFromInt(context_len)) / @as(f32, @floatFromInt(max_context));
    return @min(1.0, ratio * @as(f32, @floatCast(PHI)));
}

// Tests
test "inner forward" {
    const input = [_]f32{ 1.0, 2.0 };
    const weights = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var output: [2]f32 = undefined;
    innerForward(&input, &weights, &output);
    try testing.expectEqual(@as(f32, 1.0), output[0]);
}

test "gradient step" {
    var weights = [_]f32{ 1.0, 2.0 };
    const gradient = [_]f32{ 0.1, 0.2 };
    gradientStep(&weights, &gradient, 1.0);
    try testing.expectEqual(@as(f32, 0.9), weights[0]);
}

test "phi learning rate" {
    const lr0 = phiLearningRate(0.01, 0);
    const lr5 = phiLearningRate(0.01, 5);
    try testing.expect(lr0 > lr5);
}

test "adaptation strength" {
    const s1 = adaptationStrength(100, 1000);
    const s2 = adaptationStrength(500, 1000);
    try testing.expect(s2 > s1);
}

test "test time train" {
    const context = [_]f32{ 1.0, 2.0 };
    var weights = [_]f32{ 0.5, 0.5, 0.5, 0.5 };
    testTimeTrain(&context, &weights, 1, 0.01, 2);
    // Weights should change
    try testing.expect(weights[0] != 0.5 or weights[1] != 0.5);
}

test "config defaults" {
    const config = TTTConfig{};
    try testing.expectEqual(@as(usize, 1), config.num_steps);
}
