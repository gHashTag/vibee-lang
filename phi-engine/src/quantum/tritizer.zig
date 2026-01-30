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
const golden_wrap = @import("../core/tvc/golden_wrap.zig");

/// Re-export Trit type for convenience
pub const Trit = golden_wrap.Trit;

/// Convert string to trits
/// Uses ASCII code of each character -> Golden Wrap -> Trit
pub fn stringToTrits(allocator: std.mem.Allocator, str: []const u8) ![]Trit {
    const trits = try allocator.alloc(Trit, str.len);

    for (str, 0..) |c, i| {
        trits[i] = golden_wrap.goldenWrap(@as(i64, c));
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
            .minus => @as(u8, 'N'), // Negative
            .zero => @as(u8, '0'),
            .plus => @as(u8, 'P'), // Positive
        };
    }
    return result;
}

// ═════════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS (MVP Week 1)                          ║
// ╚════════════════════════════════════════════════════════════════════════════════╝

test "Tritizer: stringToTrits 'A'" {
    // ASCII 'A' = 65
    // Golden Wrap(65) -> Trit
    // 65 % 3 = 2 -> .plus
    const str = "A";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 1), trits.len);
    try std.testing.expectEqual(Trit.plus, trits[0]);
}

test "Tritizer: stringToTrits 'ABC'" {
    // A=65(2->+), B=66(0->0), C=67(1->-)
    const str = "ABC";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 3), trits.len);
    try std.testing.expectEqual(Trit.plus, trits[0]);
    try std.testing.expectEqual(Trit.zero, trits[1]);
    try std.testing.expectEqual(Trit.minus, trits[2]);
}

test "Tritizer: stringToTrits empty" {
    const str = "";
    const trits = try stringToTrits(std.testing.allocator, str);
    defer std.testing.allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 0), trits.len);
}

test "Tritizer: tritsToString visualization" {
    // Visualization test: -1->'N', 0->'0', +1->'P'
    const trits = [_]Trit{ .minus, .zero, .plus };
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

    // The trits are: +, +, -, -, 0 (approx)
    // The idea is: "Hello" -> [+, +, -, -, 0] -> Quantum Superposition
}
