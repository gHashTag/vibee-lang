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

        // Limit URL length to prevent buffer overflow
        const safe_url = if (url.len > 500) url[0..500] else url;

        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Page.navigate\",\"params\":{{\"url\":\"{s}\"}}}}", .{ self.message_id, safe_url }) catch return AgentError.OutOfMemory;
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

    /// Click element by CSS selector
    /// Uses Runtime.evaluate to get element coordinates, then dispatches mouse events
    pub fn clickSelector(self: *Self, selector: []const u8) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // Step 1: Get element bounding box via JavaScript
        var cmd_buf: [2048]u8 = undefined;

        // Escape selector for JS string (single quotes)
        var escaped_selector: [512]u8 = undefined;
        var escaped_len: usize = 0;
        for (selector) |c| {
            if (c == '\'' or c == '\\') {
                escaped_selector[escaped_len] = '\\';
                escaped_len += 1;
            }
            escaped_selector[escaped_len] = c;
            escaped_len += 1;
        }

        // Build JS expression
        var js_buf: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf, "(function(){{var el=document.querySelector('{s}');if(!el)return null;var r=el.getBoundingClientRect();return {{x:r.x+r.width/2,y:r.y+r.height/2}};}})()", .{escaped_selector[0..escaped_len]}) catch return AgentError.OutOfMemory;

        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"{s}\",\"returnByValue\":true}}}}", .{ self.message_id, js }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Parse coordinates from response
        // Format: {"id":N,"result":{"result":{"type":"object","value":{"x":123,"y":456}}}}
        var x: f64 = 0;
        var y: f64 = 0;

        if (std.mem.indexOf(u8, frame.payload, "\"x\":")) |x_start| {
            const x_val_start = x_start + 4;
            var x_end = x_val_start;
            while (x_end < frame.payload.len and (frame.payload[x_end] == '.' or (frame.payload[x_end] >= '0' and frame.payload[x_end] <= '9'))) : (x_end += 1) {}
            x = std.fmt.parseFloat(f64, frame.payload[x_val_start..x_end]) catch 0;
        }

        if (std.mem.indexOf(u8, frame.payload, "\"y\":")) |y_start| {
            const y_val_start = y_start + 4;
            var y_end = y_val_start;
            while (y_end < frame.payload.len and (frame.payload[y_end] == '.' or (frame.payload[y_end] >= '0' and frame.payload[y_end] <= '9'))) : (y_end += 1) {}
            y = std.fmt.parseFloat(f64, frame.payload[y_val_start..y_end]) catch 0;
        }

        if (x == 0 and y == 0) {
            return AgentError.EvaluationFailed; // Element not found
        }

        // Step 2: Dispatch mouse events
        try self.dispatchMouseEvent("mousePressed", x, y);
        try self.dispatchMouseEvent("mouseReleased", x, y);
    }

    /// Dispatch mouse event at coordinates
    fn dispatchMouseEvent(self: *Self, event_type: []const u8, x: f64, y: f64) AgentError!void {
        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.dispatchMouseEvent\",\"params\":{{\"type\":\"{s}\",\"x\":{d},\"y\":{d},\"button\":\"left\",\"clickCount\":1}}}}", .{ self.message_id, event_type, x, y }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Type text into focused element
    pub fn typeText(self: *Self, text: []const u8) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // Escape text for JSON
        var escaped: [2048]u8 = undefined;
        var escaped_len: usize = 0;
        for (text) |c| {
            if (c == '"' or c == '\\') {
                escaped[escaped_len] = '\\';
                escaped_len += 1;
            }
            escaped[escaped_len] = c;
            escaped_len += 1;
        }

        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.insertText\",\"params\":{{\"text\":\"{s}\"}}}}", .{ self.message_id, escaped[0..escaped_len] }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Click element and type text (common pattern for form filling)
    pub fn clickAndType(self: *Self, selector: []const u8, text: []const u8) AgentError!void {
        try self.clickSelector(selector);
        std.time.sleep(100 * std.time.ns_per_ms); // Small delay for focus
        try self.typeText(text);
    }

    /// Press Enter key
    pub fn pressEnter(self: *Self) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;

        // Key down
        var cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.dispatchKeyEvent\",\"params\":{{\"type\":\"keyDown\",\"key\":\"Enter\",\"code\":\"Enter\",\"windowsVirtualKeyCode\":13}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;
        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;
        var frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);

        // Key up
        cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.dispatchKeyEvent\",\"params\":{{\"type\":\"keyUp\",\"key\":\"Enter\",\"code\":\"Enter\",\"windowsVirtualKeyCode\":13}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;
        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;
        frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Scroll page
    pub fn scroll(self: *Self, delta_y: i32) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"window.scrollBy(0, {d})\"}}}}", .{ self.message_id, delta_y }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Wait for element to appear on page
    pub fn waitForSelector(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!bool {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        const start_time = std.time.milliTimestamp();
        const timeout_end = start_time + @as(i64, timeout_ms);

        while (std.time.milliTimestamp() < timeout_end) {
            // Check if element exists
            var cmd_buf: [1024]u8 = undefined;

            // Escape selector
            var escaped: [256]u8 = undefined;
            var escaped_len: usize = 0;
            for (selector) |c| {
                if (c == '\'' or c == '\\') {
                    escaped[escaped_len] = '\\';
                    escaped_len += 1;
                }
                if (escaped_len < escaped.len) {
                    escaped[escaped_len] = c;
                    escaped_len += 1;
                }
            }

            const js = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.querySelector('{s}') !== null\"}}}}", .{ self.message_id, escaped[0..escaped_len] }) catch return AgentError.OutOfMemory;
            self.message_id += 1;

            self.ws.sendText(js) catch return AgentError.EvaluationFailed;

            const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
            defer self.allocator.free(frame.payload);

            // Check if result is true
            if (std.mem.indexOf(u8, frame.payload, "\"value\":true") != null) {
                return true; // Element found
            }

            // Wait 100ms before next check
            std.time.sleep(100 * std.time.ns_per_ms);
        }

        return false; // Timeout
    }

    /// Click element with wait
    pub fn clickSelectorWithWait(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!void {
        // Wait for element
        const found = try self.waitForSelector(selector, timeout_ms);
        if (!found) {
            return AgentError.EvaluationFailed; // Element not found
        }

        // Click
        try self.clickSelector(selector);
    }

    /// Get current URL
    pub fn getURL(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"window.location.href\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"")) |start| {
            const value_start = start + 9;
            if (std.mem.indexOf(u8, frame.payload[value_start..], "\"")) |end| {
                return self.allocator.dupe(u8, frame.payload[value_start .. value_start + end]) catch return AgentError.OutOfMemory;
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

test "RealAgent methods exist" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Verify methods exist (will fail with BrowserConnectionFailed since not connected)
    _ = agent.clickSelector("a") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.typeText("test") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.pressEnter() catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.scroll(100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.getURL() catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}
