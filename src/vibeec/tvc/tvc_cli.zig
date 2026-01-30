const std = @import("std");

const tvc_ir = @import("tvc_ir.zig");
const tvc_parser = @import("tvc_parser.zig");
const binary_codegen = @import("binary_codegen.zig");
const ternary_codegen = @import("ternary_codegen.zig");

// TVC MVP CLI - Main entry point for TVC compiler

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage(args[0]);
        return error.Usage;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "compile")) {
        try runCompile(allocator, args);
    } else if (std.mem.eql(u8, command, "parse")) {
        try runParse(allocator, args);
    } else if (std.mem.eql(u8, command, "demo")) {
        try runDemo(allocator);
    } else {
        try printUsage(args[0]);
        return error.InvalidCommand;
    }
}

fn printUsage(program_name: []const u8) !void {
    std.debug.print(
        \\TVC MVP - Trinary Virtual Code Compiler
        \\Usage: {s} <command> [options]
        \\
        \\Commands:
        \\  compile <spec.vibee> [output_dir]    Compile .vibee to TVC (binary + ternary)
        \\  parse <spec.vibee>                   Parse .vibee and display TVC IR
        \\  demo                                  Run TVC demo with example spec
        \\
        \\Examples:
        \\  {s} compile specs/tri/agent_reasoning_v10842.vibee
        \\  {s} parse specs/tri/agent_reasoning_v10842.vibee
        \\  {s} demo
        \\
    , .{ program_name, program_name, program_name, program_name });
    std.process.exit(1);
}

fn runCompile(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 3) {
        std.debug.print("Error: No .vibee specification provided\n", .{});
        return error.MissingArgument;
    }

    const spec_path = args[2];
    const output_dir = if (args.len > 3) args[3] else "generated/tvc";

    try std.fs.cwd().makePath(output_dir);

    // Parse .vibee specification
    var parser = tvc_parser.TVCParser.init(allocator);
    const module = try parser.parseVibeeSpec(spec_path);
    defer module.deinit();

    std.debug.print("✓ Parsed: {s}\n", .{spec_path});
    std.debug.print("  Module: {s}\n", .{module.name});
    std.debug.print("  Functions: {d}\n", .{module.functions.count()});

    // Compile to binary (x86_64)
    var bin_emitter = binary_codegen.BinaryEmitter.init(allocator, .x86_64);
    const binary_code = try bin_emitter.emitModule(module);
    defer allocator.free(binary_code);

    const bin_output_path = try std.fmt.allocPrint(allocator, "{s}/{s}_x86_64.bin", .{ output_dir, module.name });
    defer allocator.free(bin_output_path);

    const bin_file = try std.fs.cwd().createFile(bin_output_path, .{});
    defer bin_file.close();
    try bin_file.writeAll(binary_code);

    std.debug.print("✓ Binary: {s}\n", .{bin_output_path});
    std.debug.print("  Size: {d} bytes\n", .{binary_code.len});

    // Compile to ternary (TRIT-CPU)
    var tern_emitter = ternary_codegen.TernaryEmitter.init(allocator, .trit_cpu);
    const ternary_code = try tern_emitter.emitModule(module);
    defer allocator.free(ternary_code);

    const tern_output_path = try std.fmt.allocPrint(allocator, "{s}/{s}_ternary.trit", .{ output_dir, module.name });
    defer allocator.free(tern_output_path);

    const tern_file = try std.fs.cwd().createFile(tern_output_path, .{});
    defer tern_file.close();
    try tern_file.writeAll(ternary_code);

    std.debug.print("✓ Ternary: {s}\n", .{tern_output_path});
    std.debug.print("  Size: {d} bytes\n", .{ternary_code.len});

    std.debug.print("\n✅ TVC COMPILATION COMPLETE\n", .{});
    std.debug.print("  Binary + Ternary targets generated\n", .{});
}

