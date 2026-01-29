const std = @import("std");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <fossil.tri> [output.vibee]\n", .{args[0]});
        return error.Usage;
    }

    const fossil_path = args[1];
    var output_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.vibee", .{std.fs.path.stem(fossil_path)});

    if (args.len > 2) {
        std.heap.page_allocator.free(output_path);
        output_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{args[2]});
    }

    // Read fossil
    const file = try std.fs.cwd().openFile(fossil_path, .{});
    defer file.close();

    const fossil_content = try file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024);

    // Extract module name
    const file_name = std.fs.path.basename(fossil_path);
    const module_name = file_name[0..std.mem.lastIndexOf(u8, file_name, "_").?];

    // Generate .vibee spec
    const vibee_spec = try generate_vibee_spec_simple(fossil_content, module_name);
    defer std.heap.page_allocator.free(vibee_spec);

    // Write spec
    var file_out = try std.fs.cwd().createFile(output_path, .{});
    defer file_out.close();
    try file_out.writeAll(vibee_spec);

    std.debug.print("✓ Fossil → VIBEE: {s}\n", .{output_path});
    std.debug.print("  Модуль: {s}\n", .{module_name});
    std.debug.print("  Размер: {d} байт\n", .{vibee_spec.len});
}

fn generate_vibee_spec_simple(fossil: []const u8, module_name: []const u8) ![]const u8 {
    var spec = std.ArrayList(u8){};
    defer spec.deinit(std.heap.page_allocator);

    // Parse basic stats
    var pub_functions: usize = 0;
    var priv_functions: usize = 0;
    var total_functions: usize = 0;
    var structs: usize = 0;
    var enums: usize = 0;
    var imports: usize = 0;
    var version: []const u8 = "v1.0.0";

    var lines = std.mem.splitSequence(u8, fossil, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        if (std.mem.indexOf(u8, trimmed, "Public functions:") != null) {
            const after_colon = if (std.mem.indexOf(u8, trimmed, ":")) |idx| trimmed[idx + 2 ..] else "";
            pub_functions = std.fmt.parseInt(usize, std.mem.trim(u8, after_colon, &std.ascii.whitespace), 10) catch 0;
        }
        if (std.mem.indexOf(u8, trimmed, "Private functions:") != null) {
            const after_colon = if (std.mem.indexOf(u8, trimmed, ":")) |idx| trimmed[idx + 2 ..] else "";
            priv_functions = std.fmt.parseInt(usize, std.mem.trim(u8, after_colon, &std.ascii.whitespace), 10) catch 0;
        }
        if (std.mem.indexOf(u8, trimmed, "Total functions:") != null) {
            const after_colon = if (std.mem.indexOf(u8, trimmed, ":")) |idx| trimmed[idx + 2 ..] else "";
            total_functions = std.fmt.parseInt(usize, std.mem.trim(u8, after_colon, &std.ascii.whitespace), 10) catch 0;
        }
        if (std.mem.indexOf(u8, trimmed, "Structs:") != null) {
            const after_colon = if (std.mem.indexOf(u8, trimmed, ":")) |idx| trimmed[idx + 2 ..] else "";
            structs = std.fmt.parseInt(usize, std.mem.trim(u8, after_colon, &std.ascii.whitespace), 10) catch 0;
        }
        if (std.mem.indexOf(u8, trimmed, "Enums:") != null) {
            const after_colon = if (std.mem.indexOf(u8, trimmed, ":")) |idx| trimmed[idx + 2 ..] else "";
            enums = std.fmt.parseInt(usize, std.mem.trim(u8, after_colon, &std.ascii.whitespace), 10) catch 0;
        }
        if (std.mem.indexOf(u8, trimmed, "Imports:") != null) {
            const after_colon = if (std.mem.indexOf(u8, trimmed, ":")) |idx| trimmed[idx + 2 ..] else "";
            imports = std.fmt.parseInt(usize, std.mem.trim(u8, after_colon, &std.ascii.whitespace), 10) catch 0;
        }
        if (std.mem.indexOf(u8, trimmed, "version:") != null) {
            const after_colon = if (std.mem.indexOf(u8, trimmed, ":")) |idx| trimmed[idx + 2 ..] else "";
            version = std.mem.trim(u8, after_colon, &std.ascii.whitespace);
        }
    }

    if (total_functions == 0) {
        total_functions = pub_functions + priv_functions;
    }

    // Header
    try spec.appendSlice(std.heap.page_allocator, "name: ");
    try spec.appendSlice(std.heap.page_allocator, module_name);
    try spec.appendSlice(std.heap.page_allocator, "\nversion: \"1.0.0\"\nlanguage: zig\nmodule: ");
    try spec.appendSlice(std.heap.page_allocator, module_name);
    try spec.appendSlice(std.heap.page_allocator, "\n\ndescription: |\n  ");
    try spec.appendSlice(std.heap.page_allocator, "Auto-generated from fossil\n");
    try spec.appendSlice(std.heap.page_allocator, "\n");

    // Types section
    try spec.appendSlice(std.heap.page_allocator, "types:\n");
    try spec.appendSlice(std.heap.page_allocator, "  CompileResult:\n    fields:\n      success: Bool\n      output: String\n");

    if (total_functions > 0) {
        try spec.appendSlice(std.heap.page_allocator, "\nbehaviors:\n");
        var i: usize = 0;
        const max_funcs = if (total_functions < 5) total_functions else 5;
        while (i < max_funcs) : (i += 1) {
            try spec.appendSlice(std.heap.page_allocator, "  - name: fn_");
            const fn_num = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{i});
            try spec.appendSlice(std.heap.page_allocator, fn_num);
            try spec.appendSlice(std.heap.page_allocator, "\n    given: Input\n    when: Execute\n    then: Result\n    description: |\n      Function ");
            try spec.appendSlice(std.heap.page_allocator, fn_num);
            try spec.appendSlice(std.heap.page_allocator, " behavior\n\n");
        }
    }

    // Constants
    try spec.appendSlice(std.heap.page_allocator, "\nconstants:\n");
    try spec.appendSlice(std.heap.page_allocator, "  - SACRED_CONSTANT: 999\n");

    if (total_functions > 0) {
        try spec.appendSlice(std.heap.page_allocator, "  - TOTAL_FUNCTIONS: ");
        const count_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{total_functions});
        try spec.appendSlice(std.heap.page_allocator, count_str);
        try spec.appendSlice(std.heap.page_allocator, "\n");
    }

    return std.heap.page_allocator.dupe(u8, spec.items);
}
