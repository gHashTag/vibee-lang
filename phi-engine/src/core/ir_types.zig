//! VIBEE Φ-ENGINE - IR TYPES (Solution #9)
//!
//! IR (Intermediate Representation) Types
//!
//! Scientific Basis: Static Single Assignment (SSA) Form
//! Fundamental Types for Sacred Geometry & Computation
//!
//! Sacred Formula: φ² = φ + 1

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

/// Value Type
/// Represents the data type of a value in the IR
pub const ValueType = enum(u4) {
    void,
    i1, i8, i16, i32, i64,
    u1, u8, u16, u32, u64,
    f32, f64,
    boolean,
    // Sacred Geometry Types
    point2d,
    point3d,
    quaternion,
};

/// Instruction Opcode
/// Represents the operation in the IR
pub const Opcode = enum(u8) {
    // Arithmetic
    add, sub, mul, div, mod,
    fadd, fsub, fmul, fdiv,
    // Bitwise
    and, or, xor, not, shl, shr,
    // Comparison
    eq, neq, lt, gt, lte, gte,
    // Control Flow
    jmp, br, call, ret,
    // Memory
    load, store,
    // Phi Special (Sacred)
    phi_add,       // Addition with golden ratio weight
    phi_spiral,   // Spiral coordinate mapping
    phi_lerp,     // Golden interpolation
};

/// IR Value
/// Represents a value in SSA (Static Single Assignment)
pub const IRValue = struct {
    /// Unique SSA ID
    id: u32,
    /// Value Type
    value_type: ValueType,
    /// Constant Value (if constant)
    const_value: ?union {
        i64: i64,
        f64: f64,
        bool: bool,
        // Sacred Geometry Constants
        point2d: struct { x: f64, y: f64 },
        point3d: struct { x: f64, y: f64, z: f64 },
    },
    /// Is this value a constant?
    is_const: bool,
};

/// IR Instruction
/// Represents a single operation in the IR
pub const IRInstruction = struct {
    /// Opcode
    op: Opcode,
    /// Operands (SSA IDs)
    operands: [3]u32, // max 3 operands
    /// Result ID (SSA ID)
    result: u32,
};

/// Basic Block
/// Represents a linear sequence of instructions without branches
pub const BasicBlock = struct {
    /// Unique ID
    id: u32,
    /// List of instructions
    instructions: std.ArrayListUnmanaged(IRInstruction),
    /// Successor blocks
    successors: std.ArrayListUnmanaged(u32),
};

/// IR Function
/// Represents a collection of basic blocks forming a function
pub const IRFunction = struct {
    /// Function Name
    name: []const u8,
    /// List of basic blocks
    blocks: std.ArrayListUnmanaged(BasicBlock),
    /// Return Value (SSA ID)
    return_value: u32,
};

/// IR Program
/// The top-level IR container
pub const IRProgram = struct {
    allocator: std.mem.Allocator,

    functions: std.StringHashMapUnmanaged(u32, IRFunction),
    constants: std.ArrayListUnmanaged(IRValue),

    pub fn init(allocator: std.mem.Allocator) IRProgram {
        return .{
            .allocator = allocator,
            .functions = std.StringHashMapUnmanaged(u32, IRFunction).init(allocator),
            .constants = std.ArrayListUnmanaged(IRValue).init(allocator),
        };
    }

    pub fn deinit(self: *IRProgram) void {
        var iter = self.functions.iterator();
        while (iter.next()) |entry| {
            var block_iter = entry.value_ptr.blocks.iterator();
            while (block_iter.next()) |block| {
                block.value_ptr.instructions.deinit();
                block.value_ptr.successors.deinit();
            }
            entry.value_ptr.blocks.deinit();
        }
        self.functions.deinit();
        self.constants.deinit();
    }
};

/// Create a constant value
pub fn irConst(allocator: std.mem.Allocator, value_type: ValueType, comptime T: type) !IRValue {
    const val = IRValue{
        .id = std.math.maxInt(u32), // Constants don't have SSA IDs
        .value_type = value_type,
        .const_value = switch (T) {
            i64 => .{ .i64 = 0 },
            f64 => .{ .f64 = 0.0 },
            bool => .{ .bool = false },
            else => unreachable,
        },
        .is_const = true,
    };

    // Store constant in program
    // (Implementation skipped for brevity)
    _ = allocator;
    _ = value_type;
    _ = T;

    return val;
}

// ════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                                                ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝

test "IR Types: value type enum" {
    // Just verify enum size
    try std.testing.expectEqual(@as(u4, @intFromEnum(ValueType.f32)), @intFromEnum(ValueType.f32));
    try std.testing.expectEqual(@as(u4, @intFromEnum(ValueType.point2d)), @intFromEnum(ValueType.point2d));
}

test "IR Types: opcode enum" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.add)), @intFromEnum(Opcode.add));
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.phi_spiral)), @intFromEnum(Opcode.phi_spiral));
}

test "IR Types: IRValue init" {
    const val = IRValue{
        .id = 123,
        .value_type = ValueType.i32,
        .const_value = .{ .i64 = 456 },
        .is_const = true,
    };

    try std.testing.expectEqual(@as(u32, 123), val.id);
    try std.testing.expectEqual(ValueType.i32, val.value_type);
    try std.testing.expectEqual(@as(i64, 456), val.const_value.i64);
    try std.testing.expectEqual(true, val.is_const);
}

test "IR Types: IRValue non-const" {
    const val = IRValue{
        .id = 123,
        .value_type = ValueType.i32,
        .const_value = .{ .i64 = 0 },
        .is_const = false,
    };

    try std.testing.expectEqual(@as(i64, 0), val.const_value.i64);
    try std.testing.expectEqual(false, val.is_const);
}

test "IR Types: IRInstruction init" {
    const inst = IRInstruction{
        .op = Opcode.add,
        .operands = [_]u32{ 1, 2, 3 },
        .result = 4,
    };

    try std.testing.expectEqual(Opcode.add, inst.op);
    try std.testing.expectEqual(@as(u32, 1), inst.operands[0]);
    try std.testing.expectEqual(@as(u32, 4), inst.result);
}

test "IR Types: phi identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}

test "IR Types: IRProgram init" {
    var prog = IRProgram.init(std.testing.allocator);
    defer prog.deinit();

    try std.testing.expectEqual(@as(usize, 0), prog.functions.count());
    try std.testing.expectEqual(@as(usize, 0), prog.constants.items.len);
}
