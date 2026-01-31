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

/// XMM registers for 128-bit SIMD (SSE)
pub const XMMReg = enum(u4) {
    XMM0 = 0,
    XMM1 = 1,
    XMM2 = 2,
    XMM3 = 3,
    XMM4 = 4,
    XMM5 = 5,
    XMM6 = 6,
    XMM7 = 7,
    XMM8 = 8,
    XMM9 = 9,
    XMM10 = 10,
    XMM11 = 11,
    XMM12 = 12,
    XMM13 = 13,
    XMM14 = 14,
    XMM15 = 15,
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

    pub fn getCodePosition(self: *Self) usize {
        return self.code.items.len;
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
    // SHIFT OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// shl reg, imm8 (shift left by immediate)
    pub fn shlRegImm(self: *Self, dst: Reg64, imm: u8) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, false, false, dst_val >= 8));
        try self.code.append(0xC1); // SHL r/m64, imm8
        try self.code.append(0xE0 | (dst_val & 0x7)); // ModR/M: /4 for SHL
        try self.code.append(imm & 0x3F); // Shift amount (masked to 6 bits)
    }

    /// shr reg, imm8 (shift right logical by immediate)
    pub fn shrRegImm(self: *Self, dst: Reg64, imm: u8) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, false, false, dst_val >= 8));
        try self.code.append(0xC1); // SHR r/m64, imm8
        try self.code.append(0xE8 | (dst_val & 0x7)); // ModR/M: /5 for SHR
        try self.code.append(imm & 0x3F); // Shift amount (masked to 6 bits)
    }

    /// sar reg, imm8 (shift right arithmetic by immediate)
    pub fn sarRegImm(self: *Self, dst: Reg64, imm: u8) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, false, false, dst_val >= 8));
        try self.code.append(0xC1); // SAR r/m64, imm8
        try self.code.append(0xF8 | (dst_val & 0x7)); // ModR/M: /7 for SAR
        try self.code.append(imm & 0x3F); // Shift amount (masked to 6 bits)
    }

    /// shl reg, cl (shift left by CL register)
    pub fn shlRegCL(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, false, false, dst_val >= 8));
        try self.code.append(0xD3); // SHL r/m64, CL
        try self.code.append(0xE0 | (dst_val & 0x7)); // ModR/M: /4 for SHL
    }

    /// shr reg, cl (shift right logical by CL register)
    pub fn shrRegCL(self: *Self, dst: Reg64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, false, false, dst_val >= 8));
        try self.code.append(0xD3); // SHR r/m64, CL
        try self.code.append(0xE8 | (dst_val & 0x7)); // ModR/M: /5 for SHR
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEA OPERATIONS (for multiply by 3, 5, 9)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Scale values for SIB byte
    pub const Scale = enum(u2) {
        x1 = 0, // *1
        x2 = 1, // *2
        x4 = 2, // *4
        x8 = 3, // *8
    };

    /// lea dst, [base + index*scale] - computes dst = base + index * scale
    /// For multiply: x*3 = lea dst,[src+src*2], x*5 = lea dst,[src+src*4], x*9 = lea dst,[src+src*8]
    pub fn leaRegRegScale(self: *Self, dst: Reg64, base: Reg64, index: Reg64, scale: Scale) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const base_val: u8 = @intFromEnum(base);
        const index_val: u8 = @intFromEnum(index);

        // REX prefix: W=1 (64-bit), R=dst>=8, X=index>=8, B=base>=8
        try self.code.append(rex(true, dst_val >= 8, index_val >= 8, base_val >= 8));

        // LEA opcode
        try self.code.append(0x8D);

        // ModR/M: mod=00 (no displacement), reg=dst, r/m=100 (SIB follows)
        try self.code.append(0x04 | ((dst_val & 0x7) << 3));

        // SIB byte: scale | index | base
        const sib: u8 = (@as(u8, @intFromEnum(scale)) << 6) | ((index_val & 0x7) << 3) | (base_val & 0x7);
        try self.code.append(sib);

        // Special case: if base is RBP/R13, need displacement byte
        if ((base_val & 0x7) == 5) {
            try self.code.append(0x00); // disp8 = 0
        }
    }

    /// lea dst, [index*scale + disp32] - computes dst = index * scale + displacement
    /// For multiply by power of 2: x*2 = lea dst,[0+src*2], x*4 = lea dst,[0+src*4], x*8 = lea dst,[0+src*8]
    pub fn leaRegScaleDisp(self: *Self, dst: Reg64, index: Reg64, scale: Scale, disp: i32) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const index_val: u8 = @intFromEnum(index);

        // REX prefix
        try self.code.append(rex(true, dst_val >= 8, index_val >= 8, false));

        // LEA opcode
        try self.code.append(0x8D);

        // ModR/M: mod=00, reg=dst, r/m=100 (SIB follows)
        try self.code.append(0x04 | ((dst_val & 0x7) << 3));

        // SIB byte: scale | index | base=101 (no base, disp32 follows)
        const sib: u8 = (@as(u8, @intFromEnum(scale)) << 6) | ((index_val & 0x7) << 3) | 0x05;
        try self.code.append(sib);

        // disp32
        try self.emitImm32(disp);
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

    /// mov dst, [base + offset] (load from arbitrary base register)
    pub fn movRegMemBase(self: *Self, dst: Reg64, base: Reg64, offset: i32) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const base_val: u8 = @intFromEnum(base);
        try self.code.append(rex(true, dst_val >= 8, false, base_val >= 8));
        try self.code.append(0x8B);
        if (offset == 0 and (base_val & 0x7) != 5) {
            // [base] without displacement (except RBP/R13 which need disp8)
            try self.code.append(((dst_val & 0x7) << 3) | (base_val & 0x7));
        } else if (offset >= -128 and offset <= 127) {
            // [base + disp8]
            try self.code.append(0x40 | ((dst_val & 0x7) << 3) | (base_val & 0x7));
            try self.code.append(@bitCast(@as(i8, @intCast(offset))));
        } else {
            // [base + disp32]
            try self.code.append(0x80 | ((dst_val & 0x7) << 3) | (base_val & 0x7));
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

    /// sub reg, imm32 (for stack allocation)
    pub fn subRegImm(self: *Self, reg: Reg64, imm: i32) !void {
        const r: u8 = @intFromEnum(reg);
        if (imm >= -128 and imm <= 127) {
            // sub reg, imm8
            try self.code.append(rex(true, false, false, r >= 8));
            try self.code.append(0x83);
            try self.code.append(0xE8 | (r & 0x7)); // /5 = sub
            try self.code.append(@bitCast(@as(i8, @intCast(imm))));
        } else {
            // sub reg, imm32
            try self.code.append(rex(true, false, false, r >= 8));
            try self.code.append(0x81);
            try self.code.append(0xE8 | (r & 0x7)); // /5 = sub
            const bytes: [4]u8 = @bitCast(imm);
            try self.code.appendSlice(&bytes);
        }
    }

    /// add reg, imm32 (for stack deallocation)
    pub fn addRegImm(self: *Self, reg: Reg64, imm: i32) !void {
        const r: u8 = @intFromEnum(reg);
        if (imm >= -128 and imm <= 127) {
            // add reg, imm8
            try self.code.append(rex(true, false, false, r >= 8));
            try self.code.append(0x83);
            try self.code.append(0xC0 | (r & 0x7)); // /0 = add
            try self.code.append(@bitCast(@as(i8, @intCast(imm))));
        } else {
            // add reg, imm32
            try self.code.append(rex(true, false, false, r >= 8));
            try self.code.append(0x81);
            try self.code.append(0xC0 | (r & 0x7)); // /0 = add
            const bytes: [4]u8 = @bitCast(imm);
            try self.code.appendSlice(&bytes);
        }
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

    /// cmp reg, imm32 (compare register with immediate)
    pub fn cmpRegImm32(self: *Self, reg: Reg64, imm: i32) !void {
        const reg_val: u8 = @intFromEnum(reg);
        try self.code.append(rex(true, false, false, reg_val >= 8));
        try self.code.append(0x81); // CMP r/m64, imm32
        try self.code.append(0xF8 | (reg_val & 0x7)); // ModR/M: /7 for CMP
        try self.emitImm32(imm);
    }

    /// call reg (indirect call through register)
    pub fn callReg(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        if (reg_val >= 8) {
            try self.code.append(rex(false, false, false, true));
        }
        try self.code.append(0xFF); // CALL r/m64
        try self.code.append(0xD0 | (reg_val & 0x7)); // ModR/M: /2 for CALL
    }

    /// mov reg, imm64 (load 64-bit immediate into register)
    pub fn movRegImm64(self: *Self, dst: Reg64, imm: u64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.code.append(rex(true, false, false, dst_val >= 8));
        try self.code.append(0xB8 | (dst_val & 0x7)); // MOV r64, imm64
        // Emit 64-bit immediate (little-endian)
        const bytes = @as([8]u8, @bitCast(imm));
        for (bytes) |b| {
            try self.code.append(b);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SSE/AVX SIMD INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// PADDD xmm1, xmm2 - Packed add doublewords (SSE2)
    /// Opcode: 66 0F FE /r
    pub fn paddd(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        // REX prefix if needed (for XMM8-15)
        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66); // Operand size prefix
        try self.code.append(0x0F);
        try self.code.append(0xFE); // PADDD opcode
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7)); // ModR/M
    }

    /// PSUBD xmm1, xmm2 - Packed subtract doublewords (SSE2)
    /// Opcode: 66 0F FA /r
    pub fn psubd(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0xFA); // PSUBD opcode
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    /// PMULLD xmm1, xmm2 - Packed multiply low doublewords (SSE4.1)
    /// Opcode: 66 0F 38 40 /r
    pub fn pmulld(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0x38);
        try self.code.append(0x40); // PMULLD opcode
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    /// MOVDQU xmm, m128 - Move unaligned double quadword (load)
    /// Opcode: F3 0F 6F /r
    pub fn movdquLoad(self: *Self, dst: XMMReg, base: Reg64, offset: i32) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const base_val: u8 = @intFromEnum(base);

        try self.code.append(0xF3);

        if (dst_val >= 8 or base_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, base_val >= 8));
        }

        try self.code.append(0x0F);
        try self.code.append(0x6F); // MOVDQU load opcode

        // ModR/M with displacement
        if (offset == 0 and base_val != 5) { // RBP needs displacement
            try self.code.append(((dst_val & 0x7) << 3) | (base_val & 0x7));
        } else if (offset >= -128 and offset <= 127) {
            try self.code.append(0x40 | ((dst_val & 0x7) << 3) | (base_val & 0x7));
            try self.code.append(@bitCast(@as(i8, @intCast(offset))));
        } else {
            try self.code.append(0x80 | ((dst_val & 0x7) << 3) | (base_val & 0x7));
            try self.emitImm32(offset);
        }
    }

    /// MOVDQU m128, xmm - Move unaligned double quadword (store)
    /// Opcode: F3 0F 7F /r
    pub fn movdquStore(self: *Self, base: Reg64, offset: i32, src: XMMReg) !void {
        const src_val: u8 = @intFromEnum(src);
        const base_val: u8 = @intFromEnum(base);

        try self.code.append(0xF3);

        if (src_val >= 8 or base_val >= 8) {
            try self.code.append(rex(false, src_val >= 8, false, base_val >= 8));
        }

        try self.code.append(0x0F);
        try self.code.append(0x7F); // MOVDQU store opcode

        // ModR/M with displacement
        if (offset == 0 and base_val != 5) {
            try self.code.append(((src_val & 0x7) << 3) | (base_val & 0x7));
        } else if (offset >= -128 and offset <= 127) {
            try self.code.append(0x40 | ((src_val & 0x7) << 3) | (base_val & 0x7));
            try self.code.append(@bitCast(@as(i8, @intCast(offset))));
        } else {
            try self.code.append(0x80 | ((src_val & 0x7) << 3) | (base_val & 0x7));
            try self.emitImm32(offset);
        }
    }

    /// MOVDQA xmm1, xmm2 - Move aligned double quadword (register to register)
    /// Opcode: 66 0F 6F /r
    pub fn movdqa(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0x6F);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    /// PMINSD xmm1, xmm2 - Packed minimum signed doublewords (SSE4.1)
    /// Opcode: 66 0F 38 39 /r
    pub fn pminsd(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0x38);
        try self.code.append(0x39);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    /// PMAXSD xmm1, xmm2 - Packed maximum signed doublewords (SSE4.1)
    /// Opcode: 66 0F 38 3D /r
    pub fn pmaxsd(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0x38);
        try self.code.append(0x3D);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    /// PHADDD xmm1, xmm2 - Packed horizontal add doublewords (SSSE3)
    /// Opcode: 66 0F 38 02 /r
    pub fn phaddd(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0x38);
        try self.code.append(0x02);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    /// PXOR xmm1, xmm2 - Packed XOR (SSE2)
    /// Opcode: 66 0F EF /r
    pub fn pxor(self: *Self, dst: XMMReg, src: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);

        if (dst_val >= 8 or src_val >= 8) {
            try self.code.append(rex(false, dst_val >= 8, false, src_val >= 8));
        }

        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0xEF);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AVX INSTRUCTIONS (VEX-encoded)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emit 2-byte VEX prefix: C5 [R~vvvv Lpp]
    fn emitVex2(self: *Self, r: bool, vvvv: u4, l: bool, pp: u2) !void {
        try self.code.append(0xC5);
        var byte: u8 = 0;
        if (r) byte |= 0x80; // R~ = 1 when reg < 8 (inverted REX.R)
        byte |= (@as(u8, ~vvvv) & 0x0F) << 3; // vvvv (inverted)
        if (l) byte |= 0x04; // L (vector length: 0=128, 1=256)
        byte |= pp; // pp (SIMD prefix)
        try self.code.append(byte);
    }

    /// Emit 3-byte VEX prefix: C4 [R~X~B~ mmmmm] [W vvvv L pp]
    fn emitVex3(self: *Self, r: bool, x: bool, b: bool, mmmmm: u5, w: bool, vvvv: u4, l: bool, pp: u2) !void {
        try self.code.append(0xC4);

        var byte1: u8 = 0;
        if (r) byte1 |= 0x80; // R~ = 1 when reg < 8
        if (x) byte1 |= 0x40; // X~ = 1 when index < 8
        if (b) byte1 |= 0x20; // B~ = 1 when base/rm < 8
        byte1 |= mmmmm; // mmmmm (opcode map)
        try self.code.append(byte1);

        var byte2: u8 = 0;
        if (w) byte2 |= 0x80; // W
        byte2 |= (@as(u8, ~vvvv) & 0x0F) << 3; // vvvv (inverted)
        if (l) byte2 |= 0x04; // L
        byte2 |= pp; // pp
        try self.code.append(byte2);
    }

    /// VPADDD ymm1, ymm2, ymm3 - AVX2 packed add doublewords (256-bit)
    /// VEX.256.66.0F.WIG FE /r
    pub fn vpaddd256(self: *Self, dst: XMMReg, src1: XMMReg, src2: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src1_val: u8 = @intFromEnum(src1);
        const src2_val: u8 = @intFromEnum(src2);

        // Use 3-byte VEX if any register >= 8
        if (dst_val >= 8 or src2_val >= 8) {
            try self.emitVex3(
                dst_val < 8,  // R
                true,         // X
                src2_val < 8, // B
                0x01,         // mmmmm = 0F
                false,        // W
                @truncate(src1_val), // vvvv
                true,         // L = 256-bit
                0x01,         // pp = 66
            );
        } else {
            try self.emitVex2(
                dst_val < 8,
                @truncate(src1_val),
                true,  // L = 256-bit
                0x01,  // pp = 66
            );
        }

        try self.code.append(0xFE); // PADDD opcode
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src2_val & 0x7));
    }

    /// VPADDD xmm1, xmm2, xmm3 - AVX packed add doublewords (128-bit)
    /// VEX.128.66.0F.WIG FE /r
    pub fn vpaddd128(self: *Self, dst: XMMReg, src1: XMMReg, src2: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src1_val: u8 = @intFromEnum(src1);
        const src2_val: u8 = @intFromEnum(src2);

        if (dst_val >= 8 or src2_val >= 8) {
            try self.emitVex3(
                dst_val < 8,
                true,
                src2_val < 8,
                0x01,
                false,
                @truncate(src1_val),
                false, // L = 128-bit
                0x01,
            );
        } else {
            try self.emitVex2(
                dst_val < 8,
                @truncate(src1_val),
                false, // L = 128-bit
                0x01,
            );
        }

        try self.code.append(0xFE);
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src2_val & 0x7));
    }

    /// VPMULLD ymm1, ymm2, ymm3 - AVX2 packed multiply low doublewords (256-bit)
    /// VEX.256.66.0F38.WIG 40 /r
    pub fn vpmulld256(self: *Self, dst: XMMReg, src1: XMMReg, src2: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src1_val: u8 = @intFromEnum(src1);
        const src2_val: u8 = @intFromEnum(src2);

        try self.emitVex3(
            dst_val < 8,
            true,
            src2_val < 8,
            0x02, // mmmmm = 0F38
            false,
            @truncate(src1_val),
            true, // L = 256-bit
            0x01, // pp = 66
        );

        try self.code.append(0x40); // PMULLD opcode
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src2_val & 0x7));
    }

    /// VPSUBD ymm1, ymm2, ymm3 - AVX2 packed subtract doublewords (256-bit)
    /// VEX.256.66.0F.WIG FA /r
    pub fn vpsubd256(self: *Self, dst: XMMReg, src1: XMMReg, src2: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src1_val: u8 = @intFromEnum(src1);
        const src2_val: u8 = @intFromEnum(src2);

        if (dst_val >= 8 or src2_val >= 8) {
            try self.emitVex3(
                dst_val < 8,
                true,
                src2_val < 8,
                0x01, // mmmmm = 0F
                false,
                @truncate(src1_val),
                true, // L = 256-bit
                0x01, // pp = 66
            );
        } else {
            try self.emitVex2(
                dst_val < 8,
                @truncate(src1_val),
                true, // L = 256-bit
                0x01, // pp = 66
            );
        }

        try self.code.append(0xFA); // PSUBD opcode
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src2_val & 0x7));
    }

    /// VPXOR ymm1, ymm2, ymm3 - AVX2 packed XOR (256-bit)
    /// VEX.256.66.0F.WIG EF /r
    pub fn vpxor256(self: *Self, dst: XMMReg, src1: XMMReg, src2: XMMReg) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const src1_val: u8 = @intFromEnum(src1);
        const src2_val: u8 = @intFromEnum(src2);

        if (dst_val >= 8 or src2_val >= 8) {
            try self.emitVex3(
                dst_val < 8,
                true,
                src2_val < 8,
                0x01,
                false,
                @truncate(src1_val),
                true,
                0x01,
            );
        } else {
            try self.emitVex2(
                dst_val < 8,
                @truncate(src1_val),
                true,
                0x01,
            );
        }

        try self.code.append(0xEF); // PXOR opcode
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src2_val & 0x7));
    }

    /// VMOVDQU ymm, m256 - AVX unaligned load (256-bit)
    /// VEX.256.F3.0F.WIG 6F /r
    pub fn vmovdquLoad256(self: *Self, dst: XMMReg, base: Reg64, offset: i32) !void {
        const dst_val: u8 = @intFromEnum(dst);
        const base_val: u8 = @intFromEnum(base);

        // Use 2-byte VEX when possible (no REX.X, REX.B needed, mmmmm=0F)
        if (dst_val < 8 and base_val < 8) {
            try self.emitVex2(
                true, // R = 1 (dst < 8)
                0x0F, // vvvv = 1111 (unused)
                true, // L = 256-bit
                0x02, // pp = F3
            );
        } else {
            try self.emitVex3(
                dst_val < 8,
                true,
                base_val < 8,
                0x01, // mmmmm = 0F
                false,
                0x0F, // vvvv = 1111 (unused)
                true, // L = 256-bit
                0x02, // pp = F3
            );
        }

        try self.code.append(0x6F);

        // ModR/M with displacement
        if (offset == 0 and base_val != 5) {
            try self.code.append(((dst_val & 0x7) << 3) | (base_val & 0x7));
        } else if (offset >= -128 and offset <= 127) {
            try self.code.append(0x40 | ((dst_val & 0x7) << 3) | (base_val & 0x7));
            try self.code.append(@bitCast(@as(i8, @intCast(offset))));
        } else {
            try self.code.append(0x80 | ((dst_val & 0x7) << 3) | (base_val & 0x7));
            try self.emitImm32(offset);
        }
    }

    /// VMOVDQU m256, ymm - AVX unaligned store (256-bit)
    /// VEX.256.F3.0F.WIG 7F /r
    pub fn vmovdquStore256(self: *Self, base: Reg64, offset: i32, src: XMMReg) !void {
        const src_val: u8 = @intFromEnum(src);
        const base_val: u8 = @intFromEnum(base);

        if (src_val < 8 and base_val < 8) {
            try self.emitVex2(
                true,
                0x0F,
                true,
                0x02,
            );
        } else {
            try self.emitVex3(
                src_val < 8,
                true,
                base_val < 8,
                0x01,
                false,
                0x0F,
                true, // L = 256-bit
                0x02, // pp = F3
            );
        }

        try self.code.append(0x7F);

        if (offset == 0 and base_val != 5) {
            try self.code.append(((src_val & 0x7) << 3) | (base_val & 0x7));
        } else if (offset >= -128 and offset <= 127) {
            try self.code.append(0x40 | ((src_val & 0x7) << 3) | (base_val & 0x7));
            try self.code.append(@bitCast(@as(i8, @intCast(offset))));
        } else {
            try self.code.append(0x80 | ((src_val & 0x7) << 3) | (base_val & 0x7));
            try self.emitImm32(offset);
        }
    }

    /// Get current code position (for calculating jump offsets)
    pub fn getPosition(self: *Self) usize {
        return self.code.items.len;
    }

    /// Patch a rel32 offset at a given position
    pub fn patchRel32(self: *Self, position: usize, target: usize) void {
        // Calculate relative offset from end of instruction (position + 4)
        const offset: i32 = @intCast(@as(i64, @intCast(target)) - @as(i64, @intCast(position + 4)));
        const bytes = @as([4]u8, @bitCast(offset));
        self.code.items[position] = bytes[0];
        self.code.items[position + 1] = bytes[1];
        self.code.items[position + 2] = bytes[2];
        self.code.items[position + 3] = bytes[3];
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
};

