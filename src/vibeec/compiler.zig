// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC UNIFIED COMPILER V35
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V35 - Complete VIBEE Compiler Pipeline
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Components: Parser V3 + Codegen V4 + Type Checker + Error Reporter + CLI
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// Import all compiler components
const parser = @import("parser_v3.zig");
const codegen = @import("codegen_v4.zig");
const type_checker = @import("type_checker.zig");
const error_reporter = @import("error_reporter.zig");
const cli = @import("cli.zig");
const ast_mod = @import("ast.zig");
const semantic = @import("semantic.zig");
const bytecode = @import("bytecode.zig");
const optimizer = @import("optimizer.zig");
const vm_runtime = @import("vm_runtime.zig");
const jit = @import("jit.zig");
const repl = @import("repl.zig");
const lsp = @import("lsp.zig");

// Re-export types
pub const ParserV3 = parser.ParserV3;
pub const Specification = parser.Specification;
pub const CodegenV4 = codegen.CodegenV4;
pub const OutputTarget = codegen.OutputTarget;
pub const TypeChecker = type_checker.TypeChecker;
pub const ErrorReporter = error_reporter.ErrorReporter;
pub const ColorWriter = error_reporter.ColorWriter;
pub const Color = error_reporter.Color;
pub const CLI = cli.CLI;

// V37 Components
pub const Ast = ast_mod.Ast;
pub const AstBuilder = ast_mod.AstBuilder;
pub const SemanticAnalyzer = semantic.SemanticAnalyzer;
pub const SymbolTable = semantic.SymbolTable;
pub const BytecodeEmitter = bytecode.BytecodeEmitter;
pub const Opcode = bytecode.Opcode;
pub const Optimizer = optimizer.Optimizer;
pub const EGraph = optimizer.EGraph;
pub const VM = vm_runtime.VM;
pub const JITCompiler = jit.JITCompiler;
pub const REPL = repl.REPL;
pub const LSPServer = lsp.LSPServer;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const VERSION = "35.0.0";
pub const COMPILER_NAME = "vibeec";

// ═══════════════════════════════════════════════════════════════════════════════
// COMPILE OPTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const CompileOptions = struct {
    target: OutputTarget = .both,
    output_dir: []const u8 = "./generated",
    enable_type_check: bool = true,
    enable_pas: bool = false,
    verbose: bool = false,
    use_color: bool = true,
    max_errors: u32 = 20,
    warnings_as_errors: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMPILE RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const CompileResult = struct {
    success: bool,
    spec: ?Specification,
    zig_code: ?[]const u8,
    code999: ?[]const u8,
    metrics: CompileMetrics,
    allocator: Allocator,

    pub fn deinit(self: *CompileResult) void {
        if (self.spec) |*s| s.deinit();
        if (self.zig_code) |code| self.allocator.free(code);
        if (self.code999) |code| self.allocator.free(code);
    }
};

