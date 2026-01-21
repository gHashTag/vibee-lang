// v6785_lr_finder.zig - Learning Rate Finder
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const LRFinderConfig = struct {
    start_lr: f32 = 1e-7,
    end_lr: f32 = 10.0,
    num_steps: usize = 100,
    smoothing: f32 = 0.05,
};

// Exponential LR schedule for finder
pub fn exponentialLR(start_lr: f32, end_lr: f32, step: usize, num_steps: usize) f32 {
    const progress = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(num_steps));
    const log_start = @log(start_lr);
    const log_end = @log(end_lr);
    return @exp(log_start + progress * (log_end - log_start));
}

// Smooth loss for stability
pub fn smoothLoss(current_loss: f32, smoothed_loss: f32, smoothing: f32) f32 {
    return smoothing * current_loss + (1.0 - smoothing) * smoothed_loss;
}

// Find optimal LR (steepest descent point)
pub fn findOptimalLR(losses: []const f32, lrs: []const f32) f32 {
    const n = @min(losses.len, lrs.len);
    if (n < 3) return lrs[0];

    var min_gradient: f32 = 0;
    var optimal_idx: usize = 0;

    for (1..n - 1) |i| {
        const gradient = (losses[i + 1] - losses[i - 1]) / 2.0;
        if (gradient < min_gradient) {
            min_gradient = gradient;
            optimal_idx = i;
        }
    }

    return lrs[optimal_idx];
}

// PHI-based LR suggestion
pub fn phiSuggestedLR(optimal_lr: f32) f32 {
    // Divide by PHI for safety margin
    return optimal_lr * @as(f32, @floatCast(PHI_INV));
}

// Detect divergence
pub fn isDiverging(current_loss: f32, best_loss: f32, threshold: f32) bool {
    return current_loss > best_loss * threshold;
}

// LR range test
pub fn lrRangeTest(
    start_lr: f32,
    end_lr: f32,
    num_steps: usize,
    output_lrs: []f32,
) void {
    for (0..num_steps) |i| {
        if (i < output_lrs.len) {
            output_lrs[i] = exponentialLR(start_lr, end_lr, i, num_steps);
        }
    }
}

// Tests
test "exponential lr" {
    const lr_start = exponentialLR(1e-7, 10.0, 0, 100);
    const lr_end = exponentialLR(1e-7, 10.0, 100, 100);
    try testing.expect(lr_start < lr_end);
    try testing.expect(@abs(lr_start - 1e-7) < 1e-8);
}

test "smooth loss" {
    const smoothed = smoothLoss(1.0, 0.5, 0.1);
    try testing.expect(@abs(smoothed - 0.55) < 0.01);
}

test "find optimal lr" {
    const losses = [_]f32{ 1.0, 0.8, 0.5, 0.3, 0.4, 0.6 };
    const lrs = [_]f32{ 1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1.0 };
    const optimal = findOptimalLR(&losses, &lrs);
    try testing.expect(optimal > 0); // Should find some LR
}

test "phi suggested lr" {
    const suggested = phiSuggestedLR(1e-3);
    try testing.expect(suggested < 1e-3);
}

test "is diverging" {
    try testing.expect(isDiverging(5.0, 1.0, 4.0));
    try testing.expect(!isDiverging(3.0, 1.0, 4.0));
}

test "lr range test" {
    var lrs: [10]f32 = undefined;
    lrRangeTest(1e-5, 1e-1, 10, &lrs);
    try testing.expect(lrs[9] > lrs[0]);
}