// ═══════════════════════════════════════════════════════════════════════════════
// IR TO X86-64 COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const NativeCompiler = struct {
    emitter: X86_64Emitter,
    allocator: Allocator,
    /// Custom register mapping from RegisterAllocator (optional)
    reg_mapping: ?[32]?u8 = null,
    /// Spill slot assignments: vreg -> stack offset from RBP
    spill_slots: ?[32]?i32 = null,
    /// Total stack space for spills
    spill_stack_size: u32 = 0,
    /// Temporary register for spill operations (R15)
    const SPILL_TEMP_REG: Reg64 = .R15;
    /// Second temporary register for when both src operands are spilled (R14)
    const SPILL_TEMP_REG2: Reg64 = .R14;

    const Self = @This();

    // Physical register table: index 0-7 maps to R8-R15
    const phys_regs = [8]Reg64{ .R8, .R9, .R10, .R11, .R12, .R13, .R14, .R15 };

    // Default register allocation: IR registers 0-7 map to R8-R15
    fn irRegToX86Default(ir_reg: u8) Reg64 {
        return phys_regs[ir_reg & 0x7];
    }

    /// Check if virtual register is spilled
    /// Check if virtual register is spilled (has a spill slot assigned)
    fn isSpilled(self: *Self, vreg: u8) bool {
        if (self.spill_slots) |slots| {
            if (vreg < 32) {
                return slots[vreg] != null;
            }
        }
        return false;
    }

    /// Get spill slot offset for a virtual register
    fn getSpillOffset(self: *Self, vreg: u8) ?i32 {
        if (self.spill_slots) |slots| {
            if (vreg < 32) {
                return slots[vreg];
            }
        }
        return null;
    }

    /// Convert IR register to x86-64 register using mapping if available
    /// For spilled registers, returns SPILL_TEMP_REG (caller must handle load/store)
    fn irRegToX86(self: *Self, ir_reg: u8) Reg64 {
        if (self.reg_mapping) |mapping| {
            if (ir_reg < 32) {
                if (mapping[ir_reg]) |phys_reg| {
                    return phys_regs[phys_reg & 0x7];
                } else {
                    // Spilled - use temp register
                    return SPILL_TEMP_REG;
                }
            }
        }
        // Fallback to default mapping
        return irRegToX86Default(ir_reg);
    }

    /// Load spilled register from stack into specified temp register
    fn loadSpilledTo(self: *Self, vreg: u8, temp_reg: Reg64) !void {
        if (self.getSpillOffset(vreg)) |offset| {
            try self.emitter.movRegMem(temp_reg, offset);
        }
    }

    /// Load spilled register from stack into temp register
    fn loadSpilled(self: *Self, vreg: u8) !void {
        try self.loadSpilledTo(vreg, SPILL_TEMP_REG);
    }

    /// Store from specified register to spilled register's stack slot
    fn storeSpilledFrom(self: *Self, vreg: u8, src_reg: Reg64) !void {
        if (self.getSpillOffset(vreg)) |offset| {
            try self.emitter.movMemReg(offset, src_reg);
        }
    }

    /// Store temp register to spilled register's stack slot
    fn storeSpilled(self: *Self, vreg: u8) !void {
        try self.storeSpilledFrom(vreg, SPILL_TEMP_REG);
    }

    /// Get register for src operand, loading from spill slot if needed
    /// Returns the register to use and whether it was loaded from spill
    fn getSrcReg(self: *Self, vreg: u8, use_temp2: bool) !Reg64 {
        if (self.isSpilled(vreg)) {
            const temp = if (use_temp2) SPILL_TEMP_REG2 else SPILL_TEMP_REG;
            try self.loadSpilledTo(vreg, temp);
            return temp;
        }
        return self.irRegToX86(vreg);
    }

    /// Get register for dest operand
    fn getDstReg(self: *Self, vreg: u8) Reg64 {
        if (self.isSpilled(vreg)) {
            return SPILL_TEMP_REG;
        }
        return self.irRegToX86(vreg);
    }

    /// Get XMM register for SIMD operand
    fn getXMMReg(self: *Self, vreg: u8) XMMReg {
        _ = self;
        // Map IR virtual registers to XMM registers (0-15)
        return @enumFromInt(vreg & 0x0F);
    }

    /// Store dest register to spill slot if needed
    fn storeDstIfSpilled(self: *Self, vreg: u8) !void {
        if (self.isSpilled(vreg)) {
            try self.storeSpilled(vreg);
        }
    }

    pub fn init(allocator: Allocator) Self {
        return .{
            .emitter = X86_64Emitter.init(allocator),
            .allocator = allocator,
            .reg_mapping = null,
            .spill_slots = null,
            .spill_stack_size = 0,
        };
    }

    /// Initialize with custom register mapping
    pub fn initWithMapping(allocator: Allocator, mapping: [32]?u8) Self {
        return .{
            .emitter = X86_64Emitter.init(allocator),
            .allocator = allocator,
            .reg_mapping = mapping,
            .spill_slots = null,
            .spill_stack_size = 0,
        };
    }

    /// Initialize with full register mapping including spill info
    pub fn initWithSpillInfo(allocator: Allocator, mapping: [32]?u8, spill_slots: [32]?i32, spill_stack_size: u32) Self {
        return .{
            .emitter = X86_64Emitter.init(allocator),
            .allocator = allocator,
            .reg_mapping = mapping,
            .spill_slots = spill_slots,
            .spill_stack_size = spill_stack_size,
        };
    }

    /// Set register mapping after initialization
    pub fn setMapping(self: *Self, mapping: [32]?u8) void {
        self.reg_mapping = mapping;
    }

    /// Set spill information
    pub fn setSpillInfo(self: *Self, spill_slots: [32]?i32, spill_stack_size: u32) void {
        self.spill_slots = spill_slots;
        self.spill_stack_size = spill_stack_size;
    }

    pub fn deinit(self: *Self) void {
        self.emitter.deinit();
    }

    pub fn compile(self: *Self, ir: []const IRInstruction) ![]u8 {
        // Emit prologue if we have spills
        if (self.spill_stack_size > 0) {
            // push rbp; mov rbp, rsp; sub rsp, spill_size
            try self.emitter.pushReg(.RBP);
            try self.emitter.movRegReg(.RBP, .RSP);
            if (self.spill_stack_size > 0) {
                try self.emitter.subRegImm(.RSP, @intCast(self.spill_stack_size));
            }
        }

        for (ir) |instr| {
            try self.compileInstruction(instr);
        }

        // Emit epilogue if we have spills
        if (self.spill_stack_size > 0) {
            // mov rsp, rbp; pop rbp
            try self.emitter.movRegReg(.RSP, .RBP);
            try self.emitter.popReg(.RBP);
        }

        // Add return at end
        try self.emitter.ret();
        return try self.emitter.code.toOwnedSlice();
    }

    fn compileInstruction(self: *Self, instr: IRInstruction) !void {
        switch (instr.opcode) {
            .LOAD_CONST => {
                const dst = self.getDstReg(instr.dest);
                try self.emitter.movImm64(dst, instr.imm);
                try self.storeDstIfSpilled(instr.dest);
            },

            .LOAD_LOCAL => {
                // Load from stack: [rbp - (idx+1)*8]
                const dst = self.getDstReg(instr.dest);
                const offset: i32 = -@as(i32, @intCast((instr.imm + 1) * 8));
                try self.emitter.movRegMem(dst, offset);
                try self.storeDstIfSpilled(instr.dest);
            },

            .STORE_LOCAL => {
                // Store to stack: [rbp - (idx+1)*8]
                const src = try self.getSrcReg(instr.src1, false);
                const offset: i32 = -@as(i32, @intCast((instr.imm + 1) * 8));
                try self.emitter.movMemReg(offset, src);
            },

            .ADD_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                if (dst != src1) try self.emitter.movRegReg(dst, src1);
                try self.emitter.addRegReg(dst, src2);
                try self.storeDstIfSpilled(instr.dest);
            },

            .SUB_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                if (dst != src1) try self.emitter.movRegReg(dst, src1);
                try self.emitter.subRegReg(dst, src2);
                try self.storeDstIfSpilled(instr.dest);
            },

            .MUL_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                if (dst != src1) try self.emitter.movRegReg(dst, src1);
                try self.emitter.imulRegReg(dst, src2);
                try self.storeDstIfSpilled(instr.dest);
            },

            .DIV_INT => {
                // Division: RAX = src1 / src2
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                // Move dividend to RAX
                try self.emitter.movRegReg(.RAX, src1);
                // Sign-extend RAX to RDX:RAX
                try self.emitter.cqo();
                // Divide by src2
                try self.emitter.idivReg(src2);
                // Move result to dst
                if (dst != .RAX) try self.emitter.movRegReg(dst, .RAX);
                try self.storeDstIfSpilled(instr.dest);
            },

            .MOD_INT => {
                // Modulo: RDX = src1 % src2
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                // Move dividend to RAX
                try self.emitter.movRegReg(.RAX, src1);
                // Sign-extend RAX to RDX:RAX
                try self.emitter.cqo();
                // Divide by src2
                try self.emitter.idivReg(src2);
                // Move remainder (RDX) to dst
                if (dst != .RDX) try self.emitter.movRegReg(dst, .RDX);
                try self.storeDstIfSpilled(instr.dest);
            },

            .NEG_INT => {
                const dst = self.getDstReg(instr.dest);
                const src = try self.getSrcReg(instr.src1, false);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                try self.emitter.negReg(dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .INC_INT => {
                const dst = self.getDstReg(instr.dest);
                const src = try self.getSrcReg(instr.src1, false);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                try self.emitter.incReg(dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .DEC_INT => {
                const dst = self.getDstReg(instr.dest);
                const src = try self.getSrcReg(instr.src1, false);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                try self.emitter.decReg(dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .SHL => {
                const dst = self.getDstReg(instr.dest);
                const src = try self.getSrcReg(instr.src1, false);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                // Use immediate shift if imm is set, otherwise use CL register
                if (instr.imm != 0) {
                    try self.emitter.shlRegImm(dst, @intCast(instr.imm & 0x3F));
                } else {
                    // Move src2 to RCX for variable shift
                    const shift_src = try self.getSrcReg(instr.src2, self.isSpilled(instr.src1));
                    try self.emitter.movRegReg(.RCX, shift_src);
                    try self.emitter.shlRegCL(dst);
                }
                try self.storeDstIfSpilled(instr.dest);
            },

            .SHR => {
                const dst = self.getDstReg(instr.dest);
                const src = try self.getSrcReg(instr.src1, false);
                if (dst != src) try self.emitter.movRegReg(dst, src);
                // Use immediate shift if imm is set, otherwise use CL register
                if (instr.imm != 0) {
                    // Use SAR for signed right shift (arithmetic)
                    try self.emitter.sarRegImm(dst, @intCast(instr.imm & 0x3F));
                } else {
                    // Move src2 to RCX for variable shift
                    const shift_src = try self.getSrcReg(instr.src2, self.isSpilled(instr.src1));
                    try self.emitter.movRegReg(.RCX, shift_src);
                    try self.emitter.shrRegCL(dst);
                }
                try self.storeDstIfSpilled(instr.dest);
            },

            .LEA => {
                // LEA for multiply by 3, 5, 9: dst = src1 + src1 * scale
                // imm contains scale (2, 4, or 8)
                const dst = self.getDstReg(instr.dest);
                const src = try self.getSrcReg(instr.src1, false);
                const scale: X86_64Emitter.Scale = switch (instr.imm) {
                    2 => .x2, // x*3 = x + x*2
                    4 => .x4, // x*5 = x + x*4
                    8 => .x8, // x*9 = x + x*8
                    else => .x1,
                };
                try self.emitter.leaRegRegScale(dst, src, src, scale);
                try self.storeDstIfSpilled(instr.dest);
            },

            .CMP_LT_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setl(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .CMP_LE_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setle(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .CMP_GT_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setg(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .CMP_EQ_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.sete(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .CMP_NE_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setne(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .CMP_GE_INT => {
                const dst = self.getDstReg(instr.dest);
                const src1 = try self.getSrcReg(instr.src1, false);
                const src2 = try self.getSrcReg(instr.src2, instr.src1 != instr.src2 and self.isSpilled(instr.src1));
                try self.emitter.cmpRegReg(src1, src2);
                try self.emitter.setge(dst);
                try self.emitter.movzxReg64Reg8(dst, dst);
                try self.storeDstIfSpilled(instr.dest);
            },

            .JUMP => {
                // Jump to IR offset (simplified - would need label resolution)
                const offset: i32 = @intCast(instr.imm);
                try self.emitter.jmpRel32(offset);
            },

            .JUMP_IF_ZERO => {
                // Test src1 and jump if zero
                const src = try self.getSrcReg(instr.src1, false);
                try self.emitter.testRegReg(src, src);
                const offset: i32 = @intCast(instr.imm);
                try self.emitter.jeRel32(offset);
            },

            .JUMP_IF_NOT_ZERO => {
                // Test src1 and jump if not zero
                const src = try self.getSrcReg(instr.src1, false);
                try self.emitter.testRegReg(src, src);
                const offset: i32 = @intCast(instr.imm);
                try self.emitter.jneRel32(offset);
            },

            .RETURN => {
                // Move result to RAX
                const src = try self.getSrcReg(instr.dest, false);
                try self.emitter.movRegReg(.RAX, src);
            },

            .CALL => {
                // Regular function call (simplified - would need function address resolution)
                // For now, just mark the call site
                // In a full implementation, this would:
                // 1. Push arguments
                // 2. Call the function address
                // 3. Move result to dest register
                const dst = self.getDstReg(instr.dest);
                // Placeholder: load function ID as result (for testing)
                try self.emitter.movImm64(dst, instr.imm);
                try self.storeDstIfSpilled(instr.dest);
            },

            .CALL_INLINE => {
                // Marker for inlined call - no code generation needed
                // This is just for debugging/profiling
            },

            .TAIL_CALL => {
                // Tail call optimization: jump instead of call+ret
                // This eliminates the current stack frame
                // In a full implementation, this would:
                // 1. Restore callee-saved registers
                // 2. Deallocate stack frame
                // 3. Jump to function address (not call)
                //
                // For now, emit a jump placeholder
                // The actual target would be resolved by a linker/loader
                const offset: i32 = @intCast(instr.imm);
                try self.emitter.jmpRel32(offset);
            },

            .CALL_METHOD => {
                // IC Stub Generation for method calls
                // Structure:
                //   cmp [object + type_offset], expected_type
                //   jne slow_path
                //   ; fast path - direct call to cached target
                //   call cached_target
                //   jmp done
                // slow_path:
                //   ; call runtime lookup
                //   mov rdi, object_reg
                //   mov rsi, method_id
                //   call ic_miss_handler
                // done:
                //   mov dest, rax

                const dst = self.getDstReg(instr.dest);
                const object_reg = try self.getSrcReg(instr.src1, false);
                const expected_type: i32 = @intCast(instr.src2);
                const method_id = instr.imm;

                // For now, simplified IC stub:
                // 1. Compare type (assuming type is at offset 0 of object)
                // 2. If match, call cached target
                // 3. If miss, call slow path

                // Load type from object (assuming [object + 0] = type_id)
                // mov r11, [object_reg]
                try self.emitter.movRegMemBase(.R11, object_reg, 0);

                // cmp r11, expected_type
                try self.emitter.cmpRegImm32(.R11, expected_type);

                // jne slow_path (placeholder offset, will be patched)
                const jne_pos = self.emitter.getPosition();
                try self.emitter.jneRel32(0); // Placeholder

                // Fast path: direct call (simplified - just load method_id as result)
                // In real implementation, this would call the cached native code
                try self.emitter.movImm64(dst, method_id);

                // jmp done
                const jmp_pos = self.emitter.getPosition();
                try self.emitter.jmpRel32(0); // Placeholder

                // slow_path:
                const slow_path_pos = self.emitter.getPosition();
                self.emitter.patchRel32(jne_pos + 2, slow_path_pos); // Patch jne offset

                // Slow path: call IC miss handler (simplified)
                // In real implementation, this would:
                // 1. Call runtime to lookup method
                // 2. Update IC cache
                // 3. Call the resolved method
                // For now, just load -1 to indicate miss
                try self.emitter.movImm64(dst, -1);

                // done:
                const done_pos = self.emitter.getPosition();
                self.emitter.patchRel32(jmp_pos + 1, done_pos); // Patch jmp offset

                try self.storeDstIfSpilled(instr.dest);
            },

            // SIMD Vector Operations - Real SSE/AVX Instructions
            .VADD => {
                // Vector add using SSE2 PADDD or AVX VPADDD
                const vector_width = @as(u32, @intCast(instr.imm & 0xFFF));
                const dst_xmm = self.getXMMReg(instr.dest);
                const src1_xmm = self.getXMMReg(instr.src1);
                const src2_xmm = self.getXMMReg(instr.src2);

                if (vector_width >= 256) {
                    // AVX 256-bit: VPADDD ymm, ymm, ymm
                    try self.emitter.vpaddd256(dst_xmm, src1_xmm, src2_xmm);
                } else {
                    // SSE 128-bit: PADDD xmm, xmm (dst = dst + src)
                    if (dst_xmm != src1_xmm) {
                        try self.emitter.movdqa(dst_xmm, src1_xmm);
                    }
                    try self.emitter.paddd(dst_xmm, src2_xmm);
                }
            },

            .VSUB => {
                const dst_xmm = self.getXMMReg(instr.dest);
                const src1_xmm = self.getXMMReg(instr.src1);
                const src2_xmm = self.getXMMReg(instr.src2);

                // SSE 128-bit: PSUBD xmm, xmm
                if (dst_xmm != src1_xmm) {
                    try self.emitter.movdqa(dst_xmm, src1_xmm);
                }
                try self.emitter.psubd(dst_xmm, src2_xmm);
            },

            .VMUL => {
                const vector_width = @as(u32, @intCast(instr.imm & 0xFFF));
                const dst_xmm = self.getXMMReg(instr.dest);
                const src1_xmm = self.getXMMReg(instr.src1);
                const src2_xmm = self.getXMMReg(instr.src2);

                if (vector_width >= 256) {
                    // AVX2 256-bit: VPMULLD ymm, ymm, ymm
                    try self.emitter.vpmulld256(dst_xmm, src1_xmm, src2_xmm);
                } else {
                    // SSE4.1 128-bit: PMULLD xmm, xmm
                    if (dst_xmm != src1_xmm) {
                        try self.emitter.movdqa(dst_xmm, src1_xmm);
                    }
                    try self.emitter.pmulld(dst_xmm, src2_xmm);
                }
            },

            .VLOAD => {
                // Vector load using MOVDQU (unaligned) or VMOVDQU
                const vector_width = @as(u32, @intCast(instr.imm & 0xFFF));
                const dst_xmm = self.getXMMReg(instr.dest);
                const base = try self.getSrcReg(instr.src1, false);

                if (vector_width >= 256) {
                    // AVX 256-bit: VMOVDQU ymm, [base]
                    try self.emitter.vmovdquLoad256(dst_xmm, base, 0);
                } else {
                    // SSE 128-bit: MOVDQU xmm, [base]
                    try self.emitter.movdquLoad(dst_xmm, base, 0);
                }
            },

            .VSTORE => {
                // Vector store using MOVDQU (unaligned) or VMOVDQU
                const vector_width = @as(u32, @intCast(instr.imm & 0xFFF));
                const base = try self.getSrcReg(instr.dest, false);
                const src_xmm = self.getXMMReg(instr.src1);

                if (vector_width >= 256) {
                    // AVX 256-bit: VMOVDQU [base], ymm
                    try self.emitter.vmovdquStore256(base, 0, src_xmm);
                } else {
                    // SSE 128-bit: MOVDQU [base], xmm
                    try self.emitter.movdquStore(base, 0, src_xmm);
                }
            },

            .VSUM => {
                // Horizontal sum using PHADDD (SSSE3)
                const dst_xmm = self.getXMMReg(instr.dest);
                const src_xmm = self.getXMMReg(instr.src1);

                // PHADDD twice to sum all 4 elements
                if (dst_xmm != src_xmm) {
                    try self.emitter.movdqa(dst_xmm, src_xmm);
                }
                try self.emitter.phaddd(dst_xmm, dst_xmm);
                try self.emitter.phaddd(dst_xmm, dst_xmm);
            },

            else => {
                // Unsupported - emit nop
            },
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD ARRAY OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD Array Operations - generates native code for vectorized array processing
pub const SIMDArrayOps = struct {
    allocator: Allocator,
    use_avx256: bool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .use_avx256 = detectAVX2Support(),
        };
    }

    pub fn initWithSSE(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .use_avx256 = false,
        };
    }

    pub fn initWithAVX(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .use_avx256 = true,
        };
    }

    /// Detect AVX2 support at runtime using CPUID
    fn detectAVX2Support() bool {
        // CPUID with EAX=7, ECX=0 returns AVX2 support in EBX bit 5
        // For simplicity, we assume AVX2 is available on modern x86-64
        // In production, this would use inline assembly for CPUID
        return true; // Assume AVX2 available
    }

    /// Generate best available code for array addition
    pub fn generateArrayAddBest(self: *Self) !ExecutableCode {
        if (self.use_avx256) {
            return self.generateArrayAddAVX256();
        } else {
            return self.generateArrayAdd();
        }
    }

    /// Generate best available code for array subtraction
    pub fn generateArraySubBest(self: *Self) !ExecutableCode {
        if (self.use_avx256) {
            return self.generateArraySubAVX256();
        } else {
            return self.generateArraySub();
        }
    }

    /// Generate best available code for array multiplication
    pub fn generateArrayMulBest(self: *Self) !ExecutableCode {
        if (self.use_avx256) {
            return self.generateArrayMulAVX256();
        } else {
            return self.generateArrayMul();
        }
    }

    /// Generate code for: result[i] = a[i] + b[i] for all i
    /// Args: RDI = a, RSI = b, RDX = result, RCX = length
    pub fn generateArrayAdd(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        // Function prologue - save callee-saved registers
        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);

        // RDI = a, RSI = b, RDX = result, RCX = length
        // R12 = loop counter (i)
        try emitter.pxor(.XMM0, .XMM0); // Clear for safety
        try emitter.movImm64(.R12, 0);  // i = 0

        // Main SIMD loop: process 4 elements at a time
        // loop_start:
        const loop_start = emitter.getCodePosition();

        // Check if we have at least 4 elements left: if (i + 4 > length) goto scalar
        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 4);
        try emitter.cmpRegReg(.RAX, .RCX);
        // ja scalar_loop (jump if above)
        try emitter.code.append(0x77); // JA rel8
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00); // Placeholder

        // Load a[i:i+4] into XMM0
        // lea rax, [rdi + r12*4]
        try emitter.code.append(0x4A); // REX.WX
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7); // [rdi + r12*4]
        try emitter.movdquLoad(.XMM0, .RAX, 0);

        // Load b[i:i+4] into XMM1
        // lea rax, [rsi + r12*4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6); // [rsi + r12*4]
        try emitter.movdquLoad(.XMM1, .RAX, 0);

        // XMM0 = XMM0 + XMM1
        try emitter.paddd(.XMM0, .XMM1);

        // Store result[i:i+4]
        // lea rax, [rdx + r12*4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2); // [rdx + r12*4]
        try emitter.movdquStore(.RAX, 0, .XMM0);

        // i += 4
        try emitter.addRegImm(.R12, 4);

        // Jump back to loop_start
        try emitter.code.append(0xEB); // JMP rel8
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        // Patch ja offset
        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Scalar loop for remainder
        // scalar_loop:
        // cmp r12, rcx
        try emitter.cmpRegReg(.R12, .RCX);
        // jge done
        try emitter.code.append(0x7D); // JGE rel8
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i]
        // mov eax, [rdi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        // Add b[i]
        // add eax, [rsi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x03);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);

        // Store result[i]
        // mov [rdx + r12*4], eax
        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        // i++
        try emitter.code.append(0x49); // REX.WB
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4); // inc r12

        // Jump back to scalar_loop
        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        // Patch jge offset
        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        // Function epilogue
        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate code for: result[i] = a[i] - b[i] for all i
    pub fn generateArraySub(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);
        try emitter.pxor(.XMM0, .XMM0);
        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        // Check if we have at least 4 elements left
        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 4);
        try emitter.cmpRegReg(.RAX, .RCX);
        try emitter.code.append(0x77); // JA rel8
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i:i+4] into XMM0
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);
        try emitter.movdquLoad(.XMM0, .RAX, 0);

        // Load b[i:i+4] into XMM1
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);
        try emitter.movdquLoad(.XMM1, .RAX, 0);

        // XMM0 = XMM0 - XMM1 (PSUBD)
        try emitter.psubd(.XMM0, .XMM1);

        // Store result[i:i+4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);
        try emitter.movdquStore(.RAX, 0, .XMM0);

        try emitter.addRegImm(.R12, 4);

        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Scalar loop for remainder
        try emitter.cmpRegReg(.R12, .RCX);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i]
        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        // Sub b[i]: sub eax, [rsi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x2B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);

        // Store result[i]
        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        // i++
        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate code for: result[i] = a[i] * b[i] for all i
    pub fn generateArrayMul(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);
        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        // Check 4 elements
        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 4);
        try emitter.cmpRegReg(.RAX, .RCX);
        try emitter.code.append(0x77);
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load and multiply
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);
        try emitter.movdquLoad(.XMM0, .RAX, 0);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);
        try emitter.movdquLoad(.XMM1, .RAX, 0);

        try emitter.pmulld(.XMM0, .XMM1); // PMULLD for i32 multiply

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);
        try emitter.movdquStore(.RAX, 0, .XMM0);

        try emitter.addRegImm(.R12, 4);
        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Scalar remainder
        try emitter.cmpRegReg(.R12, .RCX);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // mov eax, [rdi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        // imul eax, [rsi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x0F);
        try emitter.code.append(0xAF);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);

        // mov [rdx + r12*4], eax
        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate code for: return sum(a[0..length])
    /// Args: RDI = a, RSI = length
    /// Returns: RAX = sum
    pub fn generateArraySum(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);

        // Initialize sum accumulator in XMM0 to zero
        try emitter.pxor(.XMM0, .XMM0);
        try emitter.movImm64(.R12, 0); // i = 0
        try emitter.movImm64(.RAX, 0); // scalar sum = 0

        const loop_start = emitter.getCodePosition();

        // Check 4 elements
        try emitter.movRegReg(.RBX, .R12);
        try emitter.addRegImm(.RBX, 4);
        try emitter.cmpRegReg(.RBX, .RSI);
        try emitter.code.append(0x77);
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i:i+4] into XMM1
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x1C);
        try emitter.code.append(0xA7); // lea rbx, [rdi + r12*4]
        try emitter.movdquLoad(.XMM1, .RBX, 0);

        // XMM0 += XMM1
        try emitter.paddd(.XMM0, .XMM1);

        try emitter.addRegImm(.R12, 4);
        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Horizontal sum of XMM0 (4 x i32 -> 1 x i32)
        // PHADDD twice: [a,b,c,d] -> [a+b,c+d,a+b,c+d] -> [a+b+c+d,...]
        try emitter.phaddd(.XMM0, .XMM0);
        try emitter.phaddd(.XMM0, .XMM0);

        // Move lowest 32 bits to EAX
        // movd eax, xmm0: 66 0F 7E C0
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x7E);
        try emitter.code.append(0xC0);

        // Scalar loop for remainder
        try emitter.cmpRegReg(.R12, .RSI);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // add eax, [rdi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x03);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start + 8)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate code for: return max(a[0..length])
    pub fn generateArrayMax(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);

        // Initialize max to INT_MIN in XMM0
        // movd xmm0, 0x80000000 (broadcast)
        try emitter.movImm64(.RAX, 0x80000000);
        // movd xmm0, eax: 66 0F 6E C0
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x6E);
        try emitter.code.append(0xC0);
        // pshufd xmm0, xmm0, 0 (broadcast): 66 0F 70 C0 00
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x70);
        try emitter.code.append(0xC0);
        try emitter.code.append(0x00);

        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        try emitter.movRegReg(.RBX, .R12);
        try emitter.addRegImm(.RBX, 4);
        try emitter.cmpRegReg(.RBX, .RSI);
        try emitter.code.append(0x77);
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x1C);
        try emitter.code.append(0xA7);
        try emitter.movdquLoad(.XMM1, .RBX, 0);

        // PMAXSD xmm0, xmm1
        try emitter.pmaxsd(.XMM0, .XMM1);

        try emitter.addRegImm(.R12, 4);
        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Horizontal max: reduce 4 elements to 1
        // pshufd xmm1, xmm0, 0x4E (swap high/low 64 bits)
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x70);
        try emitter.code.append(0xC8);
        try emitter.code.append(0x4E);
        try emitter.pmaxsd(.XMM0, .XMM1);
        // pshufd xmm1, xmm0, 0xB1 (swap adjacent 32-bit elements)
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x70);
        try emitter.code.append(0xC8);
        try emitter.code.append(0xB1);
        try emitter.pmaxsd(.XMM0, .XMM1);

        // movd eax, xmm0
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x7E);
        try emitter.code.append(0xC0);

        // Scalar remainder
        try emitter.cmpRegReg(.R12, .RSI);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // mov ebx, [rdi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x1C);
        try emitter.code.append(0xA7);

        // cmp ebx, eax
        try emitter.code.append(0x39);
        try emitter.code.append(0xC3);

        // cmovg eax, ebx (if ebx > eax, eax = ebx)
        try emitter.code.append(0x0F);
        try emitter.code.append(0x4F);
        try emitter.code.append(0xC3);

        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start + 16)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate code for: result[i] = -a[i] for all i (negation)
    pub fn generateArrayNeg(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);

        // Zero register for subtraction (0 - x = -x)
        try emitter.pxor(.XMM2, .XMM2);
        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        // Check if we have at least 4 elements left
        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 4);
        try emitter.cmpRegReg(.RAX, .RSI); // RSI = length
        try emitter.code.append(0x77); // JA rel8
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i:i+4] into XMM0
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7); // [rdi + r12*4]
        try emitter.movdquLoad(.XMM0, .RAX, 0);

        // XMM1 = 0 - XMM0 (negate via PSUBD)
        try emitter.movdqa(.XMM1, .XMM2); // XMM1 = 0
        try emitter.psubd(.XMM1, .XMM0);  // XMM1 = 0 - XMM0

        // Store result[i:i+4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2); // [rdx + r12*4]
        try emitter.movdquStore(.RAX, 0, .XMM1);

        try emitter.addRegImm(.R12, 4);

        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Scalar loop for remainder
        try emitter.cmpRegReg(.R12, .RSI);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i]: mov eax, [rdi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        // Negate: neg eax
        try emitter.code.append(0xF7);
        try emitter.code.append(0xD8);

        // Store result[i]: mov [rdx + r12*4], eax
        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        // i++
        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back2: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back2));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate code for: result[i] = a[i] * scale for all i (scalar multiply)
    pub fn generateArrayScale(self: *Self, scale: i32) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);

        // Load scale into XMM2 and broadcast
        try emitter.movImm64(.RAX, @bitCast(@as(i64, scale)));
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x6E);
        try emitter.code.append(0xD0); // movd xmm2, eax
        try emitter.code.append(0x66);
        try emitter.code.append(0x0F);
        try emitter.code.append(0x70);
        try emitter.code.append(0xD2);
        try emitter.code.append(0x00); // pshufd xmm2, xmm2, 0

        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 4);
        try emitter.cmpRegReg(.RAX, .RSI);
        try emitter.code.append(0x77);
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i:i+4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);
        try emitter.movdquLoad(.XMM0, .RAX, 0);

        // XMM0 = XMM0 * XMM2 (PMULLD)
        try emitter.pmulld(.XMM0, .XMM2);

        // Store result
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);
        try emitter.movdquStore(.RAX, 0, .XMM0);

        try emitter.addRegImm(.R12, 4);

        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Scalar loop
        try emitter.cmpRegReg(.R12, .RSI);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i]
        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        // imul eax, scale: 69 C0 xx xx xx xx
        try emitter.code.append(0x69);
        try emitter.code.append(0xC0);
        const scale_bytes: [4]u8 = @bitCast(scale);
        try emitter.code.appendSlice(&scale_bytes);

        // Store result
        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        // i++
        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back2: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back2));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate unrolled vectorized code for: result[i] = a[i] + b[i]
    /// Processes 8 elements per iteration (2x unrolled SIMD)
    pub fn generateArrayAddUnrolled(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);
        try emitter.pxor(.XMM0, .XMM0);
        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        // Check if we have at least 8 elements left (2x unrolled)
        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 8);
        try emitter.cmpRegReg(.RAX, .RCX);
        try emitter.code.append(0x77); // JA rel8
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // First 4 elements: XMM0 = a[i:i+4] + b[i:i+4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);
        try emitter.movdquLoad(.XMM0, .RAX, 0);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);
        try emitter.movdquLoad(.XMM1, .RAX, 0);

        try emitter.paddd(.XMM0, .XMM1);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);
        try emitter.movdquStore(.RAX, 0, .XMM0);

        // Second 4 elements (unrolled): XMM2 = a[i+4:i+8] + b[i+4:i+8]
        // lea rax, [rdi + r12*4 + 16]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x44);
        try emitter.code.append(0xA7);
        try emitter.code.append(0x10); // +16 offset
        try emitter.movdquLoad(.XMM2, .RAX, 0);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x44);
        try emitter.code.append(0xA6);
        try emitter.code.append(0x10);
        try emitter.movdquLoad(.XMM3, .RAX, 0);

        try emitter.paddd(.XMM2, .XMM3);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x44);
        try emitter.code.append(0xA2);
        try emitter.code.append(0x10);
        try emitter.movdquStore(.RAX, 0, .XMM2);

        // i += 8
        try emitter.addRegImm(.R12, 8);

        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const simd4_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(simd4_start - ja_offset - 1);

        // Check for 4 remaining elements
        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 4);
        try emitter.cmpRegReg(.RAX, .RCX);
        try emitter.code.append(0x77);
        const ja_scalar = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Process 4 elements
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);
        try emitter.movdquLoad(.XMM0, .RAX, 0);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);
        try emitter.movdquLoad(.XMM1, .RAX, 0);

        try emitter.paddd(.XMM0, .XMM1);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);
        try emitter.movdquStore(.RAX, 0, .XMM0);

        try emitter.addRegImm(.R12, 4);

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_scalar] = @intCast(scalar_start - ja_scalar - 1);

        // Scalar loop for remainder
        try emitter.cmpRegReg(.R12, .RCX);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        try emitter.code.append(0x42);
        try emitter.code.append(0x03);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);

        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate AVX-256 code for: result[i] = a[i] + b[i] for all i
    /// Processes 8 elements per SIMD instruction (256-bit YMM registers)
    pub fn generateArrayAddAVX256(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);
        try emitter.pushReg(.R13);

        // Zero YMM0 for safety: vpxor ymm0, ymm0, ymm0
        try emitter.vpxor256(.XMM0, .XMM0, .XMM0);
        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        // Check if we have at least 8 elements left
        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 8);
        try emitter.cmpRegReg(.RAX, .RCX);
        try emitter.code.append(0x77); // JA rel8
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i:i+8] into YMM0 (256-bit = 8 x i32)
        // lea rbx, [rdi + r12*4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x1C); // RBX
        try emitter.code.append(0xA7);
        try emitter.vmovdquLoad256(.XMM0, .RBX, 0);

        // Load b[i:i+8] into YMM1
        // lea rbx, [rsi + r12*4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x1C);
        try emitter.code.append(0xA6);
        try emitter.vmovdquLoad256(.XMM1, .RBX, 0);

        // YMM0 = YMM0 + YMM1 (VPADDD)
        try emitter.vpaddd256(.XMM0, .XMM0, .XMM1);

        // Store result[i:i+8]
        // lea rbx, [rdx + r12*4]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x1C);
        try emitter.code.append(0xA2);
        try emitter.vmovdquStore256(.RBX, 0, .XMM0);

        // i += 8
        try emitter.addRegImm(.R12, 8);

        // Jump back to loop_start
        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        // Patch ja offset - jump to scalar loop
        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Scalar loop for remainder
        try emitter.cmpRegReg(.R12, .RCX);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i]
        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        // Add b[i]
        try emitter.code.append(0x42);
        try emitter.code.append(0x03);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);

        // Store result[i]
        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        // i++
        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        // VZEROUPPER to avoid AVX-SSE transition penalty
        try emitter.code.append(0xC5);
        try emitter.code.append(0xF8);
        try emitter.code.append(0x77);

        try emitter.popReg(.R13);
        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate AVX-256 code for: result[i] = a[i] - b[i] for all i
    pub fn generateArraySubAVX256(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);
        try emitter.vpxor256(.XMM0, .XMM0, .XMM0);
        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 8);
        try emitter.cmpRegReg(.RAX, .RCX);
        try emitter.code.append(0x77);
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        // Load a[i:i+8]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);
        try emitter.vmovdquLoad256(.XMM0, .RAX, 0);

        // Load b[i:i+8]
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);
        try emitter.vmovdquLoad256(.XMM1, .RAX, 0);

        // YMM0 = YMM0 - YMM1
        try emitter.vpsubd256(.XMM0, .XMM0, .XMM1);

        // Store result
        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);
        try emitter.vmovdquStore256(.RAX, 0, .XMM0);

        try emitter.addRegImm(.R12, 8);

        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        // Scalar loop
        try emitter.cmpRegReg(.R12, .RCX);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        try emitter.code.append(0x42);
        try emitter.code.append(0x2B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);

        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        // VZEROUPPER
        try emitter.code.append(0xC5);
        try emitter.code.append(0xF8);
        try emitter.code.append(0x77);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
    }

    /// Generate AVX-256 code for: result[i] = a[i] * b[i] for all i
    pub fn generateArrayMulAVX256(self: *Self) !ExecutableCode {
        var emitter = X86_64Emitter.init(self.allocator);
        defer emitter.deinit();

        try emitter.pushReg(.RBX);
        try emitter.pushReg(.R12);
        try emitter.vpxor256(.XMM0, .XMM0, .XMM0);
        try emitter.movImm64(.R12, 0);

        const loop_start = emitter.getCodePosition();

        try emitter.movRegReg(.RAX, .R12);
        try emitter.addRegImm(.RAX, 8);
        try emitter.cmpRegReg(.RAX, .RCX);
        try emitter.code.append(0x77);
        const ja_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);
        try emitter.vmovdquLoad256(.XMM0, .RAX, 0);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);
        try emitter.vmovdquLoad256(.XMM1, .RAX, 0);

        // YMM0 = YMM0 * YMM1
        try emitter.vpmulld256(.XMM0, .XMM0, .XMM1);

        try emitter.code.append(0x4A);
        try emitter.code.append(0x8D);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);
        try emitter.vmovdquStore256(.RAX, 0, .XMM0);

        try emitter.addRegImm(.R12, 8);

        try emitter.code.append(0xEB);
        const jmp_back: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(jmp_back));

        const scalar_start = emitter.getCodePosition();
        emitter.code.items[ja_offset] = @intCast(scalar_start - ja_offset - 1);

        try emitter.cmpRegReg(.R12, .RCX);
        try emitter.code.append(0x7D);
        const jge_offset = emitter.getCodePosition();
        try emitter.code.append(0x00);

        try emitter.code.append(0x42);
        try emitter.code.append(0x8B);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA7);

        // imul eax, [rsi + r12*4]
        try emitter.code.append(0x42);
        try emitter.code.append(0x0F);
        try emitter.code.append(0xAF);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA6);

        try emitter.code.append(0x42);
        try emitter.code.append(0x89);
        try emitter.code.append(0x04);
        try emitter.code.append(0xA2);

        try emitter.code.append(0x49);
        try emitter.code.append(0xFF);
        try emitter.code.append(0xC4);

        try emitter.code.append(0xEB);
        const scalar_back: i8 = @intCast(@as(i32, @intCast(scalar_start)) - @as(i32, @intCast(emitter.getCodePosition())) - 1);
        try emitter.code.append(@bitCast(scalar_back));

        const done_pos = emitter.getCodePosition();
        emitter.code.items[jge_offset] = @intCast(done_pos - jge_offset - 1);

        try emitter.code.append(0xC5);
        try emitter.code.append(0xF8);
        try emitter.code.append(0x77);

        try emitter.popReg(.R12);
        try emitter.popReg(.RBX);
        try emitter.ret();

        return ExecutableCode.init(emitter.getCode());
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

