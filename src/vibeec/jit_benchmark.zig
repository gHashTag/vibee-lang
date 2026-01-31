// ═══════════════════════════════════════════════════════════════════════════════
// JIT BENCHMARK - VM vs JIT Performance Comparison
// ═══════════════════════════════════════════════════════════════════════════════
// Compares execution performance between:
// - Pure interpreter (VM.run)
// - Fast interpreter (VM.runFast)
// - JIT Adapter (Mixed mode)
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const jit_adapter = @import("jit_adapter.zig");
const JITAdapter = jit_adapter.JITAdapter;
const JITMode = jit_adapter.JITMode;
const vm_runtime = @import("vm_runtime.zig");
const VM = vm_runtime.VM;
const bytecode = @import("bytecode.zig");
const Opcode = bytecode.Opcode;
const Value = bytecode.Value;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const WARMUP_ITERATIONS = 3;
const BENCHMARK_ITERATIONS = 10;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    interpreter_ns: u64,
    fast_interpreter_ns: u64,
    jit_adapter_ns: u64,
    interpreter_ops_per_sec: f64,
    fast_interpreter_ops_per_sec: f64,
    jit_adapter_ops_per_sec: f64,
    speedup_fast_vs_normal: f64,
    speedup_jit_vs_normal: f64,
    instructions_executed: u64,

    pub fn print(self: BenchmarkResult) void {
        std.debug.print("\n", .{});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("  BENCHMARK: {s}\n", .{self.name});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("  Instructions executed: {d}\n", .{self.instructions_executed});
        std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
        std.debug.print("  Interpreter:      {d:>10} ns  ({d:.2} Mops/s)\n", .{
            self.interpreter_ns,
            self.interpreter_ops_per_sec / 1_000_000.0,
        });
        std.debug.print("  Fast Interpreter: {d:>10} ns  ({d:.2} Mops/s)  {d:.2}x speedup\n", .{
            self.fast_interpreter_ns,
            self.fast_interpreter_ops_per_sec / 1_000_000.0,
            self.speedup_fast_vs_normal,
        });
        std.debug.print("  JIT Adapter:      {d:>10} ns  ({d:.2} Mops/s)  {d:.2}x speedup\n", .{
            self.jit_adapter_ns,
            self.jit_adapter_ops_per_sec / 1_000_000.0,
            self.speedup_jit_vs_normal,
        });
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn emitU16(code: *std.ArrayList(u8), val: u16) !void {
    try code.append(@intCast(val >> 8));
    try code.append(@intCast(val & 0xFF));
}

fn emitOp(code: *std.ArrayList(u8), op: Opcode) !void {
    try code.append(@intFromEnum(op));
}

fn emitOpU16(code: *std.ArrayList(u8), op: Opcode, val: u16) !void {
    try emitOp(code, op);
    try emitU16(code, val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK PROGRAMS
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate bytecode for: sum from 1 to N
fn generateSumLoop(allocator: std.mem.Allocator, n: i64) !struct { code: []u8, constants: []Value } {
    var code = std.ArrayList(u8).init(allocator);
    errdefer code.deinit();

    // sum = 0 (local 0)
    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // i = 1 (local 1)
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // Loop start
    const loop_start: u16 = @intCast(code.items.len);

    // Check i <= n
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOpU16(&code, .PUSH_CONST, 2);
    try emitOp(&code, .LE);
    try emitOpU16(&code, .JZ, 0); // placeholder
    const jz_patch = code.items.len - 2;

    // sum = sum + i
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOp(&code, .ADD);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // i = i + 1
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOp(&code, .INC);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // Jump back
    try emitOpU16(&code, .JMP, loop_start);

    // Loop end
    const loop_end: u16 = @intCast(code.items.len);
    code.items[jz_patch] = @intCast(loop_end >> 8);
    code.items[jz_patch + 1] = @intCast(loop_end & 0xFF);

    // Return sum
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOp(&code, .HALT);

    const constants = try allocator.alloc(Value, 3);
    constants[0] = .{ .int_val = 0 };
    constants[1] = .{ .int_val = 1 };
    constants[2] = .{ .int_val = n };

    return .{ .code = try code.toOwnedSlice(), .constants = constants };
}

/// Generate bytecode for: Fibonacci(n)
fn generateFibonacci(allocator: std.mem.Allocator, n: i64) !struct { code: []u8, constants: []Value } {
    var code = std.ArrayList(u8).init(allocator);
    errdefer code.deinit();

    // a = 0 (local 0)
    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // b = 1 (local 1)
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // n = N (local 2)
    try emitOpU16(&code, .PUSH_CONST, 2);
    try emitOpU16(&code, .STORE_LOCAL, 2);

    // Loop start
    const loop_start: u16 = @intCast(code.items.len);

    // Check n > 0
    try emitOpU16(&code, .LOAD_LOCAL, 2);
    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOp(&code, .GT);
    try emitOpU16(&code, .JZ, 0); // placeholder
    const jz_patch = code.items.len - 2;

    // temp = a + b (local 3)
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOp(&code, .ADD);
    try emitOpU16(&code, .STORE_LOCAL, 3);

    // a = b
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // b = temp
    try emitOpU16(&code, .LOAD_LOCAL, 3);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // n = n - 1
    try emitOpU16(&code, .LOAD_LOCAL, 2);
    try emitOp(&code, .DEC);
    try emitOpU16(&code, .STORE_LOCAL, 2);

    // Jump back
    try emitOpU16(&code, .JMP, loop_start);

    // Loop end
    const loop_end: u16 = @intCast(code.items.len);
    code.items[jz_patch] = @intCast(loop_end >> 8);
    code.items[jz_patch + 1] = @intCast(loop_end & 0xFF);

    // Return a
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOp(&code, .HALT);

    const constants = try allocator.alloc(Value, 3);
    constants[0] = .{ .int_val = 0 };
    constants[1] = .{ .int_val = 1 };
    constants[2] = .{ .int_val = n };

    return .{ .code = try code.toOwnedSlice(), .constants = constants };
}

/// Generate bytecode for: tryte sum loop
fn generateTryteLoop(allocator: std.mem.Allocator, n: i64) !struct { code: []u8, constants: []Value } {
    var code = std.ArrayList(u8).init(allocator);
    errdefer code.deinit();

    // total = 0t (local 0)
    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // i = 0 (local 1)
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // Loop start
    const loop_start: u16 = @intCast(code.items.len);

    // Check i < n
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOpU16(&code, .PUSH_CONST, 2);
    try emitOp(&code, .LT);
    try emitOpU16(&code, .JZ, 0); // placeholder
    const jz_patch = code.items.len - 2;

    // total = total +t 1
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOpU16(&code, .PUSH_CONST, 3);
    try emitOp(&code, .TRYTE_ADD);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // i = i + 1
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOp(&code, .INC);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // Jump back
    try emitOpU16(&code, .JMP, loop_start);

    // Loop end
    const loop_end: u16 = @intCast(code.items.len);
    code.items[jz_patch] = @intCast(loop_end >> 8);
    code.items[jz_patch + 1] = @intCast(loop_end & 0xFF);

    // Return total
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOp(&code, .HALT);

    const constants = try allocator.alloc(Value, 4);
    constants[0] = .{ .tryte_val = 0 };
    constants[1] = .{ .int_val = 0 };
    constants[2] = .{ .int_val = n };
    constants[3] = .{ .tryte_val = 1 };

    return .{ .code = try code.toOwnedSlice(), .constants = constants };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

fn runBenchmark(
    allocator: std.mem.Allocator,
    name: []const u8,
    code: []const u8,
    constants: []const Value,
) !BenchmarkResult {
    var interpreter_times: [BENCHMARK_ITERATIONS]u64 = undefined;
    var fast_interpreter_times: [BENCHMARK_ITERATIONS]u64 = undefined;
    var jit_adapter_times: [BENCHMARK_ITERATIONS]u64 = undefined;
    var instructions_executed: u64 = 0;

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        var vm = try VM.init(allocator);
        defer vm.deinit();
        vm.load(code, constants);
        _ = try vm.run();
    }

    // Benchmark interpreter
    for (0..BENCHMARK_ITERATIONS) |i| {
        var vm = try VM.init(allocator);
        defer vm.deinit();
        vm.load(code, constants);

        const start = std.time.nanoTimestamp();
        _ = try vm.run();
        const end = std.time.nanoTimestamp();

        interpreter_times[i] = @intCast(@max(0, end - start));
        if (i == 0) instructions_executed = vm.instructions_executed;
    }

    // Benchmark fast interpreter
    for (0..BENCHMARK_ITERATIONS) |i| {
        var vm = try VM.init(allocator);
        defer vm.deinit();
        vm.load(code, constants);

        const start = std.time.nanoTimestamp();
        _ = try vm.runFast();
        const end = std.time.nanoTimestamp();

        fast_interpreter_times[i] = @intCast(@max(0, end - start));
    }

    // Benchmark JIT adapter
    for (0..BENCHMARK_ITERATIONS) |i| {
        var adapter = try JITAdapter.init(allocator);
        defer adapter.deinit();
        adapter.setMode(.Mixed);

        const start = std.time.nanoTimestamp();
        _ = try adapter.execute(code, constants);
        const end = std.time.nanoTimestamp();

        jit_adapter_times[i] = @intCast(@max(0, end - start));
    }

    // Calculate median times
    std.mem.sort(u64, &interpreter_times, {}, std.sort.asc(u64));
    std.mem.sort(u64, &fast_interpreter_times, {}, std.sort.asc(u64));
    std.mem.sort(u64, &jit_adapter_times, {}, std.sort.asc(u64));

    const interpreter_ns = interpreter_times[BENCHMARK_ITERATIONS / 2];
    const fast_interpreter_ns = fast_interpreter_times[BENCHMARK_ITERATIONS / 2];
    const jit_adapter_ns = jit_adapter_times[BENCHMARK_ITERATIONS / 2];

    // Calculate ops/sec
    const interpreter_ops_per_sec = if (interpreter_ns > 0)
        @as(f64, @floatFromInt(instructions_executed)) * 1_000_000_000.0 / @as(f64, @floatFromInt(interpreter_ns))
    else
        0;

    const fast_interpreter_ops_per_sec = if (fast_interpreter_ns > 0)
        @as(f64, @floatFromInt(instructions_executed)) * 1_000_000_000.0 / @as(f64, @floatFromInt(fast_interpreter_ns))
    else
        0;

    const jit_adapter_ops_per_sec = if (jit_adapter_ns > 0)
        @as(f64, @floatFromInt(instructions_executed)) * 1_000_000_000.0 / @as(f64, @floatFromInt(jit_adapter_ns))
    else
        0;

    return BenchmarkResult{
        .name = name,
        .interpreter_ns = interpreter_ns,
        .fast_interpreter_ns = fast_interpreter_ns,
        .jit_adapter_ns = jit_adapter_ns,
        .interpreter_ops_per_sec = interpreter_ops_per_sec,
        .fast_interpreter_ops_per_sec = fast_interpreter_ops_per_sec,
        .jit_adapter_ops_per_sec = jit_adapter_ops_per_sec,
        .speedup_fast_vs_normal = if (fast_interpreter_ns > 0)
            @as(f64, @floatFromInt(interpreter_ns)) / @as(f64, @floatFromInt(fast_interpreter_ns))
        else
            0,
        .speedup_jit_vs_normal = if (jit_adapter_ns > 0)
            @as(f64, @floatFromInt(interpreter_ns)) / @as(f64, @floatFromInt(jit_adapter_ns))
        else
            0,
        .instructions_executed = instructions_executed,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           VIBEEC JIT BENCHMARK - VM vs JIT                    ║\n", .{});
    std.debug.print("║           Sacred Formula: V = n × 3^k × π^m × φ^p × e^q       ║\n", .{});
    std.debug.print("║           Golden Identity: φ² + 1/φ² = 3                      ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});

    // Benchmark Sum loop
    {
        const prog = try generateSumLoop(allocator, 100);
        defer allocator.free(prog.code);
        defer allocator.free(prog.constants);

        std.debug.print("\n--- Sum 1..100 Benchmark ---\n", .{});

        // Interpreter
        var interpreter_time: u64 = 0;
        var instructions: u64 = 0;
        {
            var vm = try VM.init(allocator);
            defer vm.deinit();
            vm.load(prog.code, prog.constants);
            const start = std.time.nanoTimestamp();
            _ = try vm.run();
            const end = std.time.nanoTimestamp();
            interpreter_time = @intCast(@max(0, end - start));
            instructions = vm.instructions_executed;
        }

        // Fast interpreter
        var fast_time: u64 = 0;
        {
            var vm = try VM.init(allocator);
            defer vm.deinit();
            vm.load(prog.code, prog.constants);
            const start = std.time.nanoTimestamp();
            _ = try vm.runFast();
            const end = std.time.nanoTimestamp();
            fast_time = @intCast(@max(0, end - start));
        }

        // JIT adapter
        var jit_time: u64 = 0;
        {
            var adapter = try JITAdapter.init(allocator);
            defer adapter.deinit();
            adapter.setMode(.Mixed);
            const start = std.time.nanoTimestamp();
            _ = try adapter.execute(prog.code, prog.constants);
            const end = std.time.nanoTimestamp();
            jit_time = @intCast(@max(0, end - start));
        }

        std.debug.print("Instructions: {d}\n", .{instructions});
        std.debug.print("Interpreter:      {d} ns\n", .{interpreter_time});
        std.debug.print("Fast Interpreter: {d} ns ({d:.2}x)\n", .{
            fast_time,
            if (fast_time > 0) @as(f64, @floatFromInt(interpreter_time)) / @as(f64, @floatFromInt(fast_time)) else 0,
        });
        std.debug.print("JIT Adapter:      {d} ns ({d:.2}x)\n", .{
            jit_time,
            if (jit_time > 0) @as(f64, @floatFromInt(interpreter_time)) / @as(f64, @floatFromInt(jit_time)) else 0,
        });
    }

    // Benchmark Fibonacci
    {
        const prog = try generateFibonacci(allocator, 20);
        defer allocator.free(prog.code);
        defer allocator.free(prog.constants);

        std.debug.print("\n--- Fibonacci(20) Benchmark ---\n", .{});

        // Interpreter
        var interpreter_time: u64 = 0;
        var instructions: u64 = 0;
        {
            var vm = try VM.init(allocator);
            defer vm.deinit();
            vm.load(prog.code, prog.constants);
            const start = std.time.nanoTimestamp();
            _ = try vm.run();
            const end = std.time.nanoTimestamp();
            interpreter_time = @intCast(@max(0, end - start));
            instructions = vm.instructions_executed;
        }

        // Fast interpreter
        var fast_time: u64 = 0;
        {
            var vm = try VM.init(allocator);
            defer vm.deinit();
            vm.load(prog.code, prog.constants);
            const start = std.time.nanoTimestamp();
            _ = try vm.runFast();
            const end = std.time.nanoTimestamp();
            fast_time = @intCast(@max(0, end - start));
        }

        // JIT adapter
        var jit_time: u64 = 0;
        {
            var adapter = try JITAdapter.init(allocator);
            defer adapter.deinit();
            adapter.setMode(.Mixed);
            const start = std.time.nanoTimestamp();
            _ = try adapter.execute(prog.code, prog.constants);
            const end = std.time.nanoTimestamp();
            jit_time = @intCast(@max(0, end - start));
        }

        std.debug.print("Instructions: {d}\n", .{instructions});
        std.debug.print("Interpreter:      {d} ns\n", .{interpreter_time});
        std.debug.print("Fast Interpreter: {d} ns ({d:.2}x)\n", .{
            fast_time,
            if (fast_time > 0) @as(f64, @floatFromInt(interpreter_time)) / @as(f64, @floatFromInt(fast_time)) else 0,
        });
        std.debug.print("JIT Adapter:      {d} ns ({d:.2}x)\n", .{
            jit_time,
            if (jit_time > 0) @as(f64, @floatFromInt(interpreter_time)) / @as(f64, @floatFromInt(jit_time)) else 0,
        });
    }

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  BENCHMARK COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "benchmark sum loop generates correct result" {
    const allocator = std.testing.allocator;
    const prog = try generateSumLoop(allocator, 10);
    defer allocator.free(prog.code);
    defer allocator.free(prog.constants);

    var vm = try VM.init(allocator);
    defer vm.deinit();
    vm.load(prog.code, prog.constants);
    const result = try vm.run();

    try std.testing.expect(result == .int_val);
    try std.testing.expectEqual(@as(i64, 55), result.int_val); // 1+2+...+10 = 55
}

test "benchmark fibonacci generates correct result" {
    const allocator = std.testing.allocator;
    const prog = try generateFibonacci(allocator, 10);
    defer allocator.free(prog.code);
    defer allocator.free(prog.constants);

    var vm = try VM.init(allocator);
    defer vm.deinit();
    vm.load(prog.code, prog.constants);
    const result = try vm.run();

    try std.testing.expect(result == .int_val);
    try std.testing.expectEqual(@as(i64, 55), result.int_val); // fib(10) = 55
}

test "benchmark tryte loop generates correct result" {
    const allocator = std.testing.allocator;
    const prog = try generateTryteLoop(allocator, 10);
    defer allocator.free(prog.code);
    defer allocator.free(prog.constants);

    var vm = try VM.init(allocator);
    defer vm.deinit();
    vm.load(prog.code, prog.constants);
    const result = try vm.run();

    try std.testing.expect(result == .tryte_val);
    try std.testing.expectEqual(@as(i8, 10), result.tryte_val);
}
