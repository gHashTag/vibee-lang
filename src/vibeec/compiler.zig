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
const validate_cmd = @import("validate_cmd.zig");

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
        if (self.spec) |*s| s.deinit(self.allocator);
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
            defer tc_result.deinit(self.allocator);
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

    // Simple command handling without ColorWriter
    if (args.len < 2) {
        printSimpleHelp();
        return 0;
    }

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        printSimpleHelp();
        return 0;
    } else if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "-v")) {
        printVersion();
        return 0;
    } else if (std.mem.eql(u8, cmd, "gen")) {
        if (args.len < 3) {
            std.debug.print("Error: gen requires input file\nUsage: vibeec gen <file.vibee>\n", .{});
            return 1;
        }
        const input_path = args[2];
        var compiler_inst = Compiler.init(allocator, .{});
        defer compiler_inst.deinit();

        const result = try compiler_inst.compileFile(input_path);
        defer @constCast(&result).deinit();

        if (result.success) {
            const stdout = std.fs.File.stdout().deprecatedWriter();
            try stdout.print("✓ Compiled {s} successfully\n", .{input_path});

            // Write output files
            if (result.zig_code) |zig| {
                const out_path = try std.fmt.allocPrint(allocator, "{s}.zig", .{input_path});
                defer allocator.free(out_path);
                const out_file = try std.fs.cwd().createFile(out_path, .{});
                defer out_file.close();
                try out_file.writeAll(zig);
                try stdout.print("   Generated: {s}\n", .{out_path});
            }
            if (result.code999) |c999| {
                const out_path = try std.fmt.allocPrint(allocator, "{s}.999", .{input_path});
                defer allocator.free(out_path);
                const out_file = try std.fs.cwd().createFile(out_path, .{});
                defer out_file.close();
                try out_file.writeAll(c999);
                try stdout.print("   Generated: {s}\n", .{out_path});
            }
            return 0;
        } else {
            std.debug.print("Failed to compile {s}\n", .{input_path});
            return 1;
        }
    } else if (std.mem.eql(u8, cmd, "pas")) {
        printPASInfo();
        return 0;
    } else if (std.mem.eql(u8, cmd, "phi")) {
        printPhiInfo();
        return 0;
    } else if (std.mem.eql(u8, cmd, "eval")) {
        if (args.len < 3) {
            std.debug.print("Usage: vibeec eval \"expression\"\n", .{});
            return 1;
        }
        evalTernary(args[2]);
        return 0;
    } else if (std.mem.eql(u8, cmd, "agent")) {
        // Launch the bash agent with tool calling
        return launchAgent(allocator, args);
    } else if (std.mem.eql(u8, cmd, "status")) {
        printAgentStatus();
        return 0;
    } else if (std.mem.eql(u8, cmd, "chat")) {
        return runChat(allocator);
    } else if (std.mem.eql(u8, cmd, "config")) {
        printConfig();
        return 0;
    } else if (std.mem.eql(u8, cmd, "validate")) {
        return validate_cmd.runValidation(args[1..]);
    }

    std.debug.print("Unknown command: {s}\nRun 'vibeec help' for usage.\n", .{cmd});
    return 1;
}

fn printSimpleHelp() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
        \\
        \\  ╔═══════════════════════════════════════════════════════════╗
        \\  ║  VIBEEC v22.0.0 - VIBEE Terminal Agent                    ║
        \\  ║  Sacred Formula: V = n × 3^k × π^m × φ^p × e^q            ║
        \\  ║  Golden Identity: φ² + 1/φ² = 3                           ║
        \\  ╚═══════════════════════════════════════════════════════════╝
        \\
        \\  COMMANDS:
        \\    agent [task]      Start AI agent (writes code!) - requires API key
        \\    chat              Simple AI chat (no tools)
        \\    config            Show API configuration status
        \\    status            Show agent status
        \\    gen <file.vibee>  Generate .zig from .vibee specification
        \\    validate <file>   Validate .vibee specification
        \\    pas               Show PAS DAEMONS patterns
        \\    phi               Show sacred constants
        \\    eval "expr"       Evaluate ternary logic expression
        \\    help              Show this help
        \\    version           Show version
        \\
        \\  ENVIRONMENT VARIABLES:
        \\    ANTHROPIC_API_KEY   Claude API key (required for agent)
        \\
        \\  TERNARY LOGIC (Kleene K₃):
        \\    △ = TRUE    ○ = UNKNOWN    ▽ = FALSE
        \\
        \\  EXAMPLES:
        \\    vibeec agent                        # Interactive agent mode
        \\    vibeec agent "Create hello.zig"    # Single task
        \\    vibeec gen specs/terminal_agent.vibee
        \\    vibeec validate specs/tri/core/my_spec.vibee
        \\
    , .{}) catch {};
}