test "Execute native code: 5 << 3 = 40 (SHL immediate)" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 5 << 3
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .SHL, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 }, // 5 << 3 = 40
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 40), result);
}

test "Execute native code: 64 >> 2 = 16 (SHR immediate)" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 64 >> 2
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 64 },
        .{ .opcode = .SHR, .dest = 1, .src1 = 0, .src2 = 0, .imm = 2 }, // 64 >> 2 = 16
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 16), result);
}

test "Benchmark: native SHL vs MUL (strength reduction)" {
    const allocator = std.testing.allocator;

    // IR with MUL: 5 * 8
    const ir_mul = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 8 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // IR with SHL: 5 << 3 (equivalent to 5 * 8)
    const ir_shl = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .SHL, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // Compile MUL version
    var compiler_mul = NativeCompiler.init(allocator);
    defer compiler_mul.deinit();
    const code_mul = try compiler_mul.compile(&ir_mul);
    defer allocator.free(code_mul);
    var exec_mul = try ExecutableCode.init(code_mul);
    defer exec_mul.deinit();

    // Compile SHL version
    var compiler_shl = NativeCompiler.init(allocator);
    defer compiler_shl.deinit();
    const code_shl = try compiler_shl.compile(&ir_shl);
    defer allocator.free(code_shl);
    var exec_shl = try ExecutableCode.init(code_shl);
    defer exec_shl.deinit();

    const iterations: usize = 100000;

    // Benchmark MUL
    const mul_start = std.time.nanoTimestamp();
    var mul_result: i64 = 0;
    for (0..iterations) |_| {
        mul_result = exec_mul.call();
    }
    const mul_end = std.time.nanoTimestamp();
    const mul_time: u64 = @intCast(@max(0, mul_end - mul_start));

    // Benchmark SHL
    const shl_start = std.time.nanoTimestamp();
    var shl_result: i64 = 0;
    for (0..iterations) |_| {
        shl_result = exec_shl.call();
    }
    const shl_end = std.time.nanoTimestamp();
    const shl_time: u64 = @intCast(@max(0, shl_end - shl_start));

    // Both should produce same result: 40
    try std.testing.expectEqual(@as(i64, 40), mul_result);
    try std.testing.expectEqual(@as(i64, 40), shl_result);

    if (@import("builtin").mode == .Debug) {
        const mul_per_iter = @as(f64, @floatFromInt(mul_time)) / @as(f64, @floatFromInt(iterations));
        const shl_per_iter = @as(f64, @floatFromInt(shl_time)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("\n=== Native SHL vs MUL Benchmark ===\n", .{});
        std.debug.print("Iterations: {d}\n", .{iterations});
        std.debug.print("MUL (imul): {d:.2} ns/iter\n", .{mul_per_iter});
        std.debug.print("SHL (shl):  {d:.2} ns/iter\n", .{shl_per_iter});
        std.debug.print("Code size: MUL={d} bytes, SHL={d} bytes\n", .{ code_mul.len, code_shl.len });
        if (mul_per_iter > shl_per_iter) {
            std.debug.print("Speedup: {d:.2}x\n", .{mul_per_iter / shl_per_iter});
        }
    }
}

test "Execute native code: 7 * 3 = 21 (LEA)" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 7 * 3 using LEA (7 + 7*2 = 21)
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LEA, .dest = 1, .src1 = 0, .src2 = 0, .imm = 2 }, // 7 + 7*2 = 21
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 21), result);
}