fn runParse(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 3) {
        std.debug.print("Error: No .vibee specification provided\n", .{});
        return error.MissingArgument;
    }

    const spec_path = args[2];

    // Parse .vibee specification
    var parser = tvc_parser.TVCParser.init(allocator);
    const module = try parser.parseVibeeSpec(spec_path);
    defer module.deinit();

    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TVC INTERMEDIATE REPRESENTATION       ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("Module: {s}\n\n", .{module.name});

    std.debug.print("Functions ({d}):\n", .{module.functions.count()});
    var func_iter = module.functions.iterator();
    while (func_iter.next()) |entry| {
        const func = entry.value_ptr.*;
        std.debug.print("  - {s}\n", .{func.name});
        std.debug.print("    Returns: {s}\n", .{@tagName(func.returns)});
        std.debug.print("    Params: {d}\n", .{func.params.len});
        std.debug.print("    Blocks: {d}\n", .{func.blocks.count()});

        var block_iter = func.blocks.iterator();
        while (block_iter.next()) |block_entry| {
            const block = block_entry.value_ptr.*;
            std.debug.print("      Block: {s}\n", .{block.name});
            std.debug.print("        Instructions: {d}\n", .{block.instructions.items.len});
            for (block.instructions.items) |inst| {
                std.debug.print("          {any}\n", .{inst});
            }
        }
    }

    std.debug.print("\nGlobals ({d}):\n", .{module.globals.count()});
    var glob_iter = module.globals.iterator();
    while (glob_iter.next()) |entry| {
        std.debug.print("  - {s}\n", .{entry.key_ptr.*});
    }
}

