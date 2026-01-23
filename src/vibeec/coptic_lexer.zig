//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Coptic Lexer - Real Implementation
//! Поддержка 27 коптских символов (U+2C80-U+2CB4)
//! Тритовые литералы: △ (+1), ○ (0), ▽ (-1)
//! φ² + 1/φ² = 3

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;

// Coptic Unicode range
pub const COPTIC_START: u21 = 0x2C80;
pub const COPTIC_END: u21 = 0x2CB4;

// Trit symbols
pub const TRIT_TRUE: u21 = 0x25B3; // △
pub const TRIT_UNKNOWN: u21 = 0x25CB; // ○
pub const TRIT_FALSE: u21 = 0x25BD; // ▽

pub const TokenKind = enum(u8) {
    eof,
    invalid,
    int_literal,
    float_literal,
    string_literal,
    hex_literal,      // 0xFF
    binary_literal,   // 0b1010
    ternary_literal,  // 0t120 (balanced ternary)
    identifier,
    coptic_identifier,
    trit_true,
    trit_unknown,
    trit_false,
    kw_const,
    kw_var,
    kw_let,
    kw_func,
    kw_return,
    kw_if,
    kw_else,
    kw_match,
    kw_while,
    kw_for,
    kw_in,
    kw_is,
    kw_break,
    kw_continue,
    kw_phi,
    kw_trinity,
    kw_true,
    kw_false,
    kw_nil,
    kw_some,
    kw_none,
    kw_ok,
    kw_err,
    kw_and,
    kw_or,
    kw_not,
    op_plus,
    op_minus,
    op_star,
    op_slash,
    op_percent,       // %
    // Ternary operators (balanced ternary arithmetic)
    op_plus_t,        // +t (TRYTE_ADD)
    op_minus_t,       // -t (TRYTE_SUB)
    op_star_t,        // *t (TRYTE_MUL)
    op_lt_t,          // <t (TRYTE_LT)
    op_eqeq_t,        // ==t (TRYTE_EQ)
    op_eq,
    op_eqeq,
    op_fat_arrow,     // =>
    op_neq,           // !=
    op_lt,            // <
    op_gt,            // >
    op_compose,       // >> (function composition)
    op_lte,           // <=
    op_gte,           // >=
    op_and,           // &&
    op_or,            // ||
    op_bitor,         // | (single pipe for OR patterns)
    op_pipe,          // |>
    op_range,         // .. (range pattern)
    op_nullish,       // ??
    op_optional_chain, // ?.
    op_not,           // !
    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,         // [
    rbracket,         // ]
    semicolon,
    colon,
    comma,
    dot,              // .
    dot_dot_dot,      // ...
    question,         // ?
    newline,
    comment,          // // or /* */
};

pub const Token = struct {
    kind: TokenKind,
    start: u32,
    len: u16,
    line: u32,
    column: u16,

    pub fn lexeme(self: Token, source: []const u8) []const u8 {
        return source[self.start..][0..self.len];
    }
};

