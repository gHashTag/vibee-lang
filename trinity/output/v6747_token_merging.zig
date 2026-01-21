// v6747_token_merging.zig - Token Merging (ToMe)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const ToMeConfig = struct {
    merge_ratio: f32 = 0.5,
    similarity_threshold: f32 = 0.9,
};

pub fn phiMergeRatio() f32 {
    return @floatCast(1.0 - PHI_INV); // Merge 38.2%
}

pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    const n = @min(a.len, b.len);
    var dot: f64 = 0;
    var norm_a: f64 = 0;
    var norm_b: f64 = 0;

    for (0..n) |i| {
        dot += @as(f64, a[i]) * @as(f64, b[i]);
        norm_a += @as(f64, a[i]) * @as(f64, a[i]);
        norm_b += @as(f64, b[i]) * @as(f64, b[i]);
    }

    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    if (denom < 1e-10) return 0;
    return @floatCast(dot / denom);
}

pub fn findMostSimilar(tokens: []const []const f32, idx: usize) struct { partner: usize, similarity: f32 } {
    var best_partner: usize = 0;
    var best_sim: f32 = -1.0;

    for (tokens, 0..) |other, j| {
        if (j != idx) {
            const sim = cosineSimilarity(tokens[idx], other);
            if (sim > best_sim) {
                best_sim = sim;
                best_partner = j;
            }
        }
    }
    return .{ .partner = best_partner, .similarity = best_sim };
}

pub fn mergeTokenPair(a: []const f32, b: []const f32, output: []f32) void {
    const n = @min(@min(a.len, b.len), output.len);
    for (0..n) |i| {
        output[i] = (a[i] + b[i]) * 0.5;
    }
}

pub fn computeSpeedup(original_tokens: usize, merge_ratio: f32) f32 {
    const remaining = @as(f32, @floatFromInt(original_tokens)) * (1.0 - merge_ratio);
    const original_f = @as(f32, @floatFromInt(original_tokens));
    // Attention is O(N²), so speedup is (N/N')²
    return (original_f * original_f) / (remaining * remaining);
}

pub fn tokensAfterMerge(original: usize, merge_ratio: f32) usize {
    return @intFromFloat(@as(f32, @floatFromInt(original)) * (1.0 - merge_ratio));
}

// Tests
test "phi merge ratio" {
    const ratio = phiMergeRatio();
    try testing.expect(@abs(ratio - 0.382) < 0.01);
}

test "cosine similarity identical" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const b = [_]f32{ 1.0, 0.0, 0.0 };
    const sim = cosineSimilarity(&a, &b);
    try testing.expect(@abs(sim - 1.0) < 0.01);
}

test "cosine similarity orthogonal" {
    const a = [_]f32{ 1.0, 0.0 };
    const b = [_]f32{ 0.0, 1.0 };
    const sim = cosineSimilarity(&a, &b);
    try testing.expect(@abs(sim) < 0.01);
}

test "merge token pair" {
    const a = [_]f32{ 1.0, 2.0 };
    const b = [_]f32{ 3.0, 4.0 };
    var output: [2]f32 = undefined;
    mergeTokenPair(&a, &b, &output);
    try testing.expectEqual(@as(f32, 2.0), output[0]);
}

test "speedup calculation" {
    const speedup = computeSpeedup(100, 0.5);
    try testing.expect(speedup > 3.5); // (100/50)² = 4
}

test "tokens after merge" {
    const remaining = tokensAfterMerge(100, 0.3);
    try testing.expectEqual(@as(usize, 70), remaining);
}
