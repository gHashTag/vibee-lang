// ============================================================================
// VIBEEC LSP SERVER
// Language Server Protocol implementation for VIBEE
// ============================================================================

const std = @import("std");

// ============================================================================
// LSP TYPES
// ============================================================================

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

pub const DiagnosticSeverity = enum(u8) {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,
};

pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    message: []const u8,
    source: []const u8,
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

pub const CompletionItem = struct {
    label: []const u8,
    kind: CompletionItemKind,
    detail: ?[]const u8,
    documentation: ?[]const u8,
    insertText: ?[]const u8,
};

pub const Hover = struct {
    contents: []const u8,
    range: ?Range,
};

pub const TextEdit = struct {
    range: Range,
    newText: []const u8,
};

// ============================================================================
// DOCUMENT
// ============================================================================

pub const Document = struct {
    uri: []const u8,
    version: i32,
    content: []const u8,
    lines: [][]const u8,
    tree: ?*anyopaque,
    diagnostics: std.ArrayList(Diagnostic),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, uri: []const u8, content: []const u8, version: i32) !Document {
        var doc = Document{
            .uri = uri,
            .version = version,
            .content = content,
            .lines = &[_][]const u8{},
            .tree = null,
            .diagnostics = std.ArrayList(Diagnostic).init(allocator),
            .allocator = allocator,
        };
        try doc.splitLines();
        try doc.parse();
        return doc;
    }

    pub fn deinit(self: *Document) void {
        self.diagnostics.deinit();
    }

    pub fn update(self: *Document, content: []const u8, version: i32) !void {
        self.content = content;
        self.version = version;
        try self.splitLines();
        try self.parse();
    }

    fn splitLines(self: *Document) !void {
        var lines = std.ArrayList([]const u8).init(self.allocator);
        var start: usize = 0;

        for (self.content, 0..) |c, i| {
            if (c == '\n') {
                try lines.append(self.content[start..i]);
                start = i + 1;
            }
        }
        if (start < self.content.len) {
            try lines.append(self.content[start..]);
        }

        self.lines = try lines.toOwnedSlice();
    }

    fn parse(self: *Document) !void {
        self.diagnostics.clearRetainingCapacity();
        // Parsing will be done when integrated with full compiler
        self.tree = null;
    }

    pub fn getLine(self: *Document, line: u32) ?[]const u8 {
        if (line < self.lines.len) {
            return self.lines[line];
        }
        return null;
    }

    pub fn getWordAtPosition(self: *Document, pos: Position) ?[]const u8 {
        const line = self.getLine(pos.line) orelse return null;
        if (pos.character >= line.len) return null;

        var start = pos.character;
        var end = pos.character;

        // Find word start
        while (start > 0 and isIdentChar(line[start - 1])) {
            start -= 1;
        }

        // Find word end
        while (end < line.len and isIdentChar(line[end])) {
            end += 1;
        }

        if (start == end) return null;
        return line[start..end];
    }
};

fn isIdentChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_';
}

// ============================================================================
// SYMBOL TABLE
// ============================================================================

pub const SymbolKind = enum {
    Function,
    Variable,
    Constant,
    Type,
    Parameter,
};

pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    location: Location,
    type_info: ?[]const u8,
    documentation: ?[]const u8,
};

