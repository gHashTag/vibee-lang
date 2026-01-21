// ═══════════════════════════════════════════════════════════════
// v6735: ALiBi POSITION BIAS
// Attention with Linear Biases
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const ALiBiConfig = struct {
    num_heads: usize = 12,
    max_seq_len: usize = 2048,
    use_phi_slopes: bool = false,
};

pub fn computeSlopes(num_heads: usize) [16]f32 {
    var slopes: [16]f32 = undefined;
    const n = @min(num_heads, 16);

    // slopes = [2^(-8/n), 2^(-16/n), ..., 2^(-8)]
    for (0..n) |i| {
        const exp = -8.0 * @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(n));
        slopes[i] = math.pow(f32, 2.0, exp);
    }

    for (n..16) |i| {
        slopes[i] = 0;
    }

    return slopes;
}

pub fn phiSlopes(num_heads: usize) [16]f32 {
    var slopes: [16]f32 = undefined;
    const n = @min(num_heads, 16);

    // slopes = [φ^(-1), φ^(-2), ..., φ^(-n)]
    for (0..n) |i| {
        slopes[i] = @floatCast(math.pow(f64, PHI_INV, @as(f64, @floatFromInt(i + 1))));
    }

    for (n..16) |i| {
        slopes[i] = 0;
    }

    return slopes;
}

pub fn computeBias(slope: f32, pos_i: usize, pos_j: usize) f32 {
    const dist = if (pos_i > pos_j) pos_i - pos_j else pos_j - pos_i;
    return -slope * @as(f32, @floatFromInt(dist));
}

pub fn alibiAttention(q: []const f32, k: []const f32, v: []const f32, output: []f32, slopes: []const f32, head_dim: usize, head_idx: usize) void {
    const seq_len = q.len / head_dim;
    const slope = if (head_idx < slopes.len) slopes[head_idx] else 0;

    for (0..seq_len) |i| {
        var max_score: f32 = -math.inf(f32);
        var scores: [128]f32 = undefined;
        const actual_len = @min(seq_len, 128);

        // Compute scores with bias
        for (0..actual_len) |j| {
            var dot: f32 = 0;
            for (0..head_dim) |d| {
                const q_idx = i * head_dim + d;
                const k_idx = j * head_dim + d;
                if (q_idx < q.len and k_idx < k.len) {
                    dot += q[q_idx] * k[k_idx];
                }
            }
            const bias = computeBias(slope, i, j);
            scores[j] = dot / @sqrt(@as(f32, @floatFromInt(head_dim))) + bias;
            if (scores[j] > max_score) max_score = scores[j];
        }

        // Softmax
        var sum_exp: f32 = 0;
        for (scores[0..actual_len]) |*s| {
            s.* = @exp(s.* - max_score);
            sum_exp += s.*;
        }

        // Output
        for (0..head_dim) |d| {
            var acc: f32 = 0;
            for (0..actual_len) |j| {
                const v_idx = j * head_dim + d;
                if (v_idx < v.len) {
                    acc += (scores[j] / sum_exp) * v[v_idx];
                }
            }
            const out_idx = i * head_dim + d;
            if (out_idx < output.len) {
                output[out_idx] = acc;
            }
        }
    }
}

pub fn verifySymmetric(pos_i: usize, pos_j: usize, slope: f32) bool {
    const bias_ij = computeBias(slope, pos_i, pos_j);
    const bias_ji = computeBias(slope, pos_j, pos_i);
    return @abs(bias_ij - bias_ji) < 1e-6;
}

// Tests
test "slopes geometric" {
    const slopes = computeSlopes(8);
    // Should form geometric sequence
    try testing.expect(slopes[0] > slopes[1]);
    try testing.expect(slopes[1] > slopes[2]);
}

test "phi slopes" {
    const slopes = phiSlopes(12);
    // φ^(-1) ≈ 0.618
    try testing.expectApproxEqAbs(@as(f32, 0.618), slopes[0], 0.01);
    // φ^(-2) ≈ 0.382
    try testing.expectApproxEqAbs(@as(f32, 0.382), slopes[1], 0.01);
}

test "bias symmetric" {
    try testing.expect(verifySymmetric(5, 3, 0.1));
    try testing.expect(verifySymmetric(10, 2, 0.05));
}

test "extrapolation" {
    // ALiBi naturally extrapolates - bias just increases linearly
    const bias_512 = computeBias(0.1, 0, 512);
    const bias_2048 = computeBias(0.1, 0, 2048);
    try testing.expect(bias_2048 < bias_512);
    try testing.expect(!math.isNan(bias_2048));
}

test "alibi forward" {
    const q = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const k = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const v = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;
    const slopes = computeSlopes(1);

    alibiAttention(&q, &k, &v, &output, &slopes, 2, 0);
    try testing.expect(!math.isNan(output[0]));
}

test "config defaults" {
    const config = ALiBiConfig{};
    try testing.expect(config.num_heads == 12);
    try testing.expect(!config.use_phi_slopes);
}
