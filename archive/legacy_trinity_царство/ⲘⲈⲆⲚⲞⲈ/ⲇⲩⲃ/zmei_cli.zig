// ═══════════════════════════════════════════════════════════════════════════════
// ⲌⲘⲈⲒ CLI - COMMAND LINE INTERFACE FOR ZMEI GORYNYCH
// ═══════════════════════════════════════════════════════════════════════════════
// Reads .tri specifications and generates .zig code
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const zmei = @import("zmei_gorynych.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "gen")) {
        try generateFromSpec(allocator);
    } else if (std.mem.eql(u8, command, "test")) {
        try runTests(allocator);
    } else if (std.mem.eql(u8, command, "version")) {
        try printVersion();
    } else {
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  ⲌⲘⲈⲒ ⲄⲞⲢⲨⲚⲨⲬ - IGLA CODE GENERATOR
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
        \\  Golden Identity: φ² + 1/φ² = 3
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\USAGE:
        \\  zmei_cli gen      Generate .zig from .tri specs
        \\  zmei_cli test     Run generator tests
        \\  zmei_cli version  Show version
        \\
        \\PATTERNS APPLIED:
        \\  PRE  - Precomputation (identifier cache)
        \\  HSH  - Hashing (perfect hash dispatch)
        \\  AMR  - Amortization (φ-based buffer growth)
        \\  D&C  - Divide-and-Conquer (modular generation)
        \\
        \\
    , .{});
}

fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\ⲌⲘⲈⲒ ⲄⲞⲢⲨⲚⲨⲬ v{s}
        \\Golden Identity Verified: {s}
        \\
    , .{ zmei.VERSION, if (zmei.verifyGoldenIdentity()) "✓" else "✗" });
}

fn generateFromSpec(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  ⲌⲘⲈⲒ ⲄⲞⲢⲨⲚⲨⲬ - GENERATING .ZIG FROM .TRI SPECS
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{});

    // Define opcodes from .tri spec (ⲡⲉⲣⲫⲉⲕⲧ_ⲏⲁⲥⲏ.tri)
    const opcodes = [_]zmei.Opcode{
        // Arithmetic
        .{ .code = 0x01, .mnemonic = "ADD", .stack_in = 2, .stack_out = 1, .semantics = "v1+v2" },
        .{ .code = 0x02, .mnemonic = "SUB", .stack_in = 2, .stack_out = 1, .semantics = "v2-v1" },
        .{ .code = 0x03, .mnemonic = "MUL", .stack_in = 2, .stack_out = 1, .semantics = "v1*v2" },
        .{ .code = 0x04, .mnemonic = "DIV", .stack_in = 2, .stack_out = 1, .semantics = "v2/v1" },
        // Stack
        .{ .code = 0x10, .mnemonic = "PUSH", .stack_in = 0, .stack_out = 1, .semantics = "push imm" },
        .{ .code = 0x11, .mnemonic = "POP", .stack_in = 1, .stack_out = 0, .semantics = "pop" },
        .{ .code = 0x12, .mnemonic = "DUP", .stack_in = 1, .stack_out = 2, .semantics = "dup top" },
        .{ .code = 0x13, .mnemonic = "SWAP", .stack_in = 2, .stack_out = 2, .semantics = "swap top 2" },
        // Control
        .{ .code = 0xFF, .mnemonic = "HALT", .stack_in = 0, .stack_out = 0, .semantics = "halt vm" },
    };

    try stdout.print("  Opcodes defined: {d}\n", .{opcodes.len});
    try stdout.print("  Patterns: PRE, HSH, AMR, D&C\n\n", .{});

    // Initialize generator
    var generator = try zmei.ZmeiGorynych.init(allocator);
    defer generator.deinit();

    // Generate
    try stdout.print("  Generating...\n", .{});
    const result = try generator.generate(&opcodes);
    defer allocator.free(result.zig_code);

    // Write to output file
    const output_path = "output/trinity_vm.zig";
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(result.zig_code);

    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  GENERATION COMPLETE
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  Output: {s}
        \\  Bytes: {d}
        \\  Types generated: {d}
        \\  Functions generated: {d}
        \\  Tests generated: {d}
        \\  Cache hit ratio: {d:.2}%
        \\  Buffer reallocations: {d}
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{
        output_path,
        result.metrics.total_bytes,
        result.metrics.types_generated,
        result.metrics.functions_generated,
        result.metrics.tests_generated,
        result.metrics.cache_hit_ratio * 100,
        result.metrics.buffer_reallocations,
    });

    // Generate perfect hash dispatch
    try generatePerfectHashDispatch(allocator, &opcodes);
}

