// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE SPECIFICATION VALIDATOR - Simple Version for CLI
// φ² + 1/φ² = 3 | GOLDEN KEY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    line: usize,
};

pub fn validateSpec(source: []const u8, file_path: []const u8) ![]const ValidationError {
    var errors = try std.ArrayList(ValidationError).initCapacity(std.heap.page_allocator, 16);
    defer errors.deinit(std.heap.page_allocator);

    var line_num: usize = 1;
    var has_output = false;
    var has_module = false;
    var has_name = false;
    var has_version = false;
    var has_language = false;

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
            const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");

            if (std.mem.eql(u8, key, "name")) has_name = true;
            if (std.mem.eql(u8, key, "version")) has_version = true;
            if (std.mem.eql(u8, key, "language")) has_language = true;
            if (std.mem.eql(u8, key, "module")) has_module = true;
            if (std.mem.eql(u8, key, "output")) has_output = true;
        }

        line_num += 1;
    }

    // Check 1: Mandatory output: key
    if (!has_output) {
        try errors.append(std.heap.page_allocator, .{
            .code = "missing_output",
            .message = "❌ Missing mandatory 'output:' key",
            .line = 1,
        });
    }

    // Check 2: Root folder forbidden
    const tri_idx = std.mem.indexOf(u8, file_path, "specs/tri/") orelse 0;
    if (tri_idx != 0) {
        const after_tri = file_path[tri_idx + "specs/tri/".len ..];
        if (std.mem.indexOfScalar(u8, after_tri, '/') == null) {
            try errors.append(std.heap.page_allocator, .{
                .code = "root_folder",
                .message = "❌ Spec must be in subfolder (core/, compiler/, runtime/, etc.)",
                .line = 1,
            });
        }
    }

    // Check 3: Duplicate .tri files
    if (std.mem.endsWith(u8, file_path, ".tri")) {
        try errors.append(std.heap.page_allocator, .{
            .code = "duplicate_tri",
            .message = "❌ .tri files not allowed (use .vibee only)",
            .line = 1,
        });
    }

    if (errors.items.len > 0) {
        // Return slice of errors (valid since page allocator won't free immediately)
        return try std.heap.page_allocator.dupe(ValidationError, errors.items);
    }

    return &.{};
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runValidation(args: []const []const u8) !u8 {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    if (args.len < 2) {
        try stdout.print("Usage: vibee validate <spec.vibee>\n", .{});
        try stdout.print("       vibee validate-specs       # Validate all specs\n", .{});
        return 1;
    }

    const file_path = args[1];

    const source = std.fs.cwd().readFileAlloc(std.heap.page_allocator, file_path, 1024 * 1024) catch |err| {
        try stdout.print("❌ Error reading file: {}\n   Path: {s}\n", .{ err, file_path });
        return 1;
    };
    defer std.heap.page_allocator.free(source);

    const errors = try validateSpec(source, file_path);

    if (errors.len > 0) {
        try stdout.print("\n╔══════════════════════════════════════════════════════════════════╗\n", .{});
        try stdout.print("║              VIBEE SPECIFICATION VALIDATION ERRORS               ║\n", .{});
        try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n\n", .{});

        for (errors) |err| {
            try stdout.print("{s}\n\n", .{err.message});
        }

        try stdout.print("❌ Validation FAILED\n", .{});
        return 1;
    }

    try stdout.print("✅ Spec validation PASSED\n", .{});
    return 0;
}
