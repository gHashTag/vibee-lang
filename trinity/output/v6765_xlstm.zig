// v6765_xlstm.zig - xLSTM (Extended LSTM by Sepp Hochreiter)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const xLSTMConfig = struct {
    hidden_dim: usize = 256,
    memory_dim: usize = 64,
    use_matrix_memory: bool = true,
};

// Exponential gating (key innovation of xLSTM)
pub fn exponentialGate(input: f32, weight: f32) f32 {
    return @exp(input * weight);
}

// sLSTM cell: scalar memory with exponential gates
pub fn slstmCell(
    input: f32,
    prev_cell: f32,
    _: f32,
    forget_weight: f32,
    input_weight: f32,
    output_weight: f32,
) struct { cell: f32, hidden: f32 } {
    // Exponential forget gate
    const f = exponentialGate(input, forget_weight);
    // Input gate
    const i = 1.0 / (1.0 + @exp(-input * input_weight));
    // Cell candidate
    const z = math.tanh(input);
    // Output gate
    const o = 1.0 / (1.0 + @exp(-input * output_weight));

    // Cell update with exponential forget
    const cell = f * prev_cell + i * z;
    const hidden = o * math.tanh(cell);

    return .{ .cell = cell, .hidden = hidden };
}

// mLSTM: matrix memory cell
pub fn mlstmUpdate(
    _: []const f32,
    key: []const f32,
    value: []const f32,
    prev_memory: []f32,
    forget_gate: f32,
    input_gate: f32,
    memory_dim: usize,
) void {
    // C_t = f_t * C_{t-1} + i_t * v_t * k_t^T
    for (0..memory_dim) |i| {
        for (0..memory_dim) |j| {
            const idx = i * memory_dim + j;
            if (idx < prev_memory.len) {
                const v = if (i < value.len) value[i] else 0;
                const k = if (j < key.len) key[j] else 0;
                prev_memory[idx] = forget_gate * prev_memory[idx] + input_gate * v * k;
            }
        }
    }
}

// mLSTM output: h_t = o_t ⊙ (C_t q_t) / max(|n_t^T q_t|, 1)
pub fn mlstmOutput(
    query: []const f32,
    memory: []const f32,
    output_gate: f32,
    memory_dim: usize,
    output: []f32,
) void {
    var norm: f32 = 0;

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
            norm += @abs(sum);
        }
    }

    // Normalize
    const normalizer = @max(norm, 1.0);
    for (output) |*o| {
        o.* = output_gate * o.* / normalizer;
    }
}

// PHI-enhanced exponential gate
pub fn phiExponentialGate(input: f32) f32 {
    return @exp(@as(f32, @floatCast(PHI_INV)) * input);
}

// Tests
test "exponential gate" {
    const g = exponentialGate(1.0, 0.5);
    try testing.expect(g > 1.0);
}

test "slstm cell" {
    const result = slstmCell(0.5, 0.0, 0.0, 0.1, 1.0, 1.0);
    try testing.expect(result.cell != 0);
    try testing.expect(@abs(result.hidden) <= 1.0);
}

test "mlstm update" {
    const query = [_]f32{ 1.0, 0.5 };
    const key = [_]f32{ 0.5, 1.0 };
    const value = [_]f32{ 1.0, 2.0 };
    var memory: [4]f32 = [_]f32{ 0, 0, 0, 0 };
    mlstmUpdate(&query, &key, &value, &memory, 0.9, 0.1, 2);
    try testing.expect(memory[0] != 0);
}

test "mlstm output" {
    const query = [_]f32{ 1.0, 1.0 };
    const memory = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var output: [2]f32 = undefined;
    mlstmOutput(&query, &memory, 1.0, 2, &output);
    try testing.expect(output[0] != 0);
}

test "phi exponential gate" {
    const g = phiExponentialGate(1.0);
    try testing.expect(@abs(g - 1.855) < 0.1);
}

test "config defaults" {
    const config = xLSTMConfig{};
    try testing.expect(config.use_matrix_memory);
}
