//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Semantic Analyzer
//! Symbol tables, type checking, scope analysis
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_parser = @import("coptic_parser_real.zig");

const AstNode = coptic_parser.AstNode;
const NodeKind = coptic_parser.NodeKind;

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;

pub const Type = enum {
    unknown,
    int_,
    float_,
    bool_,
    trit,
    string_,
    func,
    void_,

    pub fn toString(self: Type) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .int_ => "int",
            .float_ => "float",
            .bool_ => "bool",
            .trit => "trit",
            .string_ => "string",
            .func => "func",
            .void_ => "void",
        };
    }
};

pub const Symbol = struct {
    name: []const u8,
    type_: Type,
    is_const: bool,
    is_defined: bool,
    scope_level: u32,
    line: u32,
    column: u32,
};

pub const Scope = struct {
    symbols: std.StringHashMap(Symbol),
    parent: ?*Scope,
    level: u32,

    pub fn init(allocator: std.mem.Allocator, parent: ?*Scope) Scope {
        return .{
            .symbols = std.StringHashMap(Symbol).init(allocator),
            .parent = parent,
            .level = if (parent) |p| p.level + 1 else 0,
        };
    }

    pub fn deinit(self: *Scope) void {
        self.symbols.deinit();
    }

    pub fn define(self: *Scope, name: []const u8, symbol: Symbol) !void {
        try self.symbols.put(name, symbol);
    }

    pub fn lookup(self: *Scope, name: []const u8) ?Symbol {
        if (self.symbols.get(name)) |sym| return sym;
        if (self.parent) |p| return p.lookup(name);
        return null;
    }

    pub fn lookupLocal(self: *Scope, name: []const u8) ?Symbol {
        return self.symbols.get(name);
    }
};

pub const SemanticError = struct {
    message: []const u8,
    line: u32,
    column: u32,
};

pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    current_scope: *Scope,
    global_scope: Scope,
    errors: std.ArrayListUnmanaged(SemanticError),
    warnings: std.ArrayListUnmanaged(SemanticError),
    source: []const u8,

    pub fn init(allocator: std.mem.Allocator) SemanticAnalyzer {
        return SemanticAnalyzer{
            .allocator = allocator,
            .current_scope = undefined,
            .global_scope = Scope.init(allocator, null),
            .errors = .{},
            .warnings = .{},
            .source = "",
        };
    }

    pub fn setSource(self: *SemanticAnalyzer, source: []const u8) void {
        self.source = source;
    }

    pub fn setup(self: *SemanticAnalyzer) void {
        self.current_scope = &self.global_scope;
        self.defineBuiltins() catch {};
    }

    pub fn deinit(self: *SemanticAnalyzer) void {
        self.global_scope.deinit();
        self.errors.deinit(self.allocator);
        self.warnings.deinit(self.allocator);
    }

    fn defineBuiltins(self: *SemanticAnalyzer) !void {
        // Built-in constants
        try self.current_scope.define("phi", .{
            .name = "phi",
            .type_ = .float_,
            .is_const = true,
            .is_defined = true,
            .scope_level = 0,
            .line = 0,
            .column = 0,
        });
        try self.current_scope.define("trinity", .{
            .name = "trinity",
            .type_ = .int_,
            .is_const = true,
            .is_defined = true,
            .scope_level = 0,
            .line = 0,
            .column = 0,
        });
    }

    pub const AnalyzeError = error{OutOfMemory};

    pub fn analyze(self: *SemanticAnalyzer, ast: *const AstNode) AnalyzeError!void {
        self.visitNode(ast) catch |err| return err;
    }

    fn visitNode(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        switch (node.kind) {
            .program => try self.visitProgram(node),
            .module_decl => {}, // Ничего не делаем для объявлений модулей в семантике пока что
            .const_decl => try self.visitConstDecl(node),
            .var_decl => try self.visitVarDecl(node),
            .func_decl => try self.visitFuncDecl(node),
            .identifier => try self.visitIdentifier(node),
            .binary_expr => try self.visitBinary(node),
            .call_expr => try self.visitCall(node),
            else => {
                for (node.children.items) |*child| {
                    try self.visitNode(child);
                }
            },
        }
    }

    fn visitProgram(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        for (node.children.items) |*child| {
            try self.visitNode(child);
        }
    }

    fn visitConstDecl(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        if (node.children.items.len < 1) return;

        const name_node = &node.children.items[0];
        const name = name_node.token.lexeme(self.getSource());

        // Check for redefinition
        if (self.current_scope.lookupLocal(name)) |_| {
            try self.errors.append(self.allocator, .{
                .message = "Symbol already defined in this scope",
                .line = name_node.token.line,
                .column = name_node.token.column,
            });
            return;
        }

        // Infer type from value
        var type_: Type = .unknown;
        if (node.children.items.len > 1) {
            type_ = self.inferType(&node.children.items[1]);
        }

        try self.current_scope.define(name, .{
            .name = name,
            .type_ = type_,
            .is_const = true,
            .is_defined = true,
            .scope_level = self.current_scope.level,
            .line = name_node.token.line,
            .column = name_node.token.column,
        });
    }

    fn visitVarDecl(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        if (node.children.items.len < 1) return;

        const name_node = &node.children.items[0];
        const name = name_node.token.lexeme(self.getSource());

        if (self.current_scope.lookupLocal(name)) |_| {
            try self.errors.append(self.allocator, .{
                .message = "Symbol already defined in this scope",
                .line = name_node.token.line,
                .column = name_node.token.column,
            });
            return;
        }

        var type_: Type = .unknown;
        if (node.children.items.len > 1) {
            type_ = self.inferType(&node.children.items[1]);
        }

        try self.current_scope.define(name, .{
            .name = name,
            .type_ = type_,
            .is_const = false,
            .is_defined = true,
            .scope_level = self.current_scope.level,
            .line = name_node.token.line,
            .column = name_node.token.column,
        });
    }

    fn visitFuncDecl(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        if (node.children.items.len < 1) return;

        const name_node = &node.children.items[0];
        const name = name_node.token.lexeme(self.getSource());

        try self.current_scope.define(name, .{
            .name = name,
            .type_ = .func,
            .is_const = true,
            .is_defined = true,
            .scope_level = self.current_scope.level,
            .line = name_node.token.line,
            .column = name_node.token.column,
        });

        // TODO: Create new scope for function body
    }

    fn visitIdentifier(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        const name = node.token.lexeme(self.getSource());

        if (self.current_scope.lookup(name) == null) {
            try self.errors.append(self.allocator, .{
                .message = "Undefined symbol",
                .line = node.token.line,
                .column = node.token.column,
            });
        }
    }

    fn visitBinary(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        for (node.children.items) |*child| {
            try self.visitNode(child);
        }
    }

    fn visitCall(self: *SemanticAnalyzer, node: *const AstNode) AnalyzeError!void {
        if (node.children.items.len < 1) return;

        const callee = &node.children.items[0];
        const name = callee.token.lexeme(self.getSource());

        if (self.current_scope.lookup(name)) |sym| {
            if (sym.type_ != .func) {
                try self.warnings.append(self.allocator, .{
                    .message = "Calling non-function",
                    .line = callee.token.line,
                    .column = callee.token.column,
                });
            }
        }

        // Check arguments
        var i: usize = 1;
        while (i < node.children.items.len) : (i += 1) {
            try self.visitNode(&node.children.items[i]);
        }
    }

    fn inferType(self: *SemanticAnalyzer, node: *const AstNode) Type {
        _ = self;
        return switch (node.kind) {
            .literal_int => .int_,
            .literal_float => .float_,
            .literal_trit => .trit,
            else => .unknown,
        };
    }

    fn getSource(self: *SemanticAnalyzer) []const u8 {
        return self.source;
    }

    pub fn hasErrors(self: *SemanticAnalyzer) bool {
        return self.errors.items.len > 0;
    }
};

// Tests
test "semantic basic" {
    var analyzer = SemanticAnalyzer.init(std.testing.allocator);
    analyzer.setup();
    defer analyzer.deinit();

    // Built-ins should be defined
    try std.testing.expect(analyzer.global_scope.lookup("phi") != null);
    try std.testing.expect(analyzer.global_scope.lookup("trinity") != null);
}

test "semantic scope" {
    var analyzer = SemanticAnalyzer.init(std.testing.allocator);
    analyzer.setup();
    defer analyzer.deinit();

    try analyzer.global_scope.define("x", .{
        .name = "x",
        .type_ = .int_,
        .is_const = true,
        .is_defined = true,
        .scope_level = 0,
        .line = 1,
        .column = 1,
    });

    try std.testing.expect(analyzer.global_scope.lookup("x") != null);
    try std.testing.expect(analyzer.global_scope.lookup("y") == null);
}

test "semantic type" {
    try std.testing.expectEqualStrings("int", Type.int_.toString());
    try std.testing.expectEqualStrings("trit", Type.trit.toString());
}

test "phi constant" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}
