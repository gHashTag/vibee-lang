// v6743_lora_adapter.zig - LoRA Low-Rank Adaptation
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const LoRAConfig = struct {
    rank: usize = 8,
    alpha: f32 = 16.0,
    dropout: f32 = 0.0,
};

pub fn phiRank(base: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(base)) * PHI);
}

pub fn phiAlpha(rank: usize) f32 {
    return @as(f32, @floatFromInt(rank)) * @as(f32, @floatCast(PHI));
}

pub fn loraScale(alpha: f32, rank: usize) f32 {
    return alpha / @as(f32, @floatFromInt(rank));
}

pub fn loraForward(
    input: []const f32,
    w0_output: []const f32,
    lora_a: []const f32,
    lora_b: []const f32,
    rank: usize,
    alpha: f32,
    output: []f32,
) void {
    const scale = loraScale(alpha, rank);

    // Compute BA * x (simplified: assume proper dimensions)
    for (output, 0..) |*out, i| {
        var lora_contrib: f32 = 0;
        for (0..rank) |r| {
            var a_sum: f32 = 0;
            for (input, 0..) |inp, j| {
                const a_idx = r * input.len + j;
                if (a_idx < lora_a.len) {
                    a_sum += inp * lora_a[a_idx];
                }
            }
            const b_idx = i * rank + r;
            if (b_idx < lora_b.len) {
                lora_contrib += a_sum * lora_b[b_idx];
            }
        }
        out.* = w0_output[i] + scale * lora_contrib;
    }
}

pub fn mergeWeights(w0: []f32, lora_a: []const f32, lora_b: []const f32, rank: usize, alpha: f32, d: usize, k: usize) void {
    const scale = loraScale(alpha, rank);

    // W' = W0 + scale * B @ A
    for (0..d) |i| {
        for (0..k) |j| {
            var ba: f32 = 0;
            for (0..rank) |r| {
                const b_idx = i * rank + r;
                const a_idx = r * k + j;
                if (b_idx < lora_b.len and a_idx < lora_a.len) {
                    ba += lora_b[b_idx] * lora_a[a_idx];
                }
            }
            const w_idx = i * k + j;
            if (w_idx < w0.len) {
                w0[w_idx] += scale * ba;
            }
        }
    }
}

pub fn parameterReduction(d: usize, k: usize, rank: usize) f32 {
    const full_params = d * k;
    const lora_params = rank * (d + k);
    return @as(f32, @floatFromInt(full_params)) / @as(f32, @floatFromInt(lora_params));
}

// Tests
test "phi rank" {
    try testing.expectEqual(@as(usize, 12), phiRank(8));
}

test "phi alpha" {
    const alpha = phiAlpha(8);
    try testing.expect(@abs(alpha - 12.944) < 0.1);
}

test "lora scale" {
    const scale = loraScale(16.0, 8);
    try testing.expectEqual(@as(f32, 2.0), scale);
}

test "parameter reduction" {
    const reduction = parameterReduction(768, 768, 8);
    try testing.expect(reduction > 40.0); // ~48x reduction
}

test "config defaults" {
    const config = LoRAConfig{};
    try testing.expectEqual(@as(usize, 8), config.rank);
}

test "merge weights" {
    var w0 = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const lora_a = [_]f32{ 0.1, 0.2 };
    const lora_b = [_]f32{ 0.3, 0.4 };
    mergeWeights(&w0, &lora_a, &lora_b, 1, 1.0, 2, 2);
    try testing.expect(w0[0] != 1.0);
}
