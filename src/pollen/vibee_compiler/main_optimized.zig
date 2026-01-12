// VIBEE Optimized Compiler Benchmark Runner
const std = @import("std");
const optimized = @import("vibeec_optimized.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try optimized.runOptimizedBenchmark(allocator);
}
