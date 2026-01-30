//! VIBEE Bytecode Compiler
//! Compiles Coptic AST to bytecode for VM execution
//! φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const bytecode = @import("bytecode.zig");
const coptic_parser = @import("coptic_parser_real.zig");

const Opcode = bytecode.Opcode;
const BytecodeEmitter = bytecode.BytecodeEmitter;
const Value = bytecode.Value;
const AstNode = coptic_parser.AstNode;
const NodeKind = coptic_parser.NodeKind;

pub const CompileError = error{
    OutOfMemory,
    InvalidNode,
    UndefinedVariable,
    TooManyLocals,
    TooManyConstants,
    JumpTooLarge,
    UndefinedLabel,
};

const Local = struct {
    name: []const u8,
    depth: u32,
};

const Param = struct {
    name: []const u8,
    index: u8,
};

const FuncInfo = struct {
    name: []const u8,
    addr: u16,
};

// Upvalue - captured variable from enclosing scope
const Upvalue = struct {
    index: u8,      // Index in enclosing function's locals or upvalues
    is_local: bool, // true if capturing from immediate parent, false if from grandparent+
};

pub const BytecodeCompiler = struct {
    allocator: Allocator,
    emitter: BytecodeEmitter,
    source: []const u8,
    locals: std.ArrayList(Local),
    params: std.ArrayList(Param),
    upvalues: std.ArrayList(Upvalue),
    current_func: ?FuncInfo,
    scope_depth: u32,
    loop_start: ?u32,
    loop_end_patches: std.ArrayList(u32),
    enclosing: ?*Self,  // Parent compiler for nested functions

    const Self = @This();

    pub fn init(allocator: Allocator, source: []const u8) Self {
        return .{
            .allocator = allocator,
            .emitter = BytecodeEmitter.init(allocator),
            .source = source,
            .locals = .empty,
            .params = .empty,
            .upvalues = .empty,
            .current_func = null,
            .scope_depth = 0,
            .loop_start = null,
            .loop_end_patches = .empty,
            .enclosing = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.emitter.deinit(allocator);
        self.locals.deinit(allocator);
        self.params.deinit(allocator);
        self.upvalues.deinit(allocator);
        self.loop_end_patches.deinit(allocator);
    }

    pub fn compile(self: *Self, ast: *const AstNode) CompileError!void {
        try self.compileNode(ast);
        try self.emitter.emit(.HALT);
        try self.emitter.resolveLabels();
    }

    pub fn getCode(self: *Self) []const u8 {
        return self.emitter.code.items;
    }

    pub fn getConstants(self: *Self) []const Value {
        return self.emitter.constants.entries.items;
    }
    
    // Add int constant to pool
    fn addIntConstant(self: *Self, value: i64) CompileError!u16 {
        return self.emitter.constants.addInt(value) catch return error.TooManyConstants;
    }
    
    // Add string constant to pool
    fn addStringConstant(self: *Self, value: []const u8) CompileError!u16 {
        return self.emitter.constants.addString(value) catch return error.TooManyConstants;
    }

    fn compileNode(self: *Self, node: *const AstNode) CompileError!void {
        switch (node.kind) {
            .program => try self.compileProgram(node),
            .const_decl, .var_decl, .let_decl => try self.compileDecl(node),
            .let_destructure_array => try self.compileArrayDestructure(node),
            .let_destructure_object => try self.compileObjectDestructure(node),
            .func_decl => try self.compileFunc(node),
            .identifier => try self.compileIdentifier(node),
            .literal_int => try self.compileLiteralInt(node),
            .literal_float => try self.compileLiteralFloat(node),
            .literal_string => try self.compileLiteralString(node),
            .literal_bool => try self.compileLiteralBool(node),
            .literal_nil => try self.emitter.emit(.NOP),
            .literal_trit => try self.compileLiteralTrit(node),
            .literal_tryte => try self.compileLiteralTryte(node),
            .binary_expr => try self.compileBinary(node),
            .unary_expr => try self.compileUnary(node),
            .call_expr => try self.compileCall(node),
            .return_stmt => try self.compileReturn(node),
            .if_expr => try self.compileIf(node),
            .while_stmt => try self.compileWhile(node),
            .for_stmt => try self.compileFor(node),
            .block => try self.compileBlock(node),
            .break_stmt => try self.compileBreak(),
            .array_literal => try self.compileArray(node),
            .index_expr => try self.compileIndex(node),
            .object_literal => try self.compileObject(node),
            .member_expr => try self.compileMember(node),
            .func_expr => try self.compileFuncExpr(node),
            .match_expr => try self.compileMatch(node),
            else => {},
        }
    }

    fn compileProgram(self: *Self, node: *const AstNode) CompileError!void {
        for (node.children.items) |*child| {
            try self.compileNode(child);
        }
    }

    fn compileDecl(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 1) return;

        const name = node.children.items[0].token.lexeme(self.source);

        if (node.children.items.len > 1) {
            try self.compileNode(&node.children.items[1]);
        } else {
            try self.emitter.emit(.NOP);
        }

        const idx = try self.addLocal(name);
        try self.emitter.emitWithU16(.STORE_LOCAL, idx);
    }

    // Compile array destructuring: let [a, b, c] = [1, 2, 3]
    fn compileArrayDestructure(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 1) return;
        
        // Last child is the value expression
        const value_idx = node.children.items.len - 1;
        try self.compileNode(&node.children.items[value_idx]);
        
        // Store array in temp local
        const arr_idx = try self.addLocal("__destructure_arr__");
        try self.emitter.emitWithU16(.STORE_LOCAL, arr_idx);
        
        // For each identifier in the pattern, extract from array
        var i: usize = 0;
        while (i < value_idx) : (i += 1) {
            const child = &node.children.items[i];
            
            // Skip rest_pattern for now (TODO: implement slice)
            if (child.kind == .rest_pattern) {
                continue;
            }
            
            // Regular identifier - get array[i]
            const name = child.token.lexeme(self.source);
            // Load array
            try self.emitter.emitWithU16(.LOAD_LOCAL, arr_idx);
            // Push index
            try self.emitter.emitWithU16(.PUSH_CONST, try self.addIntConstant(@intCast(i)));
            // Index operation
            try self.emitter.emit(.ARRAY_GET);
            // Store in local
            const local_idx = try self.addLocal(name);
            try self.emitter.emitWithU16(.STORE_LOCAL, local_idx);
        }
    }
    
    // Compile object destructuring: let {x, y} = {x: 1, y: 2}
    fn compileObjectDestructure(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 1) return;
        
        // Last child is the value expression
        const value_idx = node.children.items.len - 1;
        try self.compileNode(&node.children.items[value_idx]);
        
        // Store object in temp local
        const obj_idx = try self.addLocal("__destructure_obj__");
        try self.emitter.emitWithU16(.STORE_LOCAL, obj_idx);
        
        // For each identifier in the pattern, extract from object
        var i: usize = 0;
        while (i < value_idx) : (i += 1) {
            const child = &node.children.items[i];
            const name = child.token.lexeme(self.source);
            
            // Load object
            try self.emitter.emitWithU16(.LOAD_LOCAL, obj_idx);
            // Push field name as string
            try self.emitter.emitWithU16(.PUSH_CONST, try self.addStringConstant(name));
            // Get field
            try self.emitter.emit(.OBJECT_GET);
            // Store in local
            const local_idx = try self.addLocal(name);
            try self.emitter.emitWithU16(.STORE_LOCAL, local_idx);
        }
    }

    fn compileFunc(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 1) return;

        const name = node.children.items[0].token.lexeme(self.source);

        // Reserve slot for function at CURRENT scope (before entering function body)
        const func_idx = try self.addLocal(name);
        
        // Remember how many locals we had AFTER adding function name
        // (so we don't delete the function itself when restoring)
        const locals_after_func = self.locals.items.len;

        // Jump over function body (placeholder)
        try self.emitter.emit(.JMP);
        const skip_patch = @as(u32, @intCast(self.emitter.code.items.len));
        try self.emitter.code.append(allocator, 0);
        try self.emitter.code.append(allocator, 0);

        // Function entry address (right after JMP)
        const func_addr = @as(u16, @intCast(self.emitter.code.items.len));

        // Save old function context and set current
        const old_func = self.current_func;
        self.current_func = .{ .name = name, .addr = func_addr };

        // New scope for function body
        self.scope_depth += 1;
        const old_params_count = self.params.items.len;

        // Count and add parameters
        var param_count: u8 = 0;
        var body_idx: usize = 1;
        for (node.children.items[1..], 1..) |*child, i| {
            if (child.kind == .block) {
                body_idx = i;
                break;
            }
            const param_name = child.token.lexeme(self.source);
            try self.params.append(allocator, .{ .name = param_name, .index = param_count });
            param_count += 1;
        }

        // Compile body
        if (body_idx < node.children.items.len) {
            try self.compileNode(&node.children.items[body_idx]);
        }

        try self.emitter.emit(.RET);

        // Restore scope and function context
        // Keep the function name in locals, only remove body-local variables
        self.locals.shrinkRetainingCapacity(locals_after_func);
        self.params.shrinkRetainingCapacity(old_params_count);
        self.scope_depth -= 1;
        self.current_func = old_func;

        // Patch skip jump to point to init code
        const init_start = @as(u16, @intCast(self.emitter.code.items.len));

        // Store function address to the reserved slot
        const addr_idx = try self.emitter.constants.addInt(@intCast(func_addr));
        try self.emitter.emitWithU16(.PUSH_CONST, addr_idx);
        try self.emitter.emitWithU16(.STORE_LOCAL, func_idx);

        self.emitter.code.items[skip_patch] = @intCast(init_start >> 8);
        self.emitter.code.items[skip_patch + 1] = @intCast(init_start & 0xFF);
    }
    
    // Anonymous function expression: fn(args) { body }
    fn compileFuncExpr(self: *Self, node: *const AstNode) CompileError!void {
        // Remember current state
        const old_locals_count = self.locals.items.len;
        const old_upvalues_count = self.upvalues.items.len;
        
        // Jump over function body (placeholder)
        try self.emitter.emit(.JMP);
        const skip_patch = @as(u32, @intCast(self.emitter.code.items.len));
        try self.emitter.code.append(allocator, 0);
        try self.emitter.code.append(allocator, 0);

        // Function entry address (right after JMP)
        const func_addr = @as(u16, @intCast(self.emitter.code.items.len));

        // Save old function context and set up for nested function
        const old_func = self.current_func;
        const old_enclosing = self.enclosing;
        self.current_func = .{ .name = "<anon>", .addr = func_addr };
        
        // For closures: this function can capture from current scope
        // We use self as enclosing (simplified - in real impl would be separate compiler)
        
        // New scope for function body
        self.scope_depth += 1;
        const old_params_count = self.params.items.len;

        // Parse parameters (all children except last which is block)
        var param_count: u8 = 0;
        var body_idx: usize = 0;
        for (node.children.items, 0..) |*child, i| {
            if (child.kind == .block) {
                body_idx = i;
                break;
            }
            const param_name = child.token.lexeme(self.source);
            try self.params.append(allocator, .{ .name = param_name, .index = param_count });
            param_count += 1;
        }

        // Compile body
        if (body_idx < node.children.items.len) {
            try self.compileNode(&node.children.items[body_idx]);
        }

        try self.emitter.emit(.RET);

        // Count upvalues captured by this function
        const upvalue_count: u8 = @intCast(self.upvalues.items.len - old_upvalues_count);

        // Restore scope and function context
        self.locals.shrinkRetainingCapacity(old_locals_count);
        self.params.shrinkRetainingCapacity(old_params_count);
        self.upvalues.shrinkRetainingCapacity(old_upvalues_count);
        self.scope_depth -= 1;
        self.current_func = old_func;
        self.enclosing = old_enclosing;

        // Patch skip jump to point to code after function
        const after_func = @as(u16, @intCast(self.emitter.code.items.len));
        self.emitter.code.items[skip_patch] = @intCast(after_func >> 8);
        self.emitter.code.items[skip_patch + 1] = @intCast(after_func & 0xFF);

        if (upvalue_count > 0) {
            // Create closure with upvalues
            try self.emitter.emit(.CLOSURE);
            try self.emitter.code.append(allocator, @intCast(func_addr >> 8));
            try self.emitter.code.append(allocator, @intCast(func_addr & 0xFF));
            try self.emitter.code.append(allocator, upvalue_count);
            
            // Emit upvalue info (which locals to capture)
            // For now simplified - just emit indices
            for (self.upvalues.items[old_upvalues_count..]) |uv| {
                try self.emitter.code.append(allocator, if (uv.is_local) 1 else 0);
                try self.emitter.code.append(allocator, uv.index);
            }
        } else {
            // No upvalues - just push function address
            const addr_idx = try self.emitter.constants.addInt(@intCast(func_addr));
            try self.emitter.emitWithU16(.PUSH_CONST, addr_idx);
        }
    }

    fn compileIdentifier(self: *Self, node: *const AstNode) CompileError!void {
        const name = node.token.lexeme(self.source);

        // Check for built-in constants
        if (std.mem.eql(u8, name, "phi")) {
            try self.emitter.emit(.PUSH_PHI);
            return;
        }
        if (std.mem.eql(u8, name, "pi")) {
            try self.emitter.emit(.PUSH_PI);
            return;
        }
        if (std.mem.eql(u8, name, "e")) {
            try self.emitter.emit(.PUSH_E);
            return;
        }
        if (std.mem.eql(u8, name, "true")) {
            const idx = try self.emitter.constants.addBool(true);
            try self.emitter.emitWithU16(.PUSH_CONST, idx);
            return;
        }
        if (std.mem.eql(u8, name, "false")) {
            const idx = try self.emitter.constants.addBool(false);
            try self.emitter.emitWithU16(.PUSH_CONST, idx);
            return;
        }
        
        // ТРОИЧНЫЕ КОНСТАНТЫ: T, F, U
        if (std.mem.eql(u8, name, "T")) {
            try self.emitter.emit(.PUSH_TRIT);
            self.emitter.code.append(allocator, 1) catch return CompileError.OutOfMemory; // T = 1
            return;
        }
        if (std.mem.eql(u8, name, "F")) {
            try self.emitter.emit(.PUSH_TRIT);
            self.emitter.code.append(allocator, @bitCast(@as(i8, -1))) catch return CompileError.OutOfMemory; // F = -1
            return;
        }
        if (std.mem.eql(u8, name, "U")) {
            try self.emitter.emit(.PUSH_TRIT);
            self.emitter.code.append(allocator, 0) catch return CompileError.OutOfMemory; // U = 0
            return;
        }

        // Check for function parameter first
        if (self.resolveParam(name)) |idx| {
            try self.emitter.emit(.LOAD_ARG);
            self.emitter.code.append(allocator, idx) catch return CompileError.OutOfMemory;
            return;
        }

        // Check for recursive call (current function name)
        if (self.current_func) |func| {
            if (std.mem.eql(u8, func.name, name)) {
                // Push current function's address for recursive call
                const addr_idx = try self.emitter.constants.addInt(@intCast(func.addr));
                try self.emitter.emitWithU16(.PUSH_CONST, addr_idx);
                return;
            }
        }

        // Local variable
        if (self.resolveLocal(name)) |idx| {
            try self.emitter.emitWithU16(.LOAD_LOCAL, idx);
            return;
        }
        
        // Upvalue (captured from enclosing scope)
        if (try self.resolveUpvalue(name)) |idx| {
            try self.emitter.emit(.GET_UPVALUE);
            try self.emitter.code.append(allocator, idx);
            return;
        }
        
        // Not found - global
        try self.emitter.emitWithU16(.LOAD_GLOBAL, 0);
    }

    fn resolveParam(self: *Self, name: []const u8) ?u8 {
        var i: usize = self.params.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.params.items[i].name, name)) {
                return self.params.items[i].index;
            }
        }
        return null;
    }

    fn compileLiteralInt(self: *Self, node: *const AstNode) CompileError!void {
        const lexeme = node.token.lexeme(self.source);
        const val = std.fmt.parseInt(i64, lexeme, 10) catch 0;
        try self.emitter.emitPushInt(val);
    }

    fn compileLiteralFloat(self: *Self, node: *const AstNode) CompileError!void {
        const lexeme = node.token.lexeme(self.source);
        const val = std.fmt.parseFloat(f64, lexeme) catch 0.0;
        try self.emitter.emitPushFloat(val);
    }

    fn compileLiteralString(self: *Self, node: *const AstNode) CompileError!void {
        const lexeme = node.token.lexeme(self.source);
        const str = if (lexeme.len >= 2) lexeme[1 .. lexeme.len - 1] else "";
        const idx = try self.emitter.constants.addString(str);
        try self.emitter.emitWithU16(.PUSH_CONST, idx);
    }

    fn compileLiteralBool(self: *Self, node: *const AstNode) CompileError!void {
        const lexeme = node.token.lexeme(self.source);
        const val = std.mem.eql(u8, lexeme, "true");
        const idx = try self.emitter.constants.addBool(val);
        try self.emitter.emitWithU16(.PUSH_CONST, idx);
    }

    fn compileLiteralTrit(self: *Self, node: *const AstNode) CompileError!void {
        const lexeme = node.token.lexeme(self.source);
        // Trit literal: T, 0, 1 or balanced: -, 0, +
        var trit_val: i8 = 0;
        if (lexeme.len > 0) {
            const c = lexeme[0];
            if (c == 'T' or c == '-') {
                trit_val = -1;
            } else if (c == '1' or c == '+') {
                trit_val = 1;
            } else {
                trit_val = 0;
            }
        }
        try self.emitter.emitWithI8(.PUSH_TRIT, trit_val);
    }

    fn compileLiteralTryte(self: *Self, node: *const AstNode) CompileError!void {
        const lexeme = node.token.lexeme(self.source);
        // Tryte literal: 0t012 (3 trits in balanced ternary)
        // Balanced ternary: 0=0, 1=1, 2=-1 (or T=-1)
        // Skip "0t" prefix
        var tryte_val: i16 = 0;
        if (lexeme.len >= 2 and lexeme[0] == '0' and lexeme[1] == 't') {
            const trits = lexeme[2..];
            var power: i16 = 1;
            var i: usize = trits.len;
            while (i > 0) {
                i -= 1;
                const c = trits[i];
                var trit: i16 = 0;
                if (c == '2' or c == 'T' or c == 't') {
                    trit = -1; // balanced ternary: 2 = -1
                } else if (c == '1') {
                    trit = 1;
                }
                // c == '0' -> trit stays 0
                tryte_val += trit * power;
                power *= 3;
            }
        }
        try self.emitter.emitWithI16(.PUSH_TRYTE, tryte_val);
    }

    fn compileBinary(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 2) return;

        const op = node.token.lexeme(self.source);

        // Handle assignment specially
        if (std.mem.eql(u8, op, "=")) {
            const left = &node.children.items[0];
            
            // Check if left side is member expression (obj.field = value)
            if (left.kind == .member_expr and left.children.items.len >= 2) {
                // Compile object
                try self.compileNode(&left.children.items[0]);
                
                // Get field name
                const field_name = left.children.items[1].token.lexeme(self.source);
                
                // Push field name as string constant
                const key_idx = try self.emitter.constants.addString(field_name);
                try self.emitter.emitWithU16(.PUSH_CONST, key_idx);
                
                // Compile value
                try self.compileNode(&node.children.items[1]);
                
                // Set property: stack is [obj, key, value] -> [obj]
                try self.emitter.emit(.OBJECT_SET);
                
                // Pop object, push value for expression result
                try self.emitter.emit(.POP);
                try self.compileNode(&node.children.items[1]);
                return;
            }
            
            // Left side is identifier
            const name = left.token.lexeme(self.source);
            // Compile right side (value)
            try self.compileNode(&node.children.items[1]);
            // Store to variable
            if (self.resolveLocal(name)) |idx| {
                try self.emitter.emitWithU16(.STORE_LOCAL, idx);
                // Push value back for expression result
                try self.emitter.emitWithU16(.LOAD_LOCAL, idx);
            } else {
                // Variable not found - create it as global
                const idx = try self.addLocal(name);
                try self.emitter.emitWithU16(.STORE_LOCAL, idx);
                try self.emitter.emitWithU16(.LOAD_LOCAL, idx);
            }
            return;
        }

        // Optimization: LOAD_ADD/SUB/MUL for local + expr pattern
        const left = &node.children.items[0];
        const right = &node.children.items[1];

        if (left.kind == .identifier) {
            const name = left.token.lexeme(self.source);
            if (self.resolveLocal(name)) |idx| {
                // Left is a local variable - use fused opcode
                if (std.mem.eql(u8, op, "+")) {
                    try self.compileNode(right);
                    try self.emitter.emitWithU16(.LOAD_ADD, idx);
                    return;
                } else if (std.mem.eql(u8, op, "-")) {
                    try self.compileNode(right);
                    try self.emitter.emitWithU16(.LOAD_SUB, idx);
                    return;
                } else if (std.mem.eql(u8, op, "*")) {
                    try self.compileNode(right);
                    try self.emitter.emitWithU16(.LOAD_MUL, idx);
                    return;
                } else if (std.mem.eql(u8, op, "+t")) {
                    // Fused ternary add
                    try self.compileNode(right);
                    try self.emitter.emitWithU16(.LOAD_TRYTE_ADD, idx);
                    return;
                }
            }
        }

        // Fallback: compile normally
        try self.compileNode(left);
        try self.compileNode(right);

        if (std.mem.eql(u8, op, "+")) {
            try self.emitter.emit(.ADD);
        } else if (std.mem.eql(u8, op, "-")) {
            try self.emitter.emit(.SUB);
        } else if (std.mem.eql(u8, op, "*")) {
            try self.emitter.emit(.MUL);
        } else if (std.mem.eql(u8, op, "/")) {
            try self.emitter.emit(.DIV);
        } else if (std.mem.eql(u8, op, "%")) {
            try self.emitter.emit(.MOD);
        } else if (std.mem.eql(u8, op, "==")) {
            try self.emitter.emit(.EQ);
        } else if (std.mem.eql(u8, op, "!=")) {
            try self.emitter.emit(.NE);
        } else if (std.mem.eql(u8, op, "<")) {
            try self.emitter.emit(.LT);
        } else if (std.mem.eql(u8, op, ">")) {
            try self.emitter.emit(.GT);
        } else if (std.mem.eql(u8, op, "<=")) {
            try self.emitter.emit(.LE);
        } else if (std.mem.eql(u8, op, ">=")) {
            try self.emitter.emit(.GE);
        } else if (std.mem.eql(u8, op, "&&") or std.mem.eql(u8, op, "and")) {
            try self.emitter.emit(.AND);
        } else if (std.mem.eql(u8, op, "||") or std.mem.eql(u8, op, "or")) {
            try self.emitter.emit(.OR);
        }
        // Ternary/Trit operators
        else if (std.mem.eql(u8, op, "&&&") or std.mem.eql(u8, op, "tand")) {
            try self.emitter.emit(.TRIT_AND);
        } else if (std.mem.eql(u8, op, "|||") or std.mem.eql(u8, op, "tor")) {
            try self.emitter.emit(.TRIT_OR);
        } else if (std.mem.eql(u8, op, "+t")) {
            try self.emitter.emit(.TRYTE_ADD);
        } else if (std.mem.eql(u8, op, "-t")) {
            try self.emitter.emit(.TRYTE_SUB);
        } else if (std.mem.eql(u8, op, "*t")) {
            try self.emitter.emit(.TRYTE_MUL);
        } else if (std.mem.eql(u8, op, "<t")) {
            try self.emitter.emit(.TRYTE_LT);
        } else if (std.mem.eql(u8, op, "==t")) {
            try self.emitter.emit(.TRYTE_EQ);
        }
    }

    fn compileUnary(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 1) return;

        try self.compileNode(&node.children.items[0]);

        const op = node.token.lexeme(self.source);
        if (std.mem.eql(u8, op, "-")) {
            try self.emitter.emit(.NEG);
        } else if (std.mem.eql(u8, op, "!") or std.mem.eql(u8, op, "not")) {
            try self.emitter.emit(.NOT);
        }
    }

    fn compileCall(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 1) return;

        const callee = &node.children.items[0];
        const arg_count: u8 = @intCast(node.children.items.len - 1);

        if (callee.kind == .identifier) {
            const name = callee.token.lexeme(self.source);

            // Check for native/built-in functions
            const natives = [_][]const u8{
                "print", "sqrt", "sin", "cos", "phi", "golden",
                "len", "type", "str", "int", "float",
                "abs", "min", "max", "floor", "ceil",
                "push", "pop", "first", "last", "range",
                "keys", "values",
                "sum", "product", "reverse", "concat",
                "map", "filter", "reduce", "foreach",
                "toTryte", "fromTryte", "tritAdd", "tritMul",
                "tryteSum", "tryteMax", "tryteMin", "tryteRange",
                "tryteArrayNew", "tryteArrayGet", "tryteArraySet", "tryteArrayLen",
                "tryteArraySum", "tryteArrayMax", "tryteArrayMin", "tryteArrayFill",
                "phi", "lucas", "fibonacci", "phiHash", "goldenWrap",
                "clock", "elapsed",
            };
            
            // Special handling for TryteArray operations - emit opcodes directly for inline SIMD
            if (std.mem.eql(u8, name, "tryteArraySum")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_SUM);
                return;
            }
            if (std.mem.eql(u8, name, "tryteArrayMax")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_MAX);
                return;
            }
            if (std.mem.eql(u8, name, "tryteArrayMin")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_MIN);
                return;
            }
            if (std.mem.eql(u8, name, "tryteArrayLen")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_LEN);
                return;
            }
            if (std.mem.eql(u8, name, "tryteArrayGet")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_GET);
                return;
            }
            if (std.mem.eql(u8, name, "tryteArraySet")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_SET);
                return;
            }
            if (std.mem.eql(u8, name, "tryteArrayNew")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_NEW);
                return;
            }
            if (std.mem.eql(u8, name, "tryteArrayFill")) {
                for (node.children.items[1..]) |*arg| {
                    try self.compileNode(arg);
                }
                try self.emitter.emit(.TRYTE_ARRAY_FILL);
                return;
            }
            
            for (natives) |native_name| {
                if (std.mem.eql(u8, name, native_name)) {
                    // Push arguments first
                    for (node.children.items[1..]) |*arg| {
                        try self.compileNode(arg);
                    }
                    
                    // Emit CALL_NATIVE with name index and arity
                    const name_idx = try self.emitter.constants.addString(name);
                    try self.emitter.emit(.CALL_NATIVE);
                    try self.emitter.code.append(allocator, @intCast(name_idx >> 8));
                    try self.emitter.code.append(allocator, @intCast(name_idx & 0xFF));
                    try self.emitter.code.append(allocator, arg_count);
                    return;
                }
            }
        }

        // Push function address first
        try self.compileNode(callee);

        // Push arguments
        for (node.children.items[1..]) |*arg| {
            try self.compileNode(arg);
        }

        // Call with arity
        try self.emitter.emit(.CALL_INDIRECT);
        self.emitter.code.append(allocator, arg_count) catch return CompileError.OutOfMemory;
    }

    fn compileReturn(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len > 0) {
            const expr = &node.children.items[0];
            
            // Tail call optimization: return f(...) -> TAIL_CALL
            if (expr.kind == .call_expr and expr.children.items.len >= 1) {
                const callee = &expr.children.items[0];
                if (callee.kind == .identifier) {
                    const name = callee.token.lexeme(self.source);
                    // Check if calling a known function
                    if (self.resolveLocal(name)) |idx| {
                        // Compile arguments
                        for (expr.children.items[1..]) |*arg| {
                            try self.compileNode(arg);
                        }
                        // Get function address from local
                        try self.emitter.emitWithU16(.LOAD_LOCAL, idx);
                        // For now, fall through to normal return
                        // Full TCO would require more complex handling
                    }
                }
            }
            
            try self.compileNode(expr);
        }
        try self.emitter.emit(.RET);
    }

    fn compileIf(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 2) return;

        const cond = &node.children.items[0];
        var else_patch: u32 = 0;

        // Optimization: fused compare+jump for binary comparisons
        if (cond.kind == .binary_expr and cond.children.items.len >= 2) {
            const op = cond.token.lexeme(self.source);
            const fused_op: ?bytecode.Opcode = if (std.mem.eql(u8, op, "<"))
                .LT_JZ
            else if (std.mem.eql(u8, op, "<="))
                .LE_JZ
            else if (std.mem.eql(u8, op, ">"))
                .GT_JZ
            else if (std.mem.eql(u8, op, ">="))
                .GE_JZ
            else if (std.mem.eql(u8, op, "=="))
                .EQ_JZ
            else if (std.mem.eql(u8, op, "!="))
                .NE_JZ
            else
                null;

            if (fused_op) |fop| {
                // Compile operands
                try self.compileNode(&cond.children.items[0]);
                try self.compileNode(&cond.children.items[1]);
                // Emit fused compare+jump
                try self.emitter.emit(fop);
                else_patch = @as(u32, @intCast(self.emitter.code.items.len));
                try self.emitter.code.append(allocator, 0);
                try self.emitter.code.append(allocator, 0);
            } else {
                // Fallback: compile condition normally
                try self.compileNode(cond);
                try self.emitter.emit(.JZ);
                else_patch = @as(u32, @intCast(self.emitter.code.items.len));
                try self.emitter.code.append(allocator, 0);
                try self.emitter.code.append(allocator, 0);
            }
        } else {
            // Compile condition normally
            try self.compileNode(cond);
            try self.emitter.emit(.JZ);
            else_patch = @as(u32, @intCast(self.emitter.code.items.len));
            try self.emitter.code.append(allocator, 0);
            try self.emitter.code.append(allocator, 0);
        }

        // Compile then branch
        try self.compileNode(&node.children.items[1]);

        if (node.children.items.len > 2) {
            // Jump over else
            try self.emitter.emit(.JMP);
            const end_patch = @as(u32, @intCast(self.emitter.code.items.len));
            try self.emitter.code.append(allocator, 0);
            try self.emitter.code.append(allocator, 0);

            // Patch else jump
            const else_addr = @as(u16, @intCast(self.emitter.code.items.len));
            self.emitter.code.items[else_patch] = @intCast(else_addr >> 8);
            self.emitter.code.items[else_patch + 1] = @intCast(else_addr & 0xFF);

            try self.compileNode(&node.children.items[2]);

            // Patch end jump
            const end_addr = @as(u16, @intCast(self.emitter.code.items.len));
            self.emitter.code.items[end_patch] = @intCast(end_addr >> 8);
            self.emitter.code.items[end_patch + 1] = @intCast(end_addr & 0xFF);
        } else {
            // Patch else jump
            const else_addr = @as(u16, @intCast(self.emitter.code.items.len));
            self.emitter.code.items[else_patch] = @intCast(else_addr >> 8);
            self.emitter.code.items[else_patch + 1] = @intCast(else_addr & 0xFF);
        }
    }

    fn compileWhile(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 2) return;

        const loop_start_addr = @as(u16, @intCast(self.emitter.code.items.len));
        self.loop_start = loop_start_addr;

        // Condition
        try self.compileNode(&node.children.items[0]);

        // JZ to end (placeholder)
        try self.emitter.emit(.JZ);
        const end_patch = @as(u32, @intCast(self.emitter.code.items.len));
        try self.emitter.code.append(allocator, 0);
        try self.emitter.code.append(allocator, 0);

        // Body
        try self.compileNode(&node.children.items[1]);

        // JMP back to start
        try self.emitter.emitWithU16(.JMP, loop_start_addr);

        // Patch end jump
        const end_addr = @as(u16, @intCast(self.emitter.code.items.len));
        self.emitter.code.items[end_patch] = @intCast(end_addr >> 8);
        self.emitter.code.items[end_patch + 1] = @intCast(end_addr & 0xFF);

        self.loop_start = null;
    }

    fn compileFor(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 3) return;

        // For now, compile as while with counter
        self.scope_depth += 1;
        const old_locals = self.locals.items.len;

        const iter_name = node.children.items[0].token.lexeme(self.source);
        const iter_idx = try self.addLocal(iter_name);

        // Initialize counter to 0
        try self.emitter.emitPushInt(0);
        try self.emitter.emitWithU16(.STORE_LOCAL, iter_idx);

        // Compile iterable (get length)
        try self.compileNode(&node.children.items[1]);

        const loop_start_addr = @as(u16, @intCast(self.emitter.code.items.len));

        // Check counter < length
        try self.emitter.emitWithU16(.LOAD_LOCAL, iter_idx);
        try self.emitter.emit(.LT);

        // JZ to end (placeholder)
        try self.emitter.emit(.JZ);
        const end_patch = @as(u32, @intCast(self.emitter.code.items.len));
        try self.emitter.code.append(allocator, 0);
        try self.emitter.code.append(allocator, 0);

        // Body
        try self.compileNode(&node.children.items[2]);

        // Increment counter
        try self.emitter.emitWithU16(.LOAD_LOCAL, iter_idx);
        try self.emitter.emit(.INC);
        try self.emitter.emitWithU16(.STORE_LOCAL, iter_idx);

        // JMP back to start
        try self.emitter.emitWithU16(.JMP, loop_start_addr);

        // Patch end jump
        const end_addr = @as(u16, @intCast(self.emitter.code.items.len));
        self.emitter.code.items[end_patch] = @intCast(end_addr >> 8);
        self.emitter.code.items[end_patch + 1] = @intCast(end_addr & 0xFF);

        self.locals.shrinkRetainingCapacity(old_locals);
        self.scope_depth -= 1;
    }

    fn compileBlock(self: *Self, node: *const AstNode) CompileError!void {
        self.scope_depth += 1;
        const old_locals = self.locals.items.len;

        for (node.children.items) |*child| {
            try self.compileNode(child);
        }

        self.locals.shrinkRetainingCapacity(old_locals);
        self.scope_depth -= 1;
    }

    fn compileBreak(self: *Self) CompileError!void {
        // Placeholder - needs loop context
        try self.emitter.emit(.NOP);
    }

    fn compileArray(self: *Self, node: *const AstNode) CompileError!void {
        // Compile each element
        for (node.children.items) |*child| {
            try self.compileNode(child);
        }
        // Create array with N elements
        const count: u8 = @intCast(@min(node.children.items.len, 255));
        try self.emitter.emit(.NEW_ARRAY);
        self.emitter.code.append(allocator, count) catch return CompileError.OutOfMemory;
    }

    fn compileIndex(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 2) return;
        
        // Compile array/object
        try self.compileNode(&node.children.items[0]);
        // Compile index
        try self.compileNode(&node.children.items[1]);
        // Get element
        try self.emitter.emit(.ARRAY_GET);
    }
    
    fn compileObject(self: *Self, node: *const AstNode) CompileError!void {
        // Create empty object first
        try self.emitter.emit(.NEW_OBJECT);
        
        // For each field, set the property
        for (node.children.items) |*field| {
            if (field.kind != .object_field) continue;
            
            // Get key name from field token
            const key = field.token.lexeme(self.source);
            
            // Duplicate object on stack (we need it for each SET)
            try self.emitter.emit(.DUP);
            
            // Push key as string constant
            const key_idx = try self.emitter.constants.addString(key);
            try self.emitter.emitWithU16(.PUSH_CONST, key_idx);
            
            // Compile value
            if (field.children.items.len > 0) {
                try self.compileNode(&field.children.items[0]);
            } else {
                try self.emitter.emit(.NOP);
            }
            
            // Set property: stack is [obj, key, value] -> [obj]
            try self.emitter.emit(.OBJECT_SET);
            
            // Pop the returned object (we have original on stack)
            try self.emitter.emit(.POP);
        }
    }
    
    fn compileMember(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 2) return;
        
        // Compile object
        try self.compileNode(&node.children.items[0]);
        
        // Get field name
        const field_name = node.children.items[1].token.lexeme(self.source);
        
        // Push field name as string constant
        const key_idx = try self.emitter.constants.addString(field_name);
        try self.emitter.emitWithU16(.PUSH_CONST, key_idx);
        
        // Get property
        try self.emitter.emit(.OBJECT_GET);
    }
    
    // Match expression: compile to chain of if-else
    // Supports guards: pattern if condition => result
    fn compileMatch(self: *Self, node: *const AstNode) CompileError!void {
        if (node.children.items.len < 1) return;
        
        // First child is the subject expression
        // Store it in a temporary local
        try self.compileNode(&node.children.items[0]);
        const subject_idx = try self.addLocal("$match");
        try self.emitter.emitWithU16(.STORE_LOCAL, subject_idx);
        
        // Collect jump patches for each arm's end (to jump to match end)
        var end_patches = std.ArrayList(u32).init(allocator);
        defer end_patches.deinit(allocator);
        
        // Process each match arm (children[1..])
        for (node.children.items[1..]) |*arm| {
            if (arm.kind != .match_arm or arm.children.items.len < 2) continue;
            
            const pattern = &arm.children.items[0];
            // Check if there's a guard (3 children: pattern, guard, result)
            const has_guard = arm.children.items.len >= 3;
            const result = if (has_guard) &arm.children.items[2] else &arm.children.items[1];
            
            // Check if pattern is wildcard (_)
            const is_wildcard = pattern.kind == .identifier and 
                std.mem.eql(u8, pattern.token.lexeme(self.source), "_");
            
            if (is_wildcard) {
                // Wildcard matches everything
                if (has_guard) {
                    // But check guard condition
                    const guard = &arm.children.items[1];
                    try self.emitter.emitWithU16(.LOAD_LOCAL, subject_idx);
                    // Create binding for _ (as $it)
                    const it_idx = try self.addLocal("$it");
                    try self.emitter.emitWithU16(.STORE_LOCAL, it_idx);
                    try self.compileNode(guard);
                    try self.emitter.emit(.JZ);
                    const skip_patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    
                    try self.compileNode(result);
                    try self.emitter.emit(.JMP);
                    const patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    end_patches.append(allocator, patch) catch return CompileError.OutOfMemory;
                    
                    const here = @as(u16, @intCast(self.emitter.code.items.len));
                    self.emitter.code.items[skip_patch] = @intCast(here >> 8);
                    self.emitter.code.items[skip_patch + 1] = @intCast(here & 0xFF);
                } else {
                    try self.compileNode(result);
                    try self.emitter.emit(.JMP);
                    const patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    end_patches.append(allocator, patch) catch return CompileError.OutOfMemory;
                }
            } else if (pattern.kind == .identifier) {
                // Binding pattern - bind value to variable
                const name = pattern.token.lexeme(self.source);
                try self.emitter.emitWithU16(.LOAD_LOCAL, subject_idx);
                const bind_idx = try self.addLocal(name);
                try self.emitter.emitWithU16(.STORE_LOCAL, bind_idx);
                
                if (has_guard) {
                    // Check guard condition
                    const guard = &arm.children.items[1];
                    try self.compileNode(guard);
                    try self.emitter.emit(.JZ);
                    const skip_patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    
                    try self.compileNode(result);
                    try self.emitter.emit(.JMP);
                    const patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    end_patches.append(allocator, patch) catch return CompileError.OutOfMemory;
                    
                    const here = @as(u16, @intCast(self.emitter.code.items.len));
                    self.emitter.code.items[skip_patch] = @intCast(here >> 8);
                    self.emitter.code.items[skip_patch + 1] = @intCast(here & 0xFF);
                } else {
                    try self.compileNode(result);
                    try self.emitter.emit(.JMP);
                    const patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    end_patches.append(allocator, patch) catch return CompileError.OutOfMemory;
                }
            } else {
                // Literal pattern - compare with subject
                try self.emitter.emitWithU16(.LOAD_LOCAL, subject_idx);
                try self.compileNode(pattern);
                try self.emitter.emit(.EQ);
                
                // Jump if not equal
                try self.emitter.emit(.JZ);
                const skip_patch = @as(u32, @intCast(self.emitter.code.items.len));
                try self.emitter.code.append(allocator, 0);
                try self.emitter.code.append(allocator, 0);
                
                if (has_guard) {
                    // Also check guard
                    const guard = &arm.children.items[1];
                    try self.compileNode(guard);
                    try self.emitter.emit(.JZ);
                    const guard_skip = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    
                    try self.compileNode(result);
                    try self.emitter.emit(.JMP);
                    const end_patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    end_patches.append(allocator, end_patch) catch return CompileError.OutOfMemory;
                    
                    const here = @as(u16, @intCast(self.emitter.code.items.len));
                    self.emitter.code.items[skip_patch] = @intCast(here >> 8);
                    self.emitter.code.items[skip_patch + 1] = @intCast(here & 0xFF);
                    self.emitter.code.items[guard_skip] = @intCast(here >> 8);
                    self.emitter.code.items[guard_skip + 1] = @intCast(here & 0xFF);
                } else {
                    try self.compileNode(result);
                    try self.emitter.emit(.JMP);
                    const end_patch = @as(u32, @intCast(self.emitter.code.items.len));
                    try self.emitter.code.append(allocator, 0);
                    try self.emitter.code.append(allocator, 0);
                    end_patches.append(allocator, end_patch) catch return CompileError.OutOfMemory;
                    
                    const here = @as(u16, @intCast(self.emitter.code.items.len));
                    self.emitter.code.items[skip_patch] = @intCast(here >> 8);
                    self.emitter.code.items[skip_patch + 1] = @intCast(here & 0xFF);
                }
            }
        }
        
        // Default: push nil if no match
        try self.emitter.emit(.NOP);
        
        // Patch all end jumps to here
        const end_addr = @as(u16, @intCast(self.emitter.code.items.len));
        for (end_patches.items) |patch| {
            self.emitter.code.items[patch] = @intCast(end_addr >> 8);
            self.emitter.code.items[patch + 1] = @intCast(end_addr & 0xFF);
        }
    }

    fn addLocal(self: *Self, name: []const u8) CompileError!u16 {
        if (self.locals.items.len >= 65535) return CompileError.TooManyLocals;
        const idx: u16 = @intCast(self.locals.items.len);
        self.locals.append(allocator, .{ .name = name, .depth = self.scope_depth }) catch return CompileError.OutOfMemory;
        return idx;
    }

    fn resolveLocal(self: *Self, name: []const u8) ?u16 {
        var i: usize = self.locals.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.locals.items[i].name, name)) {
                return @intCast(i);
            }
        }
        return null;
    }
    
    fn addUpvalue(self: *Self, index: u8, is_local: bool) CompileError!u8 {
        // Check if we already have this upvalue
        for (self.upvalues.items, 0..) |uv, i| {
            if (uv.index == index and uv.is_local == is_local) {
                return @intCast(i);
            }
        }
        
        if (self.upvalues.items.len >= 255) return CompileError.TooManyLocals;
        
        const idx: u8 = @intCast(self.upvalues.items.len);
        self.upvalues.append(allocator, .{ .index = index, .is_local = is_local }) catch return CompileError.OutOfMemory;
        return idx;
    }
    
    fn resolveUpvalue(self: *Self, name: []const u8) CompileError!?u8 {
        // No enclosing scope - can't capture
        const enclosing = self.enclosing orelse return null;
        
        // Try to find in enclosing's locals
        if (enclosing.resolveLocal(name)) |local_idx| {
            return try self.addUpvalue(@intCast(local_idx), true);
        }
        
        // Try to find in enclosing's upvalues (recursive)
        if (try enclosing.resolveUpvalue(name)) |upvalue_idx| {
            return try self.addUpvalue(upvalue_idx, false);
        }
        
        return null;
    }
};

