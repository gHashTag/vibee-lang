// ═══════════════════════════════════════════════════════════════════════════════
// qml_benchmark v1.0.0 - Бенчмарки производительности
// Сравнение с предыдущими версиями
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;
const time = std.time;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const BenchmarkResult = struct {
    name: [64]u8 = [_]u8{0} ** 64,
    latency_ms: f64 = 0,
    throughput: f64 = 0, // samples/sec
    memory_mb: f64 = 0,
    accuracy: f64 = 0,
    iterations: usize = 0,

    pub fn setName(self: *BenchmarkResult, name_str: []const u8) void {
        const len = @min(name_str.len, 63);
        for (0..len) |i| {
            self.name[i] = name_str[i];
        }
    }
};

pub const ComparisonResult = struct {
    baseline: BenchmarkResult,
    current: BenchmarkResult,

    pub fn speedup(self: *const ComparisonResult) f64 {
        if (self.current.latency_ms == 0) return 0;
        return self.baseline.latency_ms / self.current.latency_ms;
    }

    pub fn memoryReduction(self: *const ComparisonResult) f64 {
        if (self.current.memory_mb == 0) return 0;
        return 1.0 - (self.current.memory_mb / self.baseline.memory_mb);
    }

    pub fn accuracyDelta(self: *const ComparisonResult) f64 {
        return self.current.accuracy - self.baseline.accuracy;
    }
};

pub const BenchmarkConfig = struct {
    warmup_iterations: usize = 10,
    benchmark_iterations: usize = 100,
    batch_sizes: [4]usize = [_]usize{ 1, 8, 32, 64 },
    sequence_lengths: [4]usize = [_]usize{ 32, 64, 128, 256 },
};

// Timer utility
pub const Timer = struct {
    start_time: i128 = 0,

    pub fn start(self: *Timer) void {
        self.start_time = time.nanoTimestamp();
    }

    pub fn elapsedMs(self: *const Timer) f64 {
        const end = time.nanoTimestamp();
        return @as(f64, @floatFromInt(end - self.start_time)) / 1_000_000.0;
    }
};

// Benchmark a function
pub fn benchmarkFn(
    comptime func: anytype,
    args: anytype,
    config: BenchmarkConfig,
) BenchmarkResult {
    var result = BenchmarkResult{};
    var timer = Timer{};

    // Warmup
    for (0..config.warmup_iterations) |_| {
        _ = @call(.auto, func, args);
    }

    // Benchmark
    timer.start();
    for (0..config.benchmark_iterations) |_| {
        _ = @call(.auto, func, args);
    }
    const total_ms = timer.elapsedMs();

    result.latency_ms = total_ms / @as(f64, @floatFromInt(config.benchmark_iterations));
    result.throughput = 1000.0 / result.latency_ms;
    result.iterations = config.benchmark_iterations;

    return result;
}

// Statistical analysis
pub fn computeStats(values: []const f64) struct { mean: f64, std: f64, min: f64, max: f64 } {
    if (values.len == 0) return .{ .mean = 0, .std = 0, .min = 0, .max = 0 };

    var sum: f64 = 0;
    var min_val: f64 = values[0];
    var max_val: f64 = values[0];

    for (values) |v| {
        sum += v;
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
    }

    const mean = sum / @as(f64, @floatFromInt(values.len));

    var variance: f64 = 0;
    for (values) |v| {
        const diff = v - mean;
        variance += diff * diff;
    }
    variance /= @as(f64, @floatFromInt(values.len));

    return .{
        .mean = mean,
        .std = @sqrt(variance),
        .min = min_val,
        .max = max_val,
    };
}

// PHI-weighted performance score
pub fn phiPerformanceScore(latency_ms: f64, accuracy: f64, memory_mb: f64) f64 {
    if (latency_ms == 0 or memory_mb == 0) return 0;
    const acc_factor = @exp(@log(accuracy) * PHI);
    const lat_factor = latency_ms;
    const mem_factor = @exp(@log(memory_mb) * PHI_INV);
    return acc_factor / (lat_factor * mem_factor) * @as(f64, PHOENIX);
}

// Compare two benchmark results
pub fn compareBenchmarks(baseline: BenchmarkResult, current: BenchmarkResult) ComparisonResult {
    return ComparisonResult{
        .baseline = baseline,
        .current = current,
    };
}

// Format benchmark report
pub fn formatSpeedup(speedup_val: f64) [16]u8 {
    var buf: [16]u8 = [_]u8{0} ** 16;
    if (speedup_val >= 1.0) {
        _ = std.fmt.bufPrint(&buf, "{d:.2}x faster", .{speedup_val}) catch {};
    } else {
        _ = std.fmt.bufPrint(&buf, "{d:.2}x slower", .{1.0 / speedup_val}) catch {};
    }
    return buf;
}

// Matryoshka benchmark - compare different embedding dimensions
pub fn matryoshkaBenchmark(
    full_latency_ms: f64,
    full_accuracy: f64,
    dims: []const usize,
    full_dim: usize,
) [8]BenchmarkResult {
    var results: [8]BenchmarkResult = undefined;

    for (dims, 0..) |dim, i| {
        if (i >= 8) break;
        results[i] = BenchmarkResult{};

        // Latency scales roughly linearly with dimension
        const dim_ratio = @as(f64, @floatFromInt(dim)) / @as(f64, @floatFromInt(full_dim));
        results[i].latency_ms = full_latency_ms * dim_ratio;

        // Accuracy degrades slightly with smaller dimensions
        const accuracy_penalty = (1.0 - dim_ratio) * 0.05; // Max 5% penalty
        results[i].accuracy = full_accuracy - accuracy_penalty;

        results[i].throughput = 1000.0 / results[i].latency_ms;
    }

    return results;
}

// Tests
test "timer" {
    var timer = Timer{};
    timer.start();
    std.time.sleep(1_000_000); // 1ms
    const elapsed = timer.elapsedMs();
    try testing.expect(elapsed >= 0.5);
    try testing.expect(elapsed < 10.0);
}

test "compute stats" {
    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const stats = computeStats(&values);
    try testing.expectApproxEqAbs(@as(f64, 3.0), stats.mean, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 1.0), stats.min, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 5.0), stats.max, 0.001);
}

test "phi performance score" {
    const score = phiPerformanceScore(10.0, 0.95, 100.0);
    try testing.expect(score > 0);
}

test "comparison result" {
    const baseline = BenchmarkResult{ .latency_ms = 100.0, .memory_mb = 1000.0, .accuracy = 0.90 };
    const current = BenchmarkResult{ .latency_ms = 50.0, .memory_mb = 500.0, .accuracy = 0.92 };
    const comparison = compareBenchmarks(baseline, current);

    try testing.expectApproxEqAbs(@as(f64, 2.0), comparison.speedup(), 0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.5), comparison.memoryReduction(), 0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.02), comparison.accuracyDelta(), 0.001);
}

test "matryoshka benchmark" {
    const dims = [_]usize{ 384, 256, 128, 64, 32 };
    const results = matryoshkaBenchmark(10.0, 0.95, &dims, 384);

    // Smaller dims should be faster
    try testing.expect(results[1].latency_ms < results[0].latency_ms);
    try testing.expect(results[2].latency_ms < results[1].latency_ms);

    // Accuracy should decrease slightly
    try testing.expect(results[1].accuracy <= results[0].accuracy);
}

test "format speedup" {
    const buf = formatSpeedup(2.5);
    try testing.expect(buf[0] != 0);
}
