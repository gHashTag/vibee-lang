//! VIBEE Φ-ENGINE - IR TYPES (Solution #9)
//!
//! IR Types - Native Phi Support in Intermediate Representation

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

pub const IRType = enum(u8) {
    void_ir,
    i1,
    i8,
    i16,
    i32,
    i64,
    f32,
    f64,
    ptr,
    phi_ir,
    array,
    struct_ir,
    func,

    pub fn size(self: IRType) u32 {
        return switch (self) {
            .void_ir => 0,
            .i1, .i8 => 1,
            .i16 => 2,
            .i32, .f32, .ptr, .phi_ir => 4,
            .i64, .f64 => 8,
            .array, .struct_ir, .func => 8,
        };
    }
};

pub const ValueKind = enum(u8) {
    const_int,
    const_float,
    const_bool,
    const_null,
    const_phi,
    instruction,
    parameter,
    global,
    undef,
};

pub const IRValue = struct {
    type: IRType,
    kind: ValueKind,
    const_int: i64 = 0,
    const_float: f64 = 0.0,
    const_bool: bool = false,
};

pub fn isConstant(value: *const IRValue) bool {
    return @intFromEnum(value.kind) <= @intFromEnum(ValueKind.const_phi);
}

pub fn foldPhiIdentity(value: *const IRValue) f64 {
    if (value.type != .f64) return 0.0;
    if (value.kind != .const_float) return 0.0;

    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    return phi_sq + inv_phi_sq;
}

// ════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═══════════════════════════════════════════════════════════════════╝

test "IR Types: phi_ir size" {
    try std.testing.expectEqual(@as(u32, 4), IRType.phi_ir.size());
}

test "IR Types: phi_ir != void" {
    try std.testing.expect(IRType.phi_ir != .void_ir);
}

test "IR Value: is constant phi" {
    const value = IRValue{
        .type = .f64,
        .kind = .const_phi,
        .const_float = PHI,
    };
    try std.testing.expect(isConstant(&value));
}

test "IR Value: is not constant" {
    const value = IRValue{
        .type = .f64,
        .kind = .instruction,
        .const_float = 0.0,
    };
    try std.testing.expect(!isConstant(&value));
}

test "IR Value: fold phi identity" {
    const value = IRValue{
        .type = .f64,
        .kind = .const_float,
        .const_float = 0.0,
    };
    const result = foldPhiIdentity(&value);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0001);
}

test "IR Types: golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