// Tests
test "compile simple expression" {
    const source = "const x = 42";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);
    try std.testing.expect(compiler.getCode().len > 0);
}

test "compile arithmetic" {
    const source = "const x = 10 + 5";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    const code = compiler.getCode();
    try std.testing.expect(code.len > 0);

    // Should contain ADD opcode
    var has_add = false;
    for (code) |byte| {
        if (byte == @intFromEnum(Opcode.ADD)) has_add = true;
    }
    try std.testing.expect(has_add);
}

test "compile if statement" {
    const source = "if true { 42 }";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    const code = compiler.getCode();
    // Should contain JZ opcode
    var has_jz = false;
    for (code) |byte| {
        if (byte == @intFromEnum(Opcode.JZ)) has_jz = true;
    }
    try std.testing.expect(has_jz);
}

test "compile while loop" {
    const source = "while false { 1 }";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    const code = compiler.getCode();
    // Should contain JMP opcode for loop
    var has_jmp = false;
    for (code) |byte| {
        if (byte == @intFromEnum(Opcode.JMP)) has_jmp = true;
    }
    try std.testing.expect(has_jmp);
}

test "compile phi constant" {
    const source = "phi";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    const code = compiler.getCode();
    // Should contain PUSH_PHI opcode
    var has_phi = false;
    for (code) |byte| {
        if (byte == @intFromEnum(Opcode.PUSH_PHI)) has_phi = true;
    }
    try std.testing.expect(has_phi);
}