pub const Lexer = struct {
    source: []const u8,
    pos: u32,
    line: u32,
    column: u16,

    pub fn init(source: []const u8) Lexer {
        return .{ .source = source, .pos = 0, .line = 1, .column = 1 };
    }

    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();
        if (self.pos >= self.source.len) {
            return self.makeToken(.eof, 0);
        }

        const start = self.pos;
        const start_col = self.column;
        const c = self.source[self.pos];

        // Check for UTF-8 multi-byte (Coptic/Trit)
        if (c >= 0x80) {
            return self.scanUtf8Token(start, start_col);
        }

        // Single char tokens
        switch (c) {
            '\n' => { self.advance(); self.line += 1; self.column = 1; return self.makeTokenAt(.newline, start, 1, start_col); },
            '+' => {
                self.advance();
                // Check for +t (ternary add)
                if (self.pos < self.source.len and self.source[self.pos] == 't') {
                    self.advance();
                    return self.makeTokenAt(.op_plus_t, start, 2, start_col);
                }
                return self.makeTokenAt(.op_plus, start, 1, start_col);
            },
            '-' => {
                self.advance();
                // Check for -t (ternary sub)
                if (self.pos < self.source.len and self.source[self.pos] == 't') {
                    self.advance();
                    return self.makeTokenAt(.op_minus_t, start, 2, start_col);
                }
                return self.makeTokenAt(.op_minus, start, 1, start_col);
            },
            '*' => {
                self.advance();
                // Check for *t (ternary mul)
                if (self.pos < self.source.len and self.source[self.pos] == 't') {
                    self.advance();
                    return self.makeTokenAt(.op_star_t, start, 2, start_col);
                }
                return self.makeTokenAt(.op_star, start, 1, start_col);
            },
            '/' => {
                self.advance();
                if (self.pos < self.source.len) {
                    if (self.source[self.pos] == '/') {
                        return self.scanLineComment(start, start_col);
                    }
                    if (self.source[self.pos] == '*') {
                        return self.scanBlockComment(start, start_col);
                    }
                }
                return self.makeTokenAt(.op_slash, start, 1, start_col);
            },
            '%' => { self.advance(); return self.makeTokenAt(.op_percent, start, 1, start_col); },
            '(' => { self.advance(); return self.makeTokenAt(.lparen, start, 1, start_col); },
            ')' => { self.advance(); return self.makeTokenAt(.rparen, start, 1, start_col); },
            '{' => { self.advance(); return self.makeTokenAt(.lbrace, start, 1, start_col); },
            '}' => { self.advance(); return self.makeTokenAt(.rbrace, start, 1, start_col); },
            '[' => { self.advance(); return self.makeTokenAt(.lbracket, start, 1, start_col); },
            ']' => { self.advance(); return self.makeTokenAt(.rbracket, start, 1, start_col); },
            ';' => { self.advance(); return self.makeTokenAt(.semicolon, start, 1, start_col); },
            ':' => { self.advance(); return self.makeTokenAt(.colon, start, 1, start_col); },
            ',' => { self.advance(); return self.makeTokenAt(.comma, start, 1, start_col); },
            '.' => {
                self.advance();
                // Check for ... (spread/rest operator)
                if (self.pos + 1 < self.source.len and self.source[self.pos] == '.' and self.source[self.pos + 1] == '.') {
                    self.advance();
                    self.advance();
                    return self.makeTokenAt(.dot_dot_dot, start, 3, start_col);
                }
                // Check for .. (range pattern)
                if (self.pos < self.source.len and self.source[self.pos] == '.') {
                    self.advance();
                    return self.makeTokenAt(.op_range, start, 2, start_col);
                }
                return self.makeTokenAt(.dot, start, 1, start_col);
            },
            '?' => {
                self.advance();
                if (self.pos < self.source.len and self.source[self.pos] == '?') {
                    self.advance();
                    return self.makeTokenAt(.op_nullish, start, 2, start_col);
                }
                if (self.pos < self.source.len and self.source[self.pos] == '.') {
                    self.advance();
                    return self.makeTokenAt(.op_optional_chain, start, 2, start_col);
                }
                return self.makeTokenAt(.question, start, 1, start_col);
            },
            '=' => {
                self.advance();
                if (self.pos < self.source.len) {
                    if (self.source[self.pos] == '=') {
                        self.advance();
                        // Check for ==t (ternary equality)
                        if (self.pos < self.source.len and self.source[self.pos] == 't') {
                            self.advance();
                            return self.makeTokenAt(.op_eqeq_t, start, 3, start_col);
                        }
                        return self.makeTokenAt(.op_eqeq, start, 2, start_col);
                    }
                    if (self.source[self.pos] == '>') {
                        self.advance();
                        return self.makeTokenAt(.op_fat_arrow, start, 2, start_col);
                    }
                }
                return self.makeTokenAt(.op_eq, start, 1, start_col);
            },
            '!' => {
                self.advance();
                if (self.pos < self.source.len and self.source[self.pos] == '=') {
                    self.advance();
                    return self.makeTokenAt(.op_neq, start, 2, start_col);
                }
                return self.makeTokenAt(.op_not, start, 1, start_col);
            },
            '<' => {
                self.advance();
                if (self.pos < self.source.len) {
                    if (self.source[self.pos] == '=') {
                        self.advance();
                        return self.makeTokenAt(.op_lte, start, 2, start_col);
                    }
                    // Check for <t (ternary less than)
                    if (self.source[self.pos] == 't') {
                        self.advance();
                        return self.makeTokenAt(.op_lt_t, start, 2, start_col);
                    }
                }
                return self.makeTokenAt(.op_lt, start, 1, start_col);
            },
            '>' => {
                self.advance();
                if (self.pos < self.source.len) {
                    if (self.source[self.pos] == '=') {
                        self.advance();
                        return self.makeTokenAt(.op_gte, start, 2, start_col);
                    }
                    if (self.source[self.pos] == '>') {
                        self.advance();
                        return self.makeTokenAt(.op_compose, start, 2, start_col);
                    }
                }
                return self.makeTokenAt(.op_gt, start, 1, start_col);
            },
            '&' => {
                self.advance();
                if (self.pos < self.source.len and self.source[self.pos] == '&') {
                    self.advance();
                    return self.makeTokenAt(.op_and, start, 2, start_col);
                }
                return self.makeTokenAt(.invalid, start, 1, start_col);
            },
            '|' => {
                self.advance();
                if (self.pos < self.source.len) {
                    if (self.source[self.pos] == '|') {
                        self.advance();
                        return self.makeTokenAt(.op_or, start, 2, start_col);
                    }
                    if (self.source[self.pos] == '>') {
                        self.advance();
                        return self.makeTokenAt(.op_pipe, start, 2, start_col);
                    }
                }
                // Single | for OR patterns in match
                return self.makeTokenAt(.op_bitor, start, 1, start_col);
            },
            '"' => return self.scanString(start, start_col),
            '0'...'9' => return self.scanNumber(start, start_col),
            'a'...'z', 'A'...'Z', '_' => return self.scanIdentifier(start, start_col),
            else => { self.advance(); return self.makeTokenAt(.invalid, start, 1, start_col); },
        }
    }

    fn scanUtf8Token(self: *Lexer, start: u32, start_col: u16) Token {
        const decoded = self.decodeUtf8();
        if (decoded.codepoint) |cp| {
            // Trit symbols
            if (cp == TRIT_TRUE) return self.makeTokenAt(.trit_true, start, decoded.len, start_col);
            if (cp == TRIT_UNKNOWN) return self.makeTokenAt(.trit_unknown, start, decoded.len, start_col);
            if (cp == TRIT_FALSE) return self.makeTokenAt(.trit_false, start, decoded.len, start_col);
            // Coptic range
            if (cp >= COPTIC_START and cp <= COPTIC_END) {
                return self.makeTokenAt(.coptic_identifier, start, decoded.len, start_col);
            }
        }
        self.pos += decoded.len;
        self.column += 1;
        return self.makeTokenAt(.invalid, start, decoded.len, start_col);
    }

    fn decodeUtf8(self: *Lexer) struct { codepoint: ?u21, len: u8 } {
        if (self.pos >= self.source.len) return .{ .codepoint = null, .len = 0 };
        const b0 = self.source[self.pos];
        if (b0 < 0x80) {
            self.pos += 1; self.column += 1;
            return .{ .codepoint = b0, .len = 1 };
        }
        if (b0 & 0xE0 == 0xC0 and self.pos + 1 < self.source.len) {
            const cp = (@as(u21, b0 & 0x1F) << 6) | (self.source[self.pos + 1] & 0x3F);
            self.pos += 2; self.column += 1;
            return .{ .codepoint = cp, .len = 2 };
        }
        if (b0 & 0xF0 == 0xE0 and self.pos + 2 < self.source.len) {
            const cp = (@as(u21, b0 & 0x0F) << 12) | (@as(u21, self.source[self.pos + 1] & 0x3F) << 6) | (self.source[self.pos + 2] & 0x3F);
            self.pos += 3; self.column += 1;
            return .{ .codepoint = cp, .len = 3 };
        }
        self.pos += 1; self.column += 1;
        return .{ .codepoint = null, .len = 1 };
    }

    fn scanNumber(self: *Lexer, start: u32, start_col: u16) Token {
        // Check for 0x, 0b, 0t prefixes
        if (self.source[self.pos] == '0' and self.pos + 1 < self.source.len) {
            const next = self.source[self.pos + 1];
            if (next == 'x' or next == 'X') {
                self.advance(); self.advance(); // skip 0x
                return self.scanHexNumber(start, start_col);
            }
            if (next == 'b' or next == 'B') {
                self.advance(); self.advance(); // skip 0b
                return self.scanBinaryNumber(start, start_col);
            }
            if (next == 't' or next == 'T') {
                self.advance(); self.advance(); // skip 0t
                return self.scanTernaryNumber(start, start_col);
            }
        }
        
        var is_float = false;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c >= '0' and c <= '9') { self.advance(); }
            else if (c == '_') { self.advance(); } // allow 1_000_000
            else if (c == '.' and !is_float) {
                // Check if this is a range operator (..) - don't consume the dot
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '.') {
                    break; // Stop here, let the main lexer handle ..
                }
                is_float = true; 
                self.advance(); 
            }
            else break;
        }
        const len: u16 = @intCast(self.pos - start);
        return self.makeTokenAt(if (is_float) .float_literal else .int_literal, start, len, start_col);
    }
    
    fn scanHexNumber(self: *Lexer, start: u32, start_col: u16) Token {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if ((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F') or c == '_') {
                self.advance();
            } else break;
        }
        const len: u16 = @intCast(self.pos - start);
        return self.makeTokenAt(.hex_literal, start, len, start_col);
    }
    
    fn scanBinaryNumber(self: *Lexer, start: u32, start_col: u16) Token {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '0' or c == '1' or c == '_') {
                self.advance();
            } else break;
        }
        const len: u16 = @intCast(self.pos - start);
        return self.makeTokenAt(.binary_literal, start, len, start_col);
    }
    
    fn scanTernaryNumber(self: *Lexer, start: u32, start_col: u16) Token {
        // Balanced ternary: digits are 0, 1, 2 (or T, 0, 1 for -1, 0, +1)
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c >= '0' and c <= '2') { self.advance(); }
            else if (c == 'T' or c == 't') { self.advance(); } // T = -1 in balanced ternary
            else if (c == '_') { self.advance(); }
            else break;
        }
        const len: u16 = @intCast(self.pos - start);
        return self.makeTokenAt(.ternary_literal, start, len, start_col);
    }
    
    fn scanLineComment(self: *Lexer, start: u32, start_col: u16) Token {
        self.advance(); // skip second /
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.advance();
        }
        const len: u16 = @intCast(self.pos - start);
        return self.makeTokenAt(.comment, start, len, start_col);
    }
    
    fn scanBlockComment(self: *Lexer, start: u32, start_col: u16) Token {
        self.advance(); // skip *
        var depth: u32 = 1;
        while (self.pos + 1 < self.source.len and depth > 0) {
            if (self.source[self.pos] == '*' and self.source[self.pos + 1] == '/') {
                depth -= 1;
                self.advance(); self.advance();
            } else if (self.source[self.pos] == '/' and self.source[self.pos + 1] == '*') {
                depth += 1;
                self.advance(); self.advance();
            } else {
                if (self.source[self.pos] == '\n') {
                    self.line += 1;
                    self.column = 0;
                }
                self.advance();
            }
        }
        const len: u16 = @intCast(self.pos - start);
        return self.makeTokenAt(.comment, start, len, start_col);
    }

    fn scanString(self: *Lexer, start: u32, start_col: u16) Token {
        self.advance(); // skip opening "
        while (self.pos < self.source.len and self.source[self.pos] != '"') {
            if (self.source[self.pos] == '\\' and self.pos + 1 < self.source.len) self.advance();
            self.advance();
        }
        if (self.pos < self.source.len) self.advance(); // skip closing "
        const len: u16 = @intCast(self.pos - start);
        return self.makeTokenAt(.string_literal, start, len, start_col);
    }

    fn scanIdentifier(self: *Lexer, start: u32, start_col: u16) Token {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_') {
                self.advance();
            } else break;
        }
        const len: u16 = @intCast(self.pos - start);
        const lex = self.source[start..][0..len];
        const kind = self.checkKeyword(lex);
        return self.makeTokenAt(kind, start, len, start_col);
    }

    fn checkKeyword(self: *Lexer, lex: []const u8) TokenKind {
        _ = self;
        if (std.mem.eql(u8, lex, "const")) return .kw_const;
        if (std.mem.eql(u8, lex, "var")) return .kw_var;
        if (std.mem.eql(u8, lex, "let")) return .kw_let;
        if (std.mem.eql(u8, lex, "func")) return .kw_func;
        if (std.mem.eql(u8, lex, "fn")) return .kw_func;
        if (std.mem.eql(u8, lex, "return")) return .kw_return;
        if (std.mem.eql(u8, lex, "if")) return .kw_if;
        if (std.mem.eql(u8, lex, "else")) return .kw_else;
        if (std.mem.eql(u8, lex, "match")) return .kw_match;
        if (std.mem.eql(u8, lex, "while")) return .kw_while;
        if (std.mem.eql(u8, lex, "for")) return .kw_for;
        if (std.mem.eql(u8, lex, "in")) return .kw_in;
        if (std.mem.eql(u8, lex, "is")) return .kw_is;
        if (std.mem.eql(u8, lex, "break")) return .kw_break;
        if (std.mem.eql(u8, lex, "continue")) return .kw_continue;
        if (std.mem.eql(u8, lex, "true")) return .kw_true;
        if (std.mem.eql(u8, lex, "false")) return .kw_false;
        if (std.mem.eql(u8, lex, "nil")) return .kw_nil;
        if (std.mem.eql(u8, lex, "Some")) return .kw_some;
        if (std.mem.eql(u8, lex, "None")) return .kw_none;
        if (std.mem.eql(u8, lex, "Ok")) return .kw_ok;
        if (std.mem.eql(u8, lex, "Err")) return .kw_err;
        if (std.mem.eql(u8, lex, "and")) return .kw_and;
        if (std.mem.eql(u8, lex, "or")) return .kw_or;
        if (std.mem.eql(u8, lex, "not")) return .kw_not;
        if (std.mem.eql(u8, lex, "if")) return .kw_if;
        if (std.mem.eql(u8, lex, "else")) return .kw_else;
        if (std.mem.eql(u8, lex, "phi")) return .kw_phi;
        if (std.mem.eql(u8, lex, "trinity")) return .kw_trinity;
        return .identifier;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t' or c == '\r') { self.advance(); }
            else break;
        }
    }

    fn advance(self: *Lexer) void {
        self.pos += 1;
        self.column += 1;
    }

    fn makeToken(self: *Lexer, kind: TokenKind, len: u16) Token {
        return .{ .kind = kind, .start = self.pos, .len = len, .line = self.line, .column = self.column };
    }

    fn makeTokenAt(self: *Lexer, kind: TokenKind, start: u32, len: u16, col: u16) Token {
        _ = self;
        return .{ .kind = kind, .start = start, .len = len, .line = 1, .column = col };
    }

    pub fn tokenize(source: []const u8, allocator: std.mem.Allocator) ![]Token {
        var lexer = Lexer.init(source);
        var tokens = std.ArrayList(Token).init(allocator);
        while (true) {
            const tok = lexer.nextToken();
            try tokens.append(tok);
            if (tok.kind == .eof) break;
        }
        return tokens.toOwnedSlice();
    }
};

