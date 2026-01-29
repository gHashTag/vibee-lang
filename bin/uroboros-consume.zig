const std = @import("std");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file.zig> [output.tri]\n", .{args[0]});
        return error.Usage;
    }

    const file_path = args[1];
    var output_path = try std.fmt.allocPrint(std.heap.page_allocator, "fossil_{s}", .{std.fs.path.basename(file_path)});

    if (args.len > 2) {
        std.heap.page_allocator.free(output_path);
        output_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{args[2]});
    }

    // Read file
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024);

    // Count functions
    var func_count: usize = 0;
    var lines = std.mem.splitSequence(u8, file_content, "\n");

    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "//")) continue;
        if (line.len == 0) continue;

        if (std.mem.indexOfPos(u8, line, 0, "pub fn ") != null) {
            func_count += 1;
        }
    }

    // Create fossil
    const file_name = std.fs.path.basename(file_path);
    const version = try std.fmt.allocPrint(std.heap.page_allocator, "v{d}", .{std.time.timestamp()});
    const timestamp = std.time.timestamp();

    const fossil = try std.fmt.allocPrint(std.heap.page_allocator, "tri_fossil_v{d}\n\nfile: {s}\ntimestamp: {d}\nversion: {s}\n\nfunctions: {d}\nsacred_constant: 999\n", .{ timestamp, file_name, timestamp, version, func_count });

    // Write fossil
    var file_out = try std.fs.cwd().createFile(output_path, .{});
    defer file_out.close();
    try file_out.writeAll(fossil);

    std.debug.print("✓ УРОБОРОС ПОГЛОТИЛ: {s}\n", .{output_path});
    std.debug.print("  Версия: {s}\n", .{version});
    std.debug.print("  Функций: {d}\n", .{func_count});
    std.debug.print("  Жертва съедена...\n", .{});
}