test "compile and run arithmetic" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "10 + 5";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    // Run in VM
    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    try std.testing.expectEqual(@as(i64, 15), result.int_val);
}

test "compile and run phi" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "phi";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    try std.testing.expect(result.float_val > 1.618 and result.float_val < 1.619);
}

test "compile and run comparison" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "10 > 5";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    try std.testing.expect(result.bool_val);
}

test "compile function definition" {
    const source = "func double(x) { x * 2 }";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    // Should have LOAD_ARG opcode for parameter x
    const code = compiler.getCode();
    var has_load_arg = false;
    for (code) |byte| {
        if (byte == @intFromEnum(Opcode.LOAD_ARG)) has_load_arg = true;
    }
    try std.testing.expect(has_load_arg);
}

test "compile and run simple function" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "func double(x) { x * 2 }\ndouble(5)";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    try std.testing.expectEqual(@as(i64, 10), result.int_val);
}

test "compile and run recursive factorial" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "func fact(n) { if n < 2 { 1 } else { n * fact(n - 1) } } fact(5)";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    try std.testing.expectEqual(@as(i64, 120), result.int_val);
}

test "compile and run fibonacci" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "func fib(n) { if n < 2 { n } else { fib(n - 1) + fib(n - 2) } } fib(10)";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    try std.testing.expectEqual(@as(i64, 55), result.int_val);
}

