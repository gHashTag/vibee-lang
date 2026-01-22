// VIBEE Anthropic Claude Client - Native Messages API
// Supports: Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku
// Different from OpenAI - uses Messages API format
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = @import("http_client.zig");

// Anthropic API endpoint
pub const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";

// Claude models
pub const CLAUDE_35_SONNET = "claude-3-5-sonnet-20241022";
pub const CLAUDE_3_OPUS = "claude-3-opus-20240229";
pub const CLAUDE_3_SONNET = "claude-3-sonnet-20240229";
pub const CLAUDE_3_HAIKU = "claude-3-haiku-20240307";

// Default model
pub const DEFAULT_MODEL = CLAUDE_35_SONNET;

pub const AnthropicError = error{
    ApiError,
    RateLimited,
    InvalidApiKey,
    NetworkError,
    ParseError,
    OutOfMemory,
    Overloaded,
};

pub const Message = struct {
    role: []const u8, // "user" or "assistant"
    content: []const u8,
};

pub const ChatResponse = struct {
    content: []const u8,
    stop_reason: []const u8,
    input_tokens: u32,
    output_tokens: u32,
    model: []const u8,
    latency_ns: i64,
    allocator: Allocator,

    pub fn deinit(self: *ChatResponse) void {
        self.allocator.free(self.content);
    }
};

