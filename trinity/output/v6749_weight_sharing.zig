// v6749_weight_sharing.zig - ALBERT-style Weight Sharing
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const SharingConfig = struct {
    share_attention: bool = true,
    share_ffn: bool = true,
    num_groups: usize = 1,
};

pub fn phiGroups(num_layers: usize) usize {
    // PHI-based grouping
    return @max(1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(num_layers)) / PHI)));
}

pub fn parameterReduction(num_layers: usize, num_groups: usize) f32 {
    return @as(f32, @floatFromInt(num_layers)) / @as(f32, @floatFromInt(num_groups));
}

pub fn layerToGroup(layer_idx: usize, num_groups: usize, num_layers: usize) usize {
    const layers_per_group = num_layers / num_groups;
    return @min(layer_idx / layers_per_group, num_groups - 1);
}

pub fn factorizeEmbedding(vocab_size: usize, hidden_size: usize, embedding_size: usize) struct { e_params: usize, h_params: usize, total: usize, original: usize } {
    const e_params = vocab_size * embedding_size;
    const h_params = embedding_size * hidden_size;
    const total = e_params + h_params;
    const original = vocab_size * hidden_size;
    return .{
        .e_params = e_params,
        .h_params = h_params,
        .total = total,
        .original = original,
    };
}

pub fn embeddingReduction(vocab_size: usize, hidden_size: usize, embedding_size: usize) f32 {
    const fact = factorizeEmbedding(vocab_size, hidden_size, embedding_size);
    return @as(f32, @floatFromInt(fact.original)) / @as(f32, @floatFromInt(fact.total));
}

pub fn phiEmbeddingSize(hidden_size: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(hidden_size)) * PHI_INV);
}

pub fn crossLayerSharing(layer_a: []const f32, layer_b: []f32) void {
    // Copy weights from layer_a to layer_b (sharing)
    const n = @min(layer_a.len, layer_b.len);
    for (0..n) |i| {
        layer_b[i] = layer_a[i];
    }
}

// Tests
test "phi groups" {
    try testing.expectEqual(@as(usize, 7), phiGroups(12));
    try testing.expectEqual(@as(usize, 3), phiGroups(6));
}

test "parameter reduction" {
    const reduction = parameterReduction(12, 1);
    try testing.expectEqual(@as(f32, 12.0), reduction);
}

test "layer to group" {
    try testing.expectEqual(@as(usize, 0), layerToGroup(0, 3, 12));
    try testing.expectEqual(@as(usize, 1), layerToGroup(5, 3, 12));
    try testing.expectEqual(@as(usize, 2), layerToGroup(11, 3, 12));
}

test "factorize embedding" {
    const fact = factorizeEmbedding(30000, 768, 128);
    try testing.expect(fact.total < fact.original);
}

test "embedding reduction" {
    const reduction = embeddingReduction(30000, 768, 128);
    try testing.expect(reduction > 3.0);
}

test "phi embedding size" {
    const size = phiEmbeddingSize(768);
    try testing.expect(size > 400);
    try testing.expect(size < 500);
}