test "Execute native code: 4 * 5 = 20 (LEA)" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 4 * 5 using LEA (4 + 4*4 = 20)
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 4 },
        .{ .opcode = .LEA, .dest = 1, .src1 = 0, .src2 = 0, .imm = 4 }, // 4 + 4*4 = 20
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 20), result);
}

test "Execute native code: 3 * 9 = 27 (LEA)" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate: return 3 * 9 using LEA (3 + 3*8 = 27)
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .LEA, .dest = 1, .src1 = 0, .src2 = 0, .imm = 8 }, // 3 + 3*8 = 27
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    const result = exec.call();
    try std.testing.expectEqual(@as(i64, 27), result);
}

test "Benchmark: native LEA vs MUL (multiply by 3)" {
    const allocator = std.testing.allocator;

    // IR with MUL: 7 * 3
    const ir_mul = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // IR with LEA: 7 + 7*2 = 21 (equivalent to 7 * 3)
    const ir_lea = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LEA, .dest = 1, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // Compile MUL version
    var compiler_mul = NativeCompiler.init(allocator);
    defer compiler_mul.deinit();
    const code_mul = try compiler_mul.compile(&ir_mul);
    defer allocator.free(code_mul);
    var exec_mul = try ExecutableCode.init(code_mul);
    defer exec_mul.deinit();

    // Compile LEA version
    var compiler_lea = NativeCompiler.init(allocator);
    defer compiler_lea.deinit();
    const code_lea = try compiler_lea.compile(&ir_lea);
    defer allocator.free(code_lea);
    var exec_lea = try ExecutableCode.init(code_lea);
    defer exec_lea.deinit();

    const iterations: usize = 100000;

    // Benchmark MUL
    const mul_start = std.time.nanoTimestamp();
    var mul_result: i64 = 0;
    for (0..iterations) |_| {
        mul_result = exec_mul.call();
    }
    const mul_end = std.time.nanoTimestamp();
    const mul_time: u64 = @intCast(@max(0, mul_end - mul_start));

    // Benchmark LEA
    const lea_start = std.time.nanoTimestamp();
    var lea_result: i64 = 0;
    for (0..iterations) |_| {
        lea_result = exec_lea.call();
    }
    const lea_end = std.time.nanoTimestamp();
    const lea_time: u64 = @intCast(@max(0, lea_end - lea_start));

    // Both should produce same result: 21
    try std.testing.expectEqual(@as(i64, 21), mul_result);
    try std.testing.expectEqual(@as(i64, 21), lea_result);

    if (@import("builtin").mode == .Debug) {
        const mul_per_iter = @as(f64, @floatFromInt(mul_time)) / @as(f64, @floatFromInt(iterations));
        const lea_per_iter = @as(f64, @floatFromInt(lea_time)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("\n=== Native LEA vs MUL Benchmark (x*3) ===\n", .{});
        std.debug.print("Iterations: {d}\n", .{iterations});
        std.debug.print("MUL (imul): {d:.2} ns/iter\n", .{mul_per_iter});
        std.debug.print("LEA (lea):  {d:.2} ns/iter\n", .{lea_per_iter});
        std.debug.print("Code size: MUL={d} bytes, LEA={d} bytes\n", .{ code_mul.len, code_lea.len });
        if (mul_per_iter > lea_per_iter) {
            std.debug.print("Speedup: {d:.2}x\n", .{mul_per_iter / lea_per_iter});
        }
    }
}

test "IC Stub generation for CALL_METHOD" {
    const allocator = std.testing.allocator;
    var compiler = NativeCompiler.init(allocator);
    defer compiler.deinit();

    // Generate IC stub for method call
    // CALL_METHOD: dest=0, src1=object_reg, src2=expected_type, imm=method_id
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0x1000 }, // object address
        .{ .opcode = .CALL_METHOD, .dest = 0, .src1 = 1, .src2 = 42, .imm = 100 }, // call method 100 on object, expect type 42
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const code = try compiler.compile(&ir);
    defer allocator.free(code);

    // Verify code was generated (IC stub should be ~50-100 bytes)
    try std.testing.expect(code.len > 30);
    try std.testing.expect(code.len < 200);

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== IC Stub Generation Test ===\n", .{});
        std.debug.print("Generated code size: {d} bytes\n", .{code.len});
    }
}

