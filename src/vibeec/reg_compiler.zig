// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC REGISTER COMPILER - .999 TO REGISTER BYTECODE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V38 - Compiles AST to register-based bytecode
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: 16 general-purpose registers (R0-R15)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const reg_bytecode = @import("reg_bytecode.zig");
const RegOpcode = reg_bytecode.RegOpcode;
const RegBytecodeEmitter = reg_bytecode.RegBytecodeEmitter;
const bytecode = @import("bytecode.zig");
const Value = bytecode.Value;
const coptic_parser = @import("coptic_parser_real.zig");
const AstNode = coptic_parser.AstNode;
const NodeKind = coptic_parser.NodeKind;

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER ALLOCATION
// ═══════════════════════════════════════════════════════════════════════════════

// Register conventions:
// R0  = accumulator / return value
// R1-R13 = general purpose / temporaries
// R14 = reserved (frame pointer)
// R15 = reserved (stack pointer)

pub const NUM_TEMP_REGS: u4 = 14; // R0-R13 available for allocation

pub const CompileError = error{
    OutOfMemory,
    InvalidNode,
    UndefinedVariable,
    TooManyLocals,
    TooManyConstants,
    JumpTooLarge,
    RegisterSpill, // Out of registers
};

const Local = struct {
    name: []const u8,
    reg: u4, // Assigned register (or 0xFF if spilled to locals[])
    depth: u32,
    spilled: bool,
    local_idx: u16, // Index in locals[] if spilled
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const RegCompiler = struct {
    allocator: Allocator,
    emitter: RegBytecodeEmitter,
    source: []const u8,

    // Variable tracking
    locals: std.ArrayList(Local),
    scope_depth: u32,

    // Register allocation
    reg_in_use: [NUM_TEMP_REGS]bool,
    next_local_idx: u16, // For spilled variables

    // Loop handling
    loop_start: ?u16,
    loop_end_patches: std.ArrayList(u16),

    const Self = @This();

    pub fn init(allocator: Allocator, source: []const u8) Self {
        return .{
            .allocator = allocator,
            .emitter = RegBytecodeEmitter.init(allocator),
            .source = source,
            .locals = std.ArrayList(Local).init(allocator),
            .scope_depth = 0,
            .reg_in_use = [_]bool{false} ** NUM_TEMP_REGS,
            .next_local_idx = 0,
            .loop_start = null,
            .loop_end_patches = std.ArrayList(u16).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.emitter.deinit();
        self.locals.deinit();
        self.loop_end_patches.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REGISTER ALLOCATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Allocate a free register
    fn allocReg(self: *Self) CompileError!u4 {
        for (0..NUM_TEMP_REGS) |i| {
            if (!self.reg_in_use[i]) {
                self.reg_in_use[i] = true;
                return @intCast(i);
            }
        }
        return CompileError.RegisterSpill;
    }

    /// Free a register
    fn freeReg(self: *Self, reg: u4) void {
        if (reg < NUM_TEMP_REGS) {
            self.reg_in_use[reg] = false;
        }
    }

    /// Find local variable by name
    fn findLocal(self: *Self, name: []const u8) ?*Local {
        var i = self.locals.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.locals.items[i].name, name)) {
                return &self.locals.items[i];
            }
        }
        return null;
    }

    /// Declare a new local variable
    fn declareLocal(self: *Self, name: []const u8) CompileError!u4 {
        // Try to allocate a register
        const reg = self.allocReg() catch {
            // Spill to locals array
            const idx = self.next_local_idx;
            self.next_local_idx += 1;
            try self.locals.append(.{
                .name = name,
                .reg = 0,
                .depth = self.scope_depth,
                .spilled = true,
                .local_idx = idx,
            });
            return 0; // Will use locals[] instead
        };

        try self.locals.append(.{
            .name = name,
            .reg = reg,
            .depth = self.scope_depth,
            .spilled = false,
            .local_idx = 0,
        });

        return reg;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn compile(self: *Self, ast: *const AstNode) CompileError!void {
        _ = try self.compileExpr(ast, 0);
        try self.emitter.emit(.HALT);
    }

    /// Compile expression, result goes to target register
    /// Returns the register containing the result
    fn compileExpr(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        return switch (node.kind) {
            .program => try self.compileProgram(node, target),
            .block => try self.compileBlock(node, target),
            .number => try self.compileNumber(node, target),
            .string => try self.compileString(node, target),
            .boolean => try self.compileBoolean(node, target),
            .identifier => try self.compileIdentifier(node, target),
            .binary_op => try self.compileBinaryOp(node, target),
            .unary_op => try self.compileUnaryOp(node, target),
            .assignment => try self.compileAssignment(node, target),
            .var_decl => try self.compileVarDecl(node, target),
            .if_stmt => try self.compileIf(node, target),
            .while_stmt => try self.compileWhile(node, target),
            .for_stmt => try self.compileFor(node, target),
            .func_call => try self.compileFuncCall(node, target),
            else => target, // Unsupported - return target unchanged
        };
    }

    fn compileProgram(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        for (node.children.items) |child| {
            _ = try self.compileExpr(child, target);
        }
        return target;
    }

    fn compileBlock(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        self.scope_depth += 1;
        const locals_count = self.locals.items.len;

        for (node.children.items) |child| {
            _ = try self.compileExpr(child, target);
        }

        // Pop locals from this scope
        while (self.locals.items.len > locals_count) {
            const local = self.locals.pop();
            if (!local.spilled) {
                self.freeReg(local.reg);
            }
        }
        self.scope_depth -= 1;

        return target;
    }

    fn compileNumber(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.value) |val| {
            // Parse number from source
            const num_str = self.source[val.start..val.end];
            if (std.mem.indexOf(u8, num_str, ".")) |_| {
                // Float
                const f = std.fmt.parseFloat(f64, num_str) catch 0.0;
                const idx = try self.emitter.addConstant(.{ .float_val = f });
                try self.emitter.emitRI(.LOAD_CONST, target, idx);
            } else {
                // Integer
                const i = std.fmt.parseInt(i64, num_str, 10) catch 0;
                if (i >= 0 and i <= 65535) {
                    // Small immediate
                    try self.emitter.emitRI(.MOV_RI, target, @intCast(@as(u16, @truncate(@as(u64, @bitCast(i))))));
                } else {
                    // Use constant pool
                    const idx = try self.emitter.addConstant(.{ .int_val = i });
                    try self.emitter.emitRI(.LOAD_CONST, target, idx);
                }
            }
        }
        return target;
    }

    fn compileString(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.value) |val| {
            const str = self.source[val.start + 1 .. val.end - 1]; // Remove quotes
            const idx = try self.emitter.addConstant(.{ .string_val = str });
            try self.emitter.emitRI(.LOAD_CONST, target, idx);
        }
        return target;
    }

    fn compileBoolean(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.value) |val| {
            const bool_str = self.source[val.start..val.end];
            const b: u16 = if (std.mem.eql(u8, bool_str, "true")) 1 else 0;
            try self.emitter.emitRI(.MOV_RI, target, b);
        }
        return target;
    }

    fn compileIdentifier(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.value) |val| {
            const name = self.source[val.start..val.end];
            if (self.findLocal(name)) |local| {
                if (local.spilled) {
                    try self.emitter.emitRI(.LOAD_LOCAL, target, local.local_idx);
                } else if (local.reg != target) {
                    try self.emitter.emitRR(.MOV_RR, target, local.reg);
                }
                return target;
            }
            // Undefined variable - could emit LOAD_GLOBAL here
        }
        return target;
    }

    fn compileBinaryOp(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 2) return target;

        const left = node.children.items[0];
        const right = node.children.items[1];

        // Compile left to target
        _ = try self.compileExpr(left, target);

        // Allocate temp for right
        const right_reg = try self.allocReg();
        defer self.freeReg(right_reg);

        _ = try self.compileExpr(right, right_reg);

        // Get operator
        if (node.value) |val| {
            const op = self.source[val.start..val.end];

            if (std.mem.eql(u8, op, "+")) {
                try self.emitter.emitRRR(.ADD_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "-")) {
                try self.emitter.emitRRR(.SUB_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "*")) {
                try self.emitter.emitRRR(.MUL_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "/")) {
                try self.emitter.emitRRR(.DIV_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "<")) {
                try self.emitter.emitRRR(.LT_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "<=")) {
                try self.emitter.emitRRR(.LE_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, ">")) {
                try self.emitter.emitRRR(.GT_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, ">=")) {
                try self.emitter.emitRRR(.GE_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "==")) {
                try self.emitter.emitRRR(.EQ_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "!=")) {
                try self.emitter.emitRRR(.NE_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "and") or std.mem.eql(u8, op, "&&")) {
                try self.emitter.emitRRR(.AND_RRR, target, target, right_reg);
            } else if (std.mem.eql(u8, op, "or") or std.mem.eql(u8, op, "||")) {
                try self.emitter.emitRRR(.OR_RRR, target, target, right_reg);
            }
        }

        return target;
    }

    fn compileUnaryOp(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 1) return target;

        _ = try self.compileExpr(node.children.items[0], target);

        if (node.value) |val| {
            const op = self.source[val.start..val.end];
            if (std.mem.eql(u8, op, "-")) {
                try self.emitter.emitRR(.NEG_RR, target, target);
            } else if (std.mem.eql(u8, op, "not") or std.mem.eql(u8, op, "!")) {
                try self.emitter.emitRR(.NOT_RR, target, target);
            }
        }

        return target;
    }

    fn compileAssignment(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 2) return target;

        const name_node = node.children.items[0];
        const value_node = node.children.items[1];

        if (name_node.value) |val| {
            const name = self.source[val.start..val.end];

            if (self.findLocal(name)) |local| {
                if (local.spilled) {
                    _ = try self.compileExpr(value_node, target);
                    try self.emitter.emitRI(.STORE_LOCAL, target, local.local_idx);
                } else {
                    _ = try self.compileExpr(value_node, local.reg);
                }
            }
        }

        return target;
    }

    fn compileVarDecl(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 1) return target;

        const name_node = node.children.items[0];
        if (name_node.value) |val| {
            const name = self.source[val.start..val.end];
            const reg = try self.declareLocal(name);

            // If there's an initializer
            if (node.children.items.len >= 2) {
                const init_node = node.children.items[1];
                const local = self.findLocal(name).?;

                if (local.spilled) {
                    _ = try self.compileExpr(init_node, target);
                    try self.emitter.emitRI(.STORE_LOCAL, target, local.local_idx);
                } else {
                    _ = try self.compileExpr(init_node, reg);
                }
            } else {
                // Initialize to 0
                const local = self.findLocal(name).?;
                if (local.spilled) {
                    try self.emitter.emitRI(.MOV_RI, target, 0);
                    try self.emitter.emitRI(.STORE_LOCAL, target, local.local_idx);
                } else {
                    try self.emitter.emitRI(.MOV_RI, reg, 0);
                }
            }
        }

        return target;
    }

    fn compileIf(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 2) return target;

        const cond = node.children.items[0];
        const then_branch = node.children.items[1];

        // Compile condition to target
        _ = try self.compileExpr(cond, target);

        // JZ_R target, else_addr
        const jump_pos = self.emitter.currentPos() + 2; // Position of address
        try self.emitter.emitRAddr(.JZ_R, target, 0); // Placeholder

        // Compile then branch
        _ = try self.compileExpr(then_branch, target);

        if (node.children.items.len >= 3) {
            // Has else branch
            const else_branch = node.children.items[2];

            // JMP end_addr
            const end_jump_pos = self.emitter.currentPos() + 1;
            try self.emitter.emitAddr(.JMP, 0); // Placeholder

            // Patch else jump
            const else_addr = self.emitter.currentPos();
            self.emitter.patchJump(jump_pos, else_addr);

            // Compile else branch
            _ = try self.compileExpr(else_branch, target);

            // Patch end jump
            const end_addr = self.emitter.currentPos();
            self.emitter.patchJump(end_jump_pos, end_addr);
        } else {
            // No else - patch jump to here
            const end_addr = self.emitter.currentPos();
            self.emitter.patchJump(jump_pos, end_addr);
        }

        return target;
    }

    fn compileWhile(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 2) return target;

        const cond = node.children.items[0];
        const body = node.children.items[1];

        const loop_start = self.emitter.currentPos();
        self.loop_start = loop_start;

        // Compile condition
        _ = try self.compileExpr(cond, target);

        // JZ_R target, end
        const exit_jump_pos = self.emitter.currentPos() + 2;
        try self.emitter.emitRAddr(.JZ_R, target, 0);

        // Compile body
        _ = try self.compileExpr(body, target);

        // JMP loop_start
        try self.emitter.emitAddr(.JMP, loop_start);

        // Patch exit jump
        const end_addr = self.emitter.currentPos();
        self.emitter.patchJump(exit_jump_pos, end_addr);

        // Patch break statements
        for (self.loop_end_patches.items) |patch_pos| {
            self.emitter.patchJump(patch_pos, end_addr);
        }
        self.loop_end_patches.clearRetainingCapacity();

        self.loop_start = null;

        return target;
    }

    fn compileFor(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        // for i in range(n) { body }
        // Simplified: expects 3 children: var_name, limit, body
        if (node.children.items.len < 3) return target;

        self.scope_depth += 1;

        const var_node = node.children.items[0];
        const limit_node = node.children.items[1];
        const body = node.children.items[2];

        // Declare loop variable
        var loop_reg: u4 = 0;
        if (var_node.value) |val| {
            const name = self.source[val.start..val.end];
            loop_reg = try self.declareLocal(name);
            // Initialize to 0
            try self.emitter.emitRI(.MOV_RI, loop_reg, 0);
        }

        // Compile limit to a register
        const limit_reg = try self.allocReg();
        defer self.freeReg(limit_reg);
        _ = try self.compileExpr(limit_node, limit_reg);

        // Loop start
        const loop_start = self.emitter.currentPos();
        self.loop_start = loop_start;

        // Compare: CMP loop_reg, limit_reg
        try self.emitter.emitRR(.CMP_RR, loop_reg, limit_reg);

        // JGE end (exit if loop_reg >= limit_reg)
        const exit_jump_pos = self.emitter.currentPos() + 1;
        try self.emitter.emitAddr(.JGE, 0);

        // Compile body
        _ = try self.compileExpr(body, target);

        // Increment loop variable
        try self.emitter.emitRR(.INC_R, loop_reg, 0);

        // Jump back
        try self.emitter.emitAddr(.JMP, loop_start);

        // Patch exit
        const end_addr = self.emitter.currentPos();
        self.emitter.patchJump(exit_jump_pos, end_addr);

        // Clean up scope
        while (self.locals.items.len > 0 and self.locals.items[self.locals.items.len - 1].depth == self.scope_depth) {
            const local = self.locals.pop();
            if (!local.spilled) {
                self.freeReg(local.reg);
            }
        }
        self.scope_depth -= 1;
        self.loop_start = null;

        return target;
    }

    fn compileFuncCall(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        // For now, just handle print() as a native call
        if (node.value) |val| {
            const name = self.source[val.start..val.end];

            if (std.mem.eql(u8, name, "print")) {
                // Compile argument to R0
                if (node.children.items.len > 0) {
                    _ = try self.compileExpr(node.children.items[0], 0);
                }
                // CALL_NATIVE print (index 0)
                try self.emitter.emitAddr(.CALL_NATIVE, 0);
            }
        }

        return target;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // OUTPUT
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn getCode(self: *Self) []const u8 {
        return self.emitter.code.items;
    }

    pub fn getConstants(self: *Self) []const Value {
        return self.emitter.constants.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RegCompiler init" {
    var compiler = RegCompiler.init(std.testing.allocator, "");
    defer compiler.deinit();

    try std.testing.expectEqual(@as(u32, 0), compiler.scope_depth);
}

test "RegCompiler register allocation" {
    var compiler = RegCompiler.init(std.testing.allocator, "");
    defer compiler.deinit();

    const r0 = try compiler.allocReg();
    try std.testing.expectEqual(@as(u4, 0), r0);

    const r1 = try compiler.allocReg();
    try std.testing.expectEqual(@as(u4, 1), r1);

    compiler.freeReg(r0);
    const r0_again = try compiler.allocReg();
    try std.testing.expectEqual(@as(u4, 0), r0_again);
}