pub const CompileMetrics = struct {
    parse_time_ns: u64,
    type_check_time_ns: u64,
    codegen_time_ns: u64,
    total_time_ns: u64,
    lines_parsed: u64,
    types_checked: u64,
    types_generated: u64,
    functions_generated: u64,
    tests_generated: u64,
    zig_bytes: usize,
    code999_bytes: usize,
    error_count: u32,
    warning_count: u32,

    pub fn totalTimeMs(self: CompileMetrics) f64 {
        return @as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000.0;
    }

    pub fn throughputLinesPerSec(self: CompileMetrics) f64 {
        if (self.total_time_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.lines_parsed)) * 1_000_000_000.0 / @as(f64, @floatFromInt(self.total_time_ns));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Compiler = struct {
    allocator: Allocator,
    parser: ParserV3,
    type_checker: TypeChecker,
    options: CompileOptions,

    // Statistics
    files_compiled: u64,
    total_lines: u64,
    total_time_ns: u64,

    const Self = @This();

    pub fn init(allocator: Allocator, options: CompileOptions) Self {
        return Self{
            .allocator = allocator,
            .parser = ParserV3.init(allocator),
            .type_checker = TypeChecker.init(allocator),
            .options = options,
            .files_compiled = 0,
            .total_lines = 0,
            .total_time_ns = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.parser.deinit();
        self.type_checker.deinit();
    }

    pub fn compile(self: *Self, source: []const u8) !CompileResult {
        const start_time = std.time.nanoTimestamp();
        var metrics = CompileMetrics{
            .parse_time_ns = 0,
            .type_check_time_ns = 0,
            .codegen_time_ns = 0,
            .total_time_ns = 0,
            .lines_parsed = 0,
            .types_checked = 0,
            .types_generated = 0,
            .functions_generated = 0,
            .tests_generated = 0,
            .zig_bytes = 0,
            .code999_bytes = 0,
            .error_count = 0,
            .warning_count = 0,
        };

        // Phase 1: Parse
        const parse_start = std.time.nanoTimestamp();
        var spec = self.parser.parse(source) catch {
            return CompileResult{
                .success = false,
                .spec = null,
                .zig_code = null,
                .code999 = null,
                .metrics = metrics,
                .allocator = self.allocator,
            };
        };
        const parse_end = std.time.nanoTimestamp();
        metrics.parse_time_ns = @intCast(parse_end - parse_start);
        metrics.lines_parsed = self.parser.lines_parsed;

        // Phase 2: Type Check
        if (self.options.enable_type_check) {
            const tc_start = std.time.nanoTimestamp();
            var tc_result = try self.type_checker.check(&spec);
            defer tc_result.deinit();
            const tc_end = std.time.nanoTimestamp();
            metrics.type_check_time_ns = @intCast(tc_end - tc_start);
            metrics.types_checked = self.type_checker.types_checked;

            if (!tc_result.success) {
                metrics.error_count = @intCast(tc_result.errors.items.len);
            }
        }

        // Phase 3: Code Generation
        const cg_start = std.time.nanoTimestamp();
        var cg = try CodegenV4.init(self.allocator, self.options.target);
        defer cg.deinit();

        const gen_result = try cg.generate(&spec);
        const cg_end = std.time.nanoTimestamp();
        metrics.codegen_time_ns = @intCast(cg_end - cg_start);

        // Collect codegen metrics
        metrics.types_generated = gen_result.metrics.types_generated;
        metrics.functions_generated = gen_result.metrics.functions_generated;
        metrics.tests_generated = gen_result.metrics.tests_generated;
        metrics.zig_bytes = gen_result.metrics.zig_bytes;
        metrics.code999_bytes = gen_result.metrics.code999_bytes;

        // Total time
        const end_time = std.time.nanoTimestamp();
        metrics.total_time_ns = @intCast(end_time - start_time);

        // Update statistics
        self.files_compiled += 1;
        self.total_lines += metrics.lines_parsed;
        self.total_time_ns += metrics.total_time_ns;

        return CompileResult{
            .success = metrics.error_count == 0,
            .spec = spec,
            .zig_code = gen_result.zig_code,
            .code999 = gen_result.code999,
            .metrics = metrics,
            .allocator = self.allocator,
        };
    }

    pub fn compileFile(self: *Self, path: []const u8) !CompileResult {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(source);

        return self.compile(source);
    }

    pub fn getStats(self: Self) CompilerStats {
        return .{
            .files_compiled = self.files_compiled,
            .total_lines = self.total_lines,
            .total_time_ns = self.total_time_ns,
        };
    }
};

pub const CompilerStats = struct {
    files_compiled: u64,
    total_lines: u64,
    total_time_ns: u64,

    pub fn avgTimePerFileMs(self: CompilerStats) f64 {
        if (self.files_compiled == 0) return 0;
        return @as(f64, @floatFromInt(self.total_time_ns)) / @as(f64, @floatFromInt(self.files_compiled)) / 1_000_000.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cli_instance = CLI.init(allocator, null);
    return cli_instance.run(args);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Compiler full pipeline" {
    const allocator = std.testing.allocator;

    var compiler = Compiler.init(allocator, .{});
    defer compiler.deinit();

    const source =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
        \\module: test
        \\
        \\sacred_formula:
        \\  equation: V = n × 3^k × π^m × φ^p × e^q
        \\  golden_identity: φ² + 1/φ² = 3
        \\  self_evolution: enabled
        \\
        \\creation_pattern:
        \\  source: Input
        \\  transformer: Process
        \\  result: Output
        \\
        \\behaviors:
        \\  - name: test_behavior
        \\    given: precondition
        \\    when: action
        \\    then: result
        \\
        \\types:
        \\  - name: TestStruct
        \\    kind: struct
    ;

    var result = try compiler.compile(source);
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expect(result.zig_code != null);
    try std.testing.expect(result.code999 != null);
    try std.testing.expect(result.metrics.lines_parsed > 0);
    try std.testing.expect(result.metrics.total_time_ns > 0);
}

test "Compiler metrics" {
    const allocator = std.testing.allocator;

    var compiler = Compiler.init(allocator, .{});
    defer compiler.deinit();

    const source =
        \\name: metrics_test
        \\version: "1.0.0"
    ;

    var result = try compiler.compile(source);
    defer result.deinit();

    const metrics = result.metrics;
    try std.testing.expect(metrics.parse_time_ns > 0);
    try std.testing.expect(metrics.codegen_time_ns > 0);
    try std.testing.expect(metrics.totalTimeMs() > 0);
}

test "Compiler stats" {
    const allocator = std.testing.allocator;

    var compiler = Compiler.init(allocator, .{});
    defer compiler.deinit();

    const source = "name: test\nversion: 1.0.0";

    var result1 = try compiler.compile(source);
    defer result1.deinit();

    var result2 = try compiler.compile(source);
    defer result2.deinit();

    const stats = compiler.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.files_compiled);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

test "sacred constants" {
    try std.testing.expectApproxEqAbs(1.618033988749895, PHI, 0.0000001);
    try std.testing.expectApproxEqAbs(2.618033988749895, PHI_SQ, 0.0000001);
    try std.testing.expectApproxEqAbs(3.0, GOLDEN_IDENTITY, 0.0001);
}
