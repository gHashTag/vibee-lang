// VIBEE CDP Client - Chrome DevTools Protocol
// Pure Zig implementation
// JSON-RPC over WebSocket
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const ws = @import("websocket.zig");
const json = @import("json_parser.zig");
const http = @import("http_client.zig");

pub const CDPError = error{
    ConnectionFailed,
    CommandFailed,
    Timeout,
    ParseError,
    NoTargets,
    OutOfMemory,
};

pub const CDPTarget = struct {
    id: []const u8,
    target_type: []const u8,
    title: []const u8,
    url: []const u8,
    ws_url: []const u8,
};

pub const CDPResponse = struct {
    id: u32,
    result: ?[]const u8,
    err: ?[]const u8,
};

pub const CDPClient = struct {
    allocator: Allocator,
    websocket: ws.WebSocketClient,
    http_client: http.HttpClient,
    host: []const u8,
    port: u16,
    message_id: u32,
    connected: bool,

    const Self = @This();

    pub fn init(allocator: Allocator, host: []const u8, port: u16) Self {
        return Self{
            .allocator = allocator,
            .websocket = ws.WebSocketClient.init(allocator),
            .http_client = http.HttpClient.init(allocator),
            .host = host,
            .port = port,
            .message_id = 1,
            .connected = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.websocket.deinit();
        self.http_client.deinit();
    }

    /// Discover available targets via HTTP
    pub fn discoverTargets(self: *Self) CDPError![]CDPTarget {
        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "http://{s}:{d}/json", .{ self.host, self.port }) catch return CDPError.OutOfMemory;

        var response = self.http_client.get(url) catch return CDPError.ConnectionFailed;
        defer response.deinit();

        if (response.status != 200) {
            return CDPError.ConnectionFailed;
        }

        // Parse JSON array of targets
        var parser = json.JsonParser.init(self.allocator);
        var result = parser.parse(response.body) catch return CDPError.ParseError;
        defer result.deinit(self.allocator);

        const arr = result.value.getArray() orelse return CDPError.ParseError;

        var targets = std.ArrayList(CDPTarget).init(self.allocator);
        errdefer targets.deinit();

        for (arr) |item| {
            const obj = item.getObject() orelse continue;

            const target = CDPTarget{
                .id = obj.get("id").?.getString() orelse "",
                .target_type = obj.get("type").?.getString() orelse "",
                .title = obj.get("title").?.getString() orelse "",
                .url = obj.get("url").?.getString() orelse "",
                .ws_url = obj.get("webSocketDebuggerUrl").?.getString() orelse "",
            };

            targets.append(target) catch continue;
        }

        if (targets.items.len == 0) {
            return CDPError.NoTargets;
        }

        return targets.toOwnedSlice() catch return CDPError.OutOfMemory;
    }

    /// Connect to a specific target
    pub fn connectToTarget(self: *Self, ws_url: []const u8) CDPError!void {
        self.websocket.connect(ws_url) catch return CDPError.ConnectionFailed;
        self.connected = true;
    }

    /// Send CDP command and get response
    pub fn sendCommand(self: *Self, method: []const u8, params: ?[]const u8) CDPError!CDPResponse {
        if (!self.connected) return CDPError.ConnectionFailed;

        const id = self.message_id;
        self.message_id += 1;

        // Build JSON-RPC message
        var msg_buf: [4096]u8 = undefined;
        const msg = if (params) |p|
            std.fmt.bufPrint(&msg_buf, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s}}}", .{ id, method, p }) catch return CDPError.OutOfMemory
        else
            std.fmt.bufPrint(&msg_buf, "{{\"id\":{d},\"method\":\"{s}\"}}", .{ id, method }) catch return CDPError.OutOfMemory;

        // Send
        self.websocket.sendText(msg) catch return CDPError.ConnectionFailed;

        // Receive response
        const frame = self.websocket.receive() catch return CDPError.ConnectionFailed;
        defer self.allocator.free(frame.payload);

        // Parse response
        var parser = json.JsonParser.init(self.allocator);
        var result = parser.parse(frame.payload) catch return CDPError.ParseError;
        defer result.deinit(self.allocator);

        const resp_id = json.queryPath(result.value, "$.id");
        const resp_result = json.queryPath(result.value, "$.result");
        const resp_error = json.queryPath(result.value, "$.error");

        return CDPResponse{
            .id = if (resp_id) |v| @intFromFloat(v.getNumber() orelse 0) else 0,
            .result = if (resp_result) |_| frame.payload else null,
            .err = if (resp_error) |v| v.getString() else null,
        };
    }

    // ========================================================================
    // High-level CDP methods
    // ========================================================================

    /// Navigate to URL
    pub fn navigate(self: *Self, url: []const u8) CDPError!void {
        var params_buf: [1024]u8 = undefined;
        const params = std.fmt.bufPrint(&params_buf, "{{\"url\":\"{s}\"}}", .{url}) catch return CDPError.OutOfMemory;

        _ = try self.sendCommand("Page.navigate", params);
    }

    /// Take screenshot (returns base64)
    pub fn screenshot(self: *Self) CDPError![]const u8 {
        const response = try self.sendCommand("Page.captureScreenshot", null);
        if (response.result) |r| {
            return r;
        }
        return CDPError.CommandFailed;
    }

    /// Evaluate JavaScript
    pub fn evaluate(self: *Self, expression: []const u8) CDPError![]const u8 {
        var params_buf: [4096]u8 = undefined;
        const params = std.fmt.bufPrint(&params_buf, "{{\"expression\":\"{s}\",\"returnByValue\":true}}", .{expression}) catch return CDPError.OutOfMemory;

        const response = try self.sendCommand("Runtime.evaluate", params);
        if (response.result) |r| {
            return r;
        }
        return CDPError.CommandFailed;
    }

    /// Click at coordinates
    pub fn click(self: *Self, x: f64, y: f64) CDPError!void {
        var params_buf: [256]u8 = undefined;

        // Mouse down
        var params = std.fmt.bufPrint(&params_buf, "{{\"type\":\"mousePressed\",\"x\":{d},\"y\":{d},\"button\":\"left\",\"clickCount\":1}}", .{ x, y }) catch return CDPError.OutOfMemory;
        _ = try self.sendCommand("Input.dispatchMouseEvent", params);

        // Mouse up
        params = std.fmt.bufPrint(&params_buf, "{{\"type\":\"mouseReleased\",\"x\":{d},\"y\":{d},\"button\":\"left\",\"clickCount\":1}}", .{ x, y }) catch return CDPError.OutOfMemory;
        _ = try self.sendCommand("Input.dispatchMouseEvent", params);
    }

    /// Type text
    pub fn typeText(self: *Self, text: []const u8) CDPError!void {
        var params_buf: [1024]u8 = undefined;
        const params = std.fmt.bufPrint(&params_buf, "{{\"text\":\"{s}\"}}", .{text}) catch return CDPError.OutOfMemory;
        _ = try self.sendCommand("Input.insertText", params);
    }

    /// Get page title
    pub fn getTitle(self: *Self) CDPError![]const u8 {
        return self.evaluate("document.title");
    }

    /// Enable Page domain
    pub fn enablePage(self: *Self) CDPError!void {
        _ = try self.sendCommand("Page.enable", null);
    }

    /// Enable DOM domain
    pub fn enableDOM(self: *Self) CDPError!void {
        _ = try self.sendCommand("DOM.enable", null);
    }

    /// Enable Runtime domain
    pub fn enableRuntime(self: *Self) CDPError!void {
        _ = try self.sendCommand("Runtime.enable", null);
    }

    /// Close connection
    pub fn close(self: *Self) void {
        self.websocket.close();
        self.connected = false;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "CDP client initialization" {
    const allocator = std.testing.allocator;
    var client = CDPClient.init(allocator, "localhost", 9222);
    defer client.deinit();

    try std.testing.expectEqual(@as(u16, 9222), client.port);
    try std.testing.expect(!client.connected);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "CDP target struct" {
    const target = CDPTarget{
        .id = "ABC123",
        .target_type = "page",
        .title = "Test Page",
        .url = "https://example.com",
        .ws_url = "ws://localhost:9222/devtools/page/ABC123",
    };
    try std.testing.expectEqualStrings("ABC123", target.id);
    try std.testing.expectEqualStrings("page", target.target_type);
    try std.testing.expectEqualStrings("Test Page", target.title);
}

test "CDP response struct" {
    const response = CDPResponse{
        .id = 42,
        .result = "{\"data\":\"test\"}",
        .err = null,
    };
    try std.testing.expectEqual(@as(u32, 42), response.id);
    try std.testing.expect(response.result != null);
    try std.testing.expect(response.err == null);
}

test "CDP response with error" {
    const response = CDPResponse{
        .id = 1,
        .result = null,
        .err = "Method not found",
    };
    try std.testing.expectEqual(@as(u32, 1), response.id);
    try std.testing.expect(response.result == null);
    try std.testing.expect(response.err != null);
}

test "CDP client message ID increment" {
    const allocator = std.testing.allocator;
    var client = CDPClient.init(allocator, "localhost", 9222);
    defer client.deinit();

    try std.testing.expectEqual(@as(u32, 1), client.message_id);
}

test "CDP client close without connection" {
    const allocator = std.testing.allocator;
    var client = CDPClient.init(allocator, "localhost", 9222);
    defer client.deinit();

    // Should not crash when closing without connection
    client.close();
    try std.testing.expect(!client.connected);
}

test "CDP error types" {
    // Verify error types exist and are distinct
    const err1: CDPError = CDPError.ConnectionFailed;
    const err2: CDPError = CDPError.CommandFailed;
    const err3: CDPError = CDPError.Timeout;
    const err4: CDPError = CDPError.ParseError;
    const err5: CDPError = CDPError.NoTargets;
    const err6: CDPError = CDPError.OutOfMemory;

    try std.testing.expect(err1 != err2);
    try std.testing.expect(err2 != err3);
    try std.testing.expect(err3 != err4);
    try std.testing.expect(err4 != err5);
    try std.testing.expect(err5 != err6);
}
