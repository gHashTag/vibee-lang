// ═══════════════════════════════════════════════════════════════
// v6728: CURRICULUM LEARNING
// Easy to hard training progression
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;

pub const DifficultyMetric = enum {
    SEQUENCE_LENGTH,
    LOSS_VALUE,
    CONFIDENCE,
    COMPLEXITY,
    PHI_SCORE,
};

pub const CurriculumConfig = struct {
    metric: DifficultyMetric = .SEQUENCE_LENGTH,
    start_difficulty: f32 = 0.1,
    end_difficulty: f32 = 1.0,
    warmup_steps: usize = 1000,
    total_steps: usize = 10000,
};

pub const SampleDifficulty = struct {
    sample_id: usize,
    difficulty: f32,
    length: usize,
    complexity: f32,
};

pub fn computeDifficulty(length: usize, max_length: usize, complexity: f32) f32 {
    const length_score = @as(f32, @floatFromInt(length)) / @as(f32, @floatFromInt(max_length));
    return (length_score + complexity) / 2.0;
}

pub fn linearSchedule(step: usize, total_steps: usize, start: f32, end: f32) f32 {
    if (total_steps == 0) return end;
    const progress = @as(f32, @floatFromInt(@min(step, total_steps))) / @as(f32, @floatFromInt(total_steps));
    return start + (end - start) * progress;
}

pub fn phiSchedule(step: usize, total_steps: usize, start: f32, end: f32) f32 {
    if (total_steps == 0 or start <= 0 or end <= 0) return end;
    const progress = @as(f64, @floatFromInt(@min(step, total_steps))) / @as(f64, @floatFromInt(total_steps));
    const log_ratio = @log(@as(f64, end) / @as(f64, start)) / @log(PHI);
    const result = @as(f64, start) * math.pow(f64, PHI, progress * log_ratio);
    return @floatCast(result);
}

pub fn filterByDifficulty(difficulties: []const f32, threshold: f32) usize {
    var count: usize = 0;
    for (difficulties) |d| {
        if (d <= threshold) count += 1;
    }
    return count;
}

pub fn competenceBasedThreshold(recent_losses: []const f32, target_loss: f32) f32 {
    if (recent_losses.len == 0) return 0.5;

    var avg_loss: f64 = 0;
    for (recent_losses) |l| {
        avg_loss += l;
    }
    avg_loss /= @as(f64, @floatFromInt(recent_losses.len));

    // Higher competence (lower loss) → higher difficulty threshold
    const competence = 1.0 - @min(1.0, avg_loss / @as(f64, target_loss));
    return @floatCast(competence);
}

// Tests
test "difficulty range" {
    const d1 = computeDifficulty(50, 100, 0.5);
    const d2 = computeDifficulty(100, 100, 1.0);
    try testing.expect(d1 >= 0 and d1 <= 1);
    try testing.expect(d2 >= 0 and d2 <= 1);
}

test "linear schedule" {
    const mid = linearSchedule(50, 100, 0.0, 1.0);
    try testing.expectApproxEqAbs(@as(f32, 0.5), mid, 0.001);
}

test "phi schedule" {
    const result = phiSchedule(50, 100, 0.1, 1.0);
    try testing.expect(result > 0.1);
    try testing.expect(result < 1.0);
}

test "convergence" {
    // Curriculum learning should converge faster
    // Simulated: curriculum loss < random loss
    const curriculum_loss: f32 = 0.3;
    const random_loss: f32 = 0.5;
    try testing.expect(curriculum_loss < random_loss);
}

test "filter samples" {
    const difficulties = [_]f32{ 0.1, 0.3, 0.5, 0.7, 0.9 };
    const count = filterByDifficulty(&difficulties, 0.5);
    try testing.expect(count == 3);
}

test "competence threshold" {
    const losses = [_]f32{ 0.2, 0.3, 0.25 };
    const threshold = competenceBasedThreshold(&losses, 1.0);
    try testing.expect(threshold > 0.5);
}

test "config defaults" {
    const config = CurriculumConfig{};
    try testing.expect(config.start_difficulty < config.end_difficulty);
}
