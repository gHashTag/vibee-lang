// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC NaN-BOXED VALUE - ULTRA-FAST 64-BIT VALUE REPRESENTATION
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V39 - NaN Boxing for φ = 1.618x speedup
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: 275M → 445M ops/sec
// ═══════════════════════════════════════════════════════════════════════════════
//
// NaN Boxing Layout (64 bits):
//
// FLOAT (native IEEE 754):
//   Any valid double that is NOT a quiet NaN with our tag pattern
//
// TAGGED VALUES:
//   ┌─────────────────────────────────────────────────────────────────┐
//   │ 0x7FFC (16 bits) │ Tag (3 bits) │ Payload (45 bits)            │
//   └─────────────────────────────────────────────────────────────────┘
//
// Tag values:
//   000 = NIL
//   001 = BOOL (bit 0 = value)
//   010 = INT (45-bit signed, shifted)
//   011 = STRING (pointer)
//   100 = ARRAY (pointer)
//   101 = OBJECT (pointer)
//   110 = TRIT (-1, 0, 1)
//   111 = TRYTE (-13..+13)
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

// Quiet NaN mask: exponent all 1s, quiet bit set
const QNAN: u64 = 0x7FFC_0000_0000_0000;

// Tag bits (bits 48-50)
const TAG_SHIFT: u6 = 45;
const TAG_MASK: u64 = 0x7 << TAG_SHIFT; // 3 bits for tag

// Payload mask (bits 0-44)
const PAYLOAD_MASK: u64 = (1 << 45) - 1; // 45 bits

// Tag values
const TAG_NIL: u64 = 0 << TAG_SHIFT;
const TAG_BOOL: u64 = 1 << TAG_SHIFT;
const TAG_INT: u64 = 2 << TAG_SHIFT;
const TAG_STRING: u64 = 3 << TAG_SHIFT;
const TAG_ARRAY: u64 = 4 << TAG_SHIFT;
const TAG_OBJECT: u64 = 5 << TAG_SHIFT;
const TAG_TRIT: u64 = 6 << TAG_SHIFT;
const TAG_TRYTE: u64 = 7 << TAG_SHIFT;

// Special values
const NIL_VALUE: u64 = QNAN | TAG_NIL;
const TRUE_VALUE: u64 = QNAN | TAG_BOOL | 1;
const FALSE_VALUE: u64 = QNAN | TAG_BOOL | 0;

// Sacred constants
pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// NaN-BOXED VALUE
// ═══════════════════════════════════════════════════════════════════════════════

