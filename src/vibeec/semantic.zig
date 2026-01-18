// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC SEMANTIC ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V36 - Symbol Table with Scope Chain and Name Resolution
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: HSH (Symbol Lookup), D&C (Scope Chain), INC (Caching)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const ast_mod = @import("ast.zig");
const Ast = ast_mod.Ast;
const AstNode = ast_mod.AstNode;
const NodeKind = ast_mod.NodeKind;
const SourceSpan = ast_mod.SourceSpan;
const NodeId = ast_mod.NodeId;
const INVALID_NODE = ast_mod.INVALID_NODE;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// SYMBOL TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScopeId = u32;
pub const SymbolId = u32;
pub const INVALID_SCOPE: ScopeId = std.math.maxInt(ScopeId);
pub const INVALID_SYMBOL: SymbolId = std.math.maxInt(SymbolId);

pub const SymbolKind = enum {
    variable,
    constant,
    function,
    type_def,
    behavior,
    field,
    method,
    parameter,
    sacred_type,
};

pub const Symbol = struct {
    id: SymbolId,
    name: []const u8,
    kind: SymbolKind,
    type_name: []const u8,
    scope_id: ScopeId,
    definition_span: SourceSpan,
    is_public: bool,
    is_mutable: bool,
    ast_node: NodeId,
};

pub const ScopeKind = enum {
    global,
    module,
    type_body,
    function_body,
    behavior_body,
    block,
};

