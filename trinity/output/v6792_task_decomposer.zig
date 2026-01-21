// v6792_task_decomposer.zig - Декомпозиция задач
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const TaskPriority = enum(u8) {
    critical = 0,
    high = 1,
    medium = 2,
    low = 3,
};

pub const Task = struct {
    id: u32,
    priority: TaskPriority,
    complexity: f32,
    dependencies: u32 = 0, // Bitmask of dependent task IDs
    completed: bool = false,
};

// Оценка сложности задачи
pub fn estimateComplexity(description_len: usize, has_dependencies: bool) f32 {
    var complexity: f32 = @as(f32, @floatFromInt(description_len)) / 100.0;
    if (has_dependencies) {
        complexity *= @as(f32, @floatCast(PHI)); // Зависимости увеличивают сложность
    }
    return @min(1.0, complexity);
}

// PHI-декомпозиция: разбить задачу на подзадачи
pub fn phiDecompose(total_complexity: f32) struct { main: f32, sub: f32 } {
    // Главная часть = PHI_INV от общей
    const main = total_complexity * @as(f32, @floatCast(PHI_INV));
    const sub = total_complexity - main;
    return .{ .main = main, .sub = sub };
}

// Оптимальное количество подзадач
pub fn optimalSubtasks(complexity: f32) usize {
    // Fibonacci-подобное разбиение
    const base = @as(usize, @intFromFloat(complexity * 10.0));
    return @max(1, @min(10, base));
}

// Проверка готовности задачи (все зависимости выполнены)
pub fn isReady(task: *const Task, completed_mask: u32) bool {
    return (task.dependencies & completed_mask) == task.dependencies;
}

// Приоритизация задач
pub fn priorityScore(task: *const Task) f32 {
    const priority_weight: f32 = switch (task.priority) {
        .critical => 1.0,
        .high => 0.8,
        .medium => 0.5,
        .low => 0.2,
    };
    // Высокая сложность = ниже приоритет (делаем простое сначала)
    return priority_weight * (1.0 - task.complexity * 0.5);
}

// Выбор следующей задачи
pub fn selectNextTask(tasks: []Task, completed_mask: u32) ?*Task {
    var best: ?*Task = null;
    var best_score: f32 = -1;

    for (tasks) |*task| {
        if (!task.completed and isReady(task, completed_mask)) {
            const score = priorityScore(task);
            if (score > best_score) {
                best_score = score;
                best = task;
            }
        }
    }

    return best;
}

// Оценка времени выполнения (в условных единицах)
pub fn estimateTime(complexity: f32, experience_factor: f32) f32 {
    // Время = сложность / опыт, с PHI-коррекцией
    const base_time = complexity / @max(0.1, experience_factor);
    return base_time * @as(f32, @floatCast(PHI_INV));
}

// Tests
test "estimate complexity" {
    const c1 = estimateComplexity(50, false);
    const c2 = estimateComplexity(50, true);
    try testing.expect(c2 > c1);
}

test "phi decompose" {
    const result = phiDecompose(1.0);
    try testing.expect(@abs(result.main - 0.618) < 0.01);
    try testing.expect(@abs(result.sub - 0.382) < 0.01);
}

test "optimal subtasks" {
    try testing.expectEqual(@as(usize, 5), optimalSubtasks(0.5));
    try testing.expectEqual(@as(usize, 10), optimalSubtasks(1.0));
}

test "is ready" {
    const task = Task{ .id = 1, .priority = .high, .complexity = 0.5, .dependencies = 0b0011 };
    try testing.expect(!isReady(&task, 0b0001));
    try testing.expect(isReady(&task, 0b0011));
}

test "priority score" {
    const critical = Task{ .id = 1, .priority = .critical, .complexity = 0.0 };
    const low = Task{ .id = 2, .priority = .low, .complexity = 0.0 };
    try testing.expect(priorityScore(&critical) > priorityScore(&low));
}

test "estimate time" {
    const time = estimateTime(1.0, 1.0);
    try testing.expect(@abs(time - 0.618) < 0.01);
}
