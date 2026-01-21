// v6745_moe_router.zig - Mixture of Experts Router
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const MoEConfig = struct {
    num_experts: usize = 8,
    top_k: usize = 2,
    capacity_factor: f32 = 1.25,
};

pub fn phiExperts(base: usize) usize {
    // Trinity-aligned: use powers of 3 or PHI scaling
    return @intFromFloat(@as(f64, @floatFromInt(base)) * PHI);
}

pub fn phiTopK(num_experts: usize) usize {
    const k = @as(f64, @floatFromInt(num_experts)) * PHI_INV;
    return @max(1, @as(usize, @intFromFloat(k)));
}

pub fn computeRoutingScores(input: []const f32, gate_weights: []const f32, num_experts: usize, scores: []f32) void {
    for (0..num_experts) |e| {
        var score: f32 = 0;
        for (input, 0..) |inp, i| {
            const idx = e * input.len + i;
            if (idx < gate_weights.len) {
                score += inp * gate_weights[idx];
            }
        }
        if (e < scores.len) {
            scores[e] = score;
        }
    }
}

pub fn softmax(scores: []f32) void {
    var max_score: f32 = scores[0];
    for (scores) |s| {
        max_score = @max(max_score, s);
    }

    var sum: f32 = 0;
    for (scores) |*s| {
        s.* = @exp(s.* - max_score);
        sum += s.*;
    }

    for (scores) |*s| {
        s.* /= sum;
    }
}

pub fn topK(scores: []const f32, k: usize, indices: []usize, values: []f32) void {
    // Simple selection for small k
    var sorted_indices: [16]usize = undefined;
    for (0..@min(scores.len, 16)) |i| {
        sorted_indices[i] = i;
    }

    // Bubble sort top k (sufficient for small k)
    for (0..k) |i| {
        for (i + 1..scores.len) |j| {
            if (j < 16 and scores[sorted_indices[j]] > scores[sorted_indices[i]]) {
                const tmp = sorted_indices[i];
                sorted_indices[i] = sorted_indices[j];
                sorted_indices[j] = tmp;
            }
        }
        if (i < indices.len) {
            indices[i] = sorted_indices[i];
            values[i] = scores[sorted_indices[i]];
        }
    }
}

pub fn loadBalanceLoss(routing_probs: []const f32, num_experts: usize, num_tokens: usize) f32 {
    // L_aux = α × Σᵢ fᵢ × Pᵢ
    var loss: f32 = 0;
    const n: f32 = @floatFromInt(num_experts);
    const t: f32 = @floatFromInt(num_tokens);

    for (0..num_experts) |e| {
        if (e < routing_probs.len) {
            const f_i = routing_probs[e]; // fraction to expert
            const p_i = 1.0 / n; // uniform target
            loss += f_i * p_i;
        }
    }
    return loss * n * t;
}

pub fn expertCapacity(num_tokens: usize, num_experts: usize, capacity_factor: f32) usize {
    const base = @as(f32, @floatFromInt(num_tokens)) / @as(f32, @floatFromInt(num_experts));
    return @intFromFloat(base * capacity_factor);
}

// Tests
test "phi experts" {
    try testing.expectEqual(@as(usize, 12), phiExperts(8));
}

test "phi top k" {
    try testing.expectEqual(@as(usize, 4), phiTopK(8));
}

test "softmax" {
    var scores = [_]f32{ 1.0, 2.0, 3.0 };
    softmax(&scores);
    var sum: f32 = 0;
    for (scores) |s| sum += s;
    try testing.expect(@abs(sum - 1.0) < 0.01);
}

test "top k" {
    const scores = [_]f32{ 0.1, 0.5, 0.3, 0.8 };
    var indices: [2]usize = undefined;
    var values: [2]f32 = undefined;
    topK(&scores, 2, &indices, &values);
    try testing.expectEqual(@as(usize, 3), indices[0]); // highest
}

test "expert capacity" {
    const cap = expertCapacity(100, 8, 1.25);
    try testing.expect(cap >= 15);
}

test "config defaults" {
    const config = MoEConfig{};
    try testing.expectEqual(@as(usize, 8), config.num_experts);
}
