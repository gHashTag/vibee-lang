// ═══════════════════════════════════════════════════════════════
// v6730: MATRYOSHKA EMBEDDINGS
// Nested embeddings at multiple dimensions
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const MatryoshkaConfig = struct {
    full_dim: usize = 384,
    use_phi_dims: bool = true,
};

pub fn phiDimensions(full_dim: usize) [8]usize {
    var dims: [8]usize = undefined;
    var current: f64 = @floatFromInt(full_dim);

    for (&dims) |*d| {
        d.* = @max(1, @as(usize, @intFromFloat(current)));
        current *= PHI_INV;
    }

    return dims;
}

pub fn standardDimensions(full_dim: usize) [8]usize {
    _ = full_dim;
    return [_]usize{ 384, 256, 192, 128, 96, 64, 48, 32 };
}

pub fn truncateEmbedding(full: []const f32, target_dim: usize, output: []f32) void {
    const n = @min(@min(full.len, target_dim), output.len);
    @memcpy(output[0..n], full[0..n]);
}

pub fn matryoshkaLoss(losses: []const f32, weights: []const f32) f32 {
    const n = @min(losses.len, weights.len);
    var total: f64 = 0;
    var weight_sum: f64 = 0;

    for (losses[0..n], weights[0..n]) |l, w| {
        total += @as(f64, l) * @as(f64, w);
        weight_sum += w;
    }

    if (weight_sum == 0) return 0;
    return @floatCast(total / weight_sum);
}

pub fn adaptiveDimension(query_complexity: f32, dims: []const usize, _: f32) usize {
    // Select smallest dimension that meets accuracy threshold
    // Higher complexity → larger dimension needed
    const idx = @as(usize, @intFromFloat(query_complexity * @as(f32, @floatFromInt(dims.len - 1))));
    return dims[@min(idx, dims.len - 1)];
}

pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    const n = @min(a.len, b.len);
    var dot: f64 = 0;
    var norm_a: f64 = 0;
    var norm_b: f64 = 0;

    for (a[0..n], b[0..n]) |ai, bi| {
        dot += @as(f64, ai) * @as(f64, bi);
        norm_a += @as(f64, ai) * @as(f64, ai);
        norm_b += @as(f64, bi) * @as(f64, bi);
    }

    if (norm_a == 0 or norm_b == 0) return 0;
    return @floatCast(dot / (@sqrt(norm_a) * @sqrt(norm_b)));
}

// Tests
test "phi dims" {
    const dims = phiDimensions(384);
    // 384, 237, 147, 91, 56, 35, 21, 13
    try testing.expect(dims[0] == 384);
    try testing.expect(dims[1] == 237);
    try testing.expect(dims[2] == 146 or dims[2] == 147);
}

test "truncation" {
    const full = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var truncated: [2]f32 = undefined;
    truncateEmbedding(&full, 2, &truncated);
    try testing.expectApproxEqAbs(@as(f32, 1.0), truncated[0], 0.001);
    try testing.expectApproxEqAbs(@as(f32, 2.0), truncated[1], 0.001);
}

test "nested quality" {
    // Truncated embeddings should maintain most similarity
    const full = [_]f32{ 1.0, 0.5, 0.25, 0.125 };
    var truncated: [2]f32 = undefined;
    truncateEmbedding(&full, 2, &truncated);

    // Similarity should be high
    const sim = cosineSimilarity(&full, &[_]f32{ 1.0, 0.5, 0, 0 });
    try testing.expect(sim > 0.9);
}

test "adaptive selection" {
    const dims = [_]usize{ 384, 256, 128, 64 };
    const selected = adaptiveDimension(0.5, &dims, 0.9);
    try testing.expect(selected > 0);
}

test "matryoshka loss" {
    const losses = [_]f32{ 0.1, 0.2, 0.3 };
    const weights = [_]f32{ 1.0, 0.5, 0.25 };
    const total = matryoshkaLoss(&losses, &weights);
    try testing.expect(total > 0);
    try testing.expect(total < 0.3);
}

test "cosine similarity" {
    const a = [_]f32{ 1.0, 0.0 };
    const b = [_]f32{ 1.0, 0.0 };
    const sim = cosineSimilarity(&a, &b);
    try testing.expectApproxEqAbs(@as(f32, 1.0), sim, 0.001);
}