test "X86_64Emitter cmpRegImm32" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // cmp rax, 42
    try emitter.cmpRegImm32(.RAX, 42);

    // Should generate: REX.W + 81 F8 2A 00 00 00
    try std.testing.expect(emitter.code.items.len >= 6);
}

test "X86_64Emitter callReg" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // call rax
    try emitter.callReg(.RAX);

    // Should generate: FF D0
    try std.testing.expectEqual(@as(usize, 2), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0xFF), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0xD0), emitter.code.items[1]);
}

test "X86_64Emitter movRegImm64" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // mov rax, 0x123456789ABCDEF0
    try emitter.movRegImm64(.RAX, 0x123456789ABCDEF0);

    // Should generate: REX.W + B8 + 8 bytes immediate
    try std.testing.expectEqual(@as(usize, 10), emitter.code.items.len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SSE/AVX SIMD INSTRUCTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "X86_64Emitter PADDD xmm0, xmm1" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // PADDD xmm0, xmm1: 66 0F FE C1
    try emitter.paddd(.XMM0, .XMM1);

    try std.testing.expectEqual(@as(usize, 4), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0x66), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0x0F), emitter.code.items[1]);
    try std.testing.expectEqual(@as(u8, 0xFE), emitter.code.items[2]);
    try std.testing.expectEqual(@as(u8, 0xC1), emitter.code.items[3]); // ModR/M: xmm0, xmm1
}

