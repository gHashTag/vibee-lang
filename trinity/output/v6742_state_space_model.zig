// v6742_state_space_model.zig - Mamba-style State Space Model
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const SSMConfig = struct {
    state_dim: usize = 16,
    input_dim: usize = 64,
    dt_rank: usize = 4,
};

pub fn phiStateDim(base: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(base)) * PHI);
}

pub fn discretize(dt: f32, a: f32) struct { a_bar: f32, b_bar: f32 } {
    const a_bar = @exp(dt * a);
    const b_bar = if (@abs(a) > 1e-6)
        (a_bar - 1.0) / a
    else
        dt;
    return .{ .a_bar = a_bar, .b_bar = b_bar };
}

pub fn selectiveScan(input: []const f32, state: []f32, a: f32, b: f32, c: f32, output: []f32) void {
    const dt: f32 = @floatCast(PHI_INV);
    const disc = discretize(dt, a);

    for (input, 0..) |x, i| {
        // State update: h = A_bar * h + B_bar * x
        for (state) |*s| {
            s.* = disc.a_bar * s.* + disc.b_bar * x * b;
        }
        // Output: y = C * h
        var y: f32 = 0;
        for (state) |s| {
            y += c * s;
        }
        if (i < output.len) {
            output[i] = y;
        }
    }
}

pub fn linearComplexity(seq_len: usize, state_dim: usize) usize {
    // O(N * D) instead of O(N²)
    return seq_len * state_dim;
}

pub fn attentionComplexity(seq_len: usize) usize {
    // O(N²)
    return seq_len * seq_len;
}

pub fn speedupVsAttention(seq_len: usize, state_dim: usize) f32 {
    const ssm = linearComplexity(seq_len, state_dim);
    const attn = attentionComplexity(seq_len);
    return @as(f32, @floatFromInt(attn)) / @as(f32, @floatFromInt(ssm));
}

// Tests
test "phi state dim" {
    try testing.expectEqual(@as(usize, 25), phiStateDim(16));
}

test "discretize" {
    const result = discretize(0.1, -1.0);
    try testing.expect(result.a_bar < 1.0);
    try testing.expect(result.b_bar > 0);
}

test "selective scan" {
    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var state = [_]f32{ 0.0, 0.0 };
    var output: [3]f32 = undefined;
    selectiveScan(&input, &state, -0.5, 1.0, 1.0, &output);
    try testing.expect(output[2] != 0);
}

test "linear complexity" {
    const ssm = linearComplexity(1024, 16);
    try testing.expectEqual(@as(usize, 16384), ssm);
}

test "speedup" {
    const speedup = speedupVsAttention(1024, 16);
    try testing.expect(speedup > 60.0); // 1024/16 = 64x
}

test "config defaults" {
    const config = SSMConfig{};
    try testing.expectEqual(@as(usize, 16), config.state_dim);
}
