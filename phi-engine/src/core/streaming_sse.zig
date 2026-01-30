// Server-Sent Events (SSE) Streaming for VIBEE Agents
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37
// Real-time streaming for AI agent communication

const std = @import("std");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const GOLDEN_IDENTITY: f64 = 3.0;
const PHOENIX: u32 = 999;

// SSE Event Types
pub const EventType = enum {
    message,
    token,
    thinking,
    tool_call,
    tool_result,
    err,
    done,
    heartbeat,
    
    pub fn toString(self: EventType) []const u8 {
        return switch (self) {
            .message => "message",
            .token => "token",
            .thinking => "thinking",
            .tool_call => "tool_call",
            .tool_result => "tool_result",
            .err => "error",
            .done => "done",
            .heartbeat => "heartbeat",
        };
    }
};

// SSE Event
pub const SSEEvent = struct {
    id: ?u64,
    event_type: EventType,
    data: []const u8,
    retry: ?u32,
    
    const Self = @This();
    
    pub fn init(event_type: EventType, data: []const u8) Self {
        return Self{
            .id = null,
            .event_type = event_type,
            .data = data,
            .retry = null,
        };
    }
    
    pub fn withId(self: Self, id: u64) Self {
        var new = self;
        new.id = id;
        return new;
    }
    
    pub fn withRetry(self: Self, retry: u32) Self {
        var new = self;
        new.retry = retry;
        return new;
    }
    
    // Format as SSE wire format
    pub fn format(self: Self, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();
        
        // Event ID
        if (self.id) |id| {
            try writer.print("id: {d}\n", .{id});
        }
        
        // Event type
        try writer.print("event: {s}\n", .{self.event_type.toString()});
        
        // Retry interval
        if (self.retry) |retry| {
            try writer.print("retry: {d}\n", .{retry});
        }
        
        // Data (handle multi-line)
        var lines = std.mem.splitScalar(u8, self.data, '\n');
        while (lines.next()) |line| {
            try writer.print("data: {s}\n", .{line});
        }
        
        // End of event
        try writer.writeAll("\n");
        
        return buffer.toOwnedSlice();
    }
};

// Token stream for LLM output
pub const TokenStream = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList([]const u8),
    current_index: usize,
    total_tokens: u64,
    start_time: i64,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .tokens = std.ArrayList([]const u8).init(allocator),
            .current_index = 0,
            .total_tokens = 0,
            .start_time = std.time.milliTimestamp(),
        };
    }
    
    pub fn deinit(self: *Self) void {
        for (self.tokens.items) |token| {
            self.allocator.free(token);
        }
        self.tokens.deinit();
    }
    
    pub fn addToken(self: *Self, token: []const u8) !void {
        const token_copy = try self.allocator.dupe(u8, token);
        try self.tokens.append(token_copy);
        self.total_tokens += 1;
    }
    
    pub fn nextToken(self: *Self) ?[]const u8 {
        if (self.current_index >= self.tokens.items.len) {
            return null;
        }
        const token = self.tokens.items[self.current_index];
        self.current_index += 1;
        return token;
    }
    
    pub fn tokensPerSecond(self: *Self) f64 {
        const elapsed = std.time.milliTimestamp() - self.start_time;
        if (elapsed <= 0) return 0;
        return @as(f64, @floatFromInt(self.total_tokens)) / (@as(f64, @floatFromInt(elapsed)) / 1000.0);
    }
    
    pub fn reset(self: *Self) void {
        self.current_index = 0;
    }
};

// SSE Connection state
pub const ConnectionState = enum {
    connecting,
    open,
    closed,
    error_state,
};

// SSE Stream handler
pub const SSEStream = struct {
    allocator: std.mem.Allocator,
    event_id: u64,
    state: ConnectionState,
    buffer: std.ArrayList(u8),
    heartbeat_interval: u32, // milliseconds
    last_heartbeat: i64,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .event_id = 0,
            .state = .connecting,
            .buffer = std.ArrayList(u8).init(allocator),
            .heartbeat_interval = 15000, // 15 seconds
            .last_heartbeat = std.time.milliTimestamp(),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }
    
    pub fn open(self: *Self) void {
        self.state = .open;
    }
    
    pub fn close(self: *Self) void {
        self.state = .closed;
    }
    
    pub fn isOpen(self: *Self) bool {
        return self.state == .open;
    }
    
    // Send an event
    pub fn send(self: *Self, event_type: EventType, data: []const u8) ![]u8 {
        self.event_id += 1;
        const event = SSEEvent.init(event_type, data).withId(self.event_id);
        return event.format(self.allocator);
    }
    
    // Send token (for LLM streaming)
    pub fn sendToken(self: *Self, token: []const u8) ![]u8 {
        return self.send(.token, token);
    }
    
    // Send thinking indicator
    pub fn sendThinking(self: *Self, thought: []const u8) ![]u8 {
        return self.send(.thinking, thought);
    }
    
    // Send tool call
    pub fn sendToolCall(self: *Self, tool_name: []const u8) ![]u8 {
        return self.send(.tool_call, tool_name);
    }
    
    // Send error
    pub fn sendError(self: *Self, error_msg: []const u8) ![]u8 {
        return self.send(.err, error_msg);
    }
    
    // Send done signal
    pub fn sendDone(self: *Self) ![]u8 {
        return self.send(.done, "stream_complete");
    }
    
    // Check if heartbeat needed
    pub fn needsHeartbeat(self: *Self) bool {
        const now = std.time.milliTimestamp();
        return (now - self.last_heartbeat) >= self.heartbeat_interval;
    }
    
    // Send heartbeat
    pub fn sendHeartbeat(self: *Self) ![]u8 {
        self.last_heartbeat = std.time.milliTimestamp();
        return self.send(.heartbeat, "ping");
    }
};

