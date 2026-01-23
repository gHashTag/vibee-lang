//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ WASM Exports
//! Ternary logic functions for browser
//! φ² + 1/φ² = 3

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;

// Trit values for WASM
pub const TRIT_FALSE: i32 = -1;
pub const TRIT_UNKNOWN: i32 = 0;
pub const TRIT_TRUE: i32 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Called from JavaScript
// ═══════════════════════════════════════════════════════════════════════════════

/// Get PHI constant (golden ratio)
export fn wasm_phi() f64 {
    return PHI;
}

/// Get TRINITY constant (27 = 3³)
export fn wasm_trinity() u32 {
    return TRINITY;
}

/// Verify golden identity: φ² + 1/φ² = 3
export fn wasm_golden_identity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// Fibonacci number
export fn wasm_fibonacci(n: u32) u64 {
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

/// Lucas number
export fn wasm_lucas(n: u32) u64 {
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

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY LOGIC OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit NOT: ¬x
export fn wasm_trit_not(x: i32) i32 {
    return -x;
}

/// Trit AND (Kleene): min(a, b)
export fn wasm_trit_and(a: i32, b: i32) i32 {
    return @min(a, b);
}

/// Trit OR (Kleene): max(a, b)
export fn wasm_trit_or(a: i32, b: i32) i32 {
    return @max(a, b);
}

/// Trit XOR
export fn wasm_trit_xor(a: i32, b: i32) i32 {
    if (a == 0 or b == 0) return 0;
    if (a == b) return -1;
    return 1;
}

/// Trit IMPLIES: ¬a ∨ b
export fn wasm_trit_implies(a: i32, b: i32) i32 {
    return wasm_trit_or(-a, b);
}

/// Trit EQUIV: (a → b) ∧ (b → a)
export fn wasm_trit_equiv(a: i32, b: i32) i32 {
    return wasm_trit_and(wasm_trit_implies(a, b), wasm_trit_implies(b, a));
}

/// Check if trit is true
export fn wasm_trit_is_true(x: i32) i32 {
    return if (x == 1) 1 else 0;
}

/// Check if trit is false
export fn wasm_trit_is_false(x: i32) i32 {
    return if (x == -1) 1 else 0;
}

/// Check if trit is unknown
export fn wasm_trit_is_unknown(x: i32) i32 {
    return if (x == 0) 1 else 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COPTIC UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert Coptic codepoint to index (0-26)
export fn wasm_coptic_to_index(codepoint: u32) i32 {
    if (codepoint >= 0x2C80 and codepoint <= 0x2C9A) {
        return @intCast(codepoint - 0x2C80);
    }
    return -1;
}

/// Convert index (0-26) to Coptic codepoint
export fn wasm_index_to_coptic(index: u32) u32 {
    if (index < 27) return 0x2C80 + index;
    return 0;
}

/// Get Coptic group (0, 1, or 2) for index
export fn wasm_coptic_group(index: u32) u32 {
    if (index < 9) return 0;
    if (index < 18) return 1;
    if (index < 27) return 2;
    return 3;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "wasm phi" {
    try std.testing.expect(wasm_phi() > 1.618 and wasm_phi() < 1.619);
}

test "wasm golden identity" {
    const result = wasm_golden_identity();
    try std.testing.expect(result > 2.99 and result < 3.01);
}

test "wasm fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), wasm_fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), wasm_fibonacci(1));
    try std.testing.expectEqual(@as(u64, 55), wasm_fibonacci(10));
}

test "wasm trit not" {
    try std.testing.expectEqual(@as(i32, -1), wasm_trit_not(1));
    try std.testing.expectEqual(@as(i32, 0), wasm_trit_not(0));
    try std.testing.expectEqual(@as(i32, 1), wasm_trit_not(-1));
}

test "wasm trit and" {
    try std.testing.expectEqual(@as(i32, 1), wasm_trit_and(1, 1));
    try std.testing.expectEqual(@as(i32, -1), wasm_trit_and(1, -1));
    try std.testing.expectEqual(@as(i32, 0), wasm_trit_and(1, 0));
}

test "wasm trit or" {
    try std.testing.expectEqual(@as(i32, 1), wasm_trit_or(1, -1));
    try std.testing.expectEqual(@as(i32, -1), wasm_trit_or(-1, -1));
    try std.testing.expectEqual(@as(i32, 1), wasm_trit_or(1, 0));
}

test "wasm coptic index" {
    try std.testing.expectEqual(@as(i32, 0), wasm_coptic_to_index(0x2C80));
    try std.testing.expectEqual(@as(i32, 26), wasm_coptic_to_index(0x2C9A));
    try std.testing.expectEqual(@as(i32, -1), wasm_coptic_to_index(0x0041));
}
