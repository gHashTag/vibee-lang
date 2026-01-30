//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Ternary Logic Implementation
//! Trit: -1 (false/▽), 0 (unknown/○), +1 (true/△)
//! Kleene and Łukasiewicz three-valued logics
//! φ² + 1/φ² = 3

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;

/// Trit: Ternary digit with values -1, 0, +1
pub const Trit = enum(i8) {
    false_ = -1,  // ▽
    unknown = 0,  // ○
    true_ = 1,    // △
    
    pub const FALSE = Trit.false_;
    pub const UNKNOWN = Trit.unknown;
    pub const TRUE = Trit.true_;
    
    /// Create from integer (-1, 0, 1)
    pub fn fromInt(v: i8) Trit {
        if (v < 0) return .false_;
        if (v > 0) return .true_;
        return .unknown;
    }
    
    /// Convert to integer
    pub fn toInt(self: Trit) i8 {
        return @intFromEnum(self);
    }
    
    /// Get symbol representation
    pub fn symbol(self: Trit) []const u8 {
        return switch (self) {
            .false_ => "▽",
            .unknown => "○",
            .true_ => "△",
        };
    }
    
    /// Kleene NOT: ¬x
    pub fn not(self: Trit) Trit {
        return fromInt(-self.toInt());
    }
    
    /// Kleene AND: min(a, b)
    pub fn @"and"(a: Trit, b: Trit) Trit {
        return fromInt(@min(a.toInt(), b.toInt()));
    }
    
    /// Kleene OR: max(a, b)
    pub fn @"or"(a: Trit, b: Trit) Trit {
        return fromInt(@max(a.toInt(), b.toInt()));
    }
    
    /// Kleene XOR: a ⊕ b
    pub fn xor(a: Trit, b: Trit) Trit {
        if (a == .unknown or b == .unknown) return .unknown;
        if (a == b) return .false_;
        return .true_;
    }
    
    /// Kleene implication: a → b = ¬a ∨ b
    pub fn implies(a: Trit, b: Trit) Trit {
        return a.not().@"or"(b);
    }
    
    /// Kleene equivalence: a ↔ b
    pub fn equiv(a: Trit, b: Trit) Trit {
        return a.implies(b).@"and"(b.implies(a));
    }
    
    /// Łukasiewicz implication: min(1, 1 - a + b)
    pub fn lukasiewiczImplies(a: Trit, b: Trit) Trit {
        const result = 1 - a.toInt() + b.toInt();
        if (result >= 1) return .true_;
        if (result <= -1) return .false_;
        return .unknown;
    }
    
    /// Consensus: returns value if a == b, else unknown
    pub fn consensus(a: Trit, b: Trit) Trit {
        if (a == b) return a;
        return .unknown;
    }
    
    /// Accept: true if definitely true
    pub fn isTrue(self: Trit) bool {
        return self == .true_;
    }
    
    /// Reject: true if definitely false
    pub fn isFalse(self: Trit) bool {
        return self == .false_;
    }
    
    /// Unknown: true if unknown
    pub fn isUnknown(self: Trit) bool {
        return self == .unknown;
    }
    
    /// Definite: true if not unknown
    pub fn isDefinite(self: Trit) bool {
        return self != .unknown;
    }
};

/// Tryte: 3 trits (27 possible values)
pub const Tryte = struct {
    trits: [3]Trit,
    
    pub fn init(t0: Trit, t1: Trit, t2: Trit) Tryte {
        return .{ .trits = .{ t0, t1, t2 } };
    }
    
    pub fn fromInt(v: i8) Tryte {
        var val = v;
        var result: [3]Trit = undefined;
        for (0..3) |i| {
            const rem = @mod(val + 1, 3) - 1;
            result[i] = Trit.fromInt(@intCast(rem));
            val = @divTrunc(val - rem, 3);
        }
        return .{ .trits = result };
    }
    
    pub fn toInt(self: Tryte) i8 {
        var result: i8 = 0;
        var mult: i8 = 1;
        for (self.trits) |t| {
            result += t.toInt() * mult;
            mult *= 3;
        }
        return result;
    }
    
    /// Trit-wise NOT
    pub fn not(self: Tryte) Tryte {
        return .{ .trits = .{
            self.trits[0].not(),
            self.trits[1].not(),
            self.trits[2].not(),
        }};
    }
    
    /// Trit-wise AND
    pub fn @"and"(a: Tryte, b: Tryte) Tryte {
        return .{ .trits = .{
            a.trits[0].@"and"(b.trits[0]),
            a.trits[1].@"and"(b.trits[1]),
            a.trits[2].@"and"(b.trits[2]),
        }};
    }
    
    /// Trit-wise OR
    pub fn @"or"(a: Tryte, b: Tryte) Tryte {
        return .{ .trits = .{
            a.trits[0].@"or"(b.trits[0]),
            a.trits[1].@"or"(b.trits[1]),
            a.trits[2].@"or"(b.trits[2]),
        }};
    }
};