// Agent streaming context
pub const AgentStreamContext = struct {
    allocator: std.mem.Allocator,
    stream: SSEStream,
    token_stream: TokenStream,
    agent_id: []const u8,
    session_id: u64,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, agent_id: []const u8) Self {
        return Self{
            .allocator = allocator,
            .stream = SSEStream.init(allocator),
            .token_stream = TokenStream.init(allocator),
            .agent_id = agent_id,
            .session_id = @intCast(std.time.milliTimestamp()),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.stream.deinit();
        self.token_stream.deinit();
    }
    
    // Start streaming session
    pub fn start(self: *Self) ![]u8 {
        self.stream.open();
        
        // Send session start event
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "{{\"agent\":\"{s}\",\"session\":{d}}}", .{
            self.agent_id,
            self.session_id,
        });
        
        return self.stream.send(.message, msg);
    }
    
    // Stream a response token by token
    pub fn streamResponse(self: *Self, response: []const u8) !std.ArrayList([]u8) {
        var events = std.ArrayList([]u8).init(self.allocator);
        
        // Simulate token-by-token streaming
        var i: usize = 0;
        while (i < response.len) {
            // Find word boundary
            var end = i + 1;
            while (end < response.len and response[end] != ' ' and response[end] != '\n') {
                end += 1;
            }
            if (end < response.len) end += 1; // Include space
            
            const token = response[i..end];
            try self.token_stream.addToken(token);
            
            const event = try self.stream.sendToken(token);
            try events.append(event);
            
            i = end;
        }
        
        // Send done
        const done_event = try self.stream.sendDone();
        try events.append(done_event);
        
        return events;
    }
    
    // Get streaming statistics
    pub fn getStats(self: *Self) StreamStats {
        return StreamStats{
            .total_tokens = self.token_stream.total_tokens,
            .tokens_per_second = self.token_stream.tokensPerSecond(),
            .event_count = self.stream.event_id,
            .session_id = self.session_id,
        };
    }
};

pub const StreamStats = struct {
    total_tokens: u64,
    tokens_per_second: f64,
    event_count: u64,
    session_id: u64,
};

// HTTP headers for SSE
pub const SSE_HEADERS =
    \\Content-Type: text/event-stream
    \\Cache-Control: no-cache
    \\Connection: keep-alive
    \\Access-Control-Allow-Origin: *
    \\
;

// Tests
test "SSEEvent format" {
    const allocator = std.testing.allocator;
    
    const event = SSEEvent.init(.token, "Hello").withId(1);
    const formatted = try event.format(allocator);
    defer allocator.free(formatted);
    
    try std.testing.expect(std.mem.indexOf(u8, formatted, "id: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "event: token") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "data: Hello") != null);
}

test "SSEStream send" {
    const allocator = std.testing.allocator;
    
    var stream = SSEStream.init(allocator);
    defer stream.deinit();
    
    stream.open();
    try std.testing.expect(stream.isOpen());
    
    const event = try stream.sendToken("test");
    defer allocator.free(event);
    
    try std.testing.expect(event.len > 0);
    try std.testing.expect(stream.event_id == 1);
}

test "TokenStream" {
    const allocator = std.testing.allocator;
    
    var ts = TokenStream.init(allocator);
    defer ts.deinit();
    
    try ts.addToken("Hello");
    try ts.addToken(" ");
    try ts.addToken("World");
    
    try std.testing.expectEqual(@as(u64, 3), ts.total_tokens);
    
    const t1 = ts.nextToken();
    try std.testing.expect(t1 != null);
    try std.testing.expectEqualStrings("Hello", t1.?);
}

test "AgentStreamContext" {
    const allocator = std.testing.allocator;
    
    var ctx = AgentStreamContext.init(allocator, "test-agent");
    defer ctx.deinit();
    
    const start_event = try ctx.start();
    defer allocator.free(start_event);
    
    try std.testing.expect(ctx.stream.isOpen());
    
    var events = try ctx.streamResponse("Hello World");
    defer {
        for (events.items) |e| {
            allocator.free(e);
        }
        events.deinit();
    }
    
    // "Hello " + "World" + done = 3 events
    try std.testing.expect(events.items.len >= 2);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
