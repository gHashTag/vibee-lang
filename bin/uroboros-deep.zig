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

    // Deep analysis
    var analysis = AnalysisResult{
        .pub_functions = 0,
        .private_functions = 0,
        .structs = 0,
        .enums = 0,
        .imports = 0,
        .magic_numbers = std.ArrayList([]const u8){},
        .line_count = 0,
        .function_names = std.ArrayList([]const u8){},
    };
    defer analysis.magic_numbers.deinit(std.heap.page_allocator);
    defer analysis.function_names.deinit(std.heap.page_allocator);

    // Analyze lines
    var lines = std.mem.splitSequence(u8, file_content, "\n");

    while (lines.next()) |line| {
        analysis.line_count += 1;
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        // Skip comments
        if (std.mem.startsWith(u8, trimmed, "//")) continue;
        if (trimmed.len == 0) continue;

        // Count functions
        if (std.mem.indexOfPos(u8, trimmed, 0, "pub fn ") != null) {
            analysis.pub_functions += 1;
            try extract_function_name(std.heap.page_allocator, &analysis, trimmed);
        } else if (std.mem.indexOfPos(u8, trimmed, 0, "fn ") != null) {
            analysis.private_functions += 1;
            try extract_function_name(std.heap.page_allocator, &analysis, trimmed);
        }

        // Count structs
        if (std.mem.indexOfPos(u8, trimmed, 0, "struct ") != null) {
            analysis.structs += 1;
        }

        // Count enums
        if (std.mem.indexOfPos(u8, trimmed, 0, "enum ") != null) {
            analysis.enums += 1;
        }

        // Count imports
        if (std.mem.indexOfPos(u8, trimmed, 0, "const ") != null) {
            if (std.mem.indexOfPos(u8, trimmed, 5, "@import") != null) {
                analysis.imports += 1;
            }
        }

        // Find magic numbers
        try find_magic_numbers(std.heap.page_allocator, &analysis, trimmed);
    }

    const total_functions = analysis.pub_functions + analysis.private_functions;

    // Create detailed fossil
    const file_name = std.fs.path.basename(file_path);
    const version = try std.fmt.allocPrint(std.heap.page_allocator, "v{d}", .{std.time.timestamp()});
    const timestamp = std.time.timestamp();

    const magic_nums_str = try format_magic_numbers(analysis.magic_numbers.items);

    // Create fossil string
    var fossil = std.ArrayList(u8){};
    defer fossil.deinit(std.heap.page_allocator);

    try fossil.appendSlice(std.heap.page_allocator, "tri_fossil_v");
    const ts_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{timestamp});
    try fossil.appendSlice(std.heap.page_allocator, ts_str);
    try fossil.appendSlice(std.heap.page_allocator, "\n\nfile: ");
    try fossil.appendSlice(std.heap.page_allocator, file_name);
    try fossil.appendSlice(std.heap.page_allocator, "\ntimestamp: ");
    try fossil.appendSlice(std.heap.page_allocator, ts_str);
    try fossil.appendSlice(std.heap.page_allocator, "\nversion: ");
    try fossil.appendSlice(std.heap.page_allocator, version);
    try fossil.appendSlice(std.heap.page_allocator, "\n\n=== STRUCTURAL ANALYSIS ===\n");

    const line_count_str = try std.fmt.allocPrint(std.heap.page_allocator, "Lines: {d}\n", .{analysis.line_count});
    try fossil.appendSlice(std.heap.page_allocator, line_count_str);

    const pub_func_str = try std.fmt.allocPrint(std.heap.page_allocator, "Public functions: {d}\n", .{analysis.pub_functions});
    try fossil.appendSlice(std.heap.page_allocator, pub_func_str);

    const priv_func_str = try std.fmt.allocPrint(std.heap.page_allocator, "Private functions: {d}\n", .{analysis.private_functions});
    try fossil.appendSlice(std.heap.page_allocator, priv_func_str);

    const total_func_str = try std.fmt.allocPrint(std.heap.page_allocator, "Total functions: {d}\n", .{total_functions});
    try fossil.appendSlice(std.heap.page_allocator, total_func_str);

    const structs_str = try std.fmt.allocPrint(std.heap.page_allocator, "Structs: {d}\n", .{analysis.structs});
    try fossil.appendSlice(std.heap.page_allocator, structs_str);

    const enums_str = try std.fmt.allocPrint(std.heap.page_allocator, "Enums: {d}\n", .{analysis.enums});
    try fossil.appendSlice(std.heap.page_allocator, enums_str);

    const imports_str = try std.fmt.allocPrint(std.heap.page_allocator, "Imports: {d}\n", .{analysis.imports});
    try fossil.appendSlice(std.heap.page_allocator, imports_str);

    try fossil.appendSlice(std.heap.page_allocator, "\n=== MAGIC NUMBERS (");
    const magic_count_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{analysis.magic_numbers.items.len});
    try fossil.appendSlice(std.heap.page_allocator, magic_count_str);
    try fossil.appendSlice(std.heap.page_allocator, ") ===\n");
    try fossil.appendSlice(std.heap.page_allocator, magic_nums_str);

    try fossil.appendSlice(std.heap.page_allocator, "\n\n=== FUNCTIONS EXTRACTED (");
    const func_count_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{analysis.function_names.items.len});
    try fossil.appendSlice(std.heap.page_allocator, func_count_str);
    try fossil.appendSlice(std.heap.page_allocator, ") ===\n\nsacred_constant: 999\n");

    // Write fossil
    var file_out = try std.fs.cwd().createFile(output_path, .{});
    defer file_out.close();
    try file_out.writeAll(fossil.items);

    std.debug.print("✓ УРОБОРОС ГЛУБОКО ПОГЛОТИЛ: {s}\n", .{output_path});
    std.debug.print("  Версия: {s}\n", .{version});
    std.debug.print("  Публичных функций: {d}\n", .{analysis.pub_functions});
    std.debug.print("  Приватных функций: {d}\n", .{analysis.private_functions});
    std.debug.print("  Всего функций: {d}\n", .{total_functions});
    std.debug.print("  Структур: {d}\n", .{analysis.structs});
    std.debug.print("  Мигических чисел: {d}\n", .{analysis.magic_numbers.items.len});
    std.debug.print("  Жертва глубоко переварена...\n", .{});
}

