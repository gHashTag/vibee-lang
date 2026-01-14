// ============================================================================
// VIBEEC AST (Abstract Syntax Tree)
// AST nodes for VIBEE language
// ============================================================================

const std = @import("std");
const lexer = @import("lexer.zig");

// ============================================================================
// AST NODE TYPES
// ============================================================================

pub const NodeType = enum {
    // Program
    Program,
    
    // Declarations
    FunctionDecl,
    ConstDecl,
    VarDecl,
    LetDecl,
    TypeDecl,
    StructDecl,
    EnumDecl,
    TestDecl,
    ImportDecl,
    
    // Statements
    ExprStmt,
    ReturnStmt,
    IfStmt,
    ForStmt,
    WhileStmt,
    Block,
    
    // Expressions
    BinaryExpr,
    UnaryExpr,
    CallExpr,
    IndexExpr,
    MemberExpr,
    CastExpr,
    AssignExpr,
    TernaryExpr,
    
    // Literals
    IntLiteral,
    FloatLiteral,
    StringLiteral,
    BoolLiteral,
    NoneLiteral,
    ArrayLiteral,
    
    // Other
    Identifier,
    Parameter,
    TypeAnnotation,
    GenericParam,
    NativeCall,
};

// ============================================================================
// AST NODES
// ============================================================================

pub const Node = struct {
    node_type: NodeType,
    data: NodeData,
    line: u32,
    column: u32,
};

pub const NodeData = union {
    program: ProgramNode,
    function_decl: FunctionDeclNode,
    const_decl: ConstDeclNode,
    var_decl: VarDeclNode,
    let_decl: LetDeclNode,
    test_decl: TestDeclNode,
    import_decl: ImportDeclNode,
    return_stmt: ReturnStmtNode,
    if_stmt: IfStmtNode,
    for_stmt: ForStmtNode,
    while_stmt: WhileStmtNode,
    block: BlockNode,
    binary_expr: BinaryExprNode,
    unary_expr: UnaryExprNode,
    call_expr: CallExprNode,
    index_expr: IndexExprNode,
    member_expr: MemberExprNode,
    cast_expr: CastExprNode,
    assign_expr: AssignExprNode,
    ternary_expr: TernaryExprNode,
    int_literal: IntLiteralNode,
    float_literal: FloatLiteralNode,
    string_literal: StringLiteralNode,
    bool_literal: BoolLiteralNode,
    array_literal: ArrayLiteralNode,
    identifier: IdentifierNode,
    parameter: ParameterNode,
    type_annotation: TypeAnnotationNode,
    native_call: NativeCallNode,
    none: void,
};

pub const ProgramNode = struct {
    declarations: []*Node,
};

pub const FunctionDeclNode = struct {
    name: []const u8,
    params: []ParameterNode,
    return_type: ?*Node,
    body: ?*Node,
    is_pub: bool,
    generic_params: [][]const u8,
    doc_comment: ?[]const u8,
};

pub const ConstDeclNode = struct {
    name: []const u8,
    type_annotation: ?*Node,
    value: *Node,
    doc_comment: ?[]const u8,
};

pub const VarDeclNode = struct {
    name: []const u8,
    type_annotation: ?*Node,
    value: ?*Node,
};

pub const LetDeclNode = struct {
    name: []const u8,
    type_annotation: ?*Node,
    value: *Node,
};

pub const TestDeclNode = struct {
    name: []const u8,
    body: *Node,
};

pub const ImportDeclNode = struct {
    path: []const u8,
};

pub const ReturnStmtNode = struct {
    value: ?*Node,
};

pub const IfStmtNode = struct {
    condition: *Node,
    then_branch: *Node,
    else_branch: ?*Node,
};

pub const ForStmtNode = struct {
    variable: []const u8,
    iterable: *Node,
    body: *Node,
};

pub const WhileStmtNode = struct {
    condition: *Node,
    body: *Node,
};

pub const BlockNode = struct {
    statements: []*Node,
};

pub const BinaryExprNode = struct {
    left: *Node,
    operator: BinaryOp,
    right: *Node,
};

pub const BinaryOp = enum {
    Add,        // +
    Sub,        // -
    Mul,        // *
    Div,        // /
    Mod,        // %
    And,        // &&
    Or,         // ||
    BitAnd,     // &
    BitOr,      // |
    BitXor,     // ^
    Shl,        // <<
    Shr,        // >>
    Eq,         // ==
    Ne,         // !=
    Lt,         // <
    Le,         // <=
    Gt,         // >
    Ge,         // >=
    Range,      // ..
    RangeInc,   // ..=
};

