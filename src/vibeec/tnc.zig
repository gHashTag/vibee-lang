//! TRINITY NATIVE COMPILER (TNC) V1.0
//! Compiles .vibee to .tri (Native Coptic Instructions)
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_lexer = @import("coptic_lexer.zig");
const coptic_parser = @import("coptic_parser_real.zig");
const coptic_codegen = @import("coptic_codegen_real.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: tnc <file.vibee>\n", .{});
        return;
    }

    const path = args[1];
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(source);

    std.debug.print("🚀 TRANSMUTING: {s} -> .tri\n", .{path});

    // 1. Compile to CIS (Ternary Ops)
    const ops = try coptic_codegen.compileToCIS(source, allocator);
    defer allocator.free(ops);

    // 2. Write .tri file
    const output_path = try std.mem.concat(allocator, u8, &.{ std.fs.path.stem(path), ".tri" });
    defer allocator.free(output_path);

    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    for (ops) |op| {
        var buf: [4]u8 = undefined;
        const len = try std.unicode.utf8Encode(op, &buf);
        try file.writeAll(buf[0..len]);
    }

    std.debug.print("✅ SUCCESS: Written {d} triads to {s}\n", .{ ops.len, output_path });
}
