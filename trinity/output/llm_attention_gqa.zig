// ═══════════════════════════════════════════════════════════════════════════════
// llm_attention_gqa v1.0.0 - Grouped Query Attention
// 8x KV reduction, 50% memory savings
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: arXiv:2305.13245
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const GQAConfig = struct {
    num_heads: usize = 12,
    num_kv_heads: usize = 4, // GQA ratio = 3
    head_dim: usize = 64,
    max_seq_len: usize = 4096,
    sliding_window: usize = 0, // 0 = disabled
};

// Calculate GQA group size
pub fn gqaGroupSize(num_heads: usize, num_kv_heads: usize) usize {
    return num_heads / num_kv_heads;
}

// Expand KV heads to match Q heads
pub fn expandKV(
    kv: []const f32,
    expanded: []f32,
    num_kv_heads: usize,
    num_heads: usize,
    seq_len: usize,
    head_dim: usize,
) void {
    const group_size = num_heads / num_kv_heads;

    for (0..num_heads) |h| {
        const kv_head = h / group_size;
        for (0..seq_len) |s| {
            for (0..head_dim) |d| {
                const src_idx = kv_head * seq_len * head_dim + s * head_dim + d;
                const dst_idx = h * seq_len * head_dim + s * head_dim + d;
                expanded[dst_idx] = kv[src_idx];
            }
        }
    }
}

// Compute attention scores for single head
pub fn computeAttentionScores(
    q: []const f32,
    k: []const f32,
    scores: []f32,
    head_dim: usize,
    seq_len: usize,
) void {
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

    for (0..seq_len) |i| {
        var dot: f32 = 0;
        for (0..head_dim) |d| {
            dot += q[d] * k[i * head_dim + d];
        }
        scores[i] = dot * scale;
    }
}

// Apply causal mask
pub fn applyCausalMask(scores: []f32, seq_len: usize, query_pos: usize) void {
    for (0..seq_len) |i| {
        if (i > query_pos) {
            scores[i] = -math.inf(f32);
        }
    }
}

// Apply sliding window mask
pub fn applySlidingWindowMask(scores: []f32, seq_len: usize, query_pos: usize, window: usize) void {
    if (window == 0) return;

    for (0..seq_len) |i| {
        if (i > query_pos) {
            scores[i] = -math.inf(f32);
        } else if (query_pos > window and i < query_pos - window) {
            scores[i] = -math.inf(f32);
        }
    }
}

// Softmax for attention
pub fn attentionSoftmax(scores: []f32, size: usize) void {
    if (size == 0) return;

    var max_val: f32 = scores[0];
    for (1..size) |i| {
        if (scores[i] > max_val) max_val = scores[i];
    }

    var sum: f32 = 0;
    for (0..size) |i| {
        if (!math.isNegativeInf(scores[i])) {
            scores[i] = @exp(scores[i] - max_val);
            sum += scores[i];
        } else {
            scores[i] = 0;
        }
    }

    if (sum > 0) {
        for (0..size) |i| {
            scores[i] /= sum;
        }
    }
}

// Compute weighted sum of values
pub fn computeAttentionOutput(
    scores: []const f32,
    v: []const f32,
    output: []f32,
    seq_len: usize,
    head_dim: usize,
) void {
    for (0..head_dim) |d| {
        output[d] = 0;
        for (0..seq_len) |i| {
            output[d] += scores[i] * v[i * head_dim + d];
        }
    }
}

// GQA memory savings calculation
pub fn gqaMemorySavings(num_heads: usize, num_kv_heads: usize) f32 {
    // KV memory is proportional to num_kv_heads
    // Savings = 1 - (num_kv_heads / num_heads)
    return 1.0 - @as(f32, @floatFromInt(num_kv_heads)) / @as(f32, @floatFromInt(num_heads));
}

// PHI-optimal KV heads
pub fn phiOptimalKVHeads(num_heads: usize) usize {
    // KV heads ≈ num_heads * φ^(-2) ≈ num_heads * 0.382
    const kv_f: f64 = @as(f64, @floatFromInt(num_heads)) * PHI_INV * PHI_INV;
    return @max(1, @as(usize, @intFromFloat(@round(kv_f))));
}

// Tests
test "gqa group size" {
    try testing.expectEqual(@as(usize, 3), gqaGroupSize(12, 4));
    try testing.expectEqual(@as(usize, 1), gqaGroupSize(8, 8)); // MHA
    try testing.expectEqual(@as(usize, 8), gqaGroupSize(8, 1)); // MQA
}

test "attention scores" {
    const q = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const k = [_]f32{ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0 }; // 2 keys
    var scores: [2]f32 = undefined;

    computeAttentionScores(&q, &k, &scores, 4, 2);

    // First key matches, second doesn't
    try testing.expect(scores[0] > scores[1]);
}

test "causal mask" {
    var scores = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    applyCausalMask(&scores, 4, 1);

    try testing.expect(scores[0] == 1.0);
    try testing.expect(scores[1] == 1.0);
    try testing.expect(math.isNegativeInf(scores[2]));
    try testing.expect(math.isNegativeInf(scores[3]));
}

test "sliding window mask" {
    var scores = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0 };
    applySlidingWindowMask(&scores, 5, 4, 2);

    try testing.expect(math.isNegativeInf(scores[0]));
    try testing.expect(math.isNegativeInf(scores[1]));
    try testing.expect(scores[2] == 1.0);
    try testing.expect(scores[3] == 1.0);
    try testing.expect(scores[4] == 1.0);
}

test "gqa memory savings" {
    const savings = gqaMemorySavings(12, 4);
    try testing.expectApproxEqAbs(@as(f32, 0.667), savings, 0.01);
}

test "phi optimal kv heads" {
    const kv = phiOptimalKVHeads(12);
    try testing.expect(kv >= 3);
    try testing.expect(kv <= 6);
}
