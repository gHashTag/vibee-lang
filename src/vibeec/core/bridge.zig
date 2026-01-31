// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC BRIDGE - INTEGRATION LAYER
// ═══════════════════════════════════════════════════════════════════════════════
// Bridges unified core modules with existing bytecode infrastructure
// Provides conversion between tagged union (bytecode.Value) and NaN-boxed values
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const core_value = @import("value.zig");
const core_vm = @import("vm.zig");

// Re-export core types
pub const Value = core_value.Value;
pub const NanBoxedValue = core_value.NanBoxedValue;
pub const TaggedValue = core_value.TaggedValue;
pub const ValueTag = core_value.ValueTag;

pub const VM = core_vm.VM;
pub const VMConfig = core_vm.VMConfig;
pub const Opcode = core_vm.Opcode;
pub const CallFrame = core_vm.CallFrame;

// Sacred constants
pub const PHI = core_value.PHI;
pub const PHI_SQ = core_value.PHI_SQ;
pub const PI = core_value.PI;
pub const E = core_value.E;

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODE MAPPING: bytecode.Opcode -> core.Opcode
// ═══════════════════════════════════════════════════════════════════════════════

/// Maps legacy bytecode opcodes to unified core opcodes
pub fn mapOpcode(legacy: u8) Opcode {
    return switch (legacy) {
        0x00 => .nop,
        0x01 => .load_const, // PUSH_CONST
        0x02 => .pop,
        0x03 => .dup,
        0x04 => .swap,
        0x05 => .load_local,
        0x06 => .store_local,
        0x07 => .load_global,
        0x08 => .store_global,

        0x10 => .add,
        0x11 => .sub,
        0x12 => .mul,
        0x13 => .div,
        0x14 => .mod,
        0x15 => .neg,

        0x20 => .eq,
        0x21 => .eq, // NE handled separately
        0x22 => .lt,
        0x23 => .le,
        0x24 => .gt,
        0x25 => .ge,

        0x30 => .not,
        0x31 => .@"and",
        0x32 => .@"or",

        0x40 => .jump,
        0x41 => .jump_if_not, // JZ
        0x42 => .jump_if, // JNZ
        0x43 => .call,
        0x44 => .ret,
        0x45 => .halt,

        0x70 => .load_const, // PUSH_TRIT - load trit constant
        0x71 => .trit_not,
        0x72 => .trit_and,
        0x73 => .trit_or,

        else => .nop,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE CONVERSION: TaggedValue <-> NanBoxedValue
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert tagged union value to NaN-boxed value
pub fn taggedToNan(tagged: TaggedValue) NanBoxedValue {
    return switch (tagged) {
        .nil => NanBoxedValue.nil(),
        .bool_val => |v| NanBoxedValue.boolean(v),
        .int_val => |v| NanBoxedValue.int(v),
        .float_val => |v| NanBoxedValue.float(v),
        .trit_val => |v| NanBoxedValue.trit(v),
        .tryte_val => |v| NanBoxedValue.tryte(v),
        // Complex types store as nil (need heap allocation)
        .string_val, .array_val, .object_val, .func_val, .native_val => NanBoxedValue.nil(),
    };
}

/// Convert NaN-boxed value to tagged union value
pub fn nanToTagged(nan: NanBoxedValue) TaggedValue {
    if (nan.isNil()) return .{ .nil = {} };
    if (nan.isBool()) return .{ .bool_val = nan.asBool() };
    if (nan.isInt()) return .{ .int_val = nan.asInt() };
    if (nan.isFloat()) return .{ .float_val = nan.asFloat() };
    if (nan.isTrit()) return .{ .trit_val = nan.asTrit() };
    if (nan.isTryte()) return .{ .tryte_val = nan.asTryte() };
    return .{ .nil = {} };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE TRANSLATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Translates legacy bytecode to unified core bytecode format
pub const BytecodeTranslator = struct {
    output: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .output = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit();
    }

    /// Translate legacy bytecode to core format
    pub fn translate(self: *Self, legacy_code: []const u8) ![]const u8 {
        self.output.clearRetainingCapacity();

        var ip: usize = 0;
        while (ip < legacy_code.len) {
            const legacy_op = legacy_code[ip];
            const core_op = mapOpcode(legacy_op);
            try self.output.append(@intFromEnum(core_op));
            ip += 1;

            // Copy operands based on legacy opcode
            const operand_size = getLegacyOperandSize(legacy_op);
            if (operand_size > 0 and ip + operand_size <= legacy_code.len) {
                try self.output.appendSlice(legacy_code[ip .. ip + operand_size]);
                ip += operand_size;
            }
        }

        return self.output.items;
    }

    fn getLegacyOperandSize(op: u8) usize {
        return switch (op) {
            0x01, 0x40, 0x41, 0x42, 0x43, 0x46 => 2, // PUSH_CONST, JMP, JZ, JNZ, CALL, LOOP
            0x05, 0x06, 0x07, 0x08 => 2, // LOAD/STORE LOCAL/GLOBAL
            0x70 => 1, // PUSH_TRIT
            0x78 => 2, // PUSH_TRYTE
            else => 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

/// Runs legacy bytecode through the unified VM
pub fn runLegacyBytecode(
    allocator: std.mem.Allocator,
    legacy_code: []const u8,
    constants: []const NanBoxedValue,
) !NanBoxedValue {
    var translator = BytecodeTranslator.init(allocator);
    defer translator.deinit();

    const core_code = try translator.translate(legacy_code);

    var vm = try VM.init(allocator, .{});
    defer vm.deinit();

    vm.load(core_code, constants);
    return vm.run();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "taggedToNan conversion" {
    const tagged_int = TaggedValue{ .int_val = 42 };
    const nan = taggedToNan(tagged_int);
    try std.testing.expect(nan.isInt());
    try std.testing.expectEqual(@as(i64, 42), nan.asInt());
}

test "nanToTagged conversion" {
    const nan = NanBoxedValue.float(3.14);
    const tagged = nanToTagged(nan);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), tagged.toFloat(), 0.001);
}

test "opcode mapping" {
    try std.testing.expectEqual(Opcode.add, mapOpcode(0x10));
    try std.testing.expectEqual(Opcode.sub, mapOpcode(0x11));
    try std.testing.expectEqual(Opcode.halt, mapOpcode(0x45));
    try std.testing.expectEqual(Opcode.trit_not, mapOpcode(0x71));
}

test "BytecodeTranslator basic" {
    var translator = BytecodeTranslator.init(std.testing.allocator);
    defer translator.deinit();

    // Legacy: NOP, ADD, HALT
    const legacy = [_]u8{ 0x00, 0x10, 0x45 };
    const core = try translator.translate(&legacy);

    try std.testing.expectEqual(@as(usize, 3), core.len);
    try std.testing.expectEqual(@intFromEnum(Opcode.nop), core[0]);
    try std.testing.expectEqual(@intFromEnum(Opcode.add), core[1]);
    try std.testing.expectEqual(@intFromEnum(Opcode.halt), core[2]);
}
