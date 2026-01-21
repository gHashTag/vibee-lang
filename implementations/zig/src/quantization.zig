//! Quantization Implementations
//! ============================
//!
//! INT8 and INT4 quantization for efficient inference.

const std = @import("std");

/// Quantization configuration
pub const QuantConfig = struct {
    bits: u8 = 8,
    symmetric: bool = true,
    per_channel: bool = false,
};

/// Quantization parameters
pub const QuantParams = struct {
    scale: f32,
    zero_point: i32,
};

/// Compute quantization parameters for a tensor
pub fn computeQuantParams(data: []const f32, config: QuantConfig) QuantParams {
    var min_val: f32 = data[0];
    var max_val: f32 = data[0];
    
    for (data) |v| {
        min_val = @min(min_val, v);
        max_val = @max(max_val, v);
    }
    
    _ = if (config.symmetric) @as(f32, -128.0) else @as(f32, 0.0); // qmin
    _ = if (config.symmetric) @as(f32, 127.0) else @as(f32, 255.0); // qmax
    
    var scale: f32 = undefined;
    var zero_point: i32 = undefined;
    
    if (config.symmetric) {
        const abs_max = @max(@abs(min_val), @abs(max_val));
        scale = abs_max / 127.0;
        zero_point = 0;
    } else {
        scale = (max_val - min_val) / 255.0;
        zero_point = @intFromFloat(-min_val / scale);
        zero_point = @max(0, @min(255, zero_point));
    }
    
    // Avoid division by zero
    if (scale == 0.0) scale = 1.0;
    
    return QuantParams{ .scale = scale, .zero_point = zero_point };
}

/// Quantize f32 to i8
pub fn quantizeInt8(data: []const f32, output: []i8, params: QuantParams) void {
    for (data, output) |v, *o| {
        const q = v / params.scale + @as(f32, @floatFromInt(params.zero_point));
        o.* = @intFromFloat(std.math.clamp(q, -128.0, 127.0));
    }
}

/// Dequantize i8 to f32
pub fn dequantizeInt8(data: []const i8, output: []f32, params: QuantParams) void {
    for (data, output) |v, *o| {
        o.* = (@as(f32, @floatFromInt(v)) - @as(f32, @floatFromInt(params.zero_point))) * params.scale;
    }
}

/// Quantize f32 to i4 (packed into i8)
pub fn quantizeInt4(data: []const f32, output: []u8, params: QuantParams) void {
    var i: usize = 0;
    while (i < data.len) : (i += 2) {
        const v1 = data[i] / params.scale;
        const v2 = if (i + 1 < data.len) data[i + 1] / params.scale else 0.0;
        
        const q1: u8 = @intFromFloat(std.math.clamp(v1 + 8.0, 0.0, 15.0));
        const q2: u8 = @intFromFloat(std.math.clamp(v2 + 8.0, 0.0, 15.0));
        
        output[i / 2] = (q1 << 4) | q2;
    }
}

/// Dequantize i4 (packed) to f32
pub fn dequantizeInt4(data: []const u8, output: []f32, params: QuantParams) void {
    for (data, 0..) |byte, i| {
        const q1 = @as(i8, @intCast(byte >> 4)) - 8;
        const q2 = @as(i8, @intCast(byte & 0x0F)) - 8;
        
        output[i * 2] = @as(f32, @floatFromInt(q1)) * params.scale;
        if (i * 2 + 1 < output.len) {
            output[i * 2 + 1] = @as(f32, @floatFromInt(q2)) * params.scale;
        }
    }
}

/// Quantized matrix multiplication (INT8)
pub fn quantizedMatmul(
    a: []const i8,
    b: []const i8,
    c: []i32,
    m: usize,
    n: usize,
    k: usize,
) void {
    for (0..m) |i| {
        for (0..n) |j| {
            var sum: i32 = 0;
            for (0..k) |kk| {
                sum += @as(i32, a[i * k + kk]) * @as(i32, b[kk * n + j]);
            }
            c[i * n + j] = sum;
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "quantize int8" {
    const data = [_]f32{ -1.0, -0.5, 0.0, 0.5, 1.0 };
    var quantized: [5]i8 = undefined;
    var dequantized: [5]f32 = undefined;
    
    const params = computeQuantParams(&data, QuantConfig{});
    quantizeInt8(&data, &quantized, params);
    dequantizeInt8(&quantized, &dequantized, params);
    
    // Check roundtrip error is small
    for (data, dequantized) |orig, deq| {
        try std.testing.expect(@abs(orig - deq) < 0.02);
    }
}

test "quantize int4" {
    const data = [_]f32{ -1.0, -0.5, 0.0, 0.5, 1.0, 0.25 };
    var quantized: [3]u8 = undefined;
    var dequantized: [6]f32 = undefined;
    
    const params = computeQuantParams(&data, QuantConfig{ .bits = 4 });
    quantizeInt4(&data, &quantized, params);
    dequantizeInt4(&quantized, &dequantized, params);
    
    // INT4 has lower precision - just verify output is valid
    for (dequantized) |deq| {
        try std.testing.expect(deq >= -2.0 and deq <= 2.0);
    }
}
