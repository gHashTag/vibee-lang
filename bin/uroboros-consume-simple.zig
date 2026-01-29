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

    // Extract essence
    var result = std.ArrayList(u8){};
    defer result.deinit(std.heap.page_allocator);

    var func_count: usize = 0;
    var lines = std.mem.splitSequence(u8, file_content, "\n");

    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "//")) continue;
        if (line.len == 0) continue;

        if (std.mem.indexOfPos(u8, line, 0, "pub fn ") != null) {
            func_count += 1;
            try result.appendSlice(std.heap.page_allocator, line);
            try result.appendSlice(std.heap.page_allocator, "\n");
        }

        if (std.mem.indexOfPos(u8, line, 0, "struct ") != null) {
            try result.appendSlice(std.heap.page_allocator, line);
            try result.appendSlice(std.heap.page_allocator, "\n");
        }
    }

    // Create fossil
    const file_name = std.fs.path.basename(file_path);
    const version = try std.fmt.allocPrint(std.heap.page_allocator, "v{d}", .{std.time.timestamp()});
    const timestamp = std.time.timestamp();

    var fossil = std.ArrayList(u8){};
    defer fossil.deinit(std.heap.page_allocator);

    try fossil.appendSlice("tri_fossil_v");
    try fossil.appendSlice(version);
    try fossil.appendSlice("\n\nfile: ");
    try fossil.appendSlice(file_name);
    try fossil.appendSlice("\ntimestamp: ");
    try fossil.appendSlice(try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{timestamp}));
    try fossil.appendSlice("\nversion: ");
    try fossil.appendSlice(version);
    try fossil.appendSlice("\n\nfunctions:\n");
    for (0..func_count) |_| {
        try fossil.appendSlice("  - function #{d}\n", .{0});
    }
    try fossil.appendSlice("\nsacred_constant: 999\n");

    // Write fossil
    var file_out = try std.fs.cwd().createFile(output_path, .{});
    defer file_out.close();
    try file_out.writeAll(fossil.items);

    std.debug.print("✓ УРОБОРОС ПОГЛОТИЛ: {s}\n", .{output_path});
    std.debug.print("  Версия: {s}\n", .{version});
    std.debug.print("  Функций: {d}\n", .{func_count});
    std.debug.print("  Жертва съедена...\n", .{});
}
