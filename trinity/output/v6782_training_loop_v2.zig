// v6782_training_loop_v2.zig - Full Training Pipeline
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const TrainingConfig = struct {
    num_epochs: usize = 3,
    batch_size: usize = 32,
    learning_rate: f32 = 2e-5,
    warmup_steps: usize = 500,
    weight_decay: f32 = 0.01,
    max_grad_norm: f32 = 1.0,
    logging_steps: usize = 100,
    eval_steps: usize = 500,
    save_steps: usize = 1000,
};

pub const TrainingState = struct {
    global_step: usize = 0,
    epoch: usize = 0,
    best_metric: f32 = 0,
    total_loss: f64 = 0,
    num_samples: usize = 0,
};

// Training step
pub fn trainingStep(
    loss: f32,
    state: *TrainingState,
) void {
    state.global_step += 1;
    state.total_loss += @as(f64, loss);
    state.num_samples += 1;
}

// Compute average loss
pub fn averageLoss(state: *const TrainingState) f32 {
    if (state.num_samples == 0) return 0;
    return @floatCast(state.total_loss / @as(f64, @floatFromInt(state.num_samples)));
}

// Reset epoch stats
pub fn resetEpochStats(state: *TrainingState) void {
    state.total_loss = 0;
    state.num_samples = 0;
    state.epoch += 1;
}

// Should log
pub fn shouldLog(step: usize, logging_steps: usize) bool {
    return step > 0 and step % logging_steps == 0;
}

// Should evaluate
pub fn shouldEvaluate(step: usize, eval_steps: usize) bool {
    return step > 0 and step % eval_steps == 0;
}

// Should save
pub fn shouldSave(step: usize, save_steps: usize) bool {
    return step > 0 and step % save_steps == 0;
}

// PHI-based learning rate schedule
pub fn phiLearningRate(base_lr: f32, step: usize, warmup_steps: usize, total_steps: usize) f32 {
    if (step < warmup_steps) {
        // Linear warmup
        return base_lr * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(warmup_steps));
    }

    // PHI-based decay
    const progress = @as(f64, @floatFromInt(step - warmup_steps)) / @as(f64, @floatFromInt(total_steps - warmup_steps));
    const decay = math.pow(f64, PHI_INV, progress * 3.0);
    return base_lr * @as(f32, @floatCast(decay));
}

// Estimate total steps
pub fn estimateTotalSteps(dataset_size: usize, batch_size: usize, num_epochs: usize) usize {
    const steps_per_epoch = (dataset_size + batch_size - 1) / batch_size;
    return steps_per_epoch * num_epochs;
}

// Training progress
pub fn trainingProgress(step: usize, total_steps: usize) f32 {
    return @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(total_steps));
}

// Tests
test "training step" {
    var state = TrainingState{};
    trainingStep(0.5, &state);
    try testing.expectEqual(@as(usize, 1), state.global_step);
}

test "average loss" {
    var state = TrainingState{ .total_loss = 10.0, .num_samples = 5 };
    const avg = averageLoss(&state);
    try testing.expectEqual(@as(f32, 2.0), avg);
}

test "reset epoch stats" {
    var state = TrainingState{ .total_loss = 10.0, .num_samples = 5, .epoch = 0 };
    resetEpochStats(&state);
    try testing.expectEqual(@as(usize, 1), state.epoch);
    try testing.expectEqual(@as(f64, 0), state.total_loss);
}

test "should log" {
    try testing.expect(shouldLog(100, 100));
    try testing.expect(!shouldLog(50, 100));
}

test "phi learning rate warmup" {
    const lr = phiLearningRate(1e-4, 250, 500, 10000);
    try testing.expect(lr < 1e-4);
}

test "phi learning rate decay" {
    const lr_early = phiLearningRate(1e-4, 1000, 500, 10000);
    const lr_late = phiLearningRate(1e-4, 9000, 500, 10000);
    try testing.expect(lr_early > lr_late);
}

test "estimate total steps" {
    const steps = estimateTotalSteps(10000, 32, 3);
    try testing.expect(steps > 900);
}
