//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE UNIFIED COMPILER - GENERATED FROM specs/vibee_unified_compiler.vibee
//! ═══════════════════════════════════════════════════════════════════════════════
//! Integrates: Parser V2 + Codegen V3 + PAS Engine V2
//! Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
//! Golden Identity: φ² + 1/φ² = 3
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser_v2 = @import("parser_v2.zig");
const codegen_v3 = @import("codegen_v3.zig");
const pas_engine_v2 = @import("pas_engine_v2.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "2.0.0";
pub const COMPILER_NAME = "vibeec";

/// Verify Golden Identity: φ² + 1/φ² = 3
pub fn verifyGoldenIdentity() bool {
    const result = PHI_SQ + (1.0 / PHI_SQ);
    return @abs(result - GOLDEN_IDENTITY) < 0.0001;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from spec)
// ═══════════════════════════════════════════════════════════════════════════════

pub const OutputTarget = enum {
    zig,
    code999,
    both,
};

pub const CompileOptions = struct {
    input_path: []const u8 = "",
    output_dir: []const u8 = "./generated",
    target: OutputTarget = .both,
    enable_pas: bool = false,
    verbose: bool = false,
    emit_stats: bool = false,
};

pub const ErrorSeverity = enum {
    error_level,
    warning,
    info,
};

pub const CompileError = struct {
    line: u32,
    column: u32,
    message: []const u8,
    severity: ErrorSeverity,
};

pub const PASReport = struct {
    predictions: []const pas_engine_v2.PASPrediction,
    total_speedup: f32,
    avg_confidence: f32,
};

pub const CompileResult = struct {
    spec: parser_v2.Specification,
    zig_code: ?[]const u8,
    code_999: ?[]const u8,
    pas_report: ?PASReport,
    compile_time_ns: u64,
    success: bool,
    errors: []CompileError,
};

pub const CompilerStats = struct {
    files_compiled: u64 = 0,
    total_lines: u64 = 0,
    total_time_ns: u64 = 0,
    cache_hit_ratio: f64 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED COMPILER (from spec)
// ═══════════════════════════════════════════════════════════════════════════════

pub const UnifiedCompiler = struct {
    const Self = @This();

    allocator: Allocator,
    parser: parser_v2.ParserV2,
    codegen: codegen_v3.CodegenV3,
    pas_engine: pas_engine_v2.PASEngineV2,
    stats: CompilerStats,

    pub fn init(allocator: Allocator) !Self {
        return .{
            .allocator = allocator,
            .parser = parser_v2.ParserV2.init(allocator),
            .codegen = try codegen_v3.CodegenV3.init(allocator),
            .pas_engine = try pas_engine_v2.PASEngineV2.init(allocator),
            .stats = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.parser.deinit();
        self.codegen.deinit();
        self.pas_engine.deinit();
    }

    /// Compile .vibee source to target outputs
    pub fn compile(self: *Self, source: []const u8, options: CompileOptions) !CompileResult {
        const start_time = std.time.nanoTimestamp();

        var result = CompileResult{
            .spec = undefined,
            .zig_code = null,
            .code_999 = null,
            .pas_report = null,
            .compile_time_ns = 0,
            .success = false,
            .errors = &[_]CompileError{},
        };

        // 1. Parse
        result.spec = self.parser.parse(source) catch {
            // Error handling - return with empty errors for now
            return result;
        };

        // 2. PAS Analysis (optional)
        if (options.enable_pas) {
            result.pas_report = try self.analyzeWithPAS(&result.spec);
        }

        // 3. Generate code based on target
        switch (options.target) {
            .zig => {
                result.zig_code = try self.codegen.generateZig(&result.spec);
            },
            .code999 => {
                result.code_999 = try self.codegen.generate999(&result.spec);
            },
            .both => {
                result.zig_code = try self.codegen.generateZig(&result.spec);
                result.code_999 = try self.codegen.generate999(&result.spec);
            },
        }

        // Update stats
        const end_time = std.time.nanoTimestamp();
        result.compile_time_ns = @intCast(end_time - start_time);
        result.success = true;

        self.stats.files_compiled += 1;
        self.stats.total_time_ns += result.compile_time_ns;
        self.stats.total_lines += self.parser.stats.lines_parsed;

        return result;
    }

    /// Compile from file path
    pub fn compileFile(self: *Self, path: []const u8, options: CompileOptions) !CompileResult {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(source);

        var opts = options;
        opts.input_path = path;

        return self.compile(source, opts);
    }

    /// Analyze specification with PAS engine
    pub fn analyzeWithPAS(self: *Self, spec: *const parser_v2.Specification) !PASReport {
        var total_speedup: f32 = 1.0;
        var total_confidence: f32 = 0;
        var prediction_count: u32 = 0;

        // Get built-in predictions
        const predictions = self.pas_engine.getBuiltinPredictions();

        // Calculate totals
        for (predictions) |pred| {
            total_speedup *= pred.speedup;
            total_confidence += pred.confidence;
            prediction_count += 1;
        }

        // Also analyze spec-specific patterns
        if (spec.creation_pattern != null) {
            // Creation pattern detected - good for optimization
            const cp_prediction = try self.pas_engine.predict("creation_pattern", "O(1)");
            total_confidence += cp_prediction.confidence;
            prediction_count += 1;
        }

        return .{
            .predictions = predictions,
            .total_speedup = total_speedup,
            .avg_confidence = if (prediction_count > 0) total_confidence / @as(f32, @floatFromInt(prediction_count)) else 0,
        };
    }

    pub fn getStats(self: *const Self) CompilerStats {
        return self.stats;
    }

    /// Print compilation summary
    pub fn printSummary(_: *const Self, result: *const CompileResult, writer: anytype) !void {
        try writer.print("\n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try writer.print("VIBEE COMPILER V{s} - COMPILATION SUMMARY\n", .{VERSION});
        try writer.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try writer.print("Specification: {s}\n", .{result.spec.name});
        try writer.print("Version: {s}\n", .{result.spec.version});
        try writer.print("Success: {}\n", .{result.success});
        try writer.print("Compile time: {d:.2}ms\n", .{@as(f64, @floatFromInt(result.compile_time_ns)) / 1_000_000.0});

        if (result.zig_code) |code| {
            try writer.print("Zig code: {} bytes\n", .{code.len});
        }
        if (result.code_999) |code| {
            try writer.print(".999 code: {} bytes\n", .{code.len});
        }

        if (result.pas_report) |report| {
            try writer.print("\nPAS Analysis:\n", .{});
            try writer.print("  Total speedup: {d:.1}x\n", .{report.total_speedup});
            try writer.print("  Avg confidence: {d:.0}%\n", .{report.avg_confidence * 100});
        }

        try writer.print("\nφ² + 1/φ² = 3\n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Golden Identity verification" {
    try std.testing.expect(verifyGoldenIdentity());
}

test "UnifiedCompiler init/deinit" {
    var compiler = try UnifiedCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    try std.testing.expectEqualStrings(VERSION, "2.0.0");
}

test "UnifiedCompiler compile minimal spec" {
    var compiler = try UnifiedCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
        \\language: zig
        \\module: test_module
    ;

    const result = try compiler.compile(source, .{});

    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("test", result.spec.name);
    try std.testing.expect(result.zig_code != null);
    try std.testing.expect(result.code_999 != null);
}

test "UnifiedCompiler compile with creation_pattern" {
    var compiler = try UnifiedCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
        \\creation_pattern:
        \\  source: Input
        \\  transformer: Transform
        \\  result: Output
    ;

    const result = try compiler.compile(source, .{});

    try std.testing.expect(result.success);
    try std.testing.expect(result.spec.hasCreationPattern());
}

test "UnifiedCompiler compile with behaviors" {
    var compiler = try UnifiedCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
        \\behaviors:
        \\  - name: test_behavior
        \\    given: precondition
        \\    when: action
        \\    then: result
    ;

    const result = try compiler.compile(source, .{});

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(usize, 1), result.spec.getBehaviorCount());
}

test "UnifiedCompiler with PAS analysis" {
    var compiler = try UnifiedCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
        \\creation_pattern:
        \\  source: Input
        \\  transformer: Transform
        \\  result: Output
    ;

    const result = try compiler.compile(source, .{ .enable_pas = true });

    try std.testing.expect(result.success);
    try std.testing.expect(result.pas_report != null);
    try std.testing.expect(result.pas_report.?.total_speedup > 1.0);
}

test "UnifiedCompiler target zig only" {
    var compiler = try UnifiedCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
    ;

    const result = try compiler.compile(source, .{ .target = .zig });

    try std.testing.expect(result.success);
    try std.testing.expect(result.zig_code != null);
    try std.testing.expect(result.code_999 == null);
}

test "UnifiedCompiler target 999 only" {
    var compiler = try UnifiedCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
    ;

    const result = try compiler.compile(source, .{ .target = .code999 });

    try std.testing.expect(result.success);
    try std.testing.expect(result.zig_code == null);
    try std.testing.expect(result.code_999 != null);
}
