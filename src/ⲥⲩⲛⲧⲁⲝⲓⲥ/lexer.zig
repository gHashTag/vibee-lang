// ============================================================================
// VIBEEC LEXER
// Tokenizer for VIBEE language code format
// ============================================================================

const std = @import("std");

// ============================================================================
// TOKEN TYPES
// ============================================================================

pub const TokenType = enum {
    // Literals
    Integer,
    Float,
    String,
    Char,
    
    // Identifiers and keywords
    Identifier,
    
    // Keywords
    Fn,
    Let,
    Var,
    Const,
    If,
    Else,
    For,
    While,
    In,
    Return,
    True,
    False,
    None,
    Some,
    Test,
    Assert,
    Type,
    Struct,
    Enum,
    Match,
    Case,
    Import,
    Pub,
    As,
    
    // Operators
    Plus,           // +
    Minus,          // -
    Star,           // *
    Slash,          // /
    Percent,        // %
    Ampersand,      // &
    Pipe,           // |
    Caret,          // ^
    Tilde,          // ~
    Bang,           // !
    Equal,          // =
    Less,           // <
    Greater,        // >
    
    // Compound operators
    PlusEqual,      // +=
    MinusEqual,     // -=
    StarEqual,      // *=
    SlashEqual,     // /=
    PercentEqual,   // %=
    AmpEqual,       // &=
    PipeEqual,      // |=
    CaretEqual,     // ^=
    EqualEqual,     // ==
    BangEqual,      // !=
    LessEqual,      // <=
    GreaterEqual,   // >=
    AmpAmp,         // &&
    PipePipe,       // ||
    LessLess,       // <<
    GreaterGreater, // >>
    Arrow,          // ->
    FatArrow,       // =>
    DotDot,         // ..
    DotDotEqual,    // ..=
    
    // Delimiters
    LeftParen,      // (
    RightParen,     // )
    LeftBrace,      // {
    RightBrace,     // }
    LeftBracket,    // [
    RightBracket,   // ]
    Comma,          // ,
    Dot,            // .
    Colon,          // :
    Semicolon,      // ;
    Question,       // ?
    At,             // @
    Hash,           // #
    
    // Special
    Newline,
    Comment,
    DocComment,
    Eof,
    Error,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
    column: u32,
    
    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Token({s}, \"{s}\", {d}:{d})", .{
            @tagName(self.type),
            self.lexeme,
            self.line,
            self.column,
        });
    }
};

// ============================================================================
// LEXER
// ============================================================================

