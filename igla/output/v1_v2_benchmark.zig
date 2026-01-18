// V1 vs V2 Superinstructions Benchmark
const std = @import("std");
const superinstructions = @import("superinstructions.zig");
const superinstructions_v2 = @import("superinstructions_v2.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try stdout.print("\n╔═══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║  V1 vs V2 SUPERINSTRUCTIONS BENCHMARK                                         ║\n", .{});
    try stdout.print("╚═══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});
    
    const iterations: u32 = 100000;
    
    // V1 Benchmark: PUSH 10, PUSH 5, ADD (using LOAD2_ADD)
    {
        var vm = superinstructions.SuperVM.init(allocator);
        defer vm.deinit();
        
        // V1 code: LOAD2_ADD 10 5
        const code_v1 = [_]u8{ 0x85, 10, 5 };
        
        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            vm.load(&code_v1);
            _ = vm.run() catch 0;
            vm.stack.clearRetainingCapacity();
        }
        const end = std.time.nanoTimestamp();
        
        const total_ns: u64 = @intCast(end - start);
        const avg_ns = total_ns / iterations;
        try stdout.print("V1 LOAD2_ADD (1-byte immediates): {d} ns/op\n", .{avg_ns});
    }
    
    // V2 Benchmark: LOAD2_ADD with 8-byte immediates
    {
        var vm = superinstructions_v2.SuperVMV2.init(allocator);
        defer vm.deinit();
        
        // V2 code: LOAD2_ADD with 8-byte immediates
        const code_v2 = [_]u8{
            @intFromEnum(superinstructions_v2.SuperOpcodeV2.LOAD2_ADD),
        } ++ @as([8]u8, @bitCast(@as(i64, 10))) ++
            @as([8]u8, @bitCast(@as(i64, 5)));
        
        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            vm.load(&code_v2);
            _ = vm.run() catch 0;
            vm.reset();
        }
        const end = std.time.nanoTimestamp();
        
        const total_ns: u64 = @intCast(end - start);
        const avg_ns = total_ns / iterations;
        try stdout.print("V2 LOAD2_ADD (8-byte immediates): {d} ns/op\n", .{avg_ns});
    }
    
    // V1 Benchmark: DUP_MUL
    {
        var vm = superinstructions.SuperVM.init(allocator);
        defer vm.deinit();
        
        // V1 code: PUSH 5, DUP_MUL
        const code_v1 = [_]u8{ 0x10, 5, 0x84 };
        
        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            vm.load(&code_v1);
            _ = vm.run() catch 0;
            vm.stack.clearRetainingCapacity();
        }
        const end = std.time.nanoTimestamp();
        
        const total_ns: u64 = @intCast(end - start);
        const avg_ns = total_ns / iterations;
        try stdout.print("V1 DUP_MUL: {d} ns/op\n", .{avg_ns});
    }
    
    // V2 Benchmark: DUP_MUL
    {
        var vm = superinstructions_v2.SuperVMV2.init(allocator);
        defer vm.deinit();
        
        // V2 code: PUSH 5, DUP_MUL
        const code_v2 = [_]u8{
            @intFromEnum(superinstructions_v2.SuperOpcodeV2.PUSH),
        } ++ @as([8]u8, @bitCast(@as(i64, 5))) ++ [_]u8{
            @intFromEnum(superinstructions_v2.SuperOpcodeV2.DUP_MUL),
        };
        
        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            vm.load(&code_v2);
            _ = vm.run() catch 0;
            vm.reset();
        }
        const end = std.time.nanoTimestamp();
        
        const total_ns: u64 = @intCast(end - start);
        const avg_ns = total_ns / iterations;
        try stdout.print("V2 DUP_MUL: {d} ns/op\n", .{avg_ns});
    }
    
    // V2 NEW: TRINITY_MUL3
    {
        var vm = superinstructions_v2.SuperVMV2.init(allocator);
        defer vm.deinit();
        
        const code_v2 = [_]u8{
            @intFromEnum(superinstructions_v2.SuperOpcodeV2.PUSH),
        } ++ @as([8]u8, @bitCast(@as(i64, 7))) ++ [_]u8{
            @intFromEnum(superinstructions_v2.SuperOpcodeV2.TRINITY_MUL3),
        };
        
        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            vm.load(&code_v2);
            _ = vm.run() catch 0;
            vm.reset();
        }
        const end = std.time.nanoTimestamp();
        
        const total_ns: u64 = @intCast(end - start);
        const avg_ns = total_ns / iterations;
        try stdout.print("V2 TRINITY_MUL3: {d} ns/op\n", .{avg_ns});
    }
    
    // V2 NEW: PHI_GROW
    {
        var vm = superinstructions_v2.SuperVMV2.init(allocator);
        defer vm.deinit();
        
        const code_v2 = [_]u8{
            @intFromEnum(superinstructions_v2.SuperOpcodeV2.PUSH),
        } ++ @as([8]u8, @bitCast(@as(i64, 1000))) ++ [_]u8{
            @intFromEnum(superinstructions_v2.SuperOpcodeV2.PHI_GROW),
        };
        
        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            vm.load(&code_v2);
            _ = vm.run() catch 0;
            vm.reset();
        }
        const end = std.time.nanoTimestamp();
        
        const total_ns: u64 = @intCast(end - start);
        const avg_ns = total_ns / iterations;
        try stdout.print("V2 PHI_GROW: {d} ns/op\n", .{avg_ns});
    }
    
    try stdout.print("\n╔═══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║  ANALYSIS                                                                     ║\n", .{});
    try stdout.print("╠═══════════════════════════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║  V2 uses 8-byte immediates vs V1's 1-byte immediates                          ║\n", .{});
    try stdout.print("║  This adds memory read latency that outweighs dispatch savings                ║\n", .{});
    try stdout.print("║  SOLUTION: Use inline constants or threaded code                              ║\n", .{});
    try stdout.print("╚═══════════════════════════════════════════════════════════════════════════════╝\n", .{});
}
