// VIBEE OpenAI Client - Pure Zig Implementation
// Supports: OpenAI, Groq (FREE), Together AI, Ollama
// Uses http_client.zig and json_parser.zig
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = @import("http_client.zig");
const json = @import("json_parser.zig");

// Provider URLs (all OpenAI-compatible)
pub const OPENAI_URL = "https://api.openai.com/v1/chat/completions";
pub const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
pub const TOGETHER_URL = "https://api.together.xyz/v1/chat/completions";
pub const OLLAMA_URL = "http://localhost:11434/v1/chat/completions";
pub const HUGGINGFACE_URL = "https://router.huggingface.co/v1/chat/completions";

// Default models per provider
pub const OPENAI_MODEL = "gpt-4o-mini";
pub const GROQ_MODEL = "llama-3.3-70b-versatile"; // FREE!
pub const GROQ_FAST_MODEL = "llama-3.1-8b-instant"; // VERY FAST!
pub const TOGETHER_MODEL = "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo";
pub const OLLAMA_MODEL = "llama3.2:3b";
// HuggingFace models (FREE with API key!)
pub const HF_GPT_OSS = "openai/gpt-oss-120b";
pub const HF_DEEPSEEK_R1 = "deepseek-ai/DeepSeek-R1";
pub const HF_LLAMA_33 = "meta-llama/Llama-3.3-70B-Instruct";
pub const HF_QWEN_25 = "Qwen/Qwen2.5-72B-Instruct";
pub const HUGGINGFACE_MODEL = "Qwen/Qwen2.5-72B-Instruct"; // Default HF model

pub const Provider = enum {
    openai,
    groq,
    together,
    ollama,
    huggingface,
};

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
            .model = OPENAI_MODEL,
            .base_url = OPENAI_URL,
        };
    }

    /// Create client for Groq (FREE, FAST!)
    pub fn initGroq(allocator: Allocator, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .http_client = http.HttpClient.init(allocator),
            .api_key = api_key,
            .model = GROQ_MODEL,
            .base_url = GROQ_URL,
        };
    }

    /// Create client for Together AI
    pub fn initTogether(allocator: Allocator, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .http_client = http.HttpClient.init(allocator),
            .api_key = api_key,
            .model = TOGETHER_MODEL,
            .base_url = TOGETHER_URL,
        };
    }

    /// Create client for Ollama (local, no API key needed)
    pub fn initOllama(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .http_client = http.HttpClient.init(allocator),
            .api_key = "ollama", // not used
            .model = OLLAMA_MODEL,
            .base_url = OLLAMA_URL,
        };
    }

    /// Create client for HuggingFace (FREE with API key!)
    pub fn initHuggingFace(allocator: Allocator, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .http_client = http.HttpClient.init(allocator),
            .api_key = api_key,
            .model = HUGGINGFACE_MODEL,
            .base_url = HUGGINGFACE_URL,
        };
    }

    /// Switch to a different provider
    pub fn setProvider(self: *Self, provider: Provider) void {
        switch (provider) {
            .openai => {
                self.base_url = OPENAI_URL;
                self.model = OPENAI_MODEL;
            },
            .groq => {
                self.base_url = GROQ_URL;
                self.model = GROQ_MODEL;
            },
            .together => {
                self.base_url = TOGETHER_URL;
                self.model = TOGETHER_MODEL;
            },
            .ollama => {
                self.base_url = OLLAMA_URL;
                self.model = OLLAMA_MODEL;
            },
            .huggingface => {
                self.base_url = HUGGINGFACE_URL;
                self.model = HUGGINGFACE_MODEL;
            },
        }
    }

    /// Set custom model
    pub fn setModel(self: *Self, model: []const u8) void {
        self.model = model;
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
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

    /// Chat with vision (image analysis)
    pub fn chatWithVision(self: *Self, prompt: []const u8, image_base64: []const u8) OpenAIError!ChatResponse {
        const start_time = std.time.nanoTimestamp();

        // Build vision request
        const request_body = buildVisionRequest(self.allocator, GPT4V_MODEL, prompt, image_base64) catch return OpenAIError.OutOfMemory;
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

        // Parse response (same format as chat)
        return self.parseResponse(response.body, @intCast(end_time - start_time)) catch return OpenAIError.ParseError;
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

// ============================================================================
// VISION SUPPORT (GPT-4V)
// ============================================================================

pub const GPT4V_MODEL = "gpt-4o"; // Vision-capable model

/// Build vision request with image
pub fn buildVisionRequest(allocator: Allocator, model: []const u8, prompt: []const u8, image_base64: []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    const writer = buffer.writer();

    try writer.writeAll("{\"model\":\"");
    try writer.writeAll(model);
    try writer.writeAll("\",\"messages\":[{\"role\":\"user\",\"content\":[");

    // Text content
    try writer.writeAll("{\"type\":\"text\",\"text\":\"");
    for (prompt) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
    try writer.writeAll("\"},");

    // Image content
    try writer.writeAll("{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64,");
    try writer.writeAll(image_base64);
    try writer.writeAll("\"}}");

    try writer.writeAll("]}],\"max_tokens\":1024}");

    return buffer.toOwnedSlice();
}

test "buildVisionRequest" {
    const allocator = std.testing.allocator;
    const vision_json = try buildVisionRequest(allocator, GPT4V_MODEL, "What do you see?", "iVBORw0KGgo=");
    defer allocator.free(vision_json);

    try std.testing.expect(std.mem.indexOf(u8, vision_json, "\"type\":\"text\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, vision_json, "\"type\":\"image_url\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, vision_json, "data:image/png;base64,") != null);
}

// ============================================================================
// STREAMING SUPPORT
// ============================================================================

/// Build streaming request (adds "stream": true)
pub fn buildStreamingRequest(allocator: Allocator, model: []const u8, prompt: []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    const writer = buffer.writer();

    try writer.writeAll("{\"model\":\"");
    try writer.writeAll(model);
    try writer.writeAll("\",\"messages\":[{\"role\":\"user\",\"content\":\"");

    // Escape prompt
    for (prompt) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }

    try writer.writeAll("\"}],\"stream\":true,\"max_tokens\":1024}");

    return buffer.toOwnedSlice();
}

/// Parse SSE chunk from streaming response
/// Format: data: {"choices":[{"delta":{"content":"token"}}]}
pub fn parseStreamChunk(chunk: []const u8) ?[]const u8 {
    // Skip "data: " prefix
    const data_prefix = "data: ";
    if (!std.mem.startsWith(u8, chunk, data_prefix)) return null;

    const json_part = chunk[data_prefix.len..];

    // Check for [DONE]
    if (std.mem.eql(u8, std.mem.trim(u8, json_part, " \n\r"), "[DONE]")) return null;

    // Extract content from delta
    if (std.mem.indexOf(u8, json_part, "\"content\":\"")) |start| {
        const content_start = start + 11;
        var content_end = content_start;
        var escaped = false;
        while (content_end < json_part.len) : (content_end += 1) {
            if (escaped) {
                escaped = false;
                continue;
            }
            if (json_part[content_end] == '\\') {
                escaped = true;
                continue;
            }
            if (json_part[content_end] == '"') break;
        }
        return json_part[content_start..content_end];
    }

    return null;
}

test "buildStreamingRequest" {
    const allocator = std.testing.allocator;
    const stream_json = try buildStreamingRequest(allocator, OPENAI_MODEL, "Hello");
    defer allocator.free(stream_json);

    try std.testing.expect(std.mem.indexOf(u8, stream_json, "\"stream\":true") != null);
}

test "parseStreamChunk" {
    const chunk1 = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}";
    const result1 = parseStreamChunk(chunk1);
    try std.testing.expect(result1 != null);
    try std.testing.expectEqualStrings("Hello", result1.?);

    const chunk2 = "data: [DONE]";
    const result2 = parseStreamChunk(chunk2);
    try std.testing.expect(result2 == null);

    const chunk3 = "invalid";
    const result3 = parseStreamChunk(chunk3);
    try std.testing.expect(result3 == null);
}

test "Groq client initialization" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.initGroq(allocator, "test-groq-key");
    defer client.deinit();

    try std.testing.expectEqualStrings(GROQ_MODEL, client.model);
    try std.testing.expectEqualStrings(GROQ_URL, client.base_url);
}

test "Together client initialization" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.initTogether(allocator, "test-together-key");
    defer client.deinit();

    try std.testing.expectEqualStrings(TOGETHER_MODEL, client.model);
    try std.testing.expectEqualStrings(TOGETHER_URL, client.base_url);
}