pub const Lexer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: u32,
    column: u32,
    line_start: usize,
    
    pub fn init(source: []const u8) Lexer {
        return Lexer{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
            .column = 1,
            .line_start = 0,
        };
    }
    
    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();
        self.start = self.current;
        
        if (self.isAtEnd()) {
            return self.makeToken(.Eof);
        }
        
        const c = self.advance();
        
        // Identifiers and keywords
        if (isAlpha(c)) {
            return self.identifier();
        }
        
        // Numbers
        if (isDigit(c)) {
            return self.number();
        }
        
        // Operators and delimiters
        return switch (c) {
            '(' => self.makeToken(.LeftParen),
            ')' => self.makeToken(.RightParen),
            '{' => self.makeToken(.LeftBrace),
            '}' => self.makeToken(.RightBrace),
            '[' => self.makeToken(.LeftBracket),
            ']' => self.makeToken(.RightBracket),
            ',' => self.makeToken(.Comma),
            ';' => self.makeToken(.Semicolon),
            ':' => self.makeToken(.Colon),
            '?' => self.makeToken(.Question),
            '@' => self.makeToken(.At),
            '#' => self.makeToken(.Hash),
            '~' => self.makeToken(.Tilde),
            
            '+' => if (self.match('=')) self.makeToken(.PlusEqual) else self.makeToken(.Plus),
            '*' => if (self.match('=')) self.makeToken(.StarEqual) else self.makeToken(.Star),
            '%' => if (self.match('=')) self.makeToken(.PercentEqual) else self.makeToken(.Percent),
            '^' => if (self.match('=')) self.makeToken(.CaretEqual) else self.makeToken(.Caret),
            '!' => if (self.match('=')) self.makeToken(.BangEqual) else self.makeToken(.Bang),
            
            '-' => blk: {
                if (self.match('=')) break :blk self.makeToken(.MinusEqual);
                if (self.match('>')) break :blk self.makeToken(.Arrow);
                break :blk self.makeToken(.Minus);
            },
            
            '=' => blk: {
                if (self.match('=')) break :blk self.makeToken(.EqualEqual);
                if (self.match('>')) break :blk self.makeToken(.FatArrow);
                break :blk self.makeToken(.Equal);
            },
            
            '<' => blk: {
                if (self.match('=')) break :blk self.makeToken(.LessEqual);
                if (self.match('<')) break :blk self.makeToken(.LessLess);
                break :blk self.makeToken(.Less);
            },
            
            '>' => blk: {
                if (self.match('=')) break :blk self.makeToken(.GreaterEqual);
                if (self.match('>')) break :blk self.makeToken(.GreaterGreater);
                break :blk self.makeToken(.Greater);
            },
            
            '&' => blk: {
                if (self.match('=')) break :blk self.makeToken(.AmpEqual);
                if (self.match('&')) break :blk self.makeToken(.AmpAmp);
                break :blk self.makeToken(.Ampersand);
            },
            
            '|' => blk: {
                if (self.match('=')) break :blk self.makeToken(.PipeEqual);
                if (self.match('|')) break :blk self.makeToken(.PipePipe);
                break :blk self.makeToken(.Pipe);
            },
            
            '.' => blk: {
                if (self.match('.')) {
                    if (self.match('=')) break :blk self.makeToken(.DotDotEqual);
                    break :blk self.makeToken(.DotDot);
                }
                break :blk self.makeToken(.Dot);
            },
            
            '/' => blk: {
                if (self.match('/')) {
                    // Comment
                    if (self.match('/')) {
                        // Doc comment
                        return self.docComment();
                    }
                    return self.comment();
                }
                if (self.match('=')) break :blk self.makeToken(.SlashEqual);
                break :blk self.makeToken(.Slash);
            },
            
            '"' => self.string(),
            '\'' => self.char(),
            
            '\n' => blk: {
                self.line += 1;
                self.line_start = self.current;
                self.column = 1;
                break :blk self.makeToken(.Newline);
            },
            
            else => self.errorToken("Unexpected character"),
        };
    }
    
    /// Tokenize entire source into array
    pub fn tokenize(self: *Lexer, allocator: std.mem.Allocator) ![]Token {
        var tokens = std.ArrayList(Token).init(allocator);
        
        while (true) {
            const token = self.nextToken();
            try tokens.append(token);
            
            if (token.type == .Eof or token.type == .Error) {
                break;
            }
        }
        
        return tokens.toOwnedSlice();
    }
    
    // ========================================================================
    // HELPERS
    // ========================================================================
    
    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }
    
    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        self.column += 1;
        return c;
    }
    
    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }
    
    fn peekNext(self: *Lexer) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }
    
    fn match(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        self.column += 1;
        return true;
    }
    
    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\t', '\r' => {
                    _ = self.advance();
                },
                else => return,
            }
        }
    }
    
    fn makeToken(self: *Lexer, token_type: TokenType) Token {
        const col = if (self.start >= self.line_start) 
            self.start - self.line_start + 1 
        else 
            1;
        return Token{
            .type = token_type,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = @intCast(col),
        };
    }
    
    fn errorToken(self: *Lexer, message: []const u8) Token {
        return Token{
            .type = .Error,
            .lexeme = message,
            .line = self.line,
            .column = self.column,
        };
    }
    
    // ========================================================================
    // TOKEN SCANNERS
    // ========================================================================
    
    fn identifier(self: *Lexer) Token {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        
        return self.makeToken(self.identifierType());
    }
    
    fn identifierType(self: *Lexer) TokenType {
        const text = self.source[self.start..self.current];
        
        // Check keywords
        const keywords = std.StaticStringMap(TokenType).initComptime(.{
            .{ "fn", .Fn },
            .{ "let", .Let },
            .{ "var", .Var },
            .{ "const", .Const },
            .{ "if", .If },
            .{ "else", .Else },
            .{ "for", .For },
            .{ "while", .While },
            .{ "in", .In },
            .{ "return", .Return },
            .{ "true", .True },
            .{ "false", .False },
            .{ "None", .None },
            .{ "Some", .Some },
            .{ "test", .Test },
            .{ "assert", .Assert },
            .{ "type", .Type },
            .{ "struct", .Struct },
            .{ "enum", .Enum },
            .{ "match", .Match },
            .{ "case", .Case },
            .{ "import", .Import },
            .{ "pub", .Pub },
            .{ "as", .As },
        });
        
        return keywords.get(text) orelse .Identifier;
    }
    
    fn number(self: *Lexer) Token {
        // Integer part
        while (isDigit(self.peek())) {
            _ = self.advance();
        }
        
        // Check for float
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance(); // consume '.'
            
            while (isDigit(self.peek())) {
                _ = self.advance();
            }
            
            // Scientific notation
            if (self.peek() == 'e' or self.peek() == 'E') {
                _ = self.advance();
                if (self.peek() == '+' or self.peek() == '-') {
                    _ = self.advance();
                }
                while (isDigit(self.peek())) {
                    _ = self.advance();
                }
            }
            
            return self.makeToken(.Float);
        }
        
        // Check for hex, binary, octal
        if (self.current - self.start == 1 and self.source[self.start] == '0') {
            const next = self.peek();
            if (next == 'x' or next == 'X') {
                _ = self.advance();
                while (isHexDigit(self.peek())) {
                    _ = self.advance();
                }
            } else if (next == 'b' or next == 'B') {
                _ = self.advance();
                while (self.peek() == '0' or self.peek() == '1') {
                    _ = self.advance();
                }
            } else if (next == 'o' or next == 'O') {
                _ = self.advance();
                while (self.peek() >= '0' and self.peek() <= '7') {
                    _ = self.advance();
                }
            }
        }
        
        return self.makeToken(.Integer);
    }
    
    fn string(self: *Lexer) Token {
        while (!self.isAtEnd() and self.peek() != '"') {
            if (self.peek() == '\n') {
                self.line += 1;
                self.line_start = self.current + 1;
            }
            if (self.peek() == '\\' and !self.isAtEnd()) {
                _ = self.advance(); // skip escape char
            }
            _ = self.advance();
        }
        
        if (self.isAtEnd()) {
            return self.errorToken("Unterminated string");
        }
        
        _ = self.advance(); // closing quote
        return self.makeToken(.String);
    }
    
    fn char(self: *Lexer) Token {
        if (self.peek() == '\\') {
            _ = self.advance(); // escape
        }
        if (!self.isAtEnd()) {
            _ = self.advance(); // char
        }
        
        if (self.peek() != '\'') {
            return self.errorToken("Unterminated character literal");
        }
        
        _ = self.advance(); // closing quote
        return self.makeToken(.Char);
    }
    
    fn comment(self: *Lexer) Token {
        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }
        return self.makeToken(.Comment);
    }
    
    fn docComment(self: *Lexer) Token {
        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }
        return self.makeToken(.DocComment);
    }
};

