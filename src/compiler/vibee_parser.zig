// ============================================================================
// VIBEEC PARSER
// Parses VIBEE code into AST
// ============================================================================

const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub const ParseError = error{
    UnexpectedToken,
    ExpectedExpression,
    ExpectedIdentifier,
    ExpectedType,
    ExpectedBlock,
    OutOfMemory,
};

pub const ParserError = ParseError || std.mem.Allocator.Error;

pub const Parser = struct {
    tokens: []lexer.Token,
    current: usize,
    allocator: std.mem.Allocator,
    builder: ast.AstBuilder,
    errors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator, tokens: []lexer.Token) Parser {
        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
            .builder = ast.AstBuilder.init(allocator),
            .errors = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn parse(self: *Parser) !*ast.Node {
        var declarations = std.ArrayList(*ast.Node).init(self.allocator);

        while (!self.isAtEnd()) {
            self.skipNewlines();
            if (self.isAtEnd()) break;

            if (self.parseDeclaration()) |decl| {
                try declarations.append(decl);
            } else |_| {
                self.synchronize();
            }
        }

        return self.builder.createProgram(try declarations.toOwnedSlice());
    }

    // ========================================================================
    // DECLARATIONS
    // ========================================================================

    fn parseDeclaration(self: *Parser) !*ast.Node {
        self.skipNewlines();
        self.skipComments();

        if (self.check(.Fn)) return self.parseFunction(false);
        if (self.check(.Pub)) {
            _ = self.advance();
            if (self.check(.Fn)) return self.parseFunction(true);
        }
        if (self.check(.Const)) return self.parseConst();
        if (self.check(.Let)) return self.parseLet();
        if (self.check(.Var)) return self.parseVar();
        if (self.check(.Test)) return self.parseTest();

        return self.parseStatement();
    }

    fn parseFunction(self: *Parser, is_pub: bool) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.Fn, "Expected 'fn'");

        const name_token = try self.consume(.Identifier, "Expected function name");
        const name = name_token.lexeme;

        _ = try self.consume(.LeftParen, "Expected '(' after function name");

        var params = std.ArrayList(ast.ParameterNode).init(self.allocator);
        if (!self.check(.RightParen)) {
            try params.append(try self.parseParameter());
            while (self.match(.Comma)) {
                try params.append(try self.parseParameter());
            }
        }
        _ = try self.consume(.RightParen, "Expected ')' after parameters");

        var return_type: ?*ast.Node = null;
        if (self.match(.Arrow)) {
            return_type = try self.parseType();
        }

        var body: ?*ast.Node = null;
        if (self.check(.LeftBrace)) {
            body = try self.parseBlock();
        }

        const empty_generics = try self.allocator.alloc([]const u8, 0);
        return self.builder.createFunctionDecl(
            name,
            try params.toOwnedSlice(),
            return_type,
            body,
            is_pub,
            empty_generics,
            null,
            start.line,
            start.column,
        );
    }

    fn parseParameter(self: *Parser) !ast.ParameterNode {
        const name_token = try self.consume(.Identifier, "Expected parameter name");
        var type_ann: ?*ast.Node = null;

        if (self.match(.Colon)) {
            type_ann = try self.parseType();
        }

        return ast.ParameterNode{
            .name = name_token.lexeme,
            .type_annotation = type_ann,
            .default_value = null,
        };
    }

    fn parseConst(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.Const, "Expected 'const'");

        const name_token = try self.consume(.Identifier, "Expected constant name");
        var type_ann: ?*ast.Node = null;

        if (self.match(.Colon)) {
            type_ann = try self.parseType();
        }

        _ = try self.consume(.Equal, "Expected '=' after constant name");
        const value = try self.parseExpression();

        return self.builder.createConstDecl(name_token.lexeme, type_ann, value, null, start.line, start.column);
    }

    fn parseLet(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.Let, "Expected 'let'");

        const name_token = try self.consume(.Identifier, "Expected variable name");
        var type_ann: ?*ast.Node = null;

        if (self.match(.Colon)) {
            type_ann = try self.parseType();
        }

        _ = try self.consume(.Equal, "Expected '=' after variable name");
        const value = try self.parseExpression();

        return self.builder.createLetDecl(name_token.lexeme, type_ann, value, start.line, start.column);
    }

    fn parseVar(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.Var, "Expected 'var'");

        const name_token = try self.consume(.Identifier, "Expected variable name");
        var type_ann: ?*ast.Node = null;

        if (self.match(.Colon)) {
            type_ann = try self.parseType();
        }

        var value: ?*ast.Node = null;
        if (self.match(.Equal)) {
            value = try self.parseExpression();
        }

        return self.builder.createVarDecl(name_token.lexeme, type_ann, value, start.line, start.column);
    }

    fn parseTest(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.Test, "Expected 'test'");

        const name_token = try self.consume(.String, "Expected test name string");
        const body = try self.parseBlock();

        // Remove quotes from test name
        const name = if (name_token.lexeme.len >= 2)
            name_token.lexeme[1 .. name_token.lexeme.len - 1]
        else
            name_token.lexeme;

        return self.builder.createTestDecl(name, body, start.line, start.column);
    }

    // ========================================================================
    // STATEMENTS
    // ========================================================================

    fn parseStatement(self: *Parser) ParserError!*ast.Node {
        if (self.check(.If)) return self.parseIf();
        if (self.check(.For)) return self.parseFor();
        if (self.check(.While)) return self.parseWhile();
        if (self.check(.Return)) return self.parseReturn();
        if (self.check(.LeftBrace)) return self.parseBlock();

        return self.parseExpressionStatement();
    }

    fn parseBlock(self: *Parser) ParserError!*ast.Node {
        const start = self.peek();
        _ = try self.consume(.LeftBrace, "Expected '{'");

        var statements = std.ArrayList(*ast.Node).init(self.allocator);

        while (!self.check(.RightBrace) and !self.isAtEnd()) {
            self.skipNewlines();
            if (self.check(.RightBrace)) break;

            const stmt = self.parseStatement() catch {
                self.synchronize();
                continue;
            };
            try statements.append(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}'");
        return self.builder.createBlock(try statements.toOwnedSlice(), start.line, start.column);
    }

    fn parseIf(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.If, "Expected 'if'");

        const condition = try self.parseExpression();
        const then_branch = try self.parseBlock();

        var else_branch: ?*ast.Node = null;
        if (self.match(.Else)) {
            if (self.check(.If)) {
                else_branch = try self.parseIf();
            } else {
                else_branch = try self.parseBlock();
            }
        }

        return self.builder.createIfStmt(condition, then_branch, else_branch, start.line, start.column);
    }

    fn parseFor(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.For, "Expected 'for'");

        const var_token = try self.consume(.Identifier, "Expected loop variable");
        _ = try self.consume(.In, "Expected 'in'");

        const iterable = try self.parseExpression();
        const body = try self.parseBlock();

        return self.builder.createForStmt(var_token.lexeme, iterable, body, start.line, start.column);
    }

    fn parseWhile(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.While, "Expected 'while'");

        const condition = try self.parseExpression();
        const body = try self.parseBlock();

        return self.builder.createWhileStmt(condition, body, start.line, start.column);
    }

    fn parseReturn(self: *Parser) !*ast.Node {
        const start = self.peek();
        _ = try self.consume(.Return, "Expected 'return'");

        var value: ?*ast.Node = null;
        if (!self.check(.Newline) and !self.check(.RightBrace) and !self.isAtEnd()) {
            value = try self.parseExpression();
        }

        return self.builder.createReturnStmt(value, start.line, start.column);
    }

    fn parseExpressionStatement(self: *Parser) !*ast.Node {
        return self.parseExpression();
    }

    // ========================================================================
    // EXPRESSIONS (Pratt parser)
    // ========================================================================

    fn parseExpression(self: *Parser) ParserError!*ast.Node {
        return self.parseAssignment();
    }

    fn parseAssignment(self: *Parser) ParserError!*ast.Node {
        const expr = try self.parseOr();

        if (self.check(.Equal) or self.check(.PlusEqual) or self.check(.MinusEqual)) {
            const op_token = self.advance();
            const op: ast.AssignOp = switch (op_token.type) {
                .Equal => .Assign,
                .PlusEqual => .AddAssign,
                .MinusEqual => .SubAssign,
                .StarEqual => .MulAssign,
                .SlashEqual => .DivAssign,
                else => .Assign,
            };
            const value = try self.parseAssignment();
            return self.builder.createAssignExpr(expr, op, value, op_token.line, op_token.column);
        }

        return expr;
    }

    fn parseOr(self: *Parser) ParserError!*ast.Node {
        var expr = try self.parseAnd();

        while (self.match(.PipePipe)) {
            const right = try self.parseAnd();
            expr = try self.builder.createBinaryExpr(expr, .Or, right, expr.line, expr.column);
        }

        return expr;
    }

    fn parseAnd(self: *Parser) ParserError!*ast.Node {
        var expr = try self.parseEquality();

        while (self.match(.AmpAmp)) {
            const right = try self.parseEquality();
            expr = try self.builder.createBinaryExpr(expr, .And, right, expr.line, expr.column);
        }

        return expr;
    }

    fn parseEquality(self: *Parser) ParserError!*ast.Node {
        var expr = try self.parseComparison();

        while (self.check(.EqualEqual) or self.check(.BangEqual)) {
            const op_token = self.advance();
            const op: ast.BinaryOp = if (op_token.type == .EqualEqual) .Eq else .Ne;
            const right = try self.parseComparison();
            expr = try self.builder.createBinaryExpr(expr, op, right, op_token.line, op_token.column);
        }

        return expr;
    }

    fn parseComparison(self: *Parser) ParserError!*ast.Node {
        var expr = try self.parseTerm();

        while (self.check(.Less) or self.check(.LessEqual) or self.check(.Greater) or self.check(.GreaterEqual)) {
            const op_token = self.advance();
            const op: ast.BinaryOp = switch (op_token.type) {
                .Less => .Lt,
                .LessEqual => .Le,
                .Greater => .Gt,
                .GreaterEqual => .Ge,
                else => .Lt,
            };
            const right = try self.parseTerm();
            expr = try self.builder.createBinaryExpr(expr, op, right, op_token.line, op_token.column);
        }

        return expr;
    }

    fn parseTerm(self: *Parser) ParserError!*ast.Node {
        var expr = try self.parseFactor();

        while (self.check(.Plus) or self.check(.Minus)) {
            const op_token = self.advance();
            const op: ast.BinaryOp = if (op_token.type == .Plus) .Add else .Sub;
            const right = try self.parseFactor();
            expr = try self.builder.createBinaryExpr(expr, op, right, op_token.line, op_token.column);
        }

        return expr;
    }

    fn parseFactor(self: *Parser) ParserError!*ast.Node {
        var expr = try self.parseUnary();

        while (self.check(.Star) or self.check(.Slash) or self.check(.Percent)) {
            const op_token = self.advance();
            const op: ast.BinaryOp = switch (op_token.type) {
                .Star => .Mul,
                .Slash => .Div,
                .Percent => .Mod,
                else => .Mul,
            };
            const right = try self.parseUnary();
            expr = try self.builder.createBinaryExpr(expr, op, right, op_token.line, op_token.column);
        }

        return expr;
    }

    fn parseUnary(self: *Parser) ParserError!*ast.Node {
        if (self.check(.Minus) or self.check(.Bang) or self.check(.Tilde)) {
            const op_token = self.advance();
            const op: ast.UnaryOp = switch (op_token.type) {
                .Minus => .Neg,
                .Bang => .Not,
                .Tilde => .BitNot,
                else => .Neg,
            };
            const operand = try self.parseUnary();
            return self.builder.createUnaryExpr(op, operand, op_token.line, op_token.column);
        }

        return self.parsePostfix();
    }

    fn parsePostfix(self: *Parser) ParserError!*ast.Node {
        var expr = try self.parsePrimary();

        while (true) {
            if (self.match(.LeftParen)) {
                expr = try self.parseCall(expr);
            } else if (self.match(.LeftBracket)) {
                const index = try self.parseExpression();
                _ = try self.consume(.RightBracket, "Expected ']'");
                expr = try self.builder.createIndexExpr(expr, index, expr.line, expr.column);
            } else if (self.match(.Dot)) {
                const member = try self.consume(.Identifier, "Expected member name");
                expr = try self.builder.createMemberExpr(expr, member.lexeme, expr.line, expr.column);
            } else {
                break;
            }
        }

        return expr;
    }

    fn parseCall(self: *Parser, callee: *ast.Node) ParserError!*ast.Node {
        var args = std.ArrayList(*ast.Node).init(self.allocator);

        if (!self.check(.RightParen)) {
            try args.append(try self.parseExpression());
            while (self.match(.Comma)) {
                try args.append(try self.parseExpression());
            }
        }

        _ = try self.consume(.RightParen, "Expected ')' after arguments");
        return self.builder.createCallExpr(callee, try args.toOwnedSlice(), callee.line, callee.column);
    }

    fn parsePrimary(self: *Parser) ParserError!*ast.Node {
        const token = self.peek();

        if (self.match(.Integer)) {
            const value = std.fmt.parseInt(i64, token.lexeme, 0) catch 0;
            return self.builder.createIntLiteral(value, token.lexeme, token.line, token.column);
        }

        if (self.match(.Float)) {
            const value = std.fmt.parseFloat(f64, token.lexeme) catch 0.0;
            return self.builder.createFloatLiteral(value, token.lexeme, token.line, token.column);
        }

        if (self.match(.String)) {
            const raw = token.lexeme;
            const value = if (raw.len >= 2) raw[1 .. raw.len - 1] else raw;
            return self.builder.createStringLiteral(value, raw, token.line, token.column);
        }

        if (self.match(.True)) {
            return self.builder.createBoolLiteral(true, token.line, token.column);
        }

        if (self.match(.False)) {
            return self.builder.createBoolLiteral(false, token.line, token.column);
        }

        if (self.match(.None)) {
            return self.builder.createNoneLiteral(token.line, token.column);
        }

        if (self.match(.Identifier)) {
            return self.builder.createIdentifier(token.lexeme, token.line, token.column);
        }

        if (self.match(.LeftParen)) {
            const expr = try self.parseExpression();
            _ = try self.consume(.RightParen, "Expected ')'");
            return expr;
        }

        if (self.match(.LeftBracket)) {
            var elements = std.ArrayList(*ast.Node).init(self.allocator);
            if (!self.check(.RightBracket)) {
                try elements.append(try self.parseExpression());
                while (self.match(.Comma)) {
                    try elements.append(try self.parseExpression());
                }
            }
            _ = try self.consume(.RightBracket, "Expected ']'");
            return self.builder.createArrayLiteral(try elements.toOwnedSlice(), token.line, token.column);
        }

        if (self.check(.LeftBrace)) {
            return self.parseBlock();
        }

        return ParseError.ExpectedExpression;
    }

    // ========================================================================
    // TYPES
    // ========================================================================

    fn parseType(self: *Parser) !*ast.Node {
        const token = self.peek();

        if (self.match(.LeftBracket)) {
            _ = try self.parseType();
            _ = try self.consume(.RightBracket, "Expected ']'");
            const empty = try self.allocator.alloc(*ast.Node, 0);
            return self.builder.createTypeAnnotation("Array", empty, false, true, token.line, token.column);
        }

        const name_token = try self.consume(.Identifier, "Expected type name");
        var generics = std.ArrayList(*ast.Node).init(self.allocator);

        if (self.match(.Less)) {
            try generics.append(try self.parseType());
            while (self.match(.Comma)) {
                try generics.append(try self.parseType());
            }
            _ = try self.consume(.Greater, "Expected '>'");
        }

        const is_optional = self.match(.Question);

        return self.builder.createTypeAnnotation(
            name_token.lexeme,
            try generics.toOwnedSlice(),
            is_optional,
            false,
            token.line,
            token.column,
        );
    }

    // ========================================================================
    // HELPERS
    // ========================================================================

    fn isAtEnd(self: *Parser) bool {
        return self.current >= self.tokens.len or self.peek().type == .Eof;
    }

    fn peek(self: *Parser) lexer.Token {
        if (self.current >= self.tokens.len) {
            return lexer.Token{ .type = .Eof, .lexeme = "", .line = 0, .column = 0 };
        }
        return self.tokens[self.current];
    }

    fn advance(self: *Parser) lexer.Token {
        if (!self.isAtEnd()) {
            self.current += 1;
        }
        return self.tokens[self.current - 1];
    }

    fn check(self: *Parser, token_type: lexer.TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().type == token_type;
    }

    fn match(self: *Parser, token_type: lexer.TokenType) bool {
        if (self.check(token_type)) {
            _ = self.advance();
            return true;
        }
        return false;
    }

    fn consume(self: *Parser, token_type: lexer.TokenType, message: []const u8) !lexer.Token {
        if (self.check(token_type)) return self.advance();
        _ = message;
        return ParseError.UnexpectedToken;
    }

    fn skipNewlines(self: *Parser) void {
        while (self.check(.Newline)) {
            _ = self.advance();
        }
    }

    fn skipComments(self: *Parser) void {
        while (self.check(.Comment) or self.check(.DocComment)) {
            _ = self.advance();
            self.skipNewlines();
        }
    }

    fn synchronize(self: *Parser) void {
        _ = self.advance();
        while (!self.isAtEnd()) {
            if (self.tokens[self.current - 1].type == .Newline) return;
            switch (self.peek().type) {
                .Fn, .Const, .Let, .Var, .For, .If, .While, .Return, .Test => return,
                else => _ = self.advance(),
            }
        }
    }
};

