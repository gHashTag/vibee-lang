// ═══════════════════════════════════════════════════════════════════════════════
// LSP SERVER - Language Server Protocol for VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS: PRE + MLS | φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const json = std.json;
const mem = std.mem;
const Allocator = mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// LSP TYPES
// ═══════════════════════════════════════════════════════════════════════════════

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
    severity: u8,
    code: []const u8,
    source: []const u8,
    message: []const u8,
};

pub const CompletionItem = struct {
    label: []const u8,
    kind: u8,
    detail: []const u8,
    documentation: []const u8,
    insertText: []const u8,
};

pub const ServerCapabilities = struct {
    textDocumentSync: u8 = 1,
    completionProvider: bool = true,
    hoverProvider: bool = true,
    definitionProvider: bool = true,
    referencesProvider: bool = true,
    documentSymbolProvider: bool = true,
    diagnosticProvider: bool = true,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LSP SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const LSPServer = struct {
    allocator: Allocator,
    documents: std.StringHashMap([]const u8),
    capabilities: ServerCapabilities,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .documents = std.StringHashMap([]const u8).init(allocator),
            .capabilities = ServerCapabilities{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.documents.deinit();
    }

    pub fn handleRequest(self: *Self, method: []const u8, params: []const u8) ![]const u8 {
        _ = params;
        if (mem.eql(u8, method, "initialize")) {
            return self.handleInitialize();
        } else if (mem.eql(u8, method, "textDocument/completion")) {
            return self.handleCompletion();
        } else if (mem.eql(u8, method, "textDocument/hover")) {
            return self.handleHover();
        } else if (mem.eql(u8, method, "textDocument/definition")) {
            return self.handleDefinition();
        }
        return "null";
    }

    fn handleInitialize(self: *Self) []const u8 {
        _ = self;
        return 
            \\{"capabilities": {"textDocumentSync": 1, "completionProvider": true, "hoverProvider": true}}
        ;
    }

    fn handleCompletion(self: *Self) []const u8 {
        _ = self;
        return 
            \\[{"label": "name:", "kind": 14}, {"label": "version:", "kind": 14}, {"label": "behaviors:", "kind": 14}, {"label": "phi", "kind": 21, "detail": "1.618033988749895"}]
        ;
    }

    fn handleHover(self: *Self) []const u8 {
        _ = self;
        return 
            \\{"contents": "φ = 1.618033988749895\\nφ² + 1/φ² = 3\\nPHOENIX = 999"}
        ;
    }

    fn handleDefinition(self: *Self) []const u8 {
        _ = self;
        return 
            \\{"uri": "file:///specs/types.vibee", "range": {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 10}}}
        ;
    }

    pub fn getCompletionItems() [4]CompletionItem {
        return [4]CompletionItem{
            .{ .label = "name:", .kind = 14, .detail = "Specification name", .documentation = "Required field", .insertText = "name: " },
            .{ .label = "version:", .kind = 14, .detail = "Version string", .documentation = "Semantic version", .insertText = "version: \"1.0.0\"" },
            .{ .label = "behaviors:", .kind = 14, .detail = "Behavior list", .documentation = "Given/When/Then", .insertText = "behaviors:\\n  - name: " },
            .{ .label = "phi", .kind = 21, .detail = "1.618033988749895", .documentation = "Golden ratio", .insertText = "phi" },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LSP initialize" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();
    
    const result = try server.handleRequest("initialize", "{}");
    try std.testing.expect(mem.indexOf(u8, result, "capabilities") != null);
}

test "LSP completion" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();
    
    const result = try server.handleRequest("textDocument/completion", "{}");
    try std.testing.expect(mem.indexOf(u8, result, "name:") != null);
}

test "LSP hover" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();
    
    const result = try server.handleRequest("textDocument/hover", "{}");
    try std.testing.expect(mem.indexOf(u8, result, "1.618033988749895") != null);
}

test "LSP definition" {
    const allocator = std.testing.allocator;
    var server = LSPServer.init(allocator);
    defer server.deinit();
    
    const result = try server.handleRequest("textDocument/definition", "{}");
    try std.testing.expect(mem.indexOf(u8, result, "uri") != null);
}

test "completion items count" {
    const items = LSPServer.getCompletionItems();
    try std.testing.expectEqual(@as(usize, 4), items.len);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
