// ═══════════════════════════════════════════════════════════════════════════════
// IMPROVEMENTS BENCHMARK - V1 vs V2 COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════
// GENERATED FROM: ⲩⲗⲩⲭⲥⲉⲛⲓⲁ_ⲩ7.tri
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const superinstructions_v1 = @import("superinstructions.zig");
const superinstructions_v2 = @import("superinstructions_v2.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const ITERATIONS: usize = 100000;
const WARMUP: usize = 1000;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲒⲄⲖⲀ IMPROVEMENTS BENCHMARK - V1 vs V2\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q\n", .{});
    try stdout.print("ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = {d:.6}\n", .{
        superinstructions_v2.PHI_SQ + 1.0 / superinstructions_v2.PHI_SQ,
    });
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // BENCHMARK 1: V1 Superinstructions
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("BENCHMARK 1: Superinstructions V1\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    var vm_v1 = superinstructions_v1.SuperVM.init(allocator);
    defer vm_v1.deinit();
    
    // V1 code: PUSH 100, PUSH 200, ADD, DUP, MUL, HALT
    const code_v1 = [_]u8{
        @intFromEnum(superinstructions_v1.SuperOpcode.PUSH), 100, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(superinstructions_v1.SuperOpcode.PUSH), 200, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(superinstructions_v1.SuperOpcode.ADD),
        @intFromEnum(superinstructions_v1.SuperOpcode.DUP),
        @intFromEnum(superinstructions_v1.SuperOpcode.MUL),
        @intFromEnum(superinstructions_v1.SuperOpcode.HALT),
    };
    
    // Warmup
    for (0..WARMUP) |_| {
        vm_v1.load(&code_v1);
        _ = vm_v1.run() catch 0;
    }
    
    var timer = try std.time.Timer.start();
    
    var v1_result: u64 = 0;
    for (0..ITERATIONS) |_| {
        vm_v1.load(&code_v1);
        v1_result = vm_v1.run() catch 0;
    }
    
    const v1_time = timer.read();
    const v1_ns_per_op = @as(f64, @floatFromInt(v1_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  Opcodes: PUSH, PUSH, ADD, DUP, MUL, HALT (6 dispatches)\n", .{});
    try stdout.print("  Result: {d}\n", .{v1_result});
    try stdout.print("  Time: {d:.3} ms ({d} iterations)\n", .{
        @as(f64, @floatFromInt(v1_time)) / 1_000_000.0,
        ITERATIONS,
    });
    try stdout.print("  Per-op: {d:.2} ns\n", .{v1_ns_per_op});
    try stdout.print("  Dispatches saved: {d}\n", .{vm_v1.dispatches_saved});
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // BENCHMARK 2: V2 Superinstructions (equivalent)
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("BENCHMARK 2: Superinstructions V2 (equivalent code)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    var vm_v2 = superinstructions_v2.SuperVMV2.init(allocator);
    defer vm_v2.deinit();
    
    // V2 code: LOAD2_ADD(100, 200), DUP_MUL, HALT (uses superinstructions)
    const code_v2 = [_]u8{
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.LOAD2_ADD),
    } ++ @as([8]u8, @bitCast(@as(i64, 100))) ++
        @as([8]u8, @bitCast(@as(i64, 200))) ++ [_]u8{
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.DUP_MUL),
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.HALT),
    };
    
    // Warmup
    for (0..WARMUP) |_| {
        vm_v2.load(&code_v2);
        _ = vm_v2.run() catch 0;
    }
    
    timer.reset();
    
    var v2_result: i64 = 0;
    for (0..ITERATIONS) |_| {
        vm_v2.load(&code_v2);
        v2_result = vm_v2.run() catch 0;
    }
    
    const v2_time = timer.read();
    const v2_ns_per_op = @as(f64, @floatFromInt(v2_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  Opcodes: LOAD2_ADD, DUP_MUL, HALT (3 dispatches)\n", .{});
    try stdout.print("  Result: {d}\n", .{v2_result});
    try stdout.print("  Time: {d:.3} ms ({d} iterations)\n", .{
        @as(f64, @floatFromInt(v2_time)) / 1_000_000.0,
        ITERATIONS,
    });
    try stdout.print("  Per-op: {d:.2} ns\n", .{v2_ns_per_op});
    try stdout.print("  Dispatches saved: {d}\n", .{vm_v2.dispatches_saved});
    try stdout.print("  Efficiency: {d:.1}%\n", .{vm_v2.getEfficiency() * 100.0});
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // BENCHMARK 3: V2 NEW Superinstructions
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("BENCHMARK 3: V2 NEW Superinstructions (TRINITY, PHI, PHOENIX)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    var vm_v2_new = superinstructions_v2.SuperVMV2.init(allocator);
    defer vm_v2_new.deinit();
    
    // V2 NEW code: PUSH 100, TRINITY_MUL3, PHI_GROW, HALT
    const code_v2_new = [_]u8{
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.PUSH),
    } ++ @as([8]u8, @bitCast(@as(i64, 100))) ++ [_]u8{
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.TRINITY_MUL3),
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.PHI_GROW),
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.HALT),
    };
    
    // Warmup
    for (0..WARMUP) |_| {
        vm_v2_new.load(&code_v2_new);
        _ = vm_v2_new.run() catch 0;
    }
    
    timer.reset();
    
    var v2_new_result: i64 = 0;
    for (0..ITERATIONS) |_| {
        vm_v2_new.load(&code_v2_new);
        v2_new_result = vm_v2_new.run() catch 0;
    }
    
    const v2_new_time = timer.read();
    const v2_new_ns_per_op = @as(f64, @floatFromInt(v2_new_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  Opcodes: PUSH, TRINITY_MUL3, PHI_GROW, HALT (4 dispatches)\n", .{});
    try stdout.print("  Computation: 100 * 3 * φ = {d}\n", .{v2_new_result});
    try stdout.print("  Time: {d:.3} ms ({d} iterations)\n", .{
        @as(f64, @floatFromInt(v2_new_time)) / 1_000_000.0,
        ITERATIONS,
    });
    try stdout.print("  Per-op: {d:.2} ns\n", .{v2_new_ns_per_op});
    try stdout.print("  Dispatches saved: {d}\n", .{vm_v2_new.dispatches_saved});
    try stdout.print("  Efficiency: {d:.1}%\n", .{vm_v2_new.getEfficiency() * 100.0});
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // BENCHMARK 4: GOLDEN_IDENTITY Superinstruction
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("BENCHMARK 4: GOLDEN_IDENTITY (φ² + 1/φ² = 3)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    var vm_golden = superinstructions_v2.SuperVMV2.init(allocator);
    defer vm_golden.deinit();
    
    const code_golden = [_]u8{
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.GOLDEN_IDENTITY),
        @intFromEnum(superinstructions_v2.SuperOpcodeV2.HALT),
    };
    
    // Warmup
    for (0..WARMUP) |_| {
        vm_golden.load(&code_golden);
        _ = vm_golden.run() catch 0;
    }
    
    timer.reset();
    
    var golden_result: i64 = 0;
    for (0..ITERATIONS) |_| {
        vm_golden.load(&code_golden);
        golden_result = vm_golden.run() catch 0;
    }
    
    const golden_time = timer.read();
    const golden_ns_per_op = @as(f64, @floatFromInt(golden_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    try stdout.print("  Opcodes: GOLDEN_IDENTITY, HALT (2 dispatches)\n", .{});
    try stdout.print("  Result: {d} (φ² + 1/φ² = 3)\n", .{golden_result});
    try stdout.print("  Time: {d:.3} ms ({d} iterations)\n", .{
        @as(f64, @floatFromInt(golden_time)) / 1_000_000.0,
        ITERATIONS,
    });
    try stdout.print("  Per-op: {d:.2} ns\n", .{golden_ns_per_op});
    try stdout.print("  Dispatches saved: {d} (6 ops → 1 op)\n", .{vm_golden.dispatches_saved});
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // RESULTS SUMMARY
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("RESULTS SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("\n", .{});
    
    const speedup_v2 = v1_ns_per_op / v2_ns_per_op;
    const speedup_v2_new = v1_ns_per_op / v2_new_ns_per_op;
    
    try stdout.print("  ┌─────────────────────────────────────────────────────────────────────────┐\n", .{});
    try stdout.print("  │ VERSION              │ TIME (ns/op) │ SPEEDUP │ DISPATCHES SAVED      │\n", .{});
    try stdout.print("  ├─────────────────────────────────────────────────────────────────────────┤\n", .{});
    try stdout.print("  │ V1 (baseline)        │ {d:12.2} │   1.00x │ {d:6}                │\n", .{ v1_ns_per_op, vm_v1.dispatches_saved });
    try stdout.print("  │ V2 (equivalent)      │ {d:12.2} │ {d:6.2}x │ {d:6}                │\n", .{ v2_ns_per_op, speedup_v2, vm_v2.dispatches_saved });
    try stdout.print("  │ V2 NEW (TRINITY+PHI) │ {d:12.2} │ {d:6.2}x │ {d:6}                │\n", .{ v2_new_ns_per_op, speedup_v2_new, vm_v2_new.dispatches_saved });
    try stdout.print("  │ GOLDEN_IDENTITY      │ {d:12.2} │    N/A  │ {d:6}                │\n", .{ golden_ns_per_op, vm_golden.dispatches_saved });
    try stdout.print("  └─────────────────────────────────────────────────────────────────────────┘\n", .{});
    try stdout.print("\n", .{});
    
    try stdout.print("  Sacred Constants Verification:\n", .{});
    try stdout.print("    φ = {d:.15}\n", .{superinstructions_v2.PHI});
    try stdout.print("    φ² + 1/φ² = {d:.15} (should be 3.0)\n", .{
        superinstructions_v2.PHI_SQ + 1.0 / superinstructions_v2.PHI_SQ,
    });
    try stdout.print("    TRINITY = {d}\n", .{superinstructions_v2.TRINITY});
    try stdout.print("    TRINITY_PRIME = {d}\n", .{superinstructions_v2.TRINITY_PRIME});
    try stdout.print("    PHOENIX = {d} = 3³ × 37 = {d}\n", .{
        superinstructions_v2.PHOENIX,
        @as(u64, 27) * 37,
    });
    try stdout.print("\n", .{});
    
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲒⲄⲖⲀ IMPROVEMENTS BENCHMARK COMPLETE\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}
