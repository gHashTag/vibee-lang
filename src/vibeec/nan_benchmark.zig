// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC NaN BOXING BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════
// Compares: Tagged Union VM vs NaN-boxed VM vs NaN-boxed Register VM
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const nan_vm = @import("nan_vm.zig");
const nan_reg_vm = @import("nan_reg_vm.zig");
const vm_runtime = @import("vm_runtime.zig");
const bytecode = @import("bytecode.zig");

const PHI: f64 = 1.618033988749895;
const PHI_SQ: f64 = 2.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CODE GENERATORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate stack VM code for sum(0..N)
fn makeStackCode(n: i64, allocator: std.mem.Allocator) !struct { code: []u8, constants: []bytecode.Value } {
    var code = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(bytecode.Value).init(allocator);

    try constants.append(.{ .int_val = 0 });
    try constants.append(.{ .int_val = 1 });
    try constants.append(.{ .int_val = n });

    // sum = 0
    try code.append(@intFromEnum(bytecode.Opcode.PUSH_CONST));
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(@intFromEnum(bytecode.Opcode.STORE_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });

    // i = 0
    try code.append(@intFromEnum(bytecode.Opcode.PUSH_CONST));
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(@intFromEnum(bytecode.Opcode.STORE_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });

    const loop_start: u16 = @intCast(code.items.len);

    // sum += i
    try code.append(@intFromEnum(bytecode.Opcode.LOAD_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(@intFromEnum(bytecode.Opcode.LOAD_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(@intFromEnum(bytecode.Opcode.ADD));
    try code.append(@intFromEnum(bytecode.Opcode.STORE_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });

    // i++
    try code.append(@intFromEnum(bytecode.Opcode.LOAD_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(@intFromEnum(bytecode.Opcode.PUSH_CONST));
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(@intFromEnum(bytecode.Opcode.ADD));
    try code.append(@intFromEnum(bytecode.Opcode.STORE_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });

    // if i < N goto loop
    try code.append(@intFromEnum(bytecode.Opcode.LOAD_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(@intFromEnum(bytecode.Opcode.PUSH_CONST));
    try code.appendSlice(&[_]u8{ 0x00, 0x02 });
    try code.append(@intFromEnum(bytecode.Opcode.LT));
    try code.append(@intFromEnum(bytecode.Opcode.JNZ));
    try code.appendSlice(&[_]u8{ @truncate(loop_start >> 8), @truncate(loop_start & 0xFF) });

    // push result
    try code.append(@intFromEnum(bytecode.Opcode.LOAD_LOCAL));
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(@intFromEnum(bytecode.Opcode.HALT));

    return .{
        .code = try code.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

/// Generate NaN-boxed stack VM code for sum(0..N)
fn makeNanStackCode(n: i64, allocator: std.mem.Allocator) ![]u8 {
    var code = std.ArrayList(u8).init(allocator);

    const n_hi: u8 = @truncate(@as(u64, @bitCast(n)) >> 8);
    const n_lo: u8 = @truncate(@as(u64, @bitCast(n)) & 0xFF);

    // sum = 0 (local 0)
    try code.append(0x01); // PUSH_INT
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(0x51); // STORE_LOCAL
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });

    // i = 0 (local 1)
    try code.append(0x01);
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(0x51);
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });

    const loop_start: u16 = @intCast(code.items.len);

    // sum += i
    try code.append(0x50); // LOAD_LOCAL 0
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(0x50); // LOAD_LOCAL 1
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(0x10); // ADD
    try code.append(0x51); // STORE_LOCAL 0
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });

    // i++
    try code.append(0x50);
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(0x01);
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(0x10);
    try code.append(0x51);
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });

    // if i < N goto loop
    try code.append(0x50);
    try code.appendSlice(&[_]u8{ 0x00, 0x01 });
    try code.append(0x01);
    try code.appendSlice(&[_]u8{ n_hi, n_lo });
    try code.append(0x20); // LT
    try code.append(0x42); // JNZ
    try code.appendSlice(&[_]u8{ @truncate(loop_start >> 8), @truncate(loop_start & 0xFF) });

    // push result
    try code.append(0x50);
    try code.appendSlice(&[_]u8{ 0x00, 0x00 });
    try code.append(0x4D); // HALT

    return try code.toOwnedSlice();
}

/// Generate NaN-boxed register VM code for sum(0..N)
fn makeNanRegCode(n: i64, allocator: std.mem.Allocator) ![]u8 {
    var code = std.ArrayList(u8).init(allocator);

    const n_hi: u8 = @truncate(@as(u64, @bitCast(n)) >> 8);
    const n_lo: u8 = @truncate(@as(u64, @bitCast(n)) & 0xFF);

    // R0 = 0 (sum), R1 = 0 (i), R2 = N (limit)
    try code.append(0x01); // MOV_RI R0, 0
    try code.appendSlice(&[_]u8{ 0x00, 0x00, 0x00 });
    try code.append(0x01); // MOV_RI R1, 0
    try code.appendSlice(&[_]u8{ 0x10, 0x00, 0x00 });
    try code.append(0x01); // MOV_RI R2, N
    try code.appendSlice(&[_]u8{ 0x20, n_hi, n_lo });

    const loop_start: u16 = @intCast(code.items.len);

    // R0 = R0 + R1
    try code.append(0x10); // ADD_RRR
    try code.appendSlice(&[_]u8{ 0x00, 0x10 }); // R0, R0, R1

    // R1++
    try code.append(0x1E); // INC_R R1
    try code.append(0x10);

    // CMP R1, R2
    try code.append(0x20);
    try code.append(0x12);

    // JLT loop_start
    try code.append(0x43);
    try code.appendSlice(&[_]u8{ @truncate(loop_start >> 8), @truncate(loop_start & 0xFF) });

    try code.append(0x4D); // HALT

    return try code.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmark(allocator: std.mem.Allocator) !void {
    const iterations: i64 = 10000; // Reduced to avoid 45-bit overflow
    const runs: usize = 5;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    NaN BOXING BENCHMARK\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("Test: sum(0..{d})\n", .{iterations});
    std.debug.print("Expected result: {d}\n", .{@divTrunc(iterations * (iterations - 1), 2)});
    std.debug.print("Sacred constants: φ = {d:.6}, φ² = {d:.6}\n", .{ PHI, PHI_SQ });
    std.debug.print("───────────────────────────────────────────────────────────────────────────────\n", .{});

    // 1. Tagged Union Stack VM (baseline)
    var stack_times: [runs]u64 = undefined;
    var stack_result: i64 = 0;
    var stack_ops: u64 = 0;

    for (0..runs) |run| {
        const prog = try makeStackCode(iterations, allocator);
        defer allocator.free(prog.code);
        defer allocator.free(prog.constants);

        var vm = try vm_runtime.VM.init(allocator);
        defer vm.deinit();

        vm.code = prog.code;
        vm.constants = prog.constants;

        const result = try vm.runFast();
        stack_result = result.int_val;
        stack_times[run] = vm.execution_time_ns;
        stack_ops = vm.instructions_executed;
    }

    // 2. NaN-boxed Stack VM
    var nan_stack_times: [runs]u64 = undefined;
    var nan_stack_result: i64 = 0;
    var nan_stack_ops: u64 = 0;

    for (0..runs) |run| {
        const code = try makeNanStackCode(iterations, allocator);
        defer allocator.free(code);

        var vm = nan_vm.NanVM.init();
        vm.load(code);

        const result = vm.run();
        nan_stack_result = result.asInt();
        nan_stack_times[run] = vm.getExecutionTimeNs();
        nan_stack_ops = vm.instructions_executed;
    }

    // 3. NaN-boxed Register VM
    var nan_reg_times: [runs]u64 = undefined;
    var nan_reg_result: i64 = 0;
    var nan_reg_ops: u64 = 0;

    for (0..runs) |run| {
        const code = try makeNanRegCode(iterations, allocator);
        defer allocator.free(code);

        var vm = nan_reg_vm.NanRegVM.init();
        vm.load(code);

        const result = vm.run();
        nan_reg_result = result.asInt();
        nan_reg_times[run] = vm.getExecutionTimeNs();
        nan_reg_ops = vm.instructions_executed;
    }

    // Calculate averages
    var stack_avg: u64 = 0;
    var nan_stack_avg: u64 = 0;
    var nan_reg_avg: u64 = 0;

    for (0..runs) |i| {
        stack_avg += stack_times[i];
        nan_stack_avg += nan_stack_times[i];
        nan_reg_avg += nan_reg_times[i];
    }
    stack_avg /= runs;
    nan_stack_avg /= runs;
    nan_reg_avg /= runs;

    // Calculate ops/sec
    const stack_ops_sec = @as(f64, @floatFromInt(stack_ops)) / (@as(f64, @floatFromInt(stack_avg)) / 1_000_000_000.0);
    const nan_stack_ops_sec = @as(f64, @floatFromInt(nan_stack_ops)) / (@as(f64, @floatFromInt(nan_stack_avg)) / 1_000_000_000.0);
    const nan_reg_ops_sec = @as(f64, @floatFromInt(nan_reg_ops)) / (@as(f64, @floatFromInt(nan_reg_avg)) / 1_000_000_000.0);

    // Print results
    std.debug.print("\n", .{});
    std.debug.print("1. TAGGED UNION STACK VM (baseline):\n", .{});
    std.debug.print("   Result: {d}\n", .{stack_result});
    std.debug.print("   Time:   {d:.3} ms\n", .{@as(f64, @floatFromInt(stack_avg)) / 1_000_000.0});
    std.debug.print("   Ops:    {d:.2}M ops/sec\n", .{stack_ops_sec / 1_000_000.0});

    std.debug.print("\n", .{});
    std.debug.print("2. NaN-BOXED STACK VM:\n", .{});
    std.debug.print("   Result: {d}\n", .{nan_stack_result});
    std.debug.print("   Time:   {d:.3} ms\n", .{@as(f64, @floatFromInt(nan_stack_avg)) / 1_000_000.0});
    std.debug.print("   Ops:    {d:.2}M ops/sec\n", .{nan_stack_ops_sec / 1_000_000.0});

    std.debug.print("\n", .{});
    std.debug.print("3. NaN-BOXED REGISTER VM:\n", .{});
    std.debug.print("   Result: {d}\n", .{nan_reg_result});
    std.debug.print("   Time:   {d:.3} ms\n", .{@as(f64, @floatFromInt(nan_reg_avg)) / 1_000_000.0});
    std.debug.print("   Ops:    {d:.2}M ops/sec\n", .{nan_reg_ops_sec / 1_000_000.0});

    std.debug.print("\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────────────────\n", .{});

    // Speedups
    const nan_stack_speedup = @as(f64, @floatFromInt(stack_avg)) / @as(f64, @floatFromInt(nan_stack_avg));
    const nan_reg_speedup = @as(f64, @floatFromInt(stack_avg)) / @as(f64, @floatFromInt(nan_reg_avg));

    std.debug.print("\n", .{});
    std.debug.print("SPEEDUP vs BASELINE:\n", .{});
    std.debug.print("   NaN Stack VM:    {d:.2}x\n", .{nan_stack_speedup});
    std.debug.print("   NaN Register VM: {d:.2}x\n", .{nan_reg_speedup});

    std.debug.print("\n", .{});
    std.debug.print("SACRED MATH VERIFICATION:\n", .{});
    std.debug.print("   Expected φ speedup:  {d:.3}x\n", .{PHI});
    std.debug.print("   Expected φ² speedup: {d:.3}x\n", .{PHI_SQ});
    std.debug.print("   Actual NaN+Reg:      {d:.3}x\n", .{nan_reg_speedup});

    if (nan_reg_speedup >= PHI) {
        std.debug.print("\n   ✓ ACHIEVED φ SPEEDUP!\n", .{});
    }
    if (nan_reg_speedup >= PHI_SQ) {
        std.debug.print("   ✓ ACHIEVED φ² SPEEDUP!\n", .{});
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

test "benchmark code generation" {
    const stack_code = try makeStackCode(10, std.testing.allocator);
    defer std.testing.allocator.free(stack_code.code);
    defer std.testing.allocator.free(stack_code.constants);
    try std.testing.expect(stack_code.code.len > 0);

    const nan_stack_code = try makeNanStackCode(10, std.testing.allocator);
    defer std.testing.allocator.free(nan_stack_code);
    try std.testing.expect(nan_stack_code.len > 0);

    const nan_reg_code = try makeNanRegCode(10, std.testing.allocator);
    defer std.testing.allocator.free(nan_reg_code);
    try std.testing.expect(nan_reg_code.len > 0);
}
