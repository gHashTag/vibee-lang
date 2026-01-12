// VIBEE Phase 3 Compiler Benchmark Runner
const std = @import("std");
const phase3 = @import("vibeec_phase3.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try phase3.runPhase3Benchmark(allocator);
}
