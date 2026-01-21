// v6763_hyena_operator.zig - Hyena Long Convolution Operator
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const HyenaConfig = struct {
    filter_order: usize = 2,
    filter_size: usize = 128,
    use_fft: bool = true,
};

// Generate implicit filter with exponential decay
pub fn generateFilter(size: usize, decay: f32, filter: []f32) void {
    for (0..size) |i| {
        if (i < filter.len) {
            const t: f32 = @floatFromInt(i);
            filter[i] = @exp(-decay * t) * @cos(t * 0.1);
        }
    }
}

// PHI-based filter decay
pub fn phiFilterDecay(position: usize, filter_size: usize) f32 {
    const t = @as(f64, @floatFromInt(position)) / @as(f64, @floatFromInt(filter_size));
    return @floatCast(@exp(-PHI_INV * t * 5.0));
}

// Direct convolution (for small sequences)
pub fn directConvolution(input: []const f32, filter: []const f32, output: []f32) void {
    const n = input.len;
    const k = filter.len;

    for (0..n) |i| {
        var sum: f32 = 0;
        for (0..k) |j| {
            if (i >= j) {
                sum += input[i - j] * filter[j];
            }
        }
        if (i < output.len) {
            output[i] = sum;
        }
    }
}

// Hyena operator: y = h * (v ⊙ (h * x))
pub fn hyenaOperator(
    input: []const f32,
    filter: []const f32,
    gate: []const f32,
    output: []f32,
) void {
    var temp1: [256]f32 = undefined;
    var temp2: [256]f32 = undefined;
    const n = @min(input.len, 256);

    // First convolution: h * x
    directConvolution(input, filter, temp1[0..n]);

    // Gating: v ⊙ (h * x)
    for (0..n) |i| {
        const g = if (i < gate.len) gate[i] else 1.0;
        temp2[i] = g * temp1[i];
    }

    // Second convolution: h * (v ⊙ (h * x))
    directConvolution(temp2[0..n], filter, output);
}

// Complexity: O(N log N) with FFT
pub fn fftComplexity(seq_len: usize) usize {
    // N log N
    const n: f64 = @floatFromInt(seq_len);
    return @intFromFloat(n * @log2(n));
}

pub fn attentionComplexity(seq_len: usize) usize {
    return seq_len * seq_len;
}

pub fn speedupVsAttention(seq_len: usize) f32 {
    const hyena = fftComplexity(seq_len);
    const attn = attentionComplexity(seq_len);
    return @as(f32, @floatFromInt(attn)) / @as(f32, @floatFromInt(hyena));
}

// Tests
test "generate filter" {
    var filter: [10]f32 = undefined;
    generateFilter(10, 0.1, &filter);
    try testing.expect(filter[0] > filter[9]); // Decay
}

test "phi filter decay" {
    const d0 = phiFilterDecay(0, 100);
    const d50 = phiFilterDecay(50, 100);
    try testing.expect(d0 > d50);
}

test "direct convolution" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const filter = [_]f32{ 1.0, 0.5 };
    var output: [4]f32 = undefined;
    directConvolution(&input, &filter, &output);
    try testing.expect(output[1] > output[0]);
}

test "fft complexity" {
    const comp = fftComplexity(1024);
    try testing.expect(comp < 1024 * 1024); // Less than O(N²)
}

test "speedup" {
    const speedup = speedupVsAttention(1024);
    try testing.expect(speedup > 50); // Significant speedup
}

test "config defaults" {
    const config = HyenaConfig{};
    try testing.expectEqual(@as(usize, 2), config.filter_order);
}