pub const UnaryExprNode = struct {
    operator: UnaryOp,
    operand: *Node,
};

pub const UnaryOp = enum {
    Neg,    // -
    Not,    // !
    BitNot, // ~
};

pub const CallExprNode = struct {
    callee: *Node,
    arguments: []*Node,
};

pub const IndexExprNode = struct {
    object: *Node,
    index: *Node,
};

pub const MemberExprNode = struct {
    object: *Node,
    member: []const u8,
};

pub const CastExprNode = struct {
    value: *Node,
    target_type: *Node,
};

pub const AssignExprNode = struct {
    target: *Node,
    operator: AssignOp,
    value: *Node,
};

pub const AssignOp = enum {
    Assign,     // =
    AddAssign,  // +=
    SubAssign,  // -=
    MulAssign,  // *=
    DivAssign,  // /=
    ModAssign,  // %=
    AndAssign,  // &=
    OrAssign,   // |=
    XorAssign,  // ^=
    ShlAssign,  // <<=
    ShrAssign,  // >>=
};

pub const TernaryExprNode = struct {
    condition: *Node,
    then_expr: *Node,
    else_expr: *Node,
};

pub const IntLiteralNode = struct {
    value: i64,
    raw: []const u8,
};

pub const FloatLiteralNode = struct {
    value: f64,
    raw: []const u8,
};

pub const StringLiteralNode = struct {
    value: []const u8,
    raw: []const u8,
};

pub const BoolLiteralNode = struct {
    value: bool,
};

pub const ArrayLiteralNode = struct {
    elements: []*Node,
};

pub const IdentifierNode = struct {
    name: []const u8,
};

pub const ParameterNode = struct {
    name: []const u8,
    type_annotation: ?*Node,
    default_value: ?*Node,
};

pub const TypeAnnotationNode = struct {
    name: []const u8,
    generic_args: []*Node,
    is_optional: bool,
    is_array: bool,
};

pub const NativeCallNode = struct {
    name: []const u8,
    arguments: []*Node,
};

// ============================================================================
// AST BUILDER HELPERS
// ============================================================================