// Coptic index (0-26)
pub fn copticToIndex(codepoint: u21) ?u8 {
    if (codepoint >= COPTIC_START and codepoint <= COPTIC_END) {
        return @intCast(codepoint - COPTIC_START);
    }
    return null;
}

pub fn indexToCoptic(index: u8) ?u21 {
    if (index < TRINITY) return COPTIC_START + index;
    return null;
}

// Tests
test "lexer basic tokens" {
    const source = "const x = 42";
    var lexer = Lexer.init(source);
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.kw_const, t1.kind);
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.identifier, t2.kind);
    const t3 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.op_eq, t3.kind);
    const t4 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.int_literal, t4.kind);
}

test "lexer trit symbols" {
    const source = "△ ○ ▽";
    var lexer = Lexer.init(source);
    try std.testing.expectEqual(TokenKind.trit_true, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.trit_unknown, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.trit_false, lexer.nextToken().kind);
}

test "lexer coptic char" {
    const source = "ⲁ";
    var lexer = Lexer.init(source);
    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.coptic_identifier, tok.kind);
}

test "coptic index" {
    try std.testing.expectEqual(@as(?u8, 0), copticToIndex(0x2C80));
    try std.testing.expectEqual(@as(?u8, 26), copticToIndex(0x2C9A));
}

