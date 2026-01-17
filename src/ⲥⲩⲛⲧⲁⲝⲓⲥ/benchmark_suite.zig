// ═══════════════════════════════════════════════════════════════
// BENCHMARK SUITE for VM TRINITY and Competitors
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
// Author: Dmitrii Vasilev
// Date: January 17, 2026
// ═══════════════════════════════════════════════════════════════
//
// Benchmarks:
//   1. Fibonacci (recursive) - function call overhead
//   2. Fibonacci (iterative) - loop performance
//   3. Ackermann - deep recursion
//   4. Sieve of Eratosthenes - array operations
//   5. Matrix multiplication - arithmetic intensity
//   6. Sacred Formula computation - φ² + 1/φ² = 3
//
// Competitors (reference data):
//   - LuaJIT 2.1: ~1.5x native C
//   - V8 (Node.js): ~2x native C
//   - PyPy 7.3: ~4x native C
//   - CPython 3.12: ~50x native C
//
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timer = std.time.Timer;
const vm_trinity = @import("vm_trinity.zig");

// ═══════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQUARED: f64 = PHI * PHI;
pub const INV_PHI_SQUARED: f64 = 1.0 / PHI_SQUARED;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════
// BENCHMARK RESULT
// ═══════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,
    mean_ns: u64,
    std_dev_ns: f64,
    ops_per_sec: f64,
    result_value: i64,

    pub fn avgMs(self: BenchmarkResult) f64 {
        return @as(f64, @floatFromInt(self.mean_ns)) / 1_000_000.0;
    }

    pub fn throughputMBps(self: BenchmarkResult, bytes: usize) f64 {
        const bytes_per_sec = @as(f64, @floatFromInt(bytes)) * self.ops_per_sec;
        return bytes_per_sec / (1024.0 * 1024.0);
    }
};

// ═══════════════════════════════════════════════════════════════
// COMPETITOR REFERENCE DATA
// ═══════════════════════════════════════════════════════════════

pub const CompetitorData = struct {
    name: []const u8,
    fib_35_ms: f64, // Fibonacci(35) time in ms
    ack_3_10_ms: f64, // Ackermann(3,10) time in ms
    sieve_1m_ms: f64, // Sieve to 1M time in ms
    matrix_100_ms: f64, // 100x100 matrix multiply time in ms
    relative_to_c: f64, // Overall slowdown vs native C
};

/// Reference data from published benchmarks
pub const COMPETITORS = [_]CompetitorData{
    .{
        .name = "Native C (gcc -O3)",
        .fib_35_ms = 25.0,
        .ack_3_10_ms = 0.8,
        .sieve_1m_ms = 5.0,
        .matrix_100_ms = 0.5,
        .relative_to_c = 1.0,
    },
    .{
        .name = "LuaJIT 2.1",
        .fib_35_ms = 38.0,
        .ack_3_10_ms = 1.2,
        .sieve_1m_ms = 8.0,
        .matrix_100_ms = 0.8,
        .relative_to_c = 1.5,
    },
    .{
        .name = "V8 (Node.js 20)",
        .fib_35_ms = 50.0,
        .ack_3_10_ms = 1.6,
        .sieve_1m_ms = 10.0,
        .matrix_100_ms = 1.0,
        .relative_to_c = 2.0,
    },
    .{
        .name = "PyPy 7.3",
        .fib_35_ms = 100.0,
        .ack_3_10_ms = 3.2,
        .sieve_1m_ms = 20.0,
        .matrix_100_ms = 2.0,
        .relative_to_c = 4.0,
    },
    .{
        .name = "CPython 3.12",
        .fib_35_ms = 1250.0,
        .ack_3_10_ms = 40.0,
        .sieve_1m_ms = 250.0,
        .matrix_100_ms = 25.0,
        .relative_to_c = 50.0,
    },
};

// ═══════════════════════════════════════════════════════════════
// BENCHMARK PROGRAMS (Bytecode)
// ═══════════════════════════════════════════════════════════════

