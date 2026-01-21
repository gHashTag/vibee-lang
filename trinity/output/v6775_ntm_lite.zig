// v6775_ntm_lite.zig - Neural Turing Machine Lite
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const NTMConfig = struct {
    memory_size: usize = 128,
    memory_dim: usize = 64,
    num_heads: usize = 1,
};

// Content-based addressing: w = softmax(K(k, M))
pub fn contentAddressing(
    key: []const f32,
    memory: []const f32,
    memory_size: usize,
    memory_dim: usize,
    weights: []f32,
) void {
    var max_sim: f32 = -math.inf(f32);

    // Compute cosine similarity for each memory location
    for (0..memory_size) |i| {
        var dot: f64 = 0;
        var norm_k: f64 = 0;
        var norm_m: f64 = 0;

        for (0..memory_dim) |j| {
            const m_idx = i * memory_dim + j;
            const m = if (m_idx < memory.len) memory[m_idx] else 0;
            const k = if (j < key.len) key[j] else 0;

            dot += @as(f64, k) * @as(f64, m);
            norm_k += @as(f64, k) * @as(f64, k);
            norm_m += @as(f64, m) * @as(f64, m);
        }

        const denom = @sqrt(norm_k) * @sqrt(norm_m);
        const sim: f32 = if (denom > 1e-10) @floatCast(dot / denom) else 0;

        if (i < weights.len) {
            weights[i] = sim;
            max_sim = @max(max_sim, sim);
        }
    }

    // Softmax
    var sum: f32 = 0;
    for (0..memory_size) |i| {
        if (i < weights.len) {
            weights[i] = @exp(weights[i] - max_sim);
            sum += weights[i];
        }
    }
    for (0..memory_size) |i| {
        if (i < weights.len) {
            weights[i] /= @max(sum, 1e-10);
        }
    }
}

// Read from memory: r = Σ w_i * M_i
pub fn readMemory(
    weights: []const f32,
    memory: []const f32,
    memory_size: usize,
    memory_dim: usize,
    output: []f32,
) void {
    for (0..memory_dim) |j| {
        var sum: f32 = 0;
        for (0..memory_size) |i| {
            const m_idx = i * memory_dim + j;
            const m = if (m_idx < memory.len) memory[m_idx] else 0;
            const w = if (i < weights.len) weights[i] else 0;
            sum += w * m;
        }
        if (j < output.len) {
            output[j] = sum;
        }
    }
}

// Write to memory: M' = M * (1 - w*e) + w*a
pub fn writeMemory(
    weights: []const f32,
    erase: []const f32,
    add: []const f32,
    memory: []f32,
    memory_size: usize,
    memory_dim: usize,
) void {
    for (0..memory_size) |i| {
        const w = if (i < weights.len) weights[i] else 0;

        for (0..memory_dim) |j| {
            const m_idx = i * memory_dim + j;
            if (m_idx < memory.len) {
                const e = if (j < erase.len) erase[j] else 0;
                const a = if (j < add.len) add[j] else 0;

                memory[m_idx] = memory[m_idx] * (1.0 - w * e) + w * a;
            }
        }
    }
}

// PHI-based memory size
pub fn phiMemorySize(base_size: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(base_size)) * PHI);
}

// Location-based addressing (shift)
pub fn shiftWeights(weights: []f32, shift: i32) void {
    const n = weights.len;
    var temp: [256]f32 = undefined;
    @memcpy(temp[0..@min(n, 256)], weights[0..@min(n, 256)]);

    for (0..n) |i| {
        const src_idx = @mod(@as(i32, @intCast(i)) - shift + @as(i32, @intCast(n)), @as(i32, @intCast(n)));
        weights[i] = temp[@intCast(src_idx)];
    }
}

// Tests
test "content addressing" {
    const key = [_]f32{ 1.0, 0.0 };
    const memory = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var weights: [2]f32 = undefined;
    contentAddressing(&key, &memory, 2, 2, &weights);
    try testing.expect(weights[0] > weights[1]); // First location matches
}

test "read memory" {
    const weights = [_]f32{ 1.0, 0.0 };
    const memory = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [2]f32 = undefined;
    readMemory(&weights, &memory, 2, 2, &output);
    try testing.expectEqual(@as(f32, 1.0), output[0]);
}

test "write memory" {
    const weights = [_]f32{ 1.0, 0.0 };
    const erase = [_]f32{ 1.0, 1.0 };
    const add = [_]f32{ 5.0, 6.0 };
    var memory = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    writeMemory(&weights, &erase, &add, &memory, 2, 2);
    try testing.expectEqual(@as(f32, 5.0), memory[0]);
}

test "phi memory size" {
    const size = phiMemorySize(128);
    try testing.expect(size > 200);
}

test "shift weights" {
    var weights = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    shiftWeights(&weights, 1);
    try testing.expectEqual(@as(f32, 1.0), weights[1]);
}

test "config defaults" {
    const config = NTMConfig{};
    try testing.expectEqual(@as(usize, 128), config.memory_size);
}