pub const AnthropicClient = struct {
    allocator: Allocator,
    http_client: http.HttpClient,
    api_key: []const u8,
    model: []const u8,
    max_tokens: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .http_client = http.HttpClient.init(allocator),
            .api_key = api_key,
            .model = DEFAULT_MODEL,
            .max_tokens = 1024,
        };
    }

    /// Create client with specific model
    pub fn initWithModel(allocator: Allocator, api_key: []const u8, model: []const u8) Self {
        return Self{
            .allocator = allocator,
            .http_client = http.HttpClient.init(allocator),
            .api_key = api_key,
            .model = model,
            .max_tokens = 1024,
        };
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
    }

    /// Set model
    pub fn setModel(self: *Self, model: []const u8) void {
        self.model = model;
    }

    /// Set max tokens
    pub fn setMaxTokens(self: *Self, max_tokens: u32) void {
        self.max_tokens = max_tokens;
    }

    /// Simple chat with user message only
    pub fn chat(self: *Self, user_message: []const u8) AnthropicError!ChatResponse {
        return self.chatWithSystem(null, user_message);
    }

    /// Chat with optional system prompt (Anthropic-specific: system is separate field)
    pub fn chatWithSystem(self: *Self, system_prompt: ?[]const u8, user_message: []const u8) AnthropicError!ChatResponse {
        const start_time = std.time.nanoTimestamp();

        // Build request JSON (Anthropic Messages API format)
        const request_body = self.buildRequestJson(system_prompt, user_message) catch return AnthropicError.OutOfMemory;
        defer self.allocator.free(request_body);

        // Make HTTP request with Anthropic-specific headers
        var response = self.makeRequest(request_body) catch return AnthropicError.NetworkError;
        defer response.deinit();

        const end_time = std.time.nanoTimestamp();

        // Check status
        if (response.status == 401) return AnthropicError.InvalidApiKey;
        if (response.status == 429) return AnthropicError.RateLimited;
        if (response.status == 529) return AnthropicError.Overloaded;
        if (response.status != 200) return AnthropicError.ApiError;

        // Parse response
        return self.parseResponse(response.body, @intCast(end_time - start_time)) catch return AnthropicError.ParseError;
    }

    /// Build Anthropic Messages API request JSON
    fn buildRequestJson(self: *Self, system_prompt: ?[]const u8, user_message: []const u8) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        const writer = buffer.writer();

        // Start JSON object
        try writer.writeAll("{\"model\":\"");
        try writer.writeAll(self.model);
        try writer.writeAll("\",\"max_tokens\":");
        try writer.print("{d}", .{self.max_tokens});

        // System prompt (Anthropic-specific: separate field, not in messages)
        if (system_prompt) |sys| {
            try writer.writeAll(",\"system\":\"");
            try self.writeEscaped(writer, sys);
            try writer.writeAll("\"");
        }

        // Messages array
        try writer.writeAll(",\"messages\":[{\"role\":\"user\",\"content\":\"");
        try self.writeEscaped(writer, user_message);
        try writer.writeAll("\"}]}");

        return buffer.toOwnedSlice();
    }

    /// Make HTTP request with Anthropic headers
    fn makeRequest(self: *Self, body: []const u8) !http.HttpResponse {
        // Anthropic requires specific headers:
        // - x-api-key: API key
        // - anthropic-version: API version
        // - content-type: application/json

        var headers_buf: [512]u8 = undefined;
        const auth_header = std.fmt.bufPrint(&headers_buf, "{s}", .{self.api_key}) catch return error.OutOfMemory;

        // Use postJsonWithHeaders for Anthropic-specific headers
        return self.http_client.postJsonAnthropic(ANTHROPIC_URL, body, auth_header);
    }

    fn writeEscaped(self: *Self, writer: anytype, str: []const u8) !void {
        _ = self;
        for (str) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
    }

    fn parseResponse(self: *Self, body: []const u8, latency_ns: i64) !ChatResponse {
        // Anthropic response format:
        // {
        //   "content": [{"type": "text", "text": "..."}],
        //   "stop_reason": "end_turn",
        //   "usage": {"input_tokens": X, "output_tokens": Y}
        // }

        // Extract content text
        const content_start = std.mem.indexOf(u8, body, "\"text\":\"") orelse return AnthropicError.ParseError;
        const text_start = content_start + 8;
        var text_end = text_start;
        var escaped = false;
        while (text_end < body.len) : (text_end += 1) {
            if (escaped) {
                escaped = false;
                continue;
            }
            if (body[text_end] == '\\') {
                escaped = true;
                continue;
            }
            if (body[text_end] == '"') break;
        }

        const content = try self.allocator.dupe(u8, body[text_start..text_end]);

        // Extract stop_reason
        var stop_reason: []const u8 = "unknown";
        if (std.mem.indexOf(u8, body, "\"stop_reason\":\"")) |sr_start| {
            const sr_val_start = sr_start + 15;
            if (std.mem.indexOf(u8, body[sr_val_start..], "\"")) |sr_end| {
                stop_reason = body[sr_val_start .. sr_val_start + sr_end];
            }
        }

        // Extract usage
        var input_tokens: u32 = 0;
        var output_tokens: u32 = 0;

        if (std.mem.indexOf(u8, body, "\"input_tokens\":")) |it_start| {
            const it_val_start = it_start + 15;
            var it_end = it_val_start;
            while (it_end < body.len and body[it_end] >= '0' and body[it_end] <= '9') : (it_end += 1) {}
            if (it_end > it_val_start) {
                input_tokens = std.fmt.parseInt(u32, body[it_val_start..it_end], 10) catch 0;
            }
        }

        if (std.mem.indexOf(u8, body, "\"output_tokens\":")) |ot_start| {
            const ot_val_start = ot_start + 16;
            var ot_end = ot_val_start;
            while (ot_end < body.len and body[ot_end] >= '0' and body[ot_end] <= '9') : (ot_end += 1) {}
            if (ot_end > ot_val_start) {
                output_tokens = std.fmt.parseInt(u32, body[ot_val_start..ot_end], 10) catch 0;
            }
        }

        return ChatResponse{
            .content = content,
            .stop_reason = stop_reason,
            .input_tokens = input_tokens,
            .output_tokens = output_tokens,
            .model = self.model,
            .latency_ns = latency_ns,
            .allocator = self.allocator,
        };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "AnthropicClient initialization" {
    const allocator = std.testing.allocator;
    var client = AnthropicClient.init(allocator, "test-key");
    defer client.deinit();

    try std.testing.expectEqualStrings(DEFAULT_MODEL, client.model);
    try std.testing.expectEqual(@as(u32, 1024), client.max_tokens);
}

test "AnthropicClient with model" {
    const allocator = std.testing.allocator;
    var client = AnthropicClient.initWithModel(allocator, "test-key", CLAUDE_3_OPUS);
    defer client.deinit();

    try std.testing.expectEqualStrings(CLAUDE_3_OPUS, client.model);
}

test "setModel changes model" {
    const allocator = std.testing.allocator;
    var client = AnthropicClient.init(allocator, "test-key");
    defer client.deinit();

    client.setModel(CLAUDE_3_HAIKU);
    try std.testing.expectEqualStrings(CLAUDE_3_HAIKU, client.model);
}

test "setMaxTokens changes max_tokens" {
    const allocator = std.testing.allocator;
    var client = AnthropicClient.init(allocator, "test-key");
    defer client.deinit();

    client.setMaxTokens(4096);
    try std.testing.expectEqual(@as(u32, 4096), client.max_tokens);
}

test "build request JSON without system" {
    const allocator = std.testing.allocator;
    var client = AnthropicClient.init(allocator, "test-key");
    defer client.deinit();

    const json = try client.buildRequestJson(null, "Hello");
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"model\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"messages\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"content\":\"Hello\"") != null);
    // No system field
    try std.testing.expect(std.mem.indexOf(u8, json, "\"system\":") == null);
}

test "build request JSON with system" {
    const allocator = std.testing.allocator;
    var client = AnthropicClient.init(allocator, "test-key");
    defer client.deinit();

    const json = try client.buildRequestJson("You are helpful", "Hello");
    defer allocator.free(json);

    // System field present (Anthropic-specific)
    try std.testing.expect(std.mem.indexOf(u8, json, "\"system\":\"You are helpful\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"role\":\"user\"") != null);
}

test "model constants" {
    try std.testing.expectEqualStrings("claude-3-5-sonnet-20241022", CLAUDE_35_SONNET);
    try std.testing.expectEqualStrings("claude-3-opus-20240229", CLAUDE_3_OPUS);
    try std.testing.expectEqualStrings("claude-3-sonnet-20240229", CLAUDE_3_SONNET);
    try std.testing.expectEqualStrings("claude-3-haiku-20240307", CLAUDE_3_HAIKU);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
