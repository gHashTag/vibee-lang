// v6761_rwkv_linear.zig - RWKV Linear RNN
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const RWKVConfig = struct {
    hidden_dim: usize = 256,
    num_layers: usize = 6,
    time_decay: f32 = 0.99,
};

// Receptance - gate controlling information flow
pub fn receptance(input: []const f32, weights: []const f32, output: []f32) void {
    const n = @min(@min(input.len, weights.len), output.len);
    for (0..n) |i| {
        output[i] = 1.0 / (1.0 + @exp(-input[i] * weights[i]));
    }
}

// WKV (Weighted Key-Value) computation
pub fn wkvComputation(
    keys: []const f32,
    values: []const f32,
    time_weights: []const f32,
    output: []f32,
) void {
    const n = @min(@min(keys.len, values.len), output.len);
    var num: f64 = 0;
    var den: f64 = 0;

    for (0..n) |i| {
        const w = if (i < time_weights.len) @exp(@as(f64, time_weights[i])) else 1.0;
        num += w * @as(f64, keys[i]) * @as(f64, values[i]);
        den += w * @as(f64, keys[i]);
    }

    const wkv: f32 = if (den > 1e-10) @floatCast(num / den) else 0;
    for (output) |*o| {
        o.* = wkv;
    }
}

// Time mixing: interpolate current and previous
pub fn timeMixing(current: []const f32, previous: []const f32, mix: f32, output: []f32) void {
    const n = @min(@min(current.len, previous.len), output.len);
    for (0..n) |i| {
        output[i] = mix * current[i] + (1.0 - mix) * previous[i];
    }
}

// Channel mixing (FFN replacement)
pub fn channelMixing(input: []const f32, key_weight: f32, value_weight: f32, output: []f32) void {
    for (input, 0..) |x, i| {
        if (i < output.len) {
            const k = @max(0, x * key_weight); // ReLU-like
            const v = x * value_weight;
            output[i] = k * k * v; // Squared ReLU
        }
    }
}

pub fn phiTimeMix() f32 {
    return @floatCast(PHI_INV); // Golden ratio mixing
}

pub fn phiTimeDecay(layer: usize, num_layers: usize) f32 {
    const progress = @as(f32, @floatFromInt(layer)) / @as(f32, @floatFromInt(num_layers));
    return @floatCast(PHI_INV + (1.0 - PHI_INV) * (1.0 - progress));
}

// Tests
test "receptance" {
    const input = [_]f32{ 0.0, 1.0, -1.0 };
    const weights = [_]f32{ 1.0, 1.0, 1.0 };
    var output: [3]f32 = undefined;
    receptance(&input, &weights, &output);
    try testing.expect(@abs(output[0] - 0.5) < 0.01);
}

test "wkv computation" {
    const keys = [_]f32{ 1.0, 1.0 };
    const values = [_]f32{ 2.0, 4.0 };
    const weights = [_]f32{ 0.0, 0.0 };
    var output: [2]f32 = undefined;
    wkvComputation(&keys, &values, &weights, &output);
    try testing.expect(output[0] > 0);
}

test "time mixing" {
    const current = [_]f32{ 1.0, 2.0 };
    const previous = [_]f32{ 0.0, 0.0 };
    var output: [2]f32 = undefined;
    timeMixing(&current, &previous, 0.5, &output);
    try testing.expectEqual(@as(f32, 0.5), output[0]);
}

test "channel mixing" {
    const input = [_]f32{ 2.0, -1.0 };
    var output: [2]f32 = undefined;
    channelMixing(&input, 1.0, 1.0, &output);
    try testing.expect(output[0] > 0);
}

test "phi time mix" {
    const mix = phiTimeMix();
    try testing.expect(@abs(mix - 0.618) < 0.01);
}

test "phi time decay" {
    const early = phiTimeDecay(0, 12);
    const late = phiTimeDecay(11, 12);
    try testing.expect(early > late);
}