test "Ollama client initialization" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.initOllama(allocator);
    defer client.deinit();

    try std.testing.expectEqualStrings(OLLAMA_MODEL, client.model);
    try std.testing.expectEqualStrings(OLLAMA_URL, client.base_url);
}

test "setProvider switches correctly" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.init(allocator, "test-key");
    defer client.deinit();

    // Start with OpenAI
    try std.testing.expectEqualStrings(OPENAI_URL, client.base_url);

    // Switch to Groq
    client.setProvider(.groq);
    try std.testing.expectEqualStrings(GROQ_URL, client.base_url);
    try std.testing.expectEqualStrings(GROQ_MODEL, client.model);

    // Switch to Together
    client.setProvider(.together);
    try std.testing.expectEqualStrings(TOGETHER_URL, client.base_url);

    // Switch to Ollama
    client.setProvider(.ollama);
    try std.testing.expectEqualStrings(OLLAMA_URL, client.base_url);
}

test "setModel changes model" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.initGroq(allocator, "test-key");
    defer client.deinit();

    client.setModel(GROQ_FAST_MODEL);
    try std.testing.expectEqualStrings(GROQ_FAST_MODEL, client.model);
}

test "HuggingFace client initialization" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.initHuggingFace(allocator, "hf_test_key");
    defer client.deinit();

    try std.testing.expectEqualStrings(HUGGINGFACE_MODEL, client.model);
    try std.testing.expectEqualStrings(HUGGINGFACE_URL, client.base_url);
}

test "setProvider to HuggingFace" {
    const allocator = std.testing.allocator;
    var client = OpenAIClient.init(allocator, "test-key");
    defer client.deinit();

    client.setProvider(.huggingface);
    try std.testing.expectEqualStrings(HUGGINGFACE_URL, client.base_url);
    try std.testing.expectEqualStrings(HUGGINGFACE_MODEL, client.model);
}

test "HuggingFace models constants" {
    try std.testing.expectEqualStrings("openai/gpt-oss-120b", HF_GPT_OSS);
    try std.testing.expectEqualStrings("deepseek-ai/DeepSeek-R1", HF_DEEPSEEK_R1);
    try std.testing.expectEqualStrings("meta-llama/Llama-3.3-70B-Instruct", HF_LLAMA_33);
    try std.testing.expectEqualStrings("Qwen/Qwen2.5-72B-Instruct", HF_QWEN_25);
}
