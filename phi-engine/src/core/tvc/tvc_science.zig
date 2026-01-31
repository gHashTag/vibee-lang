// ═══════════════════════════════════════════════════════════════════════════════
// TVC SCIENCE API - Statistics, Distances, Information Theory
// ═══════════════════════════════════════════════════════════════════════════════
//
// Science API for TVC (Ternary Vector Computing)
// Provides statistics, distances, and information theory functions
// for hyperdimensional computing research.
//
// Author: Dmitrii Vasilev
// Co-authored-by: Ona <no-reply@ona.com>
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const StatisticsResult = struct {
    mean: f64,
    variance: f64,
    std_dev: f64,
    min: f64,
    max: f64,
    count: usize,
};

pub const EntropyResult = struct {
    entropy: f64,
    max_entropy: f64,
    normalized: f64,
};

pub const MutualInfoResult = struct {
    mutual_info: f64,
    normalized_mi: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute comprehensive statistics for an array of values
pub fn computeStatistics(values: []const f64) StatisticsResult {
    if (values.len == 0) {
        return StatisticsResult{
            .mean = 0,
            .variance = 0,
            .std_dev = 0,
            .min = 0,
            .max = 0,
            .count = 0,
        };
    }

    var sum: f64 = 0;
    var min_val: f64 = values[0];
    var max_val: f64 = values[0];

    for (values) |v| {
        sum += v;
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
    }

    const mean = sum / @as(f64, @floatFromInt(values.len));

    var variance_sum: f64 = 0;
    for (values) |v| {
        const diff = v - mean;
        variance_sum += diff * diff;
    }

    const variance = variance_sum / @as(f64, @floatFromInt(values.len));
    const std_dev = @sqrt(variance);

    return StatisticsResult{
        .mean = mean,
        .variance = variance,
        .std_dev = std_dev,
        .min = min_val,
        .max = max_val,
        .count = values.len,
    };
}

/// Compute arithmetic mean
pub fn computeMean(values: []const f64) f64 {
    if (values.len == 0) return 0;
    var sum: f64 = 0;
    for (values) |v| sum += v;
    return sum / @as(f64, @floatFromInt(values.len));
}

/// Compute population variance
pub fn computeVariance(values: []const f64) f64 {
    if (values.len == 0) return 0;
    const mean = computeMean(values);
    var sum: f64 = 0;
    for (values) |v| {
        const diff = v - mean;
        sum += diff * diff;
    }
    return sum / @as(f64, @floatFromInt(values.len));
}

/// Compute population standard deviation
pub fn computeStdDev(values: []const f64) f64 {
    return @sqrt(computeVariance(values));
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISTANCE METRICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Euclidean distance: sqrt(sum((a-b)^2))
pub fn euclideanDistance(a: []const f64, b: []const f64) f64 {
    if (a.len != b.len) return math.inf(f64);
    var sum: f64 = 0;
    for (a, b) |av, bv| {
        const diff = av - bv;
        sum += diff * diff;
    }
    return @sqrt(sum);
}

/// Manhattan distance: sum(|a-b|)
pub fn manhattanDistance(a: []const f64, b: []const f64) f64 {
    if (a.len != b.len) return math.inf(f64);
    var sum: f64 = 0;
    for (a, b) |av, bv| {
        sum += @abs(av - bv);
    }
    return sum;
}

/// Chebyshev distance: max(|a-b|)
pub fn chebyshevDistance(a: []const f64, b: []const f64) f64 {
    if (a.len != b.len) return math.inf(f64);
    var max_diff: f64 = 0;
    for (a, b) |av, bv| {
        const diff = @abs(av - bv);
        if (diff > max_diff) max_diff = diff;
    }
    return max_diff;
}

/// Minkowski distance: (sum(|a-b|^p))^(1/p)
pub fn minkowskiDistance(a: []const f64, b: []const f64, p: f64) f64 {
    if (a.len != b.len) return math.inf(f64);
    if (p <= 0) return math.inf(f64);
    var sum: f64 = 0;
    for (a, b) |av, bv| {
        sum += math.pow(f64, @abs(av - bv), p);
    }
    return math.pow(f64, sum, 1.0 / p);
}

/// Cosine distance: 1 - cosine_similarity
pub fn cosineDistance(a: []const f64, b: []const f64) f64 {
    return 1.0 - cosineSimilarity(a, b);
}

/// Cosine similarity: dot(a,b) / (|a| * |b|)
pub fn cosineSimilarity(a: []const f64, b: []const f64) f64 {
    if (a.len != b.len) return 0;
    var dot: f64 = 0;
    var norm_a: f64 = 0;
    var norm_b: f64 = 0;
    for (a, b) |av, bv| {
        dot += av * bv;
        norm_a += av * av;
        norm_b += bv * bv;
    }
    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    if (denom == 0) return 0;
    return dot / denom;
}

/// Normalized Hamming distance: count(a != b) / length
pub fn hammingDistanceNormalized(a: []const f64, b: []const f64) f64 {
    if (a.len != b.len) return 1.0;
    if (a.len == 0) return 0;
    var diff_count: usize = 0;
    for (a, b) |av, bv| {
        if (av != bv) diff_count += 1;
    }
    return @as(f64, @floatFromInt(diff_count)) / @as(f64, @floatFromInt(a.len));
}

/// Jaccard distance: 1 - (intersection / union)
pub fn jaccardDistance(a: []const f64, b: []const f64) f64 {
    if (a.len != b.len) return 1.0;
    var intersection: f64 = 0;
    var union_size: f64 = 0;
    for (a, b) |av, bv| {
        const a_bool = if (av != 0) @as(f64, 1) else @as(f64, 0);
        const b_bool = if (bv != 0) @as(f64, 1) else @as(f64, 0);
        intersection += @min(a_bool, b_bool);
        union_size += @max(a_bool, b_bool);
    }
    if (union_size == 0) return 0;
    return 1.0 - (intersection / union_size);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFORMATION THEORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Shannon entropy: -sum(p * log2(p))
pub fn shannonEntropy(probs: []const f64) f64 {
    var entropy: f64 = 0;
    for (probs) |p| {
        if (p > 0) {
            entropy -= p * math.log2(p);
        }
    }
    return entropy;
}

/// Compute entropy result with normalization
pub fn computeEntropy(probs: []const f64) EntropyResult {
    const entropy = shannonEntropy(probs);
    const max_entropy = math.log2(@as(f64, @floatFromInt(probs.len)));
    const normalized = if (max_entropy > 0) entropy / max_entropy else 0;
    return EntropyResult{
        .entropy = entropy,
        .max_entropy = max_entropy,
        .normalized = normalized,
    };
}

/// KL divergence: sum(P * log(P/Q))
pub fn klDivergence(p: []const f64, q: []const f64) f64 {
    if (p.len != q.len) return math.inf(f64);
    var kl: f64 = 0;
    for (p, q) |pv, qv| {
        if (pv > 0 and qv > 0) {
            kl += pv * @log(pv / qv);
        } else if (pv > 0 and qv == 0) {
            return math.inf(f64);
        }
    }
    return kl;
}

/// Cross entropy: -sum(P * log(Q))
pub fn crossEntropy(p: []const f64, q: []const f64) f64 {
    if (p.len != q.len) return math.inf(f64);
    var ce: f64 = 0;
    for (p, q) |pv, qv| {
        if (pv > 0) {
            if (qv > 0) {
                ce -= pv * @log(qv);
            } else {
                return math.inf(f64);
            }
        }
    }
    return ce;
}

/// Mutual information: I(X;Y) = H(X) + H(Y) - H(X,Y)
/// Approximated using correlation-based approach
pub fn mutualInformation(x: []const f64, y: []const f64) MutualInfoResult {
    if (x.len != y.len or x.len == 0) {
        return MutualInfoResult{ .mutual_info = 0, .normalized_mi = 0 };
    }

    // Use correlation as proxy for MI
    const corr = correlationCoefficient(x, y);
    // MI ≈ -0.5 * log(1 - r²) for Gaussian variables
    const r_sq = corr * corr;
    const mi = if (r_sq < 1) -0.5 * @log(1.0 - r_sq) else math.inf(f64);

    return MutualInfoResult{
        .mutual_info = mi,
        .normalized_mi = @abs(corr),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CORRELATION & COVARIANCE
// ═══════════════════════════════════════════════════════════════════════════════

/// Pearson correlation coefficient [-1, 1]
pub fn correlationCoefficient(x: []const f64, y: []const f64) f64 {
    if (x.len != y.len or x.len == 0) return 0;

    const mean_x = computeMean(x);
    const mean_y = computeMean(y);

    var cov: f64 = 0;
    var var_x: f64 = 0;
    var var_y: f64 = 0;

    for (x, y) |xv, yv| {
        const dx = xv - mean_x;
        const dy = yv - mean_y;
        cov += dx * dy;
        var_x += dx * dx;
        var_y += dy * dy;
    }

    const denom = @sqrt(var_x) * @sqrt(var_y);
    if (denom == 0) return 0;
    return cov / denom;
}

/// Covariance
pub fn covariance(x: []const f64, y: []const f64) f64 {
    if (x.len != y.len or x.len == 0) return 0;

    const mean_x = computeMean(x);
    const mean_y = computeMean(y);

    var cov: f64 = 0;
    for (x, y) |xv, yv| {
        cov += (xv - mean_x) * (yv - mean_y);
    }
    return cov / @as(f64, @floatFromInt(x.len));
}

// ═══════════════════════════════════════════════════════════════════════════════
// VECTOR OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// L2 normalize vector (returns unit vector)
pub fn normalizeVector(allocator: std.mem.Allocator, v: []const f64) ![]f64 {
    var norm: f64 = 0;
    for (v) |val| norm += val * val;
    norm = @sqrt(norm);

    const result = try allocator.alloc(f64, v.len);
    if (norm == 0) {
        @memset(result, 0);
    } else {
        for (result, v) |*r, val| {
            r.* = val / norm;
        }
    }
    return result;
}

/// Softmax: exp(x) / sum(exp(x))
pub fn softmax(allocator: std.mem.Allocator, logits: []const f64) ![]f64 {
    const result = try allocator.alloc(f64, logits.len);

    // Find max for numerical stability
    var max_val: f64 = logits[0];
    for (logits) |v| {
        if (v > max_val) max_val = v;
    }

    // Compute exp(x - max) and sum
    var sum: f64 = 0;
    for (result, logits) |*r, v| {
        r.* = @exp(v - max_val);
        sum += r.*;
    }

    // Normalize
    for (result) |*r| {
        r.* /= sum;
    }

    return result;
}

/// Log softmax (numerically stable)
pub fn logSoftmax(allocator: std.mem.Allocator, logits: []const f64) ![]f64 {
    const result = try allocator.alloc(f64, logits.len);

    // Find max for numerical stability
    var max_val: f64 = logits[0];
    for (logits) |v| {
        if (v > max_val) max_val = v;
    }

    // Compute log(sum(exp(x - max)))
    var sum: f64 = 0;
    for (logits) |v| {
        sum += @exp(v - max_val);
    }
    const log_sum = @log(sum) + max_val;

    // log_softmax = x - log_sum
    for (result, logits) |*r, v| {
        r.* = v - log_sum;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "statistics basic" {
    const values = [_]f64{ 1, 2, 3, 4, 5 };
    const stats = computeStatistics(&values);

    try std.testing.expectApproxEqAbs(@as(f64, 3.0), stats.mean, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), stats.variance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.414), stats.std_dev, 0.01);
    try std.testing.expectEqual(@as(f64, 1.0), stats.min);
    try std.testing.expectEqual(@as(f64, 5.0), stats.max);
    try std.testing.expectEqual(@as(usize, 5), stats.count);
}

test "euclidean distance" {
    const a = [_]f64{ 0, 0, 0 };
    const b = [_]f64{ 1, 1, 1 };
    const dist = euclideanDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.732), dist, 0.01);
}

test "manhattan distance" {
    const a = [_]f64{ 0, 0, 0 };
    const b = [_]f64{ 1, 2, 3 };
    const dist = manhattanDistance(&a, &b);
    try std.testing.expectEqual(@as(f64, 6.0), dist);
}

test "cosine similarity" {
    const a = [_]f64{ 1, 0, 0 };
    const b = [_]f64{ 1, 0, 0 };
    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);

    const c = [_]f64{ 1, 0, 0 };
    const d = [_]f64{ 0, 1, 0 };
    const sim2 = cosineSimilarity(&c, &d);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), sim2, 0.001);
}

