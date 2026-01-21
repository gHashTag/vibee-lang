// v6752_tensor_parallelism.zig - Tensor Parallelism
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const TPConfig = struct {
    world_size: usize = 1,
    rank: usize = 0,
};

pub fn shardSize(total_size: usize, world_size: usize) usize {
    return (total_size + world_size - 1) / world_size;
}

pub fn shardOffset(rank: usize, shard_size: usize) usize {
    return rank * shard_size;
}

pub fn columnParallelShard(weights: []const f32, rank: usize, world_size: usize, output: []f32) void {
    const cols_per_rank = weights.len / world_size;
    const start = rank * cols_per_rank;
    const end = @min(start + cols_per_rank, weights.len);

    for (start..end) |i| {
        if (i - start < output.len) {
            output[i - start] = weights[i];
        }
    }
}

pub fn rowParallelShard(weights: []const f32, rank: usize, world_size: usize, output: []f32) void {
    const rows_per_rank = weights.len / world_size;
    const start = rank * rows_per_rank;
    const end = @min(start + rows_per_rank, weights.len);

    for (start..end) |i| {
        if (i - start < output.len) {
            output[i - start] = weights[i];
        }
    }
}

pub fn allReduce(local: []f32, world_size: usize) void {
    // Simulate all-reduce by scaling (in real impl, would sum across ranks)
    for (local) |*v| {
        v.* /= @as(f32, @floatFromInt(world_size));
    }
}

pub fn communicationVolume(tensor_size: usize, world_size: usize) usize {
    // All-reduce: 2 * (world_size - 1) / world_size * tensor_size
    return 2 * (world_size - 1) * tensor_size / world_size;
}

pub fn phiWorldSize(model_size_gb: f32) usize {
    // PHI-based scaling for world size
    const base = model_size_gb / 10.0; // 10GB per device
    return @max(1, @as(usize, @intFromFloat(base * @as(f32, @floatCast(PHI)))));
}

// Tests
test "shard size" {
    try testing.expectEqual(@as(usize, 256), shardSize(1024, 4));
    try testing.expectEqual(@as(usize, 257), shardSize(1025, 4));
}

test "shard offset" {
    try testing.expectEqual(@as(usize, 512), shardOffset(2, 256));
}

test "column parallel shard" {
    const weights = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var output: [4]f32 = undefined;
    columnParallelShard(&weights, 1, 2, &output);
    try testing.expectEqual(@as(f32, 5), output[0]);
}

test "all reduce" {
    var local = [_]f32{ 4.0, 8.0 };
    allReduce(&local, 2);
    try testing.expectEqual(@as(f32, 2.0), local[0]);
}

test "communication volume" {
    const vol = communicationVolume(1024, 4);
    try testing.expect(vol > 0);
}

test "phi world size" {
    const ws = phiWorldSize(40.0);
    try testing.expect(ws >= 6);
}
