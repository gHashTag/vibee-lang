//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ Coptic Parser - Extended Implementation
//! Pratt parser with operator precedence
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_lexer = @import("coptic_lexer.zig");

const Lexer = coptic_lexer.Lexer;
const Token = coptic_lexer.Token;
const TokenKind = coptic_lexer.TokenKind;

pub const PHI: f64 = 1.6180339887498948482;

pub const NodeKind = enum {
    program,
    module_decl,
    const_decl,
    var_decl,
    let_decl, // let x = expr
    let_destructure_array, // let [a, b, c] = expr
    let_destructure_object, // let {x, y} = expr
    rest_pattern, // ...rest in destructuring
    func_decl,
    func_expr, // anonymous function: fn(args) { body }
    lambda_expr, // lambda: x => expr or (x, y) => expr
    block,
    return_stmt,
    if_expr,
    match_expr, // match expr { arms }
    match_arm, // pattern => result
    or_pattern, // 1 | 2 | 3 in match
    range_pattern, // 1..10 in match
    while_stmt,
    for_stmt,
    break_stmt,
    continue_stmt,
    binary_expr,
    is_expr, // x is Type
    unary_expr,
    call_expr,
    index_expr,
    member_expr, // obj.field
    optional_member, // obj?.field
    array_literal,
    list_comprehension, // [expr for x in arr if cond]
    spread_element, // ...arr in array/object literal
    object_literal, // {key: value, ...}
    object_field, // key: value pair
    literal_int,
    literal_float,
    literal_string,
    literal_trit,
    literal_tryte,
    literal_bool,
    literal_nil,
    literal_some, // Some(value)
    literal_none, // None
    literal_ok, // Ok(value)
    literal_err, // Err(value)
    identifier,
    coptic_id,
    placeholder, // _ for partial application
};