test "shannon entropy" {
    // Uniform distribution has max entropy
    const uniform = [_]f64{ 0.25, 0.25, 0.25, 0.25 };
    const entropy = shannonEntropy(&uniform);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), entropy, 0.001);

    // Deterministic has zero entropy
    const deterministic = [_]f64{ 1.0, 0.0, 0.0, 0.0 };
    const entropy2 = shannonEntropy(&deterministic);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), entropy2, 0.001);
}

test "correlation coefficient" {
    const x = [_]f64{ 1, 2, 3, 4, 5 };
    const y = [_]f64{ 2, 4, 6, 8, 10 };
    const corr = correlationCoefficient(&x, &y);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), corr, 0.001);

    const z = [_]f64{ 5, 4, 3, 2, 1 };
    const corr2 = correlationCoefficient(&x, &z);
    try std.testing.expectApproxEqAbs(@as(f64, -1.0), corr2, 0.001);
}

test "softmax" {
    const allocator = std.testing.allocator;
    const logits = [_]f64{ 1, 2, 3 };
    const probs = try softmax(allocator, &logits);
    defer allocator.free(probs);

    // Sum should be 1
    var sum: f64 = 0;
    for (probs) |p| sum += p;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sum, 0.001);

    // Largest logit should have largest probability
    try std.testing.expect(probs[2] > probs[1]);
    try std.testing.expect(probs[1] > probs[0]);
}

test "normalize vector" {
    const allocator = std.testing.allocator;
    const v = [_]f64{ 3, 4 };
    const normalized = try normalizeVector(allocator, &v);
    defer allocator.free(normalized);

    // Should be unit vector
    var norm: f64 = 0;
    for (normalized) |val| norm += val * val;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), @sqrt(norm), 0.001);
}

test "kl divergence" {
    const p = [_]f64{ 0.5, 0.5 };
    const q = [_]f64{ 0.5, 0.5 };
    const kl = klDivergence(&p, &q);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), kl, 0.001);
}
