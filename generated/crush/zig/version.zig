// version.zig - Version Information Module
// Generated from: specs/crush/version.vibee via generated/crush/tri/version.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

/// Default version when not set
pub const DEFAULT_VERSION = "devel";

/// Global version string (can be set at compile time)
pub var version: []const u8 = DEFAULT_VERSION;

/// Semantic version components
pub const SemVer = struct {
    major: u32,
    minor: u32,
    patch: u32,
    prerelease: ?[]const u8,
    build: ?[]const u8,

    const Self = @This();

    /// Compare two semantic versions
    pub fn compare(self: Self, other: Self) std.math.Order {
        if (self.major != other.major) {
            return std.math.order(self.major, other.major);
        }
        if (self.minor != other.minor) {
            return std.math.order(self.minor, other.minor);
        }
        if (self.patch != other.patch) {
            return std.math.order(self.patch, other.patch);
        }
        // Prerelease versions have lower precedence
        if (self.prerelease != null and other.prerelease == null) {
            return .lt;
        }
        if (self.prerelease == null and other.prerelease != null) {
            return .gt;
        }
        return .eq;
    }

    /// Check if this version is greater than another
    pub fn isGreaterThan(self: Self, other: Self) bool {
        return self.compare(other) == .gt;
    }

    /// Check if this version is less than another
    pub fn isLessThan(self: Self, other: Self) bool {
        return self.compare(other) == .lt;
    }

    /// Check if versions are equal
    pub fn isEqual(self: Self, other: Self) bool {
        return self.compare(other) == .eq;
    }

    /// Format version as string
    pub fn format(self: Self, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();

        try buf.writer().print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });

        if (self.prerelease) |pre| {
            try buf.append('-');
            try buf.appendSlice(pre);
        }

        if (self.build) |b| {
            try buf.append('+');
            try buf.appendSlice(b);
        }

        return buf.toOwnedSlice();
    }
};

/// Parse a semantic version string
/// Creation Pattern: VersionString → SemVerParser → SemVer
pub fn parseSemVer(ver: []const u8) !SemVer {
    var input = ver;

    // Strip optional 'v' prefix
    if (input.len > 0 and input[0] == 'v') {
        input = input[1..];
    }

    // Find prerelease separator
    var prerelease: ?[]const u8 = null;
    var build: ?[]const u8 = null;

    if (std.mem.indexOf(u8, input, "+")) |plus_idx| {
        build = input[plus_idx + 1 ..];
        input = input[0..plus_idx];
    }

    if (std.mem.indexOf(u8, input, "-")) |dash_idx| {
        prerelease = input[dash_idx + 1 ..];
        input = input[0..dash_idx];
    }

    // Parse major.minor.patch
    var parts = std.mem.splitScalar(u8, input, '.');
    const major_str = parts.next() orelse return error.InvalidVersion;
    const minor_str = parts.next() orelse "0";
    const patch_str = parts.next() orelse "0";

    const major = std.fmt.parseInt(u32, major_str, 10) catch return error.InvalidVersion;
    const minor = std.fmt.parseInt(u32, minor_str, 10) catch return error.InvalidVersion;
    const patch = std.fmt.parseInt(u32, patch_str, 10) catch return error.InvalidVersion;

    return SemVer{
        .major = major,
        .minor = minor,
        .patch = patch,
        .prerelease = prerelease,
        .build = build,
    };
}

/// Get the current version
pub fn getVersion() []const u8 {
    return version;
}

/// Set the version (typically called at init)
pub fn setVersion(ver: []const u8) void {
    if (ver.len > 0 and !std.mem.eql(u8, ver, "(devel)")) {
        version = ver;
    }
}

/// Check if version is development version
pub fn isDevel() bool {
    return std.mem.eql(u8, version, DEFAULT_VERSION) or
        std.mem.eql(u8, version, "(devel)");
}

/// Compare two version strings
pub fn compareVersions(v1: []const u8, v2: []const u8) !std.math.Order {
    const sem1 = try parseSemVer(v1);
    const sem2 = try parseSemVer(v2);
    return sem1.compare(sem2);
}

// Tests
test "parseSemVer_simple" {
    const v = try parseSemVer("1.2.3");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 2), v.minor);
    try std.testing.expectEqual(@as(u32, 3), v.patch);
    try std.testing.expect(v.prerelease == null);
}

test "parseSemVer_with_v_prefix" {
    const v = try parseSemVer("v1.2.3");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 2), v.minor);
    try std.testing.expectEqual(@as(u32, 3), v.patch);
}

test "parseSemVer_with_prerelease" {
    const v = try parseSemVer("1.2.3-beta.1");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 2), v.minor);
    try std.testing.expectEqual(@as(u32, 3), v.patch);
    try std.testing.expectEqualStrings("beta.1", v.prerelease.?);
}

test "parseSemVer_with_build" {
    const v = try parseSemVer("1.2.3+build.123");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 2), v.minor);
    try std.testing.expectEqual(@as(u32, 3), v.patch);
    try std.testing.expectEqualStrings("build.123", v.build.?);
}

test "parseSemVer_with_prerelease_and_build" {
    const v = try parseSemVer("1.2.3-alpha+build");
    try std.testing.expectEqualStrings("alpha", v.prerelease.?);
    try std.testing.expectEqualStrings("build", v.build.?);
}

test "parseSemVer_major_only" {
    const v = try parseSemVer("1");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 0), v.minor);
    try std.testing.expectEqual(@as(u32, 0), v.patch);
}

test "SemVer_compare_major" {
    const v1 = try parseSemVer("2.0.0");
    const v2 = try parseSemVer("1.0.0");
    try std.testing.expect(v1.isGreaterThan(v2));
}

test "SemVer_compare_minor" {
    const v1 = try parseSemVer("1.2.0");
    const v2 = try parseSemVer("1.1.0");
    try std.testing.expect(v1.isGreaterThan(v2));
}

test "SemVer_compare_patch" {
    const v1 = try parseSemVer("1.0.2");
    const v2 = try parseSemVer("1.0.1");
    try std.testing.expect(v1.isGreaterThan(v2));
}

test "SemVer_compare_equal" {
    const v1 = try parseSemVer("1.0.0");
    const v2 = try parseSemVer("1.0.0");
    try std.testing.expect(v1.isEqual(v2));
}

test "SemVer_compare_prerelease" {
    const v1 = try parseSemVer("1.0.0");
    const v2 = try parseSemVer("1.0.0-alpha");
    try std.testing.expect(v1.isGreaterThan(v2));
}

test "getVersion_default" {
    try std.testing.expectEqualStrings(DEFAULT_VERSION, getVersion());
}

test "isDevel_default" {
    try std.testing.expect(isDevel());
}

test "compareVersions" {
    try std.testing.expectEqual(std.math.Order.gt, try compareVersions("2.0.0", "1.0.0"));
    try std.testing.expectEqual(std.math.Order.lt, try compareVersions("1.0.0", "2.0.0"));
    try std.testing.expectEqual(std.math.Order.eq, try compareVersions("1.0.0", "1.0.0"));
}

test "SemVer_format" {
    const allocator = std.testing.allocator;
    const v = try parseSemVer("1.2.3-beta+build");
    const formatted = try v.format(allocator);
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings("1.2.3-beta+build", formatted);
}