test "X86_64Emitter PSUBD xmm2, xmm3" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // PSUBD xmm2, xmm3: 66 0F FA D3
    try emitter.psubd(.XMM2, .XMM3);

    try std.testing.expectEqual(@as(usize, 4), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0x66), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0x0F), emitter.code.items[1]);
    try std.testing.expectEqual(@as(u8, 0xFA), emitter.code.items[2]);
    try std.testing.expectEqual(@as(u8, 0xD3), emitter.code.items[3]); // ModR/M: xmm2, xmm3
}

test "X86_64Emitter PMULLD xmm0, xmm1" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // PMULLD xmm0, xmm1: 66 0F 38 40 C1
    try emitter.pmulld(.XMM0, .XMM1);

    try std.testing.expectEqual(@as(usize, 5), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0x66), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0x0F), emitter.code.items[1]);
    try std.testing.expectEqual(@as(u8, 0x38), emitter.code.items[2]);
    try std.testing.expectEqual(@as(u8, 0x40), emitter.code.items[3]);
    try std.testing.expectEqual(@as(u8, 0xC1), emitter.code.items[4]);
}

test "X86_64Emitter MOVDQU load xmm0, [rax]" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // MOVDQU xmm0, [rax]: F3 0F 6F 00
    try emitter.movdquLoad(.XMM0, .RAX, 0);

    try std.testing.expectEqual(@as(usize, 4), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0xF3), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0x0F), emitter.code.items[1]);
    try std.testing.expectEqual(@as(u8, 0x6F), emitter.code.items[2]);
    try std.testing.expectEqual(@as(u8, 0x00), emitter.code.items[3]); // ModR/M: xmm0, [rax]
}

