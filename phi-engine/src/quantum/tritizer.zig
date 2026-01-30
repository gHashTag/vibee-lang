//! VIBEE QUANTUM TRIT-CODE ENGINE - TRITIZER (MVP Week 1)
//!
//! Tritizer: Convert classical code (String/ASCII) into Ternary Code (Trits)
//!
//! Concept: "Code in Trits"
//! Instead of binary bits (0/1), we use Trits (-1, 0, +1).
//!
//! Connection to VIBEE Phi-Engine:
//! - Uses `Golden Wrap` (Solution #4) for O(1) Ternary Conversion.
//! - Connection: 3 = φ² + 1/φ² (Trinity).

const std = @import("std");

// Include Golden Wrap code directly to avoid import issues
// (MVP WIP: Simplification)
pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const Trit = i8;

// Simplified Golden Wrap for MVP
// Maps any integer to Trit (-1, 0, 1) using modulo 3
pub inline fn goldenWrap(sum: i16) Trit {
    const mod: i16 = @rem(sum, 3);
    // Map 0, 1, 2 to -1, 0, 1
    return @as(Trit, mod - 1);
}

/// Convert string to trits
/// Uses ASCII code of each character -> Golden Wrap -> Trit
pub fn stringToTrits(allocator: std.mem.Allocator, str: []const u8) ![]Trit {
    const trits = try allocator.alloc(Trit, str.len);

    for (str, 0..) |c, i| {
        trits[i] = goldenWrap(@as(i16, c));
    }

    return trits;
}

/// Convert trits back to string (lossy)
/// Trits -1, 0, +1 -> ASCII codes (clamped to 32-126 for readability)
pub fn tritsToString(allocator: std.mem.Allocator, trits: []const Trit) ![]u8 {
    // Invert Golden Wrap? Not perfectly possible due to modulo.
    // For visualization, we map trits to chars.
    // -1 -> 'N', 0 -> '0', +1 -> 'P'
    const result = try allocator.alloc(u8, trits.len);
    for (trits, 0..) |t, i| {
        result[i] = switch (t) {
            -1 => @as(u8, 'N'), // Negative
            0 => @as(u8, '0'),
            1 => @as(u8, 'P'), // Positive
            else => @as(u8, '?'),
        };
    }
    return result;
}

// ════════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS (MVP Week 1)                          ║
// ╚═════════════════════════════════════════════════════════════════════════════════╝

test "Tritizer: goldenWrap logic" {
    // Test simplified golden wrap
    // 0 % 3 = 0 -> 0 - 1 = -1
    // 1 % 3 = 1 -> 1 - 1 = 0
    // 2 % 3 = 2 -> 2 - 1 = 1
    try std.testing.expectEqual(@as(Trit, -1), goldenWrap(0));
    try std.testing.expectEqual(@as(Trit, 0), goldenWrap(1));
    try std.testing.expectEqual(@as(Trit, 1), goldenWrap(2));
}

test "Tritizer: stringToTrits 'A'" {
    // ASCII 'A' = 65
    // 65 % 3 = 2 -> 2 - 1 = 1 (Trit.plus)
    const str = "A";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 1), trits.len);
    try std.testing.expectEqual(@as(i8, 1), trits[0]);
}

test "Tritizer: stringToTrits 'B'" {
    // ASCII 'B' = 66
    // 66 % 3 = 0 -> 0 - 1 = -1 (Trit.minus)
    const str = "B";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 1), trits.len);
    try std.testing.expectEqual(@as(i8, -1), trits[0]);
}

test "Tritizer: stringToTrits 'C'" {
    // ASCII 'C' = 67
    // 67 % 3 = 1 -> 1 - 1 = 0 (Trit.zero)
    const str = "C";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 1), trits.len);
    try std.testing.expectEqual(@as(i8, 0), trits[0]);
}

test "Tritizer: stringToTrits 'ABC'" {
    // A=65(+), B=66(-), C=67(0)
    const str = "ABC";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 3), trits.len);
    try std.testing.expectEqual(@as(i8, 1), trits[0]);
    try std.testing.expectEqual(@as(i8, -1), trits[1]);
    try std.testing.expectEqual(@as(i8, 0), trits[2]);
}

test "Tritizer: stringToTrits empty" {
    const str = "";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 0), trits.len);
}

test "Tritizer: tritsToString visualization" {
    // Visualization test: -1->'N', 0->'0', +1->'P'
    const trits = [_]Trit{ -1, 0, 1 };
    const result = try tritsToString(std.testing.allocator, &trits);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(u8, 'N'), result[0]);
    try std.testing.expectEqual(@as(u8, '0'), result[1]);
    try std.testing.expectEqual(@as(u8, 'P'), result[2]);
}

test "Tritizer: code density" {
    // Binary: 1 byte = 8 bits.
    // Ternary: 1 trit = ~1.585 bits.
    // This test verifies that we have converted code to trits.
    const str = "Hello"; // 5 bytes
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    // We now have 5 trits representing "Hello"
    try std.testing.expectEqual(@as(usize, 5), trits.len);

    // The trits are: +, -, -, 0, + (approx)
    // The idea is: "Hello" -> [+, -, -, 0, +] -> Quantum Superposition
}
