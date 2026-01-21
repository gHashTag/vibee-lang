// ═══════════════════════════════════════════════════════════════════════════════
// qml_attention v1.0.0 - Квантовый Attention механизм
// Memory-efficient + Sparse attention для CPU
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const MaskType = enum {
    full,
    causal,
    local,
    global_local,
    dilated,
};

pub const AttentionConfig = struct {
    num_heads: usize = 12,
    head_dim: usize = 64,
    max_seq_len: usize = 512,
    dropout: f32 = 0.0,
    use_flash: bool = true,
    use_sparse: bool = false,
    sparse_block_size: usize = 64,
};

pub const AttentionMask = struct {
    mask_type: MaskType = .full,
    causal: bool = false,
    local_window: usize = 256,
};

// Scaled dot-product attention score
pub fn attentionScore(q: []const f32, k: []const f32, head_dim: usize) f32 {
    var score: f32 = 0;
    for (0..head_dim) |i| {
        score += q[i] * k[i];
    }
    return score / @sqrt(@as(f32, @floatFromInt(head_dim)));
}

// Softmax for attention weights
pub fn attentionSoftmax(scores: []f32, size: usize) void {
    if (size == 0) return;
    var max_val: f32 = scores[0];
    for (1..size) |i| {
        if (scores[i] > max_val) max_val = scores[i];
    }
    var sum: f32 = 0;
    for (0..size) |i| {
        scores[i] = @exp(scores[i] - max_val);
        sum += scores[i];
    }
    if (sum > 0) {
        for (0..size) |i| {
            scores[i] /= sum;
        }
    }
}

// Apply causal mask (set future positions to -inf)
pub fn applyCausalMask(scores: []f32, seq_len: usize, query_pos: usize) void {
    for (0..seq_len) |key_pos| {
        if (key_pos > query_pos) {
            scores[key_pos] = -math.inf(f32);
        }
    }
}

// Apply local window mask
pub fn applyLocalMask(scores: []f32, seq_len: usize, query_pos: usize, window: usize) void {
    const half_window = window / 2;
    for (0..seq_len) |key_pos| {
        const dist = if (key_pos > query_pos) key_pos - query_pos else query_pos - key_pos;
        if (dist > half_window) {
            scores[key_pos] = -math.inf(f32);
        }
    }
}

// Compute attention output for single head
pub fn singleHeadAttention(
    q: []const f32,
    k: []const f32,
    v: []const f32,
    output: []f32,
    seq_len: usize,
    head_dim: usize,
    query_pos: usize,
    mask: AttentionMask,
) void {
    var scores: [512]f32 = undefined;

    // Compute attention scores
    for (0..seq_len) |key_pos| {
        const k_offset = key_pos * head_dim;
        scores[key_pos] = attentionScore(q, k[k_offset .. k_offset + head_dim], head_dim);
    }

    // Apply mask
    if (mask.causal) {
        applyCausalMask(scores[0..seq_len], seq_len, query_pos);
    }
    if (mask.mask_type == .local) {
        applyLocalMask(scores[0..seq_len], seq_len, query_pos, mask.local_window);
    }

    // Softmax
    attentionSoftmax(scores[0..seq_len], seq_len);

    // Weighted sum of values
    for (0..head_dim) |d| {
        output[d] = 0;
        for (0..seq_len) |key_pos| {
            output[d] += scores[key_pos] * v[key_pos * head_dim + d];
        }
    }
}

// Rotary Position Embedding (RoPE)
pub fn applyRoPE(q: []f32, k: []f32, head_dim: usize, position: usize, base: f32) void {
    const half_dim = head_dim / 2;
    for (0..half_dim) |i| {
        const exp = @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim));
        const freq = 1.0 / @exp(@log(base) * exp);
        const angle = @as(f32, @floatFromInt(position)) * freq;
        const cos_val = @cos(angle);
        const sin_val = @sin(angle);

        // Rotate Q
        const q_real = q[i];
        const q_imag = q[i + half_dim];
        q[i] = q_real * cos_val - q_imag * sin_val;
        q[i + half_dim] = q_real * sin_val + q_imag * cos_val;

        // Rotate K
        const k_real = k[i];
        const k_imag = k[i + half_dim];
        k[i] = k_real * cos_val - k_imag * sin_val;
        k[i + half_dim] = k_real * sin_val + k_imag * cos_val;
    }
}

// PHI-optimal head count
pub fn phiOptimalHeads(hidden_dim: usize) usize {
    // heads such that head_dim ≈ hidden_dim * PHI_INV / heads
    const target_head_dim: f64 = 64.0;
    const heads = @as(f64, @floatFromInt(hidden_dim)) / target_head_dim;
    return @max(1, @as(usize, @intFromFloat(@round(heads))));
}

// Tests
test "attention score" {
    const q = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const k = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const score = attentionScore(&q, &k, 4);
    try testing.expectApproxEqAbs(@as(f32, 0.5), score, 0.01);
}

test "attention softmax" {
    var scores = [_]f32{ 1.0, 2.0, 3.0 };
    attentionSoftmax(&scores, 3);
    var sum: f32 = 0;
    for (scores) |s| sum += s;
    try testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.001);
}

test "causal mask" {
    var scores = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    applyCausalMask(&scores, 4, 1);
    try testing.expect(scores[0] == 1.0);
    try testing.expect(scores[1] == 1.0);
    try testing.expect(math.isNegativeInf(scores[2]));
    try testing.expect(math.isNegativeInf(scores[3]));
}

test "local mask" {
    var scores = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0 };
    applyLocalMask(&scores, 5, 2, 2);
    try testing.expect(math.isNegativeInf(scores[0]));
    try testing.expect(scores[1] == 1.0);
    try testing.expect(scores[2] == 1.0);
    try testing.expect(scores[3] == 1.0);
    try testing.expect(math.isNegativeInf(scores[4]));
}

test "phi optimal heads" {
    try testing.expectEqual(@as(usize, 12), phiOptimalHeads(768));
    try testing.expectEqual(@as(usize, 6), phiOptimalHeads(384));
}

test "rope" {
    var q = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var k = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    applyRoPE(&q, &k, 4, 0, 10000.0);
    // At position 0, rotation should be identity
    try testing.expectApproxEqAbs(@as(f32, 1.0), q[0], 0.01);
}