test "compile and run nested function calls" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "func add(a, b) { a + b } func mul(a, b) { a * b } mul(add(2, 3), add(4, 5))";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    // (2+3) * (4+5) = 5 * 9 = 45
    try std.testing.expectEqual(@as(i64, 45), result.int_val);
}

test "compile and run assignment" {
    const vm_runtime = @import("vm_runtime.zig");

    const source = "var x = 5; x = 10; x";
    var parser = coptic_parser.Parser.init(source, std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit(allocator);

    var compiler = BytecodeCompiler.init(std.testing.allocator, source);
    defer compiler.deinit(allocator);

    try compiler.compile(&ast);

    // Debug: print bytecode
    const code = compiler.getCode();
    std.debug.print("\nBytecode for '{s}':\n", .{source});
    var i: usize = 0;
    while (i < code.len) {
        const op: Opcode = @enumFromInt(code[i]);
        const size = op.operandSize();
        std.debug.print("  {d}: {s}", .{i, @tagName(op)});
        if (size > 0 and i + size < code.len) {
            std.debug.print(" {d}", .{(@as(u16, code[i+1]) << 8) | code[i+2]});
        }
        std.debug.print("\n", .{});
        i += 1 + size;
    }

    var vm = try vm_runtime.VM.init(std.testing.allocator);
    defer vm.deinit(allocator);

    vm.load(compiler.getCode(), compiler.getConstants());
    const result = try vm.run();

    try std.testing.expectEqual(@as(i64, 10), result.int_val);
}
