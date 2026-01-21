// ═══════════════════════════════════════════════════════════════════════════════
// qml_lora v1.0.0 - Low-Rank Adaptation
// Эффективное дообучение с минимальными параметрами
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: arXiv:2106.09685
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const LoRAConfig = struct {
    rank: usize = 16,
    alpha: f32 = 32.0,
    dropout: f32 = 0.0,
    // Scaling factor = alpha / rank
    pub fn scaling(self: *const LoRAConfig) f32 {
        return self.alpha / @as(f32, @floatFromInt(self.rank));
    }
};

pub const LoRALayer = struct {
    // A: [rank, d_in] - down projection
    // B: [d_out, rank] - up projection
    a_data: []f32,
    b_data: []f32,
    rank: usize,
    d_in: usize,
    d_out: usize,
    scaling: f32,
};

// Initialize LoRA A matrix with Kaiming uniform
pub fn initLoRAMatrixA(data: []f32, rank: usize, d_in: usize) void {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();
    const std_dev: f32 = 1.0 / @sqrt(@as(f32, @floatFromInt(d_in)));

    for (0..rank * d_in) |i| {
        data[i] = (random.float(f32) * 2.0 - 1.0) * std_dev;
    }
}

// Initialize LoRA B matrix with zeros
pub fn initLoRAMatrixB(data: []f32, d_out: usize, rank: usize) void {
    for (0..d_out * rank) |i| {
        data[i] = 0.0;
    }
}

// LoRA forward: output = W*x + (B*A)*x * scaling
// Here we compute just the LoRA delta: (B*A)*x * scaling
pub fn loraForward(
    input: []const f32,
    a: []const f32,
    b: []const f32,
    output: []f32,
    rank: usize,
    d_in: usize,
    d_out: usize,
    scaling: f32,
) void {
    // Intermediate: A*x [rank]
    var intermediate: [64]f32 = [_]f32{0} ** 64;

    // A*x: [rank, d_in] * [d_in] = [rank]
    for (0..rank) |r| {
        var sum: f32 = 0;
        for (0..d_in) |i| {
            sum += a[r * d_in + i] * input[i];
        }
        intermediate[r] = sum;
    }

    // B*(A*x): [d_out, rank] * [rank] = [d_out]
    for (0..d_out) |o| {
        var sum: f32 = 0;
        for (0..rank) |r| {
            sum += b[o * rank + r] * intermediate[r];
        }
        output[o] = sum * scaling;
    }
}

// Merge LoRA into base weights: W_merged = W + B*A*scaling
pub fn mergeLoRA(
    base_weights: []f32,
    a: []const f32,
    b: []const f32,
    rank: usize,
    d_in: usize,
    d_out: usize,
    scaling: f32,
) void {
    // Compute B*A and add to base_weights
    for (0..d_out) |o| {
        for (0..d_in) |i| {
            var delta: f32 = 0;
            for (0..rank) |r| {
                delta += b[o * rank + r] * a[r * d_in + i];
            }
            base_weights[o * d_in + i] += delta * scaling;
        }
    }
}

// Unmerge LoRA from weights: W = W_merged - B*A*scaling
pub fn unmergeLoRA(
    merged_weights: []f32,
    a: []const f32,
    b: []const f32,
    rank: usize,
    d_in: usize,
    d_out: usize,
    scaling: f32,
) void {
    for (0..d_out) |o| {
        for (0..d_in) |i| {
            var delta: f32 = 0;
            for (0..rank) |r| {
                delta += b[o * rank + r] * a[r * d_in + i];
            }
            merged_weights[o * d_in + i] -= delta * scaling;
        }
    }
}

// Calculate trainable parameters for LoRA
pub fn loraTrainableParams(rank: usize, d_in: usize, d_out: usize) usize {
    return rank * d_in + d_out * rank;
}

// Calculate parameter reduction ratio
pub fn loraReductionRatio(rank: usize, d_in: usize, d_out: usize) f32 {
    const full_params = d_in * d_out;
    const lora_params = loraTrainableParams(rank, d_in, d_out);
    return @as(f32, @floatFromInt(full_params)) / @as(f32, @floatFromInt(lora_params));
}

// PHI-optimal rank for given dimension
pub fn phiOptimalRank(dim: usize) usize {
    // rank ≈ dim * φ^(-3) ≈ dim * 0.236
    const rank_f: f64 = @as(f64, @floatFromInt(dim)) * PHI_INV * PHI_INV * PHI_INV;
    return @max(4, @as(usize, @intFromFloat(@round(rank_f))));
}

// Tests
test "lora config scaling" {
    const config = LoRAConfig{ .rank = 16, .alpha = 32.0 };
    try testing.expectApproxEqAbs(@as(f32, 2.0), config.scaling(), 0.001);
}

test "init lora matrices" {
    var a: [64]f32 = undefined;
    var b: [64]f32 = undefined;
    initLoRAMatrixA(&a, 8, 8);
    initLoRAMatrixB(&b, 8, 8);

    // A should have non-zero values
    var a_sum: f32 = 0;
    for (a) |v| a_sum += @abs(v);
    try testing.expect(a_sum > 0);

    // B should be all zeros
    var b_sum: f32 = 0;
    for (b) |v| b_sum += @abs(v);
    try testing.expectApproxEqAbs(@as(f32, 0.0), b_sum, 0.001);
}

test "lora forward" {
    // Simple test: rank=2, d_in=4, d_out=4
    const input = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    const a = [_]f32{ 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 }; // [2, 4]
    const b = [_]f32{ 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0 }; // [4, 2]
    var output: [4]f32 = undefined;

    loraForward(&input, &a, &b, &output, 2, 4, 4, 1.0);

    // A*x = [2, 2], B*(A*x) = [2, 2, 2, 2]
    try testing.expectApproxEqAbs(@as(f32, 2.0), output[0], 0.001);
}

test "lora trainable params" {
    // rank=16, d_in=768, d_out=768
    const params = loraTrainableParams(16, 768, 768);
    try testing.expectEqual(@as(usize, 16 * 768 + 768 * 16), params);
}

test "lora reduction ratio" {
    const ratio = loraReductionRatio(16, 768, 768);
    // Full: 768*768 = 589824, LoRA: 16*768*2 = 24576
    // Ratio ≈ 24
    try testing.expect(ratio > 20);
}

test "phi optimal rank" {
    const rank = phiOptimalRank(768);
    try testing.expect(rank >= 4);
    try testing.expect(rank <= 256);
}
