//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ CLI
//! Command-line interface for the VIBEE compiler
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_compiler = @import("coptic_compiler.zig");
const coptic_semantic = @import("coptic_semantic.zig");
const coptic_lexer = @import("coptic_lexer.zig");
const coptic_parser = @import("coptic_parser_real.zig");
const bytecode_compiler = @import("bytecode_compiler.zig");
const vm_runtime = @import("vm_runtime.zig");
// NOTE: coptic_interpreter.zig is DEPRECATED - use VM only!

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;
pub const VERSION = "0.4.0";

const Command = enum {
    compile,
    run,      // Run via bytecode VM (the only way!)
    vm,       // Fast VM mode for .999 files
    bench,    // Benchmark with detailed timing
    profile,  // Profile opcodes
    check,
    lex,
    parse,
    repl,
    version,
    help,
    unknown,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        printUsage();
        return;
    }
    
    const cmd = parseCommand(args[1]);
    
    switch (cmd) {
        .compile => {
            if (args.len < 3) {
                printError("Missing file argument for 'compile'");
                return;
            }
            try compileFile(args[2], allocator);
        },
        .run => {
            // Run via bytecode VM - the only way!
            if (args.len < 3) {
                printError("Missing file argument for 'run'");
                return;
            }
            try runVM(args[2], allocator);
        },
        .vm => {
            // Fast VM mode - minimal output, maximum speed
            if (args.len < 3) {
                printError("Missing file argument for 'vm'");
                return;
            }
            try runFastVM(args[2], allocator);
        },
        .bench => {
            // Benchmark with detailed timing
            if (args.len < 3) {
                printError("Missing file argument for 'bench'");
                return;
            }
            const iterations: u32 = if (args.len >= 4) 
                std.fmt.parseInt(u32, args[3], 10) catch 10
            else 
                10;
            try benchmarkVM(args[2], iterations, allocator);
        },
        .profile => {
            // Profile opcodes
            if (args.len < 3) {
                printError("Missing file argument for 'profile'");
                return;
            }
            try profileVM(args[2], allocator);
        },
        .check => {
            if (args.len < 3) {
                printError("Missing file argument for 'check'");
                return;
            }
            try checkFile(args[2], allocator);
        },
        .lex => {
            if (args.len < 3) {
                printError("Missing file argument for 'lex'");
                return;
            }
            try lexFile(args[2], allocator);
        },
        .parse => {
            if (args.len < 3) {
                printError("Missing file argument for 'parse'");
                return;
            }
            try parseFile(args[2], allocator);
        },
        .repl => {
            printInfo("REPL mode - use vibee-repl binary");
        },
        .version => printVersion(),
        .help => printUsage(),
        .unknown => {
            printError("Unknown command");
            printUsage();
        },
    }
}

fn parseCommand(arg: []const u8) Command {
    if (std.mem.eql(u8, arg, "compile") or std.mem.eql(u8, arg, "c")) return .compile;
    if (std.mem.eql(u8, arg, "run") or std.mem.eql(u8, arg, "r")) return .run;
    if (std.mem.eql(u8, arg, "vm")) return .vm;
    if (std.mem.eql(u8, arg, "bench") or std.mem.eql(u8, arg, "b")) return .bench;
    if (std.mem.eql(u8, arg, "profile") or std.mem.eql(u8, arg, "p")) return .profile;
    if (std.mem.eql(u8, arg, "check") or std.mem.eql(u8, arg, "k")) return .check;
    if (std.mem.eql(u8, arg, "lex") or std.mem.eql(u8, arg, "l")) return .lex;
    if (std.mem.eql(u8, arg, "parse") or std.mem.eql(u8, arg, "p")) return .parse;
    if (std.mem.eql(u8, arg, "repl")) return .repl;
    if (std.mem.eql(u8, arg, "version") or std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) return .version;
    if (std.mem.eql(u8, arg, "help") or std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) return .help;
    return .unknown;
}

