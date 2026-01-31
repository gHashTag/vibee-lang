// ═══════════════════════════════════════════════════════════════════════════════
// X86-64 NATIVE CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════
// Generates executable x86-64 machine code from JIT IR
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const jit = @import("jit.zig");
const IROpcode = jit.IROpcode;
const IRInstruction = jit.IRInstruction;

// ═══════════════════════════════════════════════════════════════════════════════
// X86-64 REGISTERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Reg64 = enum(u4) {
    RAX = 0,
    RCX = 1,
    RDX = 2,
    RBX = 3,
    RSP = 4,
    RBP = 5,
    RSI = 6,
    RDI = 7,
    R8 = 8,
    R9 = 9,
    R10 = 10,
    R11 = 11,
    R12 = 12,
    R13 = 13,
    R14 = 14,
    R15 = 15,
};

// ═══════════════════════════════════════════════════════════════════════════════
// X86-64 CODE EMITTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const X86_64Emitter = struct {
    code: std.ArrayList(u8),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .code = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    pub fn getCode(self: *Self) []u8 {
        return self.code.items;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REX PREFIX
    // ═══════════════════════════════════════════════════════════════════════════

    fn rex(w: bool, r: bool, x: bool, b: bool) u8 {
        var val: u8 = 0x40;
        if (w) val |= 0x08;
        if (r) val |= 0x04;
        if (x) val |= 0x02;
        if (b) val |= 0x01;
        return val;
    }

    fn needsRex(reg: Reg64) bool {
        return @intFromEnum(reg) >= 8;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MOV INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// mov reg, imm64
    pub fn movImm64(self: *Self, dst: Reg64, imm: i64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, false, false, dst_val >= 8));
        try self.code.append(0xB8 + (dst_val & 0x7));
        try self.emitImm64(imm);
    }

    /// mov reg, reg
    pub fn movRegReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);
        try self.code.append(rex(true, src_val >= 8, false, dst_val >= 8));
        try self.code.append(0x89);
        try self.code.append(0xC0 | ((src_val & 0x7) << 3) | (dst_val & 0x7));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARITHMETIC INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// add dst, src
    pub fn addRegReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);
        try self.code.append(rex(true, src_val >= 8, false, dst_val >= 8));
        try self.code.append(0x01);
        try self.code.append(0xC0 | ((src_val & 0x7) << 3) | (dst_val & 0x7));
    }

    /// sub dst, src
    pub fn subRegReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);
        try self.code.append(rex(true, src_val >= 8, false, dst_val >= 8));
        try self.code.append(0x29);
        try self.code.append(0xC0 | ((src_val & 0x7) << 3) | (dst_val & 0x7));
    }

    /// imul dst, src
    pub fn imulRegReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);
        try self.code.append(rex(true, dst_val >= 8, false, src_val >= 8));
        try self.code.append(0x0F);
        try self.code.append(0xAF);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    /// neg reg
    pub fn negReg(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        try self.code.append(rex(true, false, false, reg_val >= 8));
        try self.code.append(0xF7);
        try self.code.append(0xD8 | (reg_val & 0x7));
    }

    /// inc reg
    pub fn incReg(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        try self.code.append(rex(true, false, false, reg_val >= 8));
        try self.code.append(0xFF);
        try self.code.append(0xC0 | (reg_val & 0x7));
    }

    /// dec reg
    pub fn decReg(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        try self.code.append(rex(true, false, false, reg_val >= 8));
        try self.code.append(0xFF);
        try self.code.append(0xC8 | (reg_val & 0x7));
    }

    /// idiv reg (signed divide RDX:RAX by reg, quotient in RAX, remainder in RDX)
    pub fn idivReg(self: *Self, divisor: Reg64) !void {
        const div_val: u8 = @intFromEnum(divisor);
        try self.code.append(rex(true, false, false, div_val >= 8));
        try self.code.append(0xF7);
        try self.code.append(0xF8 | (div_val & 0x7));
    }

    /// cqo (sign-extend RAX into RDX:RAX)
    pub fn cqo(self: *Self) !void {
        try self.code.append(0x48);
        try self.code.append(0x99);
    }

    /// xor reg, reg (clear register)
    pub fn xorRegReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);
        try self.code.append(rex(true, src_val >= 8, false, dst_val >= 8));
        try self.code.append(0x31);
        try self.code.append(0xC0 | ((src_val & 0x7) << 3) | (dst_val & 0x7));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MEMORY OPERATIONS (for local variables)
    // ═══════════════════════════════════════════════════════════════════════════

    /// mov [rbp + offset], reg
    pub fn movMemReg(self: *Self, offset: i32, src: Reg64) !void {
        const src_val: u8 = @intFromEnum(src);
        try self.code.append(rex(true, src_val >= 8, false, false));
        try self.code.append(0x89);
        if (offset >= -128 and offset <= 127) {
            try self.code.append(0x45 | ((src_val & 0x7) << 3));
            try self.code.append(@bitCast(@as(i8, @intCast(offset))));
        } else {
            try self.code.append(0x85 | ((src_val & 0x7) << 3));
            try self.emitImm32(offset);
        }
    }

    /// mov reg, [rbp + offset]
    pub fn movRegMem(self: *Self, dst: Reg64, offset: i32) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, dst_val >= 8, false, false));
        try self.code.append(0x8B);
        if (offset >= -128 and offset <= 127) {
            try self.code.append(0x45 | ((dst_val & 0x7) << 3));
            try self.code.append(@bitCast(@as(i8, @intCast(offset))));
        } else {
            try self.code.append(0x85 | ((dst_val & 0x7) << 3));
            try self.emitImm32(offset);
        }
    }

    /// push reg
    pub fn pushReg(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        if (reg_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x50 + (reg_val & 0x7));
    }

    /// pop reg
    pub fn popReg(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        if (reg_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x58 + (reg_val & 0x7));
    }

    /// sub rsp, imm8
    pub fn subRspImm8(self: *Self, imm: u8) !void {
        try self.code.append(0x48);
        try self.code.append(0x83);
        try self.code.append(0xEC);
        try self.code.append(imm);
    }

    /// add rsp, imm8
    pub fn addRspImm8(self: *Self, imm: u8) !void {
        try self.code.append(0x48);
        try self.code.append(0x83);
        try self.code.append(0xC4);
        try self.code.append(imm);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPARISON INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// cmp reg1, reg2
    pub fn cmpRegReg(self: *Self, reg1: Reg64, reg2: Reg64) !void {
        const r1: u8 = @intFromEnum(reg1);
        const r2: u8 = @intFromEnum(reg2);
        try self.code.append(rex(true, r2 >= 8, false, r1 >= 8));
        try self.code.append(0x39);
        try self.code.append(0xC0 | ((r2 & 0x7) << 3) | (r1 & 0x7));
    }

    /// setl reg (set if less)
    pub fn setl(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        if (dst_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x0F);
        try self.code.append(0x9C);
        try self.code.append(0xC0 | (dst_val & 0x7));
    }

    /// setle reg (set if less or equal)
    pub fn setle(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        if (dst_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x0F);
        try self.code.append(0x9E);
        try self.code.append(0xC0 | (dst_val & 0x7));
    }

    /// setg reg (set if greater)
    pub fn setg(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        if (dst_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x0F);
        try self.code.append(0x9F);
        try self.code.append(0xC0 | (dst_val & 0x7));
    }

    /// sete reg (set if equal)
    pub fn sete(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        if (dst_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x0F);
        try self.code.append(0x94);
        try self.code.append(0xC0 | (dst_val & 0x7));
    }

    /// setne reg (set if not equal)
    pub fn setne(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        if (dst_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x0F);
        try self.code.append(0x95);
        try self.code.append(0xC0 | (dst_val & 0x7));
    }

    /// setge reg (set if greater or equal)
    pub fn setge(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        if (dst_val >= 8) try self.code.append(rex(false, false, false, true));
        try self.code.append(0x0F);
        try self.code.append(0x9D);
        try self.code.append(0xC0 | (dst_val & 0x7));
    }

    /// test reg, reg
    pub fn testRegReg(self: *Self, reg1: Reg64, reg2: Reg64) !void {
        const r1: u8 = @intFromEnum(reg1);
        const r2: u8 = @intFromEnum(reg2);
        try self.code.append(rex(true, r2 >= 8, false, r1 >= 8));
        try self.code.append(0x85);
        try self.code.append(0xC0 | ((r2 & 0x7) << 3) | (r1 & 0x7));
    }

    /// movzx reg64, reg8 (zero extend)
    pub fn movzxReg64Reg8(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);
        try self.code.append(rex(true, dst_val >= 8, false, src_val >= 8));
        try self.code.append(0x0F);
        try self.code.append(0xB6);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONTROL FLOW
    // ═══════════════════════════════════════════════════════════════════════════

    /// ret
    pub fn ret(self: *Self) !void {
        try self.code.append(0xC3);
    }

    /// jmp rel32
    pub fn jmpRel32(self: *Self, offset: i32) !void {
        try self.code.append(0xE9);
        try self.emitImm32(offset);
    }

    /// je rel32 (jump if equal/zero)
    pub fn jeRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x84);
        try self.emitImm32(offset);
    }

    /// jne rel32 (jump if not equal/not zero)
    pub fn jneRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x85);
        try self.emitImm32(offset);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn emitImm64(self: *Self, imm: i64) !void {
        const bytes: [8]u8 = @bitCast(imm);
        try self.code.appendSlice(&bytes);
    }

    fn emitImm32(self: *Self, imm: i32) !void {
        const bytes: [4]u8 = @bitCast(imm);
        try self.code.appendSlice(&bytes);
    }

    pub fn currentOffset(self: *Self) usize {
        return self.code.items.len;
    }

    pub fn patchRel32(self: *Self, offset: usize, target: i32) void {
        const bytes: [4]u8 = @bitCast(target);
        self.code.items[offset] = bytes[0];
        self.code.items[offset + 1] = bytes[1];
        self.code.items[offset + 2] = bytes[2];
        self.code.items[offset + 3] = bytes[3];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IR TO X86-64 COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const NativeCompiler = struct {
    emitter: X86_64Emitter,
    allocator: Allocator,

    const Self = @This();

    // Register allocation: IR registers 0-7 map to R8-R15
    fn irRegToX86(ir_reg: u8) Reg64 {
        return switch (ir_reg & 0x7) {
            0 => .R8,
            1 => .R9,
            2 => .R10,
            3 => .R11,
            4 => .R12,
            5 => .R13,
            6 => .R14,
            7 => .R15,
            else => .RAX,
        };
    }

    pub fn init(allocator: Allocator) Self {
        return .{
            .emitter = X86_64Emitter.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.emitter.deinit();
    }

    pub fn compile(self: *Self, ir: []const IRInstruction) ![]u8 {
        for (ir) |instr| {
            try self.compileInstruction(instr);
        }
        // Add return at end
        try self.emitter.ret();
        return try self.emitter.code.toOwnedSlice();
    }

    fn compileInstruction(self: *Self, instr: IRInstruction) !void {
        switch (instr.opcode) {
            .LOAD_CONST => {
                const dst = irRegToX86(instr.dest);
                try self.emitter.movImm64(dst, instr.imm);
            },

            .LOAD_LOCAL => {
                // Load from stack: [rbp - (idx+1)*8]
                const dst = irRegToX86(instr.dest);
                const offset: i32 = -@as(i32, @intCast((instr.imm + 1) * 8));
                try self.emitter.movRegMem(dst, offset);
            },

            .STORE_LOCAL => {
                // Store to stack: [rbp - (idx+1)*8]
                const src = irRegToX86(instr.src1);
                const offset: i32 = -@as(i32, @intCast((instr.imm + 1) * 8));
                try self.emitter.movMemReg(offset, src);
            },

            .ADD_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                if (dst != src1) try self.emitter.movRegReg(dst, src1);
                try self.emitter.addRegReg(dst, src2);
            },

            .SUB_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                if (dst != src1) try self.emitter.movRegReg(dst, src1);
                try self.emitter.subRegReg(dst, src2);
            },

            .MUL_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                if (dst != src1) try self.emitter.movRegReg(dst, src1);
                try self.emitter.imulRegReg(dst, src2);
            },

            .DIV_INT => {
                // Division: RAX = src1 / src2
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                // Move dividend to RAX
                try self.emitter.movRegReg(.RAX, src1);
                // Sign-extend RAX to RDX:RAX
                try self.emitter.cqo();
                // Divide by src2
                try self.emitter.idivReg(src2);
                // Move result to dst
                if (dst != .RAX) try self.emitter.movRegReg(dst, .RAX);
            },

            .MOD_INT => {
                // Modulo: RDX = src1 % src2
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                // Move dividend to RAX
                try self.emitter.movRegReg(.RAX, src1);
                // Sign-extend RAX to RDX:RAX
                try self.emitter.cqo();
                // Divide by src2
                try self.emitter.idivReg(src2);
                // Move remainder (RDX) to dst
                if (dst != .RDX) try self.emitter.movRegReg(dst, .RDX);
            },

            .NEG_INT => {
                const dst = irRegToX86(instr.dest);
                const src = irRegToX86(instr.src1);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                try self.emitter.negReg(dst);
            },

            .INC_INT => {
                const dst = irRegToX86(instr.dest);
                const src = irRegToX86(instr.src1);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                try self.emitter.incReg(dst);
            },

            .DEC_INT => {
                const dst = irRegToX86(instr.dest);
                const src = irRegToX86(instr.src1);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                try self.emitter.decReg(dst);
            },

            .CMP_LT_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setl(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
            },

            .CMP_LE_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setle(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
            },

            .CMP_GT_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setg(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
            },

            .CMP_EQ_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.sete(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
            },

            .CMP_NE_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setne(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
            },

            .CMP_GE_INT => {
                const dst = irRegToX86(instr.dest);
                const src1 = irRegToX86(instr.src1);
                const src2 = irRegToX86(instr.src2);
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setge(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
            },

            .JUMP => {
                // Jump to IR offset (simplified - would need label resolution)
                const offset: i32 = @intCast(instr.imm);
                try self.emitter.jmpRel32(offset);
            },

            .JUMP_IF_ZERO => {
                // Test src1 and jump if zero
                const src = irRegToX86(instr.src1);
                try self.emitter.testRegReg(src, src);
                const offset: i32 = @intCast(instr.imm);
                try self.emitter.jeRel32(offset);
            },

            .JUMP_IF_NOT_ZERO => {
                // Test src1 and jump if not zero
                const src = irRegToX86(instr.src1);
                try self.emitter.testRegReg(src, src);
                const offset: i32 = @intCast(instr.imm);
                try self.emitter.jneRel32(offset);
            },

            .RETURN => {
                // Move result to RAX
                const src = irRegToX86(instr.dest);
                try self.emitter.movRegReg(.RAX, src);
            },

            else => {
                // Unsupported - emit nop
            },
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTABLE CODE RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExecutableCode = struct {
    code: []align(4096) u8,
    len: usize,

    const Self = @This();

    pub fn init(machine_code: []const u8) !Self {
        const page_size: usize = 4096;
        const aligned_len = ((machine_code.len + page_size - 1) / page_size) * page_size;

        // Allocate executable memory using mmap
        const result = std.os.linux.mmap(
            null,
            aligned_len,
            std.os.linux.PROT.READ | std.os.linux.PROT.WRITE | std.os.linux.PROT.EXEC,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );

        // Check for error (mmap returns -1 cast to usize on error)
        if (result > std.math.maxInt(usize) - 4096) {
            return error.MmapFailed;
        }

        const code: []align(4096) u8 = @alignCast(@as([*]align(4096) u8, @ptrFromInt(result))[0..aligned_len]);
        @memcpy(code[0..machine_code.len], machine_code);

        return Self{
            .code = code,
            .len = machine_code.len,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = std.os.linux.munmap(@ptrCast(self.code.ptr), self.code.len);
    }

    pub fn call(self: *Self) i64 {
        const func: *const fn () callconv(.C) i64 = @ptrCast(self.code.ptr);
        return func();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "X86_64Emitter mov imm64" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    try emitter.movImm64(.RAX, 42);
    try std.testing.expect(emitter.code.items.len > 0);
}

test "X86_64Emitter add" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    try emitter.addRegReg(.RAX, .RBX);
    try std.testing.expectEqual(@as(usize, 3), emitter.code.items.len);
}

test "NativeCompiler compile simple" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    try std.testing.expect(code.len > 0);
}

test "Execute native code: return 42" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 42
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 42), result);
}

