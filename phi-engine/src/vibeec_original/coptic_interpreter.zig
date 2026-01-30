//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Interpreter
//! Tree-walking interpreter for Coptic AST
//! Memory managed via ArenaAllocator - no individual frees needed
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_parser = @import("coptic_parser_real.zig");
const coptic_stdlib = @import("coptic_stdlib.zig");
const trit_logic = @import("trit_logic.zig");

const AstNode = coptic_parser.AstNode;
const NodeKind = coptic_parser.NodeKind;

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;

/// Value type - uses slices allocated from arena (no individual frees)
pub const Value = union(enum) {
    int_: i64,
    float_: f64,
    bool_: bool,
    trit: i8,
    string_: []const u8,
    func: FuncValue,
    composed: ComposedFunc, // f >> g
    partial: PartialFunc,   // add(_, 5) - partial application
    array: ArrayValue,
    object: ObjectValue,
    some: *Value,     // Some(value)
    none,             // None
    ok: *Value,       // Ok(value)
    err_: *Value,     // Err(value)
    nil,
    placeholder,      // _ in partial application
    
    /// Function value - params are slice allocated from arena
    pub const FuncValue = struct {
        name: []const u8,
        params: []const []const u8, // Slice instead of ArrayList
        body: ?*const AstNode,
        is_builtin: bool,
        captured: ?*CapturedEnv, // Captured variables for closures
    };
    
    /// Captured environment for closures
    pub const CapturedEnv = struct {
        bindings: []const Binding,
        
        pub const Binding = struct {
            name: []const u8,
            value: Value,
        };
    };
    
    /// Array value - items are slice allocated from arena
    pub const ArrayValue = struct {
        items: []const Value, // Slice instead of ArrayList
    };
    
    /// Composed function value - f >> g
    pub const ComposedFunc = struct {
        first: *Value,  // f
        second: *Value, // g
    };
    
    /// Partial application - add(_, 5) creates a function waiting for first arg
    pub const PartialFunc = struct {
        func: *Value,           // Original function
        args: []const Value,    // Arguments (some may be placeholder)
        placeholder_indices: []const usize, // Which args are placeholders
    };
    
    /// Object value - key-value pairs
    pub const ObjectValue = struct {
        keys: []const []const u8,
        values: []const Value,
        
        pub fn get(self: ObjectValue, key: []const u8) ?Value {
            for (self.keys, 0..) |k, i| {
                if (std.mem.eql(u8, k, key)) {
                    return self.values[i];
                }
            }
            return null;
        }
    };
    
    pub fn format(self: Value, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .int_ => |v| try writer.print("{}", .{v}),
            .float_ => |v| try writer.print("{d:.6}", .{v}),
            .bool_ => |v| try writer.print("{}", .{v}),
            .trit => |v| {
                const sym = if (v > 0) "△" else if (v < 0) "▽" else "?";
                try writer.print("{s}", .{sym});
            },
            .string_ => |v| try writer.print("\"{s}\"", .{v}),
            .func => |v| try writer.print("<func {s}>", .{v.name}),
            .composed => try writer.print("<composed>", .{}),
            .object => |v| {
                try writer.print("{{", .{});
                for (v.keys, 0..) |key, i| {
                    if (i > 0) try writer.print(", ", .{});
                    try writer.print("{s}: {}", .{ key, v.values[i] });
                }
                try writer.print("}}", .{});
            },
            .array => |v| {
                try writer.print("[", .{});
                for (v.items, 0..) |item, i| {
                    if (i > 0) try writer.print(", ", .{});
                    try writer.print("{}", .{item});
                }
                try writer.print("]", .{});
            },
            .some => |v| try writer.print("Some({})", .{v.*}),
            .none => try writer.print("None", .{}),
            .ok => |v| try writer.print("Ok({})", .{v.*}),
            .err_ => |v| try writer.print("Err({})", .{v.*}),
            .nil => try writer.print("nil", .{}),
            .partial => try writer.print("<partial>", .{}),
            .placeholder => try writer.print("_", .{}),
        }
    }
    
    pub fn toInt(self: Value) i64 {
        return switch (self) {
            .int_ => |v| v,
            .float_ => |v| @intFromFloat(v),
            .bool_ => |v| if (v) @as(i64, 1) else 0,
            .trit => |v| v,
            else => 0,
        };
    }
    
    pub fn toFloat(self: Value) f64 {
        return switch (self) {
            .int_ => |v| @floatFromInt(v),
            .float_ => |v| v,
            .bool_ => |v| if (v) @as(f64, 1.0) else 0.0,
            .trit => |v| @floatFromInt(v),
            else => 0.0,
        };
    }
    
    pub fn toBool(self: Value) bool {
        return switch (self) {
            .int_ => |v| v != 0,
            .float_ => |v| v != 0.0,
            .bool_ => |v| v,
            .trit => |v| v > 0,
            .string_ => |v| v.len > 0,
            .array => |v| v.items.len > 0,
            .nil, .none, .placeholder => false,
            .some, .ok => true,
            .err_ => false,
            .func, .composed, .partial => true,
            .object => |v| v.keys.len > 0,
        };
    }
};

pub const Environment = struct {
    values: std.StringHashMap(Value),
    parent: ?*Environment,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, parent: ?*Environment) Environment {
        return .{
            .values = std.StringHashMap(Value).init(allocator),
            .parent = parent,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Environment) void {
        self.values.deinit(allocator);
    }
    
    pub fn define(self: *Environment, name: []const u8, value: Value) !void {
        try self.values.put(name, value);
    }
    
    pub fn get(self: *Environment, name: []const u8) ?Value {
        if (self.values.get(name)) |v| return v;
        if (self.parent) |p| return p.get(name);
        return null;
    }
    
    pub fn set(self: *Environment, name: []const u8, value: Value) bool {
        if (self.values.contains(name)) {
            self.values.put(name, value) catch return false;
            return true;
        }
        if (self.parent) |p| return p.set(name, value);
        return false;
    }
};

pub const InterpreterError = error{
    UndefinedVariable,
    TypeError,
    DivisionByZero,
    NotCallable,
    ArityMismatch,
    OutOfMemory,
};