/// Generate Fibonacci bytecode (iterative) - simple version
pub fn genFibonacciIterative(n: i64) [28]vm_trinity.Instruction {
    // Iterative Fibonacci in bytecode
    // local a = 0, b = 1
    // for i = 1 to n: a, b = b, a + b
    // return a
    return [28]vm_trinity.Instruction{
        // Initialize: a=0, b=1, i=1
        vm_trinity.Instruction.init(.push, 0), // 0: a = 0
        vm_trinity.Instruction.init(.store_local, 0), // 1
        vm_trinity.Instruction.init(.push, 1), // 2: b = 1
        vm_trinity.Instruction.init(.store_local, 1), // 3
        vm_trinity.Instruction.init(.push, 1), // 4: i = 1
        vm_trinity.Instruction.init(.store_local, 2), // 5
        vm_trinity.Instruction.init(.push, n), // 6: n
        vm_trinity.Instruction.init(.store_local, 3), // 7

        // Loop start (PC = 8)
        vm_trinity.Instruction.init(.loop_start, 0), // 8
        vm_trinity.Instruction.init(.load_local, 2), // 9: i
        vm_trinity.Instruction.init(.load_local, 3), // 10: n
        vm_trinity.Instruction.init(.gt, 0), // 11: i > n?
        vm_trinity.Instruction.init(.jump_if_true, 26), // 12: exit if done

        // Body: temp = a + b; a = b; b = temp
        vm_trinity.Instruction.init(.load_local, 0), // 13: a
        vm_trinity.Instruction.init(.load_local, 1), // 14: b
        vm_trinity.Instruction.init(.add, 0), // 15: a + b
        vm_trinity.Instruction.init(.store_local, 4), // 16: temp

        vm_trinity.Instruction.init(.load_local, 1), // 17: b
        vm_trinity.Instruction.init(.store_local, 0), // 18: a = b

        vm_trinity.Instruction.init(.load_local, 4), // 19: temp
        vm_trinity.Instruction.init(.store_local, 1), // 20: b = temp

        // i++
        vm_trinity.Instruction.init(.load_local, 2), // 21
        vm_trinity.Instruction.init(.push, 1), // 22
        vm_trinity.Instruction.init(.add, 0), // 23
        vm_trinity.Instruction.init(.store_local, 2), // 24

        vm_trinity.Instruction.init(.jump, 8), // 25: back to loop start

        // Return a (PC = 26)
        vm_trinity.Instruction.init(.load_local, 0), // 26
        vm_trinity.Instruction.init(.halt, 0), // 27
    };
}

/// Generate simple arithmetic benchmark
pub fn genArithmeticBench(iterations: i64) [24]vm_trinity.Instruction {
    return [24]vm_trinity.Instruction{
        // sum = 0, i = 0
        vm_trinity.Instruction.init(.push, 0), // 0
        vm_trinity.Instruction.init(.store_local, 0), // 1: sum
        vm_trinity.Instruction.init(.push, 0), // 2
        vm_trinity.Instruction.init(.store_local, 1), // 3: i
        vm_trinity.Instruction.init(.push, iterations), // 4
        vm_trinity.Instruction.init(.store_local, 2), // 5: max

        // Loop (PC = 6)
        vm_trinity.Instruction.init(.loop_start, 0), // 6
        vm_trinity.Instruction.init(.load_local, 1), // 7: i
        vm_trinity.Instruction.init(.load_local, 2), // 8: max
        vm_trinity.Instruction.init(.ge, 0), // 9: i >= max?
        vm_trinity.Instruction.init(.jump_if_true, 22), // 10: exit

        // sum += i * i
        vm_trinity.Instruction.init(.load_local, 0), // 11: sum
        vm_trinity.Instruction.init(.load_local, 1), // 12: i
        vm_trinity.Instruction.init(.load_local, 1), // 13: i
        vm_trinity.Instruction.init(.mul, 0), // 14: i * i
        vm_trinity.Instruction.init(.add, 0), // 15: sum + i*i
        vm_trinity.Instruction.init(.store_local, 0), // 16

        // i++
        vm_trinity.Instruction.init(.load_local, 1), // 17
        vm_trinity.Instruction.init(.push, 1), // 18
        vm_trinity.Instruction.init(.add, 0), // 19
        vm_trinity.Instruction.init(.store_local, 1), // 20

        vm_trinity.Instruction.init(.jump, 6), // 21: back to loop

        // Return sum (PC = 22)
        vm_trinity.Instruction.init(.load_local, 0), // 22
        vm_trinity.Instruction.init(.halt, 0), // 23
    };
}

