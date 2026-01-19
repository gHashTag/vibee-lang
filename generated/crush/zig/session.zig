// session.zig - Session Management Module
// Generated from: crush/internal/session
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Todo status
pub const TodoStatus = enum {
    pending,
    in_progress,
    completed,

    pub fn toString(self: TodoStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .in_progress => "in_progress",
            .completed => "completed",
        };
    }
};

/// Todo item
pub const Todo = struct {
    content: []const u8,
    status: TodoStatus,
    active_form: []const u8,
};

/// Session record
pub const Session = struct {
    id: []const u8,
    parent_session_id: ?[]const u8,
    title: []const u8,
    message_count: i64,
    prompt_tokens: i64,
    completion_tokens: i64,
    summary_message_id: ?[]const u8,
    cost: f64,
    todos: std.ArrayList(Todo),
    created_at: i64,
    updated_at: i64,
};

/// In-memory session service
pub const Service = struct {
    sessions: std.StringHashMap(Session),
    allocator: std.mem.Allocator,
    next_id: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .sessions = std.StringHashMap(Session).init(allocator),
            .allocator = allocator,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.sessions.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.todos.deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.sessions.deinit();
    }

    fn generateId(self: *Self) ![]u8 {
        const id = try std.fmt.allocPrint(self.allocator, "session_{d}", .{self.next_id});
        self.next_id += 1;
        return id;
    }

    /// Create new session
    pub fn create(self: *Self, title: []const u8) !Session {
        const id = try self.generateId();
        const now = std.time.milliTimestamp();

        const session = Session{
            .id = id,
            .parent_session_id = null,
            .title = title,
            .message_count = 0,
            .prompt_tokens = 0,
            .completion_tokens = 0,
            .summary_message_id = null,
            .cost = 0.0,
            .todos = std.ArrayList(Todo).init(self.allocator),
            .created_at = now,
            .updated_at = now,
        };

        try self.sessions.put(id, session);
        return session;
    }

    /// Get session by ID
    pub fn get(self: *Self, id: []const u8) ?Session {
        return self.sessions.get(id);
    }

    /// List all sessions
    pub fn list(self: *Self, allocator: std.mem.Allocator) ![]Session {
        var result = std.ArrayList(Session).init(allocator);
        var iter = self.sessions.iterator();
        while (iter.next()) |entry| {
            try result.append(entry.value_ptr.*);
        }
        return result.toOwnedSlice();
    }

    /// Delete session
    pub fn delete(self: *Self, id: []const u8) bool {
        if (self.sessions.fetchRemove(id)) |kv| {
            kv.value.todos.deinit();
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    /// Update session title and usage
    pub fn updateTitleAndUsage(self: *Self, id: []const u8, title: []const u8, prompt_tokens: i64, completion_tokens: i64, cost: f64) !void {
        if (self.sessions.getPtr(id)) |session| {
            session.title = title;
            session.prompt_tokens = prompt_tokens;
            session.completion_tokens = completion_tokens;
            session.cost = cost;
            session.updated_at = std.time.milliTimestamp();
        }
    }

    /// Get session count
    pub fn count(self: *Self) usize {
        return self.sessions.count();
    }

    /// Create agent tool session ID
    pub fn createAgentToolSessionId(_: *Self, message_id: []const u8, tool_call_id: []const u8) ![]u8 {
        return std.fmt.allocPrint(std.heap.page_allocator, "agent-tool:{s}:{s}", .{ message_id, tool_call_id });
    }

    /// Check if session is agent tool session
    pub fn isAgentToolSession(_: *Self, session_id: []const u8) bool {
        return std.mem.startsWith(u8, session_id, "agent-tool:");
    }
};

// Tests
test "create_session" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const session = try service.create("Test Session");
    try std.testing.expectEqualStrings("Test Session", session.title);
    try std.testing.expectEqual(@as(i64, 0), session.message_count);
}

test "get_session" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const created = try service.create("Test");
    const retrieved = service.get(created.id);

    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings(created.title, retrieved.?.title);
}

test "list_sessions" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("Session 1");
    _ = try service.create("Session 2");

    const sessions = try service.list(allocator);
    defer allocator.free(sessions);

    try std.testing.expectEqual(@as(usize, 2), sessions.len);
}

test "delete_session" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const session = try service.create("To Delete");
    try std.testing.expectEqual(@as(usize, 1), service.count());

    const deleted = service.delete(session.id);
    try std.testing.expect(deleted);
    try std.testing.expectEqual(@as(usize, 0), service.count());
}

test "todo_status" {
    try std.testing.expectEqualStrings("pending", TodoStatus.pending.toString());
    try std.testing.expectEqualStrings("in_progress", TodoStatus.in_progress.toString());
    try std.testing.expectEqualStrings("completed", TodoStatus.completed.toString());
}

test "is_agent_tool_session" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    try std.testing.expect(service.isAgentToolSession("agent-tool:msg1:tool1"));
    try std.testing.expect(!service.isAgentToolSession("regular-session"));
}
