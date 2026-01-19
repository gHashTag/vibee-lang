// permission.zig - Permission Module
// Generated from: crush/internal/permission
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Permission request
pub const Request = struct {
    id: []const u8,
    session_id: []const u8,
    tool_call_id: []const u8,
    tool_name: []const u8,
    description: []const u8,
    action: []const u8,
    path: []const u8,
};

/// Permission notification
pub const Notification = struct {
    tool_call_id: []const u8,
    granted: bool,
    denied: bool,
};

/// Permission service
pub const Service = struct {
    pending: std.StringHashMap(Request),
    granted: std.ArrayList(Request),
    allowed_tools: std.ArrayList([]const u8),
    skip_requests: bool,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .pending = std.StringHashMap(Request).init(allocator),
            .granted = std.ArrayList(Request).init(allocator),
            .allowed_tools = std.ArrayList([]const u8).init(allocator),
            .skip_requests = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.pending.deinit();
        self.granted.deinit();
        self.allowed_tools.deinit();
    }

    /// Grant permission
    pub fn grant(self: *Self, request: Request) !void {
        _ = self.pending.remove(request.id);
        try self.granted.append(request);
    }

    /// Deny permission
    pub fn deny(self: *Self, request: Request) void {
        _ = self.pending.remove(request.id);
    }

    /// Check if tool is allowed
    pub fn isAllowed(self: *Self, tool_name: []const u8, action: []const u8) bool {
        if (self.skip_requests) return true;

        const command_key_buf = std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ tool_name, action }) catch return false;
        defer self.allocator.free(command_key_buf);

        for (self.allowed_tools.items) |allowed| {
            if (std.mem.eql(u8, allowed, tool_name) or std.mem.eql(u8, allowed, command_key_buf)) {
                return true;
            }
        }

        return false;
    }

    /// Add allowed tool
    pub fn addAllowedTool(self: *Self, tool: []const u8) !void {
        try self.allowed_tools.append(tool);
    }

    /// Set skip requests
    pub fn setSkipRequests(self: *Self, skip: bool) void {
        self.skip_requests = skip;
    }

    /// Check if permission was granted for path
    pub fn hasPermission(self: *Self, tool_name: []const u8, action: []const u8, path: []const u8, session_id: []const u8) bool {
        for (self.granted.items) |p| {
            if (std.mem.eql(u8, p.tool_name, tool_name) and
                std.mem.eql(u8, p.action, action) and
                std.mem.eql(u8, p.path, path) and
                std.mem.eql(u8, p.session_id, session_id))
            {
                return true;
            }
        }
        return false;
    }

    pub fn pendingCount(self: *Self) usize {
        return self.pending.count();
    }

    pub fn grantedCount(self: *Self) usize {
        return self.granted.items.len;
    }
};

// Tests
test "grant_permission" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const request = Request{
        .id = "req1",
        .session_id = "session1",
        .tool_call_id = "tool1",
        .tool_name = "file_write",
        .description = "Write file",
        .action = "write",
        .path = "/path/to/file",
    };

    try service.grant(request);
    try std.testing.expectEqual(@as(usize, 1), service.grantedCount());
}

test "is_allowed_tool" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    try service.addAllowedTool("file_read");
    try std.testing.expect(service.isAllowed("file_read", "read"));
    try std.testing.expect(!service.isAllowed("file_write", "write"));
}

test "skip_requests" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    service.setSkipRequests(true);
    try std.testing.expect(service.isAllowed("any_tool", "any_action"));
}

test "has_permission" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const request = Request{
        .id = "req1",
        .session_id = "s1",
        .tool_call_id = "t1",
        .tool_name = "file_write",
        .description = "Write",
        .action = "write",
        .path = "/file.txt",
    };

    try service.grant(request);
    try std.testing.expect(service.hasPermission("file_write", "write", "/file.txt", "s1"));
    try std.testing.expect(!service.hasPermission("file_write", "write", "/other.txt", "s1"));
}

test "deny_permission" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    try service.pending.put("req1", Request{
        .id = "req1",
        .session_id = "s1",
        .tool_call_id = "t1",
        .tool_name = "tool",
        .description = "desc",
        .action = "act",
        .path = "/path",
    });

    service.deny(Request{ .id = "req1", .session_id = "", .tool_call_id = "", .tool_name = "", .description = "", .action = "", .path = "" });
    try std.testing.expectEqual(@as(usize, 0), service.pendingCount());
}
