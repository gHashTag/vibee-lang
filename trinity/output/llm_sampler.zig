// ═══════════════════════════════════════════════════════════════════════════════
// llm_sampler v1.0.0 - Top-p/Top-k Sampling
// Temperature, nucleus sampling, repetition penalty
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const SamplerConfig = struct {
    temperature: f32 = 0.7,
    top_p: f32 = 0.9,
    top_k: usize = 40,
    repetition_penalty: f32 = 1.1,
};

// Apply temperature scaling
pub fn applyTemperature(logits: []f32, temperature: f32) void {
    if (temperature == 0 or temperature == 1.0) return;
    for (logits) |*l| {
        l.* /= temperature;
    }
}

// Softmax
pub fn softmax(logits: []f32) void {
    if (logits.len == 0) return;

    var max_val: f32 = logits[0];
    for (logits[1..]) |l| {
        if (l > max_val) max_val = l;
    }

    var sum: f32 = 0;
    for (logits) |*l| {
        l.* = @exp(l.* - max_val);
        sum += l.*;
    }

    if (sum > 0) {
        for (logits) |*l| {
            l.* /= sum;
        }
    }
}

// Top-k filtering: keep only top k logits
pub fn topKFilter(logits: []f32, k: usize) void {
    if (k >= logits.len) return;

    // Find k-th largest value (simple O(n*k) for small k)
    var threshold: f32 = -math.inf(f32);
    var count: usize = 0;

    // Simple approach: find threshold
    for (0..k) |_| {
        var max_val: f32 = -math.inf(f32);
        for (logits) |l| {
            if (l > max_val and l > threshold) {
                max_val = l;
            }
        }
        if (max_val > -math.inf(f32)) {
            threshold = max_val;
            count += 1;
        }
    }

    // Set values below threshold to -inf
    for (logits) |*l| {
        if (l.* < threshold) {
            l.* = -math.inf(f32);
        }
    }
}

// Top-p (nucleus) filtering
pub fn topPFilter(probs: []f32, p: f32) void {
    if (p >= 1.0) return;

    // Sort indices by probability (descending)
    var indices: [32000]usize = undefined;
    for (0..probs.len) |i| {
        indices[i] = i;
    }

    // Simple bubble sort for small vocab (use better sort for large)
    for (0..@min(probs.len, 100)) |i| {
        for (i + 1..probs.len) |j| {
            if (probs[indices[j]] > probs[indices[i]]) {
                const tmp = indices[i];
                indices[i] = indices[j];
                indices[j] = tmp;
            }
        }
    }

    // Find cutoff
    var cumsum: f32 = 0;
    var cutoff_idx: usize = probs.len;
    for (0..probs.len) |i| {
        cumsum += probs[indices[i]];
        if (cumsum > p) {
            cutoff_idx = i + 1;
            break;
        }
    }

    // Zero out tokens beyond cutoff
    for (cutoff_idx..probs.len) |i| {
        probs[indices[i]] = 0;
    }

    // Renormalize
    var sum: f32 = 0;
    for (probs) |prob| sum += prob;
    if (sum > 0) {
        for (probs) |*prob| prob.* /= sum;
    }
}

// Apply repetition penalty
pub fn applyRepetitionPenalty(logits: []f32, generated: []const usize, penalty: f32) void {
    for (generated) |token_id| {
        if (token_id < logits.len) {
            if (logits[token_id] > 0) {
                logits[token_id] /= penalty;
            } else {
                logits[token_id] *= penalty;
            }
        }
    }
}

// Greedy decode: argmax
pub fn greedyDecode(logits: []const f32) usize {
    if (logits.len == 0) return 0;

    var max_idx: usize = 0;
    var max_val: f32 = logits[0];

    for (1..logits.len) |i| {
        if (logits[i] > max_val) {
            max_val = logits[i];
            max_idx = i;
        }
    }

    return max_idx;
}

// Sample from probability distribution
pub fn sampleFromProbs(probs: []const f32, rand_val: f32) usize {
    var cumsum: f32 = 0;
    for (0..probs.len) |i| {
        cumsum += probs[i];
        if (rand_val < cumsum) {
            return i;
        }
    }
    return probs.len - 1;
}

// Full sampling pipeline
pub fn sample(logits: []f32, config: SamplerConfig, generated: []const usize, rand_val: f32) usize {
    // Apply repetition penalty
    if (config.repetition_penalty != 1.0) {
        applyRepetitionPenalty(logits, generated, config.repetition_penalty);
    }

    // Apply temperature
    if (config.temperature != 1.0 and config.temperature > 0) {
        applyTemperature(logits, config.temperature);
    }

    // Greedy if temperature is 0
    if (config.temperature == 0) {
        return greedyDecode(logits);
    }

    // Top-k filter
    if (config.top_k > 0) {
        topKFilter(logits, config.top_k);
    }

    // Convert to probabilities
    softmax(logits);

    // Top-p filter
    if (config.top_p < 1.0) {
        topPFilter(logits, config.top_p);
    }

    // Sample
    return sampleFromProbs(logits, rand_val);
}

// Tests
test "apply temperature" {
    var logits = [_]f32{ 1.0, 2.0, 3.0 };
    applyTemperature(&logits, 0.5);
    try testing.expectApproxEqAbs(@as(f32, 2.0), logits[0], 0.001);
    try testing.expectApproxEqAbs(@as(f32, 4.0), logits[1], 0.001);
}

test "softmax" {
    var logits = [_]f32{ 1.0, 2.0, 3.0 };
    softmax(&logits);
    var sum: f32 = 0;
    for (logits) |l| sum += l;
    try testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.001);
    try testing.expect(logits[2] > logits[1]);
    try testing.expect(logits[1] > logits[0]);
}

test "greedy decode" {
    const logits = [_]f32{ 1.0, 3.0, 2.0 };
    try testing.expectEqual(@as(usize, 1), greedyDecode(&logits));
}

test "sample from probs" {
    const probs = [_]f32{ 0.1, 0.3, 0.6 };
    try testing.expectEqual(@as(usize, 0), sampleFromProbs(&probs, 0.05));
    try testing.expectEqual(@as(usize, 1), sampleFromProbs(&probs, 0.2));
    try testing.expectEqual(@as(usize, 2), sampleFromProbs(&probs, 0.5));
}

test "repetition penalty" {
    var logits = [_]f32{ 1.0, 2.0, 3.0 };
    const generated = [_]usize{1};
    applyRepetitionPenalty(&logits, &generated, 1.5);
    try testing.expect(logits[1] < 2.0);
}