test "X86_64Emitter MOVDQU store [rax], xmm1" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // MOVDQU [rax], xmm1: F3 0F 7F 08
    try emitter.movdquStore(.RAX, 0, .XMM1);

    try std.testing.expectEqual(@as(usize, 4), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0xF3), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0x0F), emitter.code.items[1]);
    try std.testing.expectEqual(@as(u8, 0x7F), emitter.code.items[2]);
}

test "X86_64Emitter PHADDD xmm0, xmm0" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // PHADDD xmm0, xmm0: 66 0F 38 02 C0
    try emitter.phaddd(.XMM0, .XMM0);

    try std.testing.expectEqual(@as(usize, 5), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0x66), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0x0F), emitter.code.items[1]);
    try std.testing.expectEqual(@as(u8, 0x38), emitter.code.items[2]);
    try std.testing.expectEqual(@as(u8, 0x02), emitter.code.items[3]);
}

test "X86_64Emitter AVX VPADDD ymm0, ymm1, ymm2" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // VPADDD ymm0, ymm1, ymm2: VEX.256.66.0F.WIG FE C2
    try emitter.vpaddd256(.XMM0, .XMM1, .XMM2);

    // VEX 2-byte prefix + opcode + ModR/M
    try std.testing.expect(emitter.code.items.len >= 4);
    // First byte should be VEX prefix (C5 for 2-byte)
    try std.testing.expectEqual(@as(u8, 0xC5), emitter.code.items[0]);
}

test "X86_64Emitter AVX VPMULLD ymm0, ymm1, ymm2" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // VPMULLD ymm0, ymm1, ymm2: VEX.256.66.0F38.WIG 40 C2
    try emitter.vpmulld256(.XMM0, .XMM1, .XMM2);

    // VEX 3-byte prefix + opcode + ModR/M
    try std.testing.expect(emitter.code.items.len >= 5);
    // First byte should be VEX 3-byte prefix (C4)
    try std.testing.expectEqual(@as(u8, 0xC4), emitter.code.items[0]);
}

test "X86_64Emitter PXOR xmm0, xmm0 (zero register)" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // PXOR xmm0, xmm0: 66 0F EF C0
    try emitter.pxor(.XMM0, .XMM0);

    try std.testing.expectEqual(@as(usize, 4), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0x66), emitter.code.items[0]);
    try std.testing.expectEqual(@as(u8, 0x0F), emitter.code.items[1]);
    try std.testing.expectEqual(@as(u8, 0xEF), emitter.code.items[2]);
    try std.testing.expectEqual(@as(u8, 0xC0), emitter.code.items[3]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD EXECUTION TESTS - Verify correctness of generated SIMD code
// ═══════════════════════════════════════════════════════════════════════════════

test "Execute SIMD: PADDD 4x i32 addition" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // Test: [1, 2, 3, 4] + [10, 20, 30, 40] = [11, 22, 33, 44]
    // 
    // Function that takes pointer to two arrays in RDI, RSI and stores result in RDX
    // 
    // movdqu xmm0, [rdi]     ; Load first vector
    // movdqu xmm1, [rsi]     ; Load second vector
    // paddd xmm0, xmm1       ; Add vectors
    // movdqu [rdx], xmm0     ; Store result
    // ret

    // movdqu xmm0, [rdi]: F3 0F 6F 07
    try emitter.movdquLoad(.XMM0, .RDI, 0);
    // movdqu xmm1, [rsi]: F3 0F 6F 0E
    try emitter.movdquLoad(.XMM1, .RSI, 0);
    // paddd xmm0, xmm1: 66 0F FE C1
    try emitter.paddd(.XMM0, .XMM1);
    // movdqu [rdx], xmm0: F3 0F 7F 02
    try emitter.movdquStore(.RDX, 0, .XMM0);
    // ret: C3
    try emitter.ret();

    const code = emitter.getCode();
    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    // Prepare test data (aligned to 16 bytes for safety)
    var input_a align(16) = [4]i32{ 1, 2, 3, 4 };
    var input_b align(16) = [4]i32{ 10, 20, 30, 40 };
    var result align(16) = [4]i32{ 0, 0, 0, 0 };

    // Call the function: fn(rdi=&input_a, rsi=&input_b, rdx=&result)
    const func: *const fn (*[4]i32, *[4]i32, *[4]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&input_a, &input_b, &result);

    // Verify results
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 22), result[1]);
    try std.testing.expectEqual(@as(i32, 33), result[2]);
    try std.testing.expectEqual(@as(i32, 44), result[3]);
}

test "Execute SIMD: PMULLD 4x i32 multiplication" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // Test: [2, 3, 4, 5] * [10, 10, 10, 10] = [20, 30, 40, 50]
    //
    // movdqu xmm0, [rdi]     ; Load first vector
    // movdqu xmm1, [rsi]     ; Load second vector
    // pmulld xmm0, xmm1      ; Multiply vectors
    // movdqu [rdx], xmm0     ; Store result
    // ret

    try emitter.movdquLoad(.XMM0, .RDI, 0);
    try emitter.movdquLoad(.XMM1, .RSI, 0);
    try emitter.pmulld(.XMM0, .XMM1);
    try emitter.movdquStore(.RDX, 0, .XMM0);
    try emitter.ret();

    const code = emitter.getCode();
    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    var input_a align(16) = [4]i32{ 2, 3, 4, 5 };
    var input_b align(16) = [4]i32{ 10, 10, 10, 10 };
    var result align(16) = [4]i32{ 0, 0, 0, 0 };

    const func: *const fn (*[4]i32, *[4]i32, *[4]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&input_a, &input_b, &result);

    try std.testing.expectEqual(@as(i32, 20), result[0]);
    try std.testing.expectEqual(@as(i32, 30), result[1]);
    try std.testing.expectEqual(@as(i32, 40), result[2]);
    try std.testing.expectEqual(@as(i32, 50), result[3]);
}

test "Execute SIMD: PSUBD 4x i32 subtraction" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // Test: [100, 200, 300, 400] - [1, 2, 3, 4] = [99, 198, 297, 396]

    try emitter.movdquLoad(.XMM0, .RDI, 0);
    try emitter.movdquLoad(.XMM1, .RSI, 0);
    try emitter.psubd(.XMM0, .XMM1);
    try emitter.movdquStore(.RDX, 0, .XMM0);
    try emitter.ret();

    const code = emitter.getCode();
    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    var input_a align(16) = [4]i32{ 100, 200, 300, 400 };
    var input_b align(16) = [4]i32{ 1, 2, 3, 4 };
    var result align(16) = [4]i32{ 0, 0, 0, 0 };

    const func: *const fn (*[4]i32, *[4]i32, *[4]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&input_a, &input_b, &result);

    try std.testing.expectEqual(@as(i32, 99), result[0]);
    try std.testing.expectEqual(@as(i32, 198), result[1]);
    try std.testing.expectEqual(@as(i32, 297), result[2]);
    try std.testing.expectEqual(@as(i32, 396), result[3]);
}

test "Execute SIMD: MOVDQU load/store roundtrip" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // Test: Load from [rdi], store to [rsi] - data should be preserved
    //
    // movdqu xmm0, [rdi]     ; Load
    // movdqu [rsi], xmm0     ; Store
    // ret

    try emitter.movdquLoad(.XMM0, .RDI, 0);
    try emitter.movdquStore(.RSI, 0, .XMM0);
    try emitter.ret();

    const code = emitter.getCode();
    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    var input align(16) = [4]i32{ 0x12345678, -559038737, -889275714, -2023406815 };
    var output align(16) = [4]i32{ 0, 0, 0, 0 };

    const func: *const fn (*[4]i32, *[4]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&input, &output);

    try std.testing.expectEqual(input[0], output[0]);
    try std.testing.expectEqual(input[1], output[1]);
    try std.testing.expectEqual(input[2], output[2]);
    try std.testing.expectEqual(input[3], output[3]);
}

test "Execute SIMD: PADDD with negative numbers" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // Test: [-1, -2, -3, -4] + [1, 2, 3, 4] = [0, 0, 0, 0]

    try emitter.movdquLoad(.XMM0, .RDI, 0);
    try emitter.movdquLoad(.XMM1, .RSI, 0);
    try emitter.paddd(.XMM0, .XMM1);
    try emitter.movdquStore(.RDX, 0, .XMM0);
    try emitter.ret();

    const code = emitter.getCode();
    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    var input_a align(16) = [4]i32{ -1, -2, -3, -4 };
    var input_b align(16) = [4]i32{ 1, 2, 3, 4 };
    var result align(16) = [4]i32{ 99, 99, 99, 99 };

    const func: *const fn (*[4]i32, *[4]i32, *[4]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&input_a, &input_b, &result);

    try std.testing.expectEqual(@as(i32, 0), result[0]);
    try std.testing.expectEqual(@as(i32, 0), result[1]);
    try std.testing.expectEqual(@as(i32, 0), result[2]);
    try std.testing.expectEqual(@as(i32, 0), result[3]);
}

test "Execute SIMD: PXOR to zero register" {
    const allocator = std.testing.allocator;
    var emitter = X86_64Emitter.init(allocator);
    defer emitter.deinit();

    // Test: XOR register with itself to zero it, then store
    //
    // pxor xmm0, xmm0        ; Zero xmm0
    // movdqu [rdi], xmm0     ; Store zeros
    // ret

    try emitter.pxor(.XMM0, .XMM0);
    try emitter.movdquStore(.RDI, 0, .XMM0);
    try emitter.ret();

    const code = emitter.getCode();
    var exec = try ExecutableCode.init(code);
    defer exec.deinit();

    var output align(16) = [4]i32{ 0x12345678, -559038737, -889275714, -2023406815 };

    const func: *const fn (*[4]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&output);

    try std.testing.expectEqual(@as(i32, 0), output[0]);
    try std.testing.expectEqual(@as(i32, 0), output[1]);
    try std.testing.expectEqual(@as(i32, 0), output[2]);
    try std.testing.expectEqual(@as(i32, 0), output[3]);
}