/// TritVec27: Vector of 27 trits (3³ = trinity)
pub const TritVec27 = struct {
    data: [27]Trit,
    
    pub fn init() TritVec27 {
        return .{ .data = [_]Trit{.unknown} ** 27 };
    }
    
    pub fn set(self: *TritVec27, index: u5, value: Trit) void {
        if (index < 27) self.data[index] = value;
    }
    
    pub fn get(self: TritVec27, index: u5) Trit {
        if (index < 27) return self.data[index];
        return .unknown;
    }
    
    /// Count true trits
    pub fn countTrue(self: TritVec27) u8 {
        var count: u8 = 0;
        for (self.data) |t| if (t == .true_) { count += 1; };
        return count;
    }
    
    /// Count false trits
    pub fn countFalse(self: TritVec27) u8 {
        var count: u8 = 0;
        for (self.data) |t| if (t == .false_) { count += 1; };
        return count;
    }
    
    /// Count unknown trits
    pub fn countUnknown(self: TritVec27) u8 {
        var count: u8 = 0;
        for (self.data) |t| if (t == .unknown) { count += 1; };
        return count;
    }
    
    /// Vector NOT
    pub fn not(self: TritVec27) TritVec27 {
        var result: TritVec27 = undefined;
        for (0..27) |i| result.data[i] = self.data[i].not();
        return result;
    }
    
    /// Vector AND
    pub fn @"and"(a: TritVec27, b: TritVec27) TritVec27 {
        var result: TritVec27 = undefined;
        for (0..27) |i| result.data[i] = a.data[i].@"and"(b.data[i]);
        return result;
    }
    
    /// Vector OR
    pub fn @"or"(a: TritVec27, b: TritVec27) TritVec27 {
        var result: TritVec27 = undefined;
        for (0..27) |i| result.data[i] = a.data[i].@"or"(b.data[i]);
        return result;
    }
};

// Tests
test "trit basic" {
    try std.testing.expectEqual(Trit.TRUE.toInt(), 1);
    try std.testing.expectEqual(Trit.FALSE.toInt(), -1);
    try std.testing.expectEqual(Trit.UNKNOWN.toInt(), 0);
}

test "trit not" {
    try std.testing.expectEqual(Trit.TRUE.not(), Trit.FALSE);
    try std.testing.expectEqual(Trit.FALSE.not(), Trit.TRUE);
    try std.testing.expectEqual(Trit.UNKNOWN.not(), Trit.UNKNOWN);
}

test "trit and (Kleene)" {
    try std.testing.expectEqual(Trit.TRUE.@"and"(Trit.TRUE), Trit.TRUE);
    try std.testing.expectEqual(Trit.TRUE.@"and"(Trit.FALSE), Trit.FALSE);
    try std.testing.expectEqual(Trit.TRUE.@"and"(Trit.UNKNOWN), Trit.UNKNOWN);
    try std.testing.expectEqual(Trit.FALSE.@"and"(Trit.UNKNOWN), Trit.FALSE);
}

test "trit or (Kleene)" {
    try std.testing.expectEqual(Trit.TRUE.@"or"(Trit.FALSE), Trit.TRUE);
    try std.testing.expectEqual(Trit.FALSE.@"or"(Trit.FALSE), Trit.FALSE);
    try std.testing.expectEqual(Trit.FALSE.@"or"(Trit.UNKNOWN), Trit.UNKNOWN);
    try std.testing.expectEqual(Trit.TRUE.@"or"(Trit.UNKNOWN), Trit.TRUE);
}

test "trit xor" {
    try std.testing.expectEqual(Trit.TRUE.xor(Trit.FALSE), Trit.TRUE);
    try std.testing.expectEqual(Trit.TRUE.xor(Trit.TRUE), Trit.FALSE);
    try std.testing.expectEqual(Trit.TRUE.xor(Trit.UNKNOWN), Trit.UNKNOWN);
}

test "trit implies" {
    try std.testing.expectEqual(Trit.FALSE.implies(Trit.FALSE), Trit.TRUE);
    try std.testing.expectEqual(Trit.FALSE.implies(Trit.TRUE), Trit.TRUE);
    try std.testing.expectEqual(Trit.TRUE.implies(Trit.FALSE), Trit.FALSE);
}

test "tryte" {
    const t = Tryte.init(Trit.TRUE, Trit.FALSE, Trit.UNKNOWN);
    try std.testing.expectEqual(t.trits[0], Trit.TRUE);
    try std.testing.expectEqual(t.trits[1], Trit.FALSE);
}

test "tritvec27" {
    var v = TritVec27.init();
    try std.testing.expectEqual(v.countUnknown(), 27);
    v.set(0, Trit.TRUE);
    v.set(1, Trit.FALSE);
    try std.testing.expectEqual(v.countTrue(), 1);
    try std.testing.expectEqual(v.countFalse(), 1);
    try std.testing.expectEqual(v.countUnknown(), 25);
}

test "phi constant" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}

test "trinity constant" {
    try std.testing.expectEqual(TRINITY, 27);
}