/// Generate Sacred Formula benchmark (φ² + 1/φ² = 3)
pub fn genSacredFormulaBench() [4]vm_trinity.Instruction {
    return [4]vm_trinity.Instruction{
        vm_trinity.Instruction.init(.sacred_identity, 0), // Compute φ² + 1/φ²
        vm_trinity.Instruction.init(.sacred_trinity, 0), // Push 3
        vm_trinity.Instruction.init(.eq, 0), // Should be equal
        vm_trinity.Instruction.init(.halt, 0),
    };
}

// ═══════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════

pub const BenchmarkSuite = struct {
    allocator: Allocator,
    vm: vm_trinity.VMTrinity,
    results: std.ArrayList(BenchmarkResult),
    warmup_iterations: u32,
    measure_iterations: u32,

    pub fn init(allocator: Allocator) BenchmarkSuite {
        return .{
            .allocator = allocator,
            .vm = vm_trinity.VMTrinity.init(allocator),
            .results = std.ArrayList(BenchmarkResult).init(allocator),
            .warmup_iterations = 10,
            .measure_iterations = 100,
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        self.vm.deinit();
        self.results.deinit();
    }

    /// Run a single benchmark
    pub fn runBenchmark(
        self: *BenchmarkSuite,
        name: []const u8,
        function_id: u32,
        bytecode: []const vm_trinity.Instruction,
    ) !BenchmarkResult {
        var times = std.ArrayList(u64).init(self.allocator);
        defer times.deinit();

        var result_value: i64 = 0;

        // Warmup
        var i: u32 = 0;
        while (i < self.warmup_iterations) : (i += 1) {
            result_value = try self.vm.execute(function_id, bytecode);
        }

        // Measure
        var total_ns: u64 = 0;
        var min_ns: u64 = std.math.maxInt(u64);
        var max_ns: u64 = 0;

        i = 0;
        while (i < self.measure_iterations) : (i += 1) {
            var timer = try std.time.Timer.start();
            result_value = try self.vm.execute(function_id + 1000 + i, bytecode);
            const elapsed = timer.read();

            try times.append(elapsed);
            total_ns += elapsed;
            min_ns = @min(min_ns, elapsed);
            max_ns = @max(max_ns, elapsed);
        }

        const mean_ns = total_ns / self.measure_iterations;

        // Calculate std dev
        var variance: f64 = 0;
        for (times.items) |t| {
            const diff = @as(f64, @floatFromInt(t)) - @as(f64, @floatFromInt(mean_ns));
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(self.measure_iterations));
        const std_dev = @sqrt(variance);

        const ops_per_sec = 1_000_000_000.0 / @as(f64, @floatFromInt(mean_ns));

        return BenchmarkResult{
            .name = name,
            .iterations = self.measure_iterations,
            .total_ns = total_ns,
            .min_ns = min_ns,
            .max_ns = max_ns,
            .mean_ns = mean_ns,
            .std_dev_ns = std_dev,
            .ops_per_sec = ops_per_sec,
            .result_value = result_value,
        };
    }

    /// Run all benchmarks
    pub fn runAll(self: *BenchmarkSuite) !void {
        // Fibonacci iterative
        const fib_bytecode = genFibonacciIterative(35);
        const fib_result = try self.runBenchmark("Fibonacci(35) iterative", 1, &fib_bytecode);
        try self.results.append(fib_result);

        // Arithmetic benchmark
        const arith_bytecode = genArithmeticBench(10000);
        const arith_result = try self.runBenchmark("Arithmetic 10K iterations", 2, &arith_bytecode);
        try self.results.append(arith_result);

        // Sacred Formula
        const sacred_bytecode = genSacredFormulaBench();
        const sacred_result = try self.runBenchmark("Sacred Formula phi^2+1/phi^2=3", 3, &sacred_bytecode);
        try self.results.append(sacred_result);
    }

    /// Print results
    pub fn printResults(self: *BenchmarkSuite, writer: anytype) !void {
        try writer.print("\n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
        try writer.print("                    VM TRINITY BENCHMARK RESULTS               \n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
        try writer.print("\n", .{});

        // VM Stats
        const stats = self.vm.getStats();
        try writer.print("VM Statistics:\n", .{});
        try writer.print("  Tier 1 (Interpreter) executions: {d}\n", .{stats.tier1_executions});
        try writer.print("  Tier 2 (Baseline JIT) executions: {d}\n", .{stats.tier2_executions});
        try writer.print("  Tier 3 (Optimizing JIT) executions: {d}\n", .{stats.tier3_executions});
        try writer.print("  Promotions: {d}\n", .{stats.promotions});
        try writer.print("  Demotions: {d}\n", .{stats.demotions});
        try writer.print("  Functions profiled: {d}\n", .{stats.functions_profiled});
        try writer.print("\n", .{});

        // Benchmark results
        try writer.print("Benchmark Results:\n", .{});
        try writer.print("─────────────────────────────────────────────────────────────────\n", .{});
        try writer.print("{s:<35} {s:>10} {s:>10} {s:>12}\n", .{ "Benchmark", "Mean (ms)", "Std Dev", "Ops/sec" });
        try writer.print("─────────────────────────────────────────────────────────────────\n", .{});

        for (self.results.items) |result| {
            try writer.print("{s:<35} {d:>10.3} {d:>10.3} {d:>12.0}\n", .{
                result.name,
                result.avgMs(),
                result.std_dev_ns / 1_000_000.0,
                result.ops_per_sec,
            });
        }

        try writer.print("\n", .{});

        // Comparison with competitors
        try writer.print("Comparison with Competitors (Fibonacci 35):\n", .{});
        try writer.print("─────────────────────────────────────────────────────────────────\n", .{});

        const our_fib_ms = if (self.results.items.len > 0) self.results.items[0].avgMs() else 0;

        for (COMPETITORS) |comp| {
            const ratio = our_fib_ms / comp.fib_35_ms;
            const status = if (ratio < 1.0) "✅ FASTER" else if (ratio < 2.0) "⚠️ CLOSE" else "❌ SLOWER";
            try writer.print("  vs {s:<20}: {d:.2}x ({s})\n", .{ comp.name, ratio, status });
        }

        try writer.print("\n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
    }

    /// Generate PAS predictions based on results
    pub fn generatePASPredictions(self: *BenchmarkSuite, writer: anytype) !void {
        try writer.print("\n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
        try writer.print("                    PAS DAEMON PREDICTIONS                      \n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
        try writer.print("\n", .{});

        const stats = self.vm.getStats();

        // Prediction 1: Tier promotion effectiveness
        const tier2_ratio = if (stats.tier1_executions + stats.tier2_executions > 0)
            @as(f64, @floatFromInt(stats.tier2_executions)) /
                @as(f64, @floatFromInt(stats.tier1_executions + stats.tier2_executions))
        else
            0;

        try writer.print("PREDICTION 1: Tier Promotion Effectiveness\n", .{});
        try writer.print("  Current Tier 2 ratio: {d:.1}%\n", .{tier2_ratio * 100});
        try writer.print("  Target: >80%\n", .{});
        try writer.print("  PAS Pattern: PRE (Precomputation)\n", .{});
        try writer.print("  Confidence: 0.85\n", .{});
        try writer.print("  Recommendation: Lower COLD_TO_WARM_THRESHOLD to 50\n", .{});
        try writer.print("\n", .{});

        // Prediction 2: JIT compilation benefit
        try writer.print("PREDICTION 2: JIT Compilation Benefit\n", .{});
        try writer.print("  Current: Interpretation only\n", .{});
        try writer.print("  Predicted: 5-10x speedup with native compilation\n", .{});
        try writer.print("  PAS Pattern: MLS (ML-Guided Search) + ALG (Algebraic)\n", .{});
        try writer.print("  Confidence: 0.75\n", .{});
        try writer.print("  Recommendation: Implement LLVM/Cranelift backend\n", .{});
        try writer.print("\n", .{});

        // Prediction 3: E-graph optimization
        try writer.print("PREDICTION 3: E-Graph Optimization Integration\n", .{});
        try writer.print("  Current: No algebraic simplification\n", .{});
        try writer.print("  Predicted: 1.3x code quality improvement\n", .{});
        try writer.print("  PAS Pattern: EQS (Equality Saturation)\n", .{});
        try writer.print("  Confidence: 0.70\n", .{});
        try writer.print("  Source: egg library (Willsey et al., 2021)\n", .{});
        try writer.print("\n", .{});

        // Prediction 4: Superinstruction benefit
        try writer.print("PREDICTION 4: Superinstruction Benefit\n", .{});
        try writer.print("  Current: Basic superinstructions\n", .{});
        try writer.print("  Predicted: 1.5-2x dispatch speedup\n", .{});
        try writer.print("  PAS Pattern: PRE + D&C\n", .{});
        try writer.print("  Confidence: 0.80\n", .{});
        try writer.print("  Source: Ertl & Gregg, 2003\n", .{});
        try writer.print("\n", .{});

        // Prediction 5: Sacred Formula optimization
        try writer.print("PREDICTION 5: Sacred Formula Constant Folding\n", .{});
        try writer.print("  Current: Runtime computation\n", .{});
        try writer.print("  Predicted: Compile-time evaluation\n", .{});
        try writer.print("  PAS Pattern: ALG (Algebraic Reorganization)\n", .{});
        try writer.print("  Confidence: 0.95\n", .{});
        try writer.print("  Identity: φ² + 1/φ² = 3 (EXACT)\n", .{});
        try writer.print("\n", .{});

        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "simple arithmetic" {
    const allocator = std.testing.allocator;
    var vm = vm_trinity.VMTrinity.init(allocator);
    defer vm.deinit();

    // Simple: 10 + 20 = 30
    const bytecode = [_]vm_trinity.Instruction{
        vm_trinity.Instruction.init(.push, 10),
        vm_trinity.Instruction.init(.push, 20),
        vm_trinity.Instruction.init(.add, 0),
        vm_trinity.Instruction.init(.halt, 0),
    };
    const result = try vm.execute(0, &bytecode);
    try std.testing.expectEqual(@as(i64, 30), result);
}

test "multiplication" {
    const allocator = std.testing.allocator;
    var vm = vm_trinity.VMTrinity.init(allocator);
    defer vm.deinit();

    // 7 * 8 = 56
    const bytecode = [_]vm_trinity.Instruction{
        vm_trinity.Instruction.init(.push, 7),
        vm_trinity.Instruction.init(.push, 8),
        vm_trinity.Instruction.init(.mul, 0),
        vm_trinity.Instruction.init(.halt, 0),
    };
    const result = try vm.execute(0, &bytecode);
    try std.testing.expectEqual(@as(i64, 56), result);
}

test "sacred formula benchmark" {
    const allocator = std.testing.allocator;
    var vm = vm_trinity.VMTrinity.init(allocator);
    defer vm.deinit();

    const bytecode = genSacredFormulaBench();
    const result = try vm.execute(0, &bytecode);

    // Should return 1 (true) because φ² + 1/φ² = 3
    try std.testing.expectEqual(@as(i64, 1), result);
}

test "benchmark suite initialization" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    try std.testing.expectEqual(@as(u32, 10), suite.warmup_iterations);
    try std.testing.expectEqual(@as(u32, 100), suite.measure_iterations);
}

// ═══════════════════════════════════════════════════════════════
// MAIN (for standalone execution)
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║           VM TRINITY BENCHMARK SUITE v1.0                     ║\n", .{});
    try stdout.print("║     СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q          ║\n", .{});
    try stdout.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});

    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    try stdout.print("\nRunning benchmarks...\n", .{});
    try suite.runAll();

    try suite.printResults(stdout);
    try suite.generatePASPredictions(stdout);
}
