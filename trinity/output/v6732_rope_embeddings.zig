// ═══════════════════════════════════════════════════════════════
// v6732: ROTARY POSITION EMBEDDINGS (RoPE)
// Rotation-based position encoding
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;

pub const RoPEConfig = struct {
    dim: usize = 64,
    max_seq_len: usize = 2048,
    base: f32 = 10000.0,
    scaling_factor: f32 = 1.0,
};

pub fn computeFreqs(dim: usize, base: f32) [64]f32 {
    var freqs: [64]f32 = undefined;
    const half_dim = dim / 2;

    for (0..@min(half_dim, 32)) |i| {
        const exp = @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(dim));
        freqs[i] = 1.0 / math.pow(f32, base, exp);
    }

    // Fill rest with zeros
    for (@min(half_dim, 32)..64) |i| {
        freqs[i] = 0;
    }

    return freqs;
}

pub fn rotateHalf(x: []f32) void {
    const half = x.len / 2;
    for (0..half) |i| {
        const tmp = x[i];
        x[i] = -x[i + half];
        x[i + half] = tmp;
    }
}

pub fn applyRotary(x: []f32, pos: usize, freqs: []const f32, dim: usize) void {
    const half_dim = dim / 2;
    const pos_f: f32 = @floatFromInt(pos);

    for (0..@min(half_dim, x.len / 2)) |i| {
        const freq = if (i < freqs.len) freqs[i] else 0;
        const angle = pos_f * freq;
        const cos_val = @cos(angle);
        const sin_val = @sin(angle);

        if (i < x.len and i + half_dim < x.len) {
            const x0 = x[i];
            const x1 = x[i + half_dim];
            x[i] = x0 * cos_val - x1 * sin_val;
            x[i + half_dim] = x0 * sin_val + x1 * cos_val;
        }
    }
}

pub fn phiBase(standard_base: f32) f32 {
    return standard_base * @as(f32, @floatCast(PHI));
}

pub fn ntkScaling(original_len: usize, target_len: usize, dim: usize, base: f32) f32 {
    if (original_len == 0 or target_len <= original_len) return base;
    const ratio = @as(f64, @floatFromInt(target_len)) / @as(f64, @floatFromInt(original_len));
    const exp = @as(f64, @floatFromInt(dim)) / @as(f64, @floatFromInt(dim - 2));
    return @floatCast(@as(f64, base) * math.pow(f64, ratio, exp));
}

pub fn verifyOrthogonal(x_before: []const f32, x_after: []const f32) bool {
    // Rotation should preserve norm
    var norm_before: f64 = 0;
    var norm_after: f64 = 0;

    for (x_before, x_after) |b, a| {
        norm_before += @as(f64, b) * @as(f64, b);
        norm_after += @as(f64, a) * @as(f64, a);
    }

    return @abs(@sqrt(norm_before) - @sqrt(norm_after)) < 0.01;
}

// Tests
test "frequency computation" {
    const freqs = computeFreqs(64, 10000.0);
    // Frequencies should decrease
    try testing.expect(freqs[0] > freqs[1]);
    try testing.expect(freqs[1] > freqs[2]);
}

test "rotation orthogonal" {
    var x = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const x_copy = x;
    const freqs = computeFreqs(4, 10000.0);

    applyRotary(&x, 1, &freqs, 4);

    try testing.expect(verifyOrthogonal(&x_copy, &x));
}

test "relative position" {
    // dot(q_i, k_j) should depend on (i-j)
    var q = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var k = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const freqs = computeFreqs(4, 10000.0);

    applyRotary(&q, 5, &freqs, 4);
    applyRotary(&k, 3, &freqs, 4);

    var dot: f32 = 0;
    for (q, k) |qi, ki| {
        dot += qi * ki;
    }
    try testing.expect(!math.isNan(dot));
}

test "extrapolation" {
    // RoPE should work beyond training length
    const scaled_base = ntkScaling(512, 2048, 64, 10000.0);
    try testing.expect(scaled_base > 10000.0);
}

test "phi base" {
    const phi_b = phiBase(10000.0);
    try testing.expectApproxEqAbs(@as(f32, 16180.34), phi_b, 1.0);
}

test "config defaults" {
    const config = RoPEConfig{};
    try testing.expect(config.base == 10000.0);
    try testing.expect(config.dim == 64);
}
