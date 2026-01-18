// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC LSP SERVER - LANGUAGE SERVER PROTOCOL
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V37 - IDE Integration via LSP
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const json = std.json;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";
pub const SERVER_NAME = "vibeec-lsp";

// ═══════════════════════════════════════════════════════════════════════════════
// LSP MESSAGE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const MessageType = enum(u8) {
    request = 1,
    response = 2,
    notification = 3,
};

pub const Position = struct {
    line: u32,
    character: u32,
};

pub const Range = struct {
    start: Position,
    end: Position,
};

pub const Location = struct {
    uri: []const u8,
    range: Range,
};

pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    code: ?[]const u8,
    source: []const u8,
    message: []const u8,
};

pub const DiagnosticSeverity = enum(u8) {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,
};

pub const CompletionItem = struct {
    label: []const u8,
    kind: CompletionItemKind,
    detail: ?[]const u8,
    documentation: ?[]const u8,
    insertText: ?[]const u8,
};

pub const CompletionItemKind = enum(u8) {
    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
    Unit = 11,
    Value = 12,
    Enum = 13,
    Keyword = 14,
    Snippet = 15,
    Color = 16,
    File = 17,
    Reference = 18,
    Folder = 19,
    EnumMember = 20,
    Constant = 21,
    Struct = 22,
    Event = 23,
    Operator = 24,
    TypeParameter = 25,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DOCUMENT STORE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Document = struct {
    uri: []const u8,
    content: []const u8,
    version: i32,
};

pub const DocumentStore = struct {
    allocator: Allocator,
    documents: std.StringHashMap(Document),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .documents = std.StringHashMap(Document).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.documents.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.content);
        }
        self.documents.deinit();
    }

    pub fn open(self: *Self, uri: []const u8, content: []const u8, version: i32) !void {
        const content_copy = try self.allocator.dupe(u8, content);
        try self.documents.put(uri, .{
            .uri = uri,
            .content = content_copy,
            .version = version,
        });
    }

    pub fn update(self: *Self, uri: []const u8, content: []const u8, version: i32) !void {
        if (self.documents.getPtr(uri)) |doc| {
            self.allocator.free(doc.content);
            doc.content = try self.allocator.dupe(u8, content);
            doc.version = version;
        }
    }

    pub fn close(self: *Self, uri: []const u8) void {
        if (self.documents.fetchRemove(uri)) |kv| {
            self.allocator.free(kv.value.content);
        }
    }

    pub fn get(self: *const Self, uri: []const u8) ?Document {
        return self.documents.get(uri);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LSP SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const LSPServer = struct {
    allocator: Allocator,
    documents: DocumentStore,
    initialized: bool,
    shutdown_requested: bool,

    // Capabilities
    completion_enabled: bool,
    hover_enabled: bool,
    diagnostics_enabled: bool,

    // Metrics
    requests_handled: u64,
    notifications_handled: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .documents = DocumentStore.init(allocator),
            .initialized = false,
            .shutdown_requested = false,
            .completion_enabled = true,
            .hover_enabled = true,
            .diagnostics_enabled = true,
            .requests_handled = 0,
            .notifications_handled = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.documents.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REQUEST HANDLERS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn handleInitialize(self: *Self) InitializeResult {
        self.initialized = true;
        self.requests_handled += 1;

        return InitializeResult{
            .capabilities = .{
                .textDocumentSync = 1, // Full sync
                .completionProvider = .{
                    .triggerCharacters = &[_][]const u8{ ".", ":" },
                    .resolveProvider = false,
                },
                .hoverProvider = true,
                .definitionProvider = true,
                .referencesProvider = true,
                .documentSymbolProvider = true,
            },
            .serverInfo = .{
                .name = SERVER_NAME,
                .version = VERSION,
            },
        };
    }

    pub fn handleShutdown(self: *Self) void {
        self.shutdown_requested = true;
        self.requests_handled += 1;
    }

    pub fn handleCompletion(self: *Self, uri: []const u8, position: Position) ![]CompletionItem {
        _ = uri;
        _ = position;
        self.requests_handled += 1;

        var items = ArrayList(CompletionItem).init(self.allocator);

        // VIBEE keywords
        const keywords = [_][]const u8{
            "name",            "version",       "language",       "module",
            "creation_pattern", "source",        "transformer",    "result",
            "behaviors",       "given",         "when",           "then",
            "test_cases",      "types",         "kind",           "fields",
            "methods",         "pas_analysis",  "sacred_formula", "constants",
        };

        for (keywords) |kw| {
            try items.append(.{
                .label = kw,
                .kind = .Keyword,
                .detail = "VIBEE keyword",
                .documentation = null,
                .insertText = kw,
            });
        }

        // Sacred constants
        try items.append(.{
            .label = "PHI",
            .kind = .Constant,
            .detail = "φ = 1.618033988749895",
            .documentation = "Golden ratio",
            .insertText = "1.618033988749895",
        });

        try items.append(.{
            .label = "GOLDEN_IDENTITY",
            .kind = .Constant,
            .detail = "φ² + 1/φ² = 3",
            .documentation = "Golden identity",
            .insertText = "3.0",
        });

        try items.append(.{
            .label = "PI",
            .kind = .Constant,
            .detail = "π = 3.14159265358979",
            .documentation = "Pi",
            .insertText = "3.14159265358979",
        });

        try items.append(.{
            .label = "E",
            .kind = .Constant,
            .detail = "e = 2.71828182845904",
            .documentation = "Euler's number",
            .insertText = "2.71828182845904",
        });

        return items.toOwnedSlice();
    }

    pub fn handleHover(self: *Self, uri: []const u8, position: Position) ?HoverResult {
        _ = uri;
        _ = position;
        self.requests_handled += 1;

        // Return sacred formula info
        return HoverResult{
            .contents = .{
                .kind = "markdown",
                .value =
                \\# VIBEE Sacred Formula
                \\
                \\```
                \\V = n × 3^k × π^m × φ^p × e^q
                \\```
                \\
                \\**Golden Identity:** φ² + 1/φ² = 3
                \\
                \\- φ (PHI) = 1.618033988749895
                \\- π (PI) = 3.14159265358979
                \\- e (E) = 2.71828182845904
                ,
            },
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // NOTIFICATION HANDLERS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn handleDidOpen(self: *Self, uri: []const u8, content: []const u8, version: i32) !void {
        try self.documents.open(uri, content, version);
        self.notifications_handled += 1;
    }

    pub fn handleDidChange(self: *Self, uri: []const u8, content: []const u8, version: i32) !void {
        try self.documents.update(uri, content, version);
        self.notifications_handled += 1;
    }

    pub fn handleDidClose(self: *Self, uri: []const u8) void {
        self.documents.close(uri);
        self.notifications_handled += 1;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIAGNOSTICS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn getDiagnostics(self: *Self, uri: []const u8) ![]Diagnostic {
        const doc = self.documents.get(uri) orelse return &.{};

        var diagnostics = ArrayList(Diagnostic).init(self.allocator);

        // Simple validation: check for required fields
        if (std.mem.indexOf(u8, doc.content, "name:") == null) {
            try diagnostics.append(.{
                .range = .{
                    .start = .{ .line = 0, .character = 0 },
                    .end = .{ .line = 0, .character = 1 },
                },
                .severity = .Error,
                .code = "E001",
                .source = "vibeec",
                .message = "Missing required field 'name'",
            });
        }

        return diagnostics.toOwnedSlice();
    }

    pub fn getMetrics(self: *const Self) LSPMetrics {
        return .{
            .requests_handled = self.requests_handled,
            .notifications_handled = self.notifications_handled,
            .documents_open = self.documents.documents.count(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const InitializeResult = struct {
    capabilities: ServerCapabilities,
    serverInfo: ServerInfo,
};

pub const ServerCapabilities = struct {
    textDocumentSync: u8,
    completionProvider: CompletionOptions,
    hoverProvider: bool,
    definitionProvider: bool,
    referencesProvider: bool,
    documentSymbolProvider: bool,
};

pub const CompletionOptions = struct {
    triggerCharacters: []const []const u8,
    resolveProvider: bool,
};

pub const ServerInfo = struct {
    name: []const u8,
    version: []const u8,
};

pub const HoverResult = struct {
    contents: MarkupContent,
};

pub const MarkupContent = struct {
    kind: []const u8,
    value: []const u8,
};

pub const LSPMetrics = struct {
    requests_handled: u64,
    notifications_handled: u64,
    documents_open: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LSPServer initialize" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();

    const result = server.handleInitialize();

    try std.testing.expect(server.initialized);
    try std.testing.expectEqualStrings(SERVER_NAME, result.serverInfo.name);
    try std.testing.expectEqualStrings(VERSION, result.serverInfo.version);
}

test "DocumentStore" {
    const allocator = std.testing.allocator;
    var store = DocumentStore.init(allocator);
    defer store.deinit();

    try store.open("file:///test.vibee", "name: test", 1);

    const doc = store.get("file:///test.vibee");
    try std.testing.expect(doc != null);
    try std.testing.expectEqualStrings("name: test", doc.?.content);

    store.close("file:///test.vibee");
    try std.testing.expect(store.get("file:///test.vibee") == null);
}

test "LSPServer completion" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();

    const items = try server.handleCompletion("file:///test.vibee", .{ .line = 0, .character = 0 });
    defer allocator.free(items);

    try std.testing.expect(items.len > 0);

    // Check for PHI constant
    var found_phi = false;
    for (items) |item| {
        if (std.mem.eql(u8, item.label, "PHI")) {
            found_phi = true;
            break;
        }
    }
    try std.testing.expect(found_phi);
}

test "LSPServer hover" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();

    const hover = server.handleHover("file:///test.vibee", .{ .line = 0, .character = 0 });
    try std.testing.expect(hover != null);
    try std.testing.expect(std.mem.indexOf(u8, hover.?.contents.value, "Sacred Formula") != null);
}

test "LSPServer diagnostics" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();

    try server.handleDidOpen("file:///test.vibee", "version: 1.0.0", 1);

    const diagnostics = try server.getDiagnostics("file:///test.vibee");
    defer allocator.free(diagnostics);

    // Should have error for missing 'name'
    try std.testing.expect(diagnostics.len > 0);
    try std.testing.expectEqualStrings("E001", diagnostics[0].code.?);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
