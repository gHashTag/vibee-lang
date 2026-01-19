// crush.zig - Crush Library Index Module
// Generated from: VIBEE Transpilation Pipeline
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
//
// This module re-exports all crush components for convenient access.
// Total: 9 modules, 99 tests

const std = @import("std");

// Core Utilities
pub const ansiext = @import("ansiext.zig");
pub const stringext = @import("stringext.zig");
pub const home = @import("home.zig");

// Concurrency
pub const csync = @import("csync.zig");

// File System
pub const filepathext = @import("filepathext.zig");
pub const diff = @import("diff.zig");

// Environment
pub const env = @import("env.zig");
pub const version = @import("version.zig");

// UI
pub const format = @import("format.zig");

// Version information
pub const VERSION = "1.0.0";
pub const MODULES_COUNT = 9;
pub const TESTS_COUNT = 99;

/// Sacred constants
pub const Sacred = struct {
    pub const PHI: f64 = 1.618033988749895;
    pub const TRINITY: f64 = 3.0;
    pub const PHOENIX: u32 = 999;

    /// Verify golden identity: φ² + 1/φ² = 3
    pub fn verifyGoldenIdentity() bool {
        const phi_squared = PHI * PHI;
        const inv_phi_squared = 1.0 / phi_squared;
        const result = phi_squared + inv_phi_squared;
        return @abs(result - TRINITY) < 0.0001;
    }
};

/// Module information
pub const ModuleInfo = struct {
    name: []const u8,
    tests: u32,
    description: []const u8,
};

/// List of all modules
pub const modules = [_]ModuleInfo{
    .{ .name = "ansiext", .tests = 8, .description = "Control character escaping" },
    .{ .name = "format", .tests = 6, .description = "Spinner animation" },
    .{ .name = "home", .tests = 8, .description = "Home directory utilities" },
    .{ .name = "csync", .tests = 11, .description = "Thread-safe collections" },
    .{ .name = "stringext", .tests = 17, .description = "String manipulation" },
    .{ .name = "filepathext", .tests = 12, .description = "Smart path operations" },
    .{ .name = "env", .tests = 11, .description = "Environment abstraction" },
    .{ .name = "diff", .tests = 11, .description = "Unified diff generation" },
    .{ .name = "version", .tests = 15, .description = "Semantic versioning" },
};

/// Get total test count
pub fn getTotalTests() u32 {
    var total: u32 = 0;
    for (modules) |m| {
        total += m.tests;
    }
    return total;
}

/// Print module summary
pub fn printSummary(writer: anytype) !void {
    try writer.print("=== CRUSH LIBRARY ===\n", .{});
    try writer.print("Version: {s}\n", .{VERSION});
    try writer.print("Modules: {d}\n", .{MODULES_COUNT});
    try writer.print("Tests: {d}\n\n", .{TESTS_COUNT});

    try writer.print("Modules:\n", .{});
    for (modules) |m| {
        try writer.print("  - {s}: {s} ({d} tests)\n", .{ m.name, m.description, m.tests });
    }

    try writer.print("\nSacred Formula: V = n × 3^k × π^m × φ^p × e^q\n", .{});
    try writer.print("Golden Identity: φ² + 1/φ² = 3 (verified: {})\n", .{Sacred.verifyGoldenIdentity()});
}

// Tests
test "sacred_golden_identity" {
    try std.testing.expect(Sacred.verifyGoldenIdentity());
}

test "modules_count" {
    try std.testing.expectEqual(@as(usize, MODULES_COUNT), modules.len);
}

test "total_tests" {
    try std.testing.expectEqual(@as(u32, TESTS_COUNT), getTotalTests());
}

test "ansiext_available" {
    const result = try ansiext.escape(std.testing.allocator, "test");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("test", result);
}

test "stringext_available" {
    const result = try stringext.capitalize(std.testing.allocator, "hello");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "home_available" {
    const h = home.dir();
    try std.testing.expect(h != null);
}

test "version_available" {
    const v = version.getVersion();
    try std.testing.expect(v.len > 0);
}

test "filepathext_available" {
    try std.testing.expect(filepathext.smartIsAbs("/absolute"));
    try std.testing.expect(!filepathext.smartIsAbs("relative"));
}

test "env_available" {
    var e = env.new();
    const path = e.get("PATH");
    try std.testing.expect(path.len > 0);
}