test "phi constant" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}

test "lexer string literal" {
    const source = "\"hello world\"";
    var lexer = Lexer.init(source);
    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.string_literal, tok.kind);
    try std.testing.expectEqualStrings("\"hello world\"", tok.lexeme(source));
}

test "lexer string with escape" {
    const source = "\"hello\\nworld\"";
    var lexer = Lexer.init(source);
    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.string_literal, tok.kind);
}

test "lexer line comment" {
    const source = "// this is a comment\n42";
    var lexer = Lexer.init(source);
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.comment, t1.kind);
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.newline, t2.kind);
    const t3 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.int_literal, t3.kind);
}

test "lexer block comment" {
    const source = "/* block */ 42";
    var lexer = Lexer.init(source);
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.comment, t1.kind);
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.int_literal, t2.kind);
}

test "lexer hex number" {
    const source = "0xFF 0x1A2B";
    var lexer = Lexer.init(source);
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.hex_literal, t1.kind);
    try std.testing.expectEqualStrings("0xFF", t1.lexeme(source));
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.hex_literal, t2.kind);
}

test "lexer binary number" {
    const source = "0b1010 0b1111_0000";
    var lexer = Lexer.init(source);
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.binary_literal, t1.kind);
    try std.testing.expectEqualStrings("0b1010", t1.lexeme(source));
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.binary_literal, t2.kind);
}

