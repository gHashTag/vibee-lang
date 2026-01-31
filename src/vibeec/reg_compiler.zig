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
const coptic_lexer = @import("coptic_lexer.zig");
const AstNode = coptic_parser.AstNode;
const NodeKind = coptic_parser.NodeKind;
const Token = coptic_lexer.Token;

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER ALLOCATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const NUM_TEMP_REGS: u4 = 14; // R0-R13 available for allocation

pub const CompileError = error{
    OutOfMemory,
    InvalidNode,
    UndefinedVariable,
    TooManyLocals,
    TooManyConstants,
    JumpTooLarge,
    RegisterSpill,
};

const Local = struct {
    name: []const u8,
    reg: u4,
    depth: u32,
    spilled: bool,
    local_idx: u16,
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const RegCompiler = struct {
    allocator: Allocator,
    emitter: RegBytecodeEmitter,
    source: []const u8,

    locals: std.ArrayList(Local),
    scope_depth: u32,

    reg_in_use: [NUM_TEMP_REGS]bool,
    next_local_idx: u16,

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

    fn allocReg(self: *Self) CompileError!u4 {
        for (0..NUM_TEMP_REGS) |i| {
            if (!self.reg_in_use[i]) {
                self.reg_in_use[i] = true;
                return @intCast(i);
            }
        }
        return CompileError.RegisterSpill;
    }

    fn freeReg(self: *Self, reg: u4) void {
        if (reg < NUM_TEMP_REGS) {
            self.reg_in_use[reg] = false;
        }
    }

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

    fn declareLocal(self: *Self, name: []const u8) CompileError!u4 {
        const reg = self.allocReg() catch {
            const idx = self.next_local_idx;
            self.next_local_idx += 1;
            try self.locals.append(.{
                .name = name,
                .reg = 0,
                .depth = self.scope_depth,
                .spilled = true,
                .local_idx = idx,
            });
            return 0;
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

    fn getTokenText(self: *Self, token: Token) []const u8 {
        return token.lexeme(self.source);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn compile(self: *Self, ast: *const AstNode) CompileError!void {
        _ = try self.compileExpr(ast, 0);
        try self.emitter.emit(.HALT);
    }

    fn compileExpr(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        return switch (node.kind) {
            .program => try self.compileProgram(node, target),
            .block => try self.compileBlock(node, target),
            .literal_int => try self.compileInt(node, target),
            .literal_float => try self.compileFloat(node, target),
            .literal_string => try self.compileString(node, target),
            .literal_bool => try self.compileBool(node, target),
            .identifier => try self.compileIdentifier(node, target),
            .binary_expr => try self.compileBinaryOp(node, target),
            .unary_expr => try self.compileUnaryOp(node, target),
            .var_decl, .let_decl => try self.compileVarDecl(node, target),
            .if_expr => try self.compileIf(node, target),
            .while_stmt => try self.compileWhile(node, target),
            .for_stmt => try self.compileFor(node, target),
            .call_expr => try self.compileFuncCall(node, target),
            else => target,
        };
    }

    fn compileProgram(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        for (node.children.items) |*child| {
            _ = try self.compileExpr(child, target);
        }
        return target;
    }

    fn compileBlock(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        self.scope_depth += 1;
        const locals_count = self.locals.items.len;

        for (node.children.items) |*child| {
            _ = try self.compileExpr(child, target);
        }

        while (self.locals.items.len > locals_count) {
            const local = self.locals.pop();
            if (!local.spilled) {
                self.freeReg(local.reg);
            }
        }
        self.scope_depth -= 1;

        return target;
    }

    fn compileInt(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        const text = self.getTokenText(node.token);
        const i = std.fmt.parseInt(i64, text, 10) catch 0;
        if (i >= 0 and i <= 65535) {
            try self.emitter.emitRI(.MOV_RI, target, @intCast(@as(u16, @truncate(@as(u64, @bitCast(i))))));
        } else {
            const idx = try self.emitter.addConstant(.{ .int_val = i });
            try self.emitter.emitRI(.LOAD_CONST, target, idx);
        }
        return target;
    }

    fn compileFloat(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        const text = self.getTokenText(node.token);
        const f = std.fmt.parseFloat(f64, text) catch 0.0;
        const idx = try self.emitter.addConstant(.{ .float_val = f });
        try self.emitter.emitRI(.LOAD_CONST, target, idx);
        return target;
    }

    fn compileString(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        const text = self.getTokenText(node.token);
        // Remove quotes
        const str = if (text.len >= 2) text[1 .. text.len - 1] else text;
        const idx = try self.emitter.addConstant(.{ .string_val = str });
        try self.emitter.emitRI(.LOAD_CONST, target, idx);
        return target;
    }

    fn compileBool(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        const text = self.getTokenText(node.token);
        const b: u16 = if (std.mem.eql(u8, text, "true")) 1 else 0;
        try self.emitter.emitRI(.MOV_RI, target, b);
        return target;
    }

    fn compileIdentifier(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        const name = self.getTokenText(node.token);
        if (self.findLocal(name)) |local| {
            if (local.spilled) {
                try self.emitter.emitRI(.LOAD_LOCAL, target, local.local_idx);
            } else if (local.reg != target) {
                try self.emitter.emitRR(.MOV_RR, target, local.reg);
            }
        }
        return target;
    }

    fn compileBinaryOp(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 2) return target;

        const left = &node.children.items[0];
        const right = &node.children.items[1];

        _ = try self.compileExpr(left, target);

        const right_reg = try self.allocReg();
        defer self.freeReg(right_reg);

        _ = try self.compileExpr(right, right_reg);

        const op = self.getTokenText(node.token);

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
        }

        return target;
    }

    fn compileUnaryOp(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 1) return target;

        _ = try self.compileExpr(&node.children.items[0], target);

        const op = self.getTokenText(node.token);
        if (std.mem.eql(u8, op, "-")) {
            try self.emitter.emitRR(.NEG_RR, target, target);
        } else if (std.mem.eql(u8, op, "!") or std.mem.eql(u8, op, "not")) {
            try self.emitter.emitRR(.NOT_RR, target, target);
        }

        return target;
    }

    fn compileVarDecl(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 1) return target;

        const name_node = &node.children.items[0];
        const name = self.getTokenText(name_node.token);
        const reg = try self.declareLocal(name);

        if (node.children.items.len >= 2) {
            const init_node = &node.children.items[1];
            const local = self.findLocal(name).?;

            if (local.spilled) {
                _ = try self.compileExpr(init_node, target);
                try self.emitter.emitRI(.STORE_LOCAL, target, local.local_idx);
            } else {
                _ = try self.compileExpr(init_node, reg);
            }
        } else {
            const local = self.findLocal(name).?;
            if (local.spilled) {
                try self.emitter.emitRI(.MOV_RI, target, 0);
                try self.emitter.emitRI(.STORE_LOCAL, target, local.local_idx);
            } else {
                try self.emitter.emitRI(.MOV_RI, reg, 0);
            }
        }

        return target;
    }

    fn compileIf(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 2) return target;

        const cond = &node.children.items[0];
        const then_branch = &node.children.items[1];

        _ = try self.compileExpr(cond, target);

        const jump_pos = self.emitter.currentPos() + 2;
        try self.emitter.emitRAddr(.JZ_R, target, 0);

        _ = try self.compileExpr(then_branch, target);

        if (node.children.items.len >= 3) {
            const else_branch = &node.children.items[2];

            const end_jump_pos = self.emitter.currentPos() + 1;
            try self.emitter.emitAddr(.JMP, 0);

            const else_addr = self.emitter.currentPos();
            self.emitter.patchJump(jump_pos, else_addr);

            _ = try self.compileExpr(else_branch, target);

            const end_addr = self.emitter.currentPos();
            self.emitter.patchJump(end_jump_pos, end_addr);
        } else {
            const end_addr = self.emitter.currentPos();
            self.emitter.patchJump(jump_pos, end_addr);
        }

        return target;
    }

    fn compileWhile(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 2) return target;

        const cond = &node.children.items[0];
        const body = &node.children.items[1];

        const loop_start = self.emitter.currentPos();
        self.loop_start = loop_start;

        _ = try self.compileExpr(cond, target);

        const exit_jump_pos = self.emitter.currentPos() + 2;
        try self.emitter.emitRAddr(.JZ_R, target, 0);

        _ = try self.compileExpr(body, target);

        try self.emitter.emitAddr(.JMP, loop_start);

        const end_addr = self.emitter.currentPos();
        self.emitter.patchJump(exit_jump_pos, end_addr);

        self.loop_start = null;

        return target;
    }

    fn compileFor(self: *Self, node: *const AstNode, target: u4) CompileError!u4 {
        if (node.children.items.len < 3) return target;

        self.scope_depth += 1;

        const var_node = &node.children.items[0];
        const limit_node = &node.children.items[1];
        const body = &node.children.items[2];

        var loop_reg: u4 = 0;
        const name = self.getTokenText(var_node.token);
        loop_reg = try self.declareLocal(name);
        try self.emitter.emitRI(.MOV_RI, loop_reg, 0);

        const limit_reg = try self.allocReg();
        defer self.freeReg(limit_reg);
        _ = try self.compileExpr(limit_node, limit_reg);

        const loop_start = self.emitter.currentPos();
        self.loop_start = loop_start;

        try self.emitter.emitRR(.CMP_RR, loop_reg, limit_reg);

        const exit_jump_pos = self.emitter.currentPos() + 1;
        try self.emitter.emitAddr(.JGE, 0);

        _ = try self.compileExpr(body, target);

        try self.emitter.emitRR(.INC_R, loop_reg, 0);

        try self.emitter.emitAddr(.JMP, loop_start);

        const end_addr = self.emitter.currentPos();
        self.emitter.patchJump(exit_jump_pos, end_addr);

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
        const name = self.getTokenText(node.token);

        if (std.mem.eql(u8, name, "print")) {
            if (node.children.items.len > 0) {
                _ = try self.compileExpr(&node.children.items[0], 0);
            }
            try self.emitter.emitAddr(.CALL_NATIVE, 0); // print = native 0
        }

        _ = target;
        return 0;
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