test "Execute native code: 2 + 3 = 5" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 2 + 3
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 5), result);
}

test "Execute native code: 7 * 6 = 42" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 7 * 6
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 6 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 42), result);
}

test "Execute native code: 10 - 3 = 7" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 10 - 3
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .SUB_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 7), result);
}

test "Execute native code: 5 < 10 = 1" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 5 < 10
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .CMP_LT_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 1), result);
}

test "Benchmark: native code vs IR interpreter" {
    const allocator = std.testing.allocator;

    // Generate IR for: (2 + 3) * 7
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 3, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .MUL_INT, .dest = 4, .src1 = 2, .src2 = 3, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 4, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // Compile to native code
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();
    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    // Benchmark native code
    const iterations: usize = 10000;
    const native_start = std.time.nanoTimestamp();
    var native_result: i64 = 0;
    for (0..iterations) |_| {
        native_result = exec.call();
    }
    const native_end = std.time.nanoTimestamp();
    const native_time = native_end - native_start;

    // Verify result
    try std.testing.expectEqual(@as(i64, 35), native_result);

    // Print benchmark results (only in debug)
    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Native Code Benchmark ===\n", .{});
        std.debug.print("Iterations: {d}\n", .{iterations});
        std.debug.print("Native time: {d} ns ({d:.2} ns/iter)\n", .{
            native_time,
            @as(f64, @floatFromInt(native_time)) / @as(f64, @floatFromInt(iterations)),
        });
    }
}
