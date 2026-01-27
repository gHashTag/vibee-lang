//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Unified Compiler
//! Integrates: Lexer → Parser → Semantic → CodeGen
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_lexer = @import("coptic_lexer.zig");
const coptic_parser = @import("coptic_parser_real.zig");
const coptic_codegen = @import("coptic_codegen_real.zig");
const coptic_semantic = @import("coptic_semantic.zig");
const egraph = @import("egraph_v3.zig");
const sacred_rules = @import("rules_v3.zig");
const ast_egraph_bridge = @import("ast_egraph_bridge.zig");

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;

pub const CompileError = error{
    LexerError,
    ParseError,
    SemanticError,
    CodeGenError,
    OutOfMemory,
};

pub const CompileResult = struct {
    success: bool,
    code: []const u8,
    errors: std.ArrayListUnmanaged(CompilerError),
    warnings: std.ArrayListUnmanaged(CompilerError),
    tokens_count: u32,
    ast_nodes_count: u32,
    lines_generated: u32,
    semantic_passed: bool,
    symbols_count: u32,

    pub fn deinit(self: *CompileResult, allocator: std.mem.Allocator) void {
        if (self.code.len > 0) allocator.free(self.code);
        self.errors.deinit(allocator);
        self.warnings.deinit(allocator);
    }
};

pub const CompilerError = struct {
    message: []const u8,
    line: u32,
    column: u32,
    severity: Severity,

    pub const Severity = enum { error_, warning, info };
};