fn runDemo(allocator: std.mem.Allocator) !void {
    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              TVC MVP DEMONSTRATION              ║\n", .{});
    std.debug.print("║  Trinary Virtual Code → Binary + Ternary       ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    // Create demo module
    const module = try createDemoModule(allocator);
    defer module.deinit();

    std.debug.print("✓ Created demo module: {s}\n", .{module.name});
    std.debug.print("  Functions: {d}\n", .{module.functions.count()});
    std.debug.print("  Globals: {d}\n\n", .{module.globals.count()});

    // Compile to binary (x86_64)
    std.debug.print("─── BINARY CODE GENERATION (x86_64) ───\n", .{});
    var bin_emitter = binary_codegen.BinaryEmitter.init(allocator, .x86_64);
    const binary_code = try bin_emitter.emitModule(module);
    defer allocator.free(binary_code);

    std.debug.print("✓ Generated binary code\n", .{});
    std.debug.print("  Size: {d} bytes\n", .{binary_code.len});
    std.debug.print("  First 16 bytes: ", .{});
    for (binary_code[0..@min(16, binary_code.len)]) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n\n", .{});

    // Compile to binary (ARM64)
    std.debug.print("─── BINARY CODE GENERATION (ARM64) ───\n", .{});
    var arm_emitter = binary_codegen.BinaryEmitter.init(allocator, .arm64);
    const arm_code = try arm_emitter.emitModule(module);
    defer allocator.free(arm_code);

    std.debug.print("✓ Generated ARM64 binary code\n", .{});
    std.debug.print("  Size: {d} bytes\n", .{arm_code.len});
    std.debug.print("  First 16 bytes: ", .{});
    for (arm_code[0..@min(16, arm_code.len)]) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n\n", .{});

    // Compile to binary (WebAssembly)
    std.debug.print("─── BINARY CODE GENERATION (WebAssembly) ───\n", .{});
    var wasm_emitter = binary_codegen.BinaryEmitter.init(allocator, .wasm);
    const wasm_code = try wasm_emitter.emitModule(module);
    defer allocator.free(wasm_code);

    std.debug.print("✓ Generated WebAssembly code\n", .{});
    std.debug.print("  Size: {d} bytes\n", .{wasm_code.len});
    std.debug.print("  Magic: ", .{});
    for (wasm_code[0..@min(4, wasm_code.len)]) |byte| {
        std.debug.print("{c}", .{@intFromEnum(byte)});
    }
    std.debug.print("\n\n", .{});

    // Compile to ternary (TRIT-CPU)
    std.debug.print("─── TERNARY CODE GENERATION (TRIT-CPU) ───\n", .{});
    var trit_emitter = ternary_codegen.TernaryEmitter.init(allocator, .trit_cpu);
    const ternary_code = try trit_emitter.emitModule(module);
    defer allocator.free(ternary_code);

    std.debug.print("✓ Generated ternary code\n", .{});
    std.debug.print("  Size: {d} bytes\n", .{ternary_code.len});
    std.debug.print("  Magic: ", .{});
    for (ternary_code[0..@min(4, ternary_code.len)]) |byte| {
        std.debug.print("{c}", .{@intFromEnum(byte)});
    }
    std.debug.print("\n\n", .{});

    // Compile to ternary (QUBIT-HYBRID)
    std.debug.print("─── TERNARY CODE GENERATION (QUBIT-HYBRID) ───\n", .{});
    var qubit_emitter = ternary_codegen.TernaryEmitter.init(allocator, .qubit_hybrid);
    const qubit_code = try qubit_emitter.emitModule(module);
    defer allocator.free(qubit_code);

    std.debug.print("✓ Generated quantum-ternary code\n", .{});
    std.debug.print("  Size: {d} bytes\n", .{qubit_code.len});
    std.debug.print("  Magic: ", .{});
    for (qubit_code[0..@min(4, qubit_code.len)]) |byte| {
        std.debug.print("{c}", .{@intFromEnum(byte)});
    }
    std.debug.print("\n\n", .{});

    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                   DEMO COMPLETE                  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n🎯 TVC SUCCESSFULLY GENERATES:\n", .{});
    std.debug.print("  ✓ Binary: x86_64, ARM64, WebAssembly\n", .{});
    std.debug.print("  ✓ Ternary: TRIT-CPU, QUBIT-HYBRID\n", .{});
    std.debug.print("  ✓ Single IR → Multiple targets\n", .{});
    std.debug.print("  ✓ Native trinary logic operations\n", .{});
}

fn createDemoModule(allocator: std.mem.Allocator) !*tvc_ir.TVCModule {
    const module = try allocator.create(tvc_ir.TVCModule);
    module.* = tvc_ir.TVCModule.init(allocator, "demo_module");

    // Add global constant
    try module.globals.put("PHI", tvc_ir.TVCValue{ .f64_trit = 1.618033988749894 });

    // Add function: trinary_deduce
    const deduce_func = try module.addFunction("trinary_deduce");

    var block = tvc_ir.TVCBlock.init(allocator, "entry");
    block.entry_point = 0;

    // Emit trinary NOT operation
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_not,
        .operands = &[_]u64{0},
        .location = 0,
    });

    // Emit trinary AND operation
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_and,
        .operands = &[_]u64{ 1, 2 },
        .location = 1,
    });

    // Emit trinary OR operation
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_or,
        .operands = &[_]u64{ 3, 4 },
        .location = 2,
    });

    // Emit trinary IMPLIES operation
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_implies,
        .operands = &[_]u64{ 5, 6 },
        .location = 3,
    });

    // Emit return
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 4,
    });

    block.exit_point = 4;
    const block_name = try allocator.dupe(u8, "entry");
    try deduce_func.blocks.put(block_name, block);

    deduce_func.returns = .i64_trit;
    deduce_func.is_extern = false;

    // Add function: trinary_add
    const add_func = try module.addFunction("trinary_add");

    var add_block = tvc_ir.TVCBlock.init(allocator, "entry");
    add_block.entry_point = 0;

    // Emit addition
    try add_block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .add,
        .operands = &[_]u64{ 0, 1 },
        .location = 0,
    });

    // Emit return
    try add_block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 1,
    });

    add_block.exit_point = 1;
    try add_func.blocks.put(block_name, add_block);

    add_func.returns = .i64_trit;
    add_func.is_extern = false;

    return module;
}
