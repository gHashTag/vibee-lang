// ═══════════════════════════════════════════════════════════════════════════════
// igla_v3_qlora v3.0.0 - Quantized LoRA
// 65% memory reduction with 4-bit base + LoRA
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: arXiv:2305.14314
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const QLoRAConfig = struct {
    base_bits: u8 = 4, // NF4
    lora_rank: usize = 16,
    lora_alpha: f32 = 32.0,
    double_quant: bool = true,
    
    pub fn scaling(self: *const QLoRAConfig) f32 {
        return self.lora_alpha / @as(f32, @floatFromInt(self.lora_rank));
    }
};

// NF4 quantization levels (normalized float 4-bit)
pub const NF4_LEVELS: [16]f32 = [_]f32{
    -1.0, -0.6961928009986877, -0.5250730514526367, -0.39491748809814453,
    -0.28444138169288635, -0.18477343022823334, -0.09105003625154495, 0.0,
    0.07958029955625534, 0.16093020141124725, 0.24611230194568634, 0.33791524171829224,
    0.44070982933044434, 0.5626170039176941, 0.7229568362236023, 1.0,
};

// Quantize FP32 to NF4
pub fn quantizeNF4(input: []const f32, output: []u8, absmax: *f32) void {
    if (input.len == 0) return;

    // Find absmax
    var max_val: f32 = 0;
    for (input) |v| {
        const abs_v = @abs(v);
        if (abs_v > max_val) max_val = abs_v;
    }
    absmax.* = max_val;
    if (absmax.* == 0) absmax.* = 1.0;

    // Quantize (pack 2 values per byte)
    const packed_len = (input.len + 1) / 2;
    for (0..packed_len) |i| {
        const idx1 = i * 2;
        const idx2 = i * 2 + 1;

        const norm1 = input[idx1] / absmax.*;
        const q1 = findNearestNF4(norm1);

        const q2 = if (idx2 < input.len) findNearestNF4(input[idx2] / absmax.*) else 0;

        output[i] = (q1 << 4) | q2;
    }
}

// Find nearest NF4 level
fn findNearestNF4(value: f32) u8 {
    var best_idx: u8 = 0;
    var best_dist: f32 = @abs(value - NF4_LEVELS[0]);

    for (1..16) |i| {
        const dist = @abs(value - NF4_LEVELS[i]);
        if (dist < best_dist) {
            best_dist = dist;
            best_idx = @intCast(i);
        }
    }

    return best_idx;
}

// Dequantize NF4 to FP32
pub fn dequantizeNF4(input: []const u8, output: []f32, absmax: f32, num_elements: usize) void {
    for (0..num_elements) |i| {
        const byte_idx = i / 2;
        const is_high = (i % 2) == 0;

        const q = if (is_high) (input[byte_idx] >> 4) else (input[byte_idx] & 0x0F);
        output[i] = NF4_LEVELS[q] * absmax;
    }
}

// Double quantization: quantize the absmax values
pub fn doubleQuantize(absmax_values: []const f32, quantized: []u8, scale: *f32) void {
    if (absmax_values.len == 0) return;

    var max_absmax: f32 = 0;
    for (absmax_values) |v| {
        if (v > max_absmax) max_absmax = v;
    }
    scale.* = max_absmax / 127.0;
    if (scale.* == 0) scale.* = 1.0;

    for (0..absmax_values.len) |i| {
        const q = @round(absmax_values[i] / scale.*);
        quantized[i] = @intFromFloat(@max(0.0, @min(255.0, q)));
    }
}

// QLoRA forward: quantized base + LoRA delta
pub fn qloraForward(
    input: []const f32,
    base_quantized: []const u8,
    base_absmax: f32,
    lora_a: []const f32,
    lora_b: []const f32,
    output: []f32,
    in_features: usize,
    out_features: usize,
    rank: usize,
    scaling: f32,
) void {
    // Dequantize base weights
    var base_fp32: [65536]f32 = undefined;
    dequantizeNF4(base_quantized, base_fp32[0 .. in_features * out_features], base_absmax, in_features * out_features);

    // Base forward: W*x
    for (0..out_features) |o| {
        var sum: f32 = 0;
        for (0..in_features) |i| {
            sum += base_fp32[o * in_features + i] * input[i];
        }
        output[o] = sum;
    }

    // LoRA delta: (B*A)*x * scaling
    var intermediate: [64]f32 = [_]f32{0} ** 64;

    // A*x
    for (0..rank) |r| {
        var sum: f32 = 0;
        for (0..in_features) |i| {
            sum += lora_a[r * in_features + i] * input[i];
        }
        intermediate[r] = sum;
    }

    // B*(A*x) + add to output
    for (0..out_features) |o| {
        var sum: f32 = 0;
        for (0..rank) |r| {
            sum += lora_b[o * rank + r] * intermediate[r];
        }
        output[o] += sum * scaling;
    }
}

// Calculate memory savings
pub fn memorySavings(base_bits: u8, lora_rank: usize, in_features: usize, out_features: usize) f32 {
    const full_memory = in_features * out_features * 2; // FP16
    const quantized_memory = (in_features * out_features * base_bits) / 8;
    const lora_memory = (lora_rank * in_features + out_features * lora_rank) * 2; // FP16

    const total_qlora = quantized_memory + lora_memory;
    return 1.0 - @as(f32, @floatFromInt(total_qlora)) / @as(f32, @floatFromInt(full_memory));
}

// Tests
test "nf4 quantize dequantize" {
    const input = [_]f32{ -1.0, -0.5, 0.0, 0.5, 1.0 };
    var quantized: [3]u8 = undefined;
    var absmax: f32 = undefined;

    quantizeNF4(&input, &quantized, &absmax);

    var output: [5]f32 = undefined;
    dequantizeNF4(&quantized, &output, absmax, 5);

    // Check approximate reconstruction
    for (0..5) |i| {
        try testing.expectApproxEqAbs(input[i], output[i], 0.2);
    }
}

test "find nearest nf4" {
    try testing.expectEqual(@as(u8, 0), findNearestNF4(-1.0));
    try testing.expectEqual(@as(u8, 7), findNearestNF4(0.0));
    try testing.expectEqual(@as(u8, 15), findNearestNF4(1.0));
}

test "memory savings" {
    const savings = memorySavings(4, 16, 768, 768);
    try testing.expect(savings > 0.5); // Should save >50%
    try testing.expect(savings < 0.9);
}

test "qlora config scaling" {
    const config = QLoRAConfig{ .lora_rank = 16, .lora_alpha = 32.0 };
    try testing.expectApproxEqAbs(@as(f32, 2.0), config.scaling(), 0.001);
}

test "double quantize" {
    const absmax = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var quantized: [4]u8 = undefined;
    var scale: f32 = undefined;

    doubleQuantize(&absmax, &quantized, &scale);

    try testing.expect(scale > 0);
}
