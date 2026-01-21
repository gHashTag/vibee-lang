// v6751_prefix_caching.zig - Prefix Caching for KV Reuse
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const PrefixCache = struct {
    max_entries: usize = 1024,
    hash_bits: usize = 64,
};

pub fn computePrefixHash(tokens: []const u32) u64 {
    // FNV-1a hash
    var hash: u64 = 0xcbf29ce484222325;
    for (tokens) |token| {
        hash ^= @as(u64, token);
        hash *%= 0x100000001b3;
    }
    return hash;
}

pub fn hashMatch(hash_a: u64, hash_b: u64) bool {
    return hash_a == hash_b;
}

pub fn phiCacheSize(memory_mb: usize) usize {
    // PHI-scaled cache entries
    const base = memory_mb * 10; // 10 entries per MB
    return @intFromFloat(@as(f64, @floatFromInt(base)) * PHI);
}

pub fn cacheHitRate(hits: usize, total: usize) f32 {
    if (total == 0) return 0;
    return @as(f32, @floatFromInt(hits)) / @as(f32, @floatFromInt(total));
}

pub fn prefixLength(tokens_a: []const u32, tokens_b: []const u32) usize {
    const n = @min(tokens_a.len, tokens_b.len);
    for (0..n) |i| {
        if (tokens_a[i] != tokens_b[i]) {
            return i;
        }
    }
    return n;
}

pub fn computeSavings(prefix_len: usize, total_len: usize) f32 {
    if (total_len == 0) return 0;
    return @as(f32, @floatFromInt(prefix_len)) / @as(f32, @floatFromInt(total_len));
}

pub fn evictionScore(last_access: u64, current_time: u64, access_count: usize) f64 {
    // LRU with frequency boost
    const age = @as(f64, @floatFromInt(current_time - last_access));
    const freq = @as(f64, @floatFromInt(access_count));
    return age / (freq + 1.0);
}

// Tests
test "compute prefix hash" {
    const tokens = [_]u32{ 1, 2, 3, 4 };
    const hash = computePrefixHash(&tokens);
    try testing.expect(hash != 0);
}

test "hash deterministic" {
    const tokens = [_]u32{ 1, 2, 3 };
    const hash1 = computePrefixHash(&tokens);
    const hash2 = computePrefixHash(&tokens);
    try testing.expectEqual(hash1, hash2);
}

test "phi cache size" {
    const size = phiCacheSize(100);
    try testing.expect(size > 1600);
}

test "cache hit rate" {
    const rate = cacheHitRate(80, 100);
    try testing.expectEqual(@as(f32, 0.8), rate);
}

test "prefix length" {
    const a = [_]u32{ 1, 2, 3, 4 };
    const b = [_]u32{ 1, 2, 5, 6 };
    const len = prefixLength(&a, &b);
    try testing.expectEqual(@as(usize, 2), len);
}

test "compute savings" {
    const savings = computeSavings(50, 100);
    try testing.expectEqual(@as(f32, 0.5), savings);
}