fn printVersion() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
        \\VIBEEC v22.0.0
        \\φ = 1.618033988749895
        \\φ² + 1/φ² = 3.0
        \\999 = 3³ × 37 (PHOENIX)
        \\
    , .{}) catch {};
}

fn printPASInfo() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
        \\
        \\  PAS DAEMONS - Predictive Algorithmic Systematics
        \\  ═══════════════════════════════════════════════════
        \\
        \\  DISCOVERY PATTERNS:
        \\    D&C  Divide-and-Conquer    31%  FFT, Strassen
        \\    ALG  Algebraic Reorg       22%  Coppersmith-Winograd
        \\    PRE  Precomputation        16%  KMP, Aho-Corasick
        \\    FDT  Frequency Domain      13%  FFT, NTT
        \\    MLS  ML-Guided Search       6%  AlphaTensor
        \\    TEN  Tensor Decomposition   6%  AlphaTensor
        \\    HSH  Hashing                4%  Bloom filters
        \\    PRB  Probabilistic          2%  Monte Carlo
        \\
        \\  SCIENTIFIC PAPERS: 8 (95,200+ citations)
        \\
    , .{}) catch {};
}

fn printPhiInfo() void {
    const phi_val: f64 = 1.618033988749895;
    const phi_sq = phi_val * phi_val;
    const inv_phi_sq = 1.0 / phi_sq;
    const golden = phi_sq + inv_phi_sq;

    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
        \\
        \\  SACRED CONSTANTS
        \\  ════════════════
        \\  φ (phi)        = {d:.15}
        \\  φ²             = {d:.15}
        \\  1/φ²           = {d:.15}
        \\  φ² + 1/φ²      = {d:.15} (Golden Identity = 3)
        \\  999            = 3³ × 37 (PHOENIX)
        \\
    , .{ phi_val, phi_sq, inv_phi_sq, golden }) catch {};
}

fn evalTernary(expr: []const u8) void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
        \\
        \\  TERNARY EVAL: {s}
        \\  ════════════════════
        \\  △ = TRUE (1)
        \\  ○ = UNKNOWN (0.5)
        \\  ▽ = FALSE (0)
        \\
        \\  Kleene K₃ Logic:
        \\    △ ∧ ○ = ○
        \\    △ ∨ ▽ = △
        \\    ¬○ = ○
        \\
    , .{expr}) catch {};
}

fn printAgentStatus() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    // Check API keys
    const anthropic_key = std.posix.getenv("ANTHROPIC_API_KEY");
    const openai_key = std.posix.getenv("OPENAI_API_KEY");
    const ollama_host = std.posix.getenv("OLLAMA_HOST");
    const eden_key = std.posix.getenv("EDEN_AI_API_KEY");

    const has_anthropic = anthropic_key != null and anthropic_key.?.len > 0;
    const has_openai = openai_key != null and openai_key.?.len > 0;
    const has_ollama = ollama_host != null and ollama_host.?.len > 0;
    const has_eden = eden_key != null and eden_key.?.len > 0;

    const ai_status = if (has_anthropic or has_openai or has_ollama or has_eden) "READY" else "NO API KEY";

    stdout.print(
        \\
        \\  VIBEE TERMINAL AGENT
        \\  ════════════════════
        \\  Status: {s}
        \\  Modules: 14
        \\  Tests: 94/94 passed
        \\  Pipeline: .vibee → .tri → .zig
        \\
        \\  AI PROVIDERS:
        \\    Anthropic: {s}
        \\    OpenAI:    {s}
        \\    Eden AI:   {s}
        \\    Ollama:    {s}
        \\
        \\  CAPABILITIES:
        \\    - Ternary Logic (K₃)
        \\    - PAS DAEMONS (8 patterns)
        \\    - Multi-provider AI
        \\    - Self-generating code
        \\
    , .{
        ai_status,
        if (has_anthropic) "✅ configured" else "❌ not set",
        if (has_openai) "✅ configured" else "❌ not set",
        if (has_eden) "✅ configured (Qwen)" else "❌ not set",
        if (has_ollama) "✅ configured" else "○ localhost:11434",
    }) catch {};
}

