// ═══════════════════════════════════════════════════════════════════════════════
// qml_matryoshka v1.0.0 - Вложенные эмбеддинги
// Matryoshka Representation Learning для адаптивных размеров
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: arXiv:2205.13147
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

// Standard Matryoshka dimensions for MiniLM (384-dim base)
pub const MATRYOSHKA_DIMS = [_]usize{ 384, 256, 128, 64, 32, 16, 8 };

// PHI-based Matryoshka dimensions
pub const PHI_MATRYOSHKA_DIMS = [_]usize{ 384, 237, 147, 91, 56, 35, 21, 13, 8 };

pub const MatryoshkaConfig = struct {
    full_dim: usize = 384,
    nesting_dims: []const usize = &MATRYOSHKA_DIMS,
    use_phi_weights: bool = true,
};

// Truncate embedding to target dimension
pub fn truncateEmbedding(full: []const f32, truncated: []f32, target_dim: usize) void {
    const copy_len = @min(full.len, @min(truncated.len, target_dim));
    for (0..copy_len) |i| {
        truncated[i] = full[i];
    }
}

// Compute L2 norm
pub fn l2Norm(vec: []const f32) f32 {
    var sum: f32 = 0;
    for (vec) |v| {
        sum += v * v;
    }
    return @sqrt(sum);
}

// Normalize embedding
pub fn normalizeEmbedding(vec: []f32) void {
    const norm = l2Norm(vec);
    if (norm > 0) {
        for (vec) |*v| {
            v.* /= norm;
        }
    }
}

// Cosine similarity
pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    const len = @min(a.len, b.len);
    var dot: f32 = 0;
    var norm_a: f32 = 0;
    var norm_b: f32 = 0;
    for (0..len) |i| {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }
    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    if (denom == 0) return 0;
    return dot / denom;
}

// PHI-weighted loss weight for dimension level
pub fn phiLossWeight(level: usize) f32 {
    var weight: f64 = 1.0;
    for (0..level) |_| {
        weight *= PHI_INV;
    }
    return @floatCast(weight);
}

// Compute Matryoshka contrastive loss at single dimension
pub fn matryoshkaLossAtDim(
    anchor: []const f32,
    positive: []const f32,
    negatives: []const []const f32,
    dim: usize,
    temperature: f32,
) f32 {
    // Truncate to target dimension
    var anchor_trunc: [384]f32 = undefined;
    var positive_trunc: [384]f32 = undefined;
    truncateEmbedding(anchor, anchor_trunc[0..dim], dim);
    truncateEmbedding(positive, positive_trunc[0..dim], dim);

    // Normalize
    normalizeEmbedding(anchor_trunc[0..dim]);
    normalizeEmbedding(positive_trunc[0..dim]);

    // Positive similarity
    const pos_sim = cosineSimilarity(anchor_trunc[0..dim], positive_trunc[0..dim]) / temperature;

    // Negative similarities
    var neg_sum: f32 = 0;
    for (negatives) |neg| {
        var neg_trunc: [384]f32 = undefined;
        truncateEmbedding(neg, neg_trunc[0..dim], dim);
        normalizeEmbedding(neg_trunc[0..dim]);
        const neg_sim = cosineSimilarity(anchor_trunc[0..dim], neg_trunc[0..dim]) / temperature;
        neg_sum += @exp(neg_sim);
    }

    // InfoNCE loss: -log(exp(pos) / (exp(pos) + sum(exp(neg))))
    const exp_pos = @exp(pos_sim);
    return -@log(exp_pos / (exp_pos + neg_sum + 1e-8));
}

// Compute total Matryoshka loss across all dimensions
pub fn matryoshkaTotalLoss(
    anchor: []const f32,
    positive: []const f32,
    negatives: []const []const f32,
    config: MatryoshkaConfig,
    temperature: f32,
) f32 {
    var total_loss: f32 = 0;
    var total_weight: f32 = 0;

    for (config.nesting_dims, 0..) |dim, level| {
        const weight = if (config.use_phi_weights) phiLossWeight(level) else 1.0;
        const loss = matryoshkaLossAtDim(anchor, positive, negatives, dim, temperature);
        total_loss += weight * loss;
        total_weight += weight;
    }

    return total_loss / total_weight;
}

// Find optimal dimension for latency budget
pub fn adaptiveDimension(
    latency_budget_ms: f32,
    base_latency_ms: f32,
    full_dim: usize,
    dims: []const usize,
) usize {
    // Latency scales roughly linearly with dimension
    for (dims) |dim| {
        const estimated_latency = base_latency_ms * @as(f32, @floatFromInt(dim)) / @as(f32, @floatFromInt(full_dim));
        if (estimated_latency <= latency_budget_ms) {
            return dim;
        }
    }
    return dims[dims.len - 1]; // Return smallest if nothing fits
}

// PHI-optimal nesting dimensions
pub fn phiNestingDims(base_dim: usize, num_levels: usize, output: []usize) usize {
    var dim: f64 = @floatFromInt(base_dim);
    const levels = @min(num_levels, output.len);
    for (0..levels) |i| {
        output[i] = @max(1, @as(usize, @intFromFloat(@round(dim))));
        dim *= PHI_INV;
    }
    return levels;
}

// Tests
test "truncate embedding" {
    const full = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    var truncated: [3]f32 = undefined;
    truncateEmbedding(&full, &truncated, 3);
    try testing.expectApproxEqAbs(@as(f32, 1.0), truncated[0], 0.001);
    try testing.expectApproxEqAbs(@as(f32, 3.0), truncated[2], 0.001);
}

test "l2 norm" {
    const vec = [_]f32{ 3.0, 4.0 };
    try testing.expectApproxEqAbs(@as(f32, 5.0), l2Norm(&vec), 0.001);
}

test "normalize embedding" {
    var vec = [_]f32{ 3.0, 4.0 };
    normalizeEmbedding(&vec);
    try testing.expectApproxEqAbs(@as(f32, 0.6), vec[0], 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.8), vec[1], 0.001);
}

test "cosine similarity" {
    const a = [_]f32{ 1.0, 0.0 };
    const b = [_]f32{ 1.0, 0.0 };
    try testing.expectApproxEqAbs(@as(f32, 1.0), cosineSimilarity(&a, &b), 0.001);

    const c = [_]f32{ 0.0, 1.0 };
    try testing.expectApproxEqAbs(@as(f32, 0.0), cosineSimilarity(&a, &c), 0.001);
}

test "phi loss weight" {
    try testing.expectApproxEqAbs(@as(f32, 1.0), phiLossWeight(0), 0.001);
    try testing.expectApproxEqAbs(@as(f32, @floatCast(PHI_INV)), phiLossWeight(1), 0.001);
}

test "adaptive dimension" {
    const dims = [_]usize{ 384, 256, 128, 64, 32 };
    const dim = adaptiveDimension(5.0, 10.0, 384, &dims);
    try testing.expect(dim <= 256);
}

test "phi nesting dims" {
    var output: [10]usize = undefined;
    const n = phiNestingDims(384, 5, &output);
    try testing.expectEqual(@as(usize, 5), n);
    try testing.expectEqual(@as(usize, 384), output[0]);
    try testing.expect(output[1] < output[0]);
}
