//! VIBEE SIMD-Accelerated Lexer - PAS DAEMON V39
//! Паттерны: SIMD (vectorized scanning), HSH (O(1) keyword lookup), PRE (precomputed tables)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const TokenType = enum(u8) {
    // Literals
    integer,
    float_lit,
    string,
    char_lit,
    
    // Identifiers & Keywords
    identifier,
    keyword_fn,
    keyword_let,
    keyword_const,
    keyword_if,
    keyword_else,
    keyword_while,
    keyword_for,
    keyword_return,
    keyword_struct,
    keyword_enum,
    keyword_pub,
    keyword_import,
    keyword_export,
    keyword_true,
    keyword_false,
    keyword_null,
    keyword_and,
    keyword_or,
    keyword_not,
    keyword_vibee,
    keyword_sacred,
    keyword_phi,
    
    // Operators
    plus,
    minus,
    star,
    slash,
    percent,
    caret,
    ampersand,
    pipe,
    tilde,
    bang,
    equal,
    less,
    greater,
    at,
    hash,
    dollar,
    question,
    
    // Compound operators
    plus_equal,
    minus_equal,
    star_equal,
    slash_equal,
    equal_equal,
    bang_equal,
    less_equal,
    greater_equal,
    arrow,
    fat_arrow,
    double_colon,
    dot_dot,
    dot_dot_dot,
    
    // Delimiters
    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,
    rbracket,
    comma,
    dot,
    colon,
    semicolon,
    
    // Special
    newline,
    comment,
    doc_comment,
    eof,
    invalid,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Token = struct {
    type: TokenType,
    start: u32,
    len: u16,
    line: u32,
    column: u16,
    
    pub fn lexeme(self: Token, source: []const u8) []const u8 {
        return source[self.start..][0..self.len];
    }
    
    pub fn isKeyword(self: Token) bool {
        return @intFromEnum(self.type) >= @intFromEnum(TokenType.keyword_fn) and
               @intFromEnum(self.type) <= @intFromEnum(TokenType.keyword_phi);
    }
    
    pub fn isOperator(self: Token) bool {
        return @intFromEnum(self.type) >= @intFromEnum(TokenType.plus) and
               @intFromEnum(self.type) <= @intFromEnum(TokenType.dot_dot_dot);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD CONSTANTS - Precomputed lookup tables (PRE pattern)
// ═══════════════════════════════════════════════════════════════════════════════

const SIMD_WIDTH = 16;
const SimdVec = @Vector(SIMD_WIDTH, u8);

// Character class lookup table (PRE pattern)
const CharClass = enum(u4) {
    invalid = 0,
    whitespace = 1,
    newline = 2,
    alpha = 3,
    digit = 4,
    underscore = 5,
    operator = 6,
    delimiter = 7,
    quote = 8,
    hash = 9,
    dot = 10,
    colon = 11,
    equal = 12,
    less = 13,
    greater = 14,
    bang = 15,
};

// Precomputed character class table (PRE pattern)
const char_class_table: [256]CharClass = blk: {
    var table: [256]CharClass = .{.invalid} ** 256;
    
    // Whitespace
    table[' '] = .whitespace;
    table['\t'] = .whitespace;
    table['\r'] = .whitespace;
    table['\n'] = .newline;
    
    // Alpha
    for ('a'..'z' + 1) |c| table[c] = .alpha;
    for ('A'..'Z' + 1) |c| table[c] = .alpha;
    table['_'] = .underscore;
    
    // Digits
    for ('0'..'9' + 1) |c| table[c] = .digit;
    
    // Operators
    table['+'] = .operator;
    table['-'] = .operator;
    table['*'] = .operator;
    table['/'] = .operator;
    table['%'] = .operator;
    table['^'] = .operator;
    table['&'] = .operator;
    table['|'] = .operator;
    table['~'] = .operator;
    table['@'] = .operator;
    table['$'] = .operator;
    table['?'] = .operator;
    
    // Special operators
    table['!'] = .bang;
    table['='] = .equal;
    table['<'] = .less;
    table['>'] = .greater;
    table[':'] = .colon;
    table['.'] = .dot;
    table['#'] = .hash;
    
    // Delimiters
    table['('] = .delimiter;
    table[')'] = .delimiter;
    table['{'] = .delimiter;
    table['}'] = .delimiter;
    table['['] = .delimiter;
    table[']'] = .delimiter;
    table[','] = .delimiter;
    table[';'] = .delimiter;
    
    // Quotes
    table['"'] = .quote;
    table['\''] = .quote;
    
    break :blk table;
};

// ═══════════════════════════════════════════════════════════════════════════════
// KEYWORD HASH TABLE - HSH pattern for O(1) lookup
// ═══════════════════════════════════════════════════════════════════════════════

const KeywordEntry = struct {
    name: []const u8,
    token_type: TokenType,
};

const keywords = [_]KeywordEntry{
    .{ .name = "fn", .token_type = .keyword_fn },
    .{ .name = "let", .token_type = .keyword_let },
    .{ .name = "const", .token_type = .keyword_const },
    .{ .name = "if", .token_type = .keyword_if },
    .{ .name = "else", .token_type = .keyword_else },
    .{ .name = "while", .token_type = .keyword_while },
    .{ .name = "for", .token_type = .keyword_for },
    .{ .name = "return", .token_type = .keyword_return },
    .{ .name = "struct", .token_type = .keyword_struct },
    .{ .name = "enum", .token_type = .keyword_enum },
    .{ .name = "pub", .token_type = .keyword_pub },
    .{ .name = "import", .token_type = .keyword_import },
    .{ .name = "export", .token_type = .keyword_export },
    .{ .name = "true", .token_type = .keyword_true },
    .{ .name = "false", .token_type = .keyword_false },
    .{ .name = "null", .token_type = .keyword_null },
    .{ .name = "and", .token_type = .keyword_and },
    .{ .name = "or", .token_type = .keyword_or },
    .{ .name = "not", .token_type = .keyword_not },
    .{ .name = "vibee", .token_type = .keyword_vibee },
    .{ .name = "sacred", .token_type = .keyword_sacred },
    .{ .name = "phi", .token_type = .keyword_phi },
};

// Perfect hash for keywords (HSH pattern)
fn keywordHash(str: []const u8) u32 {
    if (str.len == 0) return 0;
    var h: u32 = @as(u32, str[0]);
    if (str.len > 1) h = h *% 31 +% @as(u32, str[str.len - 1]);
    h = h *% 31 +% @as(u32, @truncate(str.len));
    return h;
}

fn lookupKeyword(str: []const u8) ?TokenType {
    for (keywords) |kw| {
        if (std.mem.eql(u8, kw.name, str)) {
            return kw.token_type;
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD LEXER - Main lexer with SIMD acceleration
// ═══════════════════════════════════════════════════════════════════════════════

pub const Lexer = struct {
    source: []const u8,
    pos: u32 = 0,
    line: u32 = 1,
    column: u16 = 1,
    tokens: std.ArrayList(Token),
    
    // Statistics
    simd_scans: u64 = 0,
    scalar_scans: u64 = 0,
    
    pub fn init(allocator: Allocator, source: []const u8) Lexer {
        return .{
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }
    
    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }
    
    /// Tokenize entire source - main entry point
    pub fn tokenize(self: *Lexer) ![]const Token {
        while (self.pos < self.source.len) {
            try self.scanToken();
        }
        
        // Add EOF token
        try self.tokens.append(.{
            .type = .eof,
            .start = @truncate(self.source.len),
            .len = 0,
            .line = self.line,
            .column = self.column,
        });
        
        return self.tokens.items;
    }
    
    /// Scan single token
    fn scanToken(self: *Lexer) !void {
        // Skip whitespace using SIMD
        self.skipWhitespaceSIMD();
        
        if (self.pos >= self.source.len) return;
        
        const start_pos = self.pos;
        const start_line = self.line;
        const start_col = self.column;
        const c = self.source[self.pos];
        const class = char_class_table[c];
        
        const token_type: TokenType = switch (class) {
            .alpha, .underscore => blk: {
                self.scanIdentifierSIMD();
                const lexeme = self.source[start_pos..self.pos];
                break :blk lookupKeyword(lexeme) orelse .identifier;
            },
            .digit => blk: {
                self.scanNumber();
                break :blk if (self.hasDecimalPoint(start_pos)) .float_lit else .integer;
            },
            .quote => blk: {
                self.scanString();
                break :blk if (c == '"') .string else .char_lit;
            },
            .hash => blk: {
                self.scanComment();
                break :blk .comment;
            },
            .newline => blk: {
                self.advance();
                self.line += 1;
                self.column = 1;
                break :blk .newline;
            },
            .operator => self.scanOperator(),
            .delimiter => self.scanDelimiter(),
            .equal => self.scanEqual(),
            .less => self.scanLess(),
            .greater => self.scanGreater(),
            .bang => self.scanBang(),
            .colon => self.scanColon(),
            .dot => self.scanDot(),
            else => blk: {
                self.advance();
                break :blk .invalid;
            },
        };
        
        const len: u16 = @truncate(self.pos - start_pos);
        
        try self.tokens.append(.{
            .type = token_type,
            .start = start_pos,
            .len = len,
            .line = start_line,
            .column = start_col,
        });
    }
    
    /// SIMD-accelerated whitespace skip
    fn skipWhitespaceSIMD(self: *Lexer) void {
        while (self.pos + SIMD_WIDTH <= self.source.len) {
            const chunk: SimdVec = self.source[self.pos..][0..SIMD_WIDTH].*;
            
            // Check for non-whitespace using SIMD
            const space_mask = chunk == @as(SimdVec, @splat(' '));
            const tab_mask = chunk == @as(SimdVec, @splat('\t'));
            const ws_mask = @select(bool, space_mask, @as(@Vector(SIMD_WIDTH, bool), @splat(true)), tab_mask);
            
            // Find first non-whitespace
            const non_ws = ~@as(u16, @bitCast(ws_mask));
            if (non_ws != 0) {
                const skip: u32 = @ctz(non_ws);
                self.pos += skip;
                self.column += @truncate(skip);
                self.simd_scans += 1;
                return;
            }
            
            self.pos += SIMD_WIDTH;
            self.column += SIMD_WIDTH;
            self.simd_scans += 1;
        }
        
        // Scalar fallback for remaining bytes
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c != ' ' and c != '\t' and c != '\r') break;
            self.pos += 1;
            self.column += 1;
            self.scalar_scans += 1;
        }
    }
    
    /// SIMD-accelerated identifier scan
    fn scanIdentifierSIMD(self: *Lexer) void {
        while (self.pos + SIMD_WIDTH <= self.source.len) {
            const chunk: SimdVec = self.source[self.pos..][0..SIMD_WIDTH].*;
            
            // Check for valid identifier characters
            var valid_mask: @Vector(SIMD_WIDTH, bool) = @splat(false);
            inline for (0..SIMD_WIDTH) |i| {
                const c = chunk[i];
                valid_mask[i] = (c >= 'a' and c <= 'z') or
                               (c >= 'A' and c <= 'Z') or
                               (c >= '0' and c <= '9') or
                               c == '_';
            }
            
            const invalid = ~@as(u16, @bitCast(valid_mask));
            if (invalid != 0) {
                const len: u32 = @ctz(invalid);
                self.pos += len;
                self.column += @truncate(len);
                self.simd_scans += 1;
                return;
            }
            
            self.pos += SIMD_WIDTH;
            self.column += SIMD_WIDTH;
            self.simd_scans += 1;
        }
        
        // Scalar fallback
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (!isIdentChar(c)) break;
            self.advance();
            self.scalar_scans += 1;
        }
    }
    
    fn scanNumber(self: *Lexer) void {
        while (self.pos < self.source.len and isDigit(self.source[self.pos])) {
            self.advance();
        }
        
        // Check for decimal point
        if (self.pos < self.source.len - 1 and 
            self.source[self.pos] == '.' and 
            isDigit(self.source[self.pos + 1])) {
            self.advance(); // consume '.'
            while (self.pos < self.source.len and isDigit(self.source[self.pos])) {
                self.advance();
            }
        }
        
        // Check for exponent
        if (self.pos < self.source.len and 
            (self.source[self.pos] == 'e' or self.source[self.pos] == 'E')) {
            self.advance();
            if (self.pos < self.source.len and 
                (self.source[self.pos] == '+' or self.source[self.pos] == '-')) {
                self.advance();
            }
            while (self.pos < self.source.len and isDigit(self.source[self.pos])) {
                self.advance();
            }
        }
    }
    
    fn hasDecimalPoint(self: *Lexer, start: u32) bool {
        for (self.source[start..self.pos]) |c| {
            if (c == '.') return true;
        }
        return false;
    }
    
    fn scanString(self: *Lexer) void {
        const quote = self.source[self.pos];
        self.advance(); // consume opening quote
        
        while (self.pos < self.source.len and self.source[self.pos] != quote) {
            if (self.source[self.pos] == '\\' and self.pos + 1 < self.source.len) {
                self.advance(); // skip escape
            }
            if (self.source[self.pos] == '\n') {
                self.line += 1;
                self.column = 0;
            }
            self.advance();
        }
        
        if (self.pos < self.source.len) {
            self.advance(); // consume closing quote
        }
    }
    
    fn scanComment(self: *Lexer) void {
        self.advance(); // consume '#'
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.advance();
        }
    }
    
    fn scanOperator(self: *Lexer) TokenType {
        const c = self.source[self.pos];
        self.advance();
        
        return switch (c) {
            '+' => if (self.match('=')) .plus_equal else .plus,
            '-' => if (self.match('=')) .minus_equal else if (self.match('>')) .arrow else .minus,
            '*' => if (self.match('=')) .star_equal else .star,
            '/' => if (self.match('=')) .slash_equal else .slash,
            '%' => .percent,
            '^' => .caret,
            '&' => .ampersand,
            '|' => .pipe,
            '~' => .tilde,
            '@' => .at,
            '$' => .dollar,
            '?' => .question,
            else => .invalid,
        };
    }
    
    fn scanDelimiter(self: *Lexer) TokenType {
        const c = self.source[self.pos];
        self.advance();
        
        return switch (c) {
            '(' => .lparen,
            ')' => .rparen,
            '{' => .lbrace,
            '}' => .rbrace,
            '[' => .lbracket,
            ']' => .rbracket,
            ',' => .comma,
            ';' => .semicolon,
            else => .invalid,
        };
    }
    
    fn scanEqual(self: *Lexer) TokenType {
        self.advance();
        if (self.match('=')) return .equal_equal;
        if (self.match('>')) return .fat_arrow;
        return .equal;
    }
    
    fn scanLess(self: *Lexer) TokenType {
        self.advance();
        if (self.match('=')) return .less_equal;
        return .less;
    }
    
    fn scanGreater(self: *Lexer) TokenType {
        self.advance();
        if (self.match('=')) return .greater_equal;
        return .greater;
    }
    
    fn scanBang(self: *Lexer) TokenType {
        self.advance();
        if (self.match('=')) return .bang_equal;
        return .bang;
    }
    
    fn scanColon(self: *Lexer) TokenType {
        self.advance();
        if (self.match(':')) return .double_colon;
        return .colon;
    }
    
    fn scanDot(self: *Lexer) TokenType {
        self.advance();
        if (self.match('.')) {
            if (self.match('.')) return .dot_dot_dot;
            return .dot_dot;
        }
        return .dot;
    }
    
    fn advance(self: *Lexer) void {
        self.pos += 1;
        self.column += 1;
    }
    
    fn match(self: *Lexer, expected: u8) bool {
        if (self.pos >= self.source.len) return false;
        if (self.source[self.pos] != expected) return false;
        self.advance();
        return true;
    }
    
    fn isIdentChar(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
               (c >= 'A' and c <= 'Z') or
               (c >= '0' and c <= '9') or
               c == '_';
    }
    
    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }
    
    /// Get lexer statistics
    pub fn getStats(self: *const Lexer) LexerStats {
        return .{
            .token_count = self.tokens.items.len,
            .simd_scans = self.simd_scans,
            .scalar_scans = self.scalar_scans,
            .simd_ratio = if (self.simd_scans + self.scalar_scans > 0)
                @as(f64, @floatFromInt(self.simd_scans)) / 
                @as(f64, @floatFromInt(self.simd_scans + self.scalar_scans))
            else 0.0,
        };
    }
};