pub const AstBuilder = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) AstBuilder {
        return AstBuilder{ .allocator = allocator };
    }
    
    pub fn createNode(self: *AstBuilder, node_type: NodeType, data: NodeData, line: u32, column: u32) !*Node {
        const node = try self.allocator.create(Node);
        node.* = Node{
            .node_type = node_type,
            .data = data,
            .line = line,
            .column = column,
        };
        return node;
    }
    
    pub fn createProgram(self: *AstBuilder, declarations: []*Node) !*Node {
        return self.createNode(.Program, .{ .program = .{ .declarations = declarations } }, 1, 1);
    }
    
    pub fn createIntLiteral(self: *AstBuilder, value: i64, raw: []const u8, line: u32, col: u32) !*Node {
        return self.createNode(.IntLiteral, .{ .int_literal = .{ .value = value, .raw = raw } }, line, col);
    }
    
    pub fn createFloatLiteral(self: *AstBuilder, value: f64, raw: []const u8, line: u32, col: u32) !*Node {
        return self.createNode(.FloatLiteral, .{ .float_literal = .{ .value = value, .raw = raw } }, line, col);
    }
    
    pub fn createStringLiteral(self: *AstBuilder, value: []const u8, raw: []const u8, line: u32, col: u32) !*Node {
        return self.createNode(.StringLiteral, .{ .string_literal = .{ .value = value, .raw = raw } }, line, col);
    }
    
    pub fn createBoolLiteral(self: *AstBuilder, value: bool, line: u32, col: u32) !*Node {
        return self.createNode(.BoolLiteral, .{ .bool_literal = .{ .value = value } }, line, col);
    }
    
    pub fn createIdentifier(self: *AstBuilder, name: []const u8, line: u32, col: u32) !*Node {
        return self.createNode(.Identifier, .{ .identifier = .{ .name = name } }, line, col);
    }
    
    pub fn createBinaryExpr(self: *AstBuilder, left: *Node, op: BinaryOp, right: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.BinaryExpr, .{ .binary_expr = .{ .left = left, .operator = op, .right = right } }, line, col);
    }
    
    pub fn createUnaryExpr(self: *AstBuilder, op: UnaryOp, operand: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.UnaryExpr, .{ .unary_expr = .{ .operator = op, .operand = operand } }, line, col);
    }
    
    pub fn createCallExpr(self: *AstBuilder, callee: *Node, args: []*Node, line: u32, col: u32) !*Node {
        return self.createNode(.CallExpr, .{ .call_expr = .{ .callee = callee, .arguments = args } }, line, col);
    }
    
    pub fn createBlock(self: *AstBuilder, statements: []*Node, line: u32, col: u32) !*Node {
        return self.createNode(.Block, .{ .block = .{ .statements = statements } }, line, col);
    }
    
    pub fn createIfStmt(self: *AstBuilder, condition: *Node, then_branch: *Node, else_branch: ?*Node, line: u32, col: u32) !*Node {
        return self.createNode(.IfStmt, .{ .if_stmt = .{ .condition = condition, .then_branch = then_branch, .else_branch = else_branch } }, line, col);
    }
    
    pub fn createForStmt(self: *AstBuilder, variable: []const u8, iterable: *Node, body: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.ForStmt, .{ .for_stmt = .{ .variable = variable, .iterable = iterable, .body = body } }, line, col);
    }
    
    pub fn createWhileStmt(self: *AstBuilder, condition: *Node, body: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.WhileStmt, .{ .while_stmt = .{ .condition = condition, .body = body } }, line, col);
    }
    
    pub fn createReturnStmt(self: *AstBuilder, value: ?*Node, line: u32, col: u32) !*Node {
        return self.createNode(.ReturnStmt, .{ .return_stmt = .{ .value = value } }, line, col);
    }
    
    pub fn createLetDecl(self: *AstBuilder, name: []const u8, type_ann: ?*Node, value: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.LetDecl, .{ .let_decl = .{ .name = name, .type_annotation = type_ann, .value = value } }, line, col);
    }
    
    pub fn createVarDecl(self: *AstBuilder, name: []const u8, type_ann: ?*Node, value: ?*Node, line: u32, col: u32) !*Node {
        return self.createNode(.VarDecl, .{ .var_decl = .{ .name = name, .type_annotation = type_ann, .value = value } }, line, col);
    }
    
    pub fn createConstDecl(self: *AstBuilder, name: []const u8, type_ann: ?*Node, value: *Node, doc: ?[]const u8, line: u32, col: u32) !*Node {
        return self.createNode(.ConstDecl, .{ .const_decl = .{ .name = name, .type_annotation = type_ann, .value = value, .doc_comment = doc } }, line, col);
    }
    
    pub fn createFunctionDecl(self: *AstBuilder, name: []const u8, params: []ParameterNode, return_type: ?*Node, body: ?*Node, is_pub: bool, generics: [][]const u8, doc: ?[]const u8, line: u32, col: u32) !*Node {
        return self.createNode(.FunctionDecl, .{ .function_decl = .{
            .name = name,
            .params = params,
            .return_type = return_type,
            .body = body,
            .is_pub = is_pub,
            .generic_params = generics,
            .doc_comment = doc,
        } }, line, col);
    }
    
    pub fn createTestDecl(self: *AstBuilder, name: []const u8, body: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.TestDecl, .{ .test_decl = .{ .name = name, .body = body } }, line, col);
    }
    
    pub fn createTypeAnnotation(self: *AstBuilder, name: []const u8, generics: []*Node, is_optional: bool, is_array: bool, line: u32, col: u32) !*Node {
        return self.createNode(.TypeAnnotation, .{ .type_annotation = .{
            .name = name,
            .generic_args = generics,
            .is_optional = is_optional,
            .is_array = is_array,
        } }, line, col);
    }
    
    pub fn createNativeCall(self: *AstBuilder, name: []const u8, args: []*Node, line: u32, col: u32) !*Node {
        return self.createNode(.NativeCall, .{ .native_call = .{ .name = name, .arguments = args } }, line, col);
    }
    
    pub fn createMemberExpr(self: *AstBuilder, object: *Node, member: []const u8, line: u32, col: u32) !*Node {
        return self.createNode(.MemberExpr, .{ .member_expr = .{ .object = object, .member = member } }, line, col);
    }
    
    pub fn createIndexExpr(self: *AstBuilder, object: *Node, index: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.IndexExpr, .{ .index_expr = .{ .object = object, .index = index } }, line, col);
    }
    
    pub fn createAssignExpr(self: *AstBuilder, target: *Node, op: AssignOp, value: *Node, line: u32, col: u32) !*Node {
        return self.createNode(.AssignExpr, .{ .assign_expr = .{ .target = target, .operator = op, .value = value } }, line, col);
    }
    
    pub fn createArrayLiteral(self: *AstBuilder, elements: []*Node, line: u32, col: u32) !*Node {
        return self.createNode(.ArrayLiteral, .{ .array_literal = .{ .elements = elements } }, line, col);
    }
    
    pub fn createNoneLiteral(self: *AstBuilder, line: u32, col: u32) !*Node {
        return self.createNode(.NoneLiteral, .{ .none = {} }, line, col);
    }
};