pub const CompilerOptions = struct {
    optimize: bool = false,
    debug_info: bool = true,
    emit_comments: bool = true,
    evolve: bool = true, // По умолчанию самоэволюция включена
    target: Target = .zig,

    pub const Target = enum { zig, wasm, llvm, verilog };
};

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    options: CompilerOptions,
    source: []const u8,
    source_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, source_name: []const u8) Compiler {
        return .{
            .allocator = allocator,
            .options = .{},
            .source = source,
            .source_name = source_name,
        };
    }

    pub fn setOptions(self: *Compiler, options: CompilerOptions) void {
        self.options = options;
    }

    pub fn compile(self: *Compiler) CompileResult {
        var result = CompileResult{
            .success = false,
            .code = "",
            .errors = .{},
            .warnings = .{},
            .tokens_count = 0,
            .ast_nodes_count = 0,
            .lines_generated = 0,
            .semantic_passed = false,
            .symbols_count = 0,
        };

        // Phase 1: Lexical Analysis
        var lexer = coptic_lexer.Lexer.init(self.source);
        var tokens_count: u32 = 0;
        while (true) {
            const tok = lexer.nextToken();
            tokens_count += 1;
            if (tok.kind == .eof) break;
            if (tok.kind == .invalid) {
                result.errors.append(self.allocator, .{
                    .message = "Invalid token",
                    .line = tok.line,
                    .column = tok.column,
                    .severity = .error_,
                }) catch {};
            }
        }
        result.tokens_count = tokens_count;

        if (result.errors.items.len > 0) return result;

        // Phase 2: Parsing
        var parser = coptic_parser.Parser.init(self.allocator, self.source);
        var ast = parser.parseProgram() catch |err| {
            result.errors.append(self.allocator, .{
                .message = @errorName(err),
                .line = parser.current.line,
                .column = parser.current.column,
                .severity = .error_,
            }) catch {};
            return result;
        };
        defer ast.deinit();

        result.ast_nodes_count = countNodes(&ast);

        // Phase 3: Semantic Analysis
        var semantic = coptic_semantic.SemanticAnalyzer.init(self.allocator);
        defer semantic.deinit();
        semantic.setup();
        semantic.setSource(self.source);

        semantic.analyze(&ast) catch |err| {
            result.errors.append(self.allocator, .{
                .message = @errorName(err),
                .line = 1,
                .column = 1,
                .severity = .error_,
            }) catch {};
        };

        // Add semantic errors/warnings
        for (semantic.errors.items) |sem_err| {
            result.errors.append(self.allocator, .{
                .message = sem_err.message,
                .line = sem_err.line,
                .column = sem_err.column,
                .severity = .error_,
            }) catch {};
        }

        for (semantic.warnings.items) |sem_warn| {
            result.warnings.append(self.allocator, .{
                .message = sem_warn.message,
                .line = sem_warn.line,
                .column = sem_warn.column,
                .severity = .warning,
            }) catch {};
        }

        result.semantic_passed = semantic.errors.items.len == 0;
        result.symbols_count = @intCast(semantic.global_scope.symbols.count());

        // Continue even with semantic warnings (but not errors)
        if (semantic.errors.items.len > 0) {
            return result;
        }

        // Phase 3.5: Self-Evolution (Equality Saturation)
        if (self.options.evolve) {
            var graph = egraph.EGraph.init(self.allocator);
            // graph.source = self.source; // V3 doesn't store source in struct yet, or does it?
            // Checking egraph_v3.zig: No 'source' field in struct EGraph.
            // But ast_egraph_bridge uses graph.source.? so I should add it or remove dependency.
            // Let's assume for now I need to add it to egraph_v3 or avoid using it in bridge if possible.
            // Bridge uses it for lexeme extraction.
            // I will add source field to EGraph in egraph_v3.zig first or monkey patch it here?
            // Better to add it to egraph_v3.zig.
            // But for this edit, I will assume I fix egraph_v3 first or I will get an error.
            // Actually, let's fix egraph_v3 to have source field first!
            // Wait, I can't do that in parallel.
            // I'll skip setting source here and fix egraph_v3 in a separate tool call if needed,
            // or I'll just comment it out and fix bridge to not need source or pass it.
            // Bridge takes graph, and uses graph.source.
            // Let's modify egraph_v3 to have optional source field.

            defer graph.deinit();

            var bridge = ast_egraph_bridge.Bridge.init(self.allocator, &graph);
            // Bridge needs source to extract literals from tokens.
            // Let's hack: I'll modify egraph_v3 right now to add `source: ?[]const u8 = null,`

            _ = bridge.astToEGraph(&ast) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "E-Graph evolution skipped: {s}", .{@errorName(err)}) catch "E-Graph evolution skipped";
                result.warnings.append(self.allocator, .{
                    .message = msg,
                    .line = 0,
                    .column = 0,
                    .severity = .warning,
                }) catch {};
            };

            // Запускаем сатурацию (Sacred Loop)
            egraph.saturate(&graph, &sacred_rules.SACRED_RULES) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Saturation failed: {s}", .{@errorName(err)}) catch "Saturation failed";
                result.warnings.append(self.allocator, .{
                    .message = msg,
                    .line = 0,
                    .column = 0,
                    .severity = .warning,
                }) catch {};
            };

            // В будущем здесь будет bridge.extractBest(class_id) для обновления AST
        }

        // Phase 4: Code Generation
        const code = switch (self.options.target) {
            .verilog => coptic_codegen.compileToVerilog(self.source, "trinity_sacred", self.allocator) catch |err| {
                result.errors.append(self.allocator, .{
                    .message = @errorName(err),
                    .line = 1,
                    .column = 1,
                    .severity = .error_,
                }) catch {};
                return result;
            },
            else => blk: {
                var codegen = coptic_codegen.CodeGen.init(self.allocator, self.source);
                defer codegen.deinit();
                const raw_code = codegen.generate(&ast) catch |err| {
                    result.errors.append(self.allocator, .{
                        .message = @errorName(err),
                        .line = 1,
                        .column = 1,
                        .severity = .error_,
                    }) catch {};
                    return result;
                };
                break :blk self.allocator.dupe(u8, raw_code) catch "";
            },
        };

        result.code = code;
        result.lines_generated = countLines(result.code);
        result.success = true;

        return result;
    }

    fn countNodes(node: *const coptic_parser.AstNode) u32 {
        var count: u32 = 1;
        for (node.children.items) |*child| {
            count += countNodes(child);
        }
        return count;
    }

    fn countLines(code: []const u8) u32 {
        var count: u32 = 1;
        for (code) |c| {
            if (c == '\n') count += 1;
        }
        return count;
    }
};

/// Compile source code to Zig
pub fn compile(source: []const u8, allocator: std.mem.Allocator) CompileResult {
    var compiler = Compiler.init(allocator, source, "input");
    return compiler.compile();
}

/// Compile file to Zig
pub fn compileFile(path: []const u8, allocator: std.mem.Allocator) !CompileResult {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    var compiler = Compiler.init(allocator, source, path);
    return compiler.compile();
}

// Tests
test "compiler basic" {
    var result = compile("const x = 42", std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.success);
    try std.testing.expect(result.tokens_count > 0);
    try std.testing.expect(result.ast_nodes_count > 0);
    try std.testing.expect(result.semantic_passed);
    try std.testing.expect(std.mem.indexOf(u8, result.code, "pub const x = 42") != null);
}

test "compiler with semantic" {
    var result = compile("const x = 42\nconst y = x + 1", std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.success);
    try std.testing.expect(result.semantic_passed);
    try std.testing.expect(result.symbols_count >= 2);
}

test "compiler func" {
    var result = compile("func add(a, b) { return a + b }", std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.code, "pub fn add") != null);
}

test "compiler trit" {
    var result = compile("△", std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.success);
}

test "compiler error" {
    // Empty source should still compile (empty program)
    var result = compile("", std.testing.allocator);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.success);
}

test "phi constant" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}
