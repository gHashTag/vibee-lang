//! VIBEE Integration Test: .vibee → tokens → validation
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_lexer = @import("coptic_lexer.zig");

const Lexer = coptic_lexer.Lexer;
const TokenKind = coptic_lexer.TokenKind;

test "integration: tokenize simple vibee-like code" {
    const source =
        \\const phi = 1.618
        \\const trinity = 27
    ;
    
    var lexer = Lexer.init(source);
    
    // const
    var tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.kw_const, tok.kind);
    
    // phi (keyword)
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.kw_phi, tok.kind);
    
    // =
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.op_eq, tok.kind);
    
    // 1.618
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.float_literal, tok.kind);
    
    // newline
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.newline, tok.kind);
    
    // const
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.kw_const, tok.kind);
    
    // trinity (keyword)
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.kw_trinity, tok.kind);
}

test "integration: tokenize coptic identifiers" {
    const source = "ⲁ ⲃ ⲅ";
    var lexer = Lexer.init(source);
    
    var tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.coptic_identifier, tok.kind);
    
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.coptic_identifier, tok.kind);
    
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.coptic_identifier, tok.kind);
}

test "integration: tokenize trit literals" {
    const source = "△ ○ ▽";
    var lexer = Lexer.init(source);
    
    try std.testing.expectEqual(TokenKind.trit_true, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.trit_unknown, lexer.nextToken().kind);
    try std.testing.expectEqual(TokenKind.trit_false, lexer.nextToken().kind);
}

test "integration: tokenize function definition" {
    const source =
        \\func calculate(x) {
        \\    return x * phi
        \\}
    ;
    
    var lexer = Lexer.init(source);
    
    // func
    var tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.kw_func, tok.kind);
    
    // calculate
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.identifier, tok.kind);
    
    // (
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.lparen, tok.kind);
    
    // x
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.identifier, tok.kind);
    
    // )
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.rparen, tok.kind);
    
    // {
    tok = lexer.nextToken();
    try std.testing.expectEqual(TokenKind.lbrace, tok.kind);
}

test "integration: full tokenization" {
    const source = "const x = 42";
    const allocator = std.testing.allocator;
    
    const tokens = try Lexer.tokenize(source, allocator);
    defer allocator.free(tokens);
    
    try std.testing.expect(tokens.len >= 4);
    try std.testing.expectEqual(TokenKind.kw_const, tokens[0].kind);
    try std.testing.expectEqual(TokenKind.identifier, tokens[1].kind);
    try std.testing.expectEqual(TokenKind.op_eq, tokens[2].kind);
    try std.testing.expectEqual(TokenKind.int_literal, tokens[3].kind);
}

test "integration: coptic index mapping" {
    // ⲁ = U+2C80 = index 0
    try std.testing.expectEqual(@as(?u8, 0), coptic_lexer.copticToIndex(0x2C80));
    // ⲃ = U+2C81 = index 1
    try std.testing.expectEqual(@as(?u8, 1), coptic_lexer.copticToIndex(0x2C81));
    // ⲱ = U+2CB1 = index 49 (outside 27)
    try std.testing.expectEqual(@as(?u8, 49), coptic_lexer.copticToIndex(0x2CB1));
}
