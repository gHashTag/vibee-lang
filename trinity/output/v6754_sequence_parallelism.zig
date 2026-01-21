// v6754_sequence_parallelism.zig - Sequence Parallelism
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const SPConfig = struct {
    sequence_parallel_size: usize = 2,
    ring_size: usize = 4,
};

pub fn chunkSize(seq_len: usize, sp_size: usize) usize {
    return (seq_len + sp_size - 1) / sp_size;
}

pub fn chunkOffset(rank: usize, chunk_size: usize) usize {
    return rank * chunk_size;
}

pub fn shardSequence(sequence: []const f32, rank: usize, sp_size: usize, output: []f32) void {
    const chunk = chunkSize(sequence.len, sp_size);
    const start = chunkOffset(rank, chunk);
    const end = @min(start + chunk, sequence.len);

    for (start..end) |i| {
        if (i - start < output.len) {
            output[i - start] = sequence[i];
        }
    }
}

pub fn ringAttentionStep(local_q: []const f32, received_kv: []const f32, output: []f32) void {
    // Simplified: compute local attention contribution
    for (output, 0..) |*out, i| {
        var sum: f32 = 0;
        for (local_q, 0..) |q, j| {
            const kv_idx = (i + j) % received_kv.len;
            sum += q * received_kv[kv_idx];
        }
        out.* += sum;
    }
}

pub fn communicationRounds(ring_size: usize) usize {
    return ring_size - 1;
}

pub fn memoryReduction(sp_size: usize) f32 {
    // Activation memory scales with 1/sp_size
    return @as(f32, @floatFromInt(sp_size));
}

pub fn phiChunkSize(seq_len: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(seq_len)) * PHI_INV);
}

pub fn effectiveContextLength(local_len: usize, ring_size: usize) usize {
    return local_len * ring_size;
}

// Tests
test "chunk size" {
    try testing.expectEqual(@as(usize, 256), chunkSize(1024, 4));
    try testing.expectEqual(@as(usize, 257), chunkSize(1025, 4));
}

test "chunk offset" {
    try testing.expectEqual(@as(usize, 512), chunkOffset(2, 256));
}

test "shard sequence" {
    const seq = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var output: [4]f32 = undefined;
    shardSequence(&seq, 1, 2, &output);
    try testing.expectEqual(@as(f32, 5), output[0]);
}

test "communication rounds" {
    try testing.expectEqual(@as(usize, 3), communicationRounds(4));
}

test "memory reduction" {
    const reduction = memoryReduction(4);
    try testing.expectEqual(@as(f32, 4.0), reduction);
}

test "phi chunk size" {
    const chunk = phiChunkSize(1024);
    try testing.expect(chunk > 600);
    try testing.expect(chunk < 700);
}