// ============================================================================
// CHARACTER HELPERS
// ============================================================================

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

fn isHexDigit(c: u8) bool {
    return isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

// ============================================================================
// TESTS
// ============================================================================

test "lexer basic tokens" {
    var lexer = Lexer.init("fn main() { }");
    
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Fn, t1.type);
    
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Identifier, t2.type);
    try std.testing.expectEqualStrings("main", t2.lexeme);
    
    const t3 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.LeftParen, t3.type);
    
    const t4 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.RightParen, t4.type);
    
    const t5 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.LeftBrace, t5.type);
    
    const t6 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.RightBrace, t6.type);
}

test "lexer numbers" {
    var lexer = Lexer.init("42 3.14 0xFF 0b1010");
    
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Integer, t1.type);
    try std.testing.expectEqualStrings("42", t1.lexeme);
    
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Float, t2.type);
    try std.testing.expectEqualStrings("3.14", t2.lexeme);
    
    const t3 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Integer, t3.type);
    try std.testing.expectEqualStrings("0xFF", t3.lexeme);
    
    const t4 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Integer, t4.type);
    try std.testing.expectEqualStrings("0b1010", t4.lexeme);
}

test "lexer strings" {
    var lexer = Lexer.init("\"hello world\" \"escape\\n\"");
    
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.String, t1.type);
    try std.testing.expectEqualStrings("\"hello world\"", t1.lexeme);
    
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.String, t2.type);
}

test "lexer operators" {
    var lexer = Lexer.init("+ - * / == != <= >= && || -> =>");
    
    try std.testing.expectEqual(TokenType.Plus, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Minus, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Star, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Slash, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.EqualEqual, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.BangEqual, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.LessEqual, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.GreaterEqual, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.AmpAmp, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.PipePipe, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Arrow, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.FatArrow, lexer.nextToken().type);
}

test "lexer keywords" {
    var lexer = Lexer.init("fn let var const if else for while return true false");
    
    try std.testing.expectEqual(TokenType.Fn, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Let, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Var, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Const, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.If, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Else, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.For, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.While, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Return, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.True, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.False, lexer.nextToken().type);
}

test "lexer comments" {
    var lexer = Lexer.init("// comment\n/// doc comment\nfn");
    
    const t1 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Comment, t1.type);
    
    _ = lexer.nextToken(); // newline
    
    const t2 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.DocComment, t2.type);
    
    _ = lexer.nextToken(); // newline
    
    const t3 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.Fn, t3.type);
}

test "lexer function signature" {
    var lexer = Lexer.init("fn abs(x: Float) -> Float");
    
    try std.testing.expectEqual(TokenType.Fn, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Identifier, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.LeftParen, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Identifier, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Colon, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Identifier, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.RightParen, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Arrow, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.Identifier, lexer.nextToken().type);
}

test "lexer tokenize all" {
    var lexer = Lexer.init("let x = 42");
    const tokens = try lexer.tokenize(std.testing.allocator);
    defer std.testing.allocator.free(tokens);
    
    try std.testing.expect(tokens.len >= 4);
    try std.testing.expectEqual(TokenType.Let, tokens[0].type);
    try std.testing.expectEqual(TokenType.Identifier, tokens[1].type);
    try std.testing.expectEqual(TokenType.Equal, tokens[2].type);
    try std.testing.expectEqual(TokenType.Integer, tokens[3].type);
}
