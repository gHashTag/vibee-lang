// ═══════════════════════════════════════════════════════════════════════════════
// TRI PARSER - GENERATED FROM ⲧⲣⲓ_ⲡⲁⲣⲥⲉⲣ.tri
// ═══════════════════════════════════════════════════════════════════════════════
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: 50-200 MB/s (competitive with libyaml)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const TokenType = enum {
    IDENT,
    STRING,
    NUMBER,
    COLON,
    DASH,
    INDENT,
    NEWLINE,
    COMMENT,
    LBRACKET,
    RBRACKET,
    LBRACE,
    RBRACE,
    COMMA,
    PIPE,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8, // Zero-copy slice into input
    line: u32,
    col: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// AST NODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueNode = union(enum) {
    string: []const u8,
    number: f64,
    boolean: bool,
    null_val: void,
    map: *MapNode,
    array: *ArrayNode,
};

pub const MapEntry = struct {
    key: []const u8,
    value: ValueNode,
};

pub const MapNode = struct {
    entries: std.ArrayList(MapEntry),

    pub fn init(allocator: std.mem.Allocator) MapNode {
        return .{ .entries = std.ArrayList(MapEntry).init(allocator) };
    }

    pub fn deinit(self: *MapNode) void {
        self.entries.deinit();
    }
};

pub const ArrayNode = struct {
    items: std.ArrayList(ValueNode),

    pub fn init(allocator: std.mem.Allocator) ArrayNode {
        return .{ .items = std.ArrayList(ValueNode).init(allocator) };
    }

    pub fn deinit(self: *ArrayNode) void {
        self.items.deinit();
    }
};