pub const AstNode = struct {
    kind: NodeKind,
    token: Token,
    children: std.ArrayListUnmanaged(AstNode),
    allocator: std.mem.Allocator,

    pub fn init(kind: NodeKind, token: Token, allocator: std.mem.Allocator) AstNode {
        return .{
            .kind = kind,
            .token = token,
            .children = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AstNode) void {
        for (self.children.items) |*child| child.deinit();
        self.children.deinit(self.allocator);
    }

    pub fn addChild(self: *AstNode, child: AstNode) !void {
        try self.children.append(self.allocator, child);
    }
};

pub const ParseError = error{ UnexpectedToken, OutOfMemory };

// Operator precedence (Pratt parsing)
const Precedence = enum(u8) {
    none = 0,
    assignment = 1, // =
    compose = 2, // >> (function composition)
    pipe = 3, // |> (left-to-right chaining)
    or_prec = 4, // ||
    and_prec = 5, // &&
    equality = 6, // == !=
    comparison = 7, // < > <= >=
    range = 8, // ..
    term = 9, // + -
    factor = 10, // * /
    unary = 11, // ! -
    call = 12, // ()
    primary = 13,
};

fn getPrecedence(kind: TokenKind) Precedence {
    return switch (kind) {
        .op_eq => .assignment,
        .op_compose => .compose,
        .op_pipe => .pipe,
        .op_nullish => .or_prec, // ?? has same precedence as ||
        .op_or, .kw_or => .or_prec,
        .op_and, .kw_and => .and_prec,
        .op_eqeq, .op_neq, .op_eqeq_t => .equality,
        .op_lt, .op_gt, .op_lte, .op_gte, .kw_is, .op_lt_t => .comparison,
        .op_range => .range,
        .op_plus, .op_minus, .op_plus_t, .op_minus_t => .term,
        .op_star, .op_slash, .op_percent, .op_star_t => .factor,
        .lparen, .lbracket, .dot, .op_optional_chain => .call,
        else => .none,
    };
}

pub const Parser = struct {
    lexer: Lexer,
    current: Token,
    previous: Token,
    source: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        var lexer = Lexer.init(source);
        const current = lexer.nextToken();
        return .{ .lexer = lexer, .current = current, .previous = current, .source = source, .allocator = allocator };
    }

    fn advance(self: *Parser) void {
        self.previous = self.current;
        self.current = self.lexer.nextToken();
    }

    fn check(self: *Parser, kind: TokenKind) bool {
        return self.current.kind == kind;
    }

    fn peekNext(self: *Parser) Token {
        // Save state
        const saved_current = self.current;
        const saved_previous = self.previous;
        const saved_pos = self.lexer.pos;
        const saved_line = self.lexer.line;
        const saved_col = self.lexer.column;

        // Advance and get next token
        self.advance();
        const next = self.current;

        // Restore state
        self.current = saved_current;
        self.previous = saved_previous;
        self.lexer.pos = saved_pos;
        self.lexer.line = saved_line;
        self.lexer.column = saved_col;

        return next;
    }

    fn match(self: *Parser, kind: TokenKind) bool {
        if (self.check(kind)) {
            self.advance();
            return true;
        }
        return false;
    }

    fn consume(self: *Parser, kind: TokenKind) !Token {
        if (self.check(kind)) {
            const t = self.current;
            self.advance();
            return t;
        }
        return error.UnexpectedToken;
    }

    // Program: declaration*
    pub fn parseProgram(self: *Parser) ParseError!AstNode {
        var node = AstNode.init(.program, self.current, self.allocator);
        while (!self.check(.eof)) {
            if (self.check(.newline) or self.check(.comment)) {
                self.advance();
                continue;
            }
            const child = try self.parseDeclaration();
            try node.addChild(child);
        }
        return node;
    }

    // Declaration: module_decl | const_decl | var_decl | let_decl | func_decl | statement
    fn parseDeclaration(self: *Parser) ParseError!AstNode {
        if (self.check(.kw_module)) return self.parseModuleDecl();
        if (self.check(.kw_const)) return self.parseConstDecl();
        if (self.check(.kw_var)) return self.parseVarDecl();
        if (self.check(.kw_let)) return self.parseLetDecl();
        if (self.check(.kw_func)) return self.parseFuncDecl();
        return self.parseStatement();
    }

    // ConstDecl: 'const' IDENT '=' expr
    fn parseConstDecl(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.const_decl, tok, self.allocator);
        const name = try self.parseIdentifier();
        try node.addChild(name);

        if (self.match(.colon)) {
            const type_node = try self.parseIdentifier();
            try node.addChild(type_node);
        }

        _ = self.match(.op_eq);
        const value = try self.parseExpression(.assignment);
        try node.addChild(value);
        return node;
    }

    // VarDecl: 'var' IDENT '=' expr
    fn parseVarDecl(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.var_decl, tok, self.allocator);
        const name = try self.parseIdentifier();
        try node.addChild(name);

        if (self.match(.colon)) {
            const type_node = try self.parseIdentifier();
            try node.addChild(type_node);
        }

        _ = self.match(.op_eq);
        const value = try self.parseExpression(.assignment);
        try node.addChild(value);
        return node;
    }

    // ModuleDecl: 'module' IDENT
    fn parseModuleDecl(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.module_decl, tok, self.allocator);
        const name = try self.parseIdentifier();
        try node.addChild(name);
        return node;
    }

    // LetDecl: 'let' pattern '=' expr (supports destructuring)
    // pattern: IDENT | '[' IDENT (',' IDENT)* ']' | '{' IDENT (',' IDENT)* '}'
    fn parseLetDecl(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();

        // Check for array destructuring: let [a, b, c] = ...
        if (self.check(.lbracket)) {
            self.advance(); // consume '['
            var node = AstNode.init(.let_destructure_array, tok, self.allocator);

            // Parse identifiers in the pattern
            while (!self.check(.rbracket) and !self.check(.eof)) {
                // Check for rest pattern: ...rest
                if (self.check(.dot_dot_dot)) {
                    self.advance();
                    const rest_name = try self.parseIdentifier();
                    var rest_node = AstNode.init(.rest_pattern, rest_name.token, self.allocator);
                    try rest_node.addChild(rest_name);
                    try node.addChild(rest_node);
                } else if (self.check(.identifier) or self.check(.coptic_identifier)) {
                    const name = try self.parseIdentifier();
                    try node.addChild(name);
                }
                if (!self.match(.comma)) break;
            }
            _ = try self.consume(.rbracket);
            _ = self.match(.op_eq);
            const value = try self.parseExpression(.assignment);
            try node.addChild(value);
            return node;
        }

        // Check for object destructuring: let {x, y} = ...
        if (self.check(.lbrace)) {
            self.advance(); // consume '{'
            var node = AstNode.init(.let_destructure_object, tok, self.allocator);

            while (!self.check(.rbrace) and !self.check(.eof)) {
                if (self.check(.identifier) or self.check(.coptic_identifier)) {
                    const name = try self.parseIdentifier();
                    try node.addChild(name);
                }
                if (!self.match(.comma)) break;
            }
            _ = try self.consume(.rbrace);
            _ = self.match(.op_eq);
            const value = try self.parseExpression(.assignment);
            try node.addChild(value);
            return node;
        }

        // Simple let: let x = ...
        var node = AstNode.init(.let_decl, tok, self.allocator);
        const name = try self.parseIdentifier();
        try node.addChild(name);
        _ = self.match(.op_eq);
        const value = try self.parseExpression(.assignment);
        try node.addChild(value);
        return node;
    }

    // FuncDecl: 'func' IDENT '(' params ')' block
    fn parseFuncDecl(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.func_decl, tok, self.allocator);
        const name = try self.parseIdentifier();
        try node.addChild(name);
        _ = try self.consume(.lparen);
        // Parse params (simplified)
        while (!self.check(.rparen) and !self.check(.eof)) {
            if (self.check(.identifier) or self.check(.coptic_identifier)) {
                const param = try self.parseIdentifier();
                try node.addChild(param);

                // Optional param type: (a: i32)
                if (self.match(.colon)) {
                    const param_type = try self.parseIdentifier();
                    try node.addChild(param_type);
                }
            }
            _ = self.match(.comma);
        }
        _ = try self.consume(.rparen);

        // Optional return type: func (...) -> i32
        if (self.match(.op_arrow) or self.match(.op_fat_arrow)) {
            const ret_type = try self.parseIdentifier();
            try node.addChild(ret_type);
        }

        const body = try self.parseBlock();
        try node.addChild(body);
        return node;
    }

    // Block: '{' statement* '}'
    fn parseBlock(self: *Parser) ParseError!AstNode {
        const tok = try self.consume(.lbrace);
        var node = AstNode.init(.block, tok, self.allocator);
        while (!self.check(.rbrace) and !self.check(.eof)) {
            if (self.check(.newline)) {
                self.advance();
                continue;
            }
            const stmt = try self.parseStatement();
            try node.addChild(stmt);
        }
        _ = try self.consume(.rbrace);
        return node;
    }

    // Statement: return_stmt | if_stmt | while_stmt | for_stmt | break | continue | expr
    fn parseStatement(self: *Parser) ParseError!AstNode {
        if (self.check(.kw_return)) return self.parseReturn();
        if (self.check(.kw_if)) return self.parseIf();
        if (self.check(.kw_while)) return self.parseWhile();
        if (self.check(.kw_for)) return self.parseFor();
        if (self.check(.kw_break)) return self.parseBreak();
        if (self.check(.kw_continue)) return self.parseContinue();
        if (self.check(.kw_const)) return self.parseConstDecl();
        if (self.check(.kw_var)) return self.parseVarDecl();
        if (self.check(.kw_let)) return self.parseLetDecl();
        return self.parseExpression(.assignment);
    }

    // Return: 'return' expr?
    fn parseReturn(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.return_stmt, tok, self.allocator);
        if (!self.check(.newline) and !self.check(.rbrace) and !self.check(.eof)) {
            const value = try self.parseExpression(.assignment);
            try node.addChild(value);
        }
        return node;
    }

    // If: 'if' expr block ('else' (if | block))?
    fn parseIf(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.if_expr, tok, self.allocator);
        const cond = try self.parseExpression(.assignment);
        try node.addChild(cond);
        const then_block = try self.parseBlock();
        try node.addChild(then_block);
        if (self.match(.kw_else)) {
            if (self.check(.kw_if)) {
                // else if
                const else_if = try self.parseIf();
                try node.addChild(else_if);
            } else {
                const else_block = try self.parseBlock();
                try node.addChild(else_block);
            }
        }
        return node;
    }

    // Match: 'match' expr '{' (pattern ['if' guard] '=>' expr (',' | newline))* '}'
    fn parseMatch(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance(); // skip 'match'
        var node = AstNode.init(.match_expr, tok, self.allocator);

        // Parse the expression to match against
        const subject = try self.parseExpression(.assignment);
        try node.addChild(subject);

        // Expect '{'
        _ = try self.consume(.lbrace);

        // Parse match arms
        // Skip leading newlines after '{'
        while (self.match(.newline)) {}

        while (!self.check(.rbrace) and !self.check(.eof)) {
            var arm = AstNode.init(.match_arm, self.current, self.allocator);

            // Parse pattern
            const pattern = try self.parsePattern();
            try arm.addChild(pattern);

            // Optional guard: 'if' condition
            // Parse guard with low precedence to stop at =>
            if (self.match(.kw_if)) {
                const guard = try self.parseGuardExpression();
                try arm.addChild(guard);
            }

            // Expect '=>'
            _ = try self.consume(.op_fat_arrow);

            // Parse result expression
            const result = try self.parseExpression(.assignment);
            try arm.addChild(result);

            try node.addChild(arm);

            // Optional comma or newline separator, skip multiple newlines
            _ = self.match(.comma);
            while (self.match(.newline)) {}
        }

        _ = try self.consume(.rbrace);
        return node;
    }

    // Parse guard expression - stops at => token
    fn parseGuardExpression(self: *Parser) ParseError!AstNode {
        // Parse a simple comparison expression that stops at =>
        // This handles: x < 0, x == 0, x > 10, etc.
        var left = try self.parsePrimary();

        // Handle binary operators but stop at =>
        while (true) {
            const op = self.current.kind;
            if (op == .op_fat_arrow or op == .newline or op == .comma or op == .rbrace or op == .eof) {
                break;
            }

            // Handle comparison and logical operators
            if (op == .op_lt or op == .op_gt or op == .op_lte or op == .op_gte or
                op == .op_eqeq or op == .op_neq or op == .op_and or op == .op_or)
            {
                const op_tok = self.current;
                self.advance();
                const right = try self.parsePrimary();

                var node = AstNode.init(.binary_expr, op_tok, self.allocator);
                try node.addChild(left);
                try node.addChild(right);
                left = node;
            } else if (op == .op_plus or op == .op_minus or op == .op_star or op == .op_slash or op == .op_percent or
                op == .op_plus_t or op == .op_minus_t or op == .op_star_t or op == .op_lt_t or op == .op_eqeq_t)
            {
                const op_tok = self.current;
                self.advance();
                const right = try self.parsePrimary();

                var node = AstNode.init(.binary_expr, op_tok, self.allocator);
                try node.addChild(left);
                try node.addChild(right);
                left = node;
            } else {
                break;
            }
        }

        return left;
    }

    // Pattern: simple_pattern ('|' simple_pattern)*
    // Supports OR patterns like: 1 | 2 | 3
    fn parsePattern(self: *Parser) ParseError!AstNode {
        const left = try self.parseSimplePattern();

        // Check for OR pattern: pattern | pattern | ...
        if (self.check(.op_bitor)) {
            var or_node = AstNode.init(.or_pattern, left.token, self.allocator);
            try or_node.addChild(left);

            while (self.match(.op_bitor)) {
                const right = try self.parseSimplePattern();
                try or_node.addChild(right);
            }

            return or_node;
        }

        return left;
    }

    // Simple pattern: literal | '_' | identifier | range
    fn parseSimplePattern(self: *Parser) ParseError!AstNode {
        const tok = self.current;

        // Wildcard pattern: _
        if (self.check(.identifier)) {
            const name = tok.lexeme(self.source);
            if (std.mem.eql(u8, name, "_")) {
                self.advance();
                return AstNode.init(.identifier, tok, self.allocator);
            }
        }

        // Literal patterns
        switch (tok.kind) {
            .int_literal, .hex_literal, .binary_literal, .ternary_literal => {
                self.advance();
                const node = AstNode.init(.literal_int, tok, self.allocator);

                // Check for range pattern: 1..10
                if (self.check(.op_range)) {
                    self.advance(); // consume ..
                    const end_tok = self.current;
                    if (self.check(.int_literal) or self.check(.hex_literal) or
                        self.check(.binary_literal) or self.check(.ternary_literal))
                    {
                        self.advance();
                        var range_node = AstNode.init(.range_pattern, tok, self.allocator);
                        try range_node.addChild(node);
                        try range_node.addChild(AstNode.init(.literal_int, end_tok, self.allocator));
                        return range_node;
                    }
                }

                return node;
            },
            .float_literal => {
                self.advance();
                return AstNode.init(.literal_float, tok, self.allocator);
            },
            .string_literal => {
                self.advance();
                return AstNode.init(.literal_string, tok, self.allocator);
            },
            .kw_true, .kw_false => {
                self.advance();
                return AstNode.init(.literal_bool, tok, self.allocator);
            },
            .kw_nil => {
                self.advance();
                return AstNode.init(.literal_nil, tok, self.allocator);
            },
            .identifier => {
                // Binding pattern - captures the value
                self.advance();
                return AstNode.init(.identifier, tok, self.allocator);
            },
            else => return error.UnexpectedToken,
        }
    }

    // While: 'while' expr block
    fn parseWhile(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.while_stmt, tok, self.allocator);
        const cond = try self.parseExpression(.assignment);
        try node.addChild(cond);
        const body = try self.parseBlock();
        try node.addChild(body);
        return node;
    }

    // For: 'for' IDENT 'in' expr block
    fn parseFor(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        var node = AstNode.init(.for_stmt, tok, self.allocator);
        const iter_var = try self.parseIdentifier();
        try node.addChild(iter_var);
        _ = try self.consume(.kw_in);
        const iterable = try self.parseExpression(.assignment);
        try node.addChild(iterable);
        const body = try self.parseBlock();
        try node.addChild(body);
        return node;
    }

    // Break: 'break'
    fn parseBreak(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        return AstNode.init(.break_stmt, tok, self.allocator);
    }

    // Continue: 'continue'
    fn parseContinue(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance();
        return AstNode.init(.continue_stmt, tok, self.allocator);
    }

    // Expression: Pratt parser
    fn parseExpression(self: *Parser, min_prec: Precedence) ParseError!AstNode {
        var left = try self.parsePrefixExpr();

        // Use >= for right-associative operators (assignment)
        // Use > for left-associative operators
        while (@intFromEnum(getPrecedence(self.current.kind)) >= @intFromEnum(min_prec) and
            getPrecedence(self.current.kind) != .none)
        {
            const op = self.current;
            const prec = getPrecedence(op.kind);
            self.advance();

            if (op.kind == .lparen) {
                // Function call
                var call = AstNode.init(.call_expr, op, self.allocator);
                try call.addChild(left);
                while (!self.check(.rparen) and !self.check(.eof)) {
                    const arg = try self.parseExpression(.assignment);
                    try call.addChild(arg);
                    _ = self.match(.comma);
                }
                _ = try self.consume(.rparen);
                left = call;
            } else if (op.kind == .lbracket) {
                // Index expression arr[i]
                var index = AstNode.init(.index_expr, op, self.allocator);
                try index.addChild(left);
                const idx = try self.parseExpression(.assignment);
                try index.addChild(idx);
                _ = try self.consume(.rbracket);
                left = index;
            } else if (op.kind == .dot) {
                // Member expression obj.field
                const field_tok = self.current;
                if (!self.check(.identifier)) {
                    return error.UnexpectedToken;
                }
                self.advance();
                var member = AstNode.init(.member_expr, op, self.allocator);
                try member.addChild(left);
                const field_node = AstNode.init(.identifier, field_tok, self.allocator);
                try member.addChild(field_node);
                left = member;
            } else if (op.kind == .op_optional_chain) {
                // Optional member expression obj?.field
                const field_tok = self.current;
                if (!self.check(.identifier)) {
                    return error.UnexpectedToken;
                }
                self.advance();
                var member = AstNode.init(.optional_member, op, self.allocator);
                try member.addChild(left);
                const field_node = AstNode.init(.identifier, field_tok, self.allocator);
                try member.addChild(field_node);
                left = member;
            } else if (op.kind == .op_pipe) {
                // Pipe expression: x |> f => f(x), x |> f(y) => f(x, y)
                // Parse right side with higher precedence to get the function/call
                const right = try self.parseExpression(.call);

                // Transform into call expression
                var call = AstNode.init(.call_expr, op, self.allocator);

                if (right.kind == .call_expr and right.children.items.len > 0) {
                    // x |> f(y, z) => f(x, y, z)
                    // First child of call_expr is the function, rest are args
                    try call.addChild(right.children.items[0]); // function
                    try call.addChild(left); // x as first arg
                    // Add remaining args from original call
                    for (right.children.items[1..]) |child| {
                        try call.addChild(child);
                    }
                } else {
                    // x |> f => f(x)
                    try call.addChild(right); // function
                    try call.addChild(left); // x as arg
                }
                left = call;
            } else if (op.kind == .kw_is) {
                // Type check expression: x is Type
                // Right side is a type name (identifier or type keyword)
                const type_tok = self.current;
                // Allow identifiers and type keywords (Some, None, Ok, Err, etc.)
                if (!self.check(.identifier) and
                    !self.check(.kw_some) and !self.check(.kw_none) and
                    !self.check(.kw_ok) and !self.check(.kw_err) and
                    !self.check(.kw_nil))
                {
                    return error.UnexpectedToken;
                }
                self.advance();
                var is_node = AstNode.init(.is_expr, op, self.allocator);
                try is_node.addChild(left);
                const type_node = AstNode.init(.identifier, type_tok, self.allocator);
                try is_node.addChild(type_node);
                left = is_node;
            } else {
                // Binary expression
                const right = try self.parseExpression(prec);
                var binary = AstNode.init(.binary_expr, op, self.allocator);
                try binary.addChild(left);
                try binary.addChild(right);
                left = binary;
            }
        }
        return left;
    }

    // Prefix: unary | primary
    fn parsePrefixExpr(self: *Parser) ParseError!AstNode {
        if (self.check(.op_minus) or self.check(.op_not) or self.check(.kw_not)) {
            const op = self.current;
            self.advance();
            var node = AstNode.init(.unary_expr, op, self.allocator);
            const operand = try self.parsePrefixExpr();
            try node.addChild(operand);
            return node;
        }
        return self.parsePrimary();
    }

    // Primary: literal | identifier | '(' expr ')' | '[' elements ']' | if_expr
    fn parsePrimary(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        const kind: NodeKind = switch (tok.kind) {
            .int_literal, .hex_literal, .binary_literal => .literal_int,
            .ternary_literal => .literal_tryte,
            .float_literal => .literal_float,
            .string_literal => .literal_string,
            .trit_true, .trit_unknown, .trit_false => .literal_trit,
            .kw_true, .kw_false => .literal_bool,
            .kw_nil => .literal_nil,
            .kw_none => .literal_none,
            .kw_some => {
                self.advance(); // consume 'Some'
                _ = try self.consume(.lparen);
                var node = AstNode.init(.literal_some, tok, self.allocator);
                const value = try self.parseExpression(.assignment);
                try node.addChild(value);
                _ = try self.consume(.rparen);
                return node;
            },
            .kw_ok => {
                self.advance(); // consume 'Ok'
                _ = try self.consume(.lparen);
                var node = AstNode.init(.literal_ok, tok, self.allocator);
                const value = try self.parseExpression(.assignment);
                try node.addChild(value);
                _ = try self.consume(.rparen);
                return node;
            },
            .kw_err => {
                self.advance(); // consume 'Err'
                _ = try self.consume(.lparen);
                var node = AstNode.init(.literal_err, tok, self.allocator);
                const value = try self.parseExpression(.assignment);
                try node.addChild(value);
                _ = try self.consume(.rparen);
                return node;
            },
            .coptic_identifier => .coptic_id,
            .identifier, .kw_phi, .kw_trinity => blk: {
                // Check if it's underscore placeholder
                const lex = tok.lexeme(self.source);
                if (std.mem.eql(u8, lex, "_")) {
                    break :blk .placeholder;
                }
                // Check for lambda: x => expr
                if (self.peekNext().kind == .op_fat_arrow) {
                    return self.parseLambda();
                }
                break :blk .identifier;
            },
            .lparen => {
                self.advance();
                // Check for lambda: (x, y) => expr
                if (self.check(.identifier) or self.check(.rparen)) {
                    // Could be lambda or grouped expression
                    // Try to parse as lambda params
                    const maybe_lambda = self.tryParseLambdaParams();
                    if (maybe_lambda) |lambda| {
                        return lambda;
                    }
                }
                // Regular grouped expression - need to re-parse
                const expr = try self.parseExpression(.assignment);
                _ = try self.consume(.rparen);
                return expr;
            },
            .lbracket => {
                return self.parseArrayLiteral();
            },
            .lbrace => {
                return self.parseObjectLiteral();
            },
            .kw_if => {
                return self.parseIf();
            },
            .kw_match => {
                return self.parseMatch();
            },
            .kw_func => {
                return self.parseFuncExpr();
            },
            .comment => {
                self.advance();
                return self.parsePrimary();
            },
            else => .identifier,
        };
        self.advance();
        return AstNode.init(kind, tok, self.allocator);
    }

    // Array: '[' (expr (',' expr)*)? ']'
    // List comprehension: '[' expr 'for' ident 'in' expr ('if' expr)? ']'
    fn parseArrayLiteral(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance(); // skip [

        // Empty array
        if (self.check(.rbracket)) {
            self.advance();
            return AstNode.init(.array_literal, tok, self.allocator);
        }

        // Check for spread as first element: [...arr]
        var first_expr: AstNode = undefined;
        if (self.check(.dot_dot_dot)) {
            const spread_tok = self.current;
            self.advance(); // consume ...
            const spread_inner = try self.parseExpression(.assignment);
            first_expr = AstNode.init(.spread_element, spread_tok, self.allocator);
            try first_expr.addChild(spread_inner);
        } else {
            // Parse first expression
            first_expr = try self.parseExpression(.assignment);
        }

        // Check for list comprehension: [expr for x in arr]
        if (self.check(.kw_for)) {
            self.advance(); // consume 'for'
            var node = AstNode.init(.list_comprehension, tok, self.allocator);

            // Add the mapping expression
            try node.addChild(first_expr);

            // Parse iterator variable
            const iter_var = try self.parseIdentifier();
            try node.addChild(iter_var);

            // Consume 'in'
            _ = try self.consume(.kw_in);

            // Parse iterable expression
            const iterable = try self.parseExpression(.assignment);
            try node.addChild(iterable);

            // Optional filter: if condition
            if (self.check(.kw_if)) {
                self.advance(); // consume 'if'
                const filter_expr = try self.parseExpression(.assignment);
                try node.addChild(filter_expr);
            }

            _ = try self.consume(.rbracket);
            return node;
        }

        // Regular array literal (may contain spread elements)
        var node = AstNode.init(.array_literal, tok, self.allocator);
        try node.addChild(first_expr);

        while (self.match(.comma)) {
            if (self.check(.rbracket)) break;

            // Check for spread: ...expr
            if (self.check(.dot_dot_dot)) {
                const spread_tok = self.current;
                self.advance(); // consume ...
                const spread_expr = try self.parseExpression(.assignment);
                var spread_node = AstNode.init(.spread_element, spread_tok, self.allocator);
                try spread_node.addChild(spread_expr);
                try node.addChild(spread_node);
            } else {
                const elem = try self.parseExpression(.assignment);
                try node.addChild(elem);
            }
        }
        _ = try self.consume(.rbracket);
        return node;
    }

    // Object: '{' (key ':' expr | '...' expr (',' ...))* '}'
    fn parseObjectLiteral(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance(); // skip {
        var node = AstNode.init(.object_literal, tok, self.allocator);
        while (!self.check(.rbrace) and !self.check(.eof)) {
            // Check for spread: ...expr
            if (self.check(.dot_dot_dot)) {
                const spread_tok = self.current;
                self.advance(); // consume ...
                const spread_expr = try self.parseExpression(.assignment);
                var spread_node = AstNode.init(.spread_element, spread_tok, self.allocator);
                try spread_node.addChild(spread_expr);
                try node.addChild(spread_node);
                _ = self.match(.comma);
                continue;
            }

            // Parse key (identifier or string)
            const key_tok = self.current;
            if (!self.check(.identifier) and !self.check(.string_literal)) {
                return error.UnexpectedToken;
            }
            self.advance();

            // Expect ':'
            _ = try self.consume(.colon);

            // Parse value
            const value = try self.parseExpression(.assignment);

            // Create field node with key as token and value as child
            var field = AstNode.init(.object_field, key_tok, self.allocator);
            try field.addChild(value);
            try node.addChild(field);

            _ = self.match(.comma);
        }
        _ = try self.consume(.rbrace);
        return node;
    }

    // Anonymous function: fn(args) { body }
    fn parseFuncExpr(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        self.advance(); // skip 'fn'

        var node = AstNode.init(.func_expr, tok, self.allocator);

        // Parse parameters: (a, b, c)
        _ = try self.consume(.lparen);
        while (!self.check(.rparen) and !self.check(.eof)) {
            const param = try self.parseIdentifier();
            try node.addChild(param);
            _ = self.match(.comma);
        }
        _ = try self.consume(.rparen);

        // Parse body: { ... }
        const body = try self.parseBlock();
        try node.addChild(body);

        return node;
    }

    // Lambda: x => expr or (x, y) => expr
    fn parseLambda(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        var node = AstNode.init(.lambda_expr, tok, self.allocator);

        // Single parameter: x => expr
        const param = try self.parseIdentifier();
        try node.addChild(param);

        // Consume =>
        _ = try self.consume(.op_fat_arrow);

        // Parse body expression
        const body = try self.parseExpression(.assignment);
        try node.addChild(body);

        return node;
    }

    // Try to parse (x, y) => expr, returns null if not a lambda
    fn tryParseLambdaParams(self: *Parser) ?AstNode {
        // We're after '(' - save position to backtrack
        const saved_current = self.current;
        const saved_previous = self.previous;
        const saved_pos = self.lexer.pos;
        const saved_line = self.lexer.line;
        const saved_col = self.lexer.column;

        // Try to collect identifiers
        var params: std.ArrayListUnmanaged(AstNode) = .{};
        defer params.deinit(self.allocator);

        // Empty params: () => expr
        if (self.check(.rparen)) {
            self.advance(); // consume )
            if (self.check(.op_fat_arrow)) {
                self.advance(); // consume =>
                var node = AstNode.init(.lambda_expr, saved_current, self.allocator);
                const body = self.parseExpression(.assignment) catch {
                    // Restore and return null
                    self.current = saved_current;
                    self.previous = saved_previous;
                    self.lexer.pos = saved_pos;
                    self.lexer.line = saved_line;
                    self.lexer.column = saved_col;
                    return null;
                };
                node.addChild(body) catch return null;
                return node;
            }
            // Not a lambda, restore
            self.current = saved_current;
            self.previous = saved_previous;
            self.lexer.pos = saved_pos;
            self.lexer.line = saved_line;
            self.lexer.column = saved_col;
            return null;
        }

        // Parse params: (x, y, z)
        while (!self.check(.rparen) and !self.check(.eof)) {
            if (!self.check(.identifier)) {
                // Not a lambda, restore
                self.current = saved_current;
                self.previous = saved_previous;
                self.lexer.pos = saved_pos;
                self.lexer.line = saved_line;
                self.lexer.column = saved_col;
                return null;
            }
            const param = self.parseIdentifier() catch {
                self.current = saved_current;
                self.previous = saved_previous;
                self.lexer.pos = saved_pos;
                self.lexer.line = saved_line;
                self.lexer.column = saved_col;
                return null;
            };
            params.append(self.allocator, param) catch return null;
            _ = self.match(.comma);
        }

        // Consume )
        _ = self.consume(.rparen) catch {
            self.current = saved_current;
            self.previous = saved_previous;
            self.lexer.pos = saved_pos;
            self.lexer.line = saved_line;
            self.lexer.column = saved_col;
            return null;
        };

        // Check for =>
        if (!self.check(.op_fat_arrow)) {
            // Not a lambda, restore
            self.current = saved_current;
            self.previous = saved_previous;
            self.lexer.pos = saved_pos;
            self.lexer.line = saved_line;
            self.lexer.column = saved_col;
            return null;
        }

        self.advance(); // consume =>

        // Parse body
        const body = self.parseExpression(.assignment) catch {
            self.current = saved_current;
            self.previous = saved_previous;
            self.lexer.pos = saved_pos;
            self.lexer.line = saved_line;
            self.lexer.column = saved_col;
            return null;
        };

        // Build lambda node
        var node = AstNode.init(.lambda_expr, saved_current, self.allocator);
        for (params.items) |param| {
            node.addChild(param) catch return null;
        }
        node.addChild(body) catch return null;

        return node;
    }

    fn parseIdentifier(self: *Parser) ParseError!AstNode {
        const tok = self.current;
        if (self.check(.identifier) or self.check(.kw_phi) or self.check(.kw_trinity) or self.check(.coptic_identifier)) {
            self.advance();
            return AstNode.init(.identifier, tok, self.allocator);
        }
        return error.UnexpectedToken;
    }
};