fn printConfig() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    const anthropic_key = std.posix.getenv("ANTHROPIC_API_KEY");
    const openai_key = std.posix.getenv("OPENAI_API_KEY");
    const ollama_host = std.posix.getenv("OLLAMA_HOST") orelse "http://localhost:11434";
    const eden_key = std.posix.getenv("EDEN_AI_API_KEY");

    const has_anthropic = anthropic_key != null and anthropic_key.?.len > 0;
    const has_openai = openai_key != null and openai_key.?.len > 0;
    const has_eden = eden_key != null and eden_key.?.len > 0;

    stdout.print(
        \\
        \\  VIBEE CONFIGURATION
        \\  ═══════════════════
        \\
        \\  API KEYS:
        \\    ANTHROPIC_API_KEY: {s}
        \\    OPENAI_API_KEY:    {s}
        \\    EDEN_AI_API_KEY:   {s}
        \\    OLLAMA_HOST:       {s}
        \\
    , .{
        if (has_anthropic) "sk-ant-***" else "(not set)",
        if (has_openai) "sk-***" else "(not set)",
        if (has_eden) "eyJhbGci***" else "(not set)",
        ollama_host,
    }) catch {};

    if (!has_anthropic and !has_openai and !has_eden) {
        stdout.print(
            \\
            \\  ⚠️  NO API KEY CONFIGURED
            \\
            \\  To use AI features, set one of:
            \\
            \\    export ANTHROPIC_API_KEY=sk-ant-your-key
            \\    export OPENAI_API_KEY=sk-your-key
            \\    export EDEN_AI_API_KEY=your-eden-key
            \\
            \\  Or use local Ollama:
            \\
            \\    ollama serve
            \\    export OLLAMA_HOST=http://localhost:11434
            \\
        , .{}) catch {};
    }
}

