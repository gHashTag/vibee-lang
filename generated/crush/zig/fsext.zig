// fsext.zig - Filesystem Extension Module
// Generated from: specs/crush/fsext.vibee
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const home = @import("home.zig");

/// Common ignored directories
pub const ignored_dirs = [_][]const u8{
    ".crush",
    "node_modules",
    "vendor",
    "dist",
    "build",
    "target",
    ".git",
    ".idea",
    ".vscode",
    "__pycache__",
    "bin",
    "obj",
    "out",
    "coverage",
    "logs",
    "generated",
    "bower_components",
    "jspm_packages",
};

/// Check if path should be skipped (hidden or ignored)
pub fn skipHidden(path: []const u8) bool {
    const base = std.fs.path.basename(path);

    // Check for hidden files (starting with .)
    if (base.len > 0 and base[0] == '.' and !std.mem.eql(u8, base, ".")) {
        return true;
    }

    // Check common ignored directories
    for (ignored_dirs) |ignored| {
        if (std.mem.eql(u8, base, ignored)) {
            return true;
        }
    }

    // Check path components
    var iter = std.mem.splitScalar(u8, path, std.fs.path.sep);
    while (iter.next()) |part| {
        for (ignored_dirs) |ignored| {
            if (std.mem.eql(u8, part, ignored)) {
                return true;
            }
        }
    }

    return false;
}

/// Lookup searches for target files walking up directory tree
pub fn lookup(allocator: std.mem.Allocator, dir: []const u8, targets: []const []const u8) ![][]const u8 {
    if (targets.len == 0) {
        return try allocator.alloc([]const u8, 0);
    }

    var found = std.ArrayList([]const u8).init(allocator);
    errdefer found.deinit();

    var current_dir = try allocator.dupe(u8, dir);
    defer allocator.free(current_dir);

    while (true) {
        for (targets) |target| {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ current_dir, target });

            // Check if file exists
            if (std.fs.cwd().access(full_path, .{})) |_| {
                try found.append(full_path);
            } else |_| {
                allocator.free(full_path);
            }
        }

        // Move to parent directory
        const parent = std.fs.path.dirname(current_dir);
        if (parent == null or std.mem.eql(u8, parent.?, current_dir)) {
            break;
        }

        allocator.free(current_dir);
        current_dir = try allocator.dupe(u8, parent.?);
    }

    return found.toOwnedSlice();
}

/// LookupClosest finds first matching target walking up
pub fn lookupClosest(allocator: std.mem.Allocator, dir: []const u8, target: []const u8) !?[]const u8 {
    var current_dir = try allocator.dupe(u8, dir);
    defer allocator.free(current_dir);

    const homedir = home.dir() orelse "";

    while (true) {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ current_dir, target });

        // Check if file exists
        if (std.fs.cwd().access(full_path, .{})) |_| {
            // Don't return if we're at home directory
            if (std.mem.eql(u8, current_dir, homedir)) {
                allocator.free(full_path);
                return null;
            }
            return full_path;
        } else |_| {
            allocator.free(full_path);
        }

        // Move to parent directory
        const parent = std.fs.path.dirname(current_dir);
        if (parent == null or std.mem.eql(u8, parent.?, current_dir)) {
            break;
        }

        const old_dir = current_dir;
        current_dir = try allocator.dupe(u8, parent.?);
        allocator.free(old_dir);
    }

    return null;
}

/// Expand shell symbols in string (~ and environment variables)
pub fn expand(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    if (s.len == 0) {
        return try allocator.alloc(u8, 0);
    }

    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '~' and (i == 0 or s[i - 1] == ' ' or s[i - 1] == '/')) {
            // Expand tilde to home directory
            if (home.dir()) |homedir| {
                try result.appendSlice(homedir);
            } else {
                try result.append('~');
            }
            i += 1;
        } else if (s[i] == '$') {
            // Expand environment variable
            i += 1;
            var var_start = i;

            // Handle ${VAR} syntax
            if (i < s.len and s[i] == '{') {
                i += 1;
                var_start = i;
                while (i < s.len and s[i] != '}') : (i += 1) {}
                const var_name = s[var_start..i];
                if (i < s.len) i += 1; // skip }

                if (std.posix.getenv(var_name)) |value| {
                    try result.appendSlice(value);
                }
            } else {
                // Handle $VAR syntax
                while (i < s.len and (std.ascii.isAlphanumeric(s[i]) or s[i] == '_')) : (i += 1) {}
                const var_name = s[var_start..i];

                if (std.posix.getenv(var_name)) |value| {
                    try result.appendSlice(value);
                }
            }
        } else {
            try result.append(s[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice();
}

/// Pretty print path (replace home with ~)
pub fn prettyPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return home.short(allocator, path);
}

/// Trim directory path to limit
pub fn dirTrim(allocator: std.mem.Allocator, pwd: []const u8, lim: usize) ![]u8 {
    if (lim == 0) {
        return try allocator.dupe(u8, pwd);
    }

    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();

    var iter = std.mem.splitScalar(u8, pwd, std.fs.path.sep);
    while (iter.next()) |part| {
        if (part.len > 0) {
            try parts.append(part);
        }
    }

    if (parts.items.len <= lim) {
        return try allocator.dupe(u8, pwd);
    }

    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    try result.appendSlice("...");
    for (parts.items[parts.items.len - lim ..]) |part| {
        try result.append(std.fs.path.sep);
        try result.appendSlice(part);
    }

    return result.toOwnedSlice();
}

// Tests
test "skipHidden_hidden_file" {
    try std.testing.expect(skipHidden(".hidden"));
    try std.testing.expect(skipHidden("/path/to/.hidden"));
}

test "skipHidden_ignored_dir" {
    try std.testing.expect(skipHidden("node_modules"));
    try std.testing.expect(skipHidden("/path/node_modules/file.js"));
    try std.testing.expect(skipHidden(".git"));
}

test "skipHidden_normal_file" {
    try std.testing.expect(!skipHidden("file.txt"));
    try std.testing.expect(!skipHidden("/path/to/file.txt"));
}

test "skipHidden_current_dir" {
    try std.testing.expect(!skipHidden("."));
}

test "expand_empty" {
    const allocator = std.testing.allocator;
    const result = try expand(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "expand_tilde" {
    const allocator = std.testing.allocator;
    const result = try expand(allocator, "~/documents");
    defer allocator.free(result);

    if (home.dir()) |homedir| {
        try std.testing.expect(std.mem.startsWith(u8, result, homedir));
    }
}

test "expand_env_var" {
    const allocator = std.testing.allocator;
    const result = try expand(allocator, "$PATH");
    defer allocator.free(result);

    // PATH should be expanded
    try std.testing.expect(result.len > 0);
}

test "expand_no_expansion" {
    const allocator = std.testing.allocator;
    const result = try expand(allocator, "normal text");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("normal text", result);
}

test "dirTrim_short_path" {
    const allocator = std.testing.allocator;
    const result = try dirTrim(allocator, "/home/user", 5);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/home/user", result);
}

test "dirTrim_long_path" {
    const allocator = std.testing.allocator;
    const result = try dirTrim(allocator, "/home/user/projects/myapp/src/components", 2);
    defer allocator.free(result);
    try std.testing.expect(std.mem.startsWith(u8, result, "..."));
}