// Tests
test "parser const" {
    var parser = Parser.init("const x = 42", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.kind == .program);
    try std.testing.expect(ast.children.items.len > 0);
    try std.testing.expect(ast.children.items[0].kind == .const_decl);
}

test "parser binary expr" {
    var parser = Parser.init("1 + 2 * 3", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .binary_expr);
}

test "parser func with params" {
    var parser = Parser.init("func add(a, b) { return a + b }", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .func_decl);
}

test "parser unary" {
    var parser = Parser.init("-42", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .unary_expr);
}

test "parser call" {
    var parser = Parser.init("foo(1, 2)", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .call_expr);
}

test "parser trit" {
    var parser = Parser.init("△", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .literal_trit);
}

test "phi" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}

test "parser if" {
    var parser = Parser.init("if x > 0 { 1 } else { 2 }", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .if_expr);
    try std.testing.expect(ast.children.items[0].children.items.len >= 2);
}

test "parser while" {
    var parser = Parser.init("while x < 10 { x }", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .while_stmt);
}

test "parser for" {
    var parser = Parser.init("for i in arr { i }", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .for_stmt);
}

test "parser array" {
    var parser = Parser.init("[1, 2, 3]", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .array_literal);
    try std.testing.expect(ast.children.items[0].children.items.len == 3);
}

test "parser index" {
    var parser = Parser.init("arr[0]", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .index_expr);
}

test "parser string" {
    var parser = Parser.init("\"hello\"", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .literal_string);
}

test "parser comparison" {
    var parser = Parser.init("x < 10 && y > 5", std.testing.allocator);
    var ast = try parser.parseProgram();
    defer ast.deinit();
    try std.testing.expect(ast.children.items[0].kind == .binary_expr);
}
