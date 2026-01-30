//! VIBEE Semantic Analyzer - PAS DAEMON V39
//! Паттерны: HSH (O(1) symbol lookup), D&C (scope tree), PRE (cached analysis)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// SYMBOL KINDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SymbolKind = enum {
    variable,
    constant,
    function,
    parameter,
    struct_type,
    enum_type,
    field,
    module,
    sacred,      // Sacred symbol (φ, π, e)
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYMBOL - Semantic information about a name
// ═══════════════════════════════════════════════════════════════════════════════

pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    type_id: u32,
    
    // Location
    decl_line: u32 = 0,
    decl_column: u16 = 0,
    
    // Flags
    is_mutable: bool = true,
    is_public: bool = false,
    is_used: bool = false,
    is_initialized: bool = false,
    
    // For functions
    param_count: u8 = 0,
    return_type_id: u32 = 0,
    
    // For structs/enums
    member_count: u16 = 0,
    
    // Scope where defined
    scope_id: u32 = 0,
    
    pub fn init(name: []const u8, kind: SymbolKind, type_id: u32) Symbol {
        return .{
            .name = name,
            .kind = kind,
            .type_id = type_id,
        };
    }
    
    pub fn markUsed(self: *Symbol) void {
        self.is_used = true;
    }
    
    pub fn isCallable(self: *const Symbol) bool {
        return self.kind == .function;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCOPE - Lexical scope with HSH symbol table
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScopeKind = enum {
    global,
    module,
    function,
    block,
    loop,
    conditional,
};

pub const Scope = struct {
    id: u32,
    kind: ScopeKind,
    parent: ?*Scope,
    
    // HSH: O(1) symbol lookup
    symbols: std.StringHashMap(Symbol),
    
    // Children scopes (D&C pattern)
    children: std.ArrayList(*Scope),
    
    // For function scopes
    return_type_id: u32 = 0,
    
    // For loop scopes
    loop_depth: u32 = 0,
    
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, id: u32, kind: ScopeKind, parent: ?*Scope) Scope {
        const loop_depth = if (parent) |p| 
            (if (kind == .loop) p.loop_depth + 1 else p.loop_depth)
        else 0;
        
        return .{
            .id = id,
            .kind = kind,
            .parent = parent,
            .symbols = std.StringHashMap(Symbol).init(allocator),
            .children = std.ArrayList(*Scope).init(allocator),
            .loop_depth = loop_depth,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Scope) void {
        // Children are freed by SemanticAnalyzer.all_scopes
        self.children.deinit();
        self.symbols.deinit();
    }
    
    /// Define symbol in this scope - O(1)
    pub fn define(self: *Scope, symbol: Symbol) !void {
        if (self.symbols.contains(symbol.name)) {
            return SemanticError.SymbolAlreadyDefined;
        }
        try self.symbols.put(symbol.name, symbol);
    }
    
    /// Lookup symbol in this scope only - O(1)
    pub fn lookupLocal(self: *const Scope, name: []const u8) ?*Symbol {
        return self.symbols.getPtr(name);
    }
    
    /// Lookup symbol in this scope and parents - O(depth)
    pub fn lookup(self: *const Scope, name: []const u8) ?*Symbol {
        if (self.symbols.getPtr(name)) |sym| return sym;
        if (self.parent) |p| return p.lookup(name);
        return null;
    }
    
    /// Check if we're inside a loop
    pub fn isInLoop(self: *const Scope) bool {
        return self.loop_depth > 0;
    }
    
    /// Get enclosing function scope
    pub fn getEnclosingFunction(self: *const Scope) ?*const Scope {
        if (self.kind == .function) return self;
        if (self.parent) |p| return p.getEnclosingFunction();
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC ERROR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SemanticError = error{
    SymbolAlreadyDefined,
    UndefinedSymbol,
    TypeMismatch,
    NotCallable,
    WrongArgumentCount,
    BreakOutsideLoop,
    ContinueOutsideLoop,
    ReturnOutsideFunction,
    AssignToConstant,
    UninitializedVariable,
    UnusedVariable,
    InvalidOperation,
    OutOfMemory,
};

pub const Diagnostic = struct {
    kind: DiagnosticKind,
    message: []const u8,
    line: u32,
    column: u16,
    
    pub const DiagnosticKind = enum {
        err,
        warning,
        hint,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC ANALYZER - Main analyzer
// ═══════════════════════════════════════════════════════════════════════════════

pub const SemanticAnalyzer = struct {
    allocator: Allocator,
    
    // Scope management (D&C pattern)
    global_scope: *Scope,
    current_scope: *Scope,
    next_scope_id: u32 = 1,
    
    // All scopes for cleanup
    all_scopes: std.ArrayList(*Scope),
    
    // Diagnostics
    diagnostics: std.ArrayList(Diagnostic),
    error_count: u32 = 0,
    warning_count: u32 = 0,
    
    // Analysis cache (PRE pattern)
    analysis_cache: std.AutoHashMap(u64, bool),
    
    // Statistics
    symbols_defined: u64 = 0,
    lookups_performed: u64 = 0,
    cache_hits: u64 = 0,
    
    pub fn init(allocator: Allocator) !SemanticAnalyzer {
        const global = try allocator.create(Scope);
        global.* = Scope.init(allocator, 0, .global, null);
        
        var analyzer = SemanticAnalyzer{
            .allocator = allocator,
            .global_scope = global,
            .current_scope = global,
            .all_scopes = std.ArrayList(*Scope).init(allocator),
            .diagnostics = std.ArrayList(Diagnostic).init(allocator),
            .analysis_cache = std.AutoHashMap(u64, bool).init(allocator),
        };
        
        try analyzer.all_scopes.append(global);
        
        // Define sacred symbols
        try analyzer.defineSacredSymbols();
        
        return analyzer;
    }
    
    pub fn deinit(self: *SemanticAnalyzer) void {
        for (self.all_scopes.items) |scope| {
            scope.deinit();
            self.allocator.destroy(scope);
        }
        self.all_scopes.deinit();
        self.diagnostics.deinit();
        self.analysis_cache.deinit();
    }
    
    /// Define sacred symbols (φ, π, e)
    fn defineSacredSymbols(self: *SemanticAnalyzer) !void {
        var phi_sym = Symbol.init("phi", .sacred, 1);
        phi_sym.is_mutable = false;
        phi_sym.is_initialized = true;
        try self.global_scope.define(phi_sym);
        
        var pi_sym = Symbol.init("pi", .sacred, 1);
        pi_sym.is_mutable = false;
        pi_sym.is_initialized = true;
        try self.global_scope.define(pi_sym);
        
        var e_sym = Symbol.init("e", .sacred, 1);
        e_sym.is_mutable = false;
        e_sym.is_initialized = true;
        try self.global_scope.define(e_sym);
        
        self.symbols_defined += 3;
    }
    
    /// Enter new scope
    pub fn enterScope(self: *SemanticAnalyzer, kind: ScopeKind) !*Scope {
        const scope = try self.allocator.create(Scope);
        scope.* = Scope.init(self.allocator, self.next_scope_id, kind, self.current_scope);
        self.next_scope_id += 1;
        
        try self.current_scope.children.append(scope);
        try self.all_scopes.append(scope);
        self.current_scope = scope;
        
        return scope;
    }
    
    /// Exit current scope
    pub fn exitScope(self: *SemanticAnalyzer) void {
        if (self.current_scope.parent) |parent| {
            self.current_scope = parent;
        }
    }
    
    /// Define variable
    pub fn defineVariable(self: *SemanticAnalyzer, name: []const u8, type_id: u32, is_mutable: bool) !void {
        var sym = Symbol.init(name, .variable, type_id);
        sym.is_mutable = is_mutable;
        sym.scope_id = self.current_scope.id;
        
        try self.current_scope.define(sym);
        self.symbols_defined += 1;
    }
    
    /// Define constant
    pub fn defineConstant(self: *SemanticAnalyzer, name: []const u8, type_id: u32) !void {
        var sym = Symbol.init(name, .constant, type_id);
        sym.is_mutable = false;
        sym.is_initialized = true;
        sym.scope_id = self.current_scope.id;
        
        try self.current_scope.define(sym);
        self.symbols_defined += 1;
    }
    
    /// Define function
    pub fn defineFunction(self: *SemanticAnalyzer, name: []const u8, param_count: u8, return_type_id: u32) !void {
        var sym = Symbol.init(name, .function, 0);
        sym.param_count = param_count;
        sym.return_type_id = return_type_id;
        sym.is_mutable = false;
        sym.scope_id = self.current_scope.id;
        
        try self.current_scope.define(sym);
        self.symbols_defined += 1;
    }
    
    /// Define struct type
    pub fn defineStruct(self: *SemanticAnalyzer, name: []const u8, member_count: u16) !void {
        var sym = Symbol.init(name, .struct_type, 0);
        sym.member_count = member_count;
        sym.is_mutable = false;
        sym.scope_id = self.current_scope.id;
        
        try self.current_scope.define(sym);
        self.symbols_defined += 1;
    }
    
    /// Lookup symbol
    pub fn lookupSymbol(self: *SemanticAnalyzer, name: []const u8) ?*Symbol {
        self.lookups_performed += 1;
        return self.current_scope.lookup(name);
    }
    
    /// Resolve symbol (lookup + mark used)
    pub fn resolveSymbol(self: *SemanticAnalyzer, name: []const u8) SemanticError!*Symbol {
        const sym = self.lookupSymbol(name) orelse {
            return SemanticError.UndefinedSymbol;
        };
        sym.markUsed();
        return sym;
    }
    
    /// Check assignment validity
    pub fn checkAssignment(self: *SemanticAnalyzer, name: []const u8) SemanticError!void {
        const sym = try self.resolveSymbol(name);
        if (!sym.is_mutable) {
            return SemanticError.AssignToConstant;
        }
        sym.is_initialized = true;
    }
    
    /// Check function call
    pub fn checkCall(self: *SemanticAnalyzer, name: []const u8, arg_count: u8) SemanticError!*Symbol {
        const sym = try self.resolveSymbol(name);
        if (!sym.isCallable()) {
            return SemanticError.NotCallable;
        }
        if (sym.param_count != arg_count) {
            return SemanticError.WrongArgumentCount;
        }
        return sym;
    }
    
    /// Check break statement
    pub fn checkBreak(self: *SemanticAnalyzer) SemanticError!void {
        if (!self.current_scope.isInLoop()) {
            return SemanticError.BreakOutsideLoop;
        }
    }
    
    /// Check continue statement
    pub fn checkContinue(self: *SemanticAnalyzer) SemanticError!void {
        if (!self.current_scope.isInLoop()) {
            return SemanticError.ContinueOutsideLoop;
        }
    }
    
    /// Check return statement
    pub fn checkReturn(self: *SemanticAnalyzer) SemanticError!u32 {
        const func_scope = self.current_scope.getEnclosingFunction() orelse {
            return SemanticError.ReturnOutsideFunction;
        };
        return func_scope.return_type_id;
    }
    
    /// Add diagnostic
    pub fn addDiagnostic(self: *SemanticAnalyzer, kind: Diagnostic.DiagnosticKind, message: []const u8, line: u32, column: u16) !void {
        try self.diagnostics.append(.{
            .kind = kind,
            .message = message,
            .line = line,
            .column = column,
        });
        
        switch (kind) {
            .err => self.error_count += 1,
            .warning => self.warning_count += 1,
            .hint => {},
        }
    }
    
    /// Check for unused variables (warning)
    pub fn checkUnusedVariables(self: *SemanticAnalyzer) !void {
        try self.checkUnusedInScope(self.global_scope);
    }
    
    fn checkUnusedInScope(self: *SemanticAnalyzer, scope: *Scope) !void {
        var iter = scope.symbols.iterator();
        while (iter.next()) |entry| {
            const sym = entry.value_ptr;
            if (!sym.is_used and sym.kind == .variable) {
                try self.addDiagnostic(.warning, "unused variable", sym.decl_line, sym.decl_column);
            }
        }
        
        for (scope.children.items) |child| {
            try self.checkUnusedInScope(child);
        }
    }
    
    /// Get analysis statistics
    pub fn getStats(self: *const SemanticAnalyzer) AnalyzerStats {
        return .{
            .symbols_defined = self.symbols_defined,
            .lookups_performed = self.lookups_performed,
            .scope_count = self.all_scopes.items.len,
            .error_count = self.error_count,
            .warning_count = self.warning_count,
            .cache_hits = self.cache_hits,
        };
    }
    
    /// Check if analysis has errors
    pub fn hasErrors(self: *const SemanticAnalyzer) bool {
        return self.error_count > 0;
    }
};

pub const AnalyzerStats = struct {
    symbols_defined: u64,
    lookups_performed: u64,
    scope_count: usize,
    error_count: u32,
    warning_count: u32,
    cache_hits: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SemanticAnalyzer initialization" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    // Sacred symbols should be defined
    try std.testing.expect(analyzer.lookupSymbol("phi") != null);
    try std.testing.expect(analyzer.lookupSymbol("pi") != null);
    try std.testing.expect(analyzer.lookupSymbol("e") != null);
}

test "variable definition and lookup" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    try analyzer.defineVariable("x", 1, true);
    try analyzer.defineVariable("y", 2, false);
    
    const x = analyzer.lookupSymbol("x").?;
    try std.testing.expect(x.is_mutable);
    
    const y = analyzer.lookupSymbol("y").?;
    try std.testing.expect(!y.is_mutable);
}

test "scope nesting" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    try analyzer.defineVariable("global_var", 1, true);
    
    _ = try analyzer.enterScope(.function);
    try analyzer.defineVariable("local_var", 2, true);
    
    // Can see both
    try std.testing.expect(analyzer.lookupSymbol("global_var") != null);
    try std.testing.expect(analyzer.lookupSymbol("local_var") != null);
    
    analyzer.exitScope();
    
    // Can only see global
    try std.testing.expect(analyzer.lookupSymbol("global_var") != null);
    try std.testing.expect(analyzer.lookupSymbol("local_var") == null);
}

test "duplicate symbol error" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    try analyzer.defineVariable("x", 1, true);
    
    const result = analyzer.defineVariable("x", 2, true);
    try std.testing.expectError(SemanticError.SymbolAlreadyDefined, result);
}

test "undefined symbol error" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    const result = analyzer.resolveSymbol("undefined");
    try std.testing.expectError(SemanticError.UndefinedSymbol, result);
}

test "constant assignment error" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    try analyzer.defineConstant("CONST", 1);
    
    const result = analyzer.checkAssignment("CONST");
    try std.testing.expectError(SemanticError.AssignToConstant, result);
}

test "function call check" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    try analyzer.defineFunction("add", 2, 1);
    
    _ = try analyzer.checkCall("add", 2);
    
    const wrong_args = analyzer.checkCall("add", 3);
    try std.testing.expectError(SemanticError.WrongArgumentCount, wrong_args);
}

test "break/continue outside loop" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    // Outside loop
    try std.testing.expectError(SemanticError.BreakOutsideLoop, analyzer.checkBreak());
    try std.testing.expectError(SemanticError.ContinueOutsideLoop, analyzer.checkContinue());
    
    // Inside loop
    _ = try analyzer.enterScope(.loop);
    try analyzer.checkBreak();
    try analyzer.checkContinue();
}

test "return outside function" {
    const allocator = std.testing.allocator;
    var analyzer = try SemanticAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    try std.testing.expectError(SemanticError.ReturnOutsideFunction, analyzer.checkReturn());
    
    const func_scope = try analyzer.enterScope(.function);
    func_scope.return_type_id = 42;
    
    const ret_type = try analyzer.checkReturn();
    try std.testing.expectEqual(@as(u32, 42), ret_type);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