const AnalysisResult = struct {
    pub_functions: usize,
    private_functions: usize,
    structs: usize,
    enums: usize,
    imports: usize,
    magic_numbers: std.ArrayList([]const u8),
    line_count: usize,
    function_names: std.ArrayList([]const u8),
};

fn extract_function_name(allocator: std.mem.Allocator, analysis: *AnalysisResult, line: []const u8) !void {
    // Extract function name from "pub fn name(" or "fn name("
    const fn_pos = std.mem.indexOfPos(u8, line, 0, "fn ") orelse return;
    const name_start = fn_pos + 3;

    if (name_start >= line.len) return;

    // Find opening parenthesis
    const paren_pos = std.mem.indexOfPos(u8, line, name_start, "(") orelse return;

    const name = try allocator.dupe(u8, line[name_start..paren_pos]);
    try analysis.function_names.append(allocator, name);
}

fn find_magic_numbers(allocator: std.mem.Allocator, analysis: *AnalysisResult, line: []const u8) !void {
    // Find common magic numbers
    const magic_patterns = &[_][]const u8{ "42", "100", "999", "0x7F", "0xFF", "3.14", "6.28", "1000", "1024" };

    for (magic_patterns) |pattern| {
        if (std.mem.indexOf(u8, line, pattern) != null) {
            const magic = try allocator.dupe(u8, pattern);
            try analysis.magic_numbers.append(allocator, magic);
        }
    }
}

fn format_magic_numbers(numbers: []const []const u8) ![]const u8 {
    if (numbers.len == 0) return "(none)";

    var result = std.ArrayList(u8){};
    defer result.deinit(std.heap.page_allocator);

    for (numbers) |num| {
        try result.appendSlice(std.heap.page_allocator, "  - ");
        try result.appendSlice(std.heap.page_allocator, num);
        try result.appendSlice(std.heap.page_allocator, "\n");
    }

    return std.heap.page_allocator.dupe(u8, result.items);
}
