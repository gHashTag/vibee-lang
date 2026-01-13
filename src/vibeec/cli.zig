// ============================================================================
// VIBEEC CLI
// Command-line interface for VIBEE compiler
// ============================================================================

const std = @import("std");
const lexer = @import("lexer.zig");
const vibee_parser = @import("vibee_parser.zig");
const ast_codegen = @import("ast_codegen.zig");
const ast = @import("ast.zig");

const version = "0.1.0";

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

    if (std.mem.eql(u8, command, "compile") or std.mem.eql(u8, command, "c")) {
        try compileCommand(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "parse")) {
        try parseCommand(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "lex")) {
        try lexCommand(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "-v") or std.mem.eql(u8, command, "--version")) {
        try printVersion();
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        try printUsage();
    } else {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Unknown command: {s}\n", .{command});
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\VIBEEC - VIBEE Language Compiler
        \\
        \\Usage: vibeec <command> [options]
        \\
        \\Commands:
        \\  compile, c    Compile .vibee file to target language
        \\  parse         Parse .vibee file and show AST
        \\  lex           Tokenize .vibee file and show tokens
        \\  version       Show version
        \\  help          Show this help
        \\
        \\Compile Options:
        \\  --target, -t  Target language: zig, rust, go (default: zig)
        \\  --output, -o  Output file path
        \\
        \\Examples:
        \\  vibeec compile example.vibee --target zig
        \\  vibeec compile example.vibee -t rust -o output.rs
        \\  vibeec parse example.vibee
        \\
    , .{});
}

fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("vibeec {s}\n", .{version});
}

fn compileCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    if (args.len == 0) {
        try stderr.print("Error: No input file specified\n", .{});
        return;
    }

    var input_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;
    var target: ast_codegen.Target = .Zig;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        
        if (std.mem.eql(u8, arg, "--target") or std.mem.eql(u8, arg, "-t")) {
            i += 1;
            if (i >= args.len) {
                try stderr.print("Error: --target requires a value\n", .{});
                return;
            }
            const target_str = args[i];
            if (std.mem.eql(u8, target_str, "zig")) {
                target = .Zig;
            } else if (std.mem.eql(u8, target_str, "rust") or std.mem.eql(u8, target_str, "rs")) {
                target = .Rust;
            } else if (std.mem.eql(u8, target_str, "go")) {
                target = .Go;
            } else {
                try stderr.print("Error: Unknown target: {s}\n", .{target_str});
                return;
            }
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            i += 1;
            if (i >= args.len) {
                try stderr.print("Error: --output requires a value\n", .{});
                return;
            }
            output_file = args[i];
        } else if (arg[0] != '-') {
            input_file = arg;
        }
    }

    if (input_file == null) {
        try stderr.print("Error: No input file specified\n", .{});
        return;
    }

    // Read input file
    const source = std.fs.cwd().readFileAlloc(allocator, input_file.?, 1024 * 1024) catch |err| {
        try stderr.print("Error reading file '{s}': {}\n", .{ input_file.?, err });
        return;
    };
    defer allocator.free(source);

    // Parse
    const tree = vibee_parser.parseSource(allocator, source) catch |err| {
        try stderr.print("Parse error: {}\n", .{err});
        return;
    };

    // Generate code
    var gen = ast_codegen.CodeGenerator.init(allocator, target);
    const code = gen.generate(tree) catch |err| {
        try stderr.print("Code generation error: {}\n", .{err});
        return;
    };
    defer allocator.free(code);

    // Output
    if (output_file) |out_path| {
        const file = std.fs.cwd().createFile(out_path, .{}) catch |err| {
            try stderr.print("Error creating output file '{s}': {}\n", .{ out_path, err });
            return;
        };
        defer file.close();
        try file.writeAll(code);
        try stdout.print("Compiled {s} -> {s}\n", .{ input_file.?, out_path });
    } else {
        try stdout.print("{s}", .{code});
    }
}

fn parseCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    if (args.len == 0) {
        try stderr.print("Error: No input file specified\n", .{});
        return;
    }

    const input_file = args[0];

    // Read input file
    const source = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |err| {
        try stderr.print("Error reading file '{s}': {}\n", .{ input_file, err });
        return;
    };
    defer allocator.free(source);

    // Parse
    const tree = vibee_parser.parseSource(allocator, source) catch |err| {
        try stderr.print("Parse error: {}\n", .{err});
        return;
    };

    // Print AST
    try stdout.print("AST for {s}:\n", .{input_file});
    try ast.printAst(tree, stdout, 0);
}

fn lexCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    if (args.len == 0) {
        try stderr.print("Error: No input file specified\n", .{});
        return;
    }

    const input_file = args[0];

    // Read input file
    const source = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |err| {
        try stderr.print("Error reading file '{s}': {}\n", .{ input_file, err });
        return;
    };
    defer allocator.free(source);

    // Tokenize
    var lex = lexer.Lexer.init(source);
    const tokens = lex.tokenize(allocator) catch |err| {
        try stderr.print("Lexer error: {}\n", .{err});
        return;
    };
    defer allocator.free(tokens);

    // Print tokens
    try stdout.print("Tokens for {s}:\n", .{input_file});
    for (tokens) |token| {
        try stdout.print("  {s:20} '{s}' at {d}:{d}\n", .{
            @tagName(token.type),
            token.lexeme,
            token.line,
            token.column,
        });
    }
}

// ============================================================================
// TESTS
// ============================================================================

test "parse args" {
    // Basic test that main compiles
    _ = main;
}
