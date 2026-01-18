const std = @import("std");
const bench = @import("real_benchmark_v29.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("TRINITY VM v29 - REAL BENCHMARK RESULTS\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("φ² + 1/φ² = 3.0 | 33 = 3 x 11 | 999 = 27 x 37\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    // Run all benchmarks
    const results = bench.runFullBenchmark(allocator);

    try stdout.print("BENCHMARK RESULTS (REAL MEASUREMENTS):\n", .{});
    try stdout.print("-------------------------------------------------------------------------------\n", .{});
    
    try stdout.print("1. SIMD Softmax:     {d:.2}x speedup (baseline: {d}ns, optimized: {d}ns)\n", .{
        results.softmax_speedup.speedup,
        results.softmax_speedup.baseline_ns,
        results.softmax_speedup.optimized_ns,
    });
    
    try stdout.print("2. Stencil Emission: {d:.2}x speedup (baseline: {d}ns, optimized: {d}ns)\n", .{
        results.stencil_speedup.speedup,
        results.stencil_speedup.baseline_ns,
        results.stencil_speedup.optimized_ns,
    });
    
    try stdout.print("3. Fitness Cache:    {d:.2}x speedup (baseline: {d}ns, optimized: {d}ns)\n", .{
        results.cache_speedup.speedup,
        results.cache_speedup.baseline_ns,
        results.cache_speedup.optimized_ns,
    });
    
    try stdout.print("4. Hash Lookup:      {d:.2}x speedup (baseline: {d}ns, optimized: {d}ns)\n", .{
        results.hash_speedup.speedup,
        results.hash_speedup.baseline_ns,
        results.hash_speedup.optimized_ns,
    });

    try stdout.print("-------------------------------------------------------------------------------\n", .{});
    try stdout.print("AVERAGE SPEEDUP:     {d:.2}x\n", .{results.avgSpeedup()});
    try stdout.print("IS REAL BENCHMARK:   {}\n", .{results.is_real});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}
