// v6769_infini_attention.zig - Infini-Attention (Infinite Context)
// КОЩЕЙ БЕССМЕРТНЫЙ - Бесконечный контекст!
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const InfiniConfig = struct {
    segment_length: usize = 2048,
    memory_size: usize = 256,
    beta: f32 = 0.9,
};

// Compressive memory update: M += K^T V (simplified)
pub fn compressiveMemoryUpdate(
    keys: []const f32,
    values: []const f32,
    memory: []f32,
    memory_dim: usize,
) void {
    // M_new = M_old + Σ k_i^T v_i
    for (0..memory_dim) |i| {
        for (0..memory_dim) |j| {
            const idx = i * memory_dim + j;
            if (idx < memory.len) {
                const k = if (i < keys.len) keys[i] else 0;
                const v = if (j < values.len) values[j] else 0;
                memory[idx] += k * v * 0.1; // Scaled update
            }
        }
    }
}

// Memory retrieval: A_mem = softmax(Q M^T / √d)
pub fn memoryRetrieval(
    query: []const f32,
    memory: []const f32,
    memory_dim: usize,
    output: []f32,
) void {
    // Simplified: Q @ M
    for (0..memory_dim) |i| {
        var sum: f32 = 0;
        for (0..memory_dim) |j| {
            const idx = i * memory_dim + j;
            const m = if (idx < memory.len) memory[idx] else 0;
            const q = if (j < query.len) query[j] else 0;
            sum += m * q;
        }
        if (i < output.len) {
            output[i] = sum;
        }
    }
}

// Combine local attention and memory: o = β * A_local + (1-β) * A_mem
pub fn combineLocalMemory(
    local_attn: []const f32,
    memory_attn: []const f32,
    beta: f32,
    output: []f32,
) void {
    const n = @min(@min(local_attn.len, memory_attn.len), output.len);
    for (0..n) |i| {
        output[i] = beta * local_attn[i] + (1.0 - beta) * memory_attn[i];
    }
}

// PHI-based beta (balance between local and memory)
pub fn phiBeta(segment_idx: usize) f32 {
    // Earlier segments rely more on memory
    const decay = @exp(-@as(f32, @floatCast(PHI_INV)) * @as(f32, @floatFromInt(segment_idx)));
    return @floatCast(PHI_INV + (1.0 - PHI_INV) * decay);
}

// Effective context length with Infini-Attention
pub fn effectiveContextLength(num_segments: usize, segment_length: usize) usize {
    // Theoretically infinite, but practically limited by memory capacity
    return num_segments * segment_length;
}

// Memory capacity (how many patterns can be stored)
pub fn memoryCapacity(memory_dim: usize) usize {
    // Approximately d patterns for d-dimensional memory
    return memory_dim;
}

// Tests
test "compressive memory update" {
    const keys = [_]f32{ 1.0, 0.5 };
    const values = [_]f32{ 2.0, 1.0 };
    var memory: [4]f32 = [_]f32{ 0, 0, 0, 0 };
    compressiveMemoryUpdate(&keys, &values, &memory, 2);
    try testing.expect(memory[0] != 0);
}

test "memory retrieval" {
    const query = [_]f32{ 1.0, 1.0 };
    const memory = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var output: [2]f32 = undefined;
    memoryRetrieval(&query, &memory, 2, &output);
    try testing.expect(output[0] != 0);
}

test "combine local memory" {
    const local = [_]f32{ 1.0, 2.0 };
    const mem = [_]f32{ 0.0, 0.0 };
    var output: [2]f32 = undefined;
    combineLocalMemory(&local, &mem, 0.9, &output);
    try testing.expectEqual(@as(f32, 0.9), output[0]);
}

test "phi beta" {
    const b0 = phiBeta(0);
    const b10 = phiBeta(10);
    try testing.expect(b0 > b10);
}

test "effective context" {
    const ctx = effectiveContextLength(100, 2048);
    try testing.expectEqual(@as(usize, 204800), ctx);
}

test "memory capacity" {
    const cap = memoryCapacity(256);
    try testing.expectEqual(@as(usize, 256), cap);
}
