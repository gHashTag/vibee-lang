// ═══════════════════════════════════════════════════════════════
// BENCHMARK - Real performance measurements for PAS claims
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const parser = @import("parser.zig");
const simd_parser = @import("simd_parser.zig");
const egraph = @import("egraph.zig");

// ═══════════════════════════════════════════════════════════════
// BENCHMARK RESULTS
// ═══════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u32,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,
    
    pub fn avgNs(self: BenchmarkResult) u64 {
        return self.total_ns / self.iterations;
    }
    
    pub fn avgMs(self: BenchmarkResult) f64 {
        return @as(f64, @floatFromInt(self.avgNs())) / 1_000_000.0;
    }
    
    pub fn throughputMBps(self: BenchmarkResult, bytes: usize) f64 {
        const ns_per_iter = self.avgNs();
        if (ns_per_iter == 0) return 0;
        const bytes_per_sec = @as(f64, @floatFromInt(bytes)) * 1_000_000_000.0 / @as(f64, @floatFromInt(ns_per_iter));
        return bytes_per_sec / (1024.0 * 1024.0);
    }
};

// ═══════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════

pub fn runBenchmark(name: []const u8, iterations: u32, func: *const fn () void) BenchmarkResult {
    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;
    
    // Warmup
    for (0..10) |_| {
        func();
    }
    
    // Actual benchmark
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        func();
        const end = std.time.nanoTimestamp();
        
        const elapsed: u64 = @intCast(end - start);
        total_ns += elapsed;
        min_ns = @min(min_ns, elapsed);
        max_ns = @max(max_ns, elapsed);
    }
    
    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

// ═══════════════════════════════════════════════════════════════
// TEST DATA
// ═══════════════════════════════════════════════════════════════

const small_spec =
    \\name: test_spec
    \\version: "1.0.0"
    \\language: zig
    \\module: test
    \\
    \\behaviors:
    \\  - name: test_behavior
    \\    given: A test condition
    \\    when: Action is taken
    \\    then: Expected result
;

const medium_spec =
    \\name: medium_spec
    \\version: "2.0.0"
    \\language: zig
    \\module: medium_test
    \\
    \\creation_pattern:
    \\  source: InputData
    \\  transformer: ProcessData
    \\  result: OutputData
    \\
    \\behaviors:
    \\  - name: behavior_1
    \\    given: Condition 1
    \\    when: Action 1
    \\    then: Result 1
    \\  - name: behavior_2
    \\    given: Condition 2
    \\    when: Action 2
    \\    then: Result 2
    \\  - name: behavior_3
    \\    given: Condition 3
    \\    when: Action 3
    \\    then: Result 3
    \\
    \\functions:
    \\  - name: process
    \\    params: [input]
    \\    returns: output
    \\  - name: validate
    \\    params: [data]
    \\    returns: bool
;

// ═══════════════════════════════════════════════════════════════
// PARSER BENCHMARKS
// ═══════════════════════════════════════════════════════════════

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
var standard_result: ?parser.Spec = null;
var simd_result: ?parser.Spec = null;

fn benchStandardParser() void {
    const allocator = gpa.allocator();
    if (standard_result) |*r| r.deinit();
    standard_result = parser.parse(allocator, medium_spec) catch null;
}

fn benchSIMDParser() void {
    const allocator = gpa.allocator();
    var fast_parser = simd_parser.FastYamlParser.init(allocator);
    defer fast_parser.deinit();
    if (simd_result) |*r| r.deinit();
    simd_result = fast_parser.parse(medium_spec) catch null;
}

// ═══════════════════════════════════════════════════════════════
// E-GRAPH BENCHMARKS
// ═══════════════════════════════════════════════════════════════

fn benchEGraphAdd() void {
    const allocator = gpa.allocator();
    var eg = egraph.EGraph.init(allocator);
    defer eg.deinit();
    
    // Add 100 expressions
    for (0..100) |i| {
        _ = eg.add(.{
            .tag = .constant,
            .children = &[_]egraph.EClassId{},
            .value = @intCast(i),
            .name = null,
        }) catch {};
    }
}

fn benchEGraphMerge() void {
    const allocator = gpa.allocator();
    var eg = egraph.EGraph.init(allocator);
    defer eg.deinit();
    
    // Add expressions
    var ids: [50]egraph.EClassId = undefined;
    for (0..50) |i| {
        ids[i] = eg.add(.{
            .tag = .constant,
            .children = &[_]egraph.EClassId{},
            .value = @intCast(i),
            .name = null,
        }) catch 0;
    }
    
    // Merge pairs
    for (0..25) |i| {
        _ = eg.merge(ids[i * 2], ids[i * 2 + 1]) catch {};
    }
}

