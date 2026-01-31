// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC REGISTER BYTECODE - .999 REGISTER-BASED FORMAT
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V38 - Register-based Bytecode for 30-50% speedup
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Architecture: 16 general-purpose registers (R0-R15)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const bytecode = @import("bytecode.zig");
const Value = bytecode.Value;

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const RegOpcode = enum(u8) {
    // ═══════════════════════════════════════════════════════════════════════════
    // Data Movement (0x00-0x0F)
    // ═══════════════════════════════════════════════════════════════════════════
    NOP = 0x00,
    MOV_RR = 0x01, // Rd = Rs                    [op][Rd:4|Rs:4]
    MOV_RI = 0x02, // Rd = imm16                 [op][Rd:4|0:4][imm16]
    LOAD_CONST = 0x03, // Rd = constants[idx]       [op][Rd:4|0:4][idx16]
    LOAD_LOCAL = 0x04, // Rd = locals[idx]          [op][Rd:4|0:4][idx16]
    STORE_LOCAL = 0x05, // locals[idx] = Rs          [op][Rs:4|0:4][idx16]
    LOAD_GLOBAL = 0x06, // Rd = globals[name_idx]    [op][Rd:4|0:4][idx16]
    STORE_GLOBAL = 0x07, // globals[name_idx] = Rs    [op][Rs:4|0:4][idx16]
    PUSH_R = 0x08, // push Rs to stack          [op][Rs:4|0:4]
    POP_R = 0x09, // pop to Rd from stack      [op][Rd:4|0:4]

    // ═══════════════════════════════════════════════════════════════════════════
    // Arithmetic 3-address (0x10-0x1F)
    // ═══════════════════════════════════════════════════════════════════════════
    ADD_RRR = 0x10, // Rd = Rs1 + Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    SUB_RRR = 0x11, // Rd = Rs1 - Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    MUL_RRR = 0x12, // Rd = Rs1 * Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    DIV_RRR = 0x13, // Rd = Rs1 / Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    MOD_RRR = 0x14, // Rd = Rs1 % Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    NEG_RR = 0x15, // Rd = -Rs                  [op][Rd:4|Rs:4]

    // Arithmetic with immediate
    ADD_RRI = 0x18, // Rd = Rs + imm16           [op][Rd:4|Rs:4][imm16]
    SUB_RRI = 0x19, // Rd = Rs - imm16           [op][Rd:4|Rs:4][imm16]
    MUL_RRI = 0x1A, // Rd = Rs * imm16           [op][Rd:4|Rs:4][imm16]

    // In-place operations (superinstructions)
    INC_R = 0x1E, // Rd = Rd + 1               [op][Rd:4|0:4]
    DEC_R = 0x1F, // Rd = Rd - 1               [op][Rd:4|0:4]

    // ═══════════════════════════════════════════════════════════════════════════
    // Comparison (0x20-0x2F)
    // ═══════════════════════════════════════════════════════════════════════════
    CMP_RR = 0x20, // flags = Rs1 cmp Rs2       [op][Rs1:4|Rs2:4]
    CMP_RI = 0x21, // flags = Rs cmp imm16      [op][Rs:4|0:4][imm16]

    // Boolean result comparisons
    LT_RRR = 0x22, // Rd = Rs1 < Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    LE_RRR = 0x23, // Rd = Rs1 <= Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    GT_RRR = 0x24, // Rd = Rs1 > Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    GE_RRR = 0x25, // Rd = Rs1 >= Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    EQ_RRR = 0x26, // Rd = Rs1 == Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    NE_RRR = 0x27, // Rd = Rs1 != Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]

    // ═══════════════════════════════════════════════════════════════════════════
    // Logic (0x30-0x3F)
    // ═══════════════════════════════════════════════════════════════════════════
    NOT_RR = 0x30, // Rd = !Rs                  [op][Rd:4|Rs:4]
    AND_RRR = 0x31, // Rd = Rs1 && Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    OR_RRR = 0x32, // Rd = Rs1 || Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    XOR_RRR = 0x33, // Rd = Rs1 ^ Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]

    // Bitwise
    SHL_RRR = 0x38, // Rd = Rs1 << Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    SHR_RRR = 0x39, // Rd = Rs1 >> Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    BAND_RRR = 0x3A, // Rd = Rs1 & Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]
    BOR_RRR = 0x3B, // Rd = Rs1 | Rs2            [op][Rd:4|Rs1:4][Rs2:4|0:4]

    // ═══════════════════════════════════════════════════════════════════════════
    // Control Flow (0x40-0x4F)
    // ═══════════════════════════════════════════════════════════════════════════
    JMP = 0x40, // ip = addr                 [op][addr16]
    JZ_R = 0x41, // if Rs == 0: ip = addr     [op][Rs:4|0:4][addr16]
    JNZ_R = 0x42, // if Rs != 0: ip = addr     [op][Rs:4|0:4][addr16]

    // Flag-based jumps (after CMP)
    JLT = 0x43, // if flags.lt: ip = addr    [op][addr16]
    JLE = 0x44, // if flags.le: ip = addr    [op][addr16]
    JGT = 0x45, // if flags.gt: ip = addr    [op][addr16]
    JGE = 0x46, // if flags.ge: ip = addr    [op][addr16]
    JEQ = 0x47, // if flags.eq: ip = addr    [op][addr16]
    JNE = 0x48, // if flags.ne: ip = addr    [op][addr16]

    // Function calls
    CALL = 0x49, // call addr, save return    [op][addr16]
    CALL_R = 0x4A, // call Rs (indirect)        [op][Rs:4|arity:4]
    RET = 0x4B, // return (R0 = result)      [op]
    RET_R = 0x4C, // return Rs                 [op][Rs:4|0:4]
    HALT = 0x4D, // stop execution            [op]

    // Native calls
    CALL_NATIVE = 0x4E, // call native[idx]          [op][idx16]

    // ═══════════════════════════════════════════════════════════════════════════
    // Arrays (0x50-0x5F)
    // ═══════════════════════════════════════════════════════════════════════════
    NEW_ARRAY_R = 0x50, // Rd = new array[Rs]        [op][Rd:4|Rs:4]
    ARRAY_GET_RRR = 0x51, // Rd = Rs1[Rs2]             [op][Rd:4|Rs1:4][Rs2:4|0:4]
    ARRAY_SET_RRR = 0x52, // Rs1[Rs2] = Rs3            [op][Rs1:4|Rs2:4][Rs3:4|0:4]
    ARRAY_LEN_RR = 0x53, // Rd = len(Rs)              [op][Rd:4|Rs:4]

    // ═══════════════════════════════════════════════════════════════════════════
    // Ternary Operations (0x70-0x7F)
    // ═══════════════════════════════════════════════════════════════════════════
    MOV_TRIT = 0x70, // Rd = trit_imm             [op][Rd:4|trit:4]
    TRIT_NOT_RR = 0x71, // Rd = trit_not(Rs)         [op][Rd:4|Rs:4]
    TRIT_AND_RRR = 0x72, // Rd = trit_and(Rs1, Rs2)   [op][Rd:4|Rs1:4][Rs2:4|0:4]
    TRIT_OR_RRR = 0x73, // Rd = trit_or(Rs1, Rs2)    [op][Rd:4|Rs1:4][Rs2:4|0:4]
    MOV_TRYTE = 0x78, // Rd = tryte_imm            [op][Rd:4|0:4][imm8]
    TRYTE_ADD_RRR = 0x79, // Rd = Rs1 +t Rs2           [op][Rd:4|Rs1:4][Rs2:4|0:4]
    TRYTE_INC_R = 0x7F, // Rd = Rd +t 1              [op][Rd:4|0:4]

    // ═══════════════════════════════════════════════════════════════════════════
    // Superinstructions (0xA0-0xAF)
    // ═══════════════════════════════════════════════════════════════════════════
    // Fused compare+jump (eliminates flag register access)
    INC_CMP_JLT = 0xA0, // Rd++; if Rd < Rs: jmp     [op][Rd:4|Rs:4][addr16]
    DEC_CMP_JGT = 0xA1, // Rd--; if Rd > Rs: jmp     [op][Rd:4|Rs:4][addr16]
    LOAD_ADD_STORE = 0xA2, // locals[d] = locals[s1] + locals[s2]

    // Sacred constants
    LOAD_PHI = 0x90, // Rd = φ                    [op][Rd:4|0:4]
    LOAD_PI = 0x91, // Rd = π                    [op][Rd:4|0:4]
    LOAD_E = 0x92, // Rd = e                    [op][Rd:4|0:4]

    pub fn size(self: RegOpcode) u8 {
        return switch (self) {
            // 1 byte (opcode only)
            .NOP, .RET, .HALT => 1,

            // 2 bytes (opcode + 1 reg byte)
            .MOV_RR, .NEG_RR, .NOT_RR, .INC_R, .DEC_R, .PUSH_R, .POP_R, .CMP_RR, .NEW_ARRAY_R, .ARRAY_LEN_RR, .RET_R, .MOV_TRIT, .TRIT_NOT_RR, .TRYTE_INC_R, .LOAD_PHI, .LOAD_PI, .LOAD_E => 2,

            // 3 bytes (opcode + 2 reg bytes OR opcode + addr16)
            .ADD_RRR, .SUB_RRR, .MUL_RRR, .DIV_RRR, .MOD_RRR, .LT_RRR, .LE_RRR, .GT_RRR, .GE_RRR, .EQ_RRR, .NE_RRR, .AND_RRR, .OR_RRR, .XOR_RRR, .SHL_RRR, .SHR_RRR, .BAND_RRR, .BOR_RRR, .ARRAY_GET_RRR, .ARRAY_SET_RRR, .TRIT_AND_RRR, .TRIT_OR_RRR, .TRYTE_ADD_RRR, .JMP, .JLT, .JLE, .JGT, .JGE, .JEQ, .JNE, .CALL, .CALL_NATIVE, .MOV_TRYTE => 3,

            // 4 bytes (opcode + reg byte + imm16)
            .MOV_RI, .LOAD_CONST, .LOAD_LOCAL, .STORE_LOCAL, .LOAD_GLOBAL, .STORE_GLOBAL, .CMP_RI, .ADD_RRI, .SUB_RRI, .MUL_RRI, .JZ_R, .JNZ_R, .CALL_R, .INC_CMP_JLT, .DEC_CMP_JGT => 4,

            // 5 bytes (special)
            .LOAD_ADD_STORE => 5,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER ENCODING HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Pack two 4-bit register indices into one byte
pub inline fn packRegs(r1: u4, r2: u4) u8 {
    return (@as(u8, r1) << 4) | @as(u8, r2);
}

/// Unpack byte into two 4-bit register indices
pub inline fn unpackRegs(byte: u8) struct { r1: u4, r2: u4 } {
    return .{
        .r1 = @truncate(byte >> 4),
        .r2 = @truncate(byte & 0x0F),
    };
}

/// Pack 16-bit value into two bytes (little-endian)
pub inline fn packU16(val: u16) struct { lo: u8, hi: u8 } {
    return .{
        .lo = @truncate(val),
        .hi = @truncate(val >> 8),
    };
}

/// Unpack two bytes into 16-bit value (little-endian)
pub inline fn unpackU16(lo: u8, hi: u8) u16 {
    return (@as(u16, hi) << 8) | @as(u16, lo);
}

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER BYTECODE EMITTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const RegBytecodeEmitter = struct {
    code: std.ArrayList(u8),
    constants: std.ArrayList(Value),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .code = std.ArrayList(u8).init(allocator),
            .constants = std.ArrayList(Value).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
        self.constants.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EMIT HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn emit(self: *Self, op: RegOpcode) !void {
        try self.code.append(@intFromEnum(op));
    }

    pub fn emitRR(self: *Self, op: RegOpcode, rd: u4, rs: u4) !void {
        try self.code.append(@intFromEnum(op));
        try self.code.append(packRegs(rd, rs));
    }

    pub fn emitRRR(self: *Self, op: RegOpcode, rd: u4, rs1: u4, rs2: u4) !void {
        try self.code.append(@intFromEnum(op));
        try self.code.append(packRegs(rd, rs1));
        try self.code.append(packRegs(rs2, 0));
    }

    pub fn emitRI(self: *Self, op: RegOpcode, rd: u4, imm: u16) !void {
        try self.code.append(@intFromEnum(op));
        try self.code.append(packRegs(rd, 0));
        const p16 = packU16(imm);
        try self.code.append(p16.lo);
        try self.code.append(p16.hi);
    }

    pub fn emitRRI(self: *Self, op: RegOpcode, rd: u4, rs: u4, imm: u16) !void {
        try self.code.append(@intFromEnum(op));
        try self.code.append(packRegs(rd, rs));
        const p16 = packU16(imm);
        try self.code.append(p16.lo);
        try self.code.append(p16.hi);
    }

    pub fn emitAddr(self: *Self, op: RegOpcode, addr: u16) !void {
        try self.code.append(@intFromEnum(op));
        const p16 = packU16(addr);
        try self.code.append(p16.lo);
        try self.code.append(p16.hi);
    }

    pub fn emitRAddr(self: *Self, op: RegOpcode, rs: u4, addr: u16) !void {
        try self.code.append(@intFromEnum(op));
        try self.code.append(packRegs(rs, 0));
        const p16 = packU16(addr);
        try self.code.append(p16.lo);
        try self.code.append(p16.hi);
    }

    /// Add constant and return its index
    pub fn addConstant(self: *Self, value: Value) !u16 {
        const idx = self.constants.items.len;
        try self.constants.append(value);
        return @intCast(idx);
    }

    /// Get current code position (for jump targets)
    pub fn currentPos(self: *Self) u16 {
        return @intCast(self.code.items.len);
    }

    /// Patch jump address at given position
    pub fn patchJump(self: *Self, pos: usize, target: u16) void {
        const p16 = packU16(target);
        self.code.items[pos] = p16.lo;
        self.code.items[pos + 1] = p16.hi;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "register packing" {
    const reg_byte = packRegs(0xA, 0xB);
    try std.testing.expectEqual(@as(u8, 0xAB), reg_byte);

    const regs = unpackRegs(0xAB);
    try std.testing.expectEqual(@as(u4, 0xA), regs.r1);
    try std.testing.expectEqual(@as(u4, 0xB), regs.r2);
}

test "u16 packing" {
    const p = packU16(0x1234);
    try std.testing.expectEqual(@as(u8, 0x34), p.lo);
    try std.testing.expectEqual(@as(u8, 0x12), p.hi);

    const val = unpackU16(0x34, 0x12);
    try std.testing.expectEqual(@as(u16, 0x1234), val);
}

test "emitter basic" {
    var emitter = RegBytecodeEmitter.init(std.testing.allocator);
    defer emitter.deinit();

    // MOV R0, R1
    try emitter.emitRR(.MOV_RR, 0, 1);
    try std.testing.expectEqual(@as(usize, 2), emitter.code.items.len);
    try std.testing.expectEqual(@as(u8, 0x01), emitter.code.items[0]); // MOV_RR
    try std.testing.expectEqual(@as(u8, 0x01), emitter.code.items[1]); // R0, R1

    // ADD R2, R3, R4
    try emitter.emitRRR(.ADD_RRR, 2, 3, 4);
    try std.testing.expectEqual(@as(usize, 5), emitter.code.items.len);
}

test "opcode sizes" {
    try std.testing.expectEqual(@as(u8, 1), RegOpcode.NOP.size());
    try std.testing.expectEqual(@as(u8, 2), RegOpcode.MOV_RR.size());
    try std.testing.expectEqual(@as(u8, 3), RegOpcode.ADD_RRR.size());
    try std.testing.expectEqual(@as(u8, 4), RegOpcode.LOAD_CONST.size());
}
