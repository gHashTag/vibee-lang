// lsp.zig - Language Server Protocol Module
// Generated from: crush/internal/lsp
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// LSP Message types
pub const MessageType = enum {
    request,
    response,
    notification,

    pub fn toString(self: MessageType) []const u8 {
        return switch (self) {
            .request => "request",
            .response => "response",
            .notification => "notification",
        };
    }
};

/// LSP Methods
pub const Method = enum {
    initialize,
    initialized,
    shutdown,
    exit,
    textDocument_didOpen,
    textDocument_didChange,
    textDocument_didClose,
    textDocument_completion,
    textDocument_hover,
    textDocument_definition,

    pub fn toString(self: Method) []const u8 {
        return switch (self) {
            .initialize => "initialize",
            .initialized => "initialized",
            .shutdown => "shutdown",
            .exit => "exit",
            .textDocument_didOpen => "textDocument/didOpen",
            .textDocument_didChange => "textDocument/didChange",
            .textDocument_didClose => "textDocument/didClose",
            .textDocument_completion => "textDocument/completion",
            .textDocument_hover => "textDocument/hover",
            .textDocument_definition => "textDocument/definition",
        };
    }
};

/// Position in document
pub const Position = struct {
    line: u32,
    character: u32,
};

/// Range in document
pub const Range = struct {
    start: Position,
    end: Position,
};

/// Text document identifier
pub const TextDocumentIdentifier = struct {
    uri: []const u8,
};

/// Text document item
pub const TextDocumentItem = struct {
    uri: []const u8,
    language_id: []const u8,
    version: i32,
    text: []const u8,
};

/// Completion item
pub const CompletionItem = struct {
    label: []const u8,
    kind: ?u8,
    detail: ?[]const u8,
    documentation: ?[]const u8,
    insert_text: ?[]const u8,
};

/// Hover result
pub const Hover = struct {
    contents: []const u8,
    range: ?Range,
};

/// Location
pub const Location = struct {
    uri: []const u8,
    range: Range,
};

/// LSP Server state
pub const ServerState = enum {
    uninitialized,
    initializing,
    initialized,
    shutting_down,
    stopped,
};

/// LSP Server
pub const Server = struct {
    state: ServerState,
    documents: std.StringHashMap(TextDocumentItem),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .state = .uninitialized,
            .documents = std.StringHashMap(TextDocumentItem).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.documents.deinit();
    }

    pub fn initialize(self: *Self) void {
        self.state = .initializing;
    }

    pub fn initialized(self: *Self) void {
        self.state = .initialized;
    }

    pub fn shutdown(self: *Self) void {
        self.state = .shutting_down;
    }

    pub fn exit(self: *Self) void {
        self.state = .stopped;
    }

    pub fn openDocument(self: *Self, doc: TextDocumentItem) !void {
        try self.documents.put(doc.uri, doc);
    }

    pub fn closeDocument(self: *Self, uri: []const u8) void {
        _ = self.documents.remove(uri);
    }

    pub fn getDocument(self: *Self, uri: []const u8) ?TextDocumentItem {
        return self.documents.get(uri);
    }

    pub fn documentCount(self: *Self) usize {
        return self.documents.count();
    }

    pub fn isInitialized(self: *Self) bool {
        return self.state == .initialized;
    }
};

/// Parse LSP header
pub fn parseHeader(header: []const u8) ?usize {
    const prefix = "Content-Length: ";
    if (std.mem.startsWith(u8, header, prefix)) {
        const len_str = header[prefix.len..];
        return std.fmt.parseInt(usize, std.mem.trim(u8, len_str, " \r\n"), 10) catch null;
    }
    return null;
}

// Tests
test "message_type_to_string" {
    try std.testing.expectEqualStrings("request", MessageType.request.toString());
    try std.testing.expectEqualStrings("response", MessageType.response.toString());
}

test "method_to_string" {
    try std.testing.expectEqualStrings("initialize", Method.initialize.toString());
    try std.testing.expectEqualStrings("textDocument/didOpen", Method.textDocument_didOpen.toString());
}

test "server_init" {
    const allocator = std.testing.allocator;
    var server = Server.init(allocator);
    defer server.deinit();

    try std.testing.expectEqual(ServerState.uninitialized, server.state);
}

test "server_lifecycle" {
    const allocator = std.testing.allocator;
    var server = Server.init(allocator);
    defer server.deinit();

    server.initialize();
    try std.testing.expectEqual(ServerState.initializing, server.state);

    server.initialized();
    try std.testing.expect(server.isInitialized());

    server.shutdown();
    try std.testing.expectEqual(ServerState.shutting_down, server.state);

    server.exit();
    try std.testing.expectEqual(ServerState.stopped, server.state);
}

test "server_documents" {
    const allocator = std.testing.allocator;
    var server = Server.init(allocator);
    defer server.deinit();

    try server.openDocument(TextDocumentItem{
        .uri = "file:///test.zig",
        .language_id = "zig",
        .version = 1,
        .text = "const x = 1;",
    });

    try std.testing.expectEqual(@as(usize, 1), server.documentCount());

    const doc = server.getDocument("file:///test.zig");
    try std.testing.expect(doc != null);
    try std.testing.expectEqualStrings("zig", doc.?.language_id);

    server.closeDocument("file:///test.zig");
    try std.testing.expectEqual(@as(usize, 0), server.documentCount());
}

test "parse_header" {
    try std.testing.expectEqual(@as(?usize, 123), parseHeader("Content-Length: 123"));
    try std.testing.expectEqual(@as(?usize, 456), parseHeader("Content-Length: 456\r\n"));
    try std.testing.expect(parseHeader("Invalid") == null);
}

test "position" {
    const pos = Position{ .line = 10, .character = 5 };
    try std.testing.expectEqual(@as(u32, 10), pos.line);
    try std.testing.expectEqual(@as(u32, 5), pos.character);
}

test "range" {
    const range = Range{
        .start = Position{ .line = 0, .character = 0 },
        .end = Position{ .line = 0, .character = 10 },
    };
    try std.testing.expectEqual(@as(u32, 0), range.start.line);
    try std.testing.expectEqual(@as(u32, 10), range.end.character);
}
