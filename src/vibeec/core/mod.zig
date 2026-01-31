// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC CORE MODULE - UNIFIED EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════
// Single import point for all core functionality
// Usage: const core = @import("core/mod.zig");
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

pub const value = @import("value.zig");
pub const vm = @import("vm.zig");
pub const jit = @import("jit.zig");
pub const bridge = @import("bridge.zig");

// Re-export primary types
pub const Value = value.Value;
pub const NanBoxedValue = value.NanBoxedValue;
pub const TaggedValue = value.TaggedValue;
pub const ValueTag = value.ValueTag;

pub const VM = vm.VM;
pub const VMConfig = vm.VMConfig;
pub const Opcode = vm.Opcode;
pub const CallFrame = vm.CallFrame;

pub const JitCompiler = jit.JitCompiler;
pub const X64Encoder = jit.X64Encoder;
pub const Reg64 = jit.Reg64;
pub const XmmReg = jit.XmmReg;

// Sacred constants
pub const PHI = value.PHI;
pub const PHI_SQ = value.PHI_SQ;
pub const PI = value.PI;
pub const E = value.E;

// Bridge functions
pub const taggedToNan = bridge.taggedToNan;
pub const nanToTagged = bridge.nanToTagged;
pub const mapOpcode = bridge.mapOpcode;
pub const BytecodeTranslator = bridge.BytecodeTranslator;
pub const runLegacyBytecode = bridge.runLegacyBytecode;

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "core module exports" {
    const std = @import("std");

    // Value tests
    const v = Value.int(42);
    try std.testing.expect(v.isInt());
    try std.testing.expectEqual(@as(i64, 42), v.asInt());

    // Sacred constants
    try std.testing.expectApproxEqAbs(@as(f64, 1.618), PHI, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), PI, 0.001);
}

test "core VM creation" {
    const std = @import("std");

    var core_vm = try VM.init(std.testing.allocator, .{});
    defer core_vm.deinit();

    try std.testing.expectEqual(@as(u32, 0), core_vm.sp);
}
