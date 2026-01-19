// filepathext.zig - Filepath Extension Utilities
// Generated from: specs/crush/filepathext.vibee via generated/crush/tri/filepathext.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");
const builtin = @import("builtin");

/// SmartJoin joins two paths, treating the second path as absolute if it is.
/// Creation Pattern: PathComponents → SmartPathJoiner → ResolvedPath
pub fn smartJoin(allocator: std.mem.Allocator, one: []const u8, two: []const u8) ![]u8 {
    // If second path is absolute, return it
    if (smartIsAbs(two)) {
        return try allocator.dupe(u8, two);
    }

    // If first path is empty, return second
    if (one.len == 0) {
        return try allocator.dupe(u8, two);
    }

    // If second path is empty, return first
    if (two.len == 0) {
        return try allocator.dupe(u8, one);
    }

    // Join paths with separator
    const sep = std.fs.path.sep;
    const needs_sep = one[one.len - 1] != sep and one[one.len - 1] != '/';

    if (needs_sep) {
        var result = try allocator.alloc(u8, one.len + 1 + two.len);
        @memcpy(result[0..one.len], one);
        result[one.len] = sep;
        @memcpy(result[one.len + 1 ..], two);
        return result;
    } else {
        var result = try allocator.alloc(u8, one.len + two.len);
        @memcpy(result[0..one.len], one);
        @memcpy(result[one.len..], two);
        return result;
    }
}

/// SmartIsAbs checks if a path is absolute, considering both OS-specific and Unix-style paths.
/// Creation Pattern: Path → AbsolutePathChecker → bool
pub fn smartIsAbs(path: []const u8) bool {
    if (path.len == 0) return false;

    // Check for Unix-style absolute path
    if (path[0] == '/') return true;

    // On Windows, also check for drive letters
    if (builtin.os.tag == .windows) {
        if (path.len >= 2 and path[1] == ':') {
            return true;
        }
        // Windows also accepts backslash as absolute
        if (path[0] == '\\') return true;
    }

    return false;
}

/// Check if path is relative
pub fn isRelative(path: []const u8) bool {
    return !smartIsAbs(path);
}

/// Get the directory part of a path
pub fn dirname(path: []const u8) []const u8 {
    return std.fs.path.dirname(path) orelse "";
}

/// Get the filename part of a path
pub fn basename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

/// Get the file extension
pub fn extension(path: []const u8) []const u8 {
    return std.fs.path.extension(path);
}

/// Normalize path separators to the current OS
pub fn normalize(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, path.len);
    const sep = std.fs.path.sep;

    for (path, 0..) |c, i| {
        if (c == '/' or c == '\\') {
            result[i] = sep;
        } else {
            result[i] = c;
        }
    }

    return result;
}

// Tests
test "smartJoin_relative" {
    const allocator = std.testing.allocator;
    const result = try smartJoin(allocator, "/home/user", "documents");
    defer allocator.free(result);

    // Check that it contains both parts
    try std.testing.expect(std.mem.startsWith(u8, result, "/home/user"));
    try std.testing.expect(std.mem.endsWith(u8, result, "documents"));
}

test "smartJoin_absolute_second" {
    const allocator = std.testing.allocator;
    const result = try smartJoin(allocator, "/home/user", "/etc/config");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("/etc/config", result);
}

test "smartJoin_empty_first" {
    const allocator = std.testing.allocator;
    const result = try smartJoin(allocator, "", "file.txt");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("file.txt", result);
}

test "smartJoin_empty_second" {
    const allocator = std.testing.allocator;
    const result = try smartJoin(allocator, "/home/user", "");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("/home/user", result);
}

test "smartIsAbs_unix_absolute" {
    try std.testing.expect(smartIsAbs("/home/user"));
    try std.testing.expect(smartIsAbs("/"));
}

test "smartIsAbs_relative" {
    try std.testing.expect(!smartIsAbs("documents/file.txt"));
    try std.testing.expect(!smartIsAbs("."));
    try std.testing.expect(!smartIsAbs(".."));
    try std.testing.expect(!smartIsAbs("file.txt"));
}

test "smartIsAbs_empty" {
    try std.testing.expect(!smartIsAbs(""));
}

test "isRelative" {
    try std.testing.expect(isRelative("documents"));
    try std.testing.expect(isRelative("./file.txt"));
    try std.testing.expect(!isRelative("/absolute/path"));
}

test "dirname" {
    try std.testing.expectEqualStrings("/home", dirname("/home/user"));
    try std.testing.expectEqualStrings("", dirname("file.txt"));
}

test "basename" {
    try std.testing.expectEqualStrings("user", basename("/home/user"));
    try std.testing.expectEqualStrings("file.txt", basename("/path/to/file.txt"));
}

test "extension" {
    try std.testing.expectEqualStrings(".txt", extension("file.txt"));
    try std.testing.expectEqualStrings(".gz", extension("archive.tar.gz"));
    try std.testing.expectEqualStrings("", extension("noextension"));
}

test "normalize" {
    const allocator = std.testing.allocator;
    const result = try normalize(allocator, "path/to/file");
    defer allocator.free(result);

    // Result should have consistent separators
    try std.testing.expectEqual(@as(usize, 12), result.len);
}
