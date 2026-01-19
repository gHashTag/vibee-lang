// home.zig - Home Directory Utilities
// Generated from: specs/crush/home.vibee via generated/crush/tri/home.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");
const builtin = @import("builtin");

/// Cached home directory path
var cached_homedir: ?[]const u8 = null;
var homedir_error: ?anyerror = null;
var init_done: bool = false;

/// Initialize home directory cache
fn initHomeDir() void {
    if (init_done) return;
    init_done = true;

    if (std.posix.getenv("HOME")) |home| {
        cached_homedir = home;
    } else if (builtin.os.tag == .windows) {
        // On Windows, try USERPROFILE
        if (std.posix.getenv("USERPROFILE")) |profile| {
            cached_homedir = profile;
        }
    }

    if (cached_homedir == null) {
        homedir_error = error.HomeDirNotFound;
        std.log.err("failed to get user home directory", .{});
    }
}

/// Dir returns the user home directory.
/// Creation Pattern: void → HomeDirLookup → []const u8
pub fn dir() ?[]const u8 {
    initHomeDir();
    return cached_homedir;
}

/// Short replaces the actual home path with `~`.
/// Creation Pattern: FilePath → TildeCompressor → ShortPath
pub fn short(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    initHomeDir();

    const homedir = cached_homedir orelse return try allocator.dupe(u8, path);

    if (homedir.len == 0) {
        return try allocator.dupe(u8, path);
    }

    if (!std.mem.startsWith(u8, path, homedir)) {
        return try allocator.dupe(u8, path);
    }

    // Replace home prefix with ~
    const suffix = path[homedir.len..];
    const result_len = 1 + suffix.len; // "~" + suffix

    var result = try allocator.alloc(u8, result_len);
    result[0] = '~';
    @memcpy(result[1..], suffix);

    return result;
}

/// Long replaces the `~` with actual home path.
/// Creation Pattern: ShortPath → TildeExpander → FilePath
pub fn long(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    initHomeDir();

    const homedir = cached_homedir orelse return try allocator.dupe(u8, path);

    if (homedir.len == 0) {
        return try allocator.dupe(u8, path);
    }

    if (!std.mem.startsWith(u8, path, "~")) {
        return try allocator.dupe(u8, path);
    }

    // Replace ~ with home directory
    const suffix = path[1..]; // Skip the ~
    const result_len = homedir.len + suffix.len;

    var result = try allocator.alloc(u8, result_len);
    @memcpy(result[0..homedir.len], homedir);
    @memcpy(result[homedir.len..], suffix);

    return result;
}

/// Check if path starts with home directory
pub fn isInHome(path: []const u8) bool {
    initHomeDir();
    const homedir = cached_homedir orelse return false;
    return std.mem.startsWith(u8, path, homedir);
}

/// Check if path uses tilde notation
pub fn hasTilde(path: []const u8) bool {
    return std.mem.startsWith(u8, path, "~");
}

/// Get the error if home directory lookup failed
pub fn getError() ?anyerror {
    initHomeDir();
    return homedir_error;
}

// Tests
test "dir_returns_value" {
    const result = dir();
    // In test environment, HOME should be set
    if (result) |home| {
        try std.testing.expect(home.len > 0);
    }
}

test "short_replaces_home" {
    const allocator = std.testing.allocator;

    if (dir()) |homedir| {
        // Create a path under home
        var path_buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/documents/file.txt", .{homedir});

        const result = try short(allocator, path);
        defer allocator.free(result);

        try std.testing.expect(std.mem.startsWith(u8, result, "~"));
        try std.testing.expect(std.mem.endsWith(u8, result, "/documents/file.txt"));
    }
}

test "short_preserves_non_home_path" {
    const allocator = std.testing.allocator;
    const path = "/absolute/path/file.txt";

    const result = try short(allocator, path);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(path, result);
}

test "long_expands_tilde" {
    const allocator = std.testing.allocator;

    if (dir()) |homedir| {
        const path = "~/documents/file.txt";

        const result = try long(allocator, path);
        defer allocator.free(result);

        try std.testing.expect(std.mem.startsWith(u8, result, homedir));
        try std.testing.expect(std.mem.endsWith(u8, result, "/documents/file.txt"));
    }
}

test "long_preserves_absolute_path" {
    const allocator = std.testing.allocator;
    const path = "/absolute/path/file.txt";

    const result = try long(allocator, path);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(path, result);
}

test "isInHome" {
    if (dir()) |homedir| {
        var path_buf: [512]u8 = undefined;
        const home_path = try std.fmt.bufPrint(&path_buf, "{s}/test", .{homedir});

        try std.testing.expect(isInHome(home_path));
        try std.testing.expect(!isInHome("/other/path"));
    }
}

test "hasTilde" {
    try std.testing.expect(hasTilde("~/documents"));
    try std.testing.expect(hasTilde("~"));
    try std.testing.expect(!hasTilde("/home/user"));
    try std.testing.expect(!hasTilde("relative/path"));
}

test "roundtrip_short_long" {
    const allocator = std.testing.allocator;

    if (dir()) |homedir| {
        var path_buf: [512]u8 = undefined;
        const original = try std.fmt.bufPrint(&path_buf, "{s}/test/file.txt", .{homedir});

        const shortened = try short(allocator, original);
        defer allocator.free(shortened);

        const expanded = try long(allocator, shortened);
        defer allocator.free(expanded);

        try std.testing.expectEqualStrings(original, expanded);
    }
}