pub const SymbolTable = struct {
    symbols: std.StringHashMap(Symbol),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SymbolTable {
        return SymbolTable{
            .symbols = std.StringHashMap(Symbol).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        self.symbols.deinit();
    }

    pub fn addSymbol(self: *SymbolTable, symbol: Symbol) !void {
        try self.symbols.put(symbol.name, symbol);
    }

    pub fn getSymbol(self: *SymbolTable, name: []const u8) ?Symbol {
        return self.symbols.get(name);
    }

    pub fn buildFromAst(self: *SymbolTable, tree: *anyopaque, uri: []const u8) !void {
        // Will be implemented when integrated with full compiler
        _ = self;
        _ = tree;
        _ = uri;
    }
};

// ============================================================================
// LSP SERVER
// ============================================================================

pub const LspServer = struct {
    allocator: std.mem.Allocator,
    documents: std.StringHashMap(Document),
    symbols: SymbolTable,
    initialized: bool,
    shutdown_requested: bool,

    pub fn init(allocator: std.mem.Allocator) LspServer {
        return LspServer{
            .allocator = allocator,
            .documents = std.StringHashMap(Document).init(allocator),
            .symbols = SymbolTable.init(allocator),
            .initialized = false,
            .shutdown_requested = false,
        };
    }

    pub fn deinit(self: *LspServer) void {
        var it = self.documents.valueIterator();
        while (it.next()) |doc| {
            doc.deinit();
        }
        self.documents.deinit();
        self.symbols.deinit();
    }

    // ========================================================================
    // DOCUMENT MANAGEMENT
    // ========================================================================

    pub fn openDocument(self: *LspServer, uri: []const u8, content: []const u8, version: i32) !void {
        const doc = try Document.init(self.allocator, uri, content, version);
        if (doc.tree) |tree| {
            try self.symbols.buildFromAst(tree, uri);
        }
        try self.documents.put(uri, doc);
    }

    pub fn updateDocument(self: *LspServer, uri: []const u8, content: []const u8, version: i32) !void {
        if (self.documents.getPtr(uri)) |doc| {
            try doc.update(content, version);
            if (doc.tree) |tree| {
                try self.symbols.buildFromAst(tree, uri);
            }
        }
    }

    pub fn closeDocument(self: *LspServer, uri: []const u8) void {
        if (self.documents.fetchRemove(uri)) |kv| {
            var doc = kv.value;
            doc.deinit();
        }
    }

    pub fn getDocument(self: *LspServer, uri: []const u8) ?*Document {
        return self.documents.getPtr(uri);
    }

    // ========================================================================
    // LSP FEATURES
    // ========================================================================

    pub fn getCompletions(self: *LspServer, uri: []const u8, pos: Position) ![]CompletionItem {
        var completions = std.ArrayList(CompletionItem).init(self.allocator);

        // Add keywords
        const keywords = [_][]const u8{
            "fn", "let", "var", "const", "if", "else", "for", "while",
            "return", "true", "false", "None", "Some", "test", "struct",
            "enum", "match", "import", "pub", "as",
        };

        for (keywords) |kw| {
            try completions.append(CompletionItem{
                .label = kw,
                .kind = .Keyword,
                .detail = "keyword",
                .documentation = null,
                .insertText = kw,
            });
        }

        // Add symbols from symbol table
        var it = self.symbols.symbols.iterator();
        while (it.next()) |entry| {
            const symbol = entry.value_ptr.*;
            try completions.append(CompletionItem{
                .label = symbol.name,
                .kind = switch (symbol.kind) {
                    .Function => .Function,
                    .Variable => .Variable,
                    .Constant => .Constant,
                    .Type => .Class,
                    .Parameter => .Variable,
                },
                .detail = symbol.type_info,
                .documentation = symbol.documentation,
                .insertText = symbol.name,
            });
        }

        // Add types
        const types = [_][]const u8{ "Int", "Float", "Bool", "String", "Void", "Array", "Option" };
        for (types) |t| {
            try completions.append(CompletionItem{
                .label = t,
                .kind = .Class,
                .detail = "type",
                .documentation = null,
                .insertText = t,
            });
        }

        _ = uri;
        _ = pos;

        return completions.toOwnedSlice();
    }

    pub fn getHover(self: *LspServer, uri: []const u8, pos: Position) ?Hover {
        const doc = self.getDocument(uri) orelse return null;
        const word = doc.getWordAtPosition(pos) orelse return null;

        // Check symbol table
        if (self.symbols.getSymbol(word)) |symbol| {
            var hover_text = std.ArrayList(u8).init(self.allocator);
            const writer = hover_text.writer();

            writer.print("{s} ({s})", .{ symbol.name, @tagName(symbol.kind) }) catch return null;

            if (symbol.type_info) |ti| {
                writer.print(": {s}", .{ti}) catch {};
            }

            if (symbol.documentation) |doc_str| {
                writer.print("\n\n{s}", .{doc_str}) catch {};
            }

            return Hover{
                .contents = hover_text.toOwnedSlice() catch return null,
                .range = null,
            };
        }

        // Check keywords
        const keyword_docs = std.StaticStringMap([]const u8).initComptime(.{
            .{ "fn", "Function declaration" },
            .{ "let", "Immutable variable binding" },
            .{ "var", "Mutable variable binding" },
            .{ "const", "Compile-time constant" },
            .{ "if", "Conditional expression" },
            .{ "else", "Alternative branch" },
            .{ "for", "For loop iteration" },
            .{ "while", "While loop" },
            .{ "return", "Return from function" },
            .{ "true", "Boolean true literal" },
            .{ "false", "Boolean false literal" },
            .{ "None", "Optional none value" },
            .{ "Some", "Optional some value" },
            .{ "test", "Test declaration" },
            .{ "struct", "Structure type" },
            .{ "enum", "Enumeration type" },
            .{ "match", "Pattern matching" },
            .{ "import", "Import module" },
            .{ "pub", "Public visibility" },
        });

        if (keyword_docs.get(word)) |doc_str| {
            return Hover{
                .contents = doc_str,
                .range = null,
            };
        }

        // Check types
        const type_docs = std.StaticStringMap([]const u8).initComptime(.{
            .{ "Int", "64-bit signed integer" },
            .{ "Float", "64-bit floating point" },
            .{ "Bool", "Boolean (true/false)" },
            .{ "String", "UTF-8 string" },
            .{ "Void", "No return value" },
            .{ "Array", "Dynamic array" },
            .{ "Option", "Optional value (Some/None)" },
        });

        if (type_docs.get(word)) |doc_str| {
            return Hover{
                .contents = doc_str,
                .range = null,
            };
        }

        return null;
    }

    pub fn getDefinition(self: *LspServer, uri: []const u8, pos: Position) ?Location {
        const doc = self.getDocument(uri) orelse return null;
        const word = doc.getWordAtPosition(pos) orelse return null;

        if (self.symbols.getSymbol(word)) |symbol| {
            return symbol.location;
        }

        return null;
    }

    pub fn getDiagnostics(self: *LspServer, uri: []const u8) []Diagnostic {
        const doc = self.getDocument(uri) orelse return &[_]Diagnostic{};
        return doc.diagnostics.items;
    }

    pub fn formatDocument(self: *LspServer, uri: []const u8) ![]TextEdit {
        _ = self;
        _ = uri;
        // TODO: Implement formatting
        return &[_]TextEdit{};
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "document parsing" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var doc = try Document.init(allocator, "test.vibee", "fn main() { }", 1);
    defer doc.deinit();

    // Tree is null until full parser integration
    try std.testing.expect(doc.diagnostics.items.len == 0);
}

test "symbol table" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var symbols = SymbolTable.init(allocator);
    defer symbols.deinit();

    try symbols.addSymbol(Symbol{
        .name = "test_func",
        .kind = .Function,
        .location = Location{
            .uri = "test.vibee",
            .range = Range{
                .start = Position{ .line = 0, .character = 0 },
                .end = Position{ .line = 0, .character = 0 },
            },
        },
        .type_info = null,
        .documentation = null,
    });

    const sym = symbols.getSymbol("test_func");
    try std.testing.expect(sym != null);
    try std.testing.expectEqualStrings("test_func", sym.?.name);
}

test "lsp server completions" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var server = LspServer.init(allocator);
    defer server.deinit();

    try server.openDocument("test.vibee", "fn main() { }", 1);

    const completions = try server.getCompletions("test.vibee", Position{ .line = 0, .character = 0 });
    try std.testing.expect(completions.len > 0);
}

test "lsp server hover" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var server = LspServer.init(allocator);
    defer server.deinit();

    try server.openDocument("test.vibee", "fn main() { }", 1);

    // Test keyword hover
    const hover = server.getHover("test.vibee", Position{ .line = 0, .character = 0 });
    // "fn" is at position 0
    _ = hover;
}
