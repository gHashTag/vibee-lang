// ═══════════════════════════════════════════════════════════════════════════════
// REALTIME METRICS - Метрики эволюции VM в реальном времени
// ═══════════════════════════════════════════════════════════════════════════════
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
// ЗОЛОТАЯ ИДЕНТИЧНОСТЬ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PerformanceMetrics = struct {
    // Execution metrics
    instructions_executed: u64,
    bytecode_bytes_executed: u64,
    
    // Timing
    total_execution_ns: u64,
    jit_compilation_ns: u64,
    gc_pause_ns: u64,
    
    // Memory
    heap_allocated: u64,
    heap_used: u64,
    stack_peak: u64,
    
    // JIT metrics
    traces_recorded: u32,
    traces_compiled: u32,
    traces_aborted: u32,
    side_exits: u64,
    
    // Cache metrics
    ic_hits: u64,
    ic_misses: u64,
    
    pub fn init() PerformanceMetrics {
        return .{
            .instructions_executed = 0,
            .bytecode_bytes_executed = 0,
            .total_execution_ns = 0,
            .jit_compilation_ns = 0,
            .gc_pause_ns = 0,
            .heap_allocated = 0,
            .heap_used = 0,
            .stack_peak = 0,
            .traces_recorded = 0,
            .traces_compiled = 0,
            .traces_aborted = 0,
            .side_exits = 0,
            .ic_hits = 0,
            .ic_misses = 0,
        };
    }
    
    pub fn getIPS(self: *const PerformanceMetrics) f64 {
        if (self.total_execution_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.instructions_executed)) / 
               (@as(f64, @floatFromInt(self.total_execution_ns)) / 1_000_000_000.0);
    }
    
    pub fn getICHitRate(self: *const PerformanceMetrics) f64 {
        const total = self.ic_hits + self.ic_misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.ic_hits)) / @as(f64, @floatFromInt(total));
    }
    
    pub fn getTraceSuccessRate(self: *const PerformanceMetrics) f64 {
        const total = self.traces_compiled + self.traces_aborted;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.traces_compiled)) / @as(f64, @floatFromInt(total));
    }
    
    pub fn getGCOverhead(self: *const PerformanceMetrics) f64 {
        if (self.total_execution_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.gc_pause_ns)) / @as(f64, @floatFromInt(self.total_execution_ns));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLUTION METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvolutionMetrics = struct {
    // Generation info
    current_generation: u32,
    total_generations: u64,
    
    // Fitness
    best_fitness: f64,
    avg_fitness: f64,
    worst_fitness: f64,
    fitness_variance: f64,
    
    // Population
    population_size: u32,
    elite_count: u32,
    
    // Improvements
    improvements_this_gen: u32,
    total_improvements: u64,
    generations_since_improvement: u32,
    
    // Diversity
    genetic_diversity: f64,
    
    pub fn init() EvolutionMetrics {
        return .{
            .current_generation = 0,
            .total_generations = 0,
            .best_fitness = 0,
            .avg_fitness = 0,
            .worst_fitness = 0,
            .fitness_variance = 0,
            .population_size = 0,
            .elite_count = 0,
            .improvements_this_gen = 0,
            .total_improvements = 0,
            .generations_since_improvement = 0,
            .genetic_diversity = 0,
        };
    }
    
    pub fn getImprovementRate(self: *const EvolutionMetrics) f64 {
        if (self.total_generations == 0) return 0;
        return @as(f64, @floatFromInt(self.total_improvements)) / @as(f64, @floatFromInt(self.total_generations));
    }
    
    pub fn isStagnant(self: *const EvolutionMetrics) bool {
        return self.generations_since_improvement > 50;
    }
    
    pub fn needsDiversification(self: *const EvolutionMetrics) bool {
        return self.genetic_diversity < 0.1 or self.isStagnant();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkMetrics = struct {
    name: []const u8,
    
    // Timing
    min_ms: f64,
    max_ms: f64,
    avg_ms: f64,
    median_ms: f64,
    stddev_ms: f64,
    
    // Iterations
    iterations: u32,
    warmup_iterations: u32,
    
    // Comparison
    vs_baseline: f64,  // Speedup vs baseline
    vs_python: f64,
    vs_luajit: f64,
    
    pub fn init(name: []const u8) BenchmarkMetrics {
        return .{
            .name = name,
            .min_ms = 0,
            .max_ms = 0,
            .avg_ms = 0,
            .median_ms = 0,
            .stddev_ms = 0,
            .iterations = 0,
            .warmup_iterations = 0,
            .vs_baseline = 1.0,
            .vs_python = 1.0,
            .vs_luajit = 0.01,
        };
    }
    
    pub fn recordRun(self: *BenchmarkMetrics, time_ms: f64) void {
        self.iterations += 1;
        
        if (self.iterations == 1) {
            self.min_ms = time_ms;
            self.max_ms = time_ms;
            self.avg_ms = time_ms;
        } else {
            self.min_ms = @min(self.min_ms, time_ms);
            self.max_ms = @max(self.max_ms, time_ms);
            
            // Running average
            const n = @as(f64, @floatFromInt(self.iterations));
            self.avg_ms = self.avg_ms + (time_ms - self.avg_ms) / n;
        }
    }
    
    pub fn calculateComparisons(self: *BenchmarkMetrics, python_ms: f64, luajit_ms: f64) void {
        if (self.avg_ms > 0) {
            self.vs_python = python_ms / self.avg_ms;
            self.vs_luajit = luajit_ms / self.avg_ms;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS COLLECTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const MetricsCollector = struct {
    allocator: Allocator,
    
    // Current metrics
    performance: PerformanceMetrics,
    evolution: EvolutionMetrics,
    
    // Benchmark history
    benchmarks: std.StringHashMap(BenchmarkMetrics),
    
    // Time series (last 100 samples)
    fitness_history: [100]f64,
    ips_history: [100]f64,
    history_index: usize,
    
    // Timestamps
    start_time: i64,
    last_update: i64,
    
    pub fn init(allocator: Allocator) MetricsCollector {
        return .{
            .allocator = allocator,
            .performance = PerformanceMetrics.init(),
            .evolution = EvolutionMetrics.init(),
            .benchmarks = std.StringHashMap(BenchmarkMetrics).init(allocator),
            .fitness_history = [_]f64{0} ** 100,
            .ips_history = [_]f64{0} ** 100,
            .history_index = 0,
            .start_time = std.time.timestamp(),
            .last_update = std.time.timestamp(),
        };
    }
    
    pub fn deinit(self: *MetricsCollector) void {
        self.benchmarks.deinit();
    }
    
    pub fn recordSample(self: *MetricsCollector) void {
        self.fitness_history[self.history_index] = self.evolution.best_fitness;
        self.ips_history[self.history_index] = self.performance.getIPS();
        self.history_index = (self.history_index + 1) % 100;
        self.last_update = std.time.timestamp();
    }
    
    pub fn recordBenchmark(self: *MetricsCollector, name: []const u8, time_ms: f64) !void {
        const result = try self.benchmarks.getOrPut(name);
        if (!result.found_existing) {
            result.value_ptr.* = BenchmarkMetrics.init(name);
        }
        result.value_ptr.recordRun(time_ms);
    }
    
    pub fn getReport(self: *const MetricsCollector) MetricsReport {
        const runtime = std.time.timestamp() - self.start_time;
        
        return .{
            .runtime_seconds = @intCast(runtime),
            .performance = self.performance,
            .evolution = self.evolution,
            .ips = self.performance.getIPS(),
            .ic_hit_rate = self.performance.getICHitRate(),
            .gc_overhead = self.performance.getGCOverhead(),
            .improvement_rate = self.evolution.getImprovementRate(),
            .is_stagnant = self.evolution.isStagnant(),
        };
    }
    
    pub fn getFitnessTrend(self: *const MetricsCollector) f64 {
        // Calculate trend from last 10 samples
        var sum_old: f64 = 0;
        var sum_new: f64 = 0;
        
        for (0..5) |i| {
            const old_idx = (self.history_index + 100 - 10 + i) % 100;
            const new_idx = (self.history_index + 100 - 5 + i) % 100;
            sum_old += self.fitness_history[old_idx];
            sum_new += self.fitness_history[new_idx];
        }
        
        if (sum_old == 0) return 0;
        return (sum_new - sum_old) / sum_old;
    }
};

pub const MetricsReport = struct {
    runtime_seconds: u64,
    performance: PerformanceMetrics,
    evolution: EvolutionMetrics,
    ips: f64,
    ic_hit_rate: f64,
    gc_overhead: f64,
    improvement_rate: f64,
    is_stagnant: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD OUTPUT
// ═══════════════════════════════════════════════════════════════════════════════

pub const Dashboard = struct {
    pub fn formatReport(report: MetricsReport, buf: []u8) []u8 {
        const result = std.fmt.bufPrint(buf,
            \\═══════════════════════════════════════════════════════════════
            \\                    VM TRINITY METRICS
            \\═══════════════════════════════════════════════════════════════
            \\Runtime: {d} seconds
            \\
            \\PERFORMANCE:
            \\  Instructions/sec: {d:.2e}
            \\  IC Hit Rate: {d:.1}%
            \\  GC Overhead: {d:.1}%
            \\
            \\EVOLUTION:
            \\  Generation: {d}
            \\  Best Fitness: {d:.4}
            \\  Improvement Rate: {d:.2}%
            \\  Status: {s}
            \\═══════════════════════════════════════════════════════════════
        , .{
            report.runtime_seconds,
            report.ips,
            report.ic_hit_rate * 100,
            report.gc_overhead * 100,
            report.evolution.current_generation,
            report.evolution.best_fitness,
            report.improvement_rate * 100,
            if (report.is_stagnant) "STAGNANT" else "EVOLVING",
        }) catch return buf[0..0];
        
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "performance metrics" {
    var metrics = PerformanceMetrics.init();
    
    metrics.instructions_executed = 1_000_000;
    metrics.total_execution_ns = 1_000_000_000;  // 1 second
    
    const ips = metrics.getIPS();
    try std.testing.expect(ips > 999_000 and ips < 1_001_000);
}

test "evolution metrics" {
    var metrics = EvolutionMetrics.init();
    
    metrics.total_generations = 100;
    metrics.total_improvements = 20;
    
    const rate = metrics.getImprovementRate();
    try std.testing.expect(rate > 0.19 and rate < 0.21);
}

test "benchmark metrics" {
    var bench = BenchmarkMetrics.init("fib30");
    
    bench.recordRun(100.0);
    bench.recordRun(90.0);
    bench.recordRun(110.0);
    
    try std.testing.expectEqual(@as(u32, 3), bench.iterations);
    try std.testing.expect(bench.min_ms == 90.0);
    try std.testing.expect(bench.max_ms == 110.0);
}

test "metrics collector" {
    var collector = MetricsCollector.init(std.testing.allocator);
    defer collector.deinit();
    
    collector.performance.instructions_executed = 1000;
    collector.evolution.current_generation = 5;
    collector.evolution.best_fitness = 0.85;
    
    collector.recordSample();
    
    const report = collector.getReport();
    try std.testing.expectEqual(@as(u32, 5), report.evolution.current_generation);
}
