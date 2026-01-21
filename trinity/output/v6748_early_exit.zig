// v6748_early_exit.zig - Early Exit / Adaptive Depth
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const EarlyExitConfig = struct {
    confidence_threshold: f32 = 0.9,
    min_layers: usize = 2,
    max_layers: usize = 12,
};

pub fn phiConfidenceThreshold() f32 {
    return @floatCast(PHI_INV); // 0.618 confidence
}

pub fn computeConfidence(logits: []const f32) f32 {
    // Softmax and return max probability
    var max_logit: f32 = logits[0];
    for (logits) |l| {
        max_logit = @max(max_logit, l);
    }

    var sum: f64 = 0;
    var max_prob: f64 = 0;
    for (logits) |l| {
        const prob = @exp(@as(f64, l - max_logit));
        sum += prob;
        max_prob = @max(max_prob, prob);
    }

    return @floatCast(max_prob / sum);
}

pub fn shouldExit(confidence: f32, threshold: f32, layer_idx: usize, min_layers: usize) bool {
    if (layer_idx < min_layers) return false;
    return confidence >= threshold;
}

pub fn computeSpeedup(avg_exit_layer: f32, max_layers: usize) f32 {
    return @as(f32, @floatFromInt(max_layers)) / avg_exit_layer;
}

pub fn adaptiveThreshold(layer_idx: usize, max_layers: usize, base_threshold: f32) f32 {
    // Lower threshold for later layers (more confident)
    const progress = @as(f32, @floatFromInt(layer_idx)) / @as(f32, @floatFromInt(max_layers));
    return base_threshold * (1.0 - progress * 0.2);
}

pub fn entropyConfidence(probs: []const f32) f32 {
    var entropy: f64 = 0;
    for (probs) |p| {
        if (p > 1e-10) {
            entropy -= @as(f64, p) * @log(@as(f64, p));
        }
    }
    // Convert entropy to confidence (lower entropy = higher confidence)
    const max_entropy = @log(@as(f64, @floatFromInt(probs.len)));
    return @floatCast(1.0 - entropy / max_entropy);
}

// Tests
test "phi confidence threshold" {
    const threshold = phiConfidenceThreshold();
    try testing.expect(@abs(threshold - 0.618) < 0.01);
}

test "compute confidence" {
    const logits = [_]f32{ 10.0, 1.0, 1.0 };
    const conf = computeConfidence(&logits);
    try testing.expect(conf > 0.9);
}

test "should exit early" {
    try testing.expect(!shouldExit(0.9, 0.8, 1, 2)); // below min layers
    try testing.expect(shouldExit(0.9, 0.8, 3, 2)); // above threshold
    try testing.expect(!shouldExit(0.5, 0.8, 3, 2)); // below threshold
}

test "speedup calculation" {
    const speedup = computeSpeedup(4.0, 12);
    try testing.expectEqual(@as(f32, 3.0), speedup);
}

test "adaptive threshold" {
    const early = adaptiveThreshold(2, 12, 0.9);
    const late = adaptiveThreshold(10, 12, 0.9);
    try testing.expect(late < early);
}

test "entropy confidence" {
    const uniform = [_]f32{ 0.25, 0.25, 0.25, 0.25 };
    const peaked = [_]f32{ 0.9, 0.05, 0.03, 0.02 };
    const conf_uniform = entropyConfidence(&uniform);
    const conf_peaked = entropyConfidence(&peaked);
    try testing.expect(conf_peaked > conf_uniform);
}
