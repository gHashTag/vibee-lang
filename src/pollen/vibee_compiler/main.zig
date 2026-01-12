// VIBEE Compiler Benchmark Runner
const std = @import("std");
const benchmark = @import("vibeec_benchmark.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try benchmark.runBenchmark(allocator);
}
