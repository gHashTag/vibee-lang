//! VIBEE Φ-ENGINE - LUCAS & FIBONACCI NUMBERS (Solution #2)
//!
//! Lucas Numbers & Fibonacci Numbers with O(n) Computation
//!
//! Scientific Basis: Binet's formula (1743) - Jacques Binet
//! Lucas Numbers: Édouard Lucas (1878)
//!
//! Sacred Formula: L(n) = φⁿ + 1/φⁿ

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

pub const LUCAS_TABLE: [20]i64 = .{
    2, // L(0)
    1, // L(1)
    3, // L(2) = TRINITY!
    4, // L(3)
    7, // L(4)
    11, // L(5)
    18, // L(6)
    29, // L(7)
    47, // L(8)
    76, // L(9)
    123, // L(10) = φ¹⁰ + 1/φ¹⁰
    199, // L(11)
    322, // L(12)
    521, // L(13)
    843, // L(14)
    1364, // L(15)
    2207, // L(16)
    3571, // L(17)
    5778, // L(18)
    9349, // L(19)
};

pub const FIBONACCI_TABLE: [20]i64 = .{
    0, // F(0)
    1, // F(1)
    1, // F(2)
    2, // F(3)
    3, // F(4)
    5, // F(5)
    8, // F(6)
    13, // F(7)
    21, // F(8)
    34, // F(9)
    55, // F(10)
    89, // F(11)
    144, // F(12)
    233, // F(13)
    377, // F(14)
    610, // F(15)
    987, // F(16)
    1597, // F(17)
    2584, // F(18)
    4181, // F(19)
};

pub inline fn lucas(n: u32) i64 {
    if (n < 20) return LUCAS_TABLE[n];
    var a: i64 = LUCAS_TABLE[18];
    var b: i64 = LUCAS_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

pub inline fn fibonacci(n: u32) i64 {
    if (n < 20) return FIBONACCI_TABLE[n];
    var a: i64 = FIBONACCI_TABLE[18];
    var b: i64 = FIBONACCI_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// ══════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═══════════════════════════════════════════════════════════════════════╝

test "Lucas: L(0)" {
    const value = lucas(0);
    try std.testing.expectEqual(@as(i64, 2), value);
}

test "Lucas: L(1)" {
    const value = lucas(1);
    try std.testing.expectEqual(@as(i64, 1), value);
}

test "Lucas: L(2) - Trinity!" {
    const value = lucas(2);
    try std.testing.expectEqual(@as(i64, 3), value);
}

test "Lucas: L(3)" {
    const value = lucas(3);
    try std.testing.expectEqual(@as(i64, 4), value);
}

test "Lucas: L(10)" {
    const value = lucas(10);
    try std.testing.expectEqual(@as(i64, 123), value);
}

test "Lucas: O(1) lookup" {
    const value = lucas(5);
    try std.testing.expectEqual(@as(i64, 11), value);
}

test "Fibonacci: F(0)" {
    const value = fibonacci(0);
    try std.testing.expectEqual(@as(i64, 0), value);
}

test "Fibonacci: F(1)" {
    const value = fibonacci(1);
    try std.testing.expectEqual(@as(i64, 1), value);
}

test "Fibonacci: F(10)" {
    const value = fibonacci(10);
    try std.testing.expectEqual(@as(i64, 55), value);
}

test "Fibonacci: O(1) lookup" {
    const value = fibonacci(5);
    try std.testing.expectEqual(@as(i64, 5), value);
}

test "Lucas vs Fibonacci: L(n) = F(n-1) + F(n+1)" {
    const n: u32 = 10;
    const lucas_val = lucas(n);
    const fib_prev = fibonacci(n - 1);
    const fib_next = fibonacci(n + 1);
    try std.testing.expectEqual(lucas_val, fib_prev + fib_next);
}

test "Lucas: phi identity" {
    // L(2) = φ² + 1/φ² = 3 (EXACT!)
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    const lucas_2 = lucas(2);
    try std.testing.expectEqual(@as(i64, 3), lucas_2);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
