// agent.zig - Agent Module
// Generated from: crush/internal/agent
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Agent state
pub const State = enum {
    idle,
    thinking,
    executing,
    waiting_permission,
    completed,
    err,

    pub fn toString(self: State) []const u8 {
        return switch (self) {
            .idle => "idle",
            .thinking => "thinking",
            .executing => "executing",
            .waiting_permission => "waiting_permission",
            .completed => "completed",
            .err => "error",
        };
    }
};

/// Tool call
pub const ToolCall = struct {
    id: []const u8,
    name: []const u8,
    input: []const u8,
    output: ?[]const u8,
    is_error: bool,
};

/// Agent
pub const Agent = struct {
    id: []const u8,
    session_id: []const u8,
    state: State,
    tool_calls: std.ArrayList(ToolCall),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, id: []const u8, session_id: []const u8) Self {
        return Self{
            .id = id,
            .session_id = session_id,
            .state = .idle,
            .tool_calls = std.ArrayList(ToolCall).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tool_calls.deinit();
    }

    pub fn setState(self: *Self, state: State) void {
        self.state = state;
    }

    pub fn addToolCall(self: *Self, call: ToolCall) !void {
        try self.tool_calls.append(call);
    }

    pub fn getToolCallCount(self: *Self) usize {
        return self.tool_calls.items.len;
    }

    pub fn isActive(self: *Self) bool {
        return self.state == .thinking or self.state == .executing;
    }
};

/// Agent registry
pub const Registry = struct {
    agents: std.StringHashMap(Agent),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .agents = std.StringHashMap(Agent).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.agents.deinit();
    }

    pub fn register(self: *Self, agent: Agent) !void {
        try self.agents.put(agent.id, agent);
    }

    pub fn get(self: *Self, id: []const u8) ?*Agent {
        return self.agents.getPtr(id);
    }

    pub fn count(self: *Self) usize {
        return self.agents.count();
    }
};

// Tests
test "state_to_string" {
    try std.testing.expectEqualStrings("idle", State.idle.toString());
    try std.testing.expectEqualStrings("thinking", State.thinking.toString());
    try std.testing.expectEqualStrings("executing", State.executing.toString());
}

test "agent_init" {
    const allocator = std.testing.allocator;
    var agent = Agent.init(allocator, "agent1", "session1");
    defer agent.deinit();

    try std.testing.expectEqual(State.idle, agent.state);
    try std.testing.expectEqualStrings("agent1", agent.id);
}

test "agent_set_state" {
    const allocator = std.testing.allocator;
    var agent = Agent.init(allocator, "agent1", "session1");
    defer agent.deinit();

    agent.setState(.thinking);
    try std.testing.expectEqual(State.thinking, agent.state);
}

test "agent_add_tool_call" {
    const allocator = std.testing.allocator;
    var agent = Agent.init(allocator, "agent1", "session1");
    defer agent.deinit();

    try agent.addToolCall(ToolCall{
        .id = "call1",
        .name = "file_read",
        .input = "{}",
        .output = null,
        .is_error = false,
    });

    try std.testing.expectEqual(@as(usize, 1), agent.getToolCallCount());
}

test "agent_is_active" {
    const allocator = std.testing.allocator;
    var agent = Agent.init(allocator, "agent1", "session1");
    defer agent.deinit();

    try std.testing.expect(!agent.isActive());
    agent.setState(.thinking);
    try std.testing.expect(agent.isActive());
}

test "registry" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const agent = Agent.init(allocator, "agent1", "session1");
    try registry.register(agent);

    try std.testing.expectEqual(@as(usize, 1), registry.count());
}
