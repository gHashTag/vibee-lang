// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE REAL AGENT - Working Browser Automation with LLM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Integrates:
// - Chrome CDP via WebSocket for browser control
// - Ollama HTTP API for LLM reasoning
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const websocket = @import("websocket.zig");
const http_client = @import("http_client.zig");

pub const AgentError = error{
    BrowserConnectionFailed,
    LLMConnectionFailed,
    NavigationFailed,
    EvaluationFailed,
    ParseError,
    OutOfMemory,
};

pub const AgentConfig = struct {
    chrome_host: []const u8 = "localhost",
    chrome_port: u16 = 9222,
    ollama_host: []const u8 = "localhost",
    ollama_port: u16 = 11434,
    model: []const u8 = "qwen2.5:0.5b",
};

pub const RealAgent = struct {
    allocator: Allocator,
    config: AgentConfig,
    ws: websocket.WebSocketClient,
    http: http_client.HttpClient,
    connected: bool,
    message_id: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, config: AgentConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .ws = websocket.WebSocketClient.init(allocator),
            .http = http_client.HttpClient.init(allocator),
            .connected = false,
            .message_id = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        self.ws.deinit();
        self.http.deinit();
    }

    /// Connect to Chrome browser via CDP
    pub fn connectBrowser(self: *Self, ws_url: []const u8) AgentError!void {
        self.ws.connect(ws_url) catch return AgentError.BrowserConnectionFailed;
        self.connected = true;
    }

    /// Navigate to URL
    pub fn navigate(self: *Self, url: []const u8) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [1024]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Page.navigate\",\"params\":{{\"url\":\"{s}\"}}}}", .{ self.message_id, url }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.NavigationFailed;

        // Read response
        const frame = self.ws.receive() catch return AgentError.NavigationFailed;
        self.allocator.free(frame.payload);
    }

    /// Get page title
    pub fn getTitle(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.title\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Extract title from response
        // Response format: {"id":N,"result":{"result":{"type":"string","value":"Title"}}}
        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"")) |start| {
            const value_start = start + 9;
            if (std.mem.indexOf(u8, frame.payload[value_start..], "\"")) |end| {
                return self.allocator.dupe(u8, frame.payload[value_start .. value_start + end]) catch return AgentError.OutOfMemory;
            }
        }

        return AgentError.ParseError;
    }

    /// Get page text content
    pub fn getPageText(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.body.innerText\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Extract text from response
        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"")) |start| {
            const value_start = start + 9;
            if (std.mem.lastIndexOf(u8, frame.payload, "\"")) |end| {
                if (end > value_start) {
                    return self.allocator.dupe(u8, frame.payload[value_start..end]) catch return AgentError.OutOfMemory;
                }
            }
        }

        return AgentError.ParseError;
    }

    /// Ask LLM a question about the page
    pub fn askLLM(self: *Self, prompt: []const u8) AgentError![]const u8 {
        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "http://{s}:{d}/api/generate", .{ self.config.ollama_host, self.config.ollama_port }) catch return AgentError.OutOfMemory;

        // Build JSON body
        var body_buf: [8192]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf, "{{\"model\":\"{s}\",\"prompt\":\"{s}\",\"stream\":false}}", .{ self.config.model, prompt }) catch return AgentError.OutOfMemory;

        var response = self.http.post(url, body, "application/json") catch return AgentError.LLMConnectionFailed;
        defer response.deinit();

        if (response.status != 200) {
            return AgentError.LLMConnectionFailed;
        }

        // Extract response text from JSON
        // Format: {"model":"...","response":"ANSWER",...}
        if (std.mem.indexOf(u8, response.body, "\"response\":\"")) |start| {
            const value_start = start + 12;
            // Find closing quote (handle escaped quotes)
            var end = value_start;
            var escaped = false;
            while (end < response.body.len) : (end += 1) {
                if (escaped) {
                    escaped = false;
                    continue;
                }
                if (response.body[end] == '\\') {
                    escaped = true;
                    continue;
                }
                if (response.body[end] == '"') {
                    break;
                }
            }
            if (end > value_start) {
                return self.allocator.dupe(u8, response.body[value_start..end]) catch return AgentError.OutOfMemory;
            }
        }

        return AgentError.ParseError;
    }

    /// Close connection
    pub fn close(self: *Self) void {
        self.ws.close();
        self.connected = false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RealAgent initialization" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    try std.testing.expect(!agent.connected);
    try std.testing.expectEqual(@as(u32, 1), agent.message_id);
}

test "AgentConfig defaults" {
    const config = AgentConfig{};
    try std.testing.expectEqualStrings("localhost", config.chrome_host);
    try std.testing.expectEqual(@as(u16, 9222), config.chrome_port);
    try std.testing.expectEqual(@as(u16, 11434), config.ollama_port);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "RealAgent close without connection" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should not crash
    agent.close();
    try std.testing.expect(!agent.connected);
}
