// ═══════════════════════════════════════════════════════════════════════════════
// filepathext - Generated from Go by VIBEE Transpiler
// ═══════════════════════════════════════════════════════════════════════════════
// SOURCE: github.com/charmbracelet/crush/internal/filepathext/filepath.go
// SPEC: specs/crush_filepathext.vibee
// TRI: trinity/ЦАРСТВО/ⲘⲈⲆⲚⲞⲈ/ⲅⲟ_ⲧⲣⲁⲛⲥⲡⲓⲗⲉⲣ/ⲕⲣⲩⲥⲏ_ⲫⲓⲗⲉⲡⲁⲧⲏⲉⲝⲧ.tri
// φ² + 1/φ² = 3 | PHOENIX = 999
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

/// SmartJoin joins two paths, treating the second path as absolute if it is.
/// Go original: filepath.Join(one, two)
pub fn smartJoin(allocator: std.mem.Allocator, one: []const u8, two: []const u8) ![]u8 {
    if (smartIsAbs(two)) {
        return try allocator.dupe(u8, two);
    }

    // Join paths
    var paths = [_][]const u8{ one, two };
    return try std.fs.path.join(allocator, &paths);
}

/// SmartIsAbs checks if a path is absolute (cross-platform).
/// Go original: filepath.IsAbs(path)
pub fn smartIsAbs(path: []const u8) bool {
    if (path.len == 0) return false;

    switch (builtin.os.tag) {
        .windows => {
            // Check for Windows absolute paths (C:\, D:\, etc.)
            if (path.len >= 2 and path[1] == ':') return true;
            // Also check for Unix-style absolute paths
            return path[0] == '/' or path[0] == '\\';
        },
        else => {
            return path[0] == '/';
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}

test "smartIsAbs unix absolute" {
    try std.testing.expect(smartIsAbs("/home/user"));
}

test "smartIsAbs relative" {
    try std.testing.expect(!smartIsAbs("relative/path"));
}

test "smartIsAbs dot relative" {
    try std.testing.expect(!smartIsAbs("./path"));
}

test "smartIsAbs empty" {
    try std.testing.expect(!smartIsAbs(""));
}

test "smartJoin relative" {
    const allocator = std.testing.allocator;
    const result = try smartJoin(allocator, "/home", "user");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/home/user", result);
}

test "smartJoin absolute second" {
    const allocator = std.testing.allocator;
    const result = try smartJoin(allocator, "/home", "/etc");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/etc", result);
}
