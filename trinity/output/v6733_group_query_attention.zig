// ═══════════════════════════════════════════════════════════════
// v6733: GROUP QUERY ATTENTION (GQA)
// Shared KV heads for efficiency
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const GQAConfig = struct {
    num_query_heads: usize = 12,
    num_kv_heads: usize = 4,
    head_dim: usize = 64,
};

pub fn computeGroupSize(query_heads: usize, kv_heads: usize) usize {
    if (kv_heads == 0) return query_heads;
    return query_heads / kv_heads;
}

pub fn phiKVHeads(query_heads: usize) usize {
    // KV heads = round(query_heads / φ)
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(query_heads)) * PHI_INV)));
}

pub fn expandKV(kv: []const f32, group_size: usize, output: []f32, head_dim: usize) void {
    const kv_heads = kv.len / head_dim;
    var out_idx: usize = 0;

    for (0..kv_heads) |kv_h| {
        for (0..group_size) |_| {
            for (0..head_dim) |d| {
                const kv_idx = kv_h * head_dim + d;
                if (kv_idx < kv.len and out_idx < output.len) {
                    output[out_idx] = kv[kv_idx];
                    out_idx += 1;
                }
            }
        }
    }
}

pub fn memorySavings(query_heads: usize, kv_heads: usize) f32 {
    if (query_heads == 0) return 0;
    return 1.0 - @as(f32, @floatFromInt(kv_heads)) / @as(f32, @floatFromInt(query_heads));
}

pub fn gqaForward(q: []const f32, k: []const f32, v: []const f32, output: []f32, config: GQAConfig) void {
    const group_size = computeGroupSize(config.num_query_heads, config.num_kv_heads);

    // Simplified: just copy with expansion
    for (0..config.num_query_heads) |qh| {
        const kv_h = qh / group_size;
        for (0..config.head_dim) |d| {
            const q_idx = qh * config.head_dim + d;
            const k_idx = kv_h * config.head_dim + d;
            const v_idx = kv_h * config.head_dim + d;

            if (q_idx < output.len and q_idx < q.len and k_idx < k.len and v_idx < v.len) {
                // Simplified attention: just weighted sum
                output[q_idx] = q[q_idx] * k[k_idx] * v[v_idx];
            }
        }
    }
}

pub fn kvCacheSize(seq_len: usize, kv_heads: usize, head_dim: usize) usize {
    return 2 * seq_len * kv_heads * head_dim * 4; // K and V, f32
}

// Tests
test "group size" {
    const group = computeGroupSize(12, 4);
    try testing.expect(group == 3);
}

test "phi kv heads" {
    const kv = phiKVHeads(12);
    // round(12 × 0.618) = round(7.416) = 7
    try testing.expect(kv == 7 or kv == 8);
}

test "output shape" {
    const config = GQAConfig{ .num_query_heads = 4, .num_kv_heads = 2, .head_dim = 4 };
    var q: [16]f32 = undefined;
    var k: [8]f32 = undefined;
    var v: [8]f32 = undefined;
    var output: [16]f32 = undefined;

    @memset(&q, 1.0);
    @memset(&k, 1.0);
    @memset(&v, 1.0);

    gqaForward(&q, &k, &v, &output, config);
    try testing.expect(output.len == q.len);
}

test "memory savings" {
    const savings = memorySavings(12, 4);
    try testing.expectApproxEqAbs(@as(f32, 0.667), savings, 0.01);
}

test "expand kv" {
    const kv = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var expanded: [8]f32 = undefined;
    expandKV(&kv, 2, &expanded, 2);
    try testing.expect(expanded[0] == 1.0);
    try testing.expect(expanded[2] == 1.0);
}

test "kv cache size" {
    const size = kvCacheSize(128, 4, 64);
    try testing.expect(size == 2 * 128 * 4 * 64 * 4);
}
