const std = @import("std");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file.zig> [output.vibee]\n", .{args[0]});
        return error.Usage;
    }

    const file_path = args[1];
    var output_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.vibee", .{std.fs.path.stem(file_path)});

    if (args.len > 2) {
        std.heap.page_allocator.free(output_path);
        output_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{args[2]});
    }

    // Read file
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024);

    // Extract module name
    const module_name = std.fs.path.stem(file_path);

    // Simple analysis
    var pub_fn_count: usize = 0;
    var pub_struct_count: usize = 0;
    var test_count: usize = 0;

    var lines = std.mem.splitSequence(u8, source, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        if (std.mem.startsWith(u8, trimmed, "//")) continue;
        if (trimmed.len == 0) continue;

        if (std.mem.indexOf(u8, trimmed, "pub fn ") != null) {
            pub_fn_count += 1;
        }
        if (std.mem.indexOf(u8, trimmed, "pub const ") != null) {
            if (std.mem.indexOf(u8, trimmed, "= struct") != null) {
                pub_struct_count += 1;
            }
        }
        if (std.mem.indexOf(u8, trimmed, "test \"") != null) {
            test_count += 1;
        }
    }

    // Generate .vibee spec
    var spec = std.ArrayList(u8){};
    defer spec.deinit(std.heap.page_allocator);

    // Header
    try spec.appendSlice(std.heap.page_allocator, "name: ");
    try spec.appendSlice(std.heap.page_allocator, module_name);
    try spec.appendSlice(std.heap.page_allocator, "\nversion: \"1.0.0\"\nlanguage: zig\nmodule: ");
    try spec.appendSlice(std.heap.page_allocator, module_name);
    try spec.appendSlice(std.heap.page_allocator, "\n\ndescription: |\n  ");
    try spec.appendSlice(std.heap.page_allocator, "Auto-generated from ");
    try spec.appendSlice(std.heap.page_allocator, module_name);
    try spec.appendSlice(std.heap.page_allocator, "\n\n");

    // Behaviors section (for public functions)
    if (pub_fn_count > 0) {
        try spec.appendSlice(std.heap.page_allocator, "behaviors:\n");
        var i: usize = 0;
        while (i < pub_fn_count) : (i += 1) {
            try spec.appendSlice(std.heap.page_allocator, "  - name: fn_");
            const i_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{i});
            try spec.appendSlice(std.heap.page_allocator, i_str);
            try spec.appendSlice(std.heap.page_allocator, "\n    given: Input\n    when: Execute\n    then: Result\n    description: |\n      Function ");
            try spec.appendSlice(std.heap.page_allocator, i_str);
            try spec.appendSlice(std.heap.page_allocator, " behavior\n\n");
        }
    }

    // Constants
    try spec.appendSlice(std.heap.page_allocator, "constants:\n");
    try spec.appendSlice(std.heap.page_allocator, "  - PUBLIC_FUNCTIONS: ");
    const fn_count_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{pub_fn_count});
    try spec.appendSlice(std.heap.page_allocator, fn_count_str);
    try spec.appendSlice(std.heap.page_allocator, "\n");

    // Tests
    if (test_count > 0) {
        try spec.appendSlice(std.heap.page_allocator, "tests:\n");
        var i: usize = 0;
        while (i < test_count) : (i += 1) {
            try spec.appendSlice(std.heap.page_allocator, "  - name: test_");
            const i_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{i});
            try spec.appendSlice(std.heap.page_allocator, i_str);
            try spec.appendSlice(std.heap.page_allocator, "\n    description: |\n      Test verification\n");
        }
    }

    // Write spec
    var file_out = try std.fs.cwd().createFile(output_path, .{});
    defer file_out.close();
    try file_out.writeAll(spec.items);

    std.debug.print("✓ AST → VIBEE: {s}\n", .{output_path});
    std.debug.print("  Модуль: {s}\n", .{module_name});
    std.debug.print("  Публичных функций: {d}\n", .{pub_fn_count});
    std.debug.print("  Структур: {d}\n", .{pub_struct_count});
    std.debug.print("  Тестов: {d}\n", .{test_count});
    std.debug.print("  Размер: {d} байт\n", .{spec.items.len});
}
