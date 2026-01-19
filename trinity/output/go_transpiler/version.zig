// ═══════════════════════════════════════════════════════════════════════════════
// version - Generated from Go by VIBEE Transpiler
// ═══════════════════════════════════════════════════════════════════════════════
// SOURCE: github.com/charmbracelet/crush/internal/version/version.go
// SPEC: specs/crush_version.vibee
// TRI: trinity/ЦАРСТВО/ⲘⲈⲆⲚⲞⲈ/ⲅⲟ_ⲧⲣⲁⲛⲥⲡⲓⲗⲉⲣ/ⲕⲣⲩⲥⲏ_ⲩⲉⲣⲥⲓⲟⲛ.tri
// φ² + 1/φ² = 3 | PHOENIX = 999
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

/// Default version if not set at compile time
pub const default_version: []const u8 = "devel";

/// Version string - can be overridden at compile time
/// Go original: var Version = "devel"
pub const version: []const u8 = default_version;

/// Get the current version
/// Go original: Version variable access
pub fn getVersion() []const u8 {
    if (version.len == 0) {
        return default_version;
    }
    return version;
}

/// Check if running development version
pub fn isDevel() bool {
    return std.mem.eql(u8, getVersion(), "devel") or
        std.mem.eql(u8, getVersion(), "(devel)");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}

test "version not empty" {
    const v = getVersion();
    try std.testing.expect(v.len > 0);
}

test "default version is devel" {
    try std.testing.expectEqualStrings("devel", default_version);
}

test "isDevel returns true for default" {
    try std.testing.expect(isDevel());
}
