// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC REGISTER VM BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════
// Compares stack-based VM vs register-based VM performance
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vm_runtime = @import("vm_runtime.zig");
const reg_vm = @import("reg_vm.zig");
const reg_bytecode = @import("reg_bytecode.zig");
const bytecode = @import("bytecode.zig");
const Value = bytecode.Value;
const Opcode = bytecode.Opcode;
const RegOpcode = reg_bytecode.RegOpcode;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: SUM 1 TO N
// ═══════════════════════════════════════════════════════════════════════════════

/// Stack-based bytecode for: sum = 0; for i = 0 to N { sum += i }
fn makeStackSumCode(n: i64, allocator: std.mem.Allocator) !struct { code: []u8, constants: []Value } {
    var code = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);

    // Constants
    try constants.append(.{ .int_val = 0 }); // idx 0: 0
    try constants.append(.{ .int_val = 1 }); // idx 1: 1
    try constants.append(.{ .int_val = n }); // idx 2: N

    // sum = 0 (local 0)
    try code.append(@intFromEnum(Opcode.PUSH_CONST));
    try code.append(0x00);
    try code.append(0x00); // const 0
    try code.append(@intFromEnum(Opcode.STORE_LOCAL));
    try code.append(0x00);
    try code.append(0x00); // local 0 = sum

    // i = 0 (local 1)
    try code.append(@intFromEnum(Opcode.PUSH_CONST));
    try code.append(0x00);
    try code.append(0x00); // const 0
    try code.append(@intFromEnum(Opcode.STORE_LOCAL));
    try code.append(0x00);
    try code.append(0x01); // local 1 = i

    // loop_start (offset 12):
    const loop_start: u16 = @intCast(code.items.len);

    // sum += i
    try code.append(@intFromEnum(Opcode.LOAD_LOCAL));
    try code.append(0x00);
    try code.append(0x00); // push sum
    try code.append(@intFromEnum(Opcode.LOAD_LOCAL));
    try code.append(0x00);
    try code.append(0x01); // push i
    try code.append(@intFromEnum(Opcode.ADD)); // sum + i
    try code.append(@intFromEnum(Opcode.STORE_LOCAL));
    try code.append(0x00);
    try code.append(0x00); // sum = result

    // i += 1
    try code.append(@intFromEnum(Opcode.LOAD_LOCAL));
    try code.append(0x00);
    try code.append(0x01); // push i
    try code.append(@intFromEnum(Opcode.PUSH_CONST));
    try code.append(0x00);
    try code.append(0x01); // push 1
    try code.append(@intFromEnum(Opcode.ADD)); // i + 1
    try code.append(@intFromEnum(Opcode.STORE_LOCAL));
    try code.append(0x00);
    try code.append(0x01); // i = result

    // if i < N goto loop_start
    try code.append(@intFromEnum(Opcode.LOAD_LOCAL));
    try code.append(0x00);
    try code.append(0x01); // push i
    try code.append(@intFromEnum(Opcode.PUSH_CONST));
    try code.append(0x00);
    try code.append(0x02); // push N
    try code.append(@intFromEnum(Opcode.LT)); // i < N
    try code.append(@intFromEnum(Opcode.JNZ));
    try code.append(@truncate(loop_start >> 8));
    try code.append(@truncate(loop_start & 0xFF));

    // push result
    try code.append(@intFromEnum(Opcode.LOAD_LOCAL));
    try code.append(0x00);
    try code.append(0x00); // push sum

    try code.append(@intFromEnum(Opcode.HALT));

    return .{
        .code = try code.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

/// Register-based bytecode for: sum = 0; for i = 0 to N { sum += i }
fn makeRegSumCode(n: i64, allocator: std.mem.Allocator) !struct { code: []u8, constants: []Value } {
    var code = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);
    _ = &constants; // Register VM doesn't need constants for this test

    // R0 = sum = 0
    try code.append(@intFromEnum(RegOpcode.MOV_RI));
    try code.append(0x00); // R0
    try code.append(0x00);
    try code.append(0x00); // imm = 0

    // R1 = i = 0
    try code.append(@intFromEnum(RegOpcode.MOV_RI));
    try code.append(0x10); // R1
    try code.append(0x00);
    try code.append(0x00); // imm = 0

    // R2 = N
    const n_lo: u8 = @truncate(@as(u64, @bitCast(n)) & 0xFF);
    const n_hi: u8 = @truncate((@as(u64, @bitCast(n)) >> 8) & 0xFF);
    try code.append(@intFromEnum(RegOpcode.MOV_RI));
    try code.append(0x20); // R2
    try code.append(n_lo);
    try code.append(n_hi); // imm = N

    // loop_start (offset 12):
    const loop_start: u16 = @intCast(code.items.len);

    // R0 = R0 + R1 (sum += i)
    try code.append(@intFromEnum(RegOpcode.ADD_RRR));
    try code.append(0x00); // R0, R0
    try code.append(0x10); // R1

    // R1++ (i++)
    try code.append(@intFromEnum(RegOpcode.INC_R));
    try code.append(0x10); // R1

    // CMP R1, R2
    try code.append(@intFromEnum(RegOpcode.CMP_RR));
    try code.append(0x12); // R1, R2

    // JLT loop_start
    try code.append(@intFromEnum(RegOpcode.JLT));
    try code.append(@truncate(loop_start & 0xFF));
    try code.append(@truncate(loop_start >> 8));

    // HALT (R0 contains result)
    try code.append(@intFromEnum(RegOpcode.HALT));

    return .{
        .code = try code.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmark(allocator: std.mem.Allocator) !void {
    const iterations: i64 = 10000;
    const runs: usize = 5;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    REGISTER VM BENCHMARK\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("Test: sum(0..{d})\n", .{iterations});
    std.debug.print("Expected result: {d}\n", .{@divTrunc(iterations * (iterations - 1), 2)});
    std.debug.print("───────────────────────────────────────────────────────────────────────────────\n", .{});

    // Stack-based VM benchmark
    var stack_times: [runs]u64 = undefined;
    var stack_result: i64 = 0;

    for (0..runs) |run| {
        const stack_prog = try makeStackSumCode(iterations, allocator);
        defer allocator.free(stack_prog.code);
        defer allocator.free(stack_prog.constants);

        var stack_vm = try vm_runtime.VM.init(allocator);
        defer stack_vm.deinit();

        stack_vm.code = stack_prog.code;
        stack_vm.constants = stack_prog.constants;

        const result = try stack_vm.runFast();
        stack_result = result.int_val;
        stack_times[run] = stack_vm.execution_time_ns;
    }

    // Register-based VM benchmark
    var reg_times: [runs]u64 = undefined;
    var reg_result: i64 = 0;

    for (0..runs) |run| {
        const reg_prog = try makeRegSumCode(iterations, allocator);
        defer allocator.free(reg_prog.code);
        defer allocator.free(reg_prog.constants);

        var register_vm = try reg_vm.RegVM.init(allocator);
        defer register_vm.deinit();

        register_vm.load(reg_prog.code, reg_prog.constants);

        const result = try register_vm.run();
        reg_result = result.int_val;
        reg_times[run] = register_vm.getExecutionTimeNs();
    }

    // Calculate averages
    var stack_avg: u64 = 0;
    var reg_avg: u64 = 0;
    for (0..runs) |i| {
        stack_avg += stack_times[i];
        reg_avg += reg_times[i];
    }
    stack_avg /= runs;
    reg_avg /= runs;

    // Print results
    std.debug.print("\n", .{});
    std.debug.print("STACK-BASED VM:\n", .{});
    std.debug.print("  Result: {d}\n", .{stack_result});
    std.debug.print("  Time:   {d} ns ({d:.2} ms)\n", .{ stack_avg, @as(f64, @floatFromInt(stack_avg)) / 1_000_000.0 });

    std.debug.print("\n", .{});
    std.debug.print("REGISTER-BASED VM:\n", .{});
    std.debug.print("  Result: {d}\n", .{reg_result});
    std.debug.print("  Time:   {d} ns ({d:.2} ms)\n", .{ reg_avg, @as(f64, @floatFromInt(reg_avg)) / 1_000_000.0 });

    std.debug.print("\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────────────────\n", .{});

    if (reg_avg > 0 and stack_avg > 0) {
        const speedup = @as(f64, @floatFromInt(stack_avg)) / @as(f64, @floatFromInt(reg_avg));
        std.debug.print("SPEEDUP: {d:.2}x\n", .{speedup});

        if (speedup > 1.0) {
            std.debug.print("Register VM is {d:.1}% FASTER\n", .{(speedup - 1.0) * 100.0});
        } else {
            std.debug.print("Stack VM is {d:.1}% faster\n", .{(1.0 / speedup - 1.0) * 100.0});
        }
    }

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runBenchmark(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "stack sum code generation" {
    const prog = try makeStackSumCode(10, std.testing.allocator);
    defer std.testing.allocator.free(prog.code);
    defer std.testing.allocator.free(prog.constants);

    try std.testing.expect(prog.code.len > 0);
    try std.testing.expectEqual(@as(usize, 3), prog.constants.len);
}

test "register sum code generation" {
    const prog = try makeRegSumCode(10, std.testing.allocator);
    defer std.testing.allocator.free(prog.code);
    defer std.testing.allocator.free(prog.constants);

    try std.testing.expect(prog.code.len > 0);
}

test "stack vm sum correctness" {
    const prog = try makeStackSumCode(100, std.testing.allocator);
    defer std.testing.allocator.free(prog.code);
    defer std.testing.allocator.free(prog.constants);

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit();

    vm.code = prog.code;
    vm.constants = prog.constants;

    const result = try vm.runFast();
    // sum(0..99) = 4950
    try std.testing.expectEqual(@as(i64, 4950), result.int_val);
}

test "register vm sum correctness" {
    const prog = try makeRegSumCode(100, std.testing.allocator);
    defer std.testing.allocator.free(prog.code);
    defer std.testing.allocator.free(prog.constants);

    var vm = try reg_vm.RegVM.init(std.testing.allocator);
    defer vm.deinit();

    vm.load(prog.code, prog.constants);

    const result = try vm.run();
    // sum(0..99) = 4950
    try std.testing.expectEqual(@as(i64, 4950), result.int_val);
}
