//! VIBEE ML Zig Benchmarks
//! ========================

const std = @import("std");
const time = std.time;

const core = @import("../src/core.zig");
const attention = @import("../src/attention.zig");
const optimizers = @import("../src/optimizers.zig");
const quantization = @import("../src/quantization.zig");

const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_ns: u64,
    avg_ns: u64,
    ops_per_sec: f64,
};

fn benchmark(comptime name: []const u8, comptime func: anytype, iterations: usize) BenchmarkResult {
    // Warmup
    for (0..10) |_| {
        func();
    }

    // Benchmark
    const start = time.nanoTimestamp();
    for (0..iterations) |_| {
        func();
    }
    const end = time.nanoTimestamp();

    const total_ns: u64 = @intCast(end - start);
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1e9);

    return BenchmarkResult{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .ops_per_sec = ops_per_sec,
    };
}

fn printResult(result: BenchmarkResult) void {
    std.debug.print("{s:<30} {d:>10} iters  {d:>10} ns/op  {d:>12.2} ops/sec\n", .{
        result.name,
        result.iterations,
        result.avg_ns,
        result.ops_per_sec,
    });
}

// Benchmark functions
var bench_params: [1024]f32 = undefined;
var bench_grads: [1024]f32 = undefined;
var bench_momentum: [1024]f32 = undefined;

fn benchLionStep() void {
    optimizers.lionStep(&bench_params, &bench_grads, &bench_momentum, optimizers.LionConfig{});
}

var bench_state: optimizers.OptimizerState(f32) = undefined;
var bench_state_initialized = false;

fn initBenchState() void {
    if (!bench_state_initialized) {
        bench_state = optimizers.OptimizerState(f32){
            .exp_avg = &[_]f32{0} ** 1024,
            .exp_avg_sq = &[_]f32{0} ** 1024,
            .step = 0,
        };
        bench_state_initialized = true;
    }
}

var quant_input: [1024]f32 = undefined;
var quant_output: [1024]i8 = undefined;

fn benchQuantizeInt8() void {
    const params = quantization.QuantParams{ .scale = 0.01, .zero_point = 0 };
    quantization.quantizeInt8(&quant_input, &quant_output, params);
}

var softmax_input: [512]f32 = undefined;
var softmax_output: [512]f32 = undefined;

fn benchSoftmax() void {
    attention.softmax(&softmax_input, &softmax_output);
}

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("=" ** 70 ++ "\n", .{});
    std.debug.print("VIBEE ML Zig Benchmarks\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});

    // Initialize test data
    for (&bench_params, 0..) |*p, i| {
        p.* = @as(f32, @floatFromInt(i)) * 0.001;
    }
    for (&bench_grads, 0..) |*g, i| {
        g.* = @as(f32, @floatFromInt(i % 100)) * 0.0001;
    }
    @memset(&bench_momentum, 0);

    for (&quant_input, 0..) |*v, i| {
        v.* = @as(f32, @floatFromInt(i % 256)) * 0.01 - 1.28;
    }

    for (&softmax_input, 0..) |*v, i| {
        v.* = @as(f32, @floatFromInt(i % 10)) * 0.1;
    }

    // Run benchmarks
    std.debug.print("{s:<30} {s:>10}       {s:>10}       {s:>12}\n", .{ "Benchmark", "Iterations", "Time/Op", "Throughput" });
    std.debug.print("-" ** 70 ++ "\n", .{});

    printResult(benchmark("Lion optimizer step", benchLionStep, 10000));
    printResult(benchmark("INT8 quantization (1024)", benchQuantizeInt8, 10000));
    printResult(benchmark("Softmax (512)", benchSoftmax, 10000));

    std.debug.print("\n", .{});
    std.debug.print("Sacred Constants Verification:\n", .{});
    std.debug.print("  φ = {d:.15}\n", .{core.PHI});
    std.debug.print("  φ² + 1/φ² = {d:.15} (should be 3.0)\n", .{core.GOLDEN_IDENTITY});
    std.debug.print("  PHOENIX = {d}\n", .{core.PHOENIX});
    std.debug.print("\n", .{});
}
