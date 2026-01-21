// ═══════════════════════════════════════════════════════════════════════════════
// VM OPCODES - Opcode definitions and handlers
// ═══════════════════════════════════════════════════════════════════════════════
// Part of micro-library architecture (TenonOS-inspired)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const core = @import("vm_core.zig");
const Value = core.Value;

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODE ENUM
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    // Stack operations (0x00-0x0F)
    NOP = 0x00,
    PUSH_CONST = 0x01,
    POP = 0x02,
    DUP = 0x03,
    SWAP = 0x04,
    
    // Arithmetic (0x10-0x1F)
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    NEG = 0x15,
    INC = 0x16,
    DEC = 0x17,
    
    // Comparison (0x20-0x2F)
    EQ = 0x20,
    NE = 0x21,
    LT = 0x22,
    LE = 0x23,
    GT = 0x24,
    GE = 0x25,
    
    // Logic (0x30-0x3F)
    NOT = 0x30,
    AND = 0x31,
    OR = 0x32,
    
    // Control flow (0x40-0x4F)
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    CALL = 0x43,
    RET = 0x44,
    HALT = 0x45,
    LOOP = 0x46,
    
    // SIMD (0x80-0x8F)
    SIMD_ADD = 0x80,
    SIMD_MUL = 0x81,
    SIMD_DOT = 0x82,
    
    // Sacred constants (0x90-0x9F)
    PUSH_PHI = 0x90,
    PUSH_PI = 0x91,
    PUSH_E = 0x92,
    GOLDEN_IDENTITY = 0x93,
    SACRED_FORMULA = 0x94,
    PUSH_SQRT2 = 0x95,
    PUSH_SQRT3 = 0x96,
    PUSH_SQRT5 = 0x97,
    
    // Superinstructions (0xA0-0xAF)
    LOAD_ADD = 0xA0,
    LOAD_SUB = 0xA1,
    LOAD_MUL = 0xA2,
    LT_JZ = 0xA3,
    LE_JZ = 0xA4,
    INC_LT = 0xA5,
    DEC_GT = 0xA6,
    DUP_LOAD_LT = 0xA7,
    ADD_STORE = 0xA8,
    LOAD_LOAD_ADD = 0xA9,
    LOAD_LOAD_LT = 0xAA,
    
    pub fn name(self: Opcode) []const u8 {
        return @tagName(self);
    }
    
    pub fn operandSize(self: Opcode) u8 {
        return switch (self) {
            .PUSH_CONST, .JMP, .JZ, .JNZ, .CALL, .LOOP,
            .LOAD_ADD, .LOAD_SUB, .LOAD_MUL, .LT_JZ, .LE_JZ,
            .DUP_LOAD_LT, .ADD_STORE,
            => 2,
            .LOAD_LOAD_ADD, .LOAD_LOAD_LT => 4,
            else => 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredConstants = struct {
    pub const PHI: f64 = 1.6180339887498948482;
    pub const PI: f64 = 3.14159265358979323846;
    pub const E: f64 = 2.71828182845904523536;
    pub const SQRT2: f64 = 1.41421356237309504880;
    pub const SQRT3: f64 = 1.73205080756887729352;
    pub const SQRT5: f64 = 2.23606797749978969640;
    
    /// φ² + 1/φ² = 3
    pub fn goldenIdentity() f64 {
        return PHI * PHI + 1.0 / (PHI * PHI);
    }
    
    /// V = n × 3^k × π^m × φ^p × e^q
    pub fn sacredFormula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {
        return n * std.math.pow(f64, 3.0, k) * 
               std.math.pow(f64, PI, m) * 
               std.math.pow(f64, PHI, p) * 
               std.math.pow(f64, E, q);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODE HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const OpcodeHandler = struct {
    /// Execute arithmetic ADD
    pub inline fn add(a: Value, b: Value) Value {
        if (a.tag == .INT and b.tag == .INT) {
            return Value.int(a.asInt() +% b.asInt());
        }
        return Value.float(a.toFloat() + b.toFloat());
    }
    
    /// Execute arithmetic SUB
    pub inline fn sub(a: Value, b: Value) Value {
        if (a.tag == .INT and b.tag == .INT) {
            return Value.int(a.asInt() -% b.asInt());
        }
        return Value.float(a.toFloat() - b.toFloat());
    }
    
    /// Execute arithmetic MUL
    pub inline fn mul(a: Value, b: Value) Value {
        if (a.tag == .INT and b.tag == .INT) {
            return Value.int(a.asInt() *% b.asInt());
        }
        return Value.float(a.toFloat() * b.toFloat());
    }
    
    /// Execute arithmetic DIV
    pub inline fn div(a: Value, b: Value) !Value {
        const bf = b.toFloat();
        if (bf == 0.0) return error.DivisionByZero;
        return Value.float(a.toFloat() / bf);
    }
    
    /// Execute comparison LT
    pub inline fn lt(a: Value, b: Value) Value {
        return Value.boolean(a.toFloat() < b.toFloat());
    }
    
    /// Execute comparison LE
    pub inline fn le(a: Value, b: Value) Value {
        return Value.boolean(a.toFloat() <= b.toFloat());
    }
    
    /// Execute comparison GT
    pub inline fn gt(a: Value, b: Value) Value {
        return Value.boolean(a.toFloat() > b.toFloat());
    }
    
    /// Execute comparison GE
    pub inline fn ge(a: Value, b: Value) Value {
        return Value.boolean(a.toFloat() >= b.toFloat());
    }
    
    /// Execute comparison EQ
    pub inline fn eq(a: Value, b: Value) Value {
        return Value.boolean(a.toFloat() == b.toFloat());
    }
    
    /// Execute comparison NE
    pub inline fn ne(a: Value, b: Value) Value {
        return Value.boolean(a.toFloat() != b.toFloat());
    }
    
    /// Execute INC
    pub inline fn inc(a: Value) Value {
        if (a.tag == .INT) {
            return Value.int(a.asInt() +% 1);
        }
        return Value.float(a.toFloat() + 1.0);
    }
    
    /// Execute DEC
    pub inline fn dec(a: Value) Value {
        if (a.tag == .INT) {
            return Value.int(a.asInt() -% 1);
        }
        return Value.float(a.toFloat() - 1.0);
    }
    
    /// Execute NEG
    pub inline fn neg(a: Value) Value {
        if (a.tag == .INT) {
            return Value.int(-a.asInt());
        }
        return Value.float(-a.toFloat());
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Opcode operand sizes" {
    try std.testing.expectEqual(@as(u8, 2), Opcode.PUSH_CONST.operandSize());
    try std.testing.expectEqual(@as(u8, 0), Opcode.ADD.operandSize());
    try std.testing.expectEqual(@as(u8, 4), Opcode.LOAD_LOAD_ADD.operandSize());
}

test "OpcodeHandler arithmetic" {
    const a = Value.int(10);
    const b = Value.int(3);
    
    try std.testing.expectEqual(@as(i64, 13), OpcodeHandler.add(a, b).asInt());
    try std.testing.expectEqual(@as(i64, 7), OpcodeHandler.sub(a, b).asInt());
    try std.testing.expectEqual(@as(i64, 30), OpcodeHandler.mul(a, b).asInt());
}

test "OpcodeHandler comparison" {
    const a = Value.int(5);
    const b = Value.int(10);
    
    try std.testing.expect(OpcodeHandler.lt(a, b).asBool());
    try std.testing.expect(!OpcodeHandler.gt(a, b).asBool());
    try std.testing.expect(OpcodeHandler.le(a, b).asBool());
}

test "Sacred constants" {
    // Golden identity: φ² + 1/φ² = 3
    const identity = SacredConstants.goldenIdentity();
    try std.testing.expect(@abs(identity - 3.0) < 0.0001);
}
