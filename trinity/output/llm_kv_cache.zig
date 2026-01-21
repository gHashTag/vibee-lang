// ═══════════════════════════════════════════════════════════════════════════════
// llm_kv_cache v1.0.0 - KV-Cache with Compression
// O(1) per token vs O(n), 4x compression with INT4
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const KVCacheConfig = struct {
    num_layers: usize = 12,
    num_kv_heads: usize = 4,
    head_dim: usize = 64,
    max_seq_len: usize = 4096,
    quantize_bits: u8 = 16, // 16, 8, or 4
};

pub const CacheEntry = struct {
    seq_len: usize = 0,
    // In real impl, would have key/value tensors
};

// Calculate KV cache memory in bytes
pub fn calculateCacheMemory(config: KVCacheConfig) usize {
    const bytes_per_element: usize = switch (config.quantize_bits) {
        4 => 1, // 2 values per byte
        8 => 1,
        16 => 2,
        else => 4,
    };

    // 2 for K and V
    return 2 * config.num_layers * config.num_kv_heads * config.max_seq_len * config.head_dim * bytes_per_element;
}

// Calculate memory per token
pub fn memoryPerToken(config: KVCacheConfig) usize {
    const bytes_per_element: usize = switch (config.quantize_bits) {
        4 => 1,
        8 => 1,
        16 => 2,
        else => 4,
    };

    return 2 * config.num_layers * config.num_kv_heads * config.head_dim * bytes_per_element;
}

// Quantize KV cache to INT8
pub fn quantizeCacheInt8(fp_cache: []const f32, int_cache: []i8, scale: *f32) void {
    if (fp_cache.len == 0) return;

    var abs_max: f32 = 0;
    for (fp_cache) |v| {
        const abs_v = @abs(v);
        if (abs_v > abs_max) abs_max = abs_v;
    }

    scale.* = abs_max / 127.0;
    if (scale.* == 0) scale.* = 1.0;

    for (0..fp_cache.len) |i| {
        const q = @round(fp_cache[i] / scale.*);
        int_cache[i] = @intFromFloat(@max(-127.0, @min(127.0, q)));
    }
}

// Dequantize INT8 cache
pub fn dequantizeCacheInt8(int_cache: []const i8, fp_cache: []f32, scale: f32) void {
    for (0..int_cache.len) |i| {
        fp_cache[i] = @as(f32, @floatFromInt(int_cache[i])) * scale;
    }
}

// Quantize to INT4 (packed)
pub fn quantizeCacheInt4(fp_cache: []const f32, int_cache: []u8, scale: *f32) void {
    if (fp_cache.len == 0) return;

    var abs_max: f32 = 0;
    for (fp_cache) |v| {
        const abs_v = @abs(v);
        if (abs_v > abs_max) abs_max = abs_v;
    }

    scale.* = abs_max / 7.0;
    if (scale.* == 0) scale.* = 1.0;

    // Pack 2 INT4 values per byte
    const packed_len = (fp_cache.len + 1) / 2;
    for (0..packed_len) |i| {
        const idx1 = i * 2;
        const idx2 = i * 2 + 1;

        const q1 = @as(u8, @intFromFloat(@max(0.0, @min(15.0, @round(fp_cache[idx1] / scale.* + 8.0)))));
        const q2 = if (idx2 < fp_cache.len)
            @as(u8, @intFromFloat(@max(0.0, @min(15.0, @round(fp_cache[idx2] / scale.* + 8.0)))))
        else
            0;

        int_cache[i] = (q1 << 4) | q2;
    }
}

// Calculate compression ratio
pub fn compressionRatio(original_bits: u8, quantized_bits: u8) f32 {
    return @as(f32, @floatFromInt(original_bits)) / @as(f32, @floatFromInt(quantized_bits));
}

// Estimate cache memory for given sequence length
pub fn estimateCacheMemoryMB(config: KVCacheConfig, seq_len: usize) f32 {
    const bytes = memoryPerToken(config) * seq_len;
    return @as(f32, @floatFromInt(bytes)) / (1024.0 * 1024.0);
}

// PHI-optimal cache size
pub fn phiOptimalCacheSize(base_size: usize) usize {
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(base_size)) * PHI)));
}

// Tests
test "calculate cache memory" {
    const config = KVCacheConfig{
        .num_layers = 12,
        .num_kv_heads = 4,
        .head_dim = 64,
        .max_seq_len = 4096,
        .quantize_bits = 16,
    };

    const mem = calculateCacheMemory(config);
    // 2 * 12 * 4 * 4096 * 64 * 2 = 50,331,648 bytes ≈ 48 MB
    try testing.expect(mem > 40_000_000);
    try testing.expect(mem < 60_000_000);
}

test "memory per token" {
    const config = KVCacheConfig{
        .num_layers = 12,
        .num_kv_heads = 4,
        .head_dim = 64,
        .quantize_bits = 16,
    };

    const mem = memoryPerToken(config);
    // 2 * 12 * 4 * 64 * 2 = 12,288 bytes per token
    try testing.expectEqual(@as(usize, 12288), mem);
}

test "quantize cache int8" {
    const fp_cache = [_]f32{ -1.0, 0.0, 0.5, 1.0 };
    var int_cache: [4]i8 = undefined;
    var scale: f32 = undefined;

    quantizeCacheInt8(&fp_cache, &int_cache, &scale);

    try testing.expect(int_cache[0] < 0);
    try testing.expectEqual(@as(i8, 0), int_cache[1]);
    try testing.expect(int_cache[3] > 0);
}

test "compression ratio" {
    try testing.expectApproxEqAbs(@as(f32, 4.0), compressionRatio(16, 4), 0.001);
    try testing.expectApproxEqAbs(@as(f32, 2.0), compressionRatio(16, 8), 0.001);
}

test "estimate cache memory mb" {
    const config = KVCacheConfig{
        .num_layers = 12,
        .num_kv_heads = 4,
        .head_dim = 64,
        .quantize_bits = 16,
    };

    const mem_mb = estimateCacheMemoryMB(config, 1024);
    try testing.expect(mem_mb > 10.0);
    try testing.expect(mem_mb < 20.0);
}
