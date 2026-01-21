// v6784_checkpoint_manager.zig - Checkpoint Manager (Save/Load)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const CheckpointConfig = struct {
    save_total_limit: usize = 3,
    save_best_only: bool = true,
    metric_for_best: []const u8 = "eval_loss",
    greater_is_better: bool = false,
};

pub const CheckpointInfo = struct {
    step: usize,
    epoch: usize,
    metric: f32,
    path: [256]u8 = [_]u8{0} ** 256,
};

// Compare checkpoints for best selection
pub fn isBetterCheckpoint(new_metric: f32, old_metric: f32, greater_is_better: bool) bool {
    if (greater_is_better) {
        return new_metric > old_metric;
    }
    return new_metric < old_metric;
}

// Generate checkpoint path
pub fn generateCheckpointPath(base_path: []const u8, step: usize, output: []u8) void {
    var i: usize = 0;
    for (base_path) |c| {
        if (i < output.len) {
            output[i] = c;
            i += 1;
        }
    }

    // Add step number (simplified)
    const step_str = "-step-";
    for (step_str) |c| {
        if (i < output.len) {
            output[i] = c;
            i += 1;
        }
    }

    // Convert step to string (simplified)
    var step_copy = step;
    var digits: [20]u8 = undefined;
    var digit_count: usize = 0;

    if (step_copy == 0) {
        digits[0] = '0';
        digit_count = 1;
    } else {
        while (step_copy > 0) {
            digits[digit_count] = @intCast((step_copy % 10) + '0');
            step_copy /= 10;
            digit_count += 1;
        }
    }

    // Reverse and append
    while (digit_count > 0) {
        digit_count -= 1;
        if (i < output.len) {
            output[i] = digits[digit_count];
            i += 1;
        }
    }
}

// Should save checkpoint
pub fn shouldSaveCheckpoint(
    current_metric: f32,
    best_metric: f32,
    config: CheckpointConfig,
) bool {
    if (!config.save_best_only) return true;
    return isBetterCheckpoint(current_metric, best_metric, config.greater_is_better);
}

// PHI-based checkpoint interval
pub fn phiCheckpointInterval(total_steps: usize, num_checkpoints: usize) usize {
    const base = total_steps / num_checkpoints;
    return @intFromFloat(@as(f64, @floatFromInt(base)) * PHI_INV);
}

// Estimate checkpoint size (bytes)
pub fn estimateCheckpointSize(num_params: usize, dtype_bytes: usize) usize {
    // Parameters + optimizer states (2x for Adam)
    return num_params * dtype_bytes * 3;
}

// Tests
test "is better checkpoint loss" {
    try testing.expect(isBetterCheckpoint(0.5, 0.6, false)); // Lower is better
    try testing.expect(!isBetterCheckpoint(0.7, 0.6, false));
}

test "is better checkpoint accuracy" {
    try testing.expect(isBetterCheckpoint(0.9, 0.8, true)); // Higher is better
    try testing.expect(!isBetterCheckpoint(0.7, 0.8, true));
}

test "generate checkpoint path" {
    var path: [256]u8 = [_]u8{0} ** 256;
    generateCheckpointPath("model", 1000, &path);
    try testing.expect(path[0] == 'm');
}

test "should save checkpoint" {
    const config = CheckpointConfig{ .save_best_only = true, .greater_is_better = false };
    try testing.expect(shouldSaveCheckpoint(0.4, 0.5, config));
    try testing.expect(!shouldSaveCheckpoint(0.6, 0.5, config));
}

test "phi checkpoint interval" {
    const interval = phiCheckpointInterval(10000, 5);
    try testing.expect(interval > 1000);
}

test "estimate checkpoint size" {
    const size = estimateCheckpointSize(1000000, 4);
    try testing.expectEqual(@as(usize, 12000000), size);
}