// ═══════════════════════════════════════════════════════════════
// MAIN BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.writeAll(
        \\╔══════════════════════════════════════════════════════════════╗
        \\║  VIBEE PAS BENCHMARK - Real Performance Measurements         ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\
        \\
    );
    
    const iterations: u32 = 1000;
    
    // Parser benchmarks
    try stdout.writeAll("═══ PARSER BENCHMARKS ═══\n\n");
    
    const standard_bench = runBenchmark("Standard Parser", iterations, benchStandardParser);
    const simd_bench = runBenchmark("SIMD Parser", iterations, benchSIMDParser);
    
    try stdout.print("Standard Parser:\n", .{});
    try stdout.print("  Avg: {d:.3} ms\n", .{standard_bench.avgMs()});
    try stdout.print("  Min: {d:.3} ms\n", .{@as(f64, @floatFromInt(standard_bench.min_ns)) / 1_000_000.0});
    try stdout.print("  Max: {d:.3} ms\n", .{@as(f64, @floatFromInt(standard_bench.max_ns)) / 1_000_000.0});
    try stdout.print("  Throughput: {d:.2} MB/s\n\n", .{standard_bench.throughputMBps(medium_spec.len)});
    
    try stdout.print("SIMD Parser:\n", .{});
    try stdout.print("  Avg: {d:.3} ms\n", .{simd_bench.avgMs()});
    try stdout.print("  Min: {d:.3} ms\n", .{@as(f64, @floatFromInt(simd_bench.min_ns)) / 1_000_000.0});
    try stdout.print("  Max: {d:.3} ms\n", .{@as(f64, @floatFromInt(simd_bench.max_ns)) / 1_000_000.0});
    try stdout.print("  Throughput: {d:.2} MB/s\n\n", .{simd_bench.throughputMBps(medium_spec.len)});
    
    // Calculate speedup
    const speedup = @as(f64, @floatFromInt(standard_bench.avgNs())) / @as(f64, @floatFromInt(simd_bench.avgNs()));
    try stdout.print("SIMD Speedup: {d:.2}x\n\n", .{speedup});
    
    // E-Graph benchmarks
    try stdout.writeAll("═══ E-GRAPH BENCHMARKS ═══\n\n");
    
    const egraph_add_bench = runBenchmark("E-Graph Add", iterations, benchEGraphAdd);
    const egraph_merge_bench = runBenchmark("E-Graph Merge", iterations, benchEGraphMerge);
    
    try stdout.print("E-Graph Add (100 nodes):\n", .{});
    try stdout.print("  Avg: {d:.3} ms\n", .{egraph_add_bench.avgMs()});
    try stdout.print("  Ops/sec: {d:.0}\n\n", .{100.0 * 1_000_000_000.0 / @as(f64, @floatFromInt(egraph_add_bench.avgNs()))});
    
    try stdout.print("E-Graph Merge (25 pairs):\n", .{});
    try stdout.print("  Avg: {d:.3} ms\n", .{egraph_merge_bench.avgMs()});
    try stdout.print("  Ops/sec: {d:.0}\n\n", .{25.0 * 1_000_000_000.0 / @as(f64, @floatFromInt(egraph_merge_bench.avgNs()))});
    
    // Summary
    try stdout.writeAll(
        \\═══ SUMMARY ═══
        \\
        \\
    );
    
    if (speedup >= 1.0) {
        try stdout.print("✅ SIMD Parser: {d:.2}x speedup (target: 3.0x)\n", .{speedup});
    } else {
        try stdout.print("❌ SIMD Parser: {d:.2}x (SLOWER than standard!)\n", .{speedup});
    }
    
    try stdout.writeAll(
        \\
        \\NOTE: These are REAL measurements, not fabricated numbers.
        \\The hybrid SIMD approach uses SIMD for structure detection
        \\but still delegates complex nested parsing to standard parser.
        \\
    );
    
    // Cleanup
    if (standard_result) |*r| r.deinit();
    if (simd_result) |*r| r.deinit();
    _ = gpa.deinit();
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "benchmark result calculations" {
    const result = BenchmarkResult{
        .name = "test",
        .iterations = 100,
        .total_ns = 1_000_000_000, // 1 second total
        .min_ns = 5_000_000,
        .max_ns = 15_000_000,
    };
    
    try std.testing.expectEqual(@as(u64, 10_000_000), result.avgNs()); // 10ms avg
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), result.avgMs(), 0.001);
}
