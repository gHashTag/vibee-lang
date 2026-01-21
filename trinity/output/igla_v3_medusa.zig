// ═══════════════════════════════════════════════════════════════════════════════
// igla_v3_medusa v3.0.0 - Multi-head Decoding
// 2-3x speedup through parallel token prediction
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: arXiv:2401.10774
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const MedusaConfig = struct {
    num_heads: usize = 4,
    hidden_size: usize = 768,
    vocab_size: usize = 32000,
    top_k: usize = 10,
};

pub const TreeCandidate = struct {
    tokens: [8]u32 = [_]u32{0} ** 8,
    length: usize = 0,
    probability: f32 = 0,
};

// Medusa head forward: predict future token
pub fn medusaHeadForward(
    hidden: []const f32,
    weight1: []const f32,
    weight2: []const f32,
    output: []f32,
    hidden_size: usize,
    intermediate_size: usize,
    vocab_size: usize,
) void {
    var intermediate: [2048]f32 = [_]f32{0} ** 2048;

    // First linear + SiLU
    for (0..intermediate_size) |i| {
        var sum: f32 = 0;
        for (0..hidden_size) |j| {
            sum += hidden[j] * weight1[j * intermediate_size + i];
        }
        // SiLU activation
        intermediate[i] = sum / (1.0 + @exp(-sum));
    }

    // Second linear to vocab
    for (0..vocab_size) |v| {
        var sum: f32 = 0;
        for (0..intermediate_size) |i| {
            sum += intermediate[i] * weight2[i * vocab_size + v];
        }
        output[v] = sum;
    }
}

// Get top-k tokens from logits
pub fn getTopK(logits: []const f32, k: usize, tokens: []u32, probs: []f32) usize {
    const n = @min(logits.len, k);
    var used: [32000]bool = [_]bool{false} ** 32000;

    // Softmax first
    var max_val: f32 = logits[0];
    for (logits[1..]) |l| {
        if (l > max_val) max_val = l;
    }

    var sum: f32 = 0;
    var exp_logits: [32000]f32 = undefined;
    for (0..logits.len) |i| {
        exp_logits[i] = @exp(logits[i] - max_val);
        sum += exp_logits[i];
    }

    // Select top-k
    for (0..n) |i| {
        var max_idx: usize = 0;
        var max_prob: f32 = -1;

        for (0..logits.len) |j| {
            const prob = exp_logits[j] / sum;
            if (!used[j] and prob > max_prob) {
                max_prob = prob;
                max_idx = j;
            }
        }

        tokens[i] = @intCast(max_idx);
        probs[i] = max_prob;
        used[max_idx] = true;
    }

    return n;
}

// Build candidate tree from Medusa heads
pub fn buildCandidateTree(
    head_tokens: []const [10]u32,
    head_probs: []const [10]f32,
    num_heads: usize,
    candidates: []TreeCandidate,
    max_candidates: usize,
) usize {
    var num_candidates: usize = 0;

    // Simple tree: combine top tokens from each head
    for (0..@min(10, max_candidates)) |i| {
        if (num_candidates >= max_candidates) break;

        var candidate = TreeCandidate{};
        var prob: f32 = 1.0;

        for (0..num_heads) |h| {
            candidate.tokens[h] = head_tokens[h][i % 10];
            prob *= head_probs[h][i % 10];
        }

        candidate.length = num_heads;
        candidate.probability = prob;
        candidates[num_candidates] = candidate;
        num_candidates += 1;
    }

    return num_candidates;
}

// Verify candidates with base model (simplified)
pub fn verifyCandidates(
    candidates: []const TreeCandidate,
    num_candidates: usize,
    base_probs: []const f32,
    accepted: []u32,
) usize {
    _ = base_probs; // Used in full implementation
    if (num_candidates == 0) return 0;

    // Find best candidate
    var best_idx: usize = 0;
    var best_prob: f32 = candidates[0].probability;

    for (1..num_candidates) |i| {
        if (candidates[i].probability > best_prob) {
            best_prob = candidates[i].probability;
            best_idx = i;
        }
    }

    // Accept tokens from best candidate
    const best = candidates[best_idx];
    for (0..best.length) |i| {
        accepted[i] = best.tokens[i];
    }

    return best.length;
}

// Calculate speedup
pub fn calculateSpeedup(accepted_tokens: usize, forward_passes: usize) f32 {
    if (forward_passes == 0) return 1.0;
    return @as(f32, @floatFromInt(accepted_tokens)) / @as(f32, @floatFromInt(forward_passes));
}

// PHI-optimal number of heads
pub fn phiOptimalHeads(base_heads: usize) usize {
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(base_heads)) * PHI_INV)));
}

// Tests
test "get top k" {
    var logits: [100]f32 = undefined;
    for (0..100) |i| {
        logits[i] = @as(f32, @floatFromInt(i)) / 100.0;
    }
    logits[50] = 10.0; // Make 50 the highest

    var tokens: [5]u32 = undefined;
    var probs: [5]f32 = undefined;

    const n = getTopK(&logits, 5, &tokens, &probs);

    try testing.expectEqual(@as(usize, 5), n);
    try testing.expectEqual(@as(u32, 50), tokens[0]);
}

test "build candidate tree" {
    var head_tokens: [4][10]u32 = undefined;
    var head_probs: [4][10]f32 = undefined;

    for (0..4) |h| {
        for (0..10) |i| {
            head_tokens[h][i] = @intCast(h * 10 + i);
            head_probs[h][i] = 0.1;
        }
    }

    var candidates: [20]TreeCandidate = undefined;
    const n = buildCandidateTree(&head_tokens, &head_probs, 4, &candidates, 20);

    try testing.expect(n > 0);
    try testing.expect(candidates[0].length == 4);
}

test "calculate speedup" {
    try testing.expectApproxEqAbs(@as(f32, 3.0), calculateSpeedup(3, 1), 0.001);
    try testing.expectApproxEqAbs(@as(f32, 2.5), calculateSpeedup(5, 2), 0.001);
}

test "phi optimal heads" {
    try testing.expectEqual(@as(usize, 2), phiOptimalHeads(4));
    try testing.expectEqual(@as(usize, 5), phiOptimalHeads(8));
}

test "tree candidate init" {
    const candidate = TreeCandidate{};
    try testing.expectEqual(@as(usize, 0), candidate.length);
    try testing.expectApproxEqAbs(@as(f32, 0), candidate.probability, 0.001);
}
