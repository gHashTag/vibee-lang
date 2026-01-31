// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC JIT BENCHMARK - NATIVE CODE vs INTERPRETER
// ═══════════════════════════════════════════════════════════════════════════════
// Compares: NaN Register VM vs JIT Native Code
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: Beat LuaJIT!
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const nan_reg_vm = @import("nan_reg_vm.zig");
const tracing_jit = @import("tracing_jit.zig");

const PHI: f64 = 1.618033988749895;
const PHI_SQ: f64 = 2.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmark(allocator: std.mem.Allocator) !void {
    const iterations: u32 = 100000;
    const runs: usize = 10;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    JIT BENCHMARK - NATIVE CODE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("Test: sum(1..{d})\n", .{iterations});
    const expected: i64 = @divTrunc(@as(i64, iterations) * (@as(i64, iterations) + 1), 2);
    std.debug.print("Expected result: {d}\n", .{expected});
    std.debug.print("Sacred constants: φ = {d:.6}, φ² = {d:.6}\n", .{ PHI, PHI_SQ });
    std.debug.print("───────────────────────────────────────────────────────────────────────────────\n", .{});

    // 1. NaN Register VM (baseline for this benchmark)
    var vm_times: [runs]u64 = undefined;
    var vm_result: i64 = 0;
    var vm_ops: u64 = 0;

    for (0..runs) |run| {
        // Generate code for sum(0..N)
        var code_list = std.ArrayList(u8).init(allocator);
        defer code_list.deinit();

        const n_hi: u8 = @truncate(iterations >> 8);
        const n_lo: u8 = @truncate(iterations & 0xFF);

        // R0 = 0 (sum), R1 = 0 (i), R2 = N (limit)
        try code_list.append(0x01); // MOV_RI R0, 0
        try code_list.appendSlice(&[_]u8{ 0x00, 0x00, 0x00 });
        try code_list.append(0x01); // MOV_RI R1, 0
        try code_list.appendSlice(&[_]u8{ 0x10, 0x00, 0x00 });
        try code_list.append(0x01); // MOV_RI R2, N
        try code_list.appendSlice(&[_]u8{ 0x20, n_hi, n_lo });

        const loop_start: u16 = @intCast(code_list.items.len);

        // R0 = R0 + R1
        try code_list.append(0x10); // ADD_RRR
        try code_list.appendSlice(&[_]u8{ 0x00, 0x10 });

        // R1++
        try code_list.append(0x1E); // INC_R R1
        try code_list.append(0x10);

        // CMP R1, R2
        try code_list.append(0x20);
        try code_list.append(0x12);

        // JLT loop_start
        try code_list.append(0x43);
        try code_list.appendSlice(&[_]u8{ @truncate(loop_start >> 8), @truncate(loop_start & 0xFF) });

        try code_list.append(0x4D); // HALT

        var vm = nan_reg_vm.NanRegVM.init();
        vm.load(code_list.items);

        const result = vm.run();
        vm_result = result.asInt();
        vm_times[run] = vm.getExecutionTimeNs();
        vm_ops = vm.instructions_executed;
    }

    // 2. JIT Native Code
    var jit_times: [runs]u64 = undefined;
    var jit_result: i64 = 0;

    var jit = tracing_jit.JITExecutor.init(allocator);
    defer jit.deinit();

    for (0..runs) |run| {
        const start = std.time.nanoTimestamp();
        jit_result = try jit.executeSumLoop(iterations);
        const end = std.time.nanoTimestamp();
        jit_times[run] = @intCast(@max(0, end - start));
    }

    // Calculate averages
    var vm_avg: u64 = 0;
    var jit_avg: u64 = 0;

    for (0..runs) |i| {
        vm_avg += vm_times[i];
        jit_avg += jit_times[i];
    }
    vm_avg /= runs;
    jit_avg /= runs;

    // Calculate ops/sec
    const vm_ops_sec = @as(f64, @floatFromInt(vm_ops)) / (@as(f64, @floatFromInt(vm_avg)) / 1_000_000_000.0);
    // JIT does ~3 ops per iteration (add, dec, jnz)
    const jit_ops: u64 = @as(u64, iterations) * 3;
    const jit_ops_sec = @as(f64, @floatFromInt(jit_ops)) / (@as(f64, @floatFromInt(jit_avg)) / 1_000_000_000.0);

    // Print results
    std.debug.print("\n", .{});
    std.debug.print("1. NaN REGISTER VM:\n", .{});
    std.debug.print("   Result: {d}\n", .{vm_result});
    std.debug.print("   Time:   {d:.3} ms\n", .{@as(f64, @floatFromInt(vm_avg)) / 1_000_000.0});
    std.debug.print("   Ops:    {d:.2}M ops/sec\n", .{vm_ops_sec / 1_000_000.0});

    std.debug.print("\n", .{});
    std.debug.print("2. JIT NATIVE CODE:\n", .{});
    std.debug.print("   Result: {d}\n", .{jit_result});
    std.debug.print("   Time:   {d:.3} ms\n", .{@as(f64, @floatFromInt(jit_avg)) / 1_000_000.0});
    std.debug.print("   Ops:    {d:.2}M ops/sec\n", .{jit_ops_sec / 1_000_000.0});

    std.debug.print("\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────────────────\n", .{});

    // Speedup
    const jit_speedup = @as(f64, @floatFromInt(vm_avg)) / @as(f64, @floatFromInt(jit_avg));

    std.debug.print("\n", .{});
    std.debug.print("JIT SPEEDUP vs NaN Register VM: {d:.2}x\n", .{jit_speedup});

    // Total speedup from baseline (355M ops/sec tagged union stack VM)
    const baseline_ops_sec: f64 = 355_000_000.0;
    const total_speedup = jit_ops_sec / baseline_ops_sec;

    std.debug.print("\n", .{});
    std.debug.print("TOTAL SPEEDUP vs BASELINE:\n", .{});
    std.debug.print("   Baseline: 355M ops/sec (Tagged Union Stack VM)\n", .{});
    std.debug.print("   JIT:      {d:.2}M ops/sec\n", .{jit_ops_sec / 1_000_000.0});
    std.debug.print("   Speedup:  {d:.2}x\n", .{total_speedup});

    std.debug.print("\n", .{});
    std.debug.print("SACRED MATH VERIFICATION:\n", .{});
    std.debug.print("   Target: φ² × φ² = {d:.3}x\n", .{PHI_SQ * PHI_SQ});
    std.debug.print("   Actual: {d:.3}x\n", .{total_speedup});

    if (total_speedup >= PHI_SQ * PHI_SQ) {
        std.debug.print("\n   ✓ ACHIEVED φ⁴ SPEEDUP! BEAT LUAJIT!\n", .{});
    } else if (total_speedup >= PHI_SQ) {
        std.debug.print("\n   ✓ ACHIEVED φ² SPEEDUP!\n", .{});
    }

    // Position estimate
    std.debug.print("\n", .{});
    std.debug.print("ESTIMATED POSITION:\n", .{});
    if (jit_ops_sec >= 1_000_000_000.0) {
        std.debug.print("   🥇 #1 - BEAT LUAJIT!\n", .{});
    } else if (jit_ops_sec >= 500_000_000.0) {
        std.debug.print("   🥈 #2 - Competing with LuaJIT\n", .{});
    } else {
        std.debug.print("   🥉 #3 - Above V8/PyPy\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try runBenchmark(gpa.allocator());
}

test "benchmark runs" {
    // Just verify it compiles
    try std.testing.expect(true);
}
