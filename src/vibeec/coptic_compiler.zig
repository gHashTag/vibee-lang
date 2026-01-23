//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Unified Compiler
//! Integrates: Lexer → Parser → Semantic → CodeGen
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_lexer = @import("coptic_lexer.zig");
const coptic_parser = @import("coptic_parser_real.zig");
const coptic_codegen = @import("coptic_codegen_real.zig");
const coptic_semantic = @import("coptic_semantic.zig");

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
    errors: std.ArrayList(CompilerError),
    warnings: std.ArrayList(CompilerError),
    tokens_count: u32,
    ast_nodes_count: u32,
    lines_generated: u32,
    semantic_passed: bool,
    symbols_count: u32,
    
    pub fn deinit(self: *CompileResult, allocator: std.mem.Allocator) void {
        if (self.code.len > 0) allocator.free(self.code);
        self.errors.deinit();
        self.warnings.deinit();
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
    target: Target = .zig,
    
    pub const Target = enum { zig, wasm, llvm };
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
            .errors = std.ArrayList(CompilerError).init(self.allocator),
            .warnings = std.ArrayList(CompilerError).init(self.allocator),
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
                result.errors.append(.{
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
        var parser = coptic_parser.Parser.init(self.source, self.allocator);
        var ast = parser.parseProgram() catch |err| {
            result.errors.append(.{
                .message = @errorName(err),
                .line = 1,
                .column = 1,
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
            result.errors.append(.{
                .message = @errorName(err),
                .line = 1,
                .column = 1,
                .severity = .error_,
            }) catch {};
        };
        
        // Add semantic errors/warnings
        for (semantic.errors.items) |sem_err| {
            result.errors.append(.{
                .message = sem_err.message,
                .line = sem_err.line,
                .column = sem_err.column,
                .severity = .error_,
            }) catch {};
        }
        
        for (semantic.warnings.items) |sem_warn| {
            result.warnings.append(.{
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
        
        // Phase 4: Code Generation
        var codegen = coptic_codegen.CodeGen.init(self.allocator, self.source);
        defer codegen.deinit();
        
        const code = codegen.generate(&ast) catch |err| {
            result.errors.append(.{
                .message = @errorName(err),
                .line = 1,
                .column = 1,
                .severity = .error_,
            }) catch {};
            return result;
        };
        
        result.code = self.allocator.dupe(u8, code) catch "";
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