// ============================================================================
// AST PRINTER (for debugging)
// ============================================================================

pub fn printAst(node: *Node, writer: anytype, indent: usize) !void {
    const spaces = "                                        ";
    const prefix = spaces[0..@min(indent * 2, spaces.len)];
    
    try writer.print("{s}{s}", .{ prefix, @tagName(node.node_type) });
    
    switch (node.node_type) {
        .Program => {
            try writer.print("\n", .{});
            for (node.data.program.declarations) |decl| {
                try printAst(decl, writer, indent + 1);
            }
        },
        .FunctionDecl => {
            const f = node.data.function_decl;
            try writer.print(" {s}(", .{f.name});
            for (f.params, 0..) |p, i| {
                if (i > 0) try writer.print(", ", .{});
                try writer.print("{s}", .{p.name});
            }
            try writer.print(")\n", .{});
            if (f.body) |body| {
                try printAst(body, writer, indent + 1);
            }
        },
        .ConstDecl => {
            try writer.print(" {s}\n", .{node.data.const_decl.name});
            try printAst(node.data.const_decl.value, writer, indent + 1);
        },
        .LetDecl => {
            try writer.print(" {s}\n", .{node.data.let_decl.name});
            try printAst(node.data.let_decl.value, writer, indent + 1);
        },
        .VarDecl => {
            try writer.print(" {s}\n", .{node.data.var_decl.name});
            if (node.data.var_decl.value) |v| {
                try printAst(v, writer, indent + 1);
            }
        },
        .Block => {
            try writer.print("\n", .{});
            for (node.data.block.statements) |stmt| {
                try printAst(stmt, writer, indent + 1);
            }
        },
        .BinaryExpr => {
            try writer.print(" {s}\n", .{@tagName(node.data.binary_expr.operator)});
            try printAst(node.data.binary_expr.left, writer, indent + 1);
            try printAst(node.data.binary_expr.right, writer, indent + 1);
        },
        .UnaryExpr => {
            try writer.print(" {s}\n", .{@tagName(node.data.unary_expr.operator)});
            try printAst(node.data.unary_expr.operand, writer, indent + 1);
        },
        .CallExpr => {
            try writer.print("\n", .{});
            try printAst(node.data.call_expr.callee, writer, indent + 1);
            for (node.data.call_expr.arguments) |arg| {
                try printAst(arg, writer, indent + 1);
            }
        },
        .IntLiteral => {
            try writer.print(" {d}\n", .{node.data.int_literal.value});
        },
        .FloatLiteral => {
            try writer.print(" {d}\n", .{node.data.float_literal.value});
        },
        .StringLiteral => {
            try writer.print(" {s}\n", .{node.data.string_literal.raw});
        },
        .BoolLiteral => {
            try writer.print(" {}\n", .{node.data.bool_literal.value});
        },
        .Identifier => {
            try writer.print(" {s}\n", .{node.data.identifier.name});
        },
        .IfStmt => {
            try writer.print("\n", .{});
            try printAst(node.data.if_stmt.condition, writer, indent + 1);
            try printAst(node.data.if_stmt.then_branch, writer, indent + 1);
            if (node.data.if_stmt.else_branch) |eb| {
                try printAst(eb, writer, indent + 1);
            }
        },
        .ForStmt => {
            try writer.print(" {s}\n", .{node.data.for_stmt.variable});
            try printAst(node.data.for_stmt.iterable, writer, indent + 1);
            try printAst(node.data.for_stmt.body, writer, indent + 1);
        },
        .WhileStmt => {
            try writer.print("\n", .{});
            try printAst(node.data.while_stmt.condition, writer, indent + 1);
            try printAst(node.data.while_stmt.body, writer, indent + 1);
        },
        .ReturnStmt => {
            try writer.print("\n", .{});
            if (node.data.return_stmt.value) |v| {
                try printAst(v, writer, indent + 1);
            }
        },
        .TestDecl => {
            try writer.print(" {s}\n", .{node.data.test_decl.name});
            try printAst(node.data.test_decl.body, writer, indent + 1);
        },
        else => {
            try writer.print("\n", .{});
        },
    }
}
