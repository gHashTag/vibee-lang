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
