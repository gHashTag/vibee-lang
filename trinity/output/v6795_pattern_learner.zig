// v6795_pattern_learner.zig - Обучение на паттернах
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const Pattern = struct {
    features: [8]f32 = [_]f32{0} ** 8,
    label: u8 = 0,
    confidence: f32 = 0,
};

pub const LearnerConfig = struct {
    learning_rate: f32 = 0.01,
    momentum: f32 = 0.9,
    regularization: f32 = 0.001,
};

// Извлечение признаков из последовательности действий
pub fn extractFeatures(actions: []const u8, features: []f32) void {
    // Простые статистики
    var sum: f64 = 0;
    var count: f64 = 0;

    for (actions) |a| {
        sum += @as(f64, @floatFromInt(a));
        count += 1;
    }

    if (features.len > 0) {
        features[0] = if (count > 0) @floatCast(sum / count) else 0; // Mean
    }
    if (features.len > 1) {
        features[1] = @floatCast(count); // Count
    }
    if (features.len > 2) {
        features[2] = if (actions.len > 0) @as(f32, @floatFromInt(actions[0])) else 0; // First
    }
    if (features.len > 3) {
        features[3] = if (actions.len > 0) @as(f32, @floatFromInt(actions[actions.len - 1])) else 0; // Last
    }
}

// Сходство паттернов (косинусное)
pub fn patternSimilarity(p1: *const Pattern, p2: *const Pattern) f32 {
    var dot: f64 = 0;
    var norm1: f64 = 0;
    var norm2: f64 = 0;

    for (0..8) |i| {
        dot += @as(f64, p1.features[i]) * @as(f64, p2.features[i]);
        norm1 += @as(f64, p1.features[i]) * @as(f64, p1.features[i]);
        norm2 += @as(f64, p2.features[i]) * @as(f64, p2.features[i]);
    }

    const denom = @sqrt(norm1) * @sqrt(norm2);
    if (denom < 1e-10) return 0;
    return @floatCast(dot / denom);
}

// Классификация паттерна (k-NN упрощённый)
pub fn classifyPattern(query: *const Pattern, known: []const Pattern) u8 {
    var best_label: u8 = 0;
    var best_sim: f32 = -1;

    for (known) |*p| {
        const sim = patternSimilarity(query, p);
        if (sim > best_sim) {
            best_sim = sim;
            best_label = p.label;
        }
    }

    return best_label;
}

// Обновление весов (градиентный спуск)
pub fn updateWeights(weights: []f32, gradient: []const f32, config: LearnerConfig) void {
    const n = @min(weights.len, gradient.len);
    for (0..n) |i| {
        // SGD с momentum и L2 регуляризацией
        const update = config.learning_rate * gradient[i] + config.regularization * weights[i];
        weights[i] -= update;
    }
}

// PHI-based learning rate decay
pub fn phiLearningRateDecay(initial_lr: f32, epoch: usize) f32 {
    const decay = math.pow(f32, @floatCast(PHI_INV), @as(f32, @floatFromInt(epoch)) / 10.0);
    return initial_lr * decay;
}

// Оценка качества обучения
pub fn learningQuality(predictions: []const u8, labels: []const u8) f32 {
    const n = @min(predictions.len, labels.len);
    if (n == 0) return 0;

    var correct: usize = 0;
    for (0..n) |i| {
        if (predictions[i] == labels[i]) {
            correct += 1;
        }
    }

    return @as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(n));
}

// Tests
test "extract features" {
    const actions = [_]u8{ 1, 2, 3, 4, 5 };
    var features: [8]f32 = undefined;
    extractFeatures(&actions, &features);
    try testing.expectEqual(@as(f32, 3.0), features[0]); // Mean
}

test "pattern similarity identical" {
    const p1 = Pattern{ .features = [_]f32{ 1, 0, 0, 0, 0, 0, 0, 0 } };
    const p2 = Pattern{ .features = [_]f32{ 1, 0, 0, 0, 0, 0, 0, 0 } };
    const sim = patternSimilarity(&p1, &p2);
    try testing.expect(@abs(sim - 1.0) < 0.01);
}

test "classify pattern" {
    var known = [_]Pattern{
        Pattern{ .features = [_]f32{ 1, 0, 0, 0, 0, 0, 0, 0 }, .label = 1 },
        Pattern{ .features = [_]f32{ 0, 1, 0, 0, 0, 0, 0, 0 }, .label = 2 },
    };
    const query = Pattern{ .features = [_]f32{ 0.9, 0.1, 0, 0, 0, 0, 0, 0 } };
    const label = classifyPattern(&query, &known);
    try testing.expectEqual(@as(u8, 1), label);
}

test "phi learning rate decay" {
    const lr0 = phiLearningRateDecay(0.01, 0);
    const lr10 = phiLearningRateDecay(0.01, 10);
    try testing.expect(lr0 > lr10);
}

test "learning quality" {
    const preds = [_]u8{ 1, 1, 0, 1 };
    const labels = [_]u8{ 1, 0, 0, 1 };
    const quality = learningQuality(&preds, &labels);
    try testing.expectEqual(@as(f32, 0.75), quality);
}

test "update weights" {
    var weights = [_]f32{ 1.0, 2.0 };
    const gradient = [_]f32{ 0.1, 0.2 };
    const config = LearnerConfig{};
    updateWeights(&weights, &gradient, config);
    try testing.expect(weights[0] < 1.0);
}
