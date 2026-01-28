// VIBEE VALIDATOR ORCHESTRATOR - Runs all 33 Bogatyrs
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("bogatyrs_common.zig");
const registry_mod = @import("bogatyrs_registry.zig");

pub const ValidatorReport = struct {
    verdict: interface.BogatyrVerdict,
    total_errors: usize,
    errors: []const interface.ValidationError,
    total_duration_ns: i64,
    bogatyrs_executed: usize,
};

pub const ValidatorEngine = struct {
    allocator: Allocator,
    registry: *registry_mod.BogatyrRegistry,
    config: *const interface.ValidatorConfig,

    pub fn init(allocator: Allocator, config: *const interface.ValidatorConfig) !ValidatorEngine {
        const registry = try allocator.create(registry_mod.BogatyrRegistry);
        try registry.init(allocator);

        return ValidatorEngine{
            .allocator = allocator,
            .registry = registry,
            .config = config,
        };
    }

    pub fn deinit(self: *ValidatorEngine) void {
        self.allocator.destroy(self.registry);
    }

    pub fn validate(self: *ValidatorEngine, spec_path: []const u8) !ValidatorReport {
        const start_time = std.time.nanoTimestamp();

        const source = try std.fs.cwd().readFileAlloc(self.allocator, spec_path, 1024 * 1024);
        defer self.allocator.free(source);

        const plugins = try self.registry.getAllPlugins();
        defer self.allocator.free(plugins);

        var all_errors = std.ArrayList(interface.ValidationError).init(self.allocator);
        defer {
            for (all_errors.items) |err| {
                self.allocator.free(err.code);
                self.allocator.free(err.message);
            }
            all_errors.deinit();
        }

        const plugin_count = plugins.len;
        for (plugins) |plugin| {
            const context = interface.ValidationContext{
                .allocator = self.allocator,
                .spec_path = spec_path,
                .source = source,
                .config = self.config.*,
                .ast = null,
                .symbol_table = null,
            };

            const result = plugin.validate(&context) catch |err| {
                try all_errors.append(try interface.createError(self.allocator, "bogatyr_execution_error", err.message, 0, 0));
                continue;
            };

            for (result.errors) |err| {
                try all_errors.append(err);
            }
        }

        const end_time = std.time.nanoTimestamp();
        const errors_slice = try self.allocator.dupe(interface.ValidationError, all_errors.items);

        const verdict = if (all_errors.items.len > 0) .Fail else .Pass;

        return ValidatorReport{
            .verdict = verdict,
            .total_errors = all_errors.items.len,
            .errors = errors_slice,
            .total_duration_ns = end_time - start_time,
            .bogatyrs_executed = plugin_count,
        };
    }

    pub fn printReport(self: *const ValidatorEngine, report: *const ValidatorReport, spec_path: []const u8) !void {
        _ = self;

        const stdout = std.io.getStdOut().writer();

        try stdout.print("╔══════════════════════════════════════════════════════════════════════════╗\n", .{});
        try stdout.print("║              VIBEE VALIDATION REPORT                         ║\n", .{});
        try stdout.print("╚═════════════════════════════════════════════════════╝\n\n", .{});

        try stdout.print("📊 SUMMARY:\n", .{});
        try stdout.print("  Verdict: {s}\n", .{switch (report.verdict) {
            .Pass => "✅ PASS",
            .Fail => "❌ FAIL",
            .Warning => "⚠️ WARNING",
            .Skip => "⊘ SKIP",
        }});
        try stdout.print("  Bogatyrs Executed: {}\n", .{report.bogatyrs_executed});
        try stdout.print("  Total Errors: {}\n", .{report.total_errors});
        try stdout.print("  Duration: {}ms\n\n", .{@divTrunc(report.total_duration_ns, 1_000_000)});

        if (report.errors.len > 0) {
            try stdout.print("❌ ERRORS:\n", .{});
            for (report.errors) |err| {
                try stdout.print("  [{s}:{d}:{d}] {s}: {s}\n", .{
                    spec_path,
                    err.line,
                    err.column,
                    err.code,
                    err.message,
                });
            }
            try stdout.print("\n", .{});
        }
    }
};

test "validator engine initialization" {
    const allocator = std.testing.allocator;
    const config = interface.ValidatorConfig{};

    var engine = try ValidatorEngine.init(allocator, &config);
    defer engine.deinit();

    const count = engine.registry.pluginCount();
    try std.testing.expect(count >= 0);
}
