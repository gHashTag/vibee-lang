// ═══════════════════════════════════════════════════════════════
// v6727: MIXED PRECISION TRAINING
// FP16/BF16 with loss scaling
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;

pub const PrecisionMode = enum { FP32, FP16, BF16, TF32 };

pub const LossScaler = struct {
    scale: f32 = 65536.0,
    growth_factor: f32 = 2.0,
    backoff_factor: f32 = 0.5,
    growth_interval: usize = 2000,
    consecutive_good: usize = 0,

    pub fn update(self: *LossScaler, overflow: bool) void {
        if (overflow) {
            self.scale *= self.backoff_factor;
            self.consecutive_good = 0;
        } else {
            self.consecutive_good += 1;
            if (self.consecutive_good >= self.growth_interval) {
                self.scale *= self.growth_factor;
                self.consecutive_good = 0;
            }
        }
    }
};

pub const MixedPrecisionConfig = struct {
    compute_dtype: PrecisionMode = .FP16,
    param_dtype: PrecisionMode = .FP32,
    output_dtype: PrecisionMode = .FP32,
    initial_scale: f32 = 65536.0,
};

pub fn castToFP16(fp32: f32) f16 {
    return @floatCast(fp32);
}

pub fn castToFP32(fp16: f16) f32 {
    return @floatCast(fp16);
}

pub fn checkOverflow(gradients: []const f32) bool {
    for (gradients) |g| {
        if (math.isNan(g) or math.isInf(g)) {
            return true;
        }
    }
    return false;
}

pub fn scaleGradients(gradients: []f32, scale: f32) void {
    for (gradients) |*g| {
        g.* *= scale;
    }
}

pub fn unscaleGradients(gradients: []f32, scale: f32) void {
    if (scale == 0) return;
    for (gradients) |*g| {
        g.* /= scale;
    }
}

pub fn clipGradients(gradients: []f32, max_norm: f32) f32 {
    var total_norm: f64 = 0;
    for (gradients) |g| {
        total_norm += @as(f64, g) * @as(f64, g);
    }
    total_norm = @sqrt(total_norm);

    const clip_coef = @as(f64, max_norm) / (total_norm + 1e-6);
    if (clip_coef < 1.0) {
        for (gradients) |*g| {
            g.* = @floatCast(@as(f64, g.*) * clip_coef);
        }
    }

    return @floatCast(total_norm);
}

pub fn memoryReduction(mode: PrecisionMode) f32 {
    return switch (mode) {
        .FP32 => 1.0,
        .FP16, .BF16 => 0.5,
        .TF32 => 0.75,
    };
}

// Tests
test "fp16 cast" {
    const fp32: f32 = 1.5;
    const fp16 = castToFP16(fp32);
    const back = castToFP32(fp16);
    try testing.expectApproxEqAbs(fp32, back, 0.001);
}

test "loss scaling" {
    var scaler = LossScaler{};
    const initial = scaler.scale;

    scaler.update(false);
    try testing.expect(scaler.scale >= initial);

    scaler.update(true);
    try testing.expect(scaler.scale < initial);
}

test "overflow detection" {
    const normal = [_]f32{ 1.0, 2.0, 3.0 };
    try testing.expect(!checkOverflow(&normal));

    const with_inf = [_]f32{ 1.0, math.inf(f32), 3.0 };
    try testing.expect(checkOverflow(&with_inf));

    const with_nan = [_]f32{ 1.0, math.nan(f32), 3.0 };
    try testing.expect(checkOverflow(&with_nan));
}

test "training stability" {
    var gradients = [_]f32{ 0.1, 0.2, 0.3 };
    scaleGradients(&gradients, 65536.0);
    try testing.expect(!checkOverflow(&gradients));
    unscaleGradients(&gradients, 65536.0);
    try testing.expectApproxEqAbs(@as(f32, 0.1), gradients[0], 0.001);
}

test "gradient clipping" {
    var gradients = [_]f32{ 3.0, 4.0 };
    const norm = clipGradients(&gradients, 1.0);
    try testing.expect(norm > 0);

    var new_norm: f64 = 0;
    for (gradients) |g| {
        new_norm += @as(f64, g) * @as(f64, g);
    }
    new_norm = @sqrt(new_norm);
    try testing.expect(new_norm <= 1.01);
}

test "memory reduction" {
    const fp16_reduction = memoryReduction(.FP16);
    try testing.expectApproxEqAbs(@as(f32, 0.5), fp16_reduction, 0.001);
}
