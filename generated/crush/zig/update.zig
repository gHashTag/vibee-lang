// update.zig - Update Checker Module
// Generated from: crush/internal/update
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Update information
pub const Info = struct {
    current: []const u8,
    latest: []const u8,
    url: []const u8,

    const Self = @This();

    /// Check if current version is development
    pub fn isDevelopment(self: Self) bool {
        if (std.mem.eql(u8, self.current, "devel")) return true;
        if (std.mem.eql(u8, self.current, "unknown")) return true;
        if (std.mem.indexOf(u8, self.current, "dirty") != null) return true;
        return false;
    }

    /// Check if update is available
    pub fn available(self: Self) bool {
        const current_prerelease = std.mem.indexOf(u8, self.current, "-") != null;
        const latest_prerelease = std.mem.indexOf(u8, self.latest, "-") != null;

        // Current is prerelease and latest isn't
        if (current_prerelease and !latest_prerelease) return true;

        // Latest is prerelease and current isn't
        if (latest_prerelease and !current_prerelease) return false;

        return !std.mem.eql(u8, self.current, self.latest);
    }
};

/// Parse version string into components
pub fn parseVersion(ver: []const u8) struct { major: u32, minor: u32, patch: u32 } {
    var input = ver;

    // Strip 'v' prefix
    if (input.len > 0 and input[0] == 'v') {
        input = input[1..];
    }

    // Strip prerelease suffix
    if (std.mem.indexOf(u8, input, "-")) |idx| {
        input = input[0..idx];
    }

    var parts = std.mem.splitScalar(u8, input, '.');
    const major = std.fmt.parseInt(u32, parts.next() orelse "0", 10) catch 0;
    const minor = std.fmt.parseInt(u32, parts.next() orelse "0", 10) catch 0;
    const patch = std.fmt.parseInt(u32, parts.next() orelse "0", 10) catch 0;

    return .{ .major = major, .minor = minor, .patch = patch };
}

/// Compare two versions
pub fn compareVersions(v1: []const u8, v2: []const u8) std.math.Order {
    const p1 = parseVersion(v1);
    const p2 = parseVersion(v2);

    if (p1.major != p2.major) return std.math.order(p1.major, p2.major);
    if (p1.minor != p2.minor) return std.math.order(p1.minor, p2.minor);
    return std.math.order(p1.patch, p2.patch);
}

/// Check if v1 is newer than v2
pub fn isNewer(v1: []const u8, v2: []const u8) bool {
    return compareVersions(v1, v2) == .gt;
}

// Tests
test "info_is_development" {
    const devel = Info{ .current = "devel", .latest = "1.0.0", .url = "" };
    try std.testing.expect(devel.isDevelopment());

    const unknown = Info{ .current = "unknown", .latest = "1.0.0", .url = "" };
    try std.testing.expect(unknown.isDevelopment());

    const dirty = Info{ .current = "1.0.0-dirty", .latest = "1.0.0", .url = "" };
    try std.testing.expect(dirty.isDevelopment());

    const stable = Info{ .current = "1.0.0", .latest = "1.0.0", .url = "" };
    try std.testing.expect(!stable.isDevelopment());
}

test "info_available" {
    const same = Info{ .current = "1.0.0", .latest = "1.0.0", .url = "" };
    try std.testing.expect(!same.available());

    const newer = Info{ .current = "1.0.0", .latest = "1.1.0", .url = "" };
    try std.testing.expect(newer.available());

    const prerelease_current = Info{ .current = "1.0.0-beta", .latest = "1.0.0", .url = "" };
    try std.testing.expect(prerelease_current.available());

    const prerelease_latest = Info{ .current = "1.0.0", .latest = "1.1.0-beta", .url = "" };
    try std.testing.expect(!prerelease_latest.available());
}

test "parse_version" {
    const v1 = parseVersion("1.2.3");
    try std.testing.expectEqual(@as(u32, 1), v1.major);
    try std.testing.expectEqual(@as(u32, 2), v1.minor);
    try std.testing.expectEqual(@as(u32, 3), v1.patch);

    const v2 = parseVersion("v2.0.0");
    try std.testing.expectEqual(@as(u32, 2), v2.major);

    const v3 = parseVersion("1.0.0-beta");
    try std.testing.expectEqual(@as(u32, 1), v3.major);
}

test "compare_versions" {
    try std.testing.expectEqual(std.math.Order.gt, compareVersions("2.0.0", "1.0.0"));
    try std.testing.expectEqual(std.math.Order.lt, compareVersions("1.0.0", "2.0.0"));
    try std.testing.expectEqual(std.math.Order.eq, compareVersions("1.0.0", "1.0.0"));
    try std.testing.expectEqual(std.math.Order.gt, compareVersions("1.1.0", "1.0.0"));
    try std.testing.expectEqual(std.math.Order.gt, compareVersions("1.0.1", "1.0.0"));
}

test "is_newer" {
    try std.testing.expect(isNewer("2.0.0", "1.0.0"));
    try std.testing.expect(!isNewer("1.0.0", "2.0.0"));
    try std.testing.expect(!isNewer("1.0.0", "1.0.0"));
}
