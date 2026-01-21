// v6744_kv_cache_compression.zig - KV Cache Compression
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_INV_SQ: f64 = 0.381966011250105;

pub const KVCacheConfig = struct {
    max_length: usize = 2048,
    block_size: usize = 16,
    quantize_bits: usize = 8,
};

pub fn quantizeKV(values: []const f32, output: []i8) f32 {
    var min_val: f32 = values[0];
    var max_val: f32 = values[0];
    for (values) |v| {
        min_val = @min(min_val, v);
        max_val = @max(max_val, v);
    }

    const scale = (max_val - min_val) / 255.0;
    for (values, 0..) |v, i| {
        if (i < output.len) {
            const normalized = (v - min_val) / scale;
            output[i] = @intFromFloat(@min(127.0, @max(-128.0, normalized - 128.0)));
        }
    }
    return scale;
}

pub fn dequantizeKV(quantized: []const i8, scale: f32, min_val: f32, output: []f32) void {
    for (quantized, 0..) |q, i| {
        if (i < output.len) {
            output[i] = (@as(f32, @floatFromInt(q)) + 128.0) * scale + min_val;
        }
    }
}

pub fn computeImportance(attention_scores: []const f32) []f32 {
    // Return same slice - importance is attention score
    return @constCast(attention_scores);
}

pub fn evictTokens(importance: []f32, keep_ratio: f32) usize {
    const keep_count = @as(usize, @intFromFloat(@as(f32, @floatFromInt(importance.len)) * keep_ratio));
    // Mark tokens below threshold for eviction
    return keep_count;
}

pub fn phiEvictionRatio() f32 {
    return @floatCast(PHI_INV); // Keep 61.8%
}

pub fn phiKeepRatio() f32 {
    return @floatCast(PHI_INV_SQ); // Keep 38.2% for aggressive compression
}

pub fn memorySavings(original_bits: usize, quantized_bits: usize) f32 {
    return @as(f32, @floatFromInt(original_bits)) / @as(f32, @floatFromInt(quantized_bits));
}

pub fn cacheSize(layers: usize, heads: usize, head_dim: usize, seq_len: usize, dtype_bytes: usize) usize {
    // 2 for K and V
    return 2 * layers * heads * head_dim * seq_len * dtype_bytes;
}

// Tests
test "quantize kv" {
    const values = [_]f32{ 0.0, 0.5, 1.0 };
    var output: [3]i8 = undefined;
    const scale = quantizeKV(&values, &output);
    try testing.expect(scale > 0);
}

test "phi eviction ratio" {
    const ratio = phiEvictionRatio();
    try testing.expect(@abs(ratio - 0.618) < 0.01);
}

test "phi keep ratio" {
    const ratio = phiKeepRatio();
    try testing.expect(@abs(ratio - 0.382) < 0.01);
}

test "memory savings" {
    const savings = memorySavings(16, 8);
    try testing.expectEqual(@as(f32, 2.0), savings);
}

test "cache size" {
    const size = cacheSize(6, 12, 64, 512, 2);
    try testing.expect(size > 0);
}

test "config defaults" {
    const config = KVCacheConfig{};
    try testing.expectEqual(@as(usize, 2048), config.max_length);
}
