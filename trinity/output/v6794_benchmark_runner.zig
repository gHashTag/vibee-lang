// v6794_benchmark_runner.zig - Автобенчмарки
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const BenchmarkResult = struct {
    name: [64]u8 = [_]u8{0} ** 64,
    iterations: usize = 0,
    total_ns: u64 = 0,
    min_ns: u64 = std.math.maxInt(u64),
    max_ns: u64 = 0,
};

// Вычисление среднего времени
pub fn averageTime(result: *const BenchmarkResult) f64 {
    if (result.iterations == 0) return 0;
    return @as(f64, @floatFromInt(result.total_ns)) / @as(f64, @floatFromInt(result.iterations));
}

// Вычисление операций в секунду
pub fn opsPerSecond(result: *const BenchmarkResult) f64 {
    const avg = averageTime(result);
    if (avg == 0) return 0;
    return 1e9 / avg;
}

// Сравнение двух результатов
pub fn compareResults(baseline: *const BenchmarkResult, current: *const BenchmarkResult) f32 {
    const baseline_avg = averageTime(baseline);
    const current_avg = averageTime(current);

    if (baseline_avg == 0) return 0;
    return @floatCast((baseline_avg - current_avg) / baseline_avg);
}

// PHI-оптимальное количество итераций
pub fn phiIterations(base: usize, warmup: bool) usize {
    const multiplier: f64 = if (warmup) PHI_INV else PHI;
    return @intFromFloat(@as(f64, @floatFromInt(base)) * multiplier);
}

// Статистическая значимость
pub fn isSignificant(improvement: f32, threshold: f32) bool {
    return @abs(improvement) > threshold;
}

// Обновление результата
pub fn updateResult(result: *BenchmarkResult, elapsed_ns: u64) void {
    result.iterations += 1;
    result.total_ns += elapsed_ns;
    result.min_ns = @min(result.min_ns, elapsed_ns);
    result.max_ns = @max(result.max_ns, elapsed_ns);
}

// Вычисление стандартного отклонения (упрощённо)
pub fn stdDeviation(result: *const BenchmarkResult) f64 {
    if (result.iterations < 2) return 0;
    const range = @as(f64, @floatFromInt(result.max_ns - result.min_ns));
    // Приближение: std ≈ range / 4
    return range / 4.0;
}

// Коэффициент вариации
pub fn coefficientOfVariation(result: *const BenchmarkResult) f32 {
    const avg = averageTime(result);
    const std_dev = stdDeviation(result);
    if (avg == 0) return 0;
    return @floatCast(std_dev / avg);
}

// PHI-порог для значимости
pub fn phiSignificanceThreshold() f32 {
    return @floatCast(1.0 - PHI_INV); // ~0.382
}

// Tests
test "average time" {
    var result = BenchmarkResult{ .iterations = 10, .total_ns = 1000 };
    try testing.expectEqual(@as(f64, 100.0), averageTime(&result));
}

test "ops per second" {
    var result = BenchmarkResult{ .iterations = 1, .total_ns = 1000000 }; // 1ms
    const ops = opsPerSecond(&result);
    try testing.expect(ops > 900);
    try testing.expect(ops < 1100);
}

test "compare results" {
    const baseline = BenchmarkResult{ .iterations = 1, .total_ns = 1000 };
    const current = BenchmarkResult{ .iterations = 1, .total_ns = 800 };
    const improvement = compareResults(&baseline, &current);
    try testing.expect(improvement > 0.1); // 20% improvement
}

test "phi iterations" {
    const warmup = phiIterations(100, true);
    const main = phiIterations(100, false);
    try testing.expect(warmup < main);
}

test "update result" {
    var result = BenchmarkResult{};
    updateResult(&result, 100);
    updateResult(&result, 200);
    try testing.expectEqual(@as(usize, 2), result.iterations);
    try testing.expectEqual(@as(u64, 100), result.min_ns);
}

test "phi significance threshold" {
    const threshold = phiSignificanceThreshold();
    try testing.expect(@abs(threshold - 0.382) < 0.01);
}
