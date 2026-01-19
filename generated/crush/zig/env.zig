// env.zig - Environment Variable Abstraction
// Generated from: specs/crush/env.vibee via generated/crush/tri/env.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

/// Env interface for environment variable access
/// Creation Pattern: EnvironmentSource → EnvAdapter → EnvInterface
pub const Env = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        get: *const fn (ptr: *anyopaque, key: []const u8) []const u8,
        getAll: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) ?[][]const u8,
    };

    pub fn get(self: Env, key: []const u8) []const u8 {
        return self.vtable.get(self.ptr, key);
    }

    pub fn getAll(self: Env, allocator: std.mem.Allocator) ?[][]const u8 {
        return self.vtable.getAll(self.ptr, allocator);
    }
};

/// OsEnv - Real OS environment implementation
pub const OsEnv = struct {
    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn get(_: *Self, key: []const u8) []const u8 {
        return std.posix.getenv(key) orelse "";
    }

    pub fn getAll(_: *Self, allocator: std.mem.Allocator) ?[][]const u8 {
        _ = allocator;
        // In Zig, getting all env vars requires platform-specific code
        // For simplicity, return null (not implemented)
        return null;
    }

    pub fn env(self: *Self) Env {
        return Env{
            .ptr = self,
            .vtable = &.{
                .get = @ptrCast(&Self.get),
                .getAll = @ptrCast(&Self.getAll),
            },
        };
    }
};

/// MapEnv - Map-based environment for testing
pub const MapEnv = struct {
    m: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .m = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn initFromMap(allocator: std.mem.Allocator, data: anytype) !Self {
        var self = Self.init(allocator);
        inline for (@typeInfo(@TypeOf(data)).@"struct".fields) |field| {
            try self.m.put(field.name, @field(data, field.name));
        }
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.m.deinit();
    }

    pub fn put(self: *Self, key: []const u8, value: []const u8) !void {
        try self.m.put(key, value);
    }

    pub fn get(self: *Self, key: []const u8) []const u8 {
        return self.m.get(key) orelse "";
    }

    pub fn getAll(self: *Self, allocator: std.mem.Allocator) ?[][]const u8 {
        if (self.m.count() == 0) return null;

        var result = allocator.alloc([]const u8, self.m.count()) catch return null;
        var i: usize = 0;

        var iter = self.m.iterator();
        while (iter.next()) |entry| {
            // Format as "KEY=VALUE"
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            const len = key.len + 1 + value.len;
            var buf = allocator.alloc(u8, len) catch return null;
            @memcpy(buf[0..key.len], key);
            buf[key.len] = '=';
            @memcpy(buf[key.len + 1 ..], value);
            result[i] = buf;
            i += 1;
        }

        return result;
    }

    pub fn count(self: *Self) usize {
        return self.m.count();
    }

    pub fn env(self: *Self) Env {
        return Env{
            .ptr = self,
            .vtable = &.{
                .get = @ptrCast(&Self.get),
                .getAll = @ptrCast(&Self.getAll),
            },
        };
    }
};

/// Create new environment (returns OsEnv in production)
pub fn new() OsEnv {
    return OsEnv.init();
}

/// Create new environment from map (for testing)
pub fn newFromMap(allocator: std.mem.Allocator) MapEnv {
    return MapEnv.init(allocator);
}

// Tests
test "os_env_get_path" {
    var e = OsEnv.init();
    const path = e.get("PATH");
    // PATH should exist on most systems
    try std.testing.expect(path.len > 0);
}

test "os_env_get_missing" {
    var e = OsEnv.init();
    const result = e.get("NONEXISTENT_VAR_12345_VIBEE");
    try std.testing.expectEqualStrings("", result);
}

test "map_env_init" {
    const allocator = std.testing.allocator;
    var e = MapEnv.init(allocator);
    defer e.deinit();

    try std.testing.expectEqual(@as(usize, 0), e.count());
}

test "map_env_put_get" {
    const allocator = std.testing.allocator;
    var e = MapEnv.init(allocator);
    defer e.deinit();

    try e.put("FOO", "bar");
    try std.testing.expectEqualStrings("bar", e.get("FOO"));
}

test "map_env_get_missing" {
    const allocator = std.testing.allocator;
    var e = MapEnv.init(allocator);
    defer e.deinit();

    try e.put("FOO", "bar");
    try std.testing.expectEqualStrings("", e.get("BAZ"));
}

test "map_env_get_all" {
    const allocator = std.testing.allocator;
    var e = MapEnv.init(allocator);
    defer e.deinit();

    try e.put("FOO", "bar");
    try e.put("BAZ", "qux");

    const all = e.getAll(allocator);
    try std.testing.expect(all != null);

    if (all) |items| {
        defer {
            for (items) |item| {
                allocator.free(item);
            }
            allocator.free(items);
        }
        try std.testing.expectEqual(@as(usize, 2), items.len);
    }
}

test "map_env_get_all_empty" {
    const allocator = std.testing.allocator;
    var e = MapEnv.init(allocator);
    defer e.deinit();

    const all = e.getAll(allocator);
    try std.testing.expect(all == null);
}

test "new_returns_os_env" {
    var e = new();
    // Should be able to get PATH
    const path = e.get("PATH");
    try std.testing.expect(path.len > 0);
}

test "newFromMap_returns_map_env" {
    const allocator = std.testing.allocator;
    var e = newFromMap(allocator);
    defer e.deinit();

    try std.testing.expectEqual(@as(usize, 0), e.count());
}

test "map_env_multiple_puts" {
    const allocator = std.testing.allocator;
    var e = MapEnv.init(allocator);
    defer e.deinit();

    try e.put("A", "1");
    try e.put("B", "2");
    try e.put("C", "3");

    try std.testing.expectEqual(@as(usize, 3), e.count());
    try std.testing.expectEqualStrings("1", e.get("A"));
    try std.testing.expectEqualStrings("2", e.get("B"));
    try std.testing.expectEqualStrings("3", e.get("C"));
}

test "map_env_overwrite" {
    const allocator = std.testing.allocator;
    var e = MapEnv.init(allocator);
    defer e.deinit();

    try e.put("FOO", "bar");
    try e.put("FOO", "baz");

    try std.testing.expectEqualStrings("baz", e.get("FOO"));
    try std.testing.expectEqual(@as(usize, 1), e.count());
}
