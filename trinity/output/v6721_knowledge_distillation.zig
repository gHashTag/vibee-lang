// ═══════════════════════════════════════════════════════════════
// v6721: KNOWLEDGE DISTILLATION
// Teacher → Student knowledge transfer
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;

pub const DistillationConfig = struct {
    temperature: f32 = 4.0,
    alpha: f32 = 0.5,
    beta: f32 = 0.1,
    distill_attention: bool = true,
    distill_hidden: bool = true,
};

pub const DistillationLoss = struct {
    soft_target_loss: f32 = 0,
    hard_target_loss: f32 = 0,
    attention_loss: f32 = 0,
    hidden_loss: f32 = 0,

    pub fn total(self: DistillationLoss, config: DistillationConfig) f32 {
        return config.alpha * self.soft_target_loss +
            (1 - config.alpha) * self.hard_target_loss +
            config.beta * self.attention_loss;
    }
};

pub fn softmax(logits: []const f32, output: []f32, temperature: f32) void {
    const n = @min(logits.len, output.len);
    if (n == 0) return;

    var max_val: f32 = logits[0];
    for (logits[1..n]) |l| {
        if (l > max_val) max_val = l;
    }

    var sum: f64 = 0;
    for (logits[0..n], output[0..n]) |l, *o| {
        o.* = @exp((l - max_val) / temperature);
        sum += o.*;
    }

    for (output[0..n]) |*o| {
        o.* = @floatCast(@as(f64, o.*) / sum);
    }
}

pub fn klDivergence(p: []const f32, q: []const f32) f32 {
    const n = @min(p.len, q.len);
    var kl: f64 = 0;
    for (p[0..n], q[0..n]) |pi, qi| {
        if (pi > 1e-10 and qi > 1e-10) {
            kl += @as(f64, pi) * @log(@as(f64, pi) / @as(f64, qi));
        }
    }
    return @floatCast(kl);
}

pub fn softTargetLoss(teacher_logits: []const f32, student_logits: []const f32, temperature: f32) f32 {
    var teacher_probs: [1024]f32 = undefined;
    var student_probs: [1024]f32 = undefined;
    const n = @min(teacher_logits.len, 1024);

    softmax(teacher_logits[0..n], teacher_probs[0..n], temperature);
    softmax(student_logits[0..n], student_probs[0..n], temperature);

    const kl = klDivergence(teacher_probs[0..n], student_probs[0..n]);
    return kl * temperature * temperature;
}

pub fn attentionTransferLoss(teacher_attn: []const f32, student_attn: []const f32) f32 {
    const n = @min(teacher_attn.len, student_attn.len);
    var mse: f64 = 0;
    for (teacher_attn[0..n], student_attn[0..n]) |t, s| {
        const diff = @as(f64, t) - @as(f64, s);
        mse += diff * diff;
    }
    return @floatCast(mse / @as(f64, @floatFromInt(n)));
}

pub fn hiddenTransferLoss(teacher_hidden: []const f32, student_hidden: []const f32) f32 {
    return attentionTransferLoss(teacher_hidden, student_hidden);
}

pub fn combinedLoss(config: DistillationConfig, soft_loss: f32, hard_loss: f32, attn_loss: f32) f32 {
    return config.alpha * soft_loss + (1 - config.alpha) * hard_loss + config.beta * attn_loss;
}

// Tests
test "temperature scaling" {
    const config = DistillationConfig{ .temperature = 4.0 };
    try testing.expect(config.temperature == 4.0);
}

test "soft targets" {
    const teacher = [_]f32{ 2.0, 1.0, 0.5 };
    const student = [_]f32{ 1.5, 1.2, 0.8 };
    const loss = softTargetLoss(&teacher, &student, 4.0);
    try testing.expect(loss >= 0);
}

test "attention transfer" {
    const teacher = [_]f32{ 0.5, 0.3, 0.2 };
    const student = [_]f32{ 0.4, 0.35, 0.25 };
    const loss = attentionTransferLoss(&teacher, &student);
    try testing.expect(loss >= 0);
}

test "combined loss" {
    const config = DistillationConfig{};
    const total = combinedLoss(config, 0.5, 0.3, 0.1);
    try testing.expect(total >= 0);
}

test "kl divergence non-negative" {
    const p = [_]f32{ 0.5, 0.3, 0.2 };
    const q = [_]f32{ 0.4, 0.35, 0.25 };
    const kl = klDivergence(&p, &q);
    try testing.expect(kl >= 0);
}

test "softmax sums to one" {
    const logits = [_]f32{ 1.0, 2.0, 3.0 };
    var probs: [3]f32 = undefined;
    softmax(&logits, &probs, 1.0);
    var sum: f32 = 0;
    for (probs) |p| sum += p;
    try testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.001);
}
