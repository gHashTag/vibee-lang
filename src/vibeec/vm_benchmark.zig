//! VM vs Interpreter Benchmark
//! Compares bytecode VM with tree-walking interpreter
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_parser = @import("coptic_parser_real.zig");
const coptic_interpreter = @import("coptic_interpreter.zig");
const bytecode_compiler = @import("bytecode_compiler.zig");
const vm_runtime = @import("vm_runtime.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    VIBEE VM BENCHMARK v1.0\n", .{});
    std.debug.print("                    φ² + 1/φ² = 3\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    // Test cases
    const tests = [_]struct { name: []const u8, source: []const u8 }{
        .{ .name = "Simple arithmetic", .source = "10 + 5 * 3" },
        .{ .name = "Comparison", .source = "100 > 50" },
        .{ .name = "Complex expr", .source = "((10 + 20) * 3) - 5" },
        .{ .name = "Nested arithmetic", .source = "1 + 2 + 3 + 4 + 5" },
    };

    var total_interp_ns: u64 = 0;
    var total_vm_ns: u64 = 0;

    for (tests) |t| {
        std.debug.print("Test: {s}\n", .{t.name});
        std.debug.print("  Source: {s}\n", .{t.source});

        // Benchmark interpreter
        const interp_result = try benchmarkInterpreter(allocator, t.source, 1000);
        total_interp_ns += interp_result.avg_ns;

        // Benchmark VM
        const vm_result = try benchmarkVM(allocator, t.source, 1000);
        total_vm_ns += vm_result.avg_ns;

        const speedup = @as(f64, @floatFromInt(interp_result.avg_ns)) / @as(f64, @floatFromInt(@max(1, vm_result.avg_ns)));

        std.debug.print("  Interpreter: {d} ns/iter\n", .{interp_result.avg_ns});
        std.debug.print("  VM:          {d} ns/iter\n", .{vm_result.avg_ns});
        std.debug.print("  Speedup:     {d:.2}x\n", .{speedup});
        std.debug.print("\n", .{});
    }

    const total_speedup = @as(f64, @floatFromInt(total_interp_ns)) / @as(f64, @floatFromInt(@max(1, total_vm_ns)));

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TOTAL SPEEDUP: {d:.2}x\n", .{total_speedup});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

const BenchResult = struct {
    avg_ns: u64,
    min_ns: u64,
    max_ns: u64,
};

fn benchmarkInterpreter(allocator: std.mem.Allocator, source: []const u8, iterations: u32) !BenchResult {
    // Parse once
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        var interp = coptic_interpreter.Interpreter.init(allocator, source);
        defer interp.deinit();

        const start = std.time.nanoTimestamp();
        _ = try interp.interpret(&ast);
        const end = std.time.nanoTimestamp();

        const elapsed: u64 = @intCast(end - start);
        total_ns += elapsed;
        min_ns = @min(min_ns, elapsed);
        max_ns = @max(max_ns, elapsed);
    }

    return .{
        .avg_ns = total_ns / iterations,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkVM(allocator: std.mem.Allocator, source: []const u8, iterations: u32) !BenchResult {
    // Compile once
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();

    var compiler = bytecode_compiler.BytecodeCompiler.init(allocator, source);
    defer compiler.deinit();
    try compiler.compile(&ast);

    const code = compiler.getCode();
    const constants = compiler.getConstants();

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        var vm = try vm_runtime.VM.init(allocator);
        defer vm.deinit();

        vm.load(code, constants);

        const start = std.time.nanoTimestamp();
        _ = try vm.run();
        const end = std.time.nanoTimestamp();

        const elapsed: u64 = @intCast(end - start);
        total_ns += elapsed;
        min_ns = @min(min_ns, elapsed);
        max_ns = @max(max_ns, elapsed);
    }

    return .{
        .avg_ns = total_ns / iterations,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

test "benchmark sanity" {
    const allocator = std.testing.allocator;

    const interp_result = try benchmarkInterpreter(allocator, "10 + 5", 10);
    try std.testing.expect(interp_result.avg_ns > 0);

    const vm_result = try benchmarkVM(allocator, "10 + 5", 10);
    try std.testing.expect(vm_result.avg_ns > 0);
}