fn generatePerfectHashDispatch(allocator: std.mem.Allocator, opcodes: []const zmei.Opcode) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  GENERATING PERFECT HASH DISPATCH
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{});

    var builder = try zmei.CodeBuilder.init(allocator);
    defer builder.deinit();

    // Header
    try builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
    try builder.appendLine("// PERFECT HASH DISPATCH - GENERATED BY ZMEI GORYNYCH");
    try builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
    try builder.appendLine("// Pattern: HSH (Minimal Perfect Hash)");
    try builder.appendLine("// Lookup: O(1) guaranteed");
    try builder.appendLine("// Formula: h(opcode) = (opcode * TRINITY_PRIME) % TABLE_SIZE");
    try builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
    try builder.append("\n");
    try builder.appendLine("const std = @import(\"std\");");
    try builder.append("\n");
    try builder.appendLine("pub const TRINITY_PRIME: u32 = 33;");
    try builder.appendLine("pub const TABLE_SIZE: u32 = 64;");
    try builder.append("\n");

    // Handler type
    try builder.appendLine("pub const Handler = *const fn (*VM) void;");
    try builder.append("\n");

    // Hash function
    try builder.appendLine("/// Perfect hash function: O(1) lookup");
    try builder.appendLine("pub inline fn hash(opcode: u8) u6 {");
    builder.indent();
    try builder.appendLine("return @truncate((opcode *% TRINITY_PRIME) % TABLE_SIZE);");
    builder.dedent();
    try builder.appendLine("}");
    try builder.append("\n");

    // Dispatch table
    try builder.appendLine("/// Precomputed dispatch table");
    try builder.appendLine("pub const dispatch_table: [TABLE_SIZE]?Handler = blk: {");
    builder.indent();
    try builder.appendLine("var table: [TABLE_SIZE]?Handler = [_]?Handler{null} ** TABLE_SIZE;");

    for (opcodes) |opcode| {
        var buf: [128]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "table[hash(0x{X:0>2})] = exec_{s};", .{ opcode.code, opcode.mnemonic }) catch continue;
        try builder.appendLine(line);
    }

    try builder.appendLine("break :blk table;");
    builder.dedent();
    try builder.appendLine("};");
    try builder.append("\n");

    // Fast dispatch
    try builder.appendLine("/// O(1) dispatch via perfect hash");
    try builder.appendLine("pub inline fn dispatch(vm: *VM, opcode: u8) void {");
    builder.indent();
    try builder.appendLine("const idx = hash(opcode);");
    try builder.appendLine("if (dispatch_table[idx]) |handler| {");
    builder.indent();
    try builder.appendLine("handler(vm);");
    builder.dedent();
    try builder.appendLine("} else {");
    builder.indent();
    try builder.appendLine("vm.status = .Error_InvalidOpcode;");
    builder.dedent();
    try builder.appendLine("}");
    builder.dedent();
    try builder.appendLine("}");
    try builder.append("\n");

    // Stub VM for compilation
    try builder.appendLine("// Stub VM for standalone compilation");
    try builder.appendLine("pub const VM = struct {");
    builder.indent();
    try builder.appendLine("status: Status,");
    try builder.appendLine("pub const Status = enum { Running, Error_InvalidOpcode };");
    builder.dedent();
    try builder.appendLine("};");
    try builder.append("\n");

    // Stub handlers
    for (opcodes) |opcode| {
        var buf: [128]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "fn exec_{s}(_: *VM) void {{}}", .{opcode.mnemonic}) catch continue;
        try builder.appendLine(line);
    }
    try builder.append("\n");

    // Test
    try builder.appendLine("test \"perfect_hash_no_collisions\" {");
    builder.indent();
    try builder.appendLine("var seen: [TABLE_SIZE]bool = [_]bool{false} ** TABLE_SIZE;");
    try builder.appendLine("const opcodes = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x10, 0x11, 0x12, 0x13, 0xFF };");
    try builder.appendLine("for (opcodes) |opcode| {");
    builder.indent();
    try builder.appendLine("const idx = hash(opcode);");
    try builder.appendLine("try std.testing.expect(!seen[idx]);");
    try builder.appendLine("seen[idx] = true;");
    builder.dedent();
    try builder.appendLine("}");
    builder.dedent();
    try builder.appendLine("}");

    // Write to file
    const output_path = "output/perfect_hash_dispatch.zig";
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(builder.getWritten());

    try stdout.print("  Output: {s}\n", .{output_path});
    try stdout.print("  Bytes: {d}\n", .{builder.len});
    try stdout.print("  Hash function: (opcode * 33) % 64\n", .{});
    try stdout.print("  Lookup time: O(1)\n", .{});
}

fn runTests(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  RUNNING ZMEI GORYNYCH TESTS
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{});

    // Test 1: Golden Identity
    const golden_ok = zmei.verifyGoldenIdentity();
    try stdout.print("  [1] Golden Identity (φ² + 1/φ² = 3): {s}\n", .{if (golden_ok) "✓ PASS" else "✗ FAIL"});

    // Test 2: Code Builder
    var builder = try zmei.CodeBuilder.init(allocator);
    defer builder.deinit();
    try builder.append("test");
    const builder_ok = builder.len == 4;
    try stdout.print("  [2] Code Builder: {s}\n", .{if (builder_ok) "✓ PASS" else "✗ FAIL"});

    // Test 3: Identifier Cache
    var cache = zmei.IdentifierCache.init(allocator);
    defer cache.deinit();
    _ = try cache.getOrCreate("ADD");
    _ = try cache.getOrCreate("ADD");
    const cache_ok = cache.hits == 1;
    try stdout.print("  [3] Identifier Cache: {s}\n", .{if (cache_ok) "✓ PASS" else "✗ FAIL"});

    // Test 4: Generator
    var gen = try zmei.ZmeiGorynych.init(allocator);
    defer gen.deinit();
    const opcodes = [_]zmei.Opcode{
        .{ .code = 0x01, .mnemonic = "ADD", .stack_in = 2, .stack_out = 1, .semantics = "v1+v2" },
    };
    const result = try gen.generate(&opcodes);
    defer allocator.free(result.zig_code);
    const gen_ok = result.zig_code.len > 0;
    try stdout.print("  [4] Code Generation: {s}\n", .{if (gen_ok) "✓ PASS" else "✗ FAIL"});

    const all_pass = golden_ok and builder_ok and cache_ok and gen_ok;
    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  RESULT: {s}
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{if (all_pass) "ALL TESTS PASSED" else "SOME TESTS FAILED"});
}
