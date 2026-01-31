// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC UNIFIED VALUE - SINGLE SOURCE OF TRUTH
// ═══════════════════════════════════════════════════════════════════════════════
// Replaces: bytecode.Value, nan_value.NanValue, coptic_interpreter.Value, etc.
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE REPRESENTATION MODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueMode = enum {
    tagged, // Tagged union (16+ bytes, compatible)
    nan_boxed, // NaN boxing (8 bytes, fast)
};

// ═══════════════════════════════════════════════════════════════════════════════
// TAGGED VALUE (Compatible mode)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueTag = enum(u8) {
    nil = 0,
    bool_val = 1,
    int_val = 2,
    float_val = 3,
    string_val = 4,
    array_val = 5,
    object_val = 6,
    func_val = 7,
    native_val = 8,
    trit_val = 9,
    tryte_val = 10,
};

pub const TaggedValue = union(ValueTag) {
    nil: void,
    bool_val: bool,
    int_val: i64,
    float_val: f64,
    string_val: []const u8,
    array_val: *std.ArrayList(TaggedValue),
    object_val: *std.StringHashMap(TaggedValue),
    func_val: u32,
    native_val: u32,
    trit_val: i8,
    tryte_val: i8,

    pub fn toInt(self: TaggedValue) i64 {
        return switch (self) {
            .int_val => |v| v,
            .float_val => |v| @intFromFloat(v),
            .bool_val => |v| if (v) @as(i64, 1) else @as(i64, 0),
            .trit_val => |v| @as(i64, v),
            .tryte_val => |v| @as(i64, v),
            else => 0,
        };
    }

    pub fn toFloat(self: TaggedValue) f64 {
        return switch (self) {
            .float_val => |v| v,
            .int_val => |v| @floatFromInt(v),
            .bool_val => |v| if (v) 1.0 else 0.0,
            else => 0.0,
        };
    }

    pub fn toBool(self: TaggedValue) bool {
        return switch (self) {
            .nil => false,
            .bool_val => |v| v,
            .int_val => |v| v != 0,
            .float_val => |v| v != 0.0,
            .trit_val => |v| v > 0,
            else => true,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NaN-BOXED VALUE (Fast mode)
// ═══════════════════════════════════════════════════════════════════════════════

const QNAN: u64 = 0x7FFC_0000_0000_0000;
const TAG_SHIFT: u6 = 45;
const TAG_MASK: u64 = 0x7 << TAG_SHIFT;
const PAYLOAD_MASK: u64 = (1 << 45) - 1;

const TAG_NIL: u64 = 0 << TAG_SHIFT;
const TAG_BOOL: u64 = 1 << TAG_SHIFT;
const TAG_INT: u64 = 2 << TAG_SHIFT;
const TAG_STRING: u64 = 3 << TAG_SHIFT;
const TAG_ARRAY: u64 = 4 << TAG_SHIFT;
const TAG_OBJECT: u64 = 5 << TAG_SHIFT;
const TAG_TRIT: u64 = 6 << TAG_SHIFT;
const TAG_TRYTE: u64 = 7 << TAG_SHIFT;

const NIL_VALUE: u64 = QNAN | TAG_NIL;
const TRUE_VALUE: u64 = QNAN | TAG_BOOL | 1;
const FALSE_VALUE: u64 = QNAN | TAG_BOOL | 0;

pub const NanBoxedValue = packed struct {
    bits: u64,

    const Self = @This();

    // Constructors
    pub inline fn nil() Self {
        return .{ .bits = NIL_VALUE };
    }

    pub inline fn boolean(b: bool) Self {
        return .{ .bits = if (b) TRUE_VALUE else FALSE_VALUE };
    }

    pub inline fn int(i: i64) Self {
        const max_int: i64 = (1 << 44) - 1;
        const min_int: i64 = -(1 << 44);
        const clamped = @max(min_int, @min(max_int, i));
        const payload: u64 = @bitCast(@as(i64, clamped) & @as(i64, @bitCast(PAYLOAD_MASK)));
        return .{ .bits = QNAN | TAG_INT | payload };
    }

    pub inline fn float(f: f64) Self {
        return .{ .bits = @bitCast(f) };
    }

    pub inline fn trit(t: i8) Self {
        const payload: u64 = @intCast(@as(u8, @bitCast(t)) & 0x3);
        return .{ .bits = QNAN | TAG_TRIT | payload };
    }

    pub inline fn tryte(t: i8) Self {
        const payload: u64 = @intCast(@as(u8, @bitCast(t)) & 0x1F);
        return .{ .bits = QNAN | TAG_TRYTE | payload };
    }

    // Type checks
    pub inline fn isFloat(self: Self) bool {
        return (self.bits & QNAN) != QNAN;
    }

    pub inline fn isNil(self: Self) bool {
        return self.bits == NIL_VALUE;
    }

    pub inline fn isBool(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_BOOL);
    }

    pub inline fn isInt(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_INT);
    }

    pub inline fn isTrit(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_TRIT);
    }

    pub inline fn isTryte(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_TRYTE);
    }

    // Extractors
    pub inline fn asFloat(self: Self) f64 {
        return @bitCast(self.bits);
    }

    pub inline fn asBool(self: Self) bool {
        return (self.bits & 1) != 0;
    }

    pub inline fn asInt(self: Self) i64 {
        const payload = self.bits & PAYLOAD_MASK;
        const sign_bit: u64 = 1 << 44;
        if ((payload & sign_bit) != 0) {
            return @as(i64, @bitCast(payload)) | @as(i64, @bitCast(~PAYLOAD_MASK));
        }
        return @as(i64, @bitCast(payload));
    }

    pub inline fn asTrit(self: Self) i8 {
        const payload: u8 = @truncate(self.bits & 0x3);
        return if (payload >= 2) @as(i8, @bitCast(payload)) - 4 else @as(i8, @bitCast(payload));
    }

    pub inline fn asTryte(self: Self) i8 {
        const payload: u8 = @truncate(self.bits & 0x1F);
        return if (payload >= 16) @as(i8, @bitCast(payload)) - 32 else @as(i8, @bitCast(payload));
    }

    // Conversions
    pub inline fn toInt(self: Self) i64 {
        if (self.isInt()) return self.asInt();
        if (self.isFloat()) return @intFromFloat(self.asFloat());
        if (self.isBool()) return if (self.asBool()) @as(i64, 1) else @as(i64, 0);
        if (self.isTrit()) return @as(i64, self.asTrit());
        if (self.isTryte()) return @as(i64, self.asTryte());
        return 0;
    }

    pub inline fn toFloat(self: Self) f64 {
        if (self.isFloat()) return self.asFloat();
        if (self.isInt()) return @floatFromInt(self.asInt());
        if (self.isBool()) return if (self.asBool()) 1.0 else 0.0;
        return 0.0;
    }

    pub inline fn toBool(self: Self) bool {
        if (self.isNil()) return false;
        if (self.isBool()) return self.asBool();
        if (self.isInt()) return self.asInt() != 0;
        if (self.isFloat()) return self.asFloat() != 0.0;
        if (self.isTrit()) return self.asTrit() > 0;
        return true;
    }

    // Arithmetic
    pub inline fn add(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return int(a.asInt() + b.asInt());
        }
        return float(a.toFloat() + b.toFloat());
    }

    pub inline fn sub(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return int(a.asInt() - b.asInt());
        }
        return float(a.toFloat() - b.toFloat());
    }

    pub inline fn mul(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return int(a.asInt() * b.asInt());
        }
        return float(a.toFloat() * b.toFloat());
    }

    pub inline fn div(a: Self, b: Self) Self {
        const bf = b.toFloat();
        if (bf == 0.0) return float(std.math.nan(f64));
        return float(a.toFloat() / bf);
    }

    // Comparison
    pub inline fn lt(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() < b.asInt());
        }
        return boolean(a.toFloat() < b.toFloat());
    }

    pub inline fn le(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() <= b.asInt());
        }
        return boolean(a.toFloat() <= b.toFloat());
    }

    pub inline fn gt(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() > b.asInt());
        }
        return boolean(a.toFloat() > b.toFloat());
    }

    pub inline fn ge(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() >= b.asInt());
        }
        return boolean(a.toFloat() >= b.toFloat());
    }

    pub inline fn eq(a: Self, b: Self) Self {
        return boolean(a.bits == b.bits);
    }

    // Ternary operations
    pub inline fn tritNot(self: Self) Self {
        if (self.isTrit()) {
            return trit(-self.asTrit());
        }
        return self;
    }

    pub inline fn tritAnd(a: Self, b: Self) Self {
        if (a.isTrit() and b.isTrit()) {
            return trit(@min(a.asTrit(), b.asTrit()));
        }
        return boolean(a.toBool() and b.toBool());
    }

    pub inline fn tritOr(a: Self, b: Self) Self {
        if (a.isTrit() and b.isTrit()) {
            return trit(@max(a.asTrit(), b.asTrit()));
        }
        return boolean(a.toBool() or b.toBool());
    }

    // Format
    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        if (self.isNil()) {
            try writer.writeAll("nil");
        } else if (self.isBool()) {
            try writer.print("{}", .{self.asBool()});
        } else if (self.isInt()) {
            try writer.print("{}", .{self.asInt()});
        } else if (self.isFloat()) {
            try writer.print("{d}", .{self.asFloat()});
        } else if (self.isTrit()) {
            const t = self.asTrit();
            const sym: []const u8 = if (t > 0) "T" else if (t < 0) "F" else "U";
            try writer.print("{s}", .{sym});
        } else if (self.isTryte()) {
            try writer.print("0t{}", .{self.asTryte()});
        } else {
            try writer.print("0x{X}", .{self.bits});
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED VALUE (Compile-time selectable)
// ═══════════════════════════════════════════════════════════════════════════════

/// Unified Value type - use NanBoxedValue for performance
pub const Value = NanBoxedValue;

/// Legacy alias for compatibility
pub const FastValue = NanBoxedValue;
pub const CompatValue = TaggedValue;

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NanBoxedValue size" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(NanBoxedValue));
}

