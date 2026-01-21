// ═══════════════════════════════════════════════════════════════
// v6712: CHAT INTERFACE - CLI Dialog with QuantumMiniLM
// Generated from specs/tri/v6712_chat_interface.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════
// TERNARY VALUE
// ═══════════════════════════════════════════════════════════════

pub const TernaryValue = enum {
    True, // △
    False, // ▽
    Unknown, // ○

    pub fn symbol(self: TernaryValue) []const u8 {
        return switch (self) {
            .True => "△",
            .False => "▽",
            .Unknown => "○",
        };
    }

    pub fn color(self: TernaryValue) []const u8 {
        return switch (self) {
            .True => "\x1b[32m", // Green
            .False => "\x1b[31m", // Red
            .Unknown => "\x1b[33m", // Yellow
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// MESSAGE ROLE
// ═══════════════════════════════════════════════════════════════

pub const MessageRole = enum {
    System,
    User,
    Assistant,

    pub fn prefix(self: MessageRole) []const u8 {
        return switch (self) {
            .System => "[SYSTEM]",
            .User => "[USER]",
            .Assistant => "[QUANTUM]",
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// CHAT MESSAGE
// ═══════════════════════════════════════════════════════════════

pub const ChatMessage = struct {
    role: MessageRole,
    content: []const u8,
    ternary_status: TernaryValue,
    confidence: f64,
    timestamp: i64,

    pub fn init(role: MessageRole, content: []const u8) ChatMessage {
        return .{
            .role = role,
            .content = content,
            .ternary_status = .Unknown,
            .confidence = 0.5,
            .timestamp = std.time.milliTimestamp(),
        };
    }

    pub fn withTernary(role: MessageRole, content: []const u8, status: TernaryValue, confidence: f64) ChatMessage {
        return .{
            .role = role,
            .content = content,
            .ternary_status = status,
            .confidence = confidence,
            .timestamp = std.time.milliTimestamp(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// CHAT HISTORY
// ═══════════════════════════════════════════════════════════════

pub const ChatHistory = struct {
    allocator: Allocator,
    messages: std.ArrayList(ChatMessage),
    max_messages: usize,

    pub fn init(allocator: Allocator, max_messages: usize) ChatHistory {
        return .{
            .allocator = allocator,
            .messages = std.ArrayList(ChatMessage).init(allocator),
            .max_messages = max_messages,
        };
    }

    pub fn deinit(self: *ChatHistory) void {
        self.messages.deinit();
    }

    pub fn addMessage(self: *ChatHistory, message: ChatMessage) !void {
        // Trim old messages if needed
        while (self.messages.items.len >= self.max_messages) {
            _ = self.messages.orderedRemove(0);
        }
        try self.messages.append(message);
    }

    pub fn getLastN(self: *ChatHistory, n: usize) []const ChatMessage {
        const start = if (self.messages.items.len > n) self.messages.items.len - n else 0;
        return self.messages.items[start..];
    }

    pub fn clear(self: *ChatHistory) void {
        self.messages.clearRetainingCapacity();
    }

    pub fn length(self: ChatHistory) usize {
        return self.messages.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════
// CHAT CONFIG
// ═══════════════════════════════════════════════════════════════

pub const ChatConfig = struct {
    model_name: []const u8 = "QuantumMiniLM",
    max_history: usize = 100,
    show_confidence: bool = true,
    show_ternary: bool = true,
    show_reasoning: bool = false,
    colored_output: bool = true,
    system_prompt: []const u8 = "You are QuantumMiniLM, an intelligent assistant using ternary logic (True/False/Unknown).",
};

// ═══════════════════════════════════════════════════════════════
// RESPONSE
// ═══════════════════════════════════════════════════════════════

pub const Response = struct {
    text: []const u8,
    ternary_status: TernaryValue,
    confidence: f64,
    reasoning_chain: []const []const u8,
    tokens_generated: usize,
    generation_time_ms: i64,

    pub fn init() Response {
        return .{
            .text = "",
            .ternary_status = .Unknown,
            .confidence = 0,
            .reasoning_chain = &[_][]const u8{},
            .tokens_generated = 0,
            .generation_time_ms = 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// CHAT INTERFACE
// ═══════════════════════════════════════════════════════════════

pub const ChatInterface = struct {
    allocator: Allocator,
    config: ChatConfig,
    history: ChatHistory,
    is_running: bool,

    pub fn init(allocator: Allocator, config: ChatConfig) ChatInterface {
        var chat = ChatInterface{
            .allocator = allocator,
            .config = config,
            .history = ChatHistory.init(allocator, config.max_history),
            .is_running = false,
        };

        // Add system message
        chat.history.addMessage(ChatMessage.init(.System, config.system_prompt)) catch {};

        return chat;
    }

    pub fn deinit(self: *ChatInterface) void {
        self.history.deinit();
    }

    /// Process user input and generate response
    pub fn processInput(self: *ChatInterface, input: []const u8) !Response {
        // Add user message
        try self.history.addMessage(ChatMessage.init(.User, input));

        // Generate response (mock implementation)
        const response = try self.generateResponse(input);

        // Add assistant message
        try self.history.addMessage(ChatMessage.withTernary(
            .Assistant,
            response.text,
            response.ternary_status,
            response.confidence,
        ));

        return response;
    }

    /// Generate response (mock - would call actual model)
    fn generateResponse(self: *ChatInterface, input: []const u8) !Response {
        _ = self;
        const start_time = std.time.milliTimestamp();

        // Mock response generation based on input
        var response = Response.init();

        // Simple pattern matching for demo
        if (std.mem.indexOf(u8, input, "2+2") != null or std.mem.indexOf(u8, input, "2 + 2") != null) {
            response.text = "4";
            response.ternary_status = .True;
            response.confidence = 0.99;
        } else if (std.mem.indexOf(u8, input, "hello") != null or std.mem.indexOf(u8, input, "hi") != null) {
            response.text = "Hello! I am QuantumMiniLM. How can I help you?";
            response.ternary_status = .True;
            response.confidence = 0.95;
        } else if (std.mem.indexOf(u8, input, "meaning of life") != null) {
            response.text = "The meaning of life is a philosophical question that remains open to interpretation.";
            response.ternary_status = .Unknown;
            response.confidence = 0.6;
        } else if (std.mem.indexOf(u8, input, "earth flat") != null) {
            response.text = "No, the Earth is not flat. It is an oblate spheroid.";
            response.ternary_status = .False;
            response.confidence = 0.99;
        } else if (std.mem.indexOf(u8, input, "phi") != null or std.mem.indexOf(u8, input, "golden") != null) {
            response.text = "φ (phi) = 1.618... is the golden ratio. φ² + 1/φ² = 3 exactly!";
            response.ternary_status = .True;
            response.confidence = 0.99;
        } else {
            response.text = "I understand your question. Let me think about it...";
            response.ternary_status = .Unknown;
            response.confidence = 0.5;
        }

        response.generation_time_ms = std.time.milliTimestamp() - start_time;
        response.tokens_generated = response.text.len / 4; // Rough estimate

        return response;
    }

    /// Format response for display
    pub fn formatResponse(self: *ChatInterface, response: Response) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        const writer = buffer.writer();

        // Model name
        try writer.print("\n{s}: ", .{self.config.model_name});

        // Response text
        try writer.print("{s}", .{response.text});

        // Ternary status
        if (self.config.show_ternary) {
            if (self.config.colored_output) {
                try writer.print("\n  {s}[{s}]\x1b[0m", .{ response.ternary_status.color(), response.ternary_status.symbol() });
            } else {
                try writer.print("\n  [{s}]", .{response.ternary_status.symbol()});
            }
        }

        // Confidence
        if (self.config.show_confidence) {
            try writer.print(" (confidence: {d:.1}%)", .{response.confidence * 100});
        }

        try writer.print("\n", .{});

        return buffer.toOwnedSlice();
    }

    /// Check if input is a command
    pub fn isCommand(input: []const u8) bool {
        return input.len > 0 and input[0] == '/';
    }

    /// Process command
    pub fn processCommand(self: *ChatInterface, command: []const u8) ![]const u8 {
        if (std.mem.eql(u8, command, "/help")) {
            return 
                \\Commands:
                \\  /help     - Show this help
                \\  /clear    - Clear chat history
                \\  /history  - Show chat history
                \\  /config   - Show configuration
                \\  /phi      - Show sacred constants
                \\  /quit     - Exit chat
            ;
        } else if (std.mem.eql(u8, command, "/clear")) {
            self.history.clear();
            return "Chat history cleared.";
        } else if (std.mem.eql(u8, command, "/phi")) {
            return 
                \\Sacred Constants:
                \\  φ = 1.618033988749895
                \\  φ² + 1/φ² = 3 (Golden Identity)
                \\  PHOENIX = 999 = 37 × 27
            ;
        } else if (std.mem.eql(u8, command, "/quit") or std.mem.eql(u8, command, "/exit")) {
            self.is_running = false;
            return "Goodbye!";
        } else {
            return "Unknown command. Type /help for available commands.";
        }
    }

    /// Print welcome message
    pub fn printWelcome(self: *ChatInterface) void {
        _ = self;
        const welcome =
            \\
            \\╔═══════════════════════════════════════════════════════════════╗
            \\║           QUANTUM MINILM - Intelligent Chat Interface         ║
            \\║                    φ² + 1/φ² = 3 | PHOENIX = 999              ║
            \\╠═══════════════════════════════════════════════════════════════╣
            \\║  Ternary Logic: △ True | ▽ False | ○ Unknown                  ║
            \\║  Type /help for commands, /quit to exit                       ║
            \\╚═══════════════════════════════════════════════════════════════╝
            \\
        ;
        std.debug.print("{s}", .{welcome});
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "chat message init" {
    const msg = ChatMessage.init(.User, "Hello");
    try testing.expect(msg.role == .User);
    try testing.expect(std.mem.eql(u8, msg.content, "Hello"));
}

test "chat message with ternary" {
    const msg = ChatMessage.withTernary(.Assistant, "Yes", .True, 0.95);
    try testing.expect(msg.ternary_status == .True);
    try testing.expectApproxEqAbs(@as(f64, 0.95), msg.confidence, 0.001);
}

test "chat history" {
    var history = ChatHistory.init(testing.allocator, 10);
    defer history.deinit();

    try history.addMessage(ChatMessage.init(.User, "Hello"));
    try history.addMessage(ChatMessage.init(.Assistant, "Hi"));

    try testing.expect(history.length() == 2);
}

test "chat history max messages" {
    var history = ChatHistory.init(testing.allocator, 3);
    defer history.deinit();

    try history.addMessage(ChatMessage.init(.User, "1"));
    try history.addMessage(ChatMessage.init(.User, "2"));
    try history.addMessage(ChatMessage.init(.User, "3"));
    try history.addMessage(ChatMessage.init(.User, "4"));

    try testing.expect(history.length() == 3);
}

test "chat interface init" {
    const config = ChatConfig{};
    var chat = ChatInterface.init(testing.allocator, config);
    defer chat.deinit();

    try testing.expect(chat.history.length() == 1); // System message
}

test "process input math" {
    const config = ChatConfig{};
    var chat = ChatInterface.init(testing.allocator, config);
    defer chat.deinit();

    const response = try chat.processInput("What is 2+2?");
    try testing.expect(std.mem.eql(u8, response.text, "4"));
    try testing.expect(response.ternary_status == .True);
}

test "process input unknown" {
    const config = ChatConfig{};
    var chat = ChatInterface.init(testing.allocator, config);
    defer chat.deinit();

    const response = try chat.processInput("random question xyz");
    try testing.expect(response.ternary_status == .Unknown);
}

test "is command" {
    try testing.expect(ChatInterface.isCommand("/help"));
    try testing.expect(!ChatInterface.isCommand("hello"));
}

test "process command help" {
    const config = ChatConfig{};
    var chat = ChatInterface.init(testing.allocator, config);
    defer chat.deinit();

    const result = try chat.processCommand("/help");
    try testing.expect(std.mem.indexOf(u8, result, "Commands") != null);
}

test "process command phi" {
    const config = ChatConfig{};
    var chat = ChatInterface.init(testing.allocator, config);
    defer chat.deinit();

    const result = try chat.processCommand("/phi");
    try testing.expect(std.mem.indexOf(u8, result, "1.618") != null);
}
