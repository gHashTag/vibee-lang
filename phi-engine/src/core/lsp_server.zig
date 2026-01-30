// LSP Server for VIBEE/999 Language
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37
// Language Server Protocol implementation

const std = @import("std");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const GOLDEN_IDENTITY: f64 = 3.0;

// LSP Message Types
pub const MessageType = enum(u8) {
    @"error" = 1,
    warning = 2,
    info = 3,
    log = 4,
};

// Position in document
pub const Position = struct {
    line: u32,
    character: u32,
};

// Range in document
pub const Range = struct {
    start: Position,
    end: Position,
};

// Location
pub const Location = struct {
    uri: []const u8,
    range: Range,
};

// Diagnostic severity
pub const DiagnosticSeverity = enum(u8) {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,
};

// Diagnostic
pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    code: ?[]const u8,
    source: []const u8,
    message: []const u8,
};

// Completion item kind
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

// Completion item
pub const CompletionItem = struct {
    label: []const u8,
    kind: CompletionItemKind,
    detail: ?[]const u8,
    documentation: ?[]const u8,
    insertText: ?[]const u8,
};

// Document symbol
pub const DocumentSymbol = struct {
    name: []const u8,
    kind: SymbolKind,
    range: Range,
    selectionRange: Range,
    children: ?[]DocumentSymbol,
};

pub const SymbolKind = enum(u8) {
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
    Object = 19,
    Key = 20,
    Null = 21,
    EnumMember = 22,
    Struct = 23,
    Event = 24,
    Operator = 25,
    TypeParameter = 26,
};

// VIBEE/999 Keywords
pub const VIBEE_KEYWORDS = [_][]const u8{
    // Coptic symbols
    "Ⲫ", // function
    "Ⲏ", // struct/type
    "Ⲕ", // const
    "Ⲃ", // var
    "Ⲉ", // if
    "Ⲁ", // else
    "Ⲝ", // for
    "Ⲱ", // while
    "Ⲣ", // return
    "△", // true
    "▽", // false
    "○", // null
    // Standard keywords
    "name",
    "version",
    "language",
    "module",
    "creation_pattern",
    "source",
    "transformer",
    "result",
    "behaviors",
    "given",
    "when",
    "then",
    "test_cases",
    "sacred_formula",
    "golden_identity",
    "phoenix",
};

// VIBEE/999 Built-in types
pub const VIBEE_TYPES = [_][]const u8{
    "Ⲓⲛⲧ",
    "Ⲫⲗⲟⲁⲧ",
    "Ⲥⲧⲣⲓⲛⲅ",
    "Ⲃⲟⲟⲗ",
    "Ⲗⲓⲥⲧ",
    "Ⲙⲁⲡ",
    "Ⲣⲉⲥⲩⲗⲧ",
    "Ⲟⲡⲧⲓⲟⲛ",
    "i32",
    "i64",
    "u32",
    "u64",
    "f32",
    "f64",
    "bool",
    "void",
};

