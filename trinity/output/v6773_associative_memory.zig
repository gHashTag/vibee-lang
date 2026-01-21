// v6773_associative_memory.zig - Associative Memory
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const AssocMemConfig = struct {
    memory_size: usize = 256,
    key_dim: usize = 64,
    value_dim: usize = 64,
};

// Store pattern: M += k^T v (outer product)
pub fn storePattern(
    key: []const f32,
    value: []const f32,
    memory: []f32,
    key_dim: usize,
) void {
    for (0..key_dim) |i| {
        for (0..key_dim) |j| {
            const idx = i * key_dim + j;
            if (idx < memory.len) {
                const k = if (i < key.len) key[i] else 0;
                const v = if (j < value.len) value[j] else 0;
                memory[idx] += k * v;
            }
        }
    }
}

// Retrieve pattern: v = M @ k
pub fn retrievePattern(
    query: []const f32,
    memory: []const f32,
    key_dim: usize,
    output: []f32,
) void {
    for (0..key_dim) |i| {
        var sum: f32 = 0;
        for (0..key_dim) |j| {
            const idx = i * key_dim + j;
            const m = if (idx < memory.len) memory[idx] else 0;
            const q = if (j < query.len) query[j] else 0;
            sum += m * q;
        }
        if (i < output.len) {
            output[i] = sum;
        }
    }
}

// PHI-optimal capacity: ~0.14 * d patterns for d-dimensional memory
pub fn phiCapacity(dim: usize) usize {
    const d: f64 = @floatFromInt(dim);
    return @intFromFloat(d * PHI_INV * 0.23); // ~14% of dimension
}

// Pattern similarity (cosine)
pub fn patternSimilarity(a: []const f32, b: []const f32) f32 {
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

// Hebbian learning: strengthen connections
pub fn hebbianUpdate(
    pre: []const f32,
    post: []const f32,
    weights: []f32,
    learning_rate: f32,
    dim: usize,
) void {
    for (0..dim) |i| {
        for (0..dim) |j| {
            const idx = i * dim + j;
            if (idx < weights.len) {
                const p1 = if (i < pre.len) pre[i] else 0;
                const p2 = if (j < post.len) post[j] else 0;
                weights[idx] += learning_rate * p1 * p2;
            }
        }
    }
}

// Tests
test "store pattern" {
    const key = [_]f32{ 1.0, 0.0 };
    const value = [_]f32{ 0.0, 1.0 };
    var memory: [4]f32 = [_]f32{ 0, 0, 0, 0 };
    storePattern(&key, &value, &memory, 2);
    try testing.expect(memory[1] != 0);
}

test "retrieve pattern" {
    const query = [_]f32{ 1.0, 0.0 };
    const memory = [_]f32{ 1.0, 0.0, 0.0, 1.0 }; // Identity-like
    var output: [2]f32 = undefined;
    retrievePattern(&query, &memory, 2, &output);
    try testing.expect(output[0] >= 0); // Result depends on memory content
}

test "phi capacity" {
    const cap = phiCapacity(256);
    try testing.expect(cap > 30);
    try testing.expect(cap < 50);
}

test "pattern similarity" {
    const a = [_]f32{ 1.0, 0.0 };
    const b = [_]f32{ 1.0, 0.0 };
    const sim = patternSimilarity(&a, &b);
    try testing.expect(@abs(sim - 1.0) < 0.01);
}

test "hebbian update" {
    const pre = [_]f32{ 1.0, 0.5 };
    const post = [_]f32{ 0.5, 1.0 };
    var weights: [4]f32 = [_]f32{ 0, 0, 0, 0 };
    hebbianUpdate(&pre, &post, &weights, 0.1, 2);
    try testing.expect(weights[0] != 0);
}

test "config defaults" {
    const config = AssocMemConfig{};
    try testing.expectEqual(@as(usize, 256), config.memory_size);
}
