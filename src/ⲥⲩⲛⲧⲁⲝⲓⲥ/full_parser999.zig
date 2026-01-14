// ═══════════════════════════════════════════════════════════════
// FULL PARSER 999 - Complete parser with AST
// Implements: Balanced Ternary, Kleene Strong, Tekum arithmetic
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// BALANCED TERNARY (-1, 0, +1)
// ═══════════════════════════════════════════════════════════════

pub const Trit = enum(i8) {
    N = -1, // ▽ (negative/false)
    Z = 0,  // ○ (zero/unknown)
    P = 1,  // △ (positive/true)

    pub fn and_(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }
    pub fn or_(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }
    pub fn not(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }
    pub fn consensus(a: Trit, b: Trit) Trit {
        return if (a == b) a else .Z;
    }
};

// ═══════════════════════════════════════════════════════════════
// TEKUM NUMBER (27 trits)
// ═══════════════════════════════════════════════════════════════

pub const Tekum = struct {
    trits: [27]Trit,

    pub fn zero() Tekum {
        return .{ .trits = [_]Trit{.Z} ** 27 };
    }

    pub fn fromInt(n: i64) Tekum {
        var t = zero();
        var val = n;
        var i: usize = 0;
        while (val != 0 and i < 27) : (i += 1) {
            const rem = @mod(val + 1, 3) - 1;
            t.trits[i] = @enumFromInt(@as(i8, @intCast(rem)));
            val = @divTrunc(val - rem, 3);
        }
        return t;
    }

    pub fn toInt(self: Tekum) i64 {
        var result: i64 = 0;
        var power: i64 = 1;
        for (self.trits) |trit| {
            result += @intFromEnum(trit) * power;
            power *= 3;
        }
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════
// TOKEN TYPES
// ═══════════════════════════════════════════════════════════════

pub const TokenType = enum {
    // Ternary
    trit_p, trit_z, trit_n,
    // Literals
    integer, float, string,
    // Coptic keywords
    kw_func, kw_struct, kw_enum, kw_if, kw_else,
    kw_const, kw_var, kw_return, kw_loop, kw_import, kw_self,
    kw_test,
    // Symbols
    lparen, rparen, lbrace, rbrace, lbracket, rbracket,
    comma, colon, semicolon, arrow, dot, at,
    // Operators
    plus, minus, star, slash, percent,
    eq, neq, lt, gt, lte, gte,
    and_op, or_op, not_op, assign,
    // Other
    identifier, comment, newline, eof,
};

pub const Token = struct {
    type: TokenType,
    text: []const u8,
    line: u32,
};

// ═══════════════════════════════════════════════════════════════
// LEXER
// ═══════════════════════════════════════════════════════════════

pub const Lexer = struct {
    src: []const u8,
    pos: usize = 0,
    line: u32 = 1,

    pub fn next(self: *Lexer) Token {
        self.skipWs();
        if (self.pos >= self.src.len) return self.tok(.eof, "");

        const c = self.src[self.pos];

        // Comments
        if (c == '/' and self.peek(1) == '/') {
            const start = self.pos;
            while (self.pos < self.src.len and self.src[self.pos] != '\n') self.pos += 1;
            return self.tok(.comment, self.src[start..self.pos]);
        }

        // String
        if (c == '"') return self.scanStr();

        // Number
        if (std.ascii.isDigit(c)) return self.scanNum();

        // Identifier/keyword
        if (std.ascii.isAlphabetic(c) or c > 127 or c == '_') return self.scanId();

        // Single/double char
        self.pos += 1;
        return switch (c) {
            '(' => self.tok(.lparen, "("),
            ')' => self.tok(.rparen, ")"),
            '{' => self.tok(.lbrace, "{"),
            '}' => self.tok(.rbrace, "}"),
            '[' => self.tok(.lbracket, "["),
            ']' => self.tok(.rbracket, "]"),
            ',' => self.tok(.comma, ","),
            ':' => self.tok(.colon, ":"),
            ';' => self.tok(.semicolon, ";"),
            '.' => self.tok(.dot, "."),
            '@' => self.tok(.at, "@"),
            '+' => self.tok(.plus, "+"),
            '*' => self.tok(.star, "*"),
            '/' => self.tok(.slash, "/"),
            '%' => self.tok(.percent, "%"),
            '-' => if (self.match('>')) self.tok(.arrow, "->") else self.tok(.minus, "-"),
            '=' => if (self.match('=')) self.tok(.eq, "==") else self.tok(.assign, "="),
            '!' => if (self.match('=')) self.tok(.neq, "!=") else self.tok(.not_op, "!"),
            '<' => if (self.match('=')) self.tok(.lte, "<=") else self.tok(.lt, "<"),
            '>' => if (self.match('=')) self.tok(.gte, ">=") else self.tok(.gt, ">"),
            '&' => if (self.match('&')) self.tok(.and_op, "&&") else self.tok(.and_op, "&"),
            '|' => if (self.match('|')) self.tok(.or_op, "||") else self.tok(.or_op, "|"),
            '\n' => blk: { self.line += 1; break :blk self.tok(.newline, "\n"); },
            else => self.tok(.eof, ""),
        };
    }

    fn skipWs(self: *Lexer) void {
        while (self.pos < self.src.len) {
            switch (self.src[self.pos]) {
                ' ', '\t', '\r' => self.pos += 1,
                else => break,
            }
        }
    }

    fn peek(self: *Lexer, off: usize) u8 {
        const i = self.pos + off;
        return if (i < self.src.len) self.src[i] else 0;
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.pos < self.src.len and self.src[self.pos] == expected) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    fn scanStr(self: *Lexer) Token {
        self.pos += 1;
        const start = self.pos;
        while (self.pos < self.src.len and self.src[self.pos] != '"') self.pos += 1;
        const text = self.src[start..self.pos];
        if (self.pos < self.src.len) self.pos += 1;
        return self.tok(.string, text);
    }

    fn scanNum(self: *Lexer) Token {
        const start = self.pos;
        var is_float = false;
        while (self.pos < self.src.len) {
            const ch = self.src[self.pos];
            if (std.ascii.isDigit(ch)) {
                self.pos += 1;
            } else if (ch == '.' and !is_float) {
                is_float = true;
                self.pos += 1;
            } else break;
        }
        return self.tok(if (is_float) .float else .integer, self.src[start..self.pos]);
    }

    fn scanId(self: *Lexer) Token {
        const start = self.pos;
        while (self.pos < self.src.len) {
            const ch = self.src[self.pos];
            if (std.ascii.isAlphanumeric(ch) or ch == '_' or ch > 127) {
                self.pos += 1;
            } else break;
        }
        const text = self.src[start..self.pos];
        return self.tok(self.kwType(text), text);
    }

    fn kwType(self: *Lexer, t: []const u8) TokenType {
        _ = self;
        if (std.mem.eql(u8, t, "△")) return .trit_p;
        if (std.mem.eql(u8, t, "○")) return .trit_z;
        if (std.mem.eql(u8, t, "▽")) return .trit_n;
        if (std.mem.eql(u8, t, "Ⲫ") or std.mem.eql(u8, t, "◬")) return .kw_func;
        if (std.mem.eql(u8, t, "Ⲏ") or std.mem.eql(u8, t, "⬡")) return .kw_struct;
        if (std.mem.eql(u8, t, "⬢")) return .kw_enum;
        if (std.mem.eql(u8, t, "Ⲉ")) return .kw_if;
        if (std.mem.eql(u8, t, "Ⲕ") or std.mem.eql(u8, t, "◇")) return .kw_const;
        if (std.mem.eql(u8, t, "Ⲃ")) return .kw_var;
        if (std.mem.eql(u8, t, "Ⲣ")) return .kw_return;
        if (std.mem.eql(u8, t, "Ⲝ")) return .kw_loop;
        if (std.mem.eql(u8, t, "Ⲯ")) return .kw_import;
        if (std.mem.eql(u8, t, "Ⲥ")) return .kw_self;
        if (std.mem.eql(u8, t, "⊡")) return .kw_test;
        return .identifier;
    }

    fn tok(self: *Lexer, tt: TokenType, text: []const u8) Token {
        return .{ .type = tt, .text = text, .line = self.line };
    }
};

// ═══════════════════════════════════════════════════════════════
// AST NODES
// ═══════════════════════════════════════════════════════════════

pub const Expr = union(enum) {
    trit: Trit,
    int: i64,
    float: f64,
    str: []const u8,
    ident: []const u8,
    binary: struct { op: []const u8, left: *Expr, right: *Expr },
    unary: struct { op: []const u8, operand: *Expr },
    call: struct { callee: *Expr, args: []*Expr },
};

pub const Stmt = union(enum) {
    expr: *Expr,
    var_decl: struct { name: []const u8, value: ?*Expr, is_const: bool },
    func_def: struct { name: []const u8, params: [][]const u8, body: []Stmt },
    struct_def: struct { name: []const u8, fields: [][]const u8 },
    if_stmt: struct { cond: *Expr, then_body: []Stmt, else_body: ?[]Stmt },
    loop_stmt: struct { iter: []const u8, iterable: *Expr, body: []Stmt },
    return_stmt: ?*Expr,
    import_stmt: []const u8,
    test_def: struct { name: []const u8, body: []Stmt },
};

// ═══════════════════════════════════════════════════════════════
// PARSER
// ═══════════════════════════════════════════════════════════════

pub const Parser = struct {
    lexer: Lexer,
    current: Token,
    alloc: Allocator,

    pub fn init(src: []const u8, alloc: Allocator) Parser {
        var p = Parser{ .lexer = Lexer{ .src = src }, .current = undefined, .alloc = alloc };
        p.advance();
        return p;
    }

    fn advance(self: *Parser) void {
        self.current = self.lexer.next();
        while (self.current.type == .comment or self.current.type == .newline) {
            self.current = self.lexer.next();
        }
    }

    fn match(self: *Parser, tt: TokenType) bool {
        if (self.current.type == tt) {
            self.advance();
            return true;
        }
        return false;
    }

    pub fn parseExpr(self: *Parser) !*Expr {
        return self.parseOr();
    }

    fn parseOr(self: *Parser) !*Expr {
        var left = try self.parseAnd();
        while (self.current.type == .or_op) {
            self.advance();
            const right = try self.parseAnd();
            const node = try self.alloc.create(Expr);
            node.* = .{ .binary = .{ .op = "||", .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseAnd(self: *Parser) !*Expr {
        var left = try self.parseEquality();
        while (self.current.type == .and_op) {
            self.advance();
            const right = try self.parseEquality();
            const node = try self.alloc.create(Expr);
            node.* = .{ .binary = .{ .op = "&&", .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseEquality(self: *Parser) !*Expr {
        var left = try self.parseComparison();
        while (self.current.type == .eq or self.current.type == .neq) {
            const op = self.current.text;
            self.advance();
            const right = try self.parseComparison();
            const node = try self.alloc.create(Expr);
            node.* = .{ .binary = .{ .op = op, .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseComparison(self: *Parser) !*Expr {
        var left = try self.parseTerm();
        while (self.current.type == .lt or self.current.type == .gt or
            self.current.type == .lte or self.current.type == .gte)
        {
            const op = self.current.text;
            self.advance();
            const right = try self.parseTerm();
            const node = try self.alloc.create(Expr);
            node.* = .{ .binary = .{ .op = op, .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseTerm(self: *Parser) !*Expr {
        var left = try self.parseFactor();
        while (self.current.type == .plus or self.current.type == .minus) {
            const op = self.current.text;
            self.advance();
            const right = try self.parseFactor();
            const node = try self.alloc.create(Expr);
            node.* = .{ .binary = .{ .op = op, .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseFactor(self: *Parser) !*Expr {
        var left = try self.parseUnary();
        while (self.current.type == .star or self.current.type == .slash or self.current.type == .percent) {
            const op = self.current.text;
            self.advance();
            const right = try self.parseUnary();
            const node = try self.alloc.create(Expr);
            node.* = .{ .binary = .{ .op = op, .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseUnary(self: *Parser) !*Expr {
        if (self.current.type == .not_op or self.current.type == .minus) {
            const op = self.current.text;
            self.advance();
            const operand = try self.parseUnary();
            const node = try self.alloc.create(Expr);
            node.* = .{ .unary = .{ .op = op, .operand = operand } };
            return node;
        }
        return self.parsePrimary();
    }

    fn parsePrimary(self: *Parser) !*Expr {
        const node = try self.alloc.create(Expr);
        switch (self.current.type) {
            .trit_p => { node.* = .{ .trit = .P }; self.advance(); },
            .trit_z => { node.* = .{ .trit = .Z }; self.advance(); },
            .trit_n => { node.* = .{ .trit = .N }; self.advance(); },
            .integer => {
                node.* = .{ .int = std.fmt.parseInt(i64, self.current.text, 10) catch 0 };
                self.advance();
            },
            .float => {
                node.* = .{ .float = std.fmt.parseFloat(f64, self.current.text) catch 0 };
                self.advance();
            },
            .string => { node.* = .{ .str = self.current.text }; self.advance(); },
            .identifier => { node.* = .{ .ident = self.current.text }; self.advance(); },
            .lparen => {
                self.advance();
                const inner = try self.parseExpr();
                _ = self.match(.rparen);
                return inner;
            },
            else => { node.* = .{ .int = 0 }; },
        }
        return node;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "lexer tokens" {
    var lex = Lexer{ .src = "△ ○ ▽ Ⲫ Ⲏ 123" };
    try std.testing.expectEqual(TokenType.trit_p, lex.next().type);
    try std.testing.expectEqual(TokenType.trit_z, lex.next().type);
    try std.testing.expectEqual(TokenType.trit_n, lex.next().type);
    try std.testing.expectEqual(TokenType.kw_func, lex.next().type);
    try std.testing.expectEqual(TokenType.kw_struct, lex.next().type);
    try std.testing.expectEqual(TokenType.integer, lex.next().type);
}

test "tekum conversion" {
    const t = Tekum.fromInt(42);
    try std.testing.expectEqual(@as(i64, 42), t.toInt());
    const t2 = Tekum.fromInt(-13);
    try std.testing.expectEqual(@as(i64, -13), t2.toInt());
}

test "trit operations" {
    try std.testing.expectEqual(Trit.P, Trit.and_(.P, .P));
    try std.testing.expectEqual(Trit.Z, Trit.and_(.P, .Z));
    try std.testing.expectEqual(Trit.N, Trit.and_(.P, .N));
    try std.testing.expectEqual(Trit.N, Trit.not(.P));
    try std.testing.expectEqual(Trit.P, Trit.consensus(.P, .P));
    try std.testing.expectEqual(Trit.Z, Trit.consensus(.P, .N));
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("999 Full Parser v1.0\n");
    try stdout.writeAll("Features: Balanced Ternary, Kleene Strong, Tekum\n");
}