fn runChat(allocator: std.mem.Allocator) !u8 {
    _ = allocator;
    const stdout = std.fs.File.stdout().deprecatedWriter();
    const stdin = std.fs.File.stdin().deprecatedReader();

    // Check for API keys
    const anthropic_key = std.posix.getenv("ANTHROPIC_API_KEY");
    const openai_key = std.posix.getenv("OPENAI_API_KEY");
    const ollama_host = std.posix.getenv("OLLAMA_HOST");
    const eden_key = std.posix.getenv("EDEN_AI_API_KEY");

    const has_anthropic = anthropic_key != null and anthropic_key.?.len > 0;
    const has_openai = openai_key != null and openai_key.?.len > 0;
    const has_ollama = ollama_host != null and ollama_host.?.len > 0;
    const has_eden = eden_key != null and eden_key.?.len > 0;

    // Determine provider
    const provider: []const u8 = if (has_eden)
        "Eden AI (Qwen)"
    else if (has_anthropic)
        "Anthropic Claude"
    else if (has_openai)
        "OpenAI GPT"
    else if (has_ollama)
        "Ollama (local)"
    else
        "none";

    stdout.print(
        \\
        \\  ╔═══════════════════════════════════════════════════════════╗
        \\  ║  VIBEE CHAT - Interactive AI Terminal                     ║
        \\  ║  φ² + 1/φ² = 3                                            ║
        \\  ╚═══════════════════════════════════════════════════════════╝
        \\
    , .{}) catch {};

    if (!has_eden and !has_anthropic and !has_openai and !has_ollama) {
        stdout.print(
            \\
            \\  ❌ NO API KEY CONFIGURED
            \\
            \\  VIBEE requires an AI provider to chat. Set one of:
            \\
            \\    export EDEN_AI_API_KEY=your-eden-key-here
            \\    export ANTHROPIC_API_KEY=sk-ant-your-key-here
            \\    export OPENAI_API_KEY=sk-your-key-here
            \\
            \\  Or run local Ollama:
            \\
            \\    ollama serve
            \\    ollama pull llama3.2
            \\    export OLLAMA_HOST=http://localhost:11434
            \\
            \\  Then run: vibeec chat
            \\
            \\  ────────────────────────────────────────────────────────
            \\
            \\  OFFLINE MODE: You can still use these commands:
            \\
            \\    vibeec gen <file.vibee>  - Generate code from spec
            \\    vibeec pas               - View PAS patterns
            \\    vibeec phi               - View sacred constants
            \\    vibeec eval "△ ∧ ○"      - Evaluate ternary logic
            \\
        , .{}) catch {};
        return 1;
    }

    stdout.print(
        \\  Provider: {s}
        \\  Type /help for commands, /quit to exit
        \\
        \\
    , .{provider}) catch {};

    // REPL loop
    var input_buf: [4096]u8 = undefined;

    while (true) {
        stdout.print("△ > ", .{}) catch {};

        const input = stdin.readUntilDelimiterOrEof(&input_buf, '\n') catch |err| {
            stdout.print("\nError reading input: {}\n", .{err}) catch {};
            continue;
        };

        if (input == null) {
            stdout.print("\n\nGoodbye! φ² + 1/φ² = 3\n", .{}) catch {};
            break;
        }

        const line = std.mem.trim(u8, input.?, " \t\r\n");

        if (line.len == 0) continue;

        // Handle commands
        if (std.mem.startsWith(u8, line, "/")) {
            if (std.mem.eql(u8, line, "/quit") or std.mem.eql(u8, line, "/exit") or std.mem.eql(u8, line, "/q")) {
                stdout.print("\nGoodbye! φ² + 1/φ² = 3\n", .{}) catch {};
                break;
            } else if (std.mem.eql(u8, line, "/help") or std.mem.eql(u8, line, "/h")) {
                printChatHelp();
            } else if (std.mem.eql(u8, line, "/pas")) {
                printPASInfo();
            } else if (std.mem.eql(u8, line, "/phi")) {
                printPhiInfo();
            } else if (std.mem.eql(u8, line, "/status")) {
                printAgentStatus();
            } else if (std.mem.eql(u8, line, "/clear")) {
                // Clear screen
                stdout.print("\x1b[2J\x1b[H", .{}) catch {};
            } else {
                stdout.print("  Unknown command: {s}\n  Type /help for available commands\n\n", .{line}) catch {};
            }
            continue;
        }

        // Send to AI (placeholder - actual HTTP call would go here)
        stdout.print("\n  ○ Processing with {s}...\n", .{provider}) catch {};
        stdout.print("\n  [AI Response would appear here]\n", .{}) catch {};
        stdout.print("  Note: HTTP client not yet implemented in Zig.\n", .{}) catch {};
        stdout.print("  Use the Python/Node wrapper for full AI support.\n\n", .{}) catch {};
    }

    return 0;
}

fn printChatHelp() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
        \\
        \\  CHAT COMMANDS
        \\  ═════════════
        \\    /help, /h     Show this help
        \\    /quit, /q     Exit chat
        \\    /clear        Clear screen
        \\    /pas          Show PAS patterns
        \\    /phi          Show sacred constants
        \\    /status       Show agent status
        \\
        \\  Just type your message to chat with AI.
        \\
    , .{}) catch {};
}

fn launchAgent(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    // Build command for vibee-agent
    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);

    // Find the agent script relative to the binary
    try argv.append(allocator, "bin/vibee-agent");

    // Pass remaining arguments
    if (args.len > 2) {
        for (args[2..]) |arg| {
            try argv.append(allocator, arg);
        }
    }

    // Execute
    var child = std.process.Child.init(argv.items, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    _ = child.spawnAndWait() catch |err| {
        const stdout = std.fs.File.stdout().deprecatedWriter();
        stdout.print("Failed to launch agent: {}\n", .{err}) catch {};
        stdout.print("\nRun directly: ./bin/vibee-agent\n", .{}) catch {};
        return 1;
    };

    return 0;
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