// LSP Server
pub const LSPServer = struct {
    allocator: std.mem.Allocator,
    documents: std.StringHashMap([]const u8),
    initialized: bool,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .documents = std.StringHashMap([]const u8).init(allocator),
            .initialized = false,
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.documents.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.documents.deinit();
    }
    
    // Handle initialize request
    pub fn handleInitialize(self: *Self) ![]const u8 {
        self.initialized = true;
        
        return 
            \\{
            \\  "capabilities": {
            \\    "textDocumentSync": 1,
            \\    "completionProvider": {
            \\      "triggerCharacters": [".", ":", "Ⲫ", "Ⲏ", "Ⲕ"]
            \\    },
            \\    "hoverProvider": true,
            \\    "definitionProvider": true,
            \\    "documentSymbolProvider": true,
            \\    "diagnosticProvider": {
            \\      "interFileDependencies": false,
            \\      "workspaceDiagnostics": false
            \\    }
            \\  },
            \\  "serverInfo": {
            \\    "name": "vibee-lsp",
            \\    "version": "3.0.0"
            \\  }
            \\}
        ;
    }
    
    // Open document
    pub fn openDocument(self: *Self, uri: []const u8, content: []const u8) !void {
        const content_copy = try self.allocator.dupe(u8, content);
        try self.documents.put(uri, content_copy);
    }
    
    // Get completions
    pub fn getCompletions(self: *Self, uri: []const u8, position: Position) ![]CompletionItem {
        _ = uri;
        _ = position;
        
        var items = std.ArrayList(CompletionItem).init(self.allocator);
        
        // Add keywords
        for (VIBEE_KEYWORDS) |kw| {
            try items.append(.{
                .label = kw,
                .kind = .Keyword,
                .detail = "VIBEE keyword",
                .documentation = null,
                .insertText = kw,
            });
        }
        
        // Add types
        for (VIBEE_TYPES) |t| {
            try items.append(.{
                .label = t,
                .kind = .Class,
                .detail = "VIBEE type",
                .documentation = null,
                .insertText = t,
            });
        }
        
        // Add sacred constants
        try items.append(.{
            .label = "PHI",
            .kind = .Constant,
            .detail = "φ = 1.618033988749895",
            .documentation = "Golden ratio constant",
            .insertText = "1.6180339887498948482",
        });
        
        try items.append(.{
            .label = "PHOENIX",
            .kind = .Constant,
            .detail = "999 = 3³ × 37",
            .documentation = "Sacred Phoenix number",
            .insertText = "999",
        });
        
        try items.append(.{
            .label = "TRINITY",
            .kind = .Constant,
            .detail = "3 = φ² + 1/φ²",
            .documentation = "Golden Identity result",
            .insertText = "3",
        });
        
        return items.toOwnedSlice();
    }
    
    // Get hover info
    pub fn getHover(self: *Self, uri: []const u8, position: Position) !?[]const u8 {
        const content = self.documents.get(uri) orelse return null;
        
        // Find word at position
        const word = self.getWordAtPosition(content, position) orelse return null;
        
        // Check for known symbols
        if (std.mem.eql(u8, word, "Ⲫ")) {
            return "**Ⲫ** - Function definition\n\nDefines a function in VIBEE/999 language.";
        }
        if (std.mem.eql(u8, word, "Ⲏ")) {
            return "**Ⲏ** - Type/Struct definition\n\nDefines a type or struct in VIBEE/999 language.";
        }
        if (std.mem.eql(u8, word, "Ⲕ")) {
            return "**Ⲕ** - Constant definition\n\nDefines a constant in VIBEE/999 language.";
        }
        if (std.mem.eql(u8, word, "△")) {
            return "**△** - True (Trinity True)\n\nBoolean true value in VIBEE/999 language.";
        }
        if (std.mem.eql(u8, word, "▽")) {
            return "**▽** - False (Trinity False)\n\nBoolean false value in VIBEE/999 language.";
        }
        if (std.mem.eql(u8, word, "○")) {
            return "**○** - Null (Trinity Null)\n\nNull value in VIBEE/999 language.";
        }
        if (std.mem.eql(u8, word, "creation_pattern")) {
            return "**creation_pattern**\n\nDefines the Source → Transformer → Result pattern.";
        }
        if (std.mem.eql(u8, word, "sacred_formula")) {
            return "**sacred_formula**\n\nV = n × 3^k × π^m × φ^p × e^q\n\nThe sacred VIBEE formula.";
        }
        if (std.mem.eql(u8, word, "golden_identity")) {
            return "**golden_identity**\n\nφ² + 1/φ² = 3\n\nThe golden identity connecting φ and 3.";
        }
        
        return null;
    }
    
    // Get diagnostics
    pub fn getDiagnostics(self: *Self, uri: []const u8) ![]Diagnostic {
        const content = self.documents.get(uri) orelse return &[_]Diagnostic{};
        
        var diagnostics = std.ArrayList(Diagnostic).init(self.allocator);
        
        // Check for common issues
        var line: u32 = 0;
        var lines = std.mem.splitScalar(u8, content, '\n');
        
        while (lines.next()) |line_content| {
            // Check for missing colon in key-value pairs
            if (std.mem.indexOf(u8, line_content, ":") == null and
                line_content.len > 0 and
                !std.mem.startsWith(u8, std.mem.trim(u8, line_content, " "), "#") and
                !std.mem.startsWith(u8, std.mem.trim(u8, line_content, " "), "-"))
            {
                // Might be missing colon
            }
            
            // Check for tabs (should use spaces)
            if (std.mem.indexOf(u8, line_content, "\t") != null) {
                try diagnostics.append(.{
                    .range = .{
                        .start = .{ .line = line, .character = 0 },
                        .end = .{ .line = line, .character = @intCast(line_content.len) },
                    },
                    .severity = .Warning,
                    .code = "W001",
                    .source = "vibee-lsp",
                    .message = "Use spaces instead of tabs for indentation",
                });
            }
            
            line += 1;
        }
        
        return diagnostics.toOwnedSlice();
    }
    
    // Helper: get word at position
    fn getWordAtPosition(self: *Self, content: []const u8, position: Position) ?[]const u8 {
        _ = self;
        
        var line: u32 = 0;
        var lines = std.mem.splitScalar(u8, content, '\n');
        
        while (lines.next()) |line_content| {
            if (line == position.line) {
                if (position.character >= line_content.len) return null;
                
                // Find word boundaries
                var start = position.character;
                var end = position.character;
                
                while (start > 0 and !isWordBoundary(line_content[start - 1])) {
                    start -= 1;
                }
                while (end < line_content.len and !isWordBoundary(line_content[end])) {
                    end += 1;
                }
                
                if (start < end) {
                    return line_content[start..end];
                }
                return null;
            }
            line += 1;
        }
        return null;
    }
    
    fn isWordBoundary(c: u8) bool {
        return c == ' ' or c == '\t' or c == ':' or c == ',' or 
               c == '[' or c == ']' or c == '{' or c == '}' or
               c == '(' or c == ')' or c == '\n' or c == '\r';
    }
};

// JSON-RPC message parser (simplified)
pub const JsonRpcMessage = struct {
    id: ?i64,
    method: []const u8,
    params: ?[]const u8,
};

// Tests
test "LSP server init" {
    const allocator = std.testing.allocator;
    
    var server = LSPServer.init(allocator);
    defer server.deinit();
    
    const response = try server.handleInitialize();
    try std.testing.expect(response.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, response, "vibee-lsp") != null);
}

test "LSP completions" {
    const allocator = std.testing.allocator;
    
    var server = LSPServer.init(allocator);
    defer server.deinit();
    
    const items = try server.getCompletions("test.vibee", .{ .line = 0, .character = 0 });
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

test "LSP hover" {
    const allocator = std.testing.allocator;
    
    var server = LSPServer.init(allocator);
    defer server.deinit();
    
    try server.openDocument("test.vibee", "Ⲫ test() { }");
    
    const hover = try server.getHover("test.vibee", .{ .line = 0, .character = 0 });
    try std.testing.expect(hover != null);
    try std.testing.expect(std.mem.indexOf(u8, hover.?, "Function") != null);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