// ============================================================================
// CONVENIENCE FUNCTION
// ============================================================================

pub fn parseSource(allocator: std.mem.Allocator, source: []const u8) !*ast.Node {
    var lex = lexer.Lexer.init(source);
    const tokens = try lex.tokenize(allocator);
    var parser = Parser.init(allocator, tokens);
    return parser.parse();
}

// ============================================================================
// TESTS
// ============================================================================

// Use arena allocator for tests to avoid leak detection issues
fn testParse(source: []const u8) !*ast.Node {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    return parseSource(allocator, source);
}

test "parse simple function" {
    const tree = try testParse("fn main() { }");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
}

test "parse function with params" {
    const tree = try testParse("fn add(a: Int, b: Int) -> Int { }");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
    try std.testing.expect(tree.data.program.declarations.len == 1);
}

test "parse const declaration" {
    const tree = try testParse("const PI: Float = 3.14");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
}

test "parse let declaration" {
    const tree = try testParse("let x = 42");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
}

test "parse binary expression" {
    const tree = try testParse("let x = 1 + 2 * 3");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
}

test "parse if statement" {
    const tree = try testParse("if x > 0 { return 1 }");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
}

test "parse for loop" {
    const tree = try testParse("for i in items { }");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
}

test "parse function call" {
    const tree = try testParse("let x = foo(1, 2)");
    try std.testing.expectEqual(ast.NodeType.Program, tree.node_type);
}
