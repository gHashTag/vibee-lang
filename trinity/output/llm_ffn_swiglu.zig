// ═══════════════════════════════════════════════════════════════════════════════
// llm_ffn_swiglu v1.0.0 - SwiGLU Feed-Forward Network
// +1-2% accuracy improvement over GELU
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: GLU Variants Improve Transformer
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const FFNConfig = struct {
    hidden_size: usize = 768,
    intermediate_size: usize = 2048,
};

// Swish activation: x * sigmoid(x)
pub fn swish(x: f32) f32 {
    return x / (1.0 + @exp(-x));
}

// SiLU (same as Swish)
pub fn silu(x: f32) f32 {
    return swish(x);
}

// GELU activation (tanh approximation)
pub fn gelu(x: f32) f32 {
    const sqrt_2_over_pi: f32 = 0.7978845608;
    const coeff: f32 = 0.044715;
    const x3 = x * x * x;
    const inner = sqrt_2_over_pi * (x + coeff * x3);
    return 0.5 * x * (1.0 + std.math.tanh(inner));
}

// SwiGLU forward: (Swish(xW_gate) ⊙ xW_up) W_down
pub fn swigluForward(
    input: []const f32,
    w_gate: []const f32,
    w_up: []const f32,
    w_down: []const f32,
    output: []f32,
    hidden_size: usize,
    intermediate_size: usize,
) void {
    // Intermediate buffers (stack allocated for small sizes)
    var gate: [4096]f32 = [_]f32{0} ** 4096;
    var up: [4096]f32 = [_]f32{0} ** 4096;

    // Gate projection: xW_gate
    for (0..intermediate_size) |i| {
        var sum: f32 = 0;
        for (0..hidden_size) |j| {
            sum += input[j] * w_gate[j * intermediate_size + i];
        }
        gate[i] = swish(sum);
    }

    // Up projection: xW_up
    for (0..intermediate_size) |i| {
        var sum: f32 = 0;
        for (0..hidden_size) |j| {
            sum += input[j] * w_up[j * intermediate_size + i];
        }
        up[i] = sum;
    }

    // Element-wise multiply
    for (0..intermediate_size) |i| {
        gate[i] *= up[i];
    }

    // Down projection: (gate ⊙ up) W_down
    for (0..hidden_size) |i| {
        var sum: f32 = 0;
        for (0..intermediate_size) |j| {
            sum += gate[j] * w_down[j * hidden_size + i];
        }
        output[i] = sum;
    }
}

// GeGLU forward: (GELU(xW_gate) ⊙ xW_up) W_down
pub fn gegluForward(
    input: []const f32,
    w_gate: []const f32,
    w_up: []const f32,
    w_down: []const f32,
    output: []f32,
    hidden_size: usize,
    intermediate_size: usize,
) void {
    var gate: [4096]f32 = [_]f32{0} ** 4096;
    var up: [4096]f32 = [_]f32{0} ** 4096;

    for (0..intermediate_size) |i| {
        var sum: f32 = 0;
        for (0..hidden_size) |j| {
            sum += input[j] * w_gate[j * intermediate_size + i];
        }
        gate[i] = gelu(sum);
    }

    for (0..intermediate_size) |i| {
        var sum: f32 = 0;
        for (0..hidden_size) |j| {
            sum += input[j] * w_up[j * intermediate_size + i];
        }
        up[i] = sum;
    }

    for (0..intermediate_size) |i| {
        gate[i] *= up[i];
    }

    for (0..hidden_size) |i| {
        var sum: f32 = 0;
        for (0..intermediate_size) |j| {
            sum += gate[j] * w_down[j * hidden_size + i];
        }
        output[i] = sum;
    }
}

// PHI-optimal intermediate size
pub fn phiIntermediateSize(hidden_size: usize) usize {
    // Typically 8/3 * hidden, but PHI-optimized
    const ratio: f64 = 8.0 / 3.0 * PHI_INV; // ≈ 1.65
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(hidden_size)) * ratio)));
}

// Calculate FFN parameters
pub fn ffnParameters(hidden_size: usize, intermediate_size: usize) usize {
    // SwiGLU has 3 weight matrices: gate, up, down
    return 3 * hidden_size * intermediate_size;
}

// Tests
test "swish activation" {
    try testing.expectApproxEqAbs(@as(f32, 0.0), swish(0.0), 0.001);
    try testing.expect(swish(1.0) > 0.7);
    try testing.expect(swish(-1.0) < 0);
}

test "gelu activation" {
    try testing.expectApproxEqAbs(@as(f32, 0.0), gelu(0.0), 0.001);
    try testing.expect(gelu(1.0) > 0.8);
    try testing.expect(gelu(-1.0) < 0);
}

test "phi intermediate size" {
    const inter = phiIntermediateSize(768);
    try testing.expect(inter > 1000);
    try testing.expect(inter < 2000);
}

test "ffn parameters" {
    const params = ffnParameters(768, 2048);
    // 3 * 768 * 2048 = 4,718,592
    try testing.expectEqual(@as(usize, 4718592), params);
}

test "swish vs silu" {
    // They should be identical
    try testing.expectApproxEqAbs(swish(0.5), silu(0.5), 0.0001);
    try testing.expectApproxEqAbs(swish(-0.5), silu(-0.5), 0.0001);
}
