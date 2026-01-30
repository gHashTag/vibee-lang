// VIBEE BOGATYR - Spec Structure Validator
// Проверяет структуру .vibee спецификации
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const common = @import("bogatyrs_common.zig");

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

    var error_count: usize = 0;

    var has_name = false;
    var has_version = false;
    var has_language = false;
    var has_module = false;

    var lines = std.mem.splitScalar(u8, ctx.source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
            const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");

            if (std.mem.eql(u8, key, "name")) has_name = true;
            if (std.mem.eql(u8, key, "version")) has_version = true;
            if (std.mem.eql(u8, key, "language")) has_language = true;
            if (std.mem.eql(u8, key, "module")) has_module = true;
        }
    }

    if (!has_name) error_count += 1;
    if (!has_version) error_count += 1;
    if (!has_language) error_count += 1;
    if (!has_module) error_count += 1;

    const end_time = std.time.nanoTimestamp();

    const verdict: common.BogatyrVerdict = if (error_count > 0) .Fail else .Pass;

    return common.BogatyrResult{
        .verdict = verdict,
        .errors = try allocator.dupe(common.ValidationError, &[_]common.ValidationError{}),
        .metrics = common.BogatyrMetrics{
            .duration_ns = end_time - start_time,
            .checks_performed = error_count,
        },
    };
}

test "spec structure - valid spec" {
    const allocator = std.testing.allocator;

    const valid_spec =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
        \\module: test_spec
    ;

    const ctx = common.ValidationContext{
        .allocator = allocator,
        .spec_path = "test.vibee",
        .source = valid_spec,
        .config = .{},
        .ast = null,
        .symbol_table = null,
    };

    const result = try validateSpecStructure(&ctx);

    allocator.free(result.errors);

    try std.testing.expectEqual(common.BogatyrVerdict.Pass, result.verdict);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