pub const Interpreter = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    global: Environment,
    current: *Environment,
    source: []const u8,
    output: std.ArrayList(u8),
    call_depth: u32,
    
    pub fn init(allocator: std.mem.Allocator, source: []const u8) Interpreter {
        const arena = std.heap.ArenaAllocator.init(allocator);
        return Interpreter{
            .allocator = allocator,
            .arena = arena,
            .global = Environment.init(allocator, null), // Use main allocator for HashMap
            .current = undefined, // Will be set by caller using fixupSelfRef
            .source = source,
            .output = .empty,
            .call_depth = 0,
        };
    }
    
    /// Must be called after init to fix self-referential pointer
    pub fn fixupSelfRef(self: *Interpreter) void {
        self.current = &self.global;
        self.defineBuiltins() catch {};
    }
    
    pub fn deinit(self: *Interpreter) void {
        self.output.deinit(allocator);
        // Deinit HashMap BEFORE arena to avoid use-after-free
        // HashMap.deinit(allocator) only frees internal buckets, not values
        self.global.values.deinit(allocator);
        self.arena.deinit(allocator);
    }
    
    /// Reset interpreter state (for REPL)
    pub fn reset(self: *Interpreter) void {
        // Free HashMap first, then arena
        self.global.deinit(allocator);
        self.arena.deinit(allocator);
        self.arena = std.heap.ArenaAllocator.init(allocator);
        self.global = Environment.init(allocator, null);
        self.current = &self.global;
        self.call_depth = 0;
        self.output.clearRetainingCapacity();
        self.defineBuiltins() catch {};
    }
    
    /// Get arena allocator for Value allocations
    fn arenaAlloc(self: *Interpreter) std.mem.Allocator {
        return self.arena.allocator();
    }
    
    fn defineBuiltins(self: *Interpreter) !void {
        try self.global.define("phi", .{ .float_ = PHI });
        try self.global.define("trinity", .{ .int_ = TRINITY });
        try self.global.define("true", .{ .bool_ = true });
        try self.global.define("false", .{ .bool_ = false });
        try self.global.define("nil", .nil);
        
        // Trit constants
        try self.global.define("T", .{ .trit = 1 });
        try self.global.define("F", .{ .trit = -1 });
        try self.global.define("U", .{ .trit = 0 });
        
        // Functional combinators
        try self.global.define("id", .{ .func = .{ .name = "id", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("const_", .{ .func = .{ .name = "const_", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("flip", .{ .func = .{ .name = "flip", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("compose", .{ .func = .{ .name = "compose", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("pipe", .{ .func = .{ .name = "pipe", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("curry", .{ .func = .{ .name = "curry", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        
        // Point-free helpers
        try self.global.define("prop", .{ .func = .{ .name = "prop", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("eq", .{ .func = .{ .name = "eq", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("gt", .{ .func = .{ .name = "gt", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("lt", .{ .func = .{ .name = "lt", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("add", .{ .func = .{ .name = "add", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("mul", .{ .func = .{ .name = "mul", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
        try self.global.define("not_", .{ .func = .{ .name = "not_", .params = &.{}, .body = null, .is_builtin = true, .captured = null }});
    }
    
    pub fn interpret(self: *Interpreter, ast: *const AstNode) InterpreterError!Value {
        return self.eval(ast);
    }
    
    fn eval(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        return switch (node.kind) {
            .program => self.evalProgram(node),
            .const_decl, .var_decl, .let_decl => self.evalDecl(node),
            .let_destructure_array => self.evalArrayDestructure(node),
            .let_destructure_object => self.evalObjectDestructure(node),
            .func_decl => self.evalFuncDecl(node),
            .identifier => self.evalIdentifier(node),
            .literal_int => self.evalLiteralInt(node),
            .literal_float => self.evalLiteralFloat(node),
            .literal_string => self.evalLiteralString(node),
            .literal_trit => self.evalLiteralTrit(node),
            .literal_bool => self.evalLiteralBool(node),
            .literal_nil => .nil,
            .literal_none => .none,
            .placeholder => .nil, // _ placeholder returns nil when evaluated directly
            .literal_some => self.evalSome(node),
            .literal_ok => self.evalOk(node),
            .literal_err => self.evalErr(node),
            .binary_expr => self.evalBinary(node),
            .is_expr => self.evalIsExpr(node),
            .unary_expr => self.evalUnary(node),
            .call_expr => self.evalCall(node),
            .lambda_expr => self.evalLambda(node),
            .return_stmt => self.evalReturn(node),
            .if_expr => self.evalIf(node),
            .match_expr => self.evalMatch(node),
            .while_stmt => self.evalWhile(node),
            .for_stmt => self.evalFor(node),
            .block => self.evalBlock(node),
            .array_literal => self.evalArray(node),
            .list_comprehension => self.evalListComprehension(node),
            .object_literal => self.evalObject(node),
            .member_expr => self.evalMember(node),
            .optional_member => self.evalOptionalMember(node),
            .index_expr => self.evalIndex(node),
            .break_stmt => error.TypeError, // Use as signal
            .continue_stmt => error.TypeError, // Use as signal
            else => .nil,
        };
    }
    
    fn evalArrayDestructure(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        
        // Last child is the value expression
        const value_idx = node.children.items.len - 1;
        const arr_value = try self.eval(&node.children.items[value_idx]);
        
        // Must be an array
        const arr = switch (arr_value) {
            .array => |a| a,
            else => return .nil,
        };
        
        // Bind each identifier to corresponding array element
        var i: usize = 0;
        while (i < value_idx) : (i += 1) {
            const child = &node.children.items[i];
            if (child.kind == .rest_pattern) continue; // TODO
            
            const name = child.token.lexeme(self.source);
            const val = if (i < arr.items.len) arr.items[i] else Value.nil;
            self.current.define(name, val) catch return error.OutOfMemory;
        }
        
        return .nil;
    }
    
    fn evalObjectDestructure(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        
        // Last child is the value expression
        const value_idx = node.children.items.len - 1;
        const obj_value = try self.eval(&node.children.items[value_idx]);
        
        // Must be an object
        if (obj_value != .object) return .nil;
        const obj = obj_value.object;
        
        // Bind each identifier to corresponding object field
        var i: usize = 0;
        while (i < value_idx) : (i += 1) {
            const child = &node.children.items[i];
            const name = child.token.lexeme(self.source);
            const val = obj.get(name) orelse Value.nil;
            self.current.define(name, val) catch return error.OutOfMemory;
        }
        
        return .nil;
    }
    
    fn evalSome(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .none;
        const inner = try self.eval(&node.children.items[0]);
        const ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
        ptr.* = inner;
        return .{ .some = ptr };
    }
    
    fn evalOk(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        const inner = try self.eval(&node.children.items[0]);
        const ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
        ptr.* = inner;
        return .{ .ok = ptr };
    }
    
    fn evalErr(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        const inner = try self.eval(&node.children.items[0]);
        const ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
        ptr.* = inner;
        return .{ .err_ = ptr };
    }
    
    fn evalProgram(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        var result: Value = .nil;
        for (node.children.items) |*child| {
            result = try self.eval(child);
        }
        return result;
    }
    
    fn evalDecl(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        
        const name_node = &node.children.items[0];
        const name = name_node.token.lexeme(self.source);
        
        var value: Value = .nil;
        if (node.children.items.len > 1) {
            value = try self.eval(&node.children.items[1]);
        }
        
        self.current.define(name, value) catch return error.OutOfMemory;
        return value;
    }
    
    fn evalFuncDecl(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        
        const name_node = &node.children.items[0];
        const name = name_node.token.lexeme(self.source);
        
        // Count parameters and find body
        var param_count: usize = 0;
        var body_idx: usize = 1;
        
        for (node.children.items[1..], 1..) |*child, i| {
            if (child.kind == .block) {
                body_idx = i;
                break;
            }
            param_count += 1;
        }
        
        // Allocate params slice from arena
        const params = self.arenaAlloc().alloc([]const u8, param_count) catch return error.OutOfMemory;
        
        // Fill params
        var idx: usize = 0;
        for (node.children.items[1..]) |*child| {
            if (child.kind == .block) break;
            params[idx] = child.token.lexeme(self.source);
            idx += 1;
        }
        
        const body_node: ?*const AstNode = if (body_idx < node.children.items.len) 
            &node.children.items[body_idx] 
        else 
            null;
        
        const func_val = Value{ .func = .{
            .name = name,
            .params = params,
            .body = body_node,
            .is_builtin = false,
            .captured = null,
        } };
        
        self.current.define(name, func_val) catch return error.OutOfMemory;
        return func_val;
    }
    
    // Lambda: x => expr or (x, y) => expr
    fn evalLambda(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        
        // Last child is the body expression
        const body_idx = node.children.items.len - 1;
        const param_count = body_idx;
        
        // Allocate params slice from arena
        const params = self.arenaAlloc().alloc([]const u8, param_count) catch return error.OutOfMemory;
        
        // Fill params
        for (node.children.items[0..param_count], 0..) |*child, i| {
            params[i] = child.token.lexeme(self.source);
        }
        
        const body_node: ?*const AstNode = &node.children.items[body_idx];
        
        return Value{ .func = .{
            .name = "<lambda>",
            .params = params,
            .body = body_node,
            .is_builtin = false,
            .captured = null,
        } };
    }
    
    fn evalIdentifier(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        const name = node.token.lexeme(self.source);
        
        // Built-in functions
        const builtins = [_][]const u8{ "fib", "print", "len", "range", "abs", "min", "max", "push", "pop", "upper", "lower", "trim", "split", "join", "head", "tail", "take", "drop", "reverse", "map", "filter", "reduce", "flatMap", "zip", "find", "any", "all", "sum", "product" };
        for (builtins) |builtin| {
            if (std.mem.eql(u8, name, builtin)) {
                return .{ .func = .{
                    .name = builtin,
                    .params = &.{}, // Empty slice for builtins
                    .body = null,
                    .is_builtin = true, .captured = null,
                } };
            }
        }
        
        return self.current.get(name) orelse error.UndefinedVariable;
    }
    
    fn evalLiteralInt(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        const lexeme = node.token.lexeme(self.source);
        const val = std.fmt.parseInt(i64, lexeme, 10) catch 0;
        return .{ .int_ = val };
    }
    
    fn evalLiteralFloat(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        const lexeme = node.token.lexeme(self.source);
        const val = std.fmt.parseFloat(f64, lexeme) catch 0.0;
        return .{ .float_ = val };
    }
    
    fn evalLiteralTrit(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        const lexeme = node.token.lexeme(self.source);
        if (lexeme.len > 0) {
            const c = lexeme[0];
            if (c == 0xE2) { // UTF-8 triangle
                if (lexeme.len >= 3 and lexeme[1] == 0x96) {
                    if (lexeme[2] == 0xB3) return .{ .trit = 1 }; // △
                    if (lexeme[2] == 0xBD) return .{ .trit = -1 }; // ▽
                }
            }
        }
        return .{ .trit = 0 };
    }
    
    fn evalLiteralString(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        const lexeme = node.token.lexeme(self.source);
        // Remove quotes
        if (lexeme.len >= 2) {
            return .{ .string_ = lexeme[1 .. lexeme.len - 1] };
        }
        return .{ .string_ = "" };
    }
    
    fn evalLiteralBool(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        const lexeme = node.token.lexeme(self.source);
        return .{ .bool_ = std.mem.eql(u8, lexeme, "true") };
    }
    
    fn evalIf(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .nil;
        
        const cond = try self.eval(&node.children.items[0]);
        
        if (cond.toBool()) {
            return try self.eval(&node.children.items[1]);
        } else if (node.children.items.len > 2) {
            return try self.eval(&node.children.items[2]);
        }
        return .nil;
    }
    
    fn evalMatch(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .nil;
        
        // First child is the value to match
        const match_value = try self.eval(&node.children.items[0]);
        
        // Remaining children are match arms
        for (node.children.items[1..]) |*arm| {
            if (arm.kind != .match_arm) continue;
            if (arm.children.items.len < 2) continue;
            
            const pattern = &arm.children.items[0];
            
            // Determine if there's a guard and where the result is
            // If 3 children: pattern, guard, result
            // If 2 children: pattern, result
            const has_guard = arm.children.items.len >= 3;
            const guard_expr: ?*const AstNode = if (has_guard) &arm.children.items[1] else null;
            const result_idx: usize = if (has_guard) 2 else 1;
            const result_expr = &arm.children.items[result_idx];
            
            // Check if pattern matches
            if (self.matchPattern(pattern, match_value)) {
                // Bind pattern variable if it's an identifier (not wildcard)
                const pattern_name = pattern.token.lexeme(self.source);
                if (!std.mem.eql(u8, pattern_name, "_")) {
                    self.current.define(pattern_name, match_value) catch return error.OutOfMemory;
                }
                
                // Check guard if present
                if (guard_expr) |guard| {
                    const guard_result = try self.eval(guard);
                    if (!guard_result.toBool()) {
                        continue; // Guard failed, try next arm
                    }
                }
                
                return try self.eval(result_expr);
            }
        }
        
        return .nil;
    }
    
    fn matchPattern(self: *Interpreter, pattern: *const AstNode, value: Value) bool {
        const pattern_name = pattern.token.lexeme(self.source);
        
        // Wildcard matches everything
        if (std.mem.eql(u8, pattern_name, "_")) {
            return true;
        }
        
        // OR pattern: 1 | 2 | 3 - matches if any sub-pattern matches
        if (pattern.kind == .or_pattern) {
            for (pattern.children.items) |*sub_pattern| {
                if (self.matchPattern(sub_pattern, value)) {
                    return true;
                }
            }
            return false;
        }
        
        // Range pattern: 1..10 - matches if value is in range [start, end)
        if (pattern.kind == .range_pattern) {
            if (pattern.children.items.len >= 2) {
                const start_name = pattern.children.items[0].token.lexeme(self.source);
                const end_name = pattern.children.items[1].token.lexeme(self.source);
                const start_val = std.fmt.parseInt(i64, start_name, 10) catch return false;
                const end_val = std.fmt.parseInt(i64, end_name, 10) catch return false;
                if (value == .int_) {
                    return value.int_ >= start_val and value.int_ < end_val;
                }
            }
            return false;
        }
        
        // Literal patterns
        if (pattern.kind == .literal_int) {
            const pattern_val = std.fmt.parseInt(i64, pattern_name, 10) catch return false;
            return value == .int_ and value.int_ == pattern_val;
        }
        
        if (pattern.kind == .literal_string) {
            if (pattern_name.len >= 2) {
                const str = pattern_name[1 .. pattern_name.len - 1];
                return value == .string_ and std.mem.eql(u8, value.string_, str);
            }
            return false;
        }
        
        if (pattern.kind == .literal_bool) {
            const pattern_bool = std.mem.eql(u8, pattern_name, "true");
            return value == .bool_ and value.bool_ == pattern_bool;
        }
        
        // Identifier pattern with guard: check if there's a guard condition
        // Guards are handled in the match arm parsing - for now, identifiers always match
        if (pattern.kind == .identifier) {
            // Check for guard in the arm (third child if present)
            // For now, just match and let the caller handle guards
            return true;
        }
        
        return false;
    }
    
    fn evalWhile(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .nil;
        
        var result: Value = .nil;
        var iterations: u32 = 0;
        const max_iterations: u32 = 10000;
        
        while (iterations < max_iterations) : (iterations += 1) {
            const cond = try self.eval(&node.children.items[0]);
            if (!cond.toBool()) break;
            result = self.eval(&node.children.items[1]) catch |err| {
                if (err == error.TypeError) break; // break statement
                return err;
            };
        }
        return result;
    }
    
    fn evalFor(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 3) return .nil;
        
        const iter_name = node.children.items[0].token.lexeme(self.source);
        const iterable = try self.eval(&node.children.items[1]);
        
        var result: Value = .nil;
        
        // Iterate over array
        if (iterable == .array) {
            for (iterable.array.items) |item| {
                self.current.define(iter_name, item) catch return error.OutOfMemory;
                result = self.eval(&node.children.items[2]) catch |err| {
                    if (err == error.TypeError) break; // break statement
                    return err;
                };
            }
            return result;
        }
        
        // Iterate over range (integer)
        if (iterable == .int_) {
            var i: i64 = 0;
            while (i < iterable.int_) : (i += 1) {
                self.current.define(iter_name, .{ .int_ = i }) catch return error.OutOfMemory;
                result = self.eval(&node.children.items[2]) catch |err| {
                    if (err == error.TypeError) break;
                    return err;
                };
            }
            return result;
        }
        
        // Iterate over string characters
        if (iterable == .string_) {
            for (iterable.string_) |c| {
                self.current.define(iter_name, .{ .int_ = c }) catch return error.OutOfMemory;
                result = self.eval(&node.children.items[2]) catch |err| {
                    if (err == error.TypeError) break;
                    return err;
                };
            }
            return result;
        }
        
        return result;
    }
    
    fn evalBlock(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        var result: Value = .nil;
        for (node.children.items) |*child| {
            result = try self.eval(child);
        }
        return result;
    }
    
    fn evalArray(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        // First pass: count total elements (including spread)
        var total: usize = 0;
        for (node.children.items) |*child| {
            if (child.kind == .spread_element) {
                if (child.children.items.len > 0) {
                    const spread_val = try self.eval(&child.children.items[0]);
                    if (spread_val == .array) {
                        total += spread_val.array.items.len;
                    } else {
                        total += 1;
                    }
                }
            } else {
                total += 1;
            }
        }
        
        // Allocate items slice from arena
        const items = self.arenaAlloc().alloc(Value, total) catch return error.OutOfMemory;
        
        // Second pass: fill items
        var idx: usize = 0;
        for (node.children.items) |*child| {
            if (child.kind == .spread_element) {
                if (child.children.items.len > 0) {
                    const spread_val = try self.eval(&child.children.items[0]);
                    if (spread_val == .array) {
                        for (spread_val.array.items) |item| {
                            items[idx] = item;
                            idx += 1;
                        }
                    } else {
                        items[idx] = spread_val;
                        idx += 1;
                    }
                }
            } else {
                items[idx] = try self.eval(child);
                idx += 1;
            }
        }
        return .{ .array = .{ .items = items } };
    }
    
    // List comprehension: [expr for x in arr if cond]
    fn evalListComprehension(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        // Children: [0] = mapping expr, [1] = iter var, [2] = iterable, [3] = filter (optional)
        if (node.children.items.len < 3) return .{ .array = .{ .items = &.{} } };
        
        const map_expr = &node.children.items[0];
        const iter_var = &node.children.items[1];
        const iterable_expr = &node.children.items[2];
        const filter_expr: ?*const AstNode = if (node.children.items.len > 3) &node.children.items[3] else null;
        
        const iter_name = iter_var.token.lexeme(self.source);
        const iterable = try self.eval(iterable_expr);
        
        // Must be an array
        if (iterable != .array) return .{ .array = .{ .items = &.{} } };
        
        const arr = iterable.array;
        
        // First pass: count results (with filter)
        var count: usize = 0;
        for (arr.items) |item| {
            self.current.define(iter_name, item) catch return error.OutOfMemory;
            if (filter_expr) |filter| {
                const cond = try self.eval(filter);
                if (!cond.toBool()) continue;
            }
            count += 1;
        }
        
        // Allocate result array
        const items = self.arenaAlloc().alloc(Value, count) catch return error.OutOfMemory;
        
        // Second pass: compute results
        var idx: usize = 0;
        for (arr.items) |item| {
            self.current.define(iter_name, item) catch return error.OutOfMemory;
            if (filter_expr) |filter| {
                const cond = try self.eval(filter);
                if (!cond.toBool()) continue;
            }
            items[idx] = try self.eval(map_expr);
            idx += 1;
        }
        
        return .{ .array = .{ .items = items } };
    }
    
    // Object literal: {x: 1, y: 2, ...obj}
    // Later keys override earlier ones (like JavaScript spread)
    fn evalObject(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        // Use temporary lists to collect key-value pairs with deduplication
        // Later keys override earlier ones
        var key_list = std.ArrayList([]const u8).init(self.arenaAlloc());
        var value_list = std.ArrayList(Value).init(self.arenaAlloc());
        
        for (node.children.items) |*child| {
            if (child.kind == .spread_element) {
                if (child.children.items.len > 0) {
                    const spread_val = try self.eval(&child.children.items[0]);
                    if (spread_val == .object) {
                        for (spread_val.object.keys, 0..) |k, i| {
                            // Check if key already exists, update if so
                            var found = false;
                            for (key_list.items, 0..) |existing_key, j| {
                                if (std.mem.eql(u8, existing_key, k)) {
                                    value_list.items[j] = spread_val.object.values[i];
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                key_list.append(allocator, k) catch return error.OutOfMemory;
                                value_list.append(allocator, spread_val.object.values[i]) catch return error.OutOfMemory;
                            }
                        }
                    }
                }
            } else {
                // Regular field
                const key = child.token.lexeme(self.source);
                const value = if (child.children.items.len > 0)
                    try self.eval(&child.children.items[0])
                else
                    .nil;
                
                // Check if key already exists, update if so
                var found = false;
                for (key_list.items, 0..) |existing_key, j| {
                    if (std.mem.eql(u8, existing_key, key)) {
                        value_list.items[j] = value;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    key_list.append(allocator, key) catch return error.OutOfMemory;
                    value_list.append(allocator, value) catch return error.OutOfMemory;
                }
            }
        }
        
        // Convert to fixed arrays
        const keys = self.arenaAlloc().alloc([]const u8, key_list.items.len) catch return error.OutOfMemory;
        const values = self.arenaAlloc().alloc(Value, value_list.items.len) catch return error.OutOfMemory;
        @memcpy(keys, key_list.items);
        @memcpy(values, value_list.items);
        
        return .{ .object = .{ .keys = keys, .values = values } };
    }
    
    // Member access: obj.field
    fn evalMember(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .nil;
        
        const obj_val = try self.eval(&node.children.items[0]);
        const field_name = node.children.items[1].token.lexeme(self.source);
        
        if (obj_val == .object) {
            return obj_val.object.get(field_name) orelse .nil;
        }
        
        return .nil;
    }
    
    // Optional member access: obj?.field (returns nil if obj is nil/none)
    fn evalOptionalMember(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .nil;
        
        const obj_val = try self.eval(&node.children.items[0]);
        
        // If nil or none, return nil without error
        if (obj_val == .nil or obj_val == .none) {
            return .nil;
        }
        
        const field_name = node.children.items[1].token.lexeme(self.source);
        
        if (obj_val == .object) {
            return obj_val.object.get(field_name) orelse .nil;
        }
        
        return .nil;
    }
    
    fn evalIndex(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .nil;
        
        const container = try self.eval(&node.children.items[0]);
        const index = try self.eval(&node.children.items[1]);
        const idx = index.toInt();
        
        if (container == .array) {
            const items = container.array.items;
            if (idx >= 0 and idx < @as(i64, @intCast(items.len))) {
                return items[@intCast(idx)];
            }
            // Negative index from end
            if (idx < 0) {
                const pos = @as(i64, @intCast(items.len)) + idx;
                if (pos >= 0) {
                    return items[@intCast(pos)];
                }
            }
        }
        
        if (container == .string_) {
            const str = container.string_;
            if (idx >= 0 and idx < @as(i64, @intCast(str.len))) {
                // Return single character as string
                return .{ .string_ = str[@intCast(idx)..][0..1] };
            }
        }
        
        return .nil;
    }
    
    // Type check: x is Type
    fn evalIsExpr(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .{ .bool_ = false };
        
        const value = try self.eval(&node.children.items[0]);
        const type_name = node.children.items[1].token.lexeme(self.source);
        
        const result = blk: {
            if (std.mem.eql(u8, type_name, "Int")) {
                break :blk value == .int_;
            } else if (std.mem.eql(u8, type_name, "Float")) {
                break :blk value == .float_;
            } else if (std.mem.eql(u8, type_name, "String")) {
                break :blk value == .string_;
            } else if (std.mem.eql(u8, type_name, "Bool")) {
                break :blk value == .bool_;
            } else if (std.mem.eql(u8, type_name, "Array")) {
                break :blk value == .array;
            } else if (std.mem.eql(u8, type_name, "Object")) {
                break :blk value == .object;
            } else if (std.mem.eql(u8, type_name, "Function") or std.mem.eql(u8, type_name, "Func")) {
                break :blk value == .func or value == .composed;
            } else if (std.mem.eql(u8, type_name, "Some")) {
                break :blk value == .some;
            } else if (std.mem.eql(u8, type_name, "None")) {
                break :blk value == .none;
            } else if (std.mem.eql(u8, type_name, "Ok")) {
                break :blk value == .ok;
            } else if (std.mem.eql(u8, type_name, "Err")) {
                break :blk value == .err_;
            } else if (std.mem.eql(u8, type_name, "Nil")) {
                break :blk value == .nil;
            } else if (std.mem.eql(u8, type_name, "Option")) {
                break :blk value == .some or value == .none;
            } else if (std.mem.eql(u8, type_name, "Result")) {
                break :blk value == .ok or value == .err_;
            } else {
                break :blk false;
            }
        };
        
        return .{ .bool_ = result };
    }
    
    fn evalBinary(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 2) return .nil;
        
        const left = try self.eval(&node.children.items[0]);
        const right = try self.eval(&node.children.items[1]);
        const op = node.token.lexeme(self.source);
        
        // Trit operations
        if (left == .trit and right == .trit) {
            const a = trit_logic.Trit.fromInt(left.trit);
            const b = trit_logic.Trit.fromInt(right.trit);
            if (std.mem.eql(u8, op, "&&") or std.mem.eql(u8, op, "and")) {
                return .{ .trit = a.@"and"(b).toInt() };
            }
            if (std.mem.eql(u8, op, "||") or std.mem.eql(u8, op, "or")) {
                return .{ .trit = a.@"or"(b).toInt() };
            }
        }
        
        // String concatenation
        if (std.mem.eql(u8, op, "+")) {
            if (left == .string_ and right == .string_) {
                // Concatenate strings using arena
                const total_len = left.string_.len + right.string_.len;
                const result = self.arenaAlloc().alloc(u8, total_len) catch return error.OutOfMemory;
                @memcpy(result[0..left.string_.len], left.string_);
                @memcpy(result[left.string_.len..], right.string_);
                return .{ .string_ = result };
            }
        }
        
        // Numeric operations
        if (std.mem.eql(u8, op, "+")) {
            if (left == .float_ or right == .float_) {
                return .{ .float_ = left.toFloat() + right.toFloat() };
            }
            return .{ .int_ = left.toInt() + right.toInt() };
        }
        if (std.mem.eql(u8, op, "-")) {
            if (left == .float_ or right == .float_) {
                return .{ .float_ = left.toFloat() - right.toFloat() };
            }
            return .{ .int_ = left.toInt() - right.toInt() };
        }
        if (std.mem.eql(u8, op, "*")) {
            if (left == .float_ or right == .float_) {
                return .{ .float_ = left.toFloat() * right.toFloat() };
            }
            return .{ .int_ = left.toInt() * right.toInt() };
        }
        if (std.mem.eql(u8, op, "/")) {
            const r = right.toInt();
            if (r == 0) return error.DivisionByZero;
            return .{ .int_ = @divTrunc(left.toInt(), r) };
        }
        if (std.mem.eql(u8, op, "%")) {
            const r = right.toInt();
            if (r == 0) return error.DivisionByZero;
            return .{ .int_ = @mod(left.toInt(), r) };
        }
        
        // Null coalescing: x ?? default
        if (std.mem.eql(u8, op, "??")) {
            // Return left if it's not nil/none, otherwise return right
            if (left == .nil or left == .none) {
                return right;
            }
            return left;
        }
        
        // Function composition: f >> g means g(f(x))
        if (std.mem.eql(u8, op, ">>")) {
            // Create a composed function
            if ((left == .func or left == .composed) and (right == .func or right == .composed)) {
                const first = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                const second = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                first.* = left;
                second.* = right;
                return .{ .composed = .{ .first = first, .second = second } };
            }
        }
        
        // Comparison
        if (std.mem.eql(u8, op, "==")) {
            return .{ .bool_ = left.toInt() == right.toInt() };
        }
        if (std.mem.eql(u8, op, "!=")) {
            return .{ .bool_ = left.toInt() != right.toInt() };
        }
        if (std.mem.eql(u8, op, "<")) {
            return .{ .bool_ = left.toInt() < right.toInt() };
        }
        if (std.mem.eql(u8, op, ">")) {
            return .{ .bool_ = left.toInt() > right.toInt() };
        }
        if (std.mem.eql(u8, op, "<=")) {
            return .{ .bool_ = left.toInt() <= right.toInt() };
        }
        if (std.mem.eql(u8, op, ">=")) {
            return .{ .bool_ = left.toInt() >= right.toInt() };
        }
        
        return .nil;
    }
    
    fn evalUnary(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        
        const operand = try self.eval(&node.children.items[0]);
        const op = node.token.lexeme(self.source);
        
        if (std.mem.eql(u8, op, "-")) {
            if (operand == .float_) return .{ .float_ = -operand.float_ };
            return .{ .int_ = -operand.toInt() };
        }
        if (std.mem.eql(u8, op, "!") or std.mem.eql(u8, op, "not")) {
            if (operand == .trit) {
                const t = trit_logic.Trit.fromInt(operand.trit);
                return .{ .trit = t.not().toInt() };
            }
            return .{ .bool_ = !operand.toBool() };
        }
        
        return operand;
    }
    
    fn evalCall(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len < 1) return .nil;
        
        const callee = try self.eval(&node.children.items[0]);
        
        // Collect arguments using arena (no need to free)
        const arg_count = node.children.items.len - 1;
        const args = self.arenaAlloc().alloc(Value, arg_count) catch return error.OutOfMemory;
        
        // Check for placeholders to create partial application
        var placeholder_count: usize = 0;
        for (node.children.items[1..], 0..) |*arg_node, i| {
            if (arg_node.kind == .placeholder) {
                args[i] = .placeholder;
                placeholder_count += 1;
            } else {
                args[i] = try self.eval(arg_node);
            }
        }
        
        // If there are placeholders, create a partial function
        if (placeholder_count > 0) {
            // Collect placeholder indices
            const indices = self.arenaAlloc().alloc(usize, placeholder_count) catch return error.OutOfMemory;
            var idx: usize = 0;
            for (args, 0..) |arg, i| {
                if (arg == .placeholder) {
                    indices[idx] = i;
                    idx += 1;
                }
            }
            
            // Store callee in arena
            const callee_ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
            callee_ptr.* = callee;
            
            return .{ .partial = .{
                .func = callee_ptr,
                .args = args,
                .placeholder_indices = indices,
            }};
        }
        
        return self.callValue(callee, args);
    }
    
    fn callValue(self: *Interpreter, callee: Value, args: []const Value) InterpreterError!Value {
        // Handle composed functions: (f >> g)(x) = g(f(x))
        if (callee == .composed) {
            const comp = callee.composed;
            // First apply f to args
            const intermediate = try self.callValue(comp.first.*, args);
            // Then apply g to result
            const single_arg = self.arenaAlloc().alloc(Value, 1) catch return error.OutOfMemory;
            single_arg[0] = intermediate;
            return self.callValue(comp.second.*, single_arg);
        }
        
        // Handle partial application: add5(3) where add5 = add(_, 5)
        if (callee == .partial) {
            const partial = callee.partial;
            // Fill in placeholders with provided args
            if (args.len != partial.placeholder_indices.len) {
                return error.TypeError; // Wrong number of args
            }
            
            // Create new args array with placeholders filled
            const full_args = self.arenaAlloc().alloc(Value, partial.args.len) catch return error.OutOfMemory;
            @memcpy(full_args, partial.args);
            
            for (partial.placeholder_indices, 0..) |placeholder_idx, i| {
                full_args[placeholder_idx] = args[i];
            }
            
            return self.callValue(partial.func.*, full_args);
        }
        
        if (callee != .func) return error.NotCallable;
        
        const func = callee.func;
        
        // Built-in functions
        if (func.is_builtin) {
            return self.callBuiltin(func.name, args);
        }
        
        // User-defined function
        return self.callUserFunc(func, args);
    }
    
    fn callBuiltin(self: *Interpreter, name: []const u8, args: []const Value) InterpreterError!Value {
        if (std.mem.eql(u8, name, "fib")) {
            if (args.len > 0) {
                const n: u32 = @intCast(@max(0, args[0].toInt()));
                return .{ .int_ = @intCast(coptic_stdlib.math.fibonacci(n)) };
            }
            return .{ .int_ = 0 };
        }
        
        if (std.mem.eql(u8, name, "print")) {
            for (args) |arg| {
                var buf: [512]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "{}", .{arg}) catch "?";
                self.output.appendSlice(allocator, str) catch {};
            }
            self.output.append(allocator, '\n') catch {};
            return .nil;
        }
        
        if (std.mem.eql(u8, name, "len")) {
            if (args.len > 0) {
                const arg = args[0];
                if (arg == .string_) {
                    return .{ .int_ = @intCast(arg.string_.len) };
                }
                if (arg == .array) {
                    return .{ .int_ = @intCast(arg.array.items.len) };
                }
            }
            return .{ .int_ = 0 };
        }
        
        if (std.mem.eql(u8, name, "range")) {
            if (args.len > 0) {
                // Create array [0, 1, ..., n-1] using arena
                const n = args[0].toInt();
                if (n <= 0) {
                    return .{ .array = .{ .items = &.{} } };
                }
                const count: usize = @intCast(n);
                const items = self.arenaAlloc().alloc(Value, count) catch return error.OutOfMemory;
                for (items, 0..) |*item, i| {
                    item.* = .{ .int_ = @intCast(i) };
                }
                return .{ .array = .{ .items = items } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        if (std.mem.eql(u8, name, "abs")) {
            if (args.len > 0) {
                const v = args[0].toInt();
                return .{ .int_ = if (v < 0) -v else v };
            }
            return .{ .int_ = 0 };
        }
        
        if (std.mem.eql(u8, name, "min")) {
            if (args.len > 1) {
                return .{ .int_ = @min(args[0].toInt(), args[1].toInt()) };
            }
            return .{ .int_ = 0 };
        }
        
        if (std.mem.eql(u8, name, "max")) {
            if (args.len > 1) {
                return .{ .int_ = @max(args[0].toInt(), args[1].toInt()) };
            }
            return .{ .int_ = 0 };
        }
        
        if (std.mem.eql(u8, name, "push")) {
            // push(arr, val) - modifies array in place
            return .nil;
        }
        
        if (std.mem.eql(u8, name, "pop")) {
            // pop(arr) - removes and returns last element
            return .nil;
        }
        
        // String functions
        if (std.mem.eql(u8, name, "upper")) {
            if (args.len > 0 and args[0] == .string_) {
                const s = args[0].string_;
                const result = self.arenaAlloc().alloc(u8, s.len) catch return error.OutOfMemory;
                for (s, 0..) |c, i| {
                    result[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
                }
                return .{ .string_ = result };
            }
            return .{ .string_ = "" };
        }
        
        if (std.mem.eql(u8, name, "lower")) {
            if (args.len > 0 and args[0] == .string_) {
                const s = args[0].string_;
                const result = self.arenaAlloc().alloc(u8, s.len) catch return error.OutOfMemory;
                for (s, 0..) |c, i| {
                    result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
                }
                return .{ .string_ = result };
            }
            return .{ .string_ = "" };
        }
        
        if (std.mem.eql(u8, name, "trim")) {
            if (args.len > 0 and args[0] == .string_) {
                const s = args[0].string_;
                var start: usize = 0;
                var end: usize = s.len;
                while (start < end and (s[start] == ' ' or s[start] == '\t' or s[start] == '\n')) : (start += 1) {}
                while (end > start and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\n')) : (end -= 1) {}
                return .{ .string_ = s[start..end] };
            }
            return .{ .string_ = "" };
        }
        
        if (std.mem.eql(u8, name, "split")) {
            if (args.len > 1 and args[0] == .string_ and args[1] == .string_) {
                const s = args[0].string_;
                const delim = args[1].string_;
                if (delim.len == 0) return .{ .array = .{ .items = &.{} } };
                
                // Count splits
                var count: usize = 1;
                var i: usize = 0;
                while (i + delim.len <= s.len) : (i += 1) {
                    if (std.mem.eql(u8, s[i..i + delim.len], delim)) {
                        count += 1;
                        i += delim.len - 1;
                    }
                }
                
                // Create array
                const items = self.arenaAlloc().alloc(Value, count) catch return error.OutOfMemory;
                var idx: usize = 0;
                var start: usize = 0;
                i = 0;
                while (i + delim.len <= s.len) : (i += 1) {
                    if (std.mem.eql(u8, s[i..i + delim.len], delim)) {
                        items[idx] = .{ .string_ = s[start..i] };
                        idx += 1;
                        start = i + delim.len;
                        i += delim.len - 1;
                    }
                }
                items[idx] = .{ .string_ = s[start..] };
                return .{ .array = .{ .items = items } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        if (std.mem.eql(u8, name, "join")) {
            if (args.len > 1 and args[0] == .array and args[1] == .string_) {
                const arr = args[0].array;
                const delim = args[1].string_;
                
                // Calculate total length
                var total_len: usize = 0;
                for (arr.items, 0..) |item, j| {
                    if (item == .string_) {
                        total_len += item.string_.len;
                        if (j > 0) total_len += delim.len;
                    }
                }
                
                // Build result
                const result = self.arenaAlloc().alloc(u8, total_len) catch return error.OutOfMemory;
                var pos: usize = 0;
                for (arr.items, 0..) |item, j| {
                    if (item == .string_) {
                        if (j > 0) {
                            @memcpy(result[pos..pos + delim.len], delim);
                            pos += delim.len;
                        }
                        @memcpy(result[pos..pos + item.string_.len], item.string_);
                        pos += item.string_.len;
                    }
                }
                return .{ .string_ = result };
            }
            return .{ .string_ = "" };
        }
        
        // Array functions
        if (std.mem.eql(u8, name, "head")) {
            if (args.len > 0 and args[0] == .array) {
                const arr = args[0].array;
                if (arr.items.len > 0) return arr.items[0];
            }
            return .nil;
        }
        
        if (std.mem.eql(u8, name, "tail")) {
            if (args.len > 0 and args[0] == .array) {
                const arr = args[0].array;
                if (arr.items.len > 1) {
                    return .{ .array = .{ .items = arr.items[1..] } };
                }
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        if (std.mem.eql(u8, name, "take")) {
            if (args.len > 1 and args[0] == .array) {
                const arr = args[0].array;
                const n: usize = @intCast(@max(0, args[1].toInt()));
                const count = @min(n, arr.items.len);
                return .{ .array = .{ .items = arr.items[0..count] } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        if (std.mem.eql(u8, name, "drop")) {
            if (args.len > 1 and args[0] == .array) {
                const arr = args[0].array;
                const n: usize = @intCast(@max(0, args[1].toInt()));
                const start = @min(n, arr.items.len);
                return .{ .array = .{ .items = arr.items[start..] } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        if (std.mem.eql(u8, name, "reverse")) {
            if (args.len > 0 and args[0] == .array) {
                const arr = args[0].array;
                const items = self.arenaAlloc().alloc(Value, arr.items.len) catch return error.OutOfMemory;
                for (arr.items, 0..) |item, i| {
                    items[arr.items.len - 1 - i] = item;
                }
                return .{ .array = .{ .items = items } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        // map(arr, fn) - apply fn to each element
        if (std.mem.eql(u8, name, "map")) {
            if (args.len > 1 and args[0] == .array and (args[1] == .func or args[1] == .composed)) {
                const arr = args[0].array;
                const items = self.arenaAlloc().alloc(Value, arr.items.len) catch return error.OutOfMemory;
                const single_arg = self.arenaAlloc().alloc(Value, 1) catch return error.OutOfMemory;
                for (arr.items, 0..) |item, i| {
                    single_arg[0] = item;
                    items[i] = try self.callValue(args[1], single_arg);
                }
                return .{ .array = .{ .items = items } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        // filter(arr, fn) - keep elements where fn returns true
        if (std.mem.eql(u8, name, "filter")) {
            if (args.len > 1 and args[0] == .array and (args[1] == .func or args[1] == .composed)) {
                const arr = args[0].array;
                // First pass: count matching elements
                var count: usize = 0;
                const single_arg = self.arenaAlloc().alloc(Value, 1) catch return error.OutOfMemory;
                for (arr.items) |item| {
                    single_arg[0] = item;
                    const result = try self.callValue(args[1], single_arg);
                    if (result.toBool()) count += 1;
                }
                // Second pass: collect matching elements
                const items = self.arenaAlloc().alloc(Value, count) catch return error.OutOfMemory;
                var idx: usize = 0;
                for (arr.items) |item| {
                    single_arg[0] = item;
                    const result = try self.callValue(args[1], single_arg);
                    if (result.toBool()) {
                        items[idx] = item;
                        idx += 1;
                    }
                }
                return .{ .array = .{ .items = items } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        // reduce(arr, fn, init) - fold array with fn
        if (std.mem.eql(u8, name, "reduce")) {
            if (args.len > 2 and args[0] == .array and (args[1] == .func or args[1] == .composed)) {
                const arr = args[0].array;
                var acc = args[2];
                const two_args = self.arenaAlloc().alloc(Value, 2) catch return error.OutOfMemory;
                for (arr.items) |item| {
                    two_args[0] = acc;
                    two_args[1] = item;
                    acc = try self.callValue(args[1], two_args);
                }
                return acc;
            }
            return args[2];
        }
        
        // flatMap(arr, fn) - map then flatten
        if (std.mem.eql(u8, name, "flatMap")) {
            if (args.len > 1 and args[0] == .array and (args[1] == .func or args[1] == .composed)) {
                const arr = args[0].array;
                // First pass: count total elements
                var total: usize = 0;
                const single_arg = self.arenaAlloc().alloc(Value, 1) catch return error.OutOfMemory;
                for (arr.items) |item| {
                    single_arg[0] = item;
                    const result = try self.callValue(args[1], single_arg);
                    if (result == .array) {
                        total += result.array.items.len;
                    } else {
                        total += 1;
                    }
                }
                // Second pass: collect elements
                const items = self.arenaAlloc().alloc(Value, total) catch return error.OutOfMemory;
                var idx: usize = 0;
                for (arr.items) |item| {
                    single_arg[0] = item;
                    const result = try self.callValue(args[1], single_arg);
                    if (result == .array) {
                        for (result.array.items) |sub_item| {
                            items[idx] = sub_item;
                            idx += 1;
                        }
                    } else {
                        items[idx] = result;
                        idx += 1;
                    }
                }
                return .{ .array = .{ .items = items } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        // zip(arr1, arr2) - combine two arrays into pairs
        if (std.mem.eql(u8, name, "zip")) {
            if (args.len > 1 and args[0] == .array and args[1] == .array) {
                const arr1 = args[0].array;
                const arr2 = args[1].array;
                const len = @min(arr1.items.len, arr2.items.len);
                const items = self.arenaAlloc().alloc(Value, len) catch return error.OutOfMemory;
                for (0..len) |i| {
                    const pair = self.arenaAlloc().alloc(Value, 2) catch return error.OutOfMemory;
                    pair[0] = arr1.items[i];
                    pair[1] = arr2.items[i];
                    items[i] = .{ .array = .{ .items = pair } };
                }
                return .{ .array = .{ .items = items } };
            }
            return .{ .array = .{ .items = &.{} } };
        }
        
        // find(arr, fn) - find first element where fn returns true
        if (std.mem.eql(u8, name, "find")) {
            if (args.len > 1 and args[0] == .array and (args[1] == .func or args[1] == .composed)) {
                const arr = args[0].array;
                const single_arg = self.arenaAlloc().alloc(Value, 1) catch return error.OutOfMemory;
                for (arr.items) |item| {
                    single_arg[0] = item;
                    const result = try self.callValue(args[1], single_arg);
                    if (result.toBool()) {
                        const ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                        ptr.* = item;
                        return .{ .some = ptr };
                    }
                }
                return .none;
            }
            return .none;
        }
        
        // any(arr, fn) - true if any element satisfies fn
        if (std.mem.eql(u8, name, "any")) {
            if (args.len > 1 and args[0] == .array and (args[1] == .func or args[1] == .composed)) {
                const arr = args[0].array;
                const single_arg = self.arenaAlloc().alloc(Value, 1) catch return error.OutOfMemory;
                for (arr.items) |item| {
                    single_arg[0] = item;
                    const result = try self.callValue(args[1], single_arg);
                    if (result.toBool()) return .{ .bool_ = true };
                }
                return .{ .bool_ = false };
            }
            return .{ .bool_ = false };
        }
        
        // all(arr, fn) - true if all elements satisfy fn
        if (std.mem.eql(u8, name, "all")) {
            if (args.len > 1 and args[0] == .array and (args[1] == .func or args[1] == .composed)) {
                const arr = args[0].array;
                const single_arg = self.arenaAlloc().alloc(Value, 1) catch return error.OutOfMemory;
                for (arr.items) |item| {
                    single_arg[0] = item;
                    const result = try self.callValue(args[1], single_arg);
                    if (!result.toBool()) return .{ .bool_ = false };
                }
                return .{ .bool_ = true };
            }
            return .{ .bool_ = true };
        }
        
        // sum(arr) - sum of all elements
        if (std.mem.eql(u8, name, "sum")) {
            if (args.len > 0 and args[0] == .array) {
                var total: i64 = 0;
                for (args[0].array.items) |item| {
                    total += item.toInt();
                }
                return .{ .int_ = total };
            }
            return .{ .int_ = 0 };
        }
        
        // product(arr) - product of all elements
        if (std.mem.eql(u8, name, "product")) {
            if (args.len > 0 and args[0] == .array) {
                var total: i64 = 1;
                for (args[0].array.items) |item| {
                    total *= item.toInt();
                }
                return .{ .int_ = total };
            }
            return .{ .int_ = 1 };
        }
        
        // ═══════════════════════════════════════════════════════════════════
        // FUNCTIONAL COMBINATORS
        // ═══════════════════════════════════════════════════════════════════
        
        // id(x) - identity function, returns x unchanged
        if (std.mem.eql(u8, name, "id")) {
            if (args.len > 0) return args[0];
            return .nil;
        }
        
        // const_(x, y) - constant function, always returns x
        if (std.mem.eql(u8, name, "const_")) {
            if (args.len > 0) return args[0];
            return .nil;
        }
        
        // flip(f) - returns a function that calls f with args reversed
        // flip(f)(a, b) = f(b, a)
        if (std.mem.eql(u8, name, "flip")) {
            if (args.len > 0 and (args[0] == .func or args[0] == .partial or args[0] == .composed)) {
                // Create a flipped function wrapper
                const func_ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                func_ptr.* = args[0];
                
                // Return a special composed function that flips args
                return .{ .func = .{
                    .name = "flipped",
                    .params = &.{},
                    .body = null,
                    .is_builtin = true, .captured = null,
                }};
            }
            return .nil;
        }
        
        // compose(f, g) - function composition, compose(f, g)(x) = f(g(x))
        if (std.mem.eql(u8, name, "compose")) {
            if (args.len >= 2) {
                const f_ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                const g_ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                f_ptr.* = args[0];
                g_ptr.* = args[1];
                return .{ .composed = .{ .first = g_ptr, .second = f_ptr } };
            }
            return .nil;
        }
        
        // pipe(f, g) - pipe composition, pipe(f, g)(x) = g(f(x))
        if (std.mem.eql(u8, name, "pipe")) {
            if (args.len >= 2) {
                const f_ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                const g_ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                f_ptr.* = args[0];
                g_ptr.* = args[1];
                return .{ .composed = .{ .first = f_ptr, .second = g_ptr } };
            }
            return .nil;
        }
        
        // curry(f) - curries a function (for now, just returns f)
        if (std.mem.eql(u8, name, "curry")) {
            if (args.len > 0) return args[0];
            return .nil;
        }
        
        // ═══════════════════════════════════════════════════════════════════
        // POINT-FREE HELPERS
        // ═══════════════════════════════════════════════════════════════════
        
        // prop(key)(obj) - get property from object
        // Returns a function that extracts the given property
        if (std.mem.eql(u8, name, "prop")) {
            if (args.len > 0 and args[0] == .string_) {
                // Store the key and return a partial function
                const key = args[0].string_;
                // Create a function that will extract this property
                return .{ .func = .{
                    .name = key, // Store key in name for prop_getter
                    .params = &.{},
                    .body = null,
                    .is_builtin = true, .captured = null,
                }};
            }
            return .nil;
        }
        
        // eq(value)(x) - equality check, returns x == value
        if (std.mem.eql(u8, name, "eq")) {
            if (args.len > 0) {
                // Store the value to compare against
                const val_ptr = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                val_ptr.* = args[0];
                
                // Create indices for single placeholder
                const indices = self.arenaAlloc().alloc(usize, 1) catch return error.OutOfMemory;
                indices[0] = 1; // Second arg is placeholder
                
                // Create args array with stored value and placeholder
                const partial_args = self.arenaAlloc().alloc(Value, 2) catch return error.OutOfMemory;
                partial_args[0] = args[0];
                partial_args[1] = .placeholder;
                
                // Create eq_check function
                const eq_func = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                eq_func.* = .{ .func = .{
                    .name = "eq_check",
                    .params = &.{},
                    .body = null,
                    .is_builtin = true, .captured = null,
                }};
                
                return .{ .partial = .{
                    .func = eq_func,
                    .args = partial_args,
                    .placeholder_indices = indices,
                }};
            }
            return .nil;
        }
        
        // eq_check(a, b) - internal equality check
        if (std.mem.eql(u8, name, "eq_check")) {
            if (args.len >= 2) {
                const a = args[0];
                const b = args[1];
                
                if (a == .int_ and b == .int_) {
                    return .{ .bool_ = a.int_ == b.int_ };
                }
                if (a == .string_ and b == .string_) {
                    return .{ .bool_ = std.mem.eql(u8, a.string_, b.string_) };
                }
                if (a == .bool_ and b == .bool_) {
                    return .{ .bool_ = a.bool_ == b.bool_ };
                }
                return .{ .bool_ = false };
            }
            return .{ .bool_ = false };
        }
        
        // gt(value)(x) - greater than check, returns x > value
        if (std.mem.eql(u8, name, "gt")) {
            if (args.len > 0) {
                const indices = self.arenaAlloc().alloc(usize, 1) catch return error.OutOfMemory;
                indices[0] = 1;
                
                const partial_args = self.arenaAlloc().alloc(Value, 2) catch return error.OutOfMemory;
                partial_args[0] = args[0];
                partial_args[1] = .placeholder;
                
                const gt_func = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                gt_func.* = .{ .func = .{
                    .name = "gt_check",
                    .params = &.{},
                    .body = null,
                    .is_builtin = true, .captured = null,
                }};
                
                return .{ .partial = .{
                    .func = gt_func,
                    .args = partial_args,
                    .placeholder_indices = indices,
                }};
            }
            return .nil;
        }
        
        // gt_check(threshold, x) - returns x > threshold
        if (std.mem.eql(u8, name, "gt_check")) {
            if (args.len >= 2) {
                return .{ .bool_ = args[1].toInt() > args[0].toInt() };
            }
            return .{ .bool_ = false };
        }
        
        // lt(value)(x) - less than check
        if (std.mem.eql(u8, name, "lt")) {
            if (args.len > 0) {
                const indices = self.arenaAlloc().alloc(usize, 1) catch return error.OutOfMemory;
                indices[0] = 1;
                
                const partial_args = self.arenaAlloc().alloc(Value, 2) catch return error.OutOfMemory;
                partial_args[0] = args[0];
                partial_args[1] = .placeholder;
                
                const lt_func = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                lt_func.* = .{ .func = .{
                    .name = "lt_check",
                    .params = &.{},
                    .body = null,
                    .is_builtin = true, .captured = null,
                }};
                
                return .{ .partial = .{
                    .func = lt_func,
                    .args = partial_args,
                    .placeholder_indices = indices,
                }};
            }
            return .nil;
        }
        
        // lt_check(threshold, x) - returns x < threshold
        if (std.mem.eql(u8, name, "lt_check")) {
            if (args.len >= 2) {
                return .{ .bool_ = args[1].toInt() < args[0].toInt() };
            }
            return .{ .bool_ = false };
        }
        
        // add(n)(x) - adds n to x
        if (std.mem.eql(u8, name, "add")) {
            if (args.len > 0) {
                const indices = self.arenaAlloc().alloc(usize, 1) catch return error.OutOfMemory;
                indices[0] = 1;
                
                const partial_args = self.arenaAlloc().alloc(Value, 2) catch return error.OutOfMemory;
                partial_args[0] = args[0];
                partial_args[1] = .placeholder;
                
                const add_func = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                add_func.* = .{ .func = .{
                    .name = "add_impl",
                    .params = &.{},
                    .body = null,
                    .is_builtin = true, .captured = null,
                }};
                
                return .{ .partial = .{
                    .func = add_func,
                    .args = partial_args,
                    .placeholder_indices = indices,
                }};
            }
            return .nil;
        }
        
        // add_impl(n, x) - returns x + n
        if (std.mem.eql(u8, name, "add_impl")) {
            if (args.len >= 2) {
                return .{ .int_ = args[0].toInt() + args[1].toInt() };
            }
            return .{ .int_ = 0 };
        }
        
        // mul(n)(x) - multiplies x by n
        if (std.mem.eql(u8, name, "mul")) {
            if (args.len > 0) {
                const indices = self.arenaAlloc().alloc(usize, 1) catch return error.OutOfMemory;
                indices[0] = 1;
                
                const partial_args = self.arenaAlloc().alloc(Value, 2) catch return error.OutOfMemory;
                partial_args[0] = args[0];
                partial_args[1] = .placeholder;
                
                const mul_func = self.arenaAlloc().create(Value) catch return error.OutOfMemory;
                mul_func.* = .{ .func = .{
                    .name = "mul_impl",
                    .params = &.{},
                    .body = null,
                    .is_builtin = true, .captured = null,
                }};
                
                return .{ .partial = .{
                    .func = mul_func,
                    .args = partial_args,
                    .placeholder_indices = indices,
                }};
            }
            return .nil;
        }
        
        // mul_impl(n, x) - returns x * n
        if (std.mem.eql(u8, name, "mul_impl")) {
            if (args.len >= 2) {
                return .{ .int_ = args[0].toInt() * args[1].toInt() };
            }
            return .{ .int_ = 0 };
        }
        
        // not_(x) - logical negation
        if (std.mem.eql(u8, name, "not_")) {
            if (args.len > 0) {
                return .{ .bool_ = !args[0].toBool() };
            }
            return .{ .bool_ = true };
        }
        
        return .nil;
    }
    
    fn callUserFunc(self: *Interpreter, func: Value.FuncValue, args: []const Value) InterpreterError!Value {
        // Check recursion depth
        self.call_depth += 1;
        defer self.call_depth -= 1;
        
        if (self.call_depth > 1000) {
            return error.OutOfMemory; // Stack overflow protection
        }
        
        // Allocate old_values from arena (no need to free)
        const OldValue = struct { name: []const u8, val: ?Value };
        const old_values = self.arenaAlloc().alloc(OldValue, func.params.len) catch return error.OutOfMemory;
        
        // Save old values and bind parameters
        for (func.params, 0..) |param, i| {
            old_values[i] = .{ .name = param, .val = self.current.get(param) };
            const arg_val = if (i < args.len) args[i] else Value.nil;
            self.current.define(param, arg_val) catch return error.OutOfMemory;
        }
        
        // Execute function body
        var result: Value = .nil;
        if (func.body) |body| {
            result = self.eval(body) catch |err| {
                // Restore old values on error
                for (old_values) |item| {
                    if (item.val) |v| {
                        self.current.define(item.name, v) catch {};
                    }
                }
                return err;
            };
        }
        
        // Restore old values
        for (old_values) |item| {
            if (item.val) |v| {
                self.current.define(item.name, v) catch {};
            }
        }
        
        return result;
    }
    
    fn evalReturn(self: *Interpreter, node: *const AstNode) InterpreterError!Value {
        if (node.children.items.len > 0) {
            return try self.eval(&node.children.items[0]);
        }
        return .nil;
    }
    
    pub fn getOutput(self: *Interpreter) []const u8 {
        return self.output.items;
    }
};

// Tests
test "interpreter basic" {
    const source = "const x = 42";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqual(@as(i64, 42), result.int_);
}

test "interpreter arithmetic" {
    const source = "const x = 10 + 5";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqual(@as(i64, 15), result.int_);
}

test "interpreter trit" {
    var interp = Interpreter.init(std.testing.allocator, "");
    defer interp.deinit(allocator);
    
    // Test built-in trit values
    if (interp.global.get("T")) |t| {
        try std.testing.expectEqual(@as(i8, 1), t.trit);
    }
    if (interp.global.get("F")) |f| {
        try std.testing.expectEqual(@as(i8, -1), f.trit);
    }
}

test "interpreter builtins" {
    var interp = Interpreter.init(std.testing.allocator, "");
    defer interp.deinit(allocator);
    
    if (interp.global.get("phi")) |phi| {
        try std.testing.expect(phi.float_ > 1.618 and phi.float_ < 1.619);
    }
    
    if (interp.global.get("trinity")) |trinity| {
        try std.testing.expectEqual(@as(i64, 27), trinity.int_);
    }
}

test "phi constant" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}

test "interpreter if" {
    const source = "if true { 42 } else { 0 }";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqual(@as(i64, 42), result.int_);
}

test "interpreter if false" {
    const source = "if false { 42 } else { 99 }";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqual(@as(i64, 99), result.int_);
}

test "interpreter comparison" {
    const source = "10 > 5";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expect(result.bool_);
}

test "interpreter string" {
    const source = "\"hello\"";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqualStrings("hello", result.string_);
}

test "interpreter user function" {
    const source = "func double(x) { x * 2 }\ndouble(5)";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqual(@as(i64, 10), result.int_);
}

test "interpreter function with multiple params" {
    const source = "func add(a, b) { a + b }\nadd(3, 7)";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqual(@as(i64, 10), result.int_);
}

test "interpreter array literal" {
    const source = "[1, 2, 3]";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expect(result == .array);
    try std.testing.expectEqual(@as(usize, 3), result.array.items.len);
}

test "interpreter array index" {
    const source = "[10, 20, 30][1]";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expectEqual(@as(i64, 20), result.int_);
}

test "interpreter for loop array" {
    const source = "for x in [1, 2, 3] { x }";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    // Returns last iteration value
    try std.testing.expectEqual(@as(i64, 3), result.int_);
}

test "interpreter range builtin" {
    const source = "range(3)";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);
    
    var interp = Interpreter.init(std.testing.allocator, source);
    defer interp.deinit(allocator);
    
    const result = try interp.interpret(&ast);
    try std.testing.expect(result == .array);
    try std.testing.expectEqual(@as(usize, 3), result.array.items.len);
}