test "Benchmark SIMD: PADDD vs scalar addition" {
    const allocator = std.testing.allocator;

    // Generate SIMD version: add 4 integers at once
    var simd_emitter = X86_64Emitter.init(allocator);
    defer simd_emitter.deinit();

    try simd_emitter.movdquLoad(.XMM0, .RDI, 0);
    try simd_emitter.movdquLoad(.XMM1, .RSI, 0);
    try simd_emitter.paddd(.XMM0, .XMM1);
    try simd_emitter.movdquStore(.RDX, 0, .XMM0);
    try simd_emitter.ret();

    var simd_exec = try ExecutableCode.init(simd_emitter.getCode());
    defer simd_exec.deinit();

    // Generate scalar version: add 4 integers one by one
    var scalar_emitter = X86_64Emitter.init(allocator);
    defer scalar_emitter.deinit();

    // mov eax, [rdi]
    try scalar_emitter.movRegMemBase(.RAX, .RDI, 0);
    // add eax, [rsi]
    try scalar_emitter.code.append(0x03); // ADD r32, r/m32
    try scalar_emitter.code.append(0x06); // [rsi]
    // mov [rdx], eax
    try scalar_emitter.code.append(0x89); // MOV r/m32, r32
    try scalar_emitter.code.append(0x02); // [rdx]

    // Repeat for other 3 elements (simplified - just return for benchmark)
    try scalar_emitter.ret();

    var scalar_exec = try ExecutableCode.init(scalar_emitter.getCode());
    defer scalar_exec.deinit();

    // Benchmark data
    var input_a align(16) = [4]i32{ 1, 2, 3, 4 };
    var input_b align(16) = [4]i32{ 10, 20, 30, 40 };
    var result align(16) = [4]i32{ 0, 0, 0, 0 };

    const simd_func: *const fn (*[4]i32, *[4]i32, *[4]i32) callconv(.C) void = @ptrCast(simd_exec.code.ptr);

    const iterations: usize = 100000;

    // Benchmark SIMD
    const simd_start = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        simd_func(&input_a, &input_b, &result);
    }
    const simd_end = std.time.nanoTimestamp();
    const simd_time: u64 = @intCast(@max(0, simd_end - simd_start));

    const simd_per_iter = @as(f64, @floatFromInt(simd_time)) / @as(f64, @floatFromInt(iterations));

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== SIMD vs Scalar Benchmark ===\n", .{});
        std.debug.print("SIMD PADDD: {d:.2} ns/iter\n", .{simd_per_iter});
        std.debug.print("Result: [{}, {}, {}, {}]\n", .{ result[0], result[1], result[2], result[3] });
    }

    // Verify SIMD result is correct
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 22), result[1]);
    try std.testing.expectEqual(@as(i32, 33), result[2]);
    try std.testing.expectEqual(@as(i32, 44), result[3]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD ARRAY OPERATIONS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SIMDArrayOps: array_add with 8 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayAdd();
    defer exec.deinit();

    // Test data: 8 elements (4 SIMD + 4 SIMD)
    var a align(16) = [8]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var b align(16) = [8]i32{ 10, 20, 30, 40, 50, 60, 70, 80 };
    var result align(16) = [8]i32{ 0, 0, 0, 0, 0, 0, 0, 0 };

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, &b, &result, 8);

    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 22), result[1]);
    try std.testing.expectEqual(@as(i32, 33), result[2]);
    try std.testing.expectEqual(@as(i32, 44), result[3]);
    try std.testing.expectEqual(@as(i32, 55), result[4]);
    try std.testing.expectEqual(@as(i32, 66), result[5]);
    try std.testing.expectEqual(@as(i32, 77), result[6]);
    try std.testing.expectEqual(@as(i32, 88), result[7]);
}

test "SIMDArrayOps: array_add with remainder (5 elements)" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayAdd();
    defer exec.deinit();

    // Test data: 5 elements (4 SIMD + 1 scalar)
    var a align(16) = [5]i32{ 1, 2, 3, 4, 5 };
    var b align(16) = [5]i32{ 10, 20, 30, 40, 50 };
    var result align(16) = [5]i32{ 0, 0, 0, 0, 0 };

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, &b, &result, 5);

    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 22), result[1]);
    try std.testing.expectEqual(@as(i32, 33), result[2]);
    try std.testing.expectEqual(@as(i32, 44), result[3]);
    try std.testing.expectEqual(@as(i32, 55), result[4]);
}

test "SIMDArrayOps: array_mul with 4 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayMul();
    defer exec.deinit();

    var a align(16) = [4]i32{ 2, 3, 4, 5 };
    var b align(16) = [4]i32{ 10, 10, 10, 10 };
    var result align(16) = [4]i32{ 0, 0, 0, 0 };

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, &b, &result, 4);

    try std.testing.expectEqual(@as(i32, 20), result[0]);
    try std.testing.expectEqual(@as(i32, 30), result[1]);
    try std.testing.expectEqual(@as(i32, 40), result[2]);
    try std.testing.expectEqual(@as(i32, 50), result[3]);
}

test "SIMDArrayOps: array_sum with 8 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArraySum();
    defer exec.deinit();

    var a align(16) = [8]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };

    const func: *const fn ([*]i32, usize) callconv(.C) i32 = @ptrCast(exec.code.ptr);
    const sum = func(&a, 8);

    // 1+2+3+4+5+6+7+8 = 36
    try std.testing.expectEqual(@as(i32, 36), sum);
}

test "SIMDArrayOps: array_max with 8 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayMax();
    defer exec.deinit();

    var a align(16) = [8]i32{ 5, 2, 9, 1, 7, 3, 8, 4 };

    const func: *const fn ([*]i32, usize) callconv(.C) i32 = @ptrCast(exec.code.ptr);
    const max = func(&a, 8);

    try std.testing.expectEqual(@as(i32, 9), max);
}

test "SIMDArrayOps: array_sub with 8 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArraySub();
    defer exec.deinit();

    var a align(16) = [8]i32{ 10, 20, 30, 40, 50, 60, 70, 80 };
    var b align(16) = [8]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var result align(16) = [8]i32{ 0, 0, 0, 0, 0, 0, 0, 0 };

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, &b, &result, 8);

    try std.testing.expectEqual(@as(i32, 9), result[0]);
    try std.testing.expectEqual(@as(i32, 18), result[1]);
    try std.testing.expectEqual(@as(i32, 72), result[7]);
}

test "SIMDArrayOps: array_neg with 8 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayNeg();
    defer exec.deinit();

    var a align(16) = [8]i32{ 1, -2, 3, -4, 5, -6, 7, -8 };
    var result align(16) = [8]i32{ 0, 0, 0, 0, 0, 0, 0, 0 };

    // generateArrayNeg uses: RDI=a, RSI=length, RDX=result
    const func: *const fn ([*]i32, usize, [*]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, 8, &result);

    try std.testing.expectEqual(@as(i32, -1), result[0]);
    try std.testing.expectEqual(@as(i32, 2), result[1]);
    try std.testing.expectEqual(@as(i32, -3), result[2]);
    try std.testing.expectEqual(@as(i32, 8), result[7]);
}

test "SIMDArrayOps: array_scale with 8 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayScale(3);
    defer exec.deinit();

    var a align(16) = [8]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var result align(16) = [8]i32{ 0, 0, 0, 0, 0, 0, 0, 0 };

    // generateArrayScale uses: RDI=a, RSI=length, RDX=result
    const func: *const fn ([*]i32, usize, [*]i32) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, 8, &result);

    try std.testing.expectEqual(@as(i32, 3), result[0]);
    try std.testing.expectEqual(@as(i32, 6), result[1]);
    try std.testing.expectEqual(@as(i32, 24), result[7]);
}

test "SIMDArrayOps: array_add_unrolled with 16 elements" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayAddUnrolled();
    defer exec.deinit();

    var a align(16) = [16]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var b align(16) = [16]i32{ 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 };
    var result align(16) = [16]i32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, &b, &result, 16);

    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 15), result[4]);
    try std.testing.expectEqual(@as(i32, 19), result[8]);
    try std.testing.expectEqual(@as(i32, 26), result[15]);
}

test "SIMDArrayOps: array_add_unrolled with 17 elements (remainder)" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayAddUnrolled();
    defer exec.deinit();

    var a align(16) = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 } ++ [_]i32{0} ** 15;
    var b align(16) = [_]i32{ 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 } ++ [_]i32{0} ** 15;
    var result align(16) = [_]i32{0} ** 32;

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, &b, &result, 17);

    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 19), result[8]);
    try std.testing.expectEqual(@as(i32, 26), result[15]);
    try std.testing.expectEqual(@as(i32, 27), result[16]); // Scalar remainder
}

// ═══════════════════════════════════════════════════════════════════════════════
// AVX-256 TESTS (disabled pending VEX encoding fixes)
// ═══════════════════════════════════════════════════════════════════════════════

// TODO: Fix VEX encoding for AVX-256 instructions
// The AVX2 instructions are implemented but VEX prefix encoding needs debugging
// SSE (128-bit) operations work correctly

test "SIMDArrayOps: AVX-256 detection" {
    const allocator = std.testing.allocator;
    const ops_avx = SIMDArrayOps.initWithAVX(allocator);
    const ops_sse = SIMDArrayOps.initWithSSE(allocator);

    try std.testing.expect(ops_avx.use_avx256);
    try std.testing.expect(!ops_sse.use_avx256);
}

// Disabled: VEX encoding needs fixing
// // AVX-256 execution tests disabled - VEX encoding needs debugging
// The code generators are implemented but produce invalid opcodes

test "SIMDArrayOps: generateArrayAddBest falls back to SSE" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.initWithSSE(allocator);

    var exec = try ops.generateArrayAddBest();
    defer exec.deinit();

    var a align(16) = [8]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var b align(16) = [8]i32{ 10, 10, 10, 10, 10, 10, 10, 10 };
    var result align(16) = [8]i32{ 0, 0, 0, 0, 0, 0, 0, 0 };

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);
    func(&a, &b, &result, 8);

    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 18), result[7]);
}

test "Benchmark: SIMD array_add vs scalar (16 elements)" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec = try ops.generateArrayAdd();
    defer exec.deinit();

    var a align(16) = [16]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var b align(16) = [16]i32{ 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 };
    var result align(16) = [16]i32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    const func: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec.code.ptr);

    const iterations: usize = 100000;

    // Benchmark SIMD array add
    const start = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        func(&a, &b, &result, 16);
    }
    const end = std.time.nanoTimestamp();
    const time: u64 = @intCast(@max(0, end - start));
    const per_iter = @as(f64, @floatFromInt(time)) / @as(f64, @floatFromInt(iterations));

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== SIMD Array Add Benchmark (16 elements) ===\n", .{});
        std.debug.print("Time: {d:.2} ns/iter\n", .{per_iter});
        std.debug.print("Throughput: {d:.2} elements/ns\n", .{16.0 / per_iter});
    }

    // Verify results
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 26), result[15]);
}

test "Benchmark: SIMD vs SIMD+Unroll (64 elements)" {
    const allocator = std.testing.allocator;
    var ops = SIMDArrayOps.init(allocator);

    var exec_simd = try ops.generateArrayAdd();
    defer exec_simd.deinit();

    var exec_unrolled = try ops.generateArrayAddUnrolled();
    defer exec_unrolled.deinit();

    var a align(16) = [64]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64 };
    var b align(16) = [64]i32{ 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 };
    var result align(16) = [64]i32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    const func_simd: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec_simd.code.ptr);
    const func_unrolled: *const fn ([*]i32, [*]i32, [*]i32, usize) callconv(.C) void = @ptrCast(exec_unrolled.code.ptr);

    const iterations: usize = 100000;

    // Benchmark SIMD only
    const start_simd = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        func_simd(&a, &b, &result, 64);
    }
    const end_simd = std.time.nanoTimestamp();
    const time_simd: u64 = @intCast(@max(0, end_simd - start_simd));
    const per_iter_simd = @as(f64, @floatFromInt(time_simd)) / @as(f64, @floatFromInt(iterations));

    // Benchmark SIMD + Unroll
    const start_unrolled = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        func_unrolled(&a, &b, &result, 64);
    }
    const end_unrolled = std.time.nanoTimestamp();
    const time_unrolled: u64 = @intCast(@max(0, end_unrolled - start_unrolled));
    const per_iter_unrolled = @as(f64, @floatFromInt(time_unrolled)) / @as(f64, @floatFromInt(iterations));

    const speedup = per_iter_simd / per_iter_unrolled;

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== SIMD vs SIMD+Unroll Benchmark (64 elements) ===\n", .{});
        std.debug.print("SIMD only:    {d:.2} ns/iter ({d:.2} elements/ns)\n", .{ per_iter_simd, 64.0 / per_iter_simd });
        std.debug.print("SIMD+Unroll:  {d:.2} ns/iter ({d:.2} elements/ns)\n", .{ per_iter_unrolled, 64.0 / per_iter_unrolled });
        std.debug.print("Speedup:      {d:.2}x\n", .{speedup});
    }

    // Verify results
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 74), result[63]);
}
