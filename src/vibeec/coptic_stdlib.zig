//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Standard Library
//! Math, strings, collections, I/O
//! φ² + 1/φ² = 3

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_SQUARED: f64 = PHI * PHI;
pub const PHI_INVERSE: f64 = 1.0 / PHI;
pub const TRINITY: u32 = 27;
pub const PHOENIX: u32 = 999;
pub const SACRED_3: u32 = 3;
pub const SACRED_9: u32 = 9;

// ═══════════════════════════════════════════════════════════════════════════════
// MATH MODULE
// ═══════════════════════════════════════════════════════════════════════════════

pub const math = struct {
    /// Golden ratio φ
    pub fn phi() f64 {
        return PHI;
    }
    
    /// Golden identity: φ² + 1/φ² = 3
    pub fn goldenIdentity() f64 {
        return PHI_SQUARED + 1.0 / PHI_SQUARED;
    }
    
    /// Fibonacci number F(n)
    pub fn fibonacci(n: u32) u64 {
        if (n <= 1) return n;
        var a: u64 = 0;
        var b: u64 = 1;
        var i: u32 = 2;
        while (i <= n) : (i += 1) {
            const c = a + b;
            a = b;
            b = c;
        }
        return b;
    }
    
    /// Lucas number L(n)
    pub fn lucas(n: u32) u64 {
        if (n == 0) return 2;
        if (n == 1) return 1;
        var a: u64 = 2;
        var b: u64 = 1;
        var i: u32 = 2;
        while (i <= n) : (i += 1) {
            const c = a + b;
            a = b;
            b = c;
        }
        return b;
    }
    
    /// Check if n is a Fibonacci number
    pub fn isFibonacci(n: u64) bool {
        // n is Fibonacci if 5n² + 4 or 5n² - 4 is a perfect square
        const sq1 = 5 * n * n + 4;
        const sq2 = 5 * n * n - 4;
        return isPerfectSquare(sq1) or isPerfectSquare(sq2);
    }
    
    fn isPerfectSquare(n: u64) bool {
        if (n == 0) return true;
        const root = std.math.sqrt(@as(f64, @floatFromInt(n)));
        const r: u64 = @intFromFloat(root);
        return r * r == n;
    }
    
    /// Power of 3: 3^n
    pub fn powerOf3(n: u32) u64 {
        var result: u64 = 1;
        var i: u32 = 0;
        while (i < n) : (i += 1) {
            result *= 3;
        }
        return result;
    }
    
    /// Check if n is a power of 3
    pub fn isPowerOf3(n: u64) bool {
        if (n == 0) return false;
        var x = n;
        while (x > 1) {
            if (x % 3 != 0) return false;
            x /= 3;
        }
        return true;
    }
    
    /// Sacred number check (divisible by 3, 9, or 27)
    pub fn isSacred(n: u64) bool {
        return n % 3 == 0;
    }
    
    /// Trinity number check (divisible by 27)
    pub fn isTrinity(n: u64) bool {
        return n % 27 == 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STRING MODULE
// ═══════════════════════════════════════════════════════════════════════════════

pub const string = struct {
    /// Check if string contains Coptic characters
    pub fn hasCoptic(s: []const u8) bool {
        var i: usize = 0;
        while (i < s.len) {
            const cp = decodeUtf8(s[i..]);
            if (cp.codepoint) |c| {
                if (c >= 0x2C80 and c <= 0x2CFF) return true;
            }
            i += cp.len;
        }
        return false;
    }
    
    /// Check if string contains trit symbols
    pub fn hasTrit(s: []const u8) bool {
        var i: usize = 0;
        while (i < s.len) {
            const cp = decodeUtf8(s[i..]);
            if (cp.codepoint) |c| {
                if (c == 0x25B3 or c == 0x25CB or c == 0x25BD) return true;
            }
            i += cp.len;
        }
        return false;
    }
    
    /// Count Coptic characters in string
    pub fn countCoptic(s: []const u8) u32 {
        var count: u32 = 0;
        var i: usize = 0;
        while (i < s.len) {
            const cp = decodeUtf8(s[i..]);
            if (cp.codepoint) |c| {
                if (c >= 0x2C80 and c <= 0x2CFF) count += 1;
            }
            i += cp.len;
        }
        return count;
    }
    
    fn decodeUtf8(bytes: []const u8) struct { codepoint: ?u21, len: u8 } {
        if (bytes.len == 0) return .{ .codepoint = null, .len = 0 };
        const b0 = bytes[0];
        if (b0 < 0x80) return .{ .codepoint = b0, .len = 1 };
        if (b0 & 0xE0 == 0xC0 and bytes.len >= 2) {
            return .{ .codepoint = (@as(u21, b0 & 0x1F) << 6) | (bytes[1] & 0x3F), .len = 2 };
        }
        if (b0 & 0xF0 == 0xE0 and bytes.len >= 3) {
            return .{ .codepoint = (@as(u21, b0 & 0x0F) << 12) | (@as(u21, bytes[1] & 0x3F) << 6) | (bytes[2] & 0x3F), .len = 3 };
        }
        return .{ .codepoint = null, .len = 1 };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COPTIC MODULE
// ═══════════════════════════════════════════════════════════════════════════════

pub const coptic = struct {
    pub const ALPHABET = "ⲁⲃⲅⲇⲉⲍⲏⲑⲓⲕⲗⲙⲛⲝⲟⲡⲣⲥⲧⲩⲫⲭⲯⲱϣϩϫ";
    pub const GROUP_1 = "ⲁⲃⲅⲇⲉⲍⲏⲑⲓ"; // 0-8
    pub const GROUP_2 = "ⲕⲗⲙⲛⲝⲟⲡⲣⲥ"; // 9-17
    pub const GROUP_3 = "ⲧⲩⲫⲭⲯⲱϣϩϫ"; // 18-26
    
    /// Convert codepoint to index (0-26)
    pub fn toIndex(codepoint: u21) ?u8 {
        if (codepoint >= 0x2C80 and codepoint <= 0x2C9A) {
            return @intCast(codepoint - 0x2C80);
        }
        return null;
    }
    
    /// Convert index to codepoint
    pub fn fromIndex(index: u8) ?u21 {
        if (index < 27) return 0x2C80 + index;
        return null;
    }
    
    /// Get group (0, 1, 2) for index
    pub fn group(index: u8) u8 {
        if (index < 9) return 0;
        if (index < 18) return 1;
        return 2;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "math phi" {
    try std.testing.expect(math.phi() > 1.618 and math.phi() < 1.619);
}

test "math golden identity" {
    const result = math.goldenIdentity();
    try std.testing.expect(result > 2.99 and result < 3.01);
}

test "math fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), math.fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), math.fibonacci(1));
    try std.testing.expectEqual(@as(u64, 55), math.fibonacci(10));
    try std.testing.expectEqual(@as(u64, 6765), math.fibonacci(20));
}

test "math lucas" {
    try std.testing.expectEqual(@as(u64, 2), math.lucas(0));
    try std.testing.expectEqual(@as(u64, 1), math.lucas(1));
    try std.testing.expectEqual(@as(u64, 123), math.lucas(10));
}

test "math power of 3" {
    try std.testing.expectEqual(@as(u64, 1), math.powerOf3(0));
    try std.testing.expectEqual(@as(u64, 3), math.powerOf3(1));
    try std.testing.expectEqual(@as(u64, 27), math.powerOf3(3));
}

test "math is sacred" {
    try std.testing.expect(math.isSacred(27));
    try std.testing.expect(math.isSacred(999));
    try std.testing.expect(!math.isSacred(10));
}

test "string has coptic" {
    try std.testing.expect(string.hasCoptic("ⲁⲃⲅ"));
    try std.testing.expect(!string.hasCoptic("abc"));
}

test "string has trit" {
    try std.testing.expect(string.hasTrit("△○▽"));
    try std.testing.expect(!string.hasTrit("abc"));
}

test "coptic index" {
    try std.testing.expectEqual(@as(?u8, 0), coptic.toIndex(0x2C80));
    try std.testing.expectEqual(@as(?u8, 26), coptic.toIndex(0x2C9A));
}

test "coptic group" {
    try std.testing.expectEqual(@as(u8, 0), coptic.group(0));
    try std.testing.expectEqual(@as(u8, 1), coptic.group(9));
    try std.testing.expectEqual(@as(u8, 2), coptic.group(18));
}