pub const Scope = struct {
    id: ScopeId,
    parent: ScopeId,
    kind: ScopeKind,
    symbols: StringHashMap(SymbolId),
    children: ArrayList(ScopeId),
    span: SourceSpan,

    pub fn init(allocator: Allocator, id: ScopeId, parent: ScopeId, kind: ScopeKind, span: SourceSpan) Scope {
        return Scope{
            .id = id,
            .parent = parent,
            .kind = kind,
            .symbols = StringHashMap(SymbolId).init(allocator),
            .children = ArrayList(ScopeId).init(allocator),
            .span = span,
        };
    }

    pub fn deinit(self: *Scope) void {
        self.symbols.deinit();
        self.children.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYMBOL TABLE - HSH PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const SymbolTable = struct {
    allocator: Allocator,
    symbols: ArrayList(Symbol),
    scopes: ArrayList(Scope),
    current_scope: ScopeId,

    // HSH Pattern: Fast lookup caches
    global_symbols: StringHashMap(SymbolId),
    type_registry: StringHashMap(SymbolId),

    // Metrics
    lookups: u64,
    cache_hits: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var self = Self{
            .allocator = allocator,
            .symbols = ArrayList(Symbol).init(allocator),
            .scopes = ArrayList(Scope).init(allocator),
            .current_scope = 0,
            .global_symbols = StringHashMap(SymbolId).init(allocator),
            .type_registry = StringHashMap(SymbolId).init(allocator),
            .lookups = 0,
            .cache_hits = 0,
        };

        // Create global scope
        try self.scopes.append(Scope.init(allocator, 0, INVALID_SCOPE, .global, SourceSpan.empty()));

        // Register built-in types
        try self.registerBuiltins();

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.scopes.items) |*scope| {
            scope.deinit();
        }
        self.scopes.deinit();
        self.symbols.deinit();
        self.global_symbols.deinit();
        self.type_registry.deinit();
    }

    fn registerBuiltins(self: *Self) !void {
        // Primitive types
        const primitives = [_][]const u8{
            "void", "bool", "i8", "i16", "i32", "i64",
            "u8",   "u16",  "u32", "u64", "f32", "f64",
            "string", "anytype",
        };

        for (primitives) |name| {
            _ = try self.defineSymbol(name, .type_def, name, SourceSpan.empty(), INVALID_NODE);
        }

        // Sacred types
        const sacred_types = [_][]const u8{
            "SacredComputation",
            "EvolutionState",
            "QuantumNeuroState",
        };

        for (sacred_types) |name| {
            _ = try self.defineSymbol(name, .sacred_type, name, SourceSpan.empty(), INVALID_NODE);
        }
    }

    /// Enter a new scope (D&C: divide into subscopes)
    pub fn enterScope(self: *Self, kind: ScopeKind, span: SourceSpan) !ScopeId {
        const new_id: ScopeId = @intCast(self.scopes.items.len);

        try self.scopes.append(Scope.init(self.allocator, new_id, self.current_scope, kind, span));

        // Add as child of current scope
        try self.scopes.items[self.current_scope].children.append(new_id);

        self.current_scope = new_id;
        return new_id;
    }

    /// Exit current scope
    pub fn exitScope(self: *Self) void {
        const current = &self.scopes.items[self.current_scope];
        if (current.parent != INVALID_SCOPE) {
            self.current_scope = current.parent;
        }
    }

    /// Define a symbol in current scope
    pub fn defineSymbol(
        self: *Self,
        name: []const u8,
        kind: SymbolKind,
        type_name: []const u8,
        span: SourceSpan,
        ast_node: NodeId,
    ) !SymbolId {
        const id: SymbolId = @intCast(self.symbols.items.len);

        const symbol = Symbol{
            .id = id,
            .name = name,
            .kind = kind,
            .type_name = type_name,
            .scope_id = self.current_scope,
            .definition_span = span,
            .is_public = false,
            .is_mutable = false,
            .ast_node = ast_node,
        };

        try self.symbols.append(symbol);
        try self.scopes.items[self.current_scope].symbols.put(name, id);

        // Add to global cache if in global scope
        if (self.current_scope == 0) {
            try self.global_symbols.put(name, id);
        }

        // Add to type registry if it's a type
        if (kind == .type_def or kind == .sacred_type) {
            try self.type_registry.put(name, id);
        }

        return id;
    }

    /// HSH Pattern: O(1) lookup with scope chain traversal
    pub fn lookup(self: *Self, name: []const u8) ?*Symbol {
        self.lookups += 1;

        // First check global cache (HSH: O(1))
        if (self.global_symbols.get(name)) |id| {
            self.cache_hits += 1;
            return &self.symbols.items[id];
        }

        // D&C: Traverse scope chain
        var scope_id = self.current_scope;
        while (scope_id != INVALID_SCOPE) {
            const scope = &self.scopes.items[scope_id];

            if (scope.symbols.get(name)) |symbol_id| {
                return &self.symbols.items[symbol_id];
            }

            scope_id = scope.parent;
        }

        return null;
    }

    /// Lookup in specific scope only
    pub fn lookupInScope(self: *Self, name: []const u8, scope_id: ScopeId) ?*Symbol {
        if (scope_id >= self.scopes.items.len) return null;

        if (self.scopes.items[scope_id].symbols.get(name)) |symbol_id| {
            return &self.symbols.items[symbol_id];
        }

        return null;
    }

    /// Lookup type by name
    pub fn lookupType(self: *Self, name: []const u8) ?*Symbol {
        if (self.type_registry.get(name)) |id| {
            return &self.symbols.items[id];
        }
        return null;
    }

    pub fn getSymbol(self: *Self, id: SymbolId) ?*Symbol {
        if (id >= self.symbols.items.len) return null;
        return &self.symbols.items[id];
    }

    pub fn hitRatio(self: Self) f64 {
        if (self.lookups == 0) return 0;
        return @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(self.lookups));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC ERROR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SemanticErrorCode = enum {
    undefined_symbol,
    duplicate_definition,
    type_not_found,
    circular_reference,
    invalid_scope_access,
    missing_required_field,
    type_mismatch,
};

pub const SemanticError = struct {
    code: SemanticErrorCode,
    message: []const u8,
    span: SourceSpan,
    symbol_name: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SemanticAnalyzer = struct {
    allocator: Allocator,
    symbol_table: SymbolTable,
    errors: ArrayList(SemanticError),
    warnings: ArrayList(SemanticError),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .symbol_table = try SymbolTable.init(allocator),
            .errors = ArrayList(SemanticError).init(allocator),
            .warnings = ArrayList(SemanticError).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.symbol_table.deinit();
        self.errors.deinit();
        self.warnings.deinit();
    }

    pub fn analyze(self: *Self, ast: *const Ast) !SemanticResult {
        if (ast.root == INVALID_NODE) {
            return SemanticResult{
                .success = false,
                .errors = self.errors.items,
                .warnings = self.warnings.items,
                .symbol_count = 0,
                .scope_count = 1,
            };
        }

        // Phase 1: Collect all type definitions (forward declarations)
        try self.collectTypes(ast);

        // Phase 2: Resolve type bodies
        try self.resolveTypes(ast);

        // Phase 3: Analyze behaviors
        try self.analyzeBehaviors(ast);

        // Phase 4: Check for unused symbols
        try self.checkUnused();

        return SemanticResult{
            .success = self.errors.items.len == 0,
            .errors = self.errors.items,
            .warnings = self.warnings.items,
            .symbol_count = self.symbol_table.symbols.items.len,
            .scope_count = self.symbol_table.scopes.items.len,
        };
    }

    fn collectTypes(self: *Self, ast: *const Ast) !void {
        var iter = ast.children(ast.root);
        while (iter.next()) |node| {
            if (node.kind == .type_list) {
                var type_iter = ast.children(node.id);
                while (type_iter.next()) |type_node| {
                    if (type_node.kind == .type_def) {
                        // Check for duplicate
                        if (self.symbol_table.lookupType(type_node.data)) |_| {
                            try self.errors.append(.{
                                .code = .duplicate_definition,
                                .message = "type already defined",
                                .span = type_node.span,
                                .symbol_name = type_node.data,
                            });
                        } else {
                            _ = try self.symbol_table.defineSymbol(
                                type_node.data,
                                .type_def,
                                type_node.data,
                                type_node.span,
                                type_node.id,
                            );
                        }
                    }
                }
            }
        }
    }

    fn resolveTypes(self: *Self, ast: *const Ast) !void {
        var iter = ast.children(ast.root);
        while (iter.next()) |node| {
            if (node.kind == .type_list) {
                var type_iter = ast.children(node.id);
                while (type_iter.next()) |type_node| {
                    if (type_node.kind == .type_def) {
                        try self.resolveTypeBody(ast, type_node);
                    }
                }
            }
        }
    }

    fn resolveTypeBody(self: *Self, ast: *const Ast, type_node: *const AstNode) !void {
        // Enter type scope
        _ = try self.symbol_table.enterScope(.type_body, type_node.span);
        defer self.symbol_table.exitScope();

        // Resolve fields
        var field_iter = ast.children(type_node.id);
        while (field_iter.next()) |field_node| {
            if (field_node.kind == .field) {
                // Field data contains type name
                if (field_node.data.len > 0) {
                    if (self.symbol_table.lookupType(field_node.data) == null) {
                        // Check if it's a built-in or unknown
                        if (!self.isBuiltinType(field_node.data)) {
                            try self.errors.append(.{
                                .code = .type_not_found,
                                .message = "unknown type",
                                .span = field_node.span,
                                .symbol_name = field_node.data,
                            });
                        }
                    }
                }
            }
        }
    }

    fn analyzeBehaviors(self: *Self, ast: *const Ast) !void {
        var iter = ast.children(ast.root);
        while (iter.next()) |node| {
            if (node.kind == .behavior_list) {
                var behavior_iter = ast.children(node.id);
                while (behavior_iter.next()) |behavior_node| {
                    if (behavior_node.kind == .behavior) {
                        _ = try self.symbol_table.defineSymbol(
                            behavior_node.data,
                            .behavior,
                            "behavior",
                            behavior_node.span,
                            behavior_node.id,
                        );
                    }
                }
            }
        }
    }

    fn checkUnused(self: *Self) !void {
        // Check for unused types (warning only)
        // Future: Add usage tracking and emit warnings for unused symbols
        _ = self;
    }

    fn isBuiltinType(self: *Self, name: []const u8) bool {
        _ = self;
        const builtins = [_][]const u8{
            "void",   "bool",   "i8",     "i16",    "i32",    "i64",
            "u8",     "u16",    "u32",    "u64",    "f32",    "f64",
            "string", "anytype", "usize",
        };

        for (builtins) |builtin| {
            if (std.mem.eql(u8, name, builtin)) return true;
        }

        // Check for array/slice/optional types
        if (name.len > 0 and (name[0] == '[' or name[0] == '?' or name[0] == '!')) {
            return true;
        }

        return false;
    }

    pub fn getSymbolTable(self: *Self) *SymbolTable {
        return &self.symbol_table;
    }
};

pub const SemanticResult = struct {
    success: bool,
    errors: []const SemanticError,
    warnings: []const SemanticError,
    symbol_count: usize,
    scope_count: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SymbolTable basic" {
    const allocator = std.testing.allocator;
    var table = try SymbolTable.init(allocator);
    defer table.deinit();

    const id = try table.defineSymbol("test_var", .variable, "i32", SourceSpan.empty(), INVALID_NODE);

    try std.testing.expect(id != INVALID_SYMBOL);

    const symbol = table.lookup("test_var");
    try std.testing.expect(symbol != null);
    try std.testing.expectEqualStrings("test_var", symbol.?.name);
}

test "SymbolTable scope chain" {
    const allocator = std.testing.allocator;
    var table = try SymbolTable.init(allocator);
    defer table.deinit();

    // Define in global scope
    _ = try table.defineSymbol("global_var", .variable, "i32", SourceSpan.empty(), INVALID_NODE);

    // Enter new scope
    _ = try table.enterScope(.function_body, SourceSpan.empty());

    // Define in function scope
    _ = try table.defineSymbol("local_var", .variable, "i32", SourceSpan.empty(), INVALID_NODE);

    // Should find both
    try std.testing.expect(table.lookup("global_var") != null);
    try std.testing.expect(table.lookup("local_var") != null);

    // Exit scope
    table.exitScope();

    // Should only find global
    try std.testing.expect(table.lookup("global_var") != null);
    try std.testing.expect(table.lookup("local_var") == null);
}

test "SymbolTable builtin types" {
    const allocator = std.testing.allocator;
    var table = try SymbolTable.init(allocator);
    defer table.deinit();

    try std.testing.expect(table.lookupType("i32") != null);
    try std.testing.expect(table.lookupType("f64") != null);
    try std.testing.expect(table.lookupType("bool") != null);
    try std.testing.expect(table.lookupType("SacredComputation") != null);
}

test "SemanticAnalyzer basic" {
    const allocator = std.testing.allocator;

    var builder = ast_mod.AstBuilder.init(allocator);
    defer builder.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
    ;

    const ast = try builder.build(source);

    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();

    const result = try analyzer.analyze(ast);

    try std.testing.expect(result.success);
    try std.testing.expect(result.symbol_count > 0);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
