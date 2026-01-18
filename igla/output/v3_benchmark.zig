// ═══════════════════════════════════════════════════════════════════════════════
// V3 BENCHMARK - V1 vs V2 vs V3 COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════
// GENERATED FROM: ⲩⲗⲩⲭⲥⲉⲛⲓⲁ_ⲩ8.tri
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const v1 = @import("superinstructions.zig");
const v2 = @import("superinstructions_v2.zig");
const v3 = @import("superinstructions_v3.zig");

const ITERATIONS: usize = 100000;
const WARMUP: usize = 1000;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲒⲄⲖⲀ BENCHMARK - V1 vs V2 vs V3\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q\n", .{});
    try stdout.print("ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = {d:.6}\n", .{
        v3.PHI_SQ + 1.0 / v3.PHI_SQ,
    });
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 1: TRINITY MULTIPLICATION (x * 3)
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("TEST 1: TRINITY MULTIPLICATION (x * 3)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    // V1: PUSH 100, PUSH 3, MUL, HALT (4 ops, 8-byte immediates)
    var vm_v1 = v1.SuperVM.init(allocator);
    defer vm_v1.deinit();
    
    const code_v1_mul3 = [_]u8{
        @intFromEnum(v1.SuperOpcode.PUSH), 100, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(v1.SuperOpcode.PUSH), 3, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(v1.SuperOpcode.MUL),
        @intFromEnum(v1.SuperOpcode.HALT),
    };
    
    // Warmup
    for (0..WARMUP) |_| {
        vm_v1.load(&code_v1_mul3);
        _ = vm_v1.run() catch 0;
    }
    
    var timer = try std.time.Timer.start();
    var v1_result: u64 = 0;
    for (0..ITERATIONS) |_| {
        vm_v1.load(&code_v1_mul3);
        v1_result = vm_v1.run() catch 0;
    }
    const v1_time = timer.read();
    const v1_ns = @as(f64, @floatFromInt(v1_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V1: PUSH 100, PUSH 3, MUL, HALT\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v1_result, v1_ns });
    
    // V2: PUSH 100, TRINITY_MUL3, HALT (2 ops, 8-byte immediate)
    var vm_v2 = v2.SuperVMV2.init(allocator);
    defer vm_v2.deinit();
    
    const code_v2_mul3 = [_]u8{
        @intFromEnum(v2.SuperOpcodeV2.PUSH),
    } ++ @as([8]u8, @bitCast(@as(i64, 100))) ++ [_]u8{
        @intFromEnum(v2.SuperOpcodeV2.TRINITY_MUL3),
        @intFromEnum(v2.SuperOpcodeV2.HALT),
    };
    
    // Warmup
    for (0..WARMUP) |_| {
        vm_v2.load(&code_v2_mul3);
        _ = vm_v2.run() catch 0;
    }
    
    timer.reset();
    var v2_result: i64 = 0;
    for (0..ITERATIONS) |_| {
        vm_v2.load(&code_v2_mul3);
        v2_result = vm_v2.run() catch 0;
    }
    const v2_time = timer.read();
    const v2_ns = @as(f64, @floatFromInt(v2_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V2: PUSH 100, TRINITY_MUL3, HALT (8-byte immediate)\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v2_result, v2_ns });
    
    // V3: PUSH_SMALL 100, MUL3, HALT (2 ops, 1-byte immediate + inline constant)
    var vm_v3 = v3.SuperVMV3.init(allocator);
    defer vm_v3.deinit();
    
    const code_v3_mul3 = [_]u8{
        @intFromEnum(v3.SuperOpcodeV3.PUSH_SMALL), 100,
        @intFromEnum(v3.SuperOpcodeV3.MUL3),
        @intFromEnum(v3.SuperOpcodeV3.HALT),
    };
    
    // Warmup
    for (0..WARMUP) |_| {
        vm_v3.load(&code_v3_mul3);
        _ = vm_v3.run() catch 0;
    }
    
    timer.reset();
    var v3_result: i64 = 0;
    for (0..ITERATIONS) |_| {
        vm_v3.load(&code_v3_mul3);
        v3_result = vm_v3.run() catch 0;
    }
    const v3_time = timer.read();
    const v3_ns = @as(f64, @floatFromInt(v3_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V3: PUSH_SMALL 100, MUL3, HALT (1-byte + inline constant)\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v3_result, v3_ns });
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 2: SQUARE (x * x)
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("TEST 2: SQUARE (x * x)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    // V1: PUSH 7, DUP, MUL, HALT
    const code_v1_sq = [_]u8{
        @intFromEnum(v1.SuperOpcode.PUSH), 7, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(v1.SuperOpcode.DUP),
        @intFromEnum(v1.SuperOpcode.MUL),
        @intFromEnum(v1.SuperOpcode.HALT),
    };
    
    for (0..WARMUP) |_| {
        vm_v1.load(&code_v1_sq);
        _ = vm_v1.run() catch 0;
    }
    
    timer.reset();
    for (0..ITERATIONS) |_| {
        vm_v1.load(&code_v1_sq);
        v1_result = vm_v1.run() catch 0;
    }
    const v1_sq_time = timer.read();
    const v1_sq_ns = @as(f64, @floatFromInt(v1_sq_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V1: PUSH 7, DUP, MUL, HALT\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v1_result, v1_sq_ns });
    
    // V2: PUSH 7, DUP_MUL, HALT
    const code_v2_sq = [_]u8{
        @intFromEnum(v2.SuperOpcodeV2.PUSH),
    } ++ @as([8]u8, @bitCast(@as(i64, 7))) ++ [_]u8{
        @intFromEnum(v2.SuperOpcodeV2.DUP_MUL),
        @intFromEnum(v2.SuperOpcodeV2.HALT),
    };
    
    for (0..WARMUP) |_| {
        vm_v2.load(&code_v2_sq);
        _ = vm_v2.run() catch 0;
    }
    
    timer.reset();
    for (0..ITERATIONS) |_| {
        vm_v2.load(&code_v2_sq);
        v2_result = vm_v2.run() catch 0;
    }
    const v2_sq_time = timer.read();
    const v2_sq_ns = @as(f64, @floatFromInt(v2_sq_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V2: PUSH 7, DUP_MUL, HALT (8-byte immediate)\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v2_result, v2_sq_ns });
    
    // V3: PUSH_SMALL 7, SQUARE, HALT
    const code_v3_sq = [_]u8{
        @intFromEnum(v3.SuperOpcodeV3.PUSH_SMALL), 7,
        @intFromEnum(v3.SuperOpcodeV3.SQUARE),
        @intFromEnum(v3.SuperOpcodeV3.HALT),
    };
    
    for (0..WARMUP) |_| {
        vm_v3.load(&code_v3_sq);
        _ = vm_v3.run() catch 0;
    }
    
    timer.reset();
    for (0..ITERATIONS) |_| {
        vm_v3.load(&code_v3_sq);
        v3_result = vm_v3.run() catch 0;
    }
    const v3_sq_time = timer.read();
    const v3_sq_ns = @as(f64, @floatFromInt(v3_sq_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V3: PUSH_SMALL 7, SQUARE, HALT (1-byte + inline)\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v3_result, v3_sq_ns });
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 3: GOLDEN IDENTITY (φ² + 1/φ² = 3)
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("TEST 3: GOLDEN IDENTITY (φ² + 1/φ² = 3)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    // V2: GOLDEN_IDENTITY, HALT
    const code_v2_golden = [_]u8{
        @intFromEnum(v2.SuperOpcodeV2.GOLDEN_IDENTITY),
        @intFromEnum(v2.SuperOpcodeV2.HALT),
    };
    
    for (0..WARMUP) |_| {
        vm_v2.load(&code_v2_golden);
        _ = vm_v2.run() catch 0;
    }
    
    timer.reset();
    for (0..ITERATIONS) |_| {
        vm_v2.load(&code_v2_golden);
        v2_result = vm_v2.run() catch 0;
    }
    const v2_golden_time = timer.read();
    const v2_golden_ns = @as(f64, @floatFromInt(v2_golden_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V2: GOLDEN_IDENTITY, HALT (computes φ² + 1/φ²)\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v2_result, v2_golden_ns });
    
    // V3: GOLDEN_ID, HALT (just pushes 3)
    const code_v3_golden = [_]u8{
        @intFromEnum(v3.SuperOpcodeV3.GOLDEN_ID),
        @intFromEnum(v3.SuperOpcodeV3.HALT),
    };
    
    for (0..WARMUP) |_| {
        vm_v3.load(&code_v3_golden);
        _ = vm_v3.run() catch 0;
    }
    
    timer.reset();
    for (0..ITERATIONS) |_| {
        vm_v3.load(&code_v3_golden);
        v3_result = vm_v3.run() catch 0;
    }
    const v3_golden_time = timer.read();
    const v3_golden_ns = @as(f64, @floatFromInt(v3_golden_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  V3: GOLDEN_ID, HALT (inline constant 3)\n", .{});
    try stdout.print("      Result: {d}, Time: {d:.2} ns/op\n", .{ v3_result, v3_golden_ns });
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // RESULTS SUMMARY
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("RESULTS SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("\n", .{});
    
    try stdout.print("  ┌─────────────────────────────────────────────────────────────────────────┐\n", .{});
    try stdout.print("  │ TEST              │ V1 (ns)  │ V2 (ns)  │ V3 (ns)  │ V3 vs V1 │ V3 vs V2│\n", .{});
    try stdout.print("  ├─────────────────────────────────────────────────────────────────────────┤\n", .{});
    try stdout.print("  │ TRINITY MUL (x*3) │ {d:8.2} │ {d:8.2} │ {d:8.2} │ {d:7.2}x │ {d:7.2}x │\n", .{
        v1_ns, v2_ns, v3_ns, v1_ns / v3_ns, v2_ns / v3_ns,
    });
    try stdout.print("  │ SQUARE (x*x)      │ {d:8.2} │ {d:8.2} │ {d:8.2} │ {d:7.2}x │ {d:7.2}x │\n", .{
        v1_sq_ns, v2_sq_ns, v3_sq_ns, v1_sq_ns / v3_sq_ns, v2_sq_ns / v3_sq_ns,
    });
    try stdout.print("  │ GOLDEN IDENTITY   │      N/A │ {d:8.2} │ {d:8.2} │     N/A  │ {d:7.2}x │\n", .{
        v2_golden_ns, v3_golden_ns, v2_golden_ns / v3_golden_ns,
    });
    try stdout.print("  └─────────────────────────────────────────────────────────────────────────┘\n", .{});
    try stdout.print("\n", .{});
    
    try stdout.print("  KEY IMPROVEMENTS IN V3:\n", .{});
    try stdout.print("    ✅ Inline constants (no immediate reads for common values)\n", .{});
    try stdout.print("    ✅ 1-byte immediates (vs 8-byte in V2)\n", .{});
    try stdout.print("    ✅ Specialized opcodes (SQUARE, CUBE, MUL2, MUL3)\n", .{});
    try stdout.print("\n", .{});
    
    try stdout.print("  Sacred Constants Verification:\n", .{});
    try stdout.print("    φ = {d:.15}\n", .{v3.PHI});
    try stdout.print("    φ² + 1/φ² = {d:.15} (should be 3.0)\n", .{
        v3.PHI_SQ + 1.0 / v3.PHI_SQ,
    });
    try stdout.print("    TRINITY = {d}\n", .{v3.TRINITY});
    try stdout.print("    PHOENIX = {d} = 3³ × 37 = {d}\n", .{
        v3.PHOENIX,
        @as(i64, 27) * 37,
    });
    try stdout.print("\n", .{});
    
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲒⲄⲖⲀ V3 BENCHMARK COMPLETE\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}
