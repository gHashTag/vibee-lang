// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC UNIFIED JIT - SINGLE SOURCE OF TRUTH
// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 JIT compiler for NaN-boxed values
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const value = @import("value.zig");
const vm_mod = @import("vm.zig");

pub const Value = value.Value;
pub const Opcode = vm_mod.Opcode;

// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 REGISTERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Reg64 = enum(u4) {
    rax = 0,
    rcx = 1,
    rdx = 2,
    rbx = 3,
    rsp = 4,
    rbp = 5,
    rsi = 6,
    rdi = 7,
    r8 = 8,
    r9 = 9,
    r10 = 10,
    r11 = 11,
    r12 = 12,
    r13 = 13,
    r14 = 14,
    r15 = 15,
};

pub const XmmReg = enum(u4) {
    xmm0 = 0,
    xmm1 = 1,
    xmm2 = 2,
    xmm3 = 3,
    xmm4 = 4,
    xmm5 = 5,
    xmm6 = 6,
    xmm7 = 7,
};

// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 ENCODER
// ═══════════════════════════════════════════════════════════════════════════════

pub const X64Encoder = struct {
    code: std.ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .code = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    pub fn getCode(self: *Self) []const u8 {
        return self.code.items;
    }

    pub fn clear(self: *Self) void {
        self.code.clearRetainingCapacity();
    }

    // REX prefix
    inline fn rex(self: *Self, w: bool, r: bool, x: bool, b: bool) !void {
        const byte: u8 = 0x40 |
            (if (w) @as(u8, 0x08) else 0) |
            (if (r) @as(u8, 0x04) else 0) |
            (if (x) @as(u8, 0x02) else 0) |
            (if (b) @as(u8, 0x01) else 0);
        try self.code.append(byte);
    }

    // ModR/M byte
    inline fn modrm(self: *Self, mod: u2, reg: u3, rm: u3) !void {
        try self.code.append((@as(u8, mod) << 6) | (@as(u8, reg) << 3) | @as(u8, rm));
    }

    // MOV reg, imm64
    pub fn movImm64(self: *Self, dst: Reg64, imm: u64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.rex(true, false, false, dst_val >= 8);
        try self.code.append(0xB8 + (dst_val & 0x7));
        try self.code.appendSlice(&@as([8]u8, @bitCast(imm)));
    }

    // MOV reg, reg
    pub fn movReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x89);
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // PUSH reg
    pub fn push(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        if (reg_val >= 8) {
            try self.code.append(0x41);
        }
        try self.code.append(0x50 + (reg_val & 0x7));
    }

    // POP reg
    pub fn pop(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        if (reg_val >= 8) {
            try self.code.append(0x41);
        }
        try self.code.append(0x58 + (reg_val & 0x7));
    }

    // ADD reg, reg
    pub fn addReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x01);
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // SUB reg, reg
    pub fn subReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x29);
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // IMUL reg, reg
    pub fn imulReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, dst_val >= 8, false, src_val >= 8);
        try self.code.append(0x0F);
        try self.code.append(0xAF);
        try self.modrm(3, @truncate(dst_val & 0x7), @truncate(src_val & 0x7));
    }

    // CMP reg, reg
    pub fn cmpReg(self: *Self, a: Reg64, b: Reg64) !void {
        const a_val = @intFromEnum(a);
        const b_val = @intFromEnum(b);
        try self.rex(true, b_val >= 8, false, a_val >= 8);
        try self.code.append(0x39);
        try self.modrm(3, @truncate(b_val & 0x7), @truncate(a_val & 0x7));
    }

    // JMP rel32
    pub fn jmpRel32(self: *Self, offset: i32) !void {
        try self.code.append(0xE9);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JE rel32
    pub fn jeRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x84);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JNE rel32
    pub fn jneRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x85);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JL rel32
    pub fn jlRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x8C);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JG rel32
    pub fn jgRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x8F);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // CALL rel32
    pub fn callRel32(self: *Self, offset: i32) !void {
        try self.code.append(0xE8);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // RET
    pub fn ret(self: *Self) !void {
        try self.code.append(0xC3);
    }

    // NOP
    pub fn nop(self: *Self) !void {
        try self.code.append(0x90);
    }

    // MOVSD xmm, xmm (SSE2 double move)
    pub fn movsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x10);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // ADDSD xmm, xmm
    pub fn addsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x58);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // SUBSD xmm, xmm
    pub fn subsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x5C);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // MULSD xmm, xmm
    pub fn mulsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x59);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // DIVSD xmm, xmm
    pub fn divsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x5E);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const JitCompiler = struct {
    encoder: X64Encoder,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .encoder = X64Encoder.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.encoder.deinit();
    }

    /// Compile bytecode to x86-64 machine code
    pub fn compile(self: *Self, bytecode: []const u8, constants: []const Value) ![]const u8 {
        self.encoder.clear();

        // Prologue
        try self.encoder.push(.rbp);
        try self.encoder.movReg(.rbp, .rsp);

        var ip: usize = 0;
        while (ip < bytecode.len) {
            const opcode: Opcode = @enumFromInt(bytecode[ip]);
            ip += 1;

            switch (opcode) {
                .nop => try self.encoder.nop(),

                .load_const => {
                    const idx = (@as(u16, bytecode[ip]) << 8) | @as(u16, bytecode[ip + 1]);
                    ip += 2;
                    if (idx < constants.len) {
                        try self.encoder.movImm64(.rax, constants[idx].bits);
                        try self.encoder.push(.rax);
                    }
                },

                .add => {
                    try self.encoder.pop(.rbx);
                    try self.encoder.pop(.rax);
                    try self.encoder.addReg(.rax, .rbx);
                    try self.encoder.push(.rax);
                },

                .sub => {
                    try self.encoder.pop(.rbx);
                    try self.encoder.pop(.rax);
                    try self.encoder.subReg(.rax, .rbx);
                    try self.encoder.push(.rax);
                },

                .mul => {
                    try self.encoder.pop(.rbx);
                    try self.encoder.pop(.rax);
                    try self.encoder.imulReg(.rax, .rbx);
                    try self.encoder.push(.rax);
                },

                .halt => {
                    try self.encoder.pop(.rax);
                    break;
                },

                else => {
                    // Skip unsupported opcodes
                    switch (opcode) {
                        .push, .load_local, .store_local, .load_global, .store_global => ip += 2,
                        .jump, .jump_if, .jump_if_not => ip += 4,
                        .call => ip += 5,
                        .native_call => ip += 2,
                        else => {},
                    }
                },
            }
        }

        // Epilogue
        try self.encoder.movReg(.rsp, .rbp);
        try self.encoder.pop(.rbp);
        try self.encoder.ret();

        return self.encoder.getCode();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "X64Encoder basic" {
    var enc = X64Encoder.init(std.testing.allocator);
    defer enc.deinit();

    try enc.nop();
    try enc.ret();

    try std.testing.expectEqual(@as(usize, 2), enc.getCode().len);
    try std.testing.expectEqual(@as(u8, 0x90), enc.getCode()[0]); // NOP
    try std.testing.expectEqual(@as(u8, 0xC3), enc.getCode()[1]); // RET
}

test "X64Encoder mov imm64" {
    var enc = X64Encoder.init(std.testing.allocator);
    defer enc.deinit();

    try enc.movImm64(.rax, 0x123456789ABCDEF0);

    // REX.W + MOV rax, imm64
    try std.testing.expectEqual(@as(u8, 0x48), enc.getCode()[0]); // REX.W
    try std.testing.expectEqual(@as(u8, 0xB8), enc.getCode()[1]); // MOV rax
}

test "X64Encoder push/pop" {
    var enc = X64Encoder.init(std.testing.allocator);
    defer enc.deinit();

    try enc.push(.rax);
    try enc.pop(.rbx);

    try std.testing.expectEqual(@as(u8, 0x50), enc.getCode()[0]); // PUSH rax
    try std.testing.expectEqual(@as(u8, 0x5B), enc.getCode()[1]); // POP rbx
}

test "JitCompiler init" {
    var jit = JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    const constants = [_]Value{Value.int(42)};
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.halt),
    };

    const code = try jit.compile(&bytecode, &constants);
    try std.testing.expect(code.len > 0);
}
