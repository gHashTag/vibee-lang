// ═══════════════════════════════════════════════════════════════
// PARSER 999 - Full parser for Language 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Token types
pub const TokenType = enum {
    // Literals
    trit_true, trit_false, trit_unknown,
    integer, float, string,
    // Keywords (Coptic)
    kw_func, kw_struct, kw_if, kw_const, kw_return,
    kw_loop, kw_import, kw_var, kw_self,
    // Symbols
    lparen, rparen, lbrace, rbrace, lbracket, rbracket,
    comma, colon, semicolon, arrow, dot,
    // Operators
    plus, minus, star, slash, percent,
    eq, neq, lt, gt, lte, gte,
    and_op, or_op, not_op,
    assign,
    // Other
    identifier, comment, eof, invalid,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
};

// Lexer
pub const Lexer = struct {
    source: []const u8,
    pos: usize = 0,
    line: u32 = 1,

    pub fn init(source: []const u8) Lexer {
        return .{ .source = source };
    }

    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();
        if (self.pos >= self.source.len) return self.makeToken(.eof, "");

        const c = self.source[self.pos];
        
        // Comments
        if (c == '/' and self.peek(1) == '/') return self.scanComment();
        
        // Strings
        if (c == '"') return self.scanString();
        
        // Numbers
        if (std.ascii.isDigit(c)) return self.scanNumber();
        
        // Identifiers and keywords
        if (std.ascii.isAlphabetic(c) or c > 127) return self.scanIdentifier();
        
        // Single char tokens
        self.pos += 1;
        return switch (c) {
            '(' => self.makeToken(.lparen, "("),
            ')' => self.makeToken(.rparen, ")"),
            '{' => self.makeToken(.lbrace, "{"),
            '}' => self.makeToken(.rbrace, "}"),
            '[' => self.makeToken(.lbracket, "["),
            ']' => self.makeToken(.rbracket, "]"),
            ',' => self.makeToken(.comma, ","),
            ':' => self.makeToken(.colon, ":"),
            ';' => self.makeToken(.semicolon, ";"),
            '.' => self.makeToken(.dot, "."),
            '+' => self.makeToken(.plus, "+"),
            '-' => if (self.match('>')) self.makeToken(.arrow, "->") else self.makeToken(.minus, "-"),
            '*' => self.makeToken(.star, "*"),
            '/' => self.makeToken(.slash, "/"),
            '%' => self.makeToken(.percent, "%"),
            '=' => if (self.match('=')) self.makeToken(.eq, "==") else self.makeToken(.assign, "="),
            '!' => if (self.match('=')) self.makeToken(.neq, "!=") else self.makeToken(.not_op, "!"),
            '<' => if (self.match('=')) self.makeToken(.lte, "<=") else self.makeToken(.lt, "<"),
            '>' => if (self.match('=')) self.makeToken(.gte, ">=") else self.makeToken(.gt, ">"),
            '&' => if (self.match('&')) self.makeToken(.and_op, "&&") else self.makeToken(.invalid, "&"),
            '|' => if (self.match('|')) self.makeToken(.or_op, "||") else self.makeToken(.invalid, "|"),
            else => self.makeToken(.invalid, &[_]u8{c}),
        };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len) {
            switch (self.source[self.pos]) {
                ' ', '\t', '\r' => self.pos += 1,
                '\n' => { self.pos += 1; self.line += 1; },
                else => break,
            }
        }
    }

    fn peek(self: *Lexer, offset: usize) u8 {
        const idx = self.pos + offset;
        return if (idx < self.source.len) self.source[idx] else 0;
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.pos < self.source.len and self.source[self.pos] == expected) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    fn scanComment(self: *Lexer) Token {
        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] != '\n') self.pos += 1;
        return self.makeToken(.comment, self.source[start..self.pos]);
    }

    fn scanString(self: *Lexer) Token {
        self.pos += 1; // skip opening "
        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] != '"') self.pos += 1;
        const lexeme = self.source[start..self.pos];
        if (self.pos < self.source.len) self.pos += 1; // skip closing "
        return self.makeToken(.string, lexeme);
    }

    fn scanNumber(self: *Lexer) Token {
        const start = self.pos;
        var is_float = false;
        while (self.pos < self.source.len and (std.ascii.isDigit(self.source[self.pos]) or self.source[self.pos] == '.')) {
            if (self.source[self.pos] == '.') is_float = true;
            self.pos += 1;
        }
        return self.makeToken(if (is_float) .float else .integer, self.source[start..self.pos]);
    }

    fn scanIdentifier(self: *Lexer) Token {
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_' or c > 127) {
                self.pos += 1;
            } else break;
        }
        const lexeme = self.source[start..self.pos];
        const tt = self.identifierType(lexeme);
        return self.makeToken(tt, lexeme);
    }

    fn identifierType(self: *Lexer, lexeme: []const u8) TokenType {
        _ = self;
        // Ternary literals
        if (std.mem.eql(u8, lexeme, "△")) return .trit_true;
        if (std.mem.eql(u8, lexeme, "▽")) return .trit_false;
        if (std.mem.eql(u8, lexeme, "○")) return .trit_unknown;
        // Coptic keywords
        if (std.mem.eql(u8, lexeme, "Ⲫ")) return .kw_func;
        if (std.mem.eql(u8, lexeme, "Ⲏ")) return .kw_struct;
        if (std.mem.eql(u8, lexeme, "Ⲉ")) return .kw_if;
        if (std.mem.eql(u8, lexeme, "Ⲕ")) return .kw_const;
        if (std.mem.eql(u8, lexeme, "Ⲣ")) return .kw_return;
        if (std.mem.eql(u8, lexeme, "Ⲝ")) return .kw_loop;
        if (std.mem.eql(u8, lexeme, "Ⲯ")) return .kw_import;
        if (std.mem.eql(u8, lexeme, "Ⲃ")) return .kw_var;
        if (std.mem.eql(u8, lexeme, "Ⲥ")) return .kw_self;
        return .identifier;
    }

    fn makeToken(self: *Lexer, tt: TokenType, lexeme: []const u8) Token {
        return .{ .type = tt, .lexeme = lexeme, .line = self.line };
    }
};

// Tests
test "lexer ternary" {
    var lex = Lexer.init("△ ○ ▽");
    try std.testing.expectEqual(TokenType.trit_true, lex.nextToken().type);
    try std.testing.expectEqual(TokenType.trit_unknown, lex.nextToken().type);
    try std.testing.expectEqual(TokenType.trit_false, lex.nextToken().type);
}

test "lexer keywords" {
    var lex = Lexer.init("Ⲫ Ⲏ Ⲉ Ⲕ Ⲣ");
    try std.testing.expectEqual(TokenType.kw_func, lex.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_struct, lex.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_if, lex.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_const, lex.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_return, lex.nextToken().type);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("999 Parser v1.0\n");
}