pub const Document = struct {
    root: MapNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Document {
        return .{
            .root = MapNode.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Document) void {
        self.root.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LEXER - ZERO-COPY TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Lexer = struct {
    input: []const u8,
    pos: usize,
    line: u32,
    col: u32,

    const Self = @This();

    pub fn init(input: []const u8) Self {
        return .{
            .input = input,
            .pos = 0,
            .line = 1,
            .col = 1,
        };
    }

    pub fn nextToken(self: *Self) Token {
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return .{ .type = .EOF, .value = "", .line = self.line, .col = self.col };
        }

        const start = self.pos;
        const start_col = self.col;
        const c = self.input[self.pos];

        // Single character tokens
        switch (c) {
            ':' => {
                self.advance();
                return .{ .type = .COLON, .value = ":", .line = self.line, .col = start_col };
            },
            '-' => {
                self.advance();
                return .{ .type = .DASH, .value = "-", .line = self.line, .col = start_col };
            },
            '[' => {
                self.advance();
                return .{ .type = .LBRACKET, .value = "[", .line = self.line, .col = start_col };
            },
            ']' => {
                self.advance();
                return .{ .type = .RBRACKET, .value = "]", .line = self.line, .col = start_col };
            },
            '{' => {
                self.advance();
                return .{ .type = .LBRACE, .value = "{", .line = self.line, .col = start_col };
            },
            '}' => {
                self.advance();
                return .{ .type = .RBRACE, .value = "}", .line = self.line, .col = start_col };
            },
            ',' => {
                self.advance();
                return .{ .type = .COMMA, .value = ",", .line = self.line, .col = start_col };
            },
            '|' => {
                self.advance();
                return .{ .type = .PIPE, .value = "|", .line = self.line, .col = start_col };
            },
            '\n' => {
                self.advance();
                self.line += 1;
                self.col = 1;
                return .{ .type = .NEWLINE, .value = "\n", .line = self.line - 1, .col = start_col };
            },
            '#' => {
                // Comment - consume until newline
                while (self.pos < self.input.len and self.input[self.pos] != '\n') {
                    self.advance();
                }
                return .{ .type = .COMMENT, .value = self.input[start..self.pos], .line = self.line, .col = start_col };
            },
            '"' => {
                // String literal
                self.advance(); // skip opening quote
                const str_start = self.pos;
                while (self.pos < self.input.len and self.input[self.pos] != '"') {
                    self.advance();
                }
                const str_end = self.pos;
                if (self.pos < self.input.len) self.advance(); // skip closing quote
                return .{ .type = .STRING, .value = self.input[str_start..str_end], .line = self.line, .col = start_col };
            },
            else => {
                // Number
                if (c >= '0' and c <= '9') {
                    while (self.pos < self.input.len and
                        ((self.input[self.pos] >= '0' and self.input[self.pos] <= '9') or
                        self.input[self.pos] == '.'))
                    {
                        self.advance();
                    }
                    return .{ .type = .NUMBER, .value = self.input[start..self.pos], .line = self.line, .col = start_col };
                }

                // Identifier (including Coptic characters)
                if (isIdentStart(c)) {
                    while (self.pos < self.input.len and isIdentChar(self.input[self.pos])) {
                        self.advance();
                    }
                    return .{ .type = .IDENT, .value = self.input[start..self.pos], .line = self.line, .col = start_col };
                }

                // Unknown - skip
                self.advance();
                return self.nextToken();
            },
        }
    }

    fn advance(self: *Self) void {
        if (self.pos < self.input.len) {
            self.pos += 1;
            self.col += 1;
        }
    }

    fn skipWhitespace(self: *Self) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ' ' or c == '\t' or c == '\r') {
                self.advance();
            } else {
                break;
            }
        }
    }

    fn isIdentStart(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            c == '_' or
            c >= 0x80; // UTF-8 continuation (Coptic)
    }

    fn isIdentChar(c: u8) bool {
        return isIdentStart(c) or (c >= '0' and c <= '9');
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Parser = struct {
    lexer: Lexer,
    current: Token,
    allocator: std.mem.Allocator,
    bytes_parsed: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        var lexer = Lexer.init(input);
        return .{
            .lexer = lexer,
            .current = lexer.nextToken(),
            .allocator = allocator,
            .bytes_parsed = 0,
        };
    }

    pub fn parse(self: *Self) !Document {
        var doc = Document.init(self.allocator);

        while (self.current.type != .EOF) {
            if (self.current.type == .NEWLINE or self.current.type == .COMMENT) {
                self.advance();
                continue;
            }

            if (self.current.type == .IDENT) {
                const key = self.current.value;
                self.advance();

                if (self.current.type == .COLON) {
                    self.advance();
                    self.skipNewlines();

                    const value = try self.parseValue();
                    try doc.root.entries.append(.{ .key = key, .value = value });
                }
            } else {
                self.advance();
            }
        }

        self.bytes_parsed = self.lexer.pos;
        return doc;
    }

    fn parseValue(self: *Self) !ValueNode {
        switch (self.current.type) {
            .STRING => {
                const val = self.current.value;
                self.advance();
                return .{ .string = val };
            },
            .NUMBER => {
                const val = std.fmt.parseFloat(f64, self.current.value) catch 0;
                self.advance();
                return .{ .number = val };
            },
            .IDENT => {
                const val = self.current.value;
                self.advance();
                // Check for boolean
                if (std.mem.eql(u8, val, "true")) return .{ .boolean = true };
                if (std.mem.eql(u8, val, "false")) return .{ .boolean = false };
                if (std.mem.eql(u8, val, "null")) return .{ .null_val = {} };
                return .{ .string = val };
            },
            .LBRACKET => {
                return try self.parseArray();
            },
            .LBRACE => {
                return try self.parseInlineMap();
            },
            else => {
                return .{ .null_val = {} };
            },
        }
    }

    fn parseArray(self: *Self) std.mem.Allocator.Error!ValueNode {
        self.advance(); // skip [
        var arr = try self.allocator.create(ArrayNode);
        arr.* = ArrayNode.init(self.allocator);

        while (self.current.type != .RBRACKET and self.current.type != .EOF) {
            self.skipNewlines();
            if (self.current.type == .RBRACKET) break;

            const item = try self.parseScalar();
            try arr.items.append(item);

            if (self.current.type == .COMMA) {
                self.advance();
            }
            self.skipNewlines();
        }

        if (self.current.type == .RBRACKET) self.advance();
        return .{ .array = arr };
    }

    fn parseInlineMap(self: *Self) std.mem.Allocator.Error!ValueNode {
        self.advance(); // skip {
        var map = try self.allocator.create(MapNode);
        map.* = MapNode.init(self.allocator);

        while (self.current.type != .RBRACE and self.current.type != .EOF) {
            self.skipNewlines();
            if (self.current.type == .RBRACE) break;

            if (self.current.type == .IDENT or self.current.type == .STRING) {
                const key = self.current.value;
                self.advance();

                if (self.current.type == .COLON) {
                    self.advance();
                    const value = try self.parseScalar();
                    try map.entries.append(.{ .key = key, .value = value });
                }
            } else {
                self.advance();
            }

            if (self.current.type == .COMMA) {
                self.advance();
            }
            self.skipNewlines();
        }

        if (self.current.type == .RBRACE) self.advance();
        return .{ .map = map };
    }

    fn parseScalar(self: *Self) std.mem.Allocator.Error!ValueNode {
        switch (self.current.type) {
            .STRING => {
                const val = self.current.value;
                self.advance();
                return .{ .string = val };
            },
            .NUMBER => {
                const val = std.fmt.parseFloat(f64, self.current.value) catch 0;
                self.advance();
                return .{ .number = val };
            },
            .IDENT => {
                const val = self.current.value;
                self.advance();
                if (std.mem.eql(u8, val, "true")) return .{ .boolean = true };
                if (std.mem.eql(u8, val, "false")) return .{ .boolean = false };
                if (std.mem.eql(u8, val, "null")) return .{ .null_val = {} };
                return .{ .string = val };
            },
            else => {
                return .{ .null_val = {} };
            },
        }
    }

    fn advance(self: *Self) void {
        self.current = self.lexer.nextToken();
    }

    fn skipNewlines(self: *Self) void {
        while (self.current.type == .NEWLINE or self.current.type == .COMMENT) {
            self.advance();
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmark(allocator: std.mem.Allocator, input: []const u8, iterations: u32) BenchmarkResult {
    var total_ns: u64 = 0;
    var total_bytes: usize = 0;

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();
        var parser = Parser.init(allocator, input);
        const doc = parser.parse() catch {
            continue;
        };
        _ = doc;
        const end = std.time.nanoTimestamp();

        total_ns += @intCast(end - start);
        total_bytes += parser.bytes_parsed;
    }

    const avg_ns = if (iterations > 0) total_ns / iterations else 0;
    const avg_bytes = if (iterations > 0) total_bytes / iterations else 0;
    const mb_per_sec = if (avg_ns > 0)
        @as(f64, @floatFromInt(avg_bytes)) / @as(f64, @floatFromInt(avg_ns)) * 1000.0
    else
        0;

    return .{
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .bytes_parsed = avg_bytes,
        .mb_per_sec = mb_per_sec,
    };
}

pub const BenchmarkResult = struct {
    iterations: u32,
    total_ns: u64,
    avg_ns: u64,
    bytes_parsed: usize,
    mb_per_sec: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden_identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}

test "lexer_simple" {
    var lexer = Lexer.init("name: \"test\"");

    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.IDENT, t1.type);
    try std.testing.expectEqualStrings("name", t1.value);

    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.COLON, t2.type);

    const t3 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.STRING, t3.type);
    try std.testing.expectEqualStrings("test", t3.value);
}

test "parser_simple_map" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const input = "name: \"test\"\nversion: \"1.0\"";

    var parser = Parser.init(allocator, input);
    const doc = try parser.parse();

    try std.testing.expectEqual(@as(usize, 2), doc.root.entries.items.len);
    try std.testing.expectEqualStrings("name", doc.root.entries.items[0].key);
}

test "parser_nested" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const input = "config: {host: \"localhost\", port: 8080}";

    var parser = Parser.init(allocator, input);
    const doc = try parser.parse();

    try std.testing.expectEqual(@as(usize, 1), doc.root.entries.items.len);
}

test "parser_array" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const input = "items: [1, 2, 3]";

    var parser = Parser.init(allocator, input);
    const doc = try parser.parse();

    try std.testing.expectEqual(@as(usize, 1), doc.root.entries.items.len);
}

test "lexer_coptic" {
    var lexer = Lexer.init("ⲛⲁⲙⲉ: \"ⲧⲉⲥⲧ\"");

    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.IDENT, t1.type);
    // Coptic characters are multi-byte UTF-8
    try std.testing.expect(t1.value.len > 0);
}
