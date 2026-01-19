// message.zig - Message Content Module
// Generated from: crush/internal/message
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Message role
pub const Role = enum {
    assistant,
    user,
    system,
    tool,

    pub fn toString(self: Role) []const u8 {
        return switch (self) {
            .assistant => "assistant",
            .user => "user",
            .system => "system",
            .tool => "tool",
        };
    }
};

/// Finish reason
pub const FinishReason = enum {
    end_turn,
    max_tokens,
    tool_use,
    canceled,
    err,
    permission_denied,
    unknown,

    pub fn toString(self: FinishReason) []const u8 {
        return switch (self) {
            .end_turn => "end_turn",
            .max_tokens => "max_tokens",
            .tool_use => "tool_use",
            .canceled => "canceled",
            .err => "error",
            .permission_denied => "permission_denied",
            .unknown => "unknown",
        };
    }
};

/// Content type
pub const ContentType = enum {
    text,
    reasoning,
    tool_use,
    tool_result,
    image,
};

/// Text content
pub const TextContent = struct {
    text: []const u8,
    content_type: ContentType = .text,
};

/// Reasoning content
pub const ReasoningContent = struct {
    thinking: []const u8,
    signature: ?[]const u8,
    started_at: ?i64,
    finished_at: ?i64,
    content_type: ContentType = .reasoning,
};

/// Tool use content
pub const ToolUseContent = struct {
    id: []const u8,
    name: []const u8,
    input: []const u8,
    content_type: ContentType = .tool_use,
};

/// Tool result content
pub const ToolResultContent = struct {
    tool_use_id: []const u8,
    content: []const u8,
    is_error: bool,
    content_type: ContentType = .tool_result,
};

/// Message
pub const Message = struct {
    id: []const u8,
    session_id: []const u8,
    role: Role,
    content: std.ArrayList(TextContent),
    finish_reason: ?FinishReason,
    model: ?[]const u8,
    created_at: i64,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, id: []const u8, session_id: []const u8, role: Role) Self {
        return Self{
            .id = id,
            .session_id = session_id,
            .role = role,
            .content = std.ArrayList(TextContent).init(allocator),
            .finish_reason = null,
            .model = null,
            .created_at = std.time.milliTimestamp(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.content.deinit();
    }

    pub fn addText(self: *Self, text: []const u8) !void {
        try self.content.append(TextContent{ .text = text });
    }

    pub fn getText(self: *Self) []const u8 {
        if (self.content.items.len == 0) return "";
        return self.content.items[0].text;
    }

    pub fn getContentCount(self: *Self) usize {
        return self.content.items.len;
    }
};

/// Message builder
pub const Builder = struct {
    allocator: std.mem.Allocator,
    role: Role,
    content: std.ArrayList(TextContent),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .role = .user,
            .content = std.ArrayList(TextContent).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.content.deinit();
    }

    pub fn setRole(self: *Self, role: Role) *Self {
        self.role = role;
        return self;
    }

    pub fn addText(self: *Self, text: []const u8) !*Self {
        try self.content.append(TextContent{ .text = text });
        return self;
    }

    pub fn build(self: *Self, id: []const u8, session_id: []const u8) Message {
        var msg = Message.init(self.allocator, id, session_id, self.role);
        msg.content = self.content.clone() catch std.ArrayList(TextContent).init(self.allocator);
        return msg;
    }
};

// Tests
test "role_to_string" {
    try std.testing.expectEqualStrings("assistant", Role.assistant.toString());
    try std.testing.expectEqualStrings("user", Role.user.toString());
    try std.testing.expectEqualStrings("system", Role.system.toString());
    try std.testing.expectEqualStrings("tool", Role.tool.toString());
}

test "finish_reason_to_string" {
    try std.testing.expectEqualStrings("end_turn", FinishReason.end_turn.toString());
    try std.testing.expectEqualStrings("max_tokens", FinishReason.max_tokens.toString());
    try std.testing.expectEqualStrings("error", FinishReason.err.toString());
}

test "message_init" {
    const allocator = std.testing.allocator;
    var msg = Message.init(allocator, "msg1", "session1", .user);
    defer msg.deinit();

    try std.testing.expectEqualStrings("msg1", msg.id);
    try std.testing.expectEqual(Role.user, msg.role);
}

test "message_add_text" {
    const allocator = std.testing.allocator;
    var msg = Message.init(allocator, "msg1", "session1", .user);
    defer msg.deinit();

    try msg.addText("Hello, world!");
    try std.testing.expectEqual(@as(usize, 1), msg.getContentCount());
    try std.testing.expectEqualStrings("Hello, world!", msg.getText());
}

test "builder" {
    const allocator = std.testing.allocator;
    var builder = Builder.init(allocator);
    defer builder.deinit();

    _ = builder.setRole(.assistant);
    _ = try builder.addText("Response");

    var msg = builder.build("msg1", "session1");
    defer msg.deinit();

    try std.testing.expectEqual(Role.assistant, msg.role);
}

test "text_content" {
    const content = TextContent{ .text = "Hello" };
    try std.testing.expectEqualStrings("Hello", content.text);
    try std.testing.expectEqual(ContentType.text, content.content_type);
}