pub const NanValue = packed struct {
    bits: u64,

    const Self = @This();

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTORS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create nil value
    pub inline fn nil() Self {
        return .{ .bits = NIL_VALUE };
    }

    /// Create boolean value
    pub inline fn boolean(b: bool) Self {
        return .{ .bits = if (b) TRUE_VALUE else FALSE_VALUE };
    }

    /// Create integer value (45-bit signed)
    pub inline fn int(i: i64) Self {
        // Clamp to 45-bit signed range
        const max_int: i64 = (1 << 44) - 1;
        const min_int: i64 = -(1 << 44);
        const clamped = @max(min_int, @min(max_int, i));
        // Store as unsigned with sign extension handled
        const payload: u64 = @bitCast(@as(i64, clamped) & @as(i64, @bitCast(PAYLOAD_MASK)));
        return .{ .bits = QNAN | TAG_INT | payload };
    }

    /// Create float value (native IEEE 754)
    pub inline fn float(f: f64) Self {
        return .{ .bits = @bitCast(f) };
    }

    /// Create string value (pointer)
    pub inline fn string(ptr: [*]const u8, len: usize) Self {
        // Pack pointer (assume 48-bit address space)
        _ = len; // Length stored elsewhere or in string header
        const addr: u64 = @intFromPtr(ptr);
        return .{ .bits = QNAN | TAG_STRING | (addr & PAYLOAD_MASK) };
    }

    /// Create string from slice
    pub inline fn stringSlice(s: []const u8) Self {
        return string(s.ptr, s.len);
    }

    /// Create trit value (-1, 0, 1)
    pub inline fn trit(t: i8) Self {
        const payload: u64 = @intCast(@as(u8, @bitCast(t)) & 0x3);
        return .{ .bits = QNAN | TAG_TRIT | payload };
    }

    /// Create tryte value (-13..+13)
    pub inline fn tryte(t: i8) Self {
        const payload: u64 = @intCast(@as(u8, @bitCast(t)) & 0x1F);
        return .{ .bits = QNAN | TAG_TRYTE | payload };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPE CHECKS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Check if value is a float (not a tagged NaN)
    pub inline fn isFloat(self: Self) bool {
        // A value is a float if it's not our special NaN pattern
        return (self.bits & QNAN) != QNAN;
    }

    /// Check if value is nil
    pub inline fn isNil(self: Self) bool {
        return self.bits == NIL_VALUE;
    }

    /// Check if value is boolean
    pub inline fn isBool(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_BOOL);
    }

    /// Check if value is integer
    pub inline fn isInt(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_INT);
    }

    /// Check if value is string
    pub inline fn isString(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_STRING);
    }

    /// Check if value is trit
    pub inline fn isTrit(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_TRIT);
    }

    /// Check if value is tryte
    pub inline fn isTryte(self: Self) bool {
        return (self.bits & (QNAN | TAG_MASK)) == (QNAN | TAG_TRYTE);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXTRACTORS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get float value (assumes isFloat() is true)
    pub inline fn asFloat(self: Self) f64 {
        return @bitCast(self.bits);
    }

    /// Get boolean value (assumes isBool() is true)
    pub inline fn asBool(self: Self) bool {
        return (self.bits & 1) != 0;
    }

    /// Get integer value (assumes isInt() is true)
    pub inline fn asInt(self: Self) i64 {
        const payload = self.bits & PAYLOAD_MASK;
        // Sign extend from 45 bits
        const sign_bit: u64 = 1 << 44;
        if ((payload & sign_bit) != 0) {
            // Negative number - sign extend
            return @as(i64, @bitCast(payload)) | @as(i64, @bitCast(~PAYLOAD_MASK));
        }
        return @as(i64, @bitCast(payload));
    }

    /// Get string pointer (assumes isString() is true)
    pub inline fn asStringPtr(self: Self) [*]const u8 {
        const addr = self.bits & PAYLOAD_MASK;
        return @ptrFromInt(addr);
    }

    /// Get trit value (assumes isTrit() is true)
    pub inline fn asTrit(self: Self) i8 {
        const payload: u8 = @truncate(self.bits & 0x3);
        // Sign extend from 2 bits
        return if (payload >= 2) @as(i8, @bitCast(payload)) - 4 else @as(i8, @bitCast(payload));
    }

    /// Get tryte value (assumes isTryte() is true)
    pub inline fn asTryte(self: Self) i8 {
        const payload: u8 = @truncate(self.bits & 0x1F);
        // Sign extend from 5 bits
        return if (payload >= 16) @as(i8, @bitCast(payload)) - 32 else @as(i8, @bitCast(payload));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONVERSIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Convert to integer (with type coercion)
    pub inline fn toInt(self: Self) i64 {
        if (self.isInt()) return self.asInt();
        if (self.isFloat()) return @intFromFloat(self.asFloat());
        if (self.isBool()) return if (self.asBool()) @as(i64, 1) else @as(i64, 0);
        if (self.isTrit()) return @as(i64, self.asTrit());
        if (self.isTryte()) return @as(i64, self.asTryte());
        return 0;
    }

    /// Convert to float (with type coercion)
    pub inline fn toFloat(self: Self) f64 {
        if (self.isFloat()) return self.asFloat();
        if (self.isInt()) return @floatFromInt(self.asInt());
        if (self.isBool()) return if (self.asBool()) 1.0 else 0.0;
        return 0.0;
    }

    /// Convert to boolean (truthiness)
    pub inline fn toBool(self: Self) bool {
        if (self.isNil()) return false;
        if (self.isBool()) return self.asBool();
        if (self.isInt()) return self.asInt() != 0;
        if (self.isFloat()) return self.asFloat() != 0.0;
        if (self.isTrit()) return self.asTrit() > 0; // T=true, U/F=false
        return true; // strings, arrays, objects are truthy
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARITHMETIC (INLINE FOR SPEED)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add two values
    pub inline fn add(a: Self, b: Self) Self {
        // Fast path: both integers
        if (a.isInt() and b.isInt()) {
            return int(a.asInt() + b.asInt());
        }
        // Float path
        return float(a.toFloat() + b.toFloat());
    }

    /// Subtract two values
    pub inline fn sub(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return int(a.asInt() - b.asInt());
        }
        return float(a.toFloat() - b.toFloat());
    }

    /// Multiply two values
    pub inline fn mul(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return int(a.asInt() * b.asInt());
        }
        return float(a.toFloat() * b.toFloat());
    }

    /// Divide two values
    pub inline fn div(a: Self, b: Self) Self {
        const bf = b.toFloat();
        if (bf == 0.0) return float(std.math.nan(f64));
        return float(a.toFloat() / bf);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPARISON
    // ═══════════════════════════════════════════════════════════════════════════

    /// Less than
    pub inline fn lt(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() < b.asInt());
        }
        return boolean(a.toFloat() < b.toFloat());
    }

    /// Less than or equal
    pub inline fn le(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() <= b.asInt());
        }
        return boolean(a.toFloat() <= b.toFloat());
    }

    /// Greater than
    pub inline fn gt(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() > b.asInt());
        }
        return boolean(a.toFloat() > b.toFloat());
    }

    /// Greater than or equal
    pub inline fn ge(a: Self, b: Self) Self {
        if (a.isInt() and b.isInt()) {
            return boolean(a.asInt() >= b.asInt());
        }
        return boolean(a.toFloat() >= b.toFloat());
    }

    /// Equal
    pub inline fn eq(a: Self, b: Self) Self {
        return boolean(a.bits == b.bits);
    }

    /// Not equal
    pub inline fn ne(a: Self, b: Self) Self {
        return boolean(a.bits != b.bits);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TERNARY OPERATIONS (SACRED)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Ternary NOT: T→F, F→T, U→U
    pub inline fn tritNot(self: Self) Self {
        if (self.isTrit()) {
            return trit(-self.asTrit());
        }
        return self;
    }

    /// Ternary AND (Kleene): min(a, b)
    pub inline fn tritAnd(a: Self, b: Self) Self {
        if (a.isTrit() and b.isTrit()) {
            return trit(@min(a.asTrit(), b.asTrit()));
        }
        return boolean(a.toBool() and b.toBool());
    }

    /// Ternary OR (Kleene): max(a, b)
    pub inline fn tritOr(a: Self, b: Self) Self {
        if (a.isTrit() and b.isTrit()) {
            return trit(@max(a.asTrit(), b.asTrit()));
        }
        return boolean(a.toBool() or b.toBool());
    }

    /// Tryte addition with wrap-around
    pub inline fn tryteAdd(a: Self, b: Self) Self {
        if (a.isTryte() and b.isTryte()) {
            var sum: i16 = @as(i16, a.asTryte()) + @as(i16, b.asTryte());
            // Wrap to -13..+13
            while (sum > 13) sum -= 27;
            while (sum < -13) sum += 27;
            return tryte(@intCast(sum));
        }
        return int(a.toInt() + b.toInt());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DEBUG
    // ═══════════════════════════════════════════════════════════════════════════

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
        } else if (self.isString()) {
            try writer.writeAll("<string>");
        } else {
            try writer.print("0x{X}", .{self.bits});
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NanValue nil" {
    const v = NanValue.nil();
    try std.testing.expect(v.isNil());
    try std.testing.expect(!v.isBool());
    try std.testing.expect(!v.isInt());
    try std.testing.expect(!v.isFloat());
}

test "NanValue boolean" {
    const t = NanValue.boolean(true);
    const f = NanValue.boolean(false);

    try std.testing.expect(t.isBool());
    try std.testing.expect(f.isBool());
    try std.testing.expect(t.asBool() == true);
    try std.testing.expect(f.asBool() == false);
}

test "NanValue integer" {
    const v = NanValue.int(42);
    try std.testing.expect(v.isInt());
    try std.testing.expectEqual(@as(i64, 42), v.asInt());

    const neg = NanValue.int(-100);
    try std.testing.expect(neg.isInt());
    try std.testing.expectEqual(@as(i64, -100), neg.asInt());
}

test "NanValue float" {
    const v = NanValue.float(3.14159);
    try std.testing.expect(v.isFloat());
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), v.asFloat(), 0.00001);

    const phi = NanValue.float(PHI);
    try std.testing.expectApproxEqAbs(PHI, phi.asFloat(), 0.0000001);
}

