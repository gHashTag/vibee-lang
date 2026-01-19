// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY v24.φ - Benchmark Suite
// ═══════════════════════════════════════════════════════════════════════════════
//
// Реальные бенчмарки для PAS анализа
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const time = std.time;
const phi_core = @import("src/phi_core.zig");

const PHI = phi_core.PHI;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    TRINITY v24.φ - Benchmark Suite\n", .{});
    try stdout.print("                    φ² + 1/φ² = 3\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("\n", .{});
    
    // Benchmark 1: Fibonacci
    try stdout.print("📊 Benchmark 1: Fibonacci\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    try benchmarkFibonacci(stdout);
    
    // Benchmark 2: φ-Power
    try stdout.print("\n📊 Benchmark 2: φ-Power\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    try benchmarkPhiPower(stdout);
    
    // Benchmark 3: φ-Spiral
    try stdout.print("\n📊 Benchmark 3: φ-Spiral Generation\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    try benchmarkSpiral(stdout);
    
    // Benchmark 4: TRINITY Identity
    try stdout.print("\n📊 Benchmark 4: TRINITY Identity Verification\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    try benchmarkTrinity(stdout);
    
    // Summary
    try stdout.print("\n═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                              SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("\n", .{});
}

fn benchmarkFibonacci(writer: anytype) !void {
    const iterations: u32 = 1_000_000;
    
    // Warmup
    var warmup: u64 = 0;
    for (0..1000) |i| {
        warmup += phi_core.fibonacci(@intCast(i % 40));
    }
    
    // Benchmark Binet formula
    const start = time.nanoTimestamp();
    var sum: u64 = 0;
    for (0..iterations) |i| {
        sum += phi_core.fibonacci(@intCast(i % 40));
    }
    const elapsed = time.nanoTimestamp() - start;
    
    const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1_000_000_000.0 / ns_per_op;
    
    try writer.print("  Iterations:    {d}\n", .{iterations});
    try writer.print("  Total time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});
    try writer.print("  Per operation: {d:.2} ns\n", .{ns_per_op});
    try writer.print("  Throughput:    {d:.0} ops/sec\n", .{ops_per_sec});
    try writer.print("  Checksum:      {d} (prevents optimization)\n", .{sum});
    
    // Verify correctness
    try writer.print("  F(10) = {d} (expected 55)\n", .{phi_core.fibonacci(10)});
    try writer.print("  F(20) = {d} (expected 6765)\n", .{phi_core.fibonacci(20)});
}

fn benchmarkPhiPower(writer: anytype) !void {
    const iterations: u32 = 10_000_000;
    
    // Warmup
    var warmup: f64 = 0;
    for (0..1000) |i| {
        warmup += phi_core.phi_power(@intCast(@as(i32, @intCast(i % 100)) - 50));
    }
    
    // Benchmark
    const start = time.nanoTimestamp();
    var sum: f64 = 0;
    for (0..iterations) |i| {
        sum += phi_core.phi_power(@intCast(@as(i32, @intCast(i % 100)) - 50));
    }
    const elapsed = time.nanoTimestamp() - start;
    
    const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1_000_000_000.0 / ns_per_op;
    
    try writer.print("  Iterations:    {d}\n", .{iterations});
    try writer.print("  Total time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});
    try writer.print("  Per operation: {d:.2} ns\n", .{ns_per_op});
    try writer.print("  Throughput:    {d:.0} ops/sec\n", .{ops_per_sec});
    try writer.print("  Checksum:      {d:.6} (prevents optimization)\n", .{sum});
    
    // Verify
    try writer.print("  φ^0 = {d:.10} (expected 1.0)\n", .{phi_core.phi_power(0)});
    try writer.print("  φ^1 = {d:.10} (expected 1.618...)\n", .{phi_core.phi_power(1)});
    try writer.print("  φ^2 = {d:.10} (expected 2.618...)\n", .{phi_core.phi_power(2)});
}

fn benchmarkSpiral(writer: anytype) !void {
    const iterations: u32 = 10_000;
    const points: u32 = 1000;
    
    // Warmup
    for (0..10) |_| {
        _ = phi_core.generate_phi_spiral(points, 1.0, 0.0, 0.0);
    }
    
    // Benchmark
    const start = time.nanoTimestamp();
    var total_points: u64 = 0;
    for (0..iterations) |_| {
        total_points += phi_core.generate_phi_spiral(points, 1.0, 0.0, 0.0);
    }
    const elapsed = time.nanoTimestamp() - start;
    
    const ns_per_spiral = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
    const spirals_per_sec = 1_000_000_000.0 / ns_per_spiral;
    const points_per_sec = spirals_per_sec * @as(f64, @floatFromInt(points));
    
    try writer.print("  Iterations:    {d}\n", .{iterations});
    try writer.print("  Points/spiral: {d}\n", .{points});
    try writer.print("  Total time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});
    try writer.print("  Per spiral:    {d:.2} µs\n", .{ns_per_spiral / 1000.0});
    try writer.print("  Spirals/sec:   {d:.0}\n", .{spirals_per_sec});
    try writer.print("  Points/sec:    {d:.0}\n", .{points_per_sec});
    try writer.print("  Total points:  {d}\n", .{total_points});
}

fn benchmarkTrinity(writer: anytype) !void {
    const iterations: u32 = 100_000_000;
    
    // Benchmark
    const start = time.nanoTimestamp();
    var sum: f64 = 0;
    for (0..iterations) |_| {
        sum += phi_core.verify_trinity();
    }
    const elapsed = time.nanoTimestamp() - start;
    
    const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1_000_000_000.0 / ns_per_op;
    
    try writer.print("  Iterations:    {d}\n", .{iterations});
    try writer.print("  Total time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});
    try writer.print("  Per operation: {d:.2} ns\n", .{ns_per_op});
    try writer.print("  Throughput:    {d:.0} ops/sec\n", .{ops_per_sec});
    
    const trinity = phi_core.verify_trinity();
    const error_val = @abs(trinity - 3.0);
    try writer.print("  φ² + 1/φ² =    {d:.15}\n", .{trinity});
    try writer.print("  Error:         {e}\n", .{error_val});
    try writer.print("  Verified:      {s}\n", .{if (error_val < 1e-10) "✓ PASS" else "✗ FAIL"});
}