fn compileFile(path: []const u8, allocator: std.mem.Allocator) !void {
    const source = readFile(path, allocator) catch |err| {
        printError("Cannot read file");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    var compiler = coptic_compiler.Compiler.init(allocator, source, path);
    var result = compiler.compile();
    defer result.deinit(allocator);
    
    if (result.success) {
        printSuccess("Compilation successful!");
        std.debug.print("\n{s}\n", .{result.code});
        
        // Stats
        std.debug.print("\n--- Stats ---\n", .{});
        std.debug.print("Tokens: {}\n", .{result.tokens_count});
        std.debug.print("AST nodes: {}\n", .{result.ast_nodes_count});
        std.debug.print("Symbols: {}\n", .{result.symbols_count});
        std.debug.print("Lines generated: {}\n", .{result.lines_generated});
    } else {
        printError("Compilation failed!");
        for (result.errors.items) |err| {
            std.debug.print("  [{d}:{d}] {s}\n", .{ err.line, err.column, err.message });
        }
    }
    
    for (result.warnings.items) |warn| {
        std.debug.print("  Warning [{d}:{d}]: {s}\n", .{ warn.line, warn.column, warn.message });
    }
}

// Run file via bytecode VM - the ONLY execution method
fn runVM(path: []const u8, allocator: std.mem.Allocator) !void {
    const source = readFile(path, allocator) catch |err| {
        printError("Cannot read file");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    // Parse
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = parser.parseProgram() catch |err| {
        printError("Parse error");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer ast.deinit();
    
    // Compile to bytecode
    var compiler = bytecode_compiler.BytecodeCompiler.init(allocator, source);
    defer compiler.deinit();
    
    compiler.compile(&ast) catch |err| {
        printError("Bytecode compilation error");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    
    const code = compiler.getCode();
    const constants = compiler.getConstants();
    
    // Execute on VM
    var vm = vm_runtime.VM.init(allocator) catch |err| {
        printError("VM initialization error");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer vm.deinit();
    
    vm.load(code, constants);
    
    const result = vm.runFast() catch |err| {
        printError("VM runtime error");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    
    // Print result
    var buf: [256]u8 = undefined;
    const result_str = std.fmt.bufPrint(&buf, "{}", .{result}) catch "?";
    
    // Print VM stats
    printSuccess("VM execution complete");
    std.debug.print("  Instructions: {}\n", .{vm.instructions_executed});
    if (!std.mem.eql(u8, result_str, "nil")) {
        std.debug.print("  Result: {s}\n", .{result_str});
    }
}

// Profile VM - show opcode statistics
fn profileVM(path: []const u8, allocator: std.mem.Allocator) !void {
    const source = readFile(path, allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = parser.parseProgram() catch {
        std.debug.print("Parse error\n", .{});
        return;
    };
    defer ast.deinit();
    
    var compiler = bytecode_compiler.BytecodeCompiler.init(allocator, source);
    defer compiler.deinit();
    
    compiler.compile(&ast) catch {
        std.debug.print("Compile error\n", .{});
        return;
    };
    
    const code = compiler.getCode();
    const constants = compiler.getConstants();
    
    var vm = vm_runtime.VM.init(allocator) catch {
        std.debug.print("VM init error\n", .{});
        return;
    };
    defer vm.deinit();
    
    vm.load(code, constants);
    _ = vm.run() catch |err| {
        std.debug.print("Runtime error: {}\n", .{err});
        return;
    };
    
    // Print profile
    vm.printProfile(15);
    
    std.debug.print("\nTotal: {d} ops in {d:.2} µs ({d:.0} ops/s)\n", .{
        vm.instructions_executed,
        vm.getExecutionTimeUs(),
        vm.getOpsPerSecond()
    });
}

// Fast VM mode - minimal overhead, maximum performance
// Supports .vb and .999 (ternary) files
fn runFastVM(path: []const u8, allocator: std.mem.Allocator) !void {
    // Check file extension
    const is_ternary = std.mem.endsWith(u8, path, ".999");
    if (is_ternary) {
        std.debug.print("⚡ TERNARY MODE (.999)\n", .{});
    }
    
    const source = readFile(path, allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    // Parse
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = parser.parseProgram() catch {
        std.debug.print("Parse error\n", .{});
        return;
    };
    defer ast.deinit();
    
    // Compile
    var compiler = bytecode_compiler.BytecodeCompiler.init(allocator, source);
    defer compiler.deinit();
    
    compiler.compile(&ast) catch {
        std.debug.print("Compile error\n", .{});
        return;
    };
    
    const code = compiler.getCode();
    const constants = compiler.getConstants();
    
    // Run VM
    var vm = vm_runtime.VM.init(allocator) catch {
        std.debug.print("VM init error\n", .{});
        return;
    };
    defer vm.deinit();
    
    vm.load(code, constants);
    
    const result = vm.run() catch |err| {
        std.debug.print("Runtime error: {}\n", .{err});
        return;
    };
    
    // Print only result and timing
    const time_us = vm.getExecutionTimeUs();
    const ops_sec = vm.getOpsPerSecond();
    
    // Print result value
    switch (result) {
        .int_val => |v| std.debug.print("{d}\n", .{v}),
        .float_val => |v| std.debug.print("{d:.6}\n", .{v}),
        .bool_val => |v| std.debug.print("{}\n", .{v}),
        .tryte_val => |v| {
            // Print tryte in balanced ternary notation
            var buf: [4]u8 = undefined;
            var val = v;
            var i: usize = 3;
            while (i > 0) {
                i -= 1;
                const trit: i8 = @intCast(@mod(val + 1, 3) - 1);
                buf[i] = if (trit < 0) '-' else if (trit > 0) '+' else '0';
                val = @divTrunc(val - trit, 3);
            }
            std.debug.print("0t{s}({d})\n", .{buf[0..3], v});
        },
        .nil => {},
        else => std.debug.print("result\n", .{}),
    }
    
    // Print stats
    std.debug.print("---\n", .{});
    std.debug.print("{d} ops | {d:.1} µs | {d:.0} ops/s\n", .{
        vm.instructions_executed, time_us, ops_sec
    });
}

// Production benchmark with detailed metrics
fn benchmarkVM(path: []const u8, iterations: u32, allocator: std.mem.Allocator) !void {
    const source = readFile(path, allocator) catch |err| {
        printError("Cannot read file");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    // Measure parse time
    const parse_start = std.time.nanoTimestamp();
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = parser.parseProgram() catch |err| {
        printError("Parse error");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer ast.deinit();
    const parse_time = std.time.nanoTimestamp() - parse_start;
    
    // Measure compile time
    const compile_start = std.time.nanoTimestamp();
    var compiler = bytecode_compiler.BytecodeCompiler.init(allocator, source);
    defer compiler.deinit();
    
    compiler.compile(&ast) catch |err| {
        printError("Bytecode compilation error");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    const compile_time = std.time.nanoTimestamp() - compile_start;
    
    const code = compiler.getCode();
    const constants = compiler.getConstants();
    
    // Benchmark runs (no warmup - each run is independent)
    var total_time_ns: u64 = 0;
    var total_instructions: u64 = 0;
    var min_time_ns: u64 = std.math.maxInt(u64);
    var max_time_ns: u64 = 0;
    var final_result: @import("bytecode.zig").Value = .{ .nil = {} };
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        var vm = vm_runtime.VM.init(allocator) catch return;
        defer vm.deinit();
        vm.load(code, constants);
        
        final_result = vm.run() catch .{ .nil = {} };
        
        const exec_time = vm.getExecutionTimeNs();
        total_time_ns += exec_time;
        total_instructions += vm.instructions_executed;
        
        if (exec_time < min_time_ns) min_time_ns = exec_time;
        if (exec_time > max_time_ns) max_time_ns = exec_time;
    }
    
    // Calculate statistics
    const avg_time_ns = total_time_ns / iterations;
    const avg_instructions = total_instructions / iterations;
    const avg_time_us = @as(f64, @floatFromInt(avg_time_ns)) / 1000.0;
    const avg_time_ms = @as(f64, @floatFromInt(avg_time_ns)) / 1_000_000.0;
    const ops_per_sec = if (avg_time_ns > 0) 
        @as(f64, @floatFromInt(avg_instructions)) / (@as(f64, @floatFromInt(avg_time_ns)) / 1_000_000_000.0)
    else 0;
    
    // Print benchmark report
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    VIBEE BENCHMARK REPORT                        ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ File: {s:<57} ║\n", .{path});
    std.debug.print("║ Iterations: {d:<51} ║\n", .{iterations});
    std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ COMPILATION PHASE                                                ║\n", .{});
    std.debug.print("║   Parse time:    {d:>12.3} µs                                  ║\n", .{@as(f64, @floatFromInt(parse_time)) / 1000.0});
    std.debug.print("║   Compile time:  {d:>12.3} µs                                  ║\n", .{@as(f64, @floatFromInt(compile_time)) / 1000.0});
    std.debug.print("║   Bytecode size: {d:>12} bytes                                 ║\n", .{code.len});
    std.debug.print("║   Constants:     {d:>12}                                       ║\n", .{constants.len});
    std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ EXECUTION PHASE (VM only)                                        ║\n", .{});
    std.debug.print("║   Avg time:      {d:>12.3} µs ({d:.3} ms)                       ║\n", .{avg_time_us, avg_time_ms});
    std.debug.print("║   Min time:      {d:>12.3} µs                                  ║\n", .{@as(f64, @floatFromInt(min_time_ns)) / 1000.0});
    std.debug.print("║   Max time:      {d:>12.3} µs                                  ║\n", .{@as(f64, @floatFromInt(max_time_ns)) / 1000.0});
    std.debug.print("║   Instructions:  {d:>12}                                       ║\n", .{avg_instructions});
    std.debug.print("║   Ops/sec:       {d:>12.0}                                       ║\n", .{ops_per_sec});
    std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    
    // Print result
    var buf: [64]u8 = undefined;
    const result_str = switch (final_result) {
        .int_val => |v| std.fmt.bufPrint(&buf, "{d}", .{v}) catch "?",
        .float_val => |v| std.fmt.bufPrint(&buf, "{d:.6}", .{v}) catch "?",
        .bool_val => |v| if (v) "true" else "false",
        .nil => "nil",
        else => "complex",
    };
    std.debug.print("║ Result: {s:<56} ║\n", .{result_str});
    std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
}

fn checkFile(path: []const u8, allocator: std.mem.Allocator) !void {
    const source = readFile(path, allocator) catch |err| {
        printError("Cannot read file");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    // Lexer check
    var lexer = coptic_lexer.Lexer.init(source);
    var token_count: u32 = 0;
    var lex_errors: u32 = 0;
    
    while (true) {
        const tok = lexer.nextToken();
        token_count += 1;
        if (tok.kind == .invalid) lex_errors += 1;
        if (tok.kind == .eof) break;
    }
    
    // Parser check
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = parser.parseProgram() catch {
        printError("Parse error");
        return;
    };
    defer ast.deinit();
    
    // Semantic check
    var semantic = coptic_semantic.SemanticAnalyzer.init(allocator);
    defer semantic.deinit();
    semantic.setup();
    semantic.setSource(source);
    semantic.analyze(&ast) catch {};
    
    // Report
    if (lex_errors == 0 and semantic.errors.items.len == 0) {
        printSuccess("Check passed!");
        std.debug.print("  Tokens: {}\n", .{token_count});
        std.debug.print("  Symbols: {}\n", .{semantic.global_scope.symbols.count()});
    } else {
        printError("Check failed!");
        std.debug.print("  Lexer errors: {}\n", .{lex_errors});
        std.debug.print("  Semantic errors: {}\n", .{semantic.errors.items.len});
    }
}

fn lexFile(path: []const u8, allocator: std.mem.Allocator) !void {
    const source = readFile(path, allocator) catch |err| {
        printError("Cannot read file");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    var lexer = coptic_lexer.Lexer.init(source);
    
    std.debug.print("--- Tokens ---\n", .{});
    while (true) {
        const tok = lexer.nextToken();
        std.debug.print("[{d}:{d}] {s} = \"{s}\"\n", .{
            tok.line,
            tok.column,
            @tagName(tok.kind),
            tok.lexeme(source),
        });
        if (tok.kind == .eof) break;
    }
}

fn parseFile(path: []const u8, allocator: std.mem.Allocator) !void {
    const source = readFile(path, allocator) catch |err| {
        printError("Cannot read file");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer allocator.free(source);
    
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = parser.parseProgram() catch |err| {
        printError("Parse error");
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    defer ast.deinit();
    
    std.debug.print("--- AST ---\n", .{});
    printAst(&ast, 0, source);
}

fn printAst(node: *const coptic_parser.AstNode, depth: u32, source: []const u8) void {
    var i: u32 = 0;
    while (i < depth) : (i += 1) {
        std.debug.print("  ", .{});
    }
    std.debug.print("{s}", .{@tagName(node.kind)});
    if (node.token.len > 0) {
        std.debug.print(" \"{s}\"", .{node.token.lexeme(source)});
    }
    std.debug.print("\n", .{});
    
    for (node.children.items) |*child| {
        printAst(child, depth + 1, source);
    }
}

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

fn printUsage() void {
    std.debug.print(
        \\VIBEE ⲦⲢⲒⲚⲒⲦⲨ Compiler v{s}
        \\
        \\Usage: vibee <command> [options]
        \\
        \\Commands:
        \\  run, r <file>       Run .999 file via bytecode VM
        \\  compile, c <file>   Compile .999 file to Zig
        \\  check, k <file>     Check file for errors
        \\  lex, l <file>       Show lexer tokens
        \\  parse, p <file>     Show AST
        \\  repl                Start REPL
        \\  version, -v         Show version
        \\  help, -h            Show this help
        \\
        \\Examples:
        \\  vibee run hello.999
        \\  vibee compile hello.999
        \\
        \\φ² + 1/φ² = 3
        \\
    , .{VERSION});
}

fn printVersion() void {
    std.debug.print("VIBEE ⲦⲢⲒⲚⲒⲦⲨ v{s}\n", .{VERSION});
    std.debug.print("φ = {d:.15}\n", .{PHI});
    std.debug.print("Trinity = {}\n", .{TRINITY});
}

fn printError(msg: []const u8) void {
    std.debug.print("\x1b[31m✗ {s}\x1b[0m\n", .{msg});
}

fn printSuccess(msg: []const u8) void {
    std.debug.print("\x1b[32m✓ {s}\x1b[0m\n", .{msg});
}

fn printInfo(msg: []const u8) void {
    std.debug.print("\x1b[34mℹ {s}\x1b[0m\n", .{msg});
}

// Tests
test "cli parse command" {
    try std.testing.expectEqual(Command.compile, parseCommand("compile"));
    try std.testing.expectEqual(Command.compile, parseCommand("c"));
    try std.testing.expectEqual(Command.check, parseCommand("check"));
    try std.testing.expectEqual(Command.version, parseCommand("-v"));
    try std.testing.expectEqual(Command.help, parseCommand("--help"));
    try std.testing.expectEqual(Command.unknown, parseCommand("invalid"));
}

test "phi constant" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}
