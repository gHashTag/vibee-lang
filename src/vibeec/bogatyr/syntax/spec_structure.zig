// VIBEE BOGATYR - Spec Structure Validator
// Проверяет структуру .vibee спецификации
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const common = @import("../../bogatyrs.zig");

const NAME = "spec_structure";
const VERSION = "1.0.0";
const CATEGORY = "syntax";
const PRIORITY = 1;

pub const bogatyr = common.BogatyrPlugin{
    .name = NAME,
    .version = VERSION,
    .category = CATEGORY,
    .priority = PRIORITY,
    .validate = validateSpecStructure,
};

fn validateSpecStructure(ctx: *const common.ValidationContext) !common.BogatyrResult {
    const start_time = std.time.nanoTimestamp();
    const allocator = ctx.allocator;

    var errors = std.ArrayList(common.ValidationError).init(allocator);
    defer errors.deinit();

    var checks: usize = 0;
    var line_num: usize = 0;

    var lines = std.mem.splitScalar(u8, ctx.source, '\n');
    while (lines.next()) |line| {
        line_num += 1;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        checks += 1;

        // Проверяем обязательные ключи
        if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
            const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");

            // Проверяем что ключи присутствуют
            if (std.mem.eql(u8, key, "name") or
                std.mem.eql(u8, key, "version") or
                std.mem.eql(u8, key, "language") or
                std.mem.eql(u8, key, "module") or
                std.mem.eql(u8, key, "output"))
            {
                // Ключ найден
            }
        }
    }

    // Проверяем наличие обязательных полей
    var has_name = false;
    var has_version = false;
    var has_language = false;
    var has_module = false;
    var has_types = false;
    var has_behaviors = false;

    lines = std.mem.splitScalar(u8, ctx.source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
            const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");

            if (std.mem.eql(u8, key, "name")) has_name = true;
            if (std.mem.eql(u8, key, "version")) has_version = true;
            if (std.mem.eql(u8, key, "language")) has_language = true;
            if (std.mem.eql(u8, key, "module")) has_module = true;
            if (std.mem.eql(u8, key, "types")) has_types = true;
            if (std.mem.eql(u8, key, "behaviors")) has_behaviors = true;
        }
    }

    // Отчет об ошибках
    if (!has_name) {
        try errors.append(try common.createError(allocator, "missing_name", "Missing required 'name' field", 1, 0));
    }

    if (!has_version) {
        try errors.append(try common.createError(allocator, "missing_version", "Missing required 'version' field", 1, 0));
    }

    if (!has_language) {
        try errors.append(try common.createError(allocator, "missing_language", "Missing required 'language' field", 1, 0));
    }

    if (!has_module) {
        try errors.append(try common.createError(allocator, "missing_module", "Missing required 'module' field", 1, 0));
    }

    if (!has_types and !has_behaviors) {
        try errors.append(try common.createError(allocator, "missing_content", "Must have at least 'types' or 'behaviors' section", 1, 0));
    }

    const end_time = std.time.nanoTimestamp();

    const verdict: common.BogatyrVerdict = if (errors.items.len > 0) .Fail else .Pass;

    return common.BogatyrResult{
        .verdict = verdict,
        .errors = try allocator.dupe(common.ValidationError, errors.items),
        .metrics = common.BogatyrMetrics{
            .duration_ns = end_time - start_time,
            .checks_performed = checks,
        },
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "spec structure validation - valid spec" {
    const allocator = std.testing.allocator;

    const valid_spec =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
        \\module: test_spec
        \\
        \\types:
        \\  TestType:
        \\    fields:
        \\      name: String
    ;

    const ctx = common.ValidationContext{
        .allocator = allocator,
        .spec_path = "test_spec.vibee",
        .source = valid_spec,
        .config = .{},
        .ast = null,
        .symbol_table = null,
    };

    const result = try validateSpecStructure(&ctx);

    defer {
        for (result.errors) |err| {
            allocator.free(err.code);
            allocator.free(err.message);
        }
        allocator.free(result.errors);
    }

    try std.testing.expectEqual(common.BogatyrVerdict.Pass, result.verdict);
    try std.testing.expectEqual(@as(usize, 0), result.errors.len);
}