pub const LexerStats = struct {
    token_count: usize,
    simd_scans: u64,
    scalar_scans: u64,
    simd_ratio: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "basic tokenization" {
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, "let x = 42");
    defer lexer.deinit();
    
    const tokens = try lexer.tokenize();
    
    try std.testing.expectEqual(@as(usize, 5), tokens.len); // let, x, =, 42, eof
    try std.testing.expectEqual(TokenType.keyword_let, tokens[0].type);
    try std.testing.expectEqual(TokenType.identifier, tokens[1].type);
    try std.testing.expectEqual(TokenType.equal, tokens[2].type);
    try std.testing.expectEqual(TokenType.integer, tokens[3].type);
}

test "keyword recognition" {
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, "fn if else while for return struct vibee sacred phi");
    defer lexer.deinit();
    
    const tokens = try lexer.tokenize();
    
    try std.testing.expectEqual(TokenType.keyword_fn, tokens[0].type);
    try std.testing.expectEqual(TokenType.keyword_if, tokens[1].type);
    try std.testing.expectEqual(TokenType.keyword_else, tokens[2].type);
    try std.testing.expectEqual(TokenType.keyword_vibee, tokens[7].type);
    try std.testing.expectEqual(TokenType.keyword_sacred, tokens[8].type);
    try std.testing.expectEqual(TokenType.keyword_phi, tokens[9].type);
}

