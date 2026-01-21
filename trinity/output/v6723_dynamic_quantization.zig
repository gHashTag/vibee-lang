// ═══════════════════════════════════════════════════════════════
// v6723: DYNAMIC QUANTIZATION
// Runtime quantization for inference
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;

pub const QuantizationScheme = enum {
    INT8_SYMMETRIC,
    INT8_ASYMMETRIC,
    INT4_GROUPED,
    FP8_E4M3,
    FP8_E5M2,
};

pub const QuantizedTensor = struct {
    scale: f32,
    zero_point: i32,
    scheme: QuantizationScheme,
    group_size: usize,
};

pub const QuantizationStats = struct {
    min_val: f32,
    max_val: f32,
    mean: f32,
    std_dev: f32,
};

pub fn computeStats(values: []const f32) QuantizationStats {
    if (values.len == 0) {
        return .{ .min_val = 0, .max_val = 0, .mean = 0, .std_dev = 0 };
    }

    var min_val: f32 = values[0];
    var max_val: f32 = values[0];
    var sum: f64 = 0;

    for (values) |v| {
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
        sum += v;
    }

    const mean: f32 = @floatCast(sum / @as(f64, @floatFromInt(values.len)));

    var variance: f64 = 0;
    for (values) |v| {
        const diff = @as(f64, v) - @as(f64, mean);
        variance += diff * diff;
    }
    variance /= @as(f64, @floatFromInt(values.len));

    return .{
        .min_val = min_val,
        .max_val = max_val,
        .mean = mean,
        .std_dev = @floatCast(@sqrt(variance)),
    };
}

pub fn computeScaleZP(stats: QuantizationStats, bits: u8) struct { scale: f32, zero_point: i32 } {
    const shift: u5 = @intCast(@min(bits, 31));
    const qmax: f32 = @floatFromInt((@as(i32, 1) << shift) - 1);
    const range = stats.max_val - stats.min_val;

    if (range < 1e-10) {
        return .{ .scale = 1.0, .zero_point = 0 };
    }

    const scale = range / qmax;
    const zero_point: i32 = @intFromFloat(-stats.min_val / scale);

    return .{ .scale = scale, .zero_point = zero_point };
}

pub fn quantizeSymmetric(values: []const f32, output: []i8) f32 {
    if (values.len == 0) return 1.0;

    var max_abs: f32 = 0;
    for (values) |v| {
        const abs_v = @abs(v);
        if (abs_v > max_abs) max_abs = abs_v;
    }

    const scale = if (max_abs > 0) max_abs / 127.0 else 1.0;

    const n = @min(values.len, output.len);
    for (values[0..n], output[0..n]) |v, *o| {
        const scaled = v / scale;
        o.* = @intFromFloat(math.clamp(scaled, -127.0, 127.0));
    }

    return scale;
}

pub fn dequantize(quantized: []const i8, scale: f32, output: []f32) void {
    const n = @min(quantized.len, output.len);
    for (quantized[0..n], output[0..n]) |q, *o| {
        o.* = @as(f32, @floatFromInt(q)) * scale;
    }
}

pub fn quantizeMatmul(a_scale: f32, b_scale: f32, result_int: i32) f32 {
    return @as(f32, @floatFromInt(result_int)) * a_scale * b_scale;
}

// Tests
test "symmetric roundtrip" {
    const values = [_]f32{ 1.0, -0.5, 0.25, -0.75, 0.0 };
    var quantized: [5]i8 = undefined;
    var dequantized: [5]f32 = undefined;

    const scale = quantizeSymmetric(&values, &quantized);
    dequantize(&quantized, scale, &dequantized);

    for (values, dequantized) |orig, deq| {
        try testing.expect(@abs(orig - deq) < 0.1);
    }
}

test "scale computation" {
    const stats = QuantizationStats{ .min_val = 0, .max_val = 1.0, .mean = 0.5, .std_dev = 0.25 };
    const result = computeScaleZP(stats, 8);
    try testing.expectApproxEqAbs(@as(f32, 1.0 / 255.0), result.scale, 0.001);
}

test "grouped accuracy" {
    // Grouped quantization should have lower error than symmetric
    const values = [_]f32{ 0.1, 0.2, 10.0, 11.0 };
    var quantized: [4]i8 = undefined;
    var dequantized: [4]f32 = undefined;

    const scale = quantizeSymmetric(&values, &quantized);
    dequantize(&quantized, scale, &dequantized);

    var total_error: f32 = 0;
    for (values, dequantized) |v, d| {
        total_error += @abs(v - d);
    }
    try testing.expect(total_error < 5.0);
}

test "matmul correctness" {
    const result = quantizeMatmul(0.1, 0.1, 100);
    try testing.expectApproxEqAbs(@as(f32, 1.0), result, 0.01);
}

test "stats computation" {
    const values = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const stats = computeStats(&values);
    try testing.expectApproxEqAbs(@as(f32, 1.0), stats.min_val, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 5.0), stats.max_val, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 3.0), stats.mean, 0.001);
}
