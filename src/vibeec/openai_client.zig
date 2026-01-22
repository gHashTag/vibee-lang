// VIBEE OpenAI Client - Pure Zig Implementation
// GPT-4, GPT-4o API calls
// Uses http_client.zig and json_parser.zig
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = @import("http_client.zig");
const json = @import("json_parser.zig");

pub const OpenAIError = error{
    ApiError,
    RateLimited,
    InvalidApiKey,
    NetworkError,
    ParseError,
    OutOfMemory,
};

pub const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatResponse = struct {
    content: []const u8,
    finish_reason: []const u8,
    prompt_tokens: u32,
    completion_tokens: u32,
    total_tokens: u32,
    latency_ns: i64,
    model: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *ChatResponse) void {
        self.allocator.free(self.content);
    }
};

pub const OpenAIClient = struct {
    allocator: Allocator,
    http_client: http.HttpClient,
    api_key: []const u8,
    model: []const u8,
    base_url: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .http_client = http.HttpClient.init(allocator),
            .api_key = api_key,
            .model = "gpt-4o-mini",
            .base_url = "https://api.openai.com/v1/chat/completions",
        };
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
    }

    pub fn setModel(self: *Self, model: []const u8) void {
        self.model = model;
    }

    /// Simple chat completion with single user message
    pub fn chat(self: *Self, user_message: []const u8) OpenAIError!ChatResponse {
        return self.chatWithSystem(null, user_message);
    }

    /// Chat completion with system prompt
    pub fn chatWithSystem(self: *Self, system_prompt: ?[]const u8, user_message: []const u8) OpenAIError!ChatResponse {
        const start_time = std.time.nanoTimestamp();

        // Build request JSON
        const request_body = self.buildRequestJson(system_prompt, user_message) catch return OpenAIError.OutOfMemory;
        defer self.allocator.free(request_body);

        // Build auth header
        var auth_buf: [256]u8 = undefined;
        const auth_header = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{self.api_key}) catch return OpenAIError.OutOfMemory;

        // Make HTTP request
        var response = self.http_client.postJson(self.base_url, request_body, auth_header) catch return OpenAIError.NetworkError;
        defer response.deinit();

        const end_time = std.time.nanoTimestamp();

        // Check status
        if (response.status == 401) return OpenAIError.InvalidApiKey;
        if (response.status == 429) return OpenAIError.RateLimited;
        if (response.status != 200) return OpenAIError.ApiError;

        // Parse response
        return self.parseResponse(response.body, @intCast(end_time - start_time)) catch return OpenAIError.ParseError;
    }

    fn buildRequestJson(self: *Self, system_prompt: ?[]const u8, user_message: []const u8) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        const writer = buffer.writer();

        try writer.writeAll("{\"model\":\"");
        try writer.writeAll(self.model);
        try writer.writeAll("\",\"messages\":[");

        if (system_prompt) |sys| {
            try writer.writeAll("{\"role\":\"system\",\"content\":\"");
            try self.writeEscaped(writer, sys);
            try writer.writeAll("\"},");
        }

        try writer.writeAll("{\"role\":\"user\",\"content\":\"");
        try self.writeEscaped(writer, user_message);
        try writer.writeAll("\"}");

        try writer.writeAll("],\"max_tokens\":1024}");

        return buffer.toOwnedSlice();
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
        var parser = json.JsonParser.init(self.allocator);
        var result = try parser.parse(body);
        defer result.deinit(self.allocator);

        // Extract content: $.choices[0].message.content
        const content_val = json.queryPath(result.value, "$.choices[0].message.content") orelse return OpenAIError.ParseError;
        const content_str = content_val.getString() orelse return OpenAIError.ParseError;

        // Copy content to owned memory
        const content = try self.allocator.dupe(u8, content_str);

        // Extract finish_reason
        const finish_val = json.queryPath(result.value, "$.choices[0].finish_reason");
        const finish_reason = if (finish_val) |v| v.getString() orelse "unknown" else "unknown";

        // Extract usage
        const prompt_val = json.queryPath(result.value, "$.usage.prompt_tokens");
        const completion_val = json.queryPath(result.value, "$.usage.completion_tokens");
        const total_val = json.queryPath(result.value, "$.usage.total_tokens");

        return ChatResponse{
            .content = content,
            .finish_reason = finish_reason,
            .prompt_tokens = if (prompt_val) |v| @intFromFloat(v.getNumber() orelse 0) else 0,
            .completion_tokens = if (completion_val) |v| @intFromFloat(v.getNumber() orelse 0) else 0,
            .total_tokens = if (total_val) |v| @intFromFloat(v.getNumber() orelse 0) else 0,
            .latency_ns = latency_ns,
            .model = self.model,
            .allocator = self.allocator,
        };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "OpenAI client initialization" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.init(allocator, "test-key");
    defer client.deinit();

    try std.testing.expectEqualStrings("gpt-4o-mini", client.model);
}

test "build request JSON" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.init(allocator, "test-key");
    defer client.deinit();

    const json_body = try client.buildRequestJson(null, "Hello");
    defer allocator.free(json_body);

    try std.testing.expect(std.mem.indexOf(u8, json_body, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_body, "\"content\":\"Hello\"") != null);
}

test "build request JSON with system" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.init(allocator, "test-key");
    defer client.deinit();

    const json_body = try client.buildRequestJson("You are helpful", "Hello");
    defer allocator.free(json_body);

    try std.testing.expect(std.mem.indexOf(u8, json_body, "\"role\":\"system\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_body, "\"role\":\"user\"") != null);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
