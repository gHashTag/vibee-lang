// v6760_igla_core.zig - iGLA (Gated Linear Attention) Core
// КОЩЕЙ БЕССМЕРТНЫЙ - Бесконечный контекст через рекуррентность
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;

pub const iGLAConfig = struct {
    hidden_dim: usize = 256,
    num_heads: usize = 4,
    chunk_size: usize = 64,
};

// Кощеева игла - гейт, контролирующий бессмертие состояния
pub fn computeGate(input: []const f32, weights: []const f32) f32 {
    var sum: f64 = 0;
    const n = @min(input.len, weights.len);
    for (0..n) |i| {
        sum += @as(f64, input[i]) * @as(f64, weights[i]);
    }
    // Sigmoid with PHI scaling
    return @floatCast(1.0 / (1.0 + @exp(-sum * PHI_INV)));
}

pub fn phiDecay(time_step: usize) f32 {
    // Golden ratio decay: exp(-φ⁻¹ × t)
    const t: f64 = @floatFromInt(time_step);
    return @floatCast(@exp(-PHI_INV * t * 0.1));
}

pub fn gatedRecurrence(
    input: []const f32,
    prev_state: []const f32,
    gate: f32,
    kv_contrib: []const f32,
    output_state: []f32,
) void {
    // h_t = G_t ⊙ h_{t-1} + (1 - G_t) ⊙ (K_t^T V_t)
    // КОЩЕЙ: gate контролирует, сколько "бессмертного" состояния сохранить
    const n = @min(@min(input.len, prev_state.len), output_state.len);
    for (0..n) |i| {
        const kv = if (i < kv_contrib.len) kv_contrib[i] else 0;
        output_state[i] = gate * prev_state[i] + (1.0 - gate) * kv;
    }
}

pub fn linearAttentionOutput(query: []const f32, state: []const f32, output: []f32) void {
    // o_t = Q_t h_t
    const n = @min(@min(query.len, state.len), output.len);
    for (0..n) |i| {
        output[i] = query[i] * state[i];
    }
}

pub fn chunkwiseForward(
    input_chunk: []const f32,
    initial_state: []const f32,
    chunk_size: usize,
    output: []f32,
    final_state: []f32,
) void {
    var state: [256]f32 = undefined;
    const state_len = @min(initial_state.len, 256);
    @memcpy(state[0..state_len], initial_state[0..state_len]);

    const num_steps = @min(input_chunk.len / chunk_size, output.len);
    for (0..num_steps) |t| {
        const gate = phiDecay(t);
        for (0..state_len) |i| {
            const idx = t * chunk_size + i;
            const inp = if (idx < input_chunk.len) input_chunk[idx] else 0;
            state[i] = gate * state[i] + (1.0 - gate) * inp;
            if (i < output.len) {
                output[i] = state[i];
            }
        }
    }

    @memcpy(final_state[0..@min(final_state.len, state_len)], state[0..@min(final_state.len, state_len)]);
}

pub fn complexityComparison(seq_len: usize) struct { attention: usize, igla: usize, speedup: f32 } {
    const attention = seq_len * seq_len; // O(N²)
    const igla = seq_len; // O(N)
    const speedup = @as(f32, @floatFromInt(attention)) / @as(f32, @floatFromInt(igla));
    return .{ .attention = attention, .igla = igla, .speedup = speedup };
}

// Tests
test "compute gate" {
    const input = [_]f32{ 1.0, 0.5, -0.5 };
    const weights = [_]f32{ 0.5, 0.5, 0.5 };
    const gate = computeGate(&input, &weights);
    try testing.expect(gate > 0);
    try testing.expect(gate < 1);
}

test "phi decay" {
    const d0 = phiDecay(0);
    const d10 = phiDecay(10);
    try testing.expect(d0 > d10); // Decay over time
    try testing.expect(@abs(d0 - 1.0) < 0.01);
}

test "gated recurrence" {
    const input = [_]f32{ 0.1, 0.2 };
    const prev = [_]f32{ 1.0, 2.0 };
    const kv = [_]f32{ 0.5, 0.5 };
    var output: [2]f32 = undefined;
    gatedRecurrence(&input, &prev, 0.6, &kv, &output);
    // output = 0.6 * prev + 0.4 * kv = 0.6 * 1.0 + 0.4 * 0.5 = 0.8
    try testing.expect(output[0] > 0.7);
}

test "complexity comparison" {
    const comp = complexityComparison(1024);
    try testing.expectEqual(@as(usize, 1048576), comp.attention);
    try testing.expectEqual(@as(usize, 1024), comp.igla);
    try testing.expect(comp.speedup > 1000);
}

test "config defaults" {
    const config = iGLAConfig{};
    try testing.expectEqual(@as(usize, 256), config.hidden_dim);
}

test "linear attention output" {
    const query = [_]f32{ 1.0, 2.0 };
    const state = [_]f32{ 0.5, 0.5 };
    var output: [2]f32 = undefined;
    linearAttentionOutput(&query, &state, &output);
    try testing.expectEqual(@as(f32, 0.5), output[0]);
}
