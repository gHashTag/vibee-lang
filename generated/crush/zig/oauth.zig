// oauth.zig - OAuth Token Module
// Generated from: crush/internal/oauth
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// OAuth token
pub const Token = struct {
    access_token: []const u8,
    token_type: []const u8,
    refresh_token: ?[]const u8,
    expires_at: ?i64,

    const Self = @This();

    /// Check if token is expired
    pub fn isExpired(self: Self) bool {
        if (self.expires_at) |exp| {
            return std.time.timestamp() >= exp;
        }
        return false;
    }

    /// Check if token is valid
    pub fn isValid(self: Self) bool {
        return self.access_token.len > 0 and !self.isExpired();
    }
};

/// Token store
pub const Store = struct {
    tokens: std.StringHashMap(Token),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .tokens = std.StringHashMap(Token).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    pub fn set(self: *Self, key: []const u8, token: Token) !void {
        try self.tokens.put(key, token);
    }

    pub fn get(self: *Self, key: []const u8) ?Token {
        return self.tokens.get(key);
    }

    pub fn remove(self: *Self, key: []const u8) void {
        _ = self.tokens.remove(key);
    }

    pub fn count(self: *Self) usize {
        return self.tokens.count();
    }
};

// Tests
test "token_is_valid" {
    const token = Token{
        .access_token = "abc123",
        .token_type = "Bearer",
        .refresh_token = null,
        .expires_at = null,
    };
    try std.testing.expect(token.isValid());
}

test "token_is_expired" {
    const token = Token{
        .access_token = "abc123",
        .token_type = "Bearer",
        .refresh_token = null,
        .expires_at = 0, // Already expired
    };
    try std.testing.expect(token.isExpired());
    try std.testing.expect(!token.isValid());
}

test "token_not_expired" {
    const future = std.time.timestamp() + 3600;
    const token = Token{
        .access_token = "abc123",
        .token_type = "Bearer",
        .refresh_token = null,
        .expires_at = future,
    };
    try std.testing.expect(!token.isExpired());
}

test "store_set_get" {
    const allocator = std.testing.allocator;
    var store = Store.init(allocator);
    defer store.deinit();

    const token = Token{
        .access_token = "token123",
        .token_type = "Bearer",
        .refresh_token = null,
        .expires_at = null,
    };

    try store.set("user1", token);
    const retrieved = store.get("user1");

    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("token123", retrieved.?.access_token);
}

test "store_remove" {
    const allocator = std.testing.allocator;
    var store = Store.init(allocator);
    defer store.deinit();

    try store.set("user1", Token{ .access_token = "t", .token_type = "B", .refresh_token = null, .expires_at = null });
    store.remove("user1");

    try std.testing.expect(store.get("user1") == null);
}
