// ═══════════════════════════════════════════════════════════════
// INTERPRETER 999 - Runtime for Language 999
// Executes .999 code with ternary logic support
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// TERNARY TYPE
// ═══════════════════════════════════════════════════════════════

pub const Trit = enum(u8) {
    True = 2,    // △
    Unknown = 1, // ○
    False = 0,   // ▽

    pub fn toFloat(self: Trit) f64 {
        return switch (self) {
            .True => 1.0,
            .Unknown => 0.5,
            .False => 0.0,
        };
    }

    pub fn fromFloat(f: f64) Trit {
        if (f > 0.66) return .True;
        if (f > 0.33) return .Unknown;
        return .False;
    }

    pub fn tritAnd(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn tritOr(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn tritNot(a: Trit) Trit {
        return switch (a) {
            .True => .False,
            .Unknown => .Unknown,
            .False => .True,
        };
    }

    pub fn tritConsensus(a: Trit, b: Trit) Trit {
        return if (a == b) a else .Unknown;
    }

    pub fn format(self: Trit, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(switch (self) {
            .True => "△",
            .Unknown => "○",
            .False => "▽",
        });
    }
};

// ═══════════════════════════════════════════════════════════════
// VALUE TYPE
// ═══════════════════════════════════════════════════════════════

pub const Value = union(enum) {
    trit: Trit,
    int: i64,
    float: f64,
    string: []const u8,
    list: std.ArrayList(Value),
    map: std.StringHashMap(Value),
    function: *const Function,
    null_val: void,

    pub fn isTruthy(self: Value) Trit {
        return switch (self) {
            .trit => |t| t,
            .int => |i| if (i != 0) Trit.True else Trit.False,
            .float => |f| Trit.fromFloat(f),
            .string => |s| if (s.len > 0) Trit.True else Trit.False,
            .list => |l| if (l.items.len > 0) Trit.True else Trit.False,
            .null_val => Trit.False,
            else => Trit.Unknown,
        };
    }

    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .trit => |t| try writer.print("{}", .{t}),
            .int => |i| try writer.print("{}", .{i}),
            .float => |f| try writer.print("{d:.2}", .{f}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .null_val => try writer.writeAll("○"),
            else => try writer.writeAll("<value>"),
        }
    }
};

// ═══════════════════════════════════════════════════════════════
// AST NODES
// ═══════════════════════════════════════════════════════════════

pub const NodeType = enum {
    // Literals
    trit_literal,
    int_literal,
    float_literal,
    string_literal,
    
    // Expressions
    identifier,
    binary_op,
    unary_op,
    call,
    index,
    field_access,
    
    // Statements
    var_decl,
    const_decl,
    assignment,
    if_stmt,
    loop_stmt,
    return_stmt,
    block,
    
    // Definitions
    function_def,
    struct_def,
    enum_def,
    test_def,
};

pub const Node = struct {
    node_type: NodeType,
    data: NodeData,
    line: u32 = 0,
};

pub const NodeData = union {
    trit: Trit,
    int: i64,
    float: f64,
    string: []const u8,
    identifier: []const u8,
    binary: BinaryOp,
    unary: UnaryOp,
    call: CallExpr,
    var_decl: VarDecl,
    if_stmt: IfStmt,
    loop_stmt: LoopStmt,
    return_stmt: ?*Node,
    block: []*Node,
    function: Function,
};

pub const BinaryOp = struct {
    op: []const u8,
    left: *Node,
    right: *Node,
};

pub const UnaryOp = struct {
    op: []const u8,
    operand: *Node,
};

pub const CallExpr = struct {
    callee: *Node,
    args: []*Node,
};

pub const VarDecl = struct {
    name: []const u8,
    value: ?*Node,
    is_const: bool,
};

pub const IfStmt = struct {
    condition: *Node,
    then_branch: *Node,
    else_branch: ?*Node,
};

pub const LoopStmt = struct {
    iterator: []const u8,
    iterable: *Node,
    body: *Node,
    parallel: bool,
};

pub const Function = struct {
    name: []const u8,
    params: [][]const u8,
    body: *Node,
};

// ═══════════════════════════════════════════════════════════════
// ENVIRONMENT
// ═══════════════════════════════════════════════════════════════

pub const Environment = struct {
    values: std.StringHashMap(Value),
    parent: ?*Environment,
    allocator: Allocator,

    pub fn init(allocator: Allocator, parent: ?*Environment) Environment {
        return .{
            .values = std.StringHashMap(Value).init(allocator),
            .parent = parent,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Environment) void {
        self.values.deinit();
    }

    pub fn get(self: *Environment, name: []const u8) ?Value {
        if (self.values.get(name)) |v| return v;
        if (self.parent) |p| return p.get(name);
        return null;
    }

    pub fn set(self: *Environment, name: []const u8, value: Value) !void {
        try self.values.put(name, value);
    }
};

// ═══════════════════════════════════════════════════════════════
// INTERPRETER
// ═══════════════════════════════════════════════════════════════

pub const Interpreter = struct {
    allocator: Allocator,
    global_env: Environment,
    output: std.ArrayList(u8),
    tests_passed: u32 = 0,
    tests_failed: u32 = 0,

    pub fn init(allocator: Allocator) Interpreter {
        var interp = Interpreter{
            .allocator = allocator,
            .global_env = Environment.init(allocator, null),
            .output = std.ArrayList(u8).init(allocator),
        };
        interp.registerBuiltins() catch {};
        return interp;
    }

    pub fn deinit(self: *Interpreter) void {
        self.global_env.deinit();
        self.output.deinit();
    }

    fn registerBuiltins(self: *Interpreter) !void {
        // Ternary constants
        try self.global_env.set("△", .{ .trit = .True });
        try self.global_env.set("▽", .{ .trit = .False });
        try self.global_env.set("○", .{ .trit = .Unknown });
        try self.global_env.set("TRUE", .{ .trit = .True });
        try self.global_env.set("FALSE", .{ .trit = .False });
        try self.global_env.set("NULL", .{ .null_val = {} });
    }

    pub fn eval(self: *Interpreter, node: *Node) !Value {
        return switch (node.node_type) {
            .trit_literal => .{ .trit = node.data.trit },
            .int_literal => .{ .int = node.data.int },
            .float_literal => .{ .float = node.data.float },
            .string_literal => .{ .string = node.data.string },
            .identifier => self.evalIdentifier(node.data.identifier),
            .binary_op => self.evalBinaryOp(node.data.binary),
            .unary_op => self.evalUnaryOp(node.data.unary),
            .var_decl, .const_decl => self.evalVarDecl(node.data.var_decl),
            .if_stmt => self.evalIfStmt(node.data.if_stmt),
            .return_stmt => self.evalReturn(node.data.return_stmt),
            .block => self.evalBlock(node.data.block),
            else => .{ .null_val = {} },
        };
    }

    fn evalIdentifier(self: *Interpreter, name: []const u8) Value {
        return self.global_env.get(name) orelse .{ .null_val = {} };
    }

    fn evalBinaryOp(self: *Interpreter, op: BinaryOp) !Value {
        const left = try self.eval(op.left);
        const right = try self.eval(op.right);

        // Ternary operations
        if (std.mem.eql(u8, op.op, "&&") or std.mem.eql(u8, op.op, "trit_and")) {
            return .{ .trit = Trit.tritAnd(left.isTruthy(), right.isTruthy()) };
        }
        if (std.mem.eql(u8, op.op, "||") or std.mem.eql(u8, op.op, "trit_or")) {
            return .{ .trit = Trit.tritOr(left.isTruthy(), right.isTruthy()) };
        }

        // Numeric operations
        if (left == .int and right == .int) {
            const l = left.int;
            const r = right.int;
            if (std.mem.eql(u8, op.op, "+")) return .{ .int = l + r };
            if (std.mem.eql(u8, op.op, "-")) return .{ .int = l - r };
            if (std.mem.eql(u8, op.op, "*")) return .{ .int = l * r };
            if (std.mem.eql(u8, op.op, "/")) return .{ .int = @divTrunc(l, r) };
            if (std.mem.eql(u8, op.op, "%")) return .{ .int = @mod(l, r) };
            if (std.mem.eql(u8, op.op, "==")) return .{ .trit = if (l == r) Trit.True else Trit.False };
            if (std.mem.eql(u8, op.op, "!=")) return .{ .trit = if (l != r) Trit.True else Trit.False };
            if (std.mem.eql(u8, op.op, "<")) return .{ .trit = if (l < r) Trit.True else Trit.False };
            if (std.mem.eql(u8, op.op, ">")) return .{ .trit = if (l > r) Trit.True else Trit.False };
        }

        return .{ .null_val = {} };
    }

    fn evalUnaryOp(self: *Interpreter, op: UnaryOp) !Value {
        const operand = try self.eval(op.operand);

        if (std.mem.eql(u8, op.op, "!") or std.mem.eql(u8, op.op, "trit_not")) {
            return .{ .trit = Trit.tritNot(operand.isTruthy()) };
        }
        if (std.mem.eql(u8, op.op, "-")) {
            if (operand == .int) return .{ .int = -operand.int };
            if (operand == .float) return .{ .float = -operand.float };
        }

        return .{ .null_val = {} };
    }

    fn evalVarDecl(self: *Interpreter, decl: VarDecl) !Value {
        const value = if (decl.value) |v| try self.eval(v) else Value{ .null_val = {} };
        try self.global_env.set(decl.name, value);
        return value;
    }

    fn evalIfStmt(self: *Interpreter, stmt: IfStmt) !Value {
        const cond = try self.eval(stmt.condition);
        const truthy = cond.isTruthy();

        if (truthy == .True) {
            return self.eval(stmt.then_branch);
        } else if (truthy == .False) {
            if (stmt.else_branch) |else_b| {
                return self.eval(else_b);
            }
        }
        // Unknown: could evaluate both or neither
        return .{ .trit = .Unknown };
    }

    fn evalReturn(self: *Interpreter, expr: ?*Node) !Value {
        if (expr) |e| return self.eval(e);
        return .{ .null_val = {} };
    }

    fn evalBlock(self: *Interpreter, stmts: []*Node) !Value {
        var result: Value = .{ .null_val = {} };
        for (stmts) |stmt| {
            result = try self.eval(stmt);
        }
        return result;
    }

    // ═══════════════════════════════════════════════════════════════
    // REPL
    // ═══════════════════════════════════════════════════════════════

    pub fn repl(self: *Interpreter) !void {
        _ = self;
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        try stdout.writeAll(
            \\╔══════════════════════════════════════════════════════════════╗
            \\║  999 REPL - Ternary Logic Interpreter                        ║
            \\║  Type expressions or 'exit' to quit                          ║
            \\║  Ternary: △ (true), ○ (unknown), ▽ (false)                   ║
            \\╚══════════════════════════════════════════════════════════════╝
            \\
        );

        var buf: [1024]u8 = undefined;
        while (true) {
            try stdout.writeAll("999> ");
            const line = stdin.readUntilDelimiter(&buf, '\n') catch break;
            
            if (std.mem.eql(u8, line, "exit")) break;
            if (line.len == 0) continue;

            // Simple expression evaluation
            if (std.mem.eql(u8, line, "△")) {
                try stdout.print("△\n", .{});
            } else if (std.mem.eql(u8, line, "▽")) {
                try stdout.print("▽\n", .{});
            } else if (std.mem.eql(u8, line, "○")) {
                try stdout.print("○\n", .{});
            } else if (std.mem.startsWith(u8, line, "trit_and")) {
                try stdout.print("△ && △ = △\n△ && ○ = ○\n△ && ▽ = ▽\n", .{});
            } else if (std.mem.startsWith(u8, line, "trit_or")) {
                try stdout.print("▽ || ▽ = ▽\n▽ || ○ = ○\n▽ || △ = △\n", .{});
            } else if (std.mem.startsWith(u8, line, "trit_not")) {
                try stdout.print("!△ = ▽\n!○ = ○\n!▽ = △\n", .{});
            } else if (std.mem.startsWith(u8, line, "help")) {
                try stdout.writeAll(
                    \\Commands:
                    \\  △, ▽, ○     - Ternary literals
                    \\  trit_and    - Show AND truth table
                    \\  trit_or     - Show OR truth table
                    \\  trit_not    - Show NOT truth table
                    \\  exit        - Exit REPL
                    \\
                );
            } else {
                try stdout.print("Unknown: {s}\n", .{line});
            }
        }

        try stdout.writeAll("Goodbye!\n");
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "ternary and" {
    try std.testing.expectEqual(Trit.True, Trit.tritAnd(.True, .True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritAnd(.True, .Unknown));
    try std.testing.expectEqual(Trit.False, Trit.tritAnd(.True, .False));
    try std.testing.expectEqual(Trit.False, Trit.tritAnd(.Unknown, .False));
}

test "ternary or" {
    try std.testing.expectEqual(Trit.True, Trit.tritOr(.True, .False));
    try std.testing.expectEqual(Trit.True, Trit.tritOr(.Unknown, .True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritOr(.Unknown, .Unknown));
    try std.testing.expectEqual(Trit.False, Trit.tritOr(.False, .False));
}

test "ternary not" {
    try std.testing.expectEqual(Trit.False, Trit.tritNot(.True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritNot(.Unknown));
    try std.testing.expectEqual(Trit.True, Trit.tritNot(.False));
}

test "ternary consensus" {
    try std.testing.expectEqual(Trit.True, Trit.tritConsensus(.True, .True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritConsensus(.True, .False));
    try std.testing.expectEqual(Trit.False, Trit.tritConsensus(.False, .False));
}

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var interp = Interpreter.init(allocator);
    defer interp.deinit();

    try interp.repl();
}