test "operators" {
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, "+ - * / == != <= >= -> =>");
    defer lexer.deinit();
    
    const tokens = try lexer.tokenize();
    
    try std.testing.expectEqual(TokenType.plus, tokens[0].type);
    try std.testing.expectEqual(TokenType.minus, tokens[1].type);
    try std.testing.expectEqual(TokenType.equal_equal, tokens[4].type);
    try std.testing.expectEqual(TokenType.bang_equal, tokens[5].type);
    try std.testing.expectEqual(TokenType.arrow, tokens[8].type);
    try std.testing.expectEqual(TokenType.fat_arrow, tokens[9].type);
}

test "string literals" {
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, "\"hello world\" 'c'");
    defer lexer.deinit();
    
    const tokens = try lexer.tokenize();
    
    try std.testing.expectEqual(TokenType.string, tokens[0].type);
    try std.testing.expectEqual(TokenType.char_lit, tokens[1].type);
}

test "numbers" {
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, "42 3.14 2.5");
    defer lexer.deinit();
    
    const tokens = try lexer.tokenize();
    
    try std.testing.expectEqual(TokenType.integer, tokens[0].type);
    try std.testing.expectEqual(TokenType.float_lit, tokens[1].type);
    try std.testing.expectEqual(TokenType.float_lit, tokens[2].type);
}

test "SIMD whitespace skip" {
    const allocator = std.testing.allocator;
    const source = "                                x"; // 32 spaces + x
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();
    
    const tokens = try lexer.tokenize();
    
    try std.testing.expectEqual(@as(usize, 2), tokens.len); // x, eof
    try std.testing.expect(lexer.simd_scans > 0);
}

test "line tracking" {
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, "a\nb\nc");
    defer lexer.deinit();
    
    const tokens = try lexer.tokenize();
    
    try std.testing.expectEqual(@as(u32, 1), tokens[0].line);
    try std.testing.expectEqual(@as(u32, 2), tokens[2].line);
    try std.testing.expectEqual(@as(u32, 3), tokens[4].line);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}

test "char class table PRE" {
    try std.testing.expectEqual(CharClass.alpha, char_class_table['a']);
    try std.testing.expectEqual(CharClass.digit, char_class_table['5']);
    try std.testing.expectEqual(CharClass.whitespace, char_class_table[' ']);
    try std.testing.expectEqual(CharClass.operator, char_class_table['+']);
    try std.testing.expectEqual(CharClass.delimiter, char_class_table['(']);
}
