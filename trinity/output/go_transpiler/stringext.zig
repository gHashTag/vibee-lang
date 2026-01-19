// ═══════════════════════════════════════════════════════════════════════════════
// stringext - Generated from Go by VIBEE Transpiler
// ═══════════════════════════════════════════════════════════════════════════════
// SOURCE: github.com/charmbracelet/crush/internal/stringext/string.go
// SPEC: specs/crush_stringext.vibee
// TRI: trinity/ЦАРСТВО/ⲘⲈⲆⲚⲞⲈ/ⲅⲟ_ⲧⲣⲁⲛⲥⲡⲓⲗⲉⲣ/ⲕⲣⲩⲥⲏ_ⲥⲧⲣⲓⲛⲅⲉⲝⲧ.tri
// φ² + 1/φ² = 3 | PHOENIX = 999
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

/// Capitalize converts text to title case (ASCII only)
/// Go original: cases.Title(language.English, cases.Compact).String(text)
pub fn capitalize(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) return try allocator.alloc(u8, 0);

    var result = try allocator.alloc(u8, text.len);
    var prev_space = true;

    for (text, 0..) |c, i| {
        if (prev_space and c >= 'a' and c <= 'z') {
            result[i] = c - 32; // to uppercase
        } else if (!prev_space and c >= 'A' and c <= 'Z') {
            result[i] = c + 32; // to lowercase
        } else {
            result[i] = c;
        }
        prev_space = (c == ' ' or c == '\t' or c == '\n');
    }

    return result;
}

/// ContainsAny returns true if str contains any of the args
/// Go original: strings.Contains(str, arg)
pub fn containsAny(str: []const u8, args: []const []const u8) bool {
    for (args) |arg| {
        if (std.mem.indexOf(u8, str, arg) != null) {
            return true;
        }
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}

test "capitalize hello world" {
    const allocator = std.testing.allocator;
    const result = try capitalize(allocator, "hello world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello World", result);
}

test "capitalize empty" {
    const allocator = std.testing.allocator;
    const result = try capitalize(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "containsAny found" {
    const args = [_][]const u8{ "world", "foo" };
    try std.testing.expect(containsAny("hello world", &args));
}

test "containsAny not found" {
    const args = [_][]const u8{ "bar", "foo" };
    try std.testing.expect(!containsAny("hello world", &args));
}

test "containsAny empty args" {
    const args = [_][]const u8{};
    try std.testing.expect(!containsAny("hello", &args));
}
