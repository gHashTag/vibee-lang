// VIBEE BOGATYR - YAML Syntax Validator
// Проверяет YAML синтаксис .vibee файла
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const common = @import("bogatyrs_common.zig");

const NAME = "yaml_syntax";
const VERSION = "1.0.0";
const CATEGORY = "syntax";
const PRIORITY = 0;

pub const bogatyr = common.BogatyrPlugin{
    .name = NAME,
    .version = VERSION,
    .category = CATEGORY,
    .priority = PRIORITY,
    .validate = validateYAMLSyntax,
};

fn validateYAMLSyntax(ctx: *const common.ValidationContext) !common.BogatyrResult {
    const start_time = std.time.nanoTimestamp();
    const allocator = ctx.allocator;

    var error_count: usize = 0;
    var line_num: usize = 0;

    var lines = std.mem.splitScalar(u8, ctx.source, '\n');
    while (lines.next()) |line| {
        line_num += 1;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        if (trimmed[0] == '#') continue;

        if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
            const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");

            if (key.len > 0) {
                const first_char = key[0];
                if (first_char >= '0' and first_char <= '9') {
                    error_count += 1;
                }
            }
        }
    }

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

test "yaml syntax - valid yaml" {
    const allocator = std.testing.allocator;

    const valid_yaml =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
    ;

    const ctx = common.ValidationContext{
        .allocator = allocator,
        .spec_path = "test.vibee",
        .source = valid_yaml,
        .config = .{},
        .ast = null,
        .symbol_table = null,
    };

    const result = try validateYAMLSyntax(&ctx);

    allocator.free(result.errors);

    try std.testing.expectEqual(common.BogatyrVerdict.Pass, result.verdict);
}

test "yaml syntax - invalid key start" {
    const allocator = std.testing.allocator;

    const invalid_yaml =
        \\1name: test_spec
        \\version: "1.0.0"
        \\language: zig
    ;

    const ctx = common.ValidationContext{
        .allocator = allocator,
        .spec_path = "test.vibee",
        .source = invalid_yaml,
        .config = .{},
        .ast = null,
        .symbol_table = null,
    };

    const result = try validateYAMLSyntax(&ctx);

    allocator.free(result.errors);

    try std.testing.expectEqual(common.BogatyrVerdict.Fail, result.verdict);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