test "NanBoxedValue nil" {
    const v = NanBoxedValue.nil();
    try std.testing.expect(v.isNil());
}

test "NanBoxedValue int" {
    const v = NanBoxedValue.int(42);
    try std.testing.expect(v.isInt());
    try std.testing.expectEqual(@as(i64, 42), v.asInt());
}

test "NanBoxedValue float" {
    const v = NanBoxedValue.float(PHI);
    try std.testing.expect(v.isFloat());
    try std.testing.expectApproxEqAbs(PHI, v.asFloat(), 0.0000001);
}

test "NanBoxedValue arithmetic" {
    const a = NanBoxedValue.int(10);
    const b = NanBoxedValue.int(3);

    try std.testing.expectEqual(@as(i64, 13), NanBoxedValue.add(a, b).asInt());
    try std.testing.expectEqual(@as(i64, 7), NanBoxedValue.sub(a, b).asInt());
    try std.testing.expectEqual(@as(i64, 30), NanBoxedValue.mul(a, b).asInt());
}

test "NanBoxedValue comparison" {
    const a = NanBoxedValue.int(5);
    const b = NanBoxedValue.int(10);

    try std.testing.expect(NanBoxedValue.lt(a, b).asBool());
    try std.testing.expect(!NanBoxedValue.gt(a, b).asBool());
}

test "NanBoxedValue trit" {
    const t = NanBoxedValue.trit(1);
    const f = NanBoxedValue.trit(-1);

    try std.testing.expect(t.isTrit());
    try std.testing.expectEqual(@as(i8, 1), t.asTrit());
    try std.testing.expectEqual(@as(i8, -1), NanBoxedValue.tritNot(t).asTrit());
    try std.testing.expectEqual(@as(i8, -1), NanBoxedValue.tritAnd(t, f).asTrit());
    try std.testing.expectEqual(@as(i8, 1), NanBoxedValue.tritOr(t, f).asTrit());
}

test "TaggedValue basic" {
    const v = TaggedValue{ .int_val = 42 };
    try std.testing.expectEqual(@as(i64, 42), v.toInt());
}
