// integration_test.zig - Cross-module Integration Tests
// Generated from: VIBEE Transpilation Pipeline
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");
const ansiext = @import("ansiext.zig");
const stringext = @import("stringext.zig");
const home = @import("home.zig");
const filepathext = @import("filepathext.zig");
const env = @import("env.zig");
const version = @import("version.zig");
const diff = @import("diff.zig");
const csync = @import("csync.zig");
const format = @import("format.zig");

// ============================================================================
// Integration Test: ansiext + stringext
// ============================================================================

test "integration: escape then capitalize" {
    const allocator = std.testing.allocator;

    // Escape control characters
    const escaped = try ansiext.escape(allocator, "hello\x00world");
    defer allocator.free(escaped);

    // Capitalize the result
    const capitalized = try stringext.capitalize(allocator, escaped);
    defer allocator.free(capitalized);

    // Should have escaped null and capitalized
    try std.testing.expect(std.mem.indexOf(u8, capitalized, "␀") != null);
}

test "integration: capitalize then check contains" {
    const allocator = std.testing.allocator;

    const text = try stringext.capitalize(allocator, "hello world");
    defer allocator.free(text);

    const patterns = [_][]const u8{ "Hello", "World" };
    try std.testing.expect(stringext.containsAny(text, &patterns));
}

// ============================================================================
// Integration Test: home + filepathext
// ============================================================================

test "integration: home path with smart join" {
    const allocator = std.testing.allocator;

    if (home.dir()) |homedir| {
        // Join home with relative path
        const full_path = try filepathext.smartJoin(allocator, homedir, "documents/file.txt");
        defer allocator.free(full_path);

        // Should be absolute
        try std.testing.expect(filepathext.smartIsAbs(full_path));

        // Should start with home
        try std.testing.expect(std.mem.startsWith(u8, full_path, homedir));
    }
}

test "integration: short path then smart join" {
    const allocator = std.testing.allocator;

    if (home.dir()) |homedir| {
        // Create a path under home
        var path_buf: [512]u8 = undefined;
        const original = try std.fmt.bufPrint(&path_buf, "{s}/test", .{homedir});

        // Shorten it
        const shortened = try home.short(allocator, original);
        defer allocator.free(shortened);

        // Should start with ~
        try std.testing.expect(std.mem.startsWith(u8, shortened, "~"));

        // Expand it back
        const expanded = try home.long(allocator, shortened);
        defer allocator.free(expanded);

        // Should be absolute again
        try std.testing.expect(filepathext.smartIsAbs(expanded));
    }
}

// ============================================================================
// Integration Test: env + version
// ============================================================================

test "integration: env with version check" {
    var e = env.new();

    // Get PATH (should exist)
    const path = e.get("PATH");
    try std.testing.expect(path.len > 0);

    // Get version
    const ver = version.getVersion();
    try std.testing.expect(ver.len > 0);

    // Both should be non-empty strings
    try std.testing.expect(!std.mem.eql(u8, path, ""));
    try std.testing.expect(!std.mem.eql(u8, ver, ""));
}

test "integration: map env with version parsing" {
    const allocator = std.testing.allocator;

    var e = env.newFromMap(allocator);
    defer e.deinit();

    try e.put("APP_VERSION", "1.2.3");

    const ver_str = e.get("APP_VERSION");
    const semver = try version.parseSemVer(ver_str);

    try std.testing.expectEqual(@as(u32, 1), semver.major);
    try std.testing.expectEqual(@as(u32, 2), semver.minor);
    try std.testing.expectEqual(@as(u32, 3), semver.patch);
}

// ============================================================================
// Integration Test: diff + stringext
// ============================================================================

test "integration: diff with string processing" {
    const allocator = std.testing.allocator;

    // Create before/after with capitalization
    const before = try stringext.capitalize(allocator, "hello world");
    defer allocator.free(before);

    const after = try stringext.capitalize(allocator, "hello universe");
    defer allocator.free(after);

    // Generate diff
    const result = try diff.generateDiff(allocator, before, after, "test.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    // Should have changes
    try std.testing.expect(result.additions > 0 or result.removals > 0);
}

test "integration: diff header contains filename" {
    const allocator = std.testing.allocator;

    const result = try diff.generateDiff(allocator, "old", "new", "myfile.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    // Check header format
    try std.testing.expect(std.mem.indexOf(u8, result.unified, "myfile.txt") != null);
}

// ============================================================================
// Integration Test: csync + multiple modules
// ============================================================================

test "integration: csync map with paths" {
    const allocator = std.testing.allocator;

    var path_cache = csync.Map(u32, []const u8).init(allocator);
    defer path_cache.deinit();

    // Store some paths
    try path_cache.set(1, "/home/user/file1.txt");
    try path_cache.set(2, "/home/user/file2.txt");

    // Retrieve and check
    const path1 = path_cache.get(1);
    try std.testing.expect(path1 != null);
    try std.testing.expect(filepathext.smartIsAbs(path1.?));
}

test "integration: csync slice with strings" {
    const allocator = std.testing.allocator;

    var string_list = csync.Slice([]const u8).init(allocator);
    defer string_list.deinit();

    // Add capitalized strings
    const s1 = try stringext.capitalize(allocator, "first");
    defer allocator.free(s1);
    const s2 = try stringext.capitalize(allocator, "second");
    defer allocator.free(s2);

    try string_list.append(s1);
    try string_list.append(s2);

    try std.testing.expectEqual(@as(usize, 2), string_list.len());
}

// ============================================================================
// Integration Test: format + ansiext
// ============================================================================

test "integration: spinner with ansi" {
    const allocator = std.testing.allocator;

    // Create spinner
    var spinner = format.Spinner.init(allocator, .{ .message = "Loading..." });

    // Get current frame
    const frame = spinner.currentFrame();

    // Frame should not contain control characters (already escaped in spinner)
    for (frame) |c| {
        try std.testing.expect(!ansiext.isControl(c));
    }
}

// ============================================================================
// Integration Test: Full Pipeline
// ============================================================================

test "integration: full pipeline - file processing simulation" {
    const allocator = std.testing.allocator;

    // 1. Get home directory
    const homedir = home.dir() orelse "/tmp";

    // 2. Create a path
    const file_path = try filepathext.smartJoin(allocator, homedir, "test.txt");
    defer allocator.free(file_path);

    // 3. Simulate file content with control chars
    const raw_content = "Hello\x00World\nLine2";
    const escaped_content = try ansiext.escape(allocator, raw_content);
    defer allocator.free(escaped_content);

    // 4. Capitalize
    const processed = try stringext.capitalize(allocator, "processed content");
    defer allocator.free(processed);

    // 5. Generate diff
    const diff_result = try diff.generateDiff(allocator, escaped_content, processed, "test.txt");
    defer if (diff_result.unified.len > 0) allocator.free(diff_result.unified);

    // 6. Store in cache
    var cache = csync.Map(u32, []const u8).init(allocator);
    defer cache.deinit();
    try cache.set(1, file_path);

    // 7. Check version
    const ver = version.getVersion();

    // Verify all steps worked
    try std.testing.expect(filepathext.smartIsAbs(file_path));
    try std.testing.expect(std.mem.indexOf(u8, escaped_content, "␀") != null);
    try std.testing.expectEqualStrings("Processed Content", processed);
    try std.testing.expect(ver.len > 0);
}

test "integration: sacred formula verification" {
    const PHI: f64 = 1.618033988749895;
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / phi_squared;
    const result = phi_squared + inv_phi_squared;

    // φ² + 1/φ² = 3
    try std.testing.expect(@abs(result - 3.0) < 0.0001);
}
