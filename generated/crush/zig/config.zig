// config.zig - Configuration Module
// Generated from: crush/internal/config
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Configuration keys
pub const Key = enum {
    api_key,
    model,
    max_tokens,
    temperature,
    debug,
    log_file,

    pub fn toString(self: Key) []const u8 {
        return switch (self) {
            .api_key => "api_key",
            .model => "model",
            .max_tokens => "max_tokens",
            .temperature => "temperature",
            .debug => "debug",
            .log_file => "log_file",
        };
    }
};

/// Configuration store
pub const Config = struct {
    values: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .values = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        try self.values.put(key, value);
    }

    pub fn get(self: *Self, key: []const u8) ?[]const u8 {
        return self.values.get(key);
    }

    pub fn setKey(self: *Self, key: Key, value: []const u8) !void {
        try self.set(key.toString(), value);
    }

    pub fn getKey(self: *Self, key: Key) ?[]const u8 {
        return self.get(key.toString());
    }

    pub fn getBool(self: *Self, key: []const u8) bool {
        if (self.get(key)) |v| {
            return std.mem.eql(u8, v, "true") or std.mem.eql(u8, v, "1");
        }
        return false;
    }

    pub fn getInt(self: *Self, key: []const u8) ?i64 {
        if (self.get(key)) |v| {
            return std.fmt.parseInt(i64, v, 10) catch null;
        }
        return null;
    }

    pub fn count(self: *Self) usize {
        return self.values.count();
    }
};

/// Default configuration
pub fn defaults(allocator: std.mem.Allocator) !Config {
    var config = Config.init(allocator);
    try config.setKey(.model, "claude-3-5-sonnet-20241022");
    try config.setKey(.max_tokens, "8192");
    try config.setKey(.temperature, "0.7");
    try config.setKey(.debug, "false");
    return config;
}

// Tests
test "config_set_get" {
    const allocator = std.testing.allocator;
    var config = Config.init(allocator);
    defer config.deinit();

    try config.set("key", "value");
    try std.testing.expectEqualStrings("value", config.get("key").?);
}

test "config_set_key" {
    const allocator = std.testing.allocator;
    var config = Config.init(allocator);
    defer config.deinit();

    try config.setKey(.model, "gpt-4");
    try std.testing.expectEqualStrings("gpt-4", config.getKey(.model).?);
}

test "config_get_bool" {
    const allocator = std.testing.allocator;
    var config = Config.init(allocator);
    defer config.deinit();

    try config.set("enabled", "true");
    try config.set("disabled", "false");

    try std.testing.expect(config.getBool("enabled"));
    try std.testing.expect(!config.getBool("disabled"));
    try std.testing.expect(!config.getBool("missing"));
}

test "config_get_int" {
    const allocator = std.testing.allocator;
    var config = Config.init(allocator);
    defer config.deinit();

    try config.set("count", "42");
    try std.testing.expectEqual(@as(?i64, 42), config.getInt("count"));
    try std.testing.expect(config.getInt("missing") == null);
}

test "key_to_string" {
    try std.testing.expectEqualStrings("api_key", Key.api_key.toString());
    try std.testing.expectEqualStrings("model", Key.model.toString());
}

test "defaults" {
    const allocator = std.testing.allocator;
    var config = try defaults(allocator);
    defer config.deinit();

    try std.testing.expect(config.getKey(.model) != null);
    try std.testing.expect(config.getKey(.max_tokens) != null);
}
