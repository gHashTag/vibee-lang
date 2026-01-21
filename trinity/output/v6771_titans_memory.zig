// v6771_titans_memory.zig - Titans Memory Layer
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const TitansConfig = struct {
    memory_slots: usize = 64,
    memory_dim: usize = 256,
    num_heads: usize = 4,
};

// Memory attention: attend to memory slots
pub fn memoryAttention(
    query: []const f32,
    memory: []const f32,
    memory_slots: usize,
    output: []f32,
) void {
    const slot_dim = memory.len / memory_slots;

    for (0..memory_slots) |slot| {
        var score: f32 = 0;
        const start = slot * slot_dim;

        for (query, 0..) |q, i| {
            const m_idx = start + i;
            if (m_idx < memory.len) {
                score += q * memory[m_idx];
            }
        }

        if (slot < output.len) {
            output[slot] = score;
        }
    }
}

// Memory update with surprise gating
pub fn memoryUpdate(
    key: []const f32,
    value: []const f32,
    memory: []f32,
    surprise: f32,
    slot_idx: usize,
    slot_dim: usize,
) void {
    const start = slot_idx * slot_dim;
    const update_strength = surprise * @as(f32, @floatCast(PHI_INV));

    for (0..slot_dim) |i| {
        const m_idx = start + i;
        if (m_idx < memory.len) {
            const k = if (i < key.len) key[i] else 0;
            const v = if (i < value.len) value[i] else 0;
            memory[m_idx] = (1.0 - update_strength) * memory[m_idx] + update_strength * k * v;
        }
    }
}

// Surprise signal: how unexpected is the input
pub fn computeSurprise(prediction: []const f32, actual: []const f32) f32 {
    var mse: f64 = 0;
    const n = @min(prediction.len, actual.len);

    for (0..n) |i| {
        const diff = @as(f64, prediction[i]) - @as(f64, actual[i]);
        mse += diff * diff;
    }

    return @floatCast(@sqrt(mse / @as(f64, @floatFromInt(n))));
}

// Gated update based on surprise
pub fn surpriseGating(surprise: f32, threshold: f32) f32 {
    // High surprise = strong update
    if (surprise > threshold) {
        return @min(1.0, surprise / threshold);
    }
    return surprise / threshold * @as(f32, @floatCast(PHI_INV));
}

// PHI-based memory capacity
pub fn phiMemorySlots(base_slots: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(base_slots)) * PHI);
}

// Tests
test "memory attention" {
    const query = [_]f32{ 1.0, 0.5 };
    const memory = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var output: [2]f32 = undefined;
    memoryAttention(&query, &memory, 2, &output);
    try testing.expect(output[0] != 0);
}

test "compute surprise" {
    const pred = [_]f32{ 1.0, 2.0 };
    const actual = [_]f32{ 1.5, 2.5 };
    const surprise = computeSurprise(&pred, &actual);
    try testing.expect(surprise > 0);
}

test "surprise gating" {
    const high = surpriseGating(2.0, 1.0);
    const low = surpriseGating(0.5, 1.0);
    try testing.expect(high > low);
}

test "phi memory slots" {
    const slots = phiMemorySlots(64);
    try testing.expect(slots > 100);
}

test "memory update" {
    const key = [_]f32{ 1.0, 0.5 };
    const value = [_]f32{ 2.0, 1.0 };
    var memory: [4]f32 = [_]f32{ 0, 0, 0, 0 };
    memoryUpdate(&key, &value, &memory, 0.5, 0, 2);
    try testing.expect(memory[0] != 0);
}

test "config defaults" {
    const config = TitansConfig{};
    try testing.expectEqual(@as(usize, 64), config.memory_slots);
}
