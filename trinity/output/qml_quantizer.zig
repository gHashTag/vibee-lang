// ═══════════════════════════════════════════════════════════════════════════════
// qml_quantizer v1.0.0 - Квантизация весов
// INT8/INT4 квантизация для CPU inference
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: arXiv:1712.05877
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const CalibrationMethod = enum {
    minmax,
    percentile,
    mse,
    entropy,
};

pub const QuantConfig = struct {
    weight_bits: u8 = 8,
    activation_bits: u8 = 8,
    symmetric: bool = true,
    per_channel: bool = true,
    calibration_method: CalibrationMethod = .minmax,
};

pub const QuantParams = struct {
    scale: f32,
    zero_point: i32,
    bits: u8,
};

// Find min and max values
pub fn findMinMax(data: []const f32) struct { min: f32, max: f32 } {
    if (data.len == 0) return .{ .min = 0, .max = 0 };
    var min_val: f32 = data[0];
    var max_val: f32 = data[0];
    for (data[1..]) |v| {
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
    }
    return .{ .min = min_val, .max = max_val };
}

// Compute quantization parameters (symmetric)
pub fn computeQuantParamsSymmetric(data: []const f32, bits: u8) QuantParams {
    const minmax = findMinMax(data);
    const abs_max = @max(@abs(minmax.min), @abs(minmax.max));
    const qmax: f32 = @floatFromInt((@as(i32, 1) << @intCast(bits - 1)) - 1);
    const scale = if (abs_max == 0) 1.0 else abs_max / qmax;
    return QuantParams{
        .scale = scale,
        .zero_point = 0,
        .bits = bits,
    };
}

// Compute quantization parameters (asymmetric)
pub fn computeQuantParamsAsymmetric(data: []const f32, bits: u8) QuantParams {
    const minmax = findMinMax(data);
    const qmin: f32 = 0;
    const qmax: f32 = @floatFromInt((@as(i32, 1) << @intCast(bits)) - 1);
    const range = minmax.max - minmax.min;
    const scale = if (range == 0) 1.0 else range / (qmax - qmin);
    const zero_point: i32 = @intFromFloat(@round(qmin - minmax.min / scale));
    return QuantParams{
        .scale = scale,
        .zero_point = zero_point,
        .bits = bits,
    };
}

// Quantize FP32 to INT8 (symmetric)
pub fn quantizeSymmetricInt8(input: []const f32, output: []i8, params: QuantParams) void {
    for (0..input.len) |i| {
        const q = @round(input[i] / params.scale);
        output[i] = @intFromFloat(@max(-128.0, @min(127.0, q)));
    }
}

// Quantize FP32 to INT8 (asymmetric)
pub fn quantizeAsymmetricInt8(input: []const f32, output: []u8, params: QuantParams) void {
    for (0..input.len) |i| {
        const q = @round(input[i] / params.scale) + @as(f32, @floatFromInt(params.zero_point));
        output[i] = @intFromFloat(@max(0.0, @min(255.0, q)));
    }
}

// Dequantize INT8 to FP32 (symmetric)
pub fn dequantizeSymmetricInt8(input: []const i8, output: []f32, params: QuantParams) void {
    for (0..input.len) |i| {
        output[i] = @as(f32, @floatFromInt(input[i])) * params.scale;
    }
}

// Dequantize UINT8 to FP32 (asymmetric)
pub fn dequantizeAsymmetricInt8(input: []const u8, output: []f32, params: QuantParams) void {
    for (0..input.len) |i| {
        output[i] = (@as(f32, @floatFromInt(input[i])) - @as(f32, @floatFromInt(params.zero_point))) * params.scale;
    }
}

// INT8 matrix multiplication with FP32 accumulation
pub fn int8MatmulFP32Accum(
    a: []const i8,
    b: []const i8,
    c: []f32,
    m: usize,
    k: usize,
    n: usize,
    scale_a: f32,
    scale_b: f32,
) void {
    const combined_scale = scale_a * scale_b;
    for (0..m) |i| {
        for (0..n) |j| {
            var sum: i32 = 0;
            for (0..k) |l| {
                sum += @as(i32, a[i * k + l]) * @as(i32, b[l * n + j]);
            }
            c[i * n + j] = @as(f32, @floatFromInt(sum)) * combined_scale;
        }
    }
}

// Compute quantization error (MSE)
pub fn quantizationError(original: []const f32, quantized: []const f32) f32 {
    if (original.len == 0) return 0;
    var mse: f32 = 0;
    for (0..original.len) |i| {
        const diff = original[i] - quantized[i];
        mse += diff * diff;
    }
    return mse / @as(f32, @floatFromInt(original.len));
}

// Estimate compression ratio
pub fn compressionRatio(original_bits: u8, quantized_bits: u8) f32 {
    return @as(f32, @floatFromInt(original_bits)) / @as(f32, @floatFromInt(quantized_bits));
}

// Tests
test "find min max" {
    const data = [_]f32{ -1.0, 0.5, 2.0, -0.5 };
    const result = findMinMax(&data);
    try testing.expectApproxEqAbs(@as(f32, -1.0), result.min, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 2.0), result.max, 0.001);
}

test "symmetric quant params" {
    const data = [_]f32{ -1.0, 0.0, 1.0 };
    const params = computeQuantParamsSymmetric(&data, 8);
    try testing.expect(params.scale > 0);
    try testing.expectEqual(@as(i32, 0), params.zero_point);
}

test "asymmetric quant params" {
    const data = [_]f32{ 0.0, 1.0, 2.0 };
    const params = computeQuantParamsAsymmetric(&data, 8);
    try testing.expect(params.scale > 0);
}

test "quantize dequantize symmetric" {
    const input = [_]f32{ -1.0, 0.0, 0.5, 1.0 };
    const params = computeQuantParamsSymmetric(&input, 8);

    var quantized: [4]i8 = undefined;
    quantizeSymmetricInt8(&input, &quantized, params);

    var dequantized: [4]f32 = undefined;
    dequantizeSymmetricInt8(&quantized, &dequantized, params);

    const quant_error = quantizationError(&input, &dequantized);
    try testing.expect(quant_error < 0.01);
}

test "int8 matmul" {
    const a = [_]i8{ 1, 2, 3, 4 };
    const b = [_]i8{ 5, 6, 7, 8 };
    var c: [4]f32 = undefined;
    int8MatmulFP32Accum(&a, &b, &c, 2, 2, 2, 0.1, 0.1);
    // Result should be scaled version of regular matmul
    try testing.expect(c[0] > 0);
}

test "compression ratio" {
    const ratio = compressionRatio(32, 8);
    try testing.expectApproxEqAbs(@as(f32, 4.0), ratio, 0.001);
}
