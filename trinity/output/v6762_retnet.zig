// v6762_retnet.zig - RetNet (Retentive Network)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const RetNetConfig = struct {
    hidden_dim: usize = 256,
    num_heads: usize = 4,
    gamma: f32 = 0.99,
};

// Decay matrix D for parallel mode
pub fn computeDecayMatrix(size: usize, gamma: f32, matrix: []f32) void {
    for (0..size) |i| {
        for (0..size) |j| {
            const idx = i * size + j;
            if (idx < matrix.len) {
                if (i >= j) {
                    matrix[idx] = math.pow(f32, gamma, @as(f32, @floatFromInt(i - j)));
                } else {
                    matrix[idx] = 0;
                }
            }
        }
    }
}

// Parallel retention: Y = (QK^T ⊙ D) V
pub fn parallelRetention(
    q: []const f32,
    k: []const f32,
    v: []const f32,
    gamma: f32,
    seq_len: usize,
    output: []f32,
) void {
    for (0..seq_len) |i| {
        var sum: f32 = 0;
        for (0..i + 1) |j| {
            const decay = math.pow(f32, gamma, @as(f32, @floatFromInt(i - j)));
            const q_val = if (i < q.len) q[i] else 0;
            const k_val = if (j < k.len) k[j] else 0;
            const v_val = if (j < v.len) v[j] else 0;
            sum += q_val * k_val * decay * v_val;
        }
        if (i < output.len) {
            output[i] = sum;
        }
    }
}

// Recurrent retention: s_n = γ s_{n-1} + k_n^T v_n
pub fn recurrentRetention(
    k: f32,
    v: f32,
    prev_state: f32,
    gamma: f32,
) struct { output: f32, new_state: f32 } {
    const new_state = gamma * prev_state + k * v;
    return .{ .output = new_state, .new_state = new_state };
}

// Query the recurrent state
pub fn queryState(q: f32, state: f32) f32 {
    return q * state;
}

pub fn phiGamma(head_idx: usize, _: usize) f32 {
    // Different gamma per head, PHI-scaled
    const base: f64 = 1.0 - math.pow(f64, 2.0, -5.0 - @as(f64, @floatFromInt(head_idx)));
    return @floatCast(base * PHI_INV + (1.0 - PHI_INV));
}

pub fn chunkwiseRetention(
    chunk_q: []const f32,
    chunk_k: []const f32,
    chunk_v: []const f32,
    prev_state: f32,
    gamma: f32,
    output: []f32,
) f32 {
    var state = prev_state;
    const n = @min(@min(chunk_q.len, chunk_k.len), @min(chunk_v.len, output.len));

    for (0..n) |i| {
        state = gamma * state + chunk_k[i] * chunk_v[i];
        output[i] = chunk_q[i] * state;
    }

    return state;
}

// Tests
test "compute decay matrix" {
    var matrix: [9]f32 = undefined;
    computeDecayMatrix(3, 0.9, &matrix);
    try testing.expectEqual(@as(f32, 1.0), matrix[0]); // D[0,0]
    try testing.expect(matrix[3] > 0); // D[1,0]
}

test "parallel retention" {
    const q = [_]f32{ 1.0, 1.0, 1.0 };
    const k = [_]f32{ 1.0, 1.0, 1.0 };
    const v = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [3]f32 = undefined;
    parallelRetention(&q, &k, &v, 0.9, 3, &output);
    try testing.expect(output[2] > output[0]);
}

test "recurrent retention" {
    const result = recurrentRetention(1.0, 2.0, 0.5, 0.9);
    try testing.expect(result.new_state > 2.0);
}

test "phi gamma" {
    const g0 = phiGamma(0, 4);
    const g3 = phiGamma(3, 4);
    try testing.expect(g0 != g3);
    try testing.expect(g0 > 0.9);
}

test "chunkwise retention" {
    const q = [_]f32{ 1.0, 1.0 };
    const k = [_]f32{ 1.0, 1.0 };
    const v = [_]f32{ 1.0, 2.0 };
    var output: [2]f32 = undefined;
    const final = chunkwiseRetention(&q, &k, &v, 0, 0.9, &output);
    try testing.expect(final > 0);
}

test "config defaults" {
    const config = RetNetConfig{};
    try testing.expectEqual(@as(f32, 0.99), config.gamma);
}
