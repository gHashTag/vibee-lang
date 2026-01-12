// VIBEEC - VIBEE Compiler
// Compiles .vibee specifications to Zig code

const std = @import("std");
const parser = @import("parser.zig");
const codegen = @import("codegen.zig");

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

    if (std.mem.eql(u8, command, "gen") or std.mem.eql(u8, command, "generate")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            std.debug.print("Usage: vibeec gen <spec.vibee> [--output <dir>]\n", .{});
            return;
        }
        const spec_file = args[2];
        const output_dir = if (args.len >= 5 and std.mem.eql(u8, args[3], "--output")) args[4] else ".";
        try generateCode(allocator, spec_file, output_dir);
    } else if (std.mem.eql(u8, command, "check")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            return;
        }
        try checkSpec(allocator, args[2]);
    } else if (std.mem.eql(u8, command, "version")) {
        std.debug.print("vibeec 1.0.0\n", .{});
    } else if (std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\VIBEEC - VIBEE Compiler v1.0.0
        \\
        \\Usage: vibeec <command> [options]
        \\
        \\Commands:
        \\  gen <spec.vibee>     Generate code from specification
        \\  check <spec.vibee>   Validate specification
        \\  version              Show version
        \\  help                 Show this help
        \\
        \\Options:
        \\  --output <dir>       Output directory (default: current)
        \\
        \\Examples:
        \\  vibeec gen specs/example.vibee
        \\  vibeec gen specs/example.vibee --output src/
        \\  vibeec check specs/example.vibee
        \\
    , .{});
}

fn generateCode(allocator: std.mem.Allocator, spec_file: []const u8, output_dir: []const u8) !void {
    std.debug.print("Generating code from: {s}\n", .{spec_file});
    std.debug.print("Output directory: {s}\n", .{output_dir});

    // Read spec file
    const file = std.fs.cwd().openFile(spec_file, .{}) catch |err| {
        std.debug.print("Error: Cannot open file {s}: {}\n", .{ spec_file, err });
        return;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Parse spec
    const spec = try parser.parse(allocator, content);
    defer spec.deinit();

    // Generate code
    const code = try codegen.generate(allocator, spec);
    defer allocator.free(code);

    // Write output
    const output_name = try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ output_dir, spec.module });
    defer allocator.free(output_name);

    const out_file = try std.fs.cwd().createFile(output_name, .{});
    defer out_file.close();
    try out_file.writeAll(code);

    std.debug.print("Generated: {s}\n", .{output_name});
}

fn checkSpec(allocator: std.mem.Allocator, spec_file: []const u8) !void {
    std.debug.print("Checking: {s}\n", .{spec_file});

    const file = std.fs.cwd().openFile(spec_file, .{}) catch |err| {
        std.debug.print("Error: Cannot open file {s}: {}\n", .{ spec_file, err });
        return;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const spec = parser.parse(allocator, content) catch |err| {
        std.debug.print("Error: Invalid spec: {}\n", .{err});
        return;
    };
    defer spec.deinit();

    std.debug.print("Valid spec: {s} v{s}\n", .{ spec.name, spec.version });
    std.debug.print("  Module: {s}\n", .{spec.module});
    std.debug.print("  Language: {s}\n", .{spec.language});
    std.debug.print("  Behaviors: {d}\n", .{spec.behaviors.len});
    std.debug.print("  Types: {d}\n", .{spec.types.len});
    std.debug.print("  Functions: {d}\n", .{spec.functions.len});
}