test "NanValue trit" {
    const t = NanValue.trit(1);
    const u = NanValue.trit(0);
    const f = NanValue.trit(-1);

    try std.testing.expect(t.isTrit());
    try std.testing.expectEqual(@as(i8, 1), t.asTrit());
    try std.testing.expectEqual(@as(i8, 0), u.asTrit());
    try std.testing.expectEqual(@as(i8, -1), f.asTrit());
}

test "NanValue tryte" {
    const v = NanValue.tryte(13);
    try std.testing.expect(v.isTryte());
    try std.testing.expectEqual(@as(i8, 13), v.asTryte());

    const neg = NanValue.tryte(-13);
    try std.testing.expectEqual(@as(i8, -13), neg.asTryte());
}

test "NanValue arithmetic" {
    const a = NanValue.int(10);
    const b = NanValue.int(3);

    const sum = NanValue.add(a, b);
    try std.testing.expectEqual(@as(i64, 13), sum.asInt());

    const diff = NanValue.sub(a, b);
    try std.testing.expectEqual(@as(i64, 7), diff.asInt());

    const prod = NanValue.mul(a, b);
    try std.testing.expectEqual(@as(i64, 30), prod.asInt());
}

test "NanValue comparison" {
    const a = NanValue.int(5);
    const b = NanValue.int(10);

    try std.testing.expect(NanValue.lt(a, b).asBool());
    try std.testing.expect(NanValue.le(a, b).asBool());
    try std.testing.expect(!NanValue.gt(a, b).asBool());
    try std.testing.expect(NanValue.ne(a, b).asBool());
}

test "NanValue ternary" {
    const t = NanValue.trit(1);
    const f = NanValue.trit(-1);

    // NOT
    try std.testing.expectEqual(@as(i8, -1), NanValue.tritNot(t).asTrit());
    try std.testing.expectEqual(@as(i8, 1), NanValue.tritNot(f).asTrit());

    // AND (min)
    try std.testing.expectEqual(@as(i8, -1), NanValue.tritAnd(t, f).asTrit());

    // OR (max)
    try std.testing.expectEqual(@as(i8, 1), NanValue.tritOr(t, f).asTrit());
}

test "NanValue size" {
    // NanValue must be exactly 64 bits
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(NanValue));
}
