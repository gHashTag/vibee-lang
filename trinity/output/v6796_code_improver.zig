// v6796_code_improver.zig - Автоулучшение кода
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const ImprovementType = enum {
    performance,
    readability,
    memory,
    correctness,
    phi_alignment,
};

pub const CodeMetrics = struct {
    lines: usize = 0,
    functions: usize = 0,
    complexity: f32 = 0,
    test_coverage: f32 = 0,
    phi_score: f32 = 0,
};

// Оценка PHI-выравнивания кода
pub fn phiAlignmentScore(metrics: *const CodeMetrics) f32 {
    // Идеальное соотношение: functions/lines ≈ PHI_INV
    if (metrics.lines == 0) return 0;

    const ratio = @as(f32, @floatFromInt(metrics.functions)) / @as(f32, @floatFromInt(metrics.lines)) * 10.0;
    const ideal: f32 = @floatCast(PHI_INV);
    const diff = @abs(ratio - ideal);

    return @max(0, 1.0 - diff);
}

// Предложение улучшения
pub fn suggestImprovement(metrics: *const CodeMetrics) ImprovementType {
    if (metrics.test_coverage < 0.8) return .correctness;
    if (metrics.phi_score < 0.5) return .phi_alignment;
    if (metrics.complexity > 0.7) return .readability;
    if (metrics.lines > 200) return .memory;
    return .performance;
}

// Оценка качества кода
pub fn codeQualityScore(metrics: *const CodeMetrics) f32 {
    const coverage_weight: f32 = @floatCast(PHI_INV);
    const phi_weight: f32 = @floatCast(1.0 - PHI_INV);

    return metrics.test_coverage * coverage_weight +
        metrics.phi_score * phi_weight;
}

// Оптимальное количество функций для N строк
pub fn optimalFunctions(lines: usize) usize {
    // PHI-based: ~6 строк на функцию
    const phi_lines_per_func: f64 = PHI * PHI * PHI; // ~4.236
    return @max(1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(lines)) / phi_lines_per_func)));
}

// Оценка сложности (цикломатическая, упрощённо)
pub fn estimateComplexity(branches: usize, loops: usize, functions: usize) f32 {
    if (functions == 0) return 1.0;
    const total = branches + loops + functions;
    const per_func = @as(f32, @floatFromInt(total)) / @as(f32, @floatFromInt(functions));
    return @min(1.0, per_func / 10.0);
}

// Приоритет улучшения
pub fn improvementPriority(improvement_type: ImprovementType, metrics: *const CodeMetrics) f32 {
    return switch (improvement_type) {
        .correctness => 1.0 - metrics.test_coverage,
        .phi_alignment => 1.0 - metrics.phi_score,
        .readability => metrics.complexity,
        .memory => @min(1.0, @as(f32, @floatFromInt(metrics.lines)) / 500.0),
        .performance => @as(f32, @floatCast(PHI_INV)), // Базовый приоритет
    };
}

// Ожидаемое улучшение после оптимизации
pub fn expectedImprovement(current_score: f32, effort: f32) f32 {
    // Закон убывающей отдачи с PHI
    const potential = 1.0 - current_score;
    const efficiency = @as(f32, @floatCast(PHI_INV)) * effort;
    return current_score + potential * efficiency;
}

// Tests
test "phi alignment score" {
    const metrics = CodeMetrics{ .lines = 100, .functions = 6 };
    const score = phiAlignmentScore(&metrics);
    try testing.expect(score > 0);
}

test "suggest improvement low coverage" {
    const metrics = CodeMetrics{ .test_coverage = 0.5 };
    const suggestion = suggestImprovement(&metrics);
    try testing.expectEqual(ImprovementType.correctness, suggestion);
}

test "code quality score" {
    const metrics = CodeMetrics{ .test_coverage = 0.9, .phi_score = 0.8 };
    const score = codeQualityScore(&metrics);
    try testing.expect(score > 0.8);
}

test "optimal functions" {
    const funcs = optimalFunctions(100);
    try testing.expect(funcs > 15);
    try testing.expect(funcs < 30);
}

test "estimate complexity" {
    const complexity = estimateComplexity(5, 3, 2);
    try testing.expect(complexity > 0);
    try testing.expect(complexity <= 1.0);
}

test "expected improvement" {
    const improved = expectedImprovement(0.5, 1.0);
    try testing.expect(improved > 0.5);
    try testing.expect(improved < 1.0);
}
