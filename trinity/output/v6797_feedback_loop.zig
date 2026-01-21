// v6797_feedback_loop.zig - Цикл обратной связи КОЩЕЯ
// БЕССМЕРТНЫЙ ЦИКЛ САМОУЛУЧШЕНИЯ
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const FeedbackType = enum {
    positive, // Успех, усилить паттерн
    negative, // Неудача, ослабить паттерн
    neutral, // Нет изменений
};

pub const FeedbackSignal = struct {
    feedback_type: FeedbackType,
    magnitude: f32,
    source: [32]u8 = [_]u8{0} ** 32,
    timestamp: u64 = 0,
};

pub const LoopState = struct {
    iteration: usize = 0,
    cumulative_reward: f64 = 0,
    learning_rate: f32 = 0.1,
    momentum: f32 = 0,
    converged: bool = false,
};

// Обработка сигнала обратной связи
pub fn processFeedback(state: *LoopState, signal: FeedbackSignal) void {
    const reward: f64 = switch (signal.feedback_type) {
        .positive => @as(f64, signal.magnitude),
        .negative => -@as(f64, signal.magnitude),
        .neutral => 0,
    };

    // Экспоненциальное скользящее среднее с PHI
    state.cumulative_reward = state.cumulative_reward * PHI_INV + reward * (1.0 - PHI_INV);
    state.iteration += 1;

    // Адаптивный learning rate
    if (signal.feedback_type == .negative) {
        state.learning_rate *= @floatCast(PHI_INV);
    } else if (signal.feedback_type == .positive) {
        state.learning_rate = @min(0.5, state.learning_rate * @as(f32, @floatCast(1.0 + (1.0 - PHI_INV) * 0.1)));
    }
}

// Проверка сходимости
pub fn checkConvergence(state: *LoopState, threshold: f32) bool {
    // Сходимость если reward стабилен и положителен
    const reward_stable = @abs(state.cumulative_reward) < @as(f64, threshold);
    const enough_iterations = state.iteration > 10;

    state.converged = reward_stable and enough_iterations and state.cumulative_reward > 0;
    return state.converged;
}

// Кощеева игла: решение о продолжении цикла
pub fn koscheiNeedle(state: *const LoopState) bool {
    // Продолжаем если:
    // 1. Не сошлись
    // 2. Reward положительный или итераций мало
    if (state.converged) return false;
    if (state.iteration < 5) return true;
    return state.cumulative_reward > -0.5;
}

// PHI-оптимальный размер шага
pub fn phiStepSize(current_error: f32, learning_rate: f32) f32 {
    return current_error * learning_rate * @as(f32, @floatCast(PHI_INV));
}

// Вычисление momentum
pub fn updateMomentum(state: *LoopState, gradient: f32, beta: f32) f32 {
    state.momentum = beta * state.momentum + (1.0 - beta) * gradient;
    return state.momentum;
}

// Оценка прогресса
pub fn progressScore(state: *const LoopState) f32 {
    if (state.iteration == 0) return 0;

    // Нормализованный reward
    const normalized_reward: f32 = @floatCast(@max(-1.0, @min(1.0, state.cumulative_reward)));

    // Бонус за итерации (опыт)
    const experience_bonus = @min(0.3, @as(f32, @floatFromInt(state.iteration)) * 0.01);

    return (normalized_reward + 1.0) / 2.0 + experience_bonus;
}

// Бессмертие: сохранение состояния для следующего цикла
pub fn immortalize(state: *const LoopState) u64 {
    // Хеш состояния для восстановления
    const iter_part = @as(u64, state.iteration);
    const reward_part = @as(u64, @bitCast(@as(i64, @intFromFloat(state.cumulative_reward * 1000))));
    return iter_part ^ (reward_part << 32) ^ PHOENIX;
}

// Tests
test "process positive feedback" {
    var state = LoopState{};
    const signal = FeedbackSignal{ .feedback_type = .positive, .magnitude = 1.0 };
    processFeedback(&state, signal);
    try testing.expect(state.cumulative_reward > 0);
    try testing.expectEqual(@as(usize, 1), state.iteration);
}

test "process negative feedback" {
    var state = LoopState{ .learning_rate = 0.1 };
    const signal = FeedbackSignal{ .feedback_type = .negative, .magnitude = 1.0 };
    processFeedback(&state, signal);
    try testing.expect(state.learning_rate < 0.1);
}

test "check convergence" {
    var state = LoopState{ .iteration = 15, .cumulative_reward = 0.01 };
    const converged = checkConvergence(&state, 0.1);
    try testing.expect(converged);
}

test "koschei needle continue" {
    const state = LoopState{ .iteration = 3, .converged = false };
    try testing.expect(koscheiNeedle(&state));
}

test "koschei needle stop" {
    const state = LoopState{ .converged = true };
    try testing.expect(!koscheiNeedle(&state));
}

test "progress score" {
    const state = LoopState{ .iteration = 10, .cumulative_reward = 0.5 };
    const score = progressScore(&state);
    try testing.expect(score > 0.5);
}
