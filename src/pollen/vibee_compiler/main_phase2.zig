// VIBEE Phase 2 Compiler Benchmark Runner
const std = @import("std");
const phase2 = @import("vibeec_phase2.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try phase2.runPhase2Benchmark(allocator);
}
