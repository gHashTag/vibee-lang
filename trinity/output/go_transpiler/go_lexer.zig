// ═══════════════════════════════════════════════════════════════════════════════
// GO LEXER - Generated from ⲅⲟ_ⲗⲉⲝⲉⲣ.tri by VIBEE Trinity Compiler
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated from .tri specification
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const MAX_TOKENS: usize = 65536;
pub const MAX_LINE_LEN: usize = 4096;

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoTokenType = enum(u8) {
    // Keywords
    PACKAGE,
    IMPORT,
    FUNC,
    TYPE,
    STRUCT,
    INTERFACE,
    CONST,
    VAR,
    IF,
    ELSE,
    FOR,
    RANGE,
    RETURN,
    GO,
    CHAN,
    SELECT,
    DEFER,
    MAP,
    BREAK,
    CONTINUE,
    SWITCH,
    CASE,
    DEFAULT,
    TRUE,
    FALSE,
    NIL,

    // Literals
    IDENT,
    STRING,
    NUMBER,

    // Operators and punctuation
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    LBRACKET,
    RBRACKET,
    COMMA,
    DOT,
    COLON,
    SEMICOLON,
    ASSIGN,
    DECLARE_ASSIGN,
    ARROW,
    ELLIPSIS,
    PLUS,
    MINUS,
    STAR,
    SLASH,
    PERCENT,
    AMPERSAND,
    PIPE,
    CARET,
    AND,
    OR,
    NOT,
    EQ,
    NE,
    LT,
    GT,
    LE,
    GE,

    EOF,
    INVALID,

    pub fn toString(self: GoTokenType) []const u8 {
        return @tagName(self);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN STRUCT
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoToken = struct {
    type: GoTokenType,
    lexeme: []const u8,
    line: u32,
    column: u32,

    pub fn init(token_type: GoTokenType, lexeme: []const u8, line: u32, column: u32) GoToken {
        return GoToken{
            .type = token_type,
            .lexeme = lexeme,
            .line = line,
            .column = column,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GO LEXER
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoLexer = struct {
    source: []const u8,
    position: usize,
    line: u32,
    column: u32,
    tokens: ArrayList(GoToken),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, source: []const u8) Self {
        return Self{
            .source = source,
            .position = 0,
            .line = 1,
            .column = 1,
            .tokens = ArrayList(GoToken).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    /// Tokenize the entire source
    pub fn tokenize(self: *Self) ![]GoToken {
        while (!self.isAtEnd()) {
            try self.scanToken();
        }

        try self.tokens.append(GoToken.init(.EOF, "", self.line, self.column));
        return self.tokens.items;
    }

    fn scanToken(self: *Self) !void {
        self.skipWhitespace();
        if (self.isAtEnd()) return;

        const start = self.position;
        const start_column = self.column;
        const c = self.advance();

        // Single character tokens
        const token_type: ?GoTokenType = switch (c) {
            '(' => .LPAREN,
            ')' => .RPAREN,
            '{' => .LBRACE,
            '}' => .RBRACE,
            '[' => .LBRACKET,
            ']' => .RBRACKET,
            ',' => .COMMA,
            ';' => .SEMICOLON,
            '+' => .PLUS,
            '-' => .MINUS,
            '*' => .STAR,
            '%' => .PERCENT,
            '^' => .CARET,
            else => null,
        };

        if (token_type) |tt| {
            try self.tokens.append(GoToken.init(tt, self.source[start..self.position], self.line, start_column));
            return;
        }

        // Multi-character tokens
        switch (c) {
            '/' => {
                if (self.match('/')) {
                    // Line comment
                    while (!self.isAtEnd() and self.peek() != '\n') {
                        _ = self.advance();
                    }
                } else if (self.match('*')) {
                    // Block comment
                    while (!self.isAtEnd()) {
                        if (self.peek() == '*' and self.peekNext() == '/') {
                            _ = self.advance();
                            _ = self.advance();
                            break;
                        }
                        if (self.advance() == '\n') {
                            self.line += 1;
                            self.column = 1;
                        }
                    }
                } else {
                    try self.tokens.append(GoToken.init(.SLASH, "/", self.line, start_column));
                }
            },
            ':' => {
                if (self.match('=')) {
                    try self.tokens.append(GoToken.init(.DECLARE_ASSIGN, ":=", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.COLON, ":", self.line, start_column));
                }
            },
            '=' => {
                if (self.match('=')) {
                    try self.tokens.append(GoToken.init(.EQ, "==", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.ASSIGN, "=", self.line, start_column));
                }
            },
            '!' => {
                if (self.match('=')) {
                    try self.tokens.append(GoToken.init(.NE, "!=", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.NOT, "!", self.line, start_column));
                }
            },
            '<' => {
                if (self.match('=')) {
                    try self.tokens.append(GoToken.init(.LE, "<=", self.line, start_column));
                } else if (self.match('-')) {
                    try self.tokens.append(GoToken.init(.ARROW, "<-", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.LT, "<", self.line, start_column));
                }
            },
            '>' => {
                if (self.match('=')) {
                    try self.tokens.append(GoToken.init(.GE, ">=", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.GT, ">", self.line, start_column));
                }
            },
            '&' => {
                if (self.match('&')) {
                    try self.tokens.append(GoToken.init(.AND, "&&", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.AMPERSAND, "&", self.line, start_column));
                }
            },
            '|' => {
                if (self.match('|')) {
                    try self.tokens.append(GoToken.init(.OR, "||", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.PIPE, "|", self.line, start_column));
                }
            },
            '.' => {
                if (self.match('.') and self.match('.')) {
                    try self.tokens.append(GoToken.init(.ELLIPSIS, "...", self.line, start_column));
                } else {
                    try self.tokens.append(GoToken.init(.DOT, ".", self.line, start_column));
                }
            },
            '"' => try self.readString(start_column),
            '`' => try self.readRawString(start_column),
            else => {
                if (isDigit(c)) {
                    try self.readNumber(start, start_column);
                } else if (isAlpha(c)) {
                    try self.readIdentifier(start, start_column);
                } else {
                    try self.tokens.append(GoToken.init(.INVALID, self.source[start..self.position], self.line, start_column));
                }
            },
        }
    }

    fn readString(self: *Self, start_column: u32) !void {
        const start = self.position;
        while (!self.isAtEnd() and self.peek() != '"') {
            if (self.peek() == '\\') {
                _ = self.advance(); // Skip escape char
            }
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            try self.tokens.append(GoToken.init(.INVALID, "unterminated string", self.line, start_column));
            return;
        }

        _ = self.advance(); // Closing "
        try self.tokens.append(GoToken.init(.STRING, self.source[start .. self.position - 1], self.line, start_column));
    }

    fn readRawString(self: *Self, start_column: u32) !void {
        const start = self.position;
        while (!self.isAtEnd() and self.peek() != '`') {
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            try self.tokens.append(GoToken.init(.INVALID, "unterminated raw string", self.line, start_column));
            return;
        }

        _ = self.advance(); // Closing `
        try self.tokens.append(GoToken.init(.STRING, self.source[start .. self.position - 1], self.line, start_column));
    }

    fn readNumber(self: *Self, start: usize, start_column: u32) !void {
        // Handle hex, octal, binary
        if (self.source[start] == '0' and !self.isAtEnd()) {
            const next = self.peek();
            if (next == 'x' or next == 'X') {
                _ = self.advance();
                while (!self.isAtEnd() and isHexDigit(self.peek())) {
                    _ = self.advance();
                }
                try self.tokens.append(GoToken.init(.NUMBER, self.source[start..self.position], self.line, start_column));
                return;
            }
        }

        while (!self.isAtEnd() and isDigit(self.peek())) {
            _ = self.advance();
        }

        // Decimal part
        if (!self.isAtEnd() and self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();
            while (!self.isAtEnd() and isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        // Exponent
        if (!self.isAtEnd() and (self.peek() == 'e' or self.peek() == 'E')) {
            _ = self.advance();
            if (!self.isAtEnd() and (self.peek() == '+' or self.peek() == '-')) {
                _ = self.advance();
            }
            while (!self.isAtEnd() and isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        try self.tokens.append(GoToken.init(.NUMBER, self.source[start..self.position], self.line, start_column));
    }

    fn readIdentifier(self: *Self, start: usize, start_column: u32) !void {
        while (!self.isAtEnd() and isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }

        const text = self.source[start..self.position];
        const token_type = getKeyword(text) orelse .IDENT;
        try self.tokens.append(GoToken.init(token_type, text, self.line, start_column));
    }

    fn skipWhitespace(self: *Self) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\r', '\t' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    self.column = 1;
                    _ = self.advance();
                },
                else => return,
            }
        }
    }

    fn isAtEnd(self: *Self) bool {
        return self.position >= self.source.len;
    }

    fn peek(self: *Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.position];
    }

    fn peekNext(self: *Self) u8 {
        if (self.position + 1 >= self.source.len) return 0;
        return self.source[self.position + 1];
    }

    fn advance(self: *Self) u8 {
        const c = self.source[self.position];
        self.position += 1;
        self.column += 1;
        return c;
    }

    fn match(self: *Self, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.position] != expected) return false;
        self.position += 1;
        self.column += 1;
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KEYWORD MAP
// ═══════════════════════════════════════════════════════════════════════════════

fn getKeyword(text: []const u8) ?GoTokenType {
    const keywords = std.StaticStringMap(GoTokenType).initComptime(.{
        .{ "package", .PACKAGE },
        .{ "import", .IMPORT },
        .{ "func", .FUNC },
        .{ "type", .TYPE },
        .{ "struct", .STRUCT },
        .{ "interface", .INTERFACE },
        .{ "const", .CONST },
        .{ "var", .VAR },
        .{ "if", .IF },
        .{ "else", .ELSE },
        .{ "for", .FOR },
        .{ "range", .RANGE },
        .{ "return", .RETURN },
        .{ "go", .GO },
        .{ "chan", .CHAN },
        .{ "select", .SELECT },
        .{ "defer", .DEFER },
        .{ "map", .MAP },
        .{ "break", .BREAK },
        .{ "continue", .CONTINUE },
        .{ "switch", .SWITCH },
        .{ "case", .CASE },
        .{ "default", .DEFAULT },
        .{ "true", .TRUE },
        .{ "false", .FALSE },
        .{ "nil", .NIL },
    });
    return keywords.get(text);
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isHexDigit(c: u8) bool {
    return isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}

test "tokenize package" {
    const allocator = std.testing.allocator;
    var lexer = GoLexer.init(allocator, "package main");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(@as(usize, 3), tokens.len);
    try std.testing.expectEqual(GoTokenType.PACKAGE, tokens[0].type);
    try std.testing.expectEqual(GoTokenType.IDENT, tokens[1].type);
    try std.testing.expectEqualStrings("main", tokens[1].lexeme);
    try std.testing.expectEqual(GoTokenType.EOF, tokens[2].type);
}

test "tokenize func" {
    const allocator = std.testing.allocator;
    var lexer = GoLexer.init(allocator, "func add(a, b int) int");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(GoTokenType.FUNC, tokens[0].type);
    try std.testing.expectEqual(GoTokenType.IDENT, tokens[1].type);
    try std.testing.expectEqualStrings("add", tokens[1].lexeme);
    try std.testing.expectEqual(GoTokenType.LPAREN, tokens[2].type);
}

test "tokenize struct" {
    const allocator = std.testing.allocator;
    var lexer = GoLexer.init(allocator, "type Point struct { X int }");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(GoTokenType.TYPE, tokens[0].type);
    try std.testing.expectEqual(GoTokenType.IDENT, tokens[1].type);
    try std.testing.expectEqual(GoTokenType.STRUCT, tokens[2].type);
    try std.testing.expectEqual(GoTokenType.LBRACE, tokens[3].type);
}

test "tokenize string" {
    const allocator = std.testing.allocator;
    var lexer = GoLexer.init(allocator, "\"hello world\"");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(GoTokenType.STRING, tokens[0].type);
    try std.testing.expectEqualStrings("hello world", tokens[0].lexeme);
}

test "tokenize number" {
    const allocator = std.testing.allocator;
    var lexer = GoLexer.init(allocator, "42 3.14 0x1F");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(GoTokenType.NUMBER, tokens[0].type);
    try std.testing.expectEqualStrings("42", tokens[0].lexeme);
    try std.testing.expectEqual(GoTokenType.NUMBER, tokens[1].type);
    try std.testing.expectEqualStrings("3.14", tokens[1].lexeme);
    try std.testing.expectEqual(GoTokenType.NUMBER, tokens[2].type);
    try std.testing.expectEqualStrings("0x1F", tokens[2].lexeme);
}

test "tokenize operators" {
    const allocator = std.testing.allocator;
    var lexer = GoLexer.init(allocator, ":= == != <= >=");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(GoTokenType.DECLARE_ASSIGN, tokens[0].type);
    try std.testing.expectEqual(GoTokenType.EQ, tokens[1].type);
    try std.testing.expectEqual(GoTokenType.NE, tokens[2].type);
    try std.testing.expectEqual(GoTokenType.LE, tokens[3].type);
    try std.testing.expectEqual(GoTokenType.GE, tokens[4].type);
}