test "lexer ternary number" {
    const source = "0t120 0tT01";
    var lexer = Lexer.init(source);
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.ternary_literal, t1.kind);
    try std.testing.expectEqualStrings("0t120", t1.lexeme(source));
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.ternary_literal, t2.kind);
}

test "lexer comparison operators" {
    const source = "< > <= >= == !=";
    var lexer = Lexer.init(source);
    try std.testing.expectEqual(TokenKind.op_lt, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.op_gt, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.op_lte, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.op_gte, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.op_eqeq, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.op_neq, lexer.nextToken().kind);
}

test "lexer logical operators" {
    const source = "&& || !";
    var lexer = Lexer.init(source);
    try std.testing.expectEqual(TokenKind.op_and, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.op_or, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.op_not, lexer.nextToken().kind);
}

test "lexer keywords" {
    const source = "if else while for in break continue true false nil and or not";
    var lexer = Lexer.init(source);
    try std.testing.expectEqual(TokenKind.kw_if, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_else, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_while, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_for, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_in, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_break, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_continue, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_true, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_false, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_nil, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_and, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_or, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.kw_not, lexer.nextToken().kind);
}

test "lexer brackets" {
    const source = "[ ] . ?";
    var lexer = Lexer.init(source);
    try std.testing.expectEqual(TokenKind.lbracket, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.rbracket, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.dot, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.question, lexer.nextToken().kind);
}
