//! VIBEE AST ↔ E-Graph Bridge
//! Преобразование AstNode в E-Classes и обратно после оптимизации
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_parser = @import("coptic_parser_real.zig");
const egraph = @import("egraph.zig");

const AstNode = coptic_parser.AstNode;
const NodeKind = coptic_parser.NodeKind;
const EGraph = egraph.EGraph;
const ENode = egraph.ENode;
const ENodeOp = egraph.ENodeOp;
const EClassId = egraph.EClassId;

pub const Bridge = struct {
    allocator: std.mem.Allocator,
    graph: *EGraph,

    pub fn init(allocator: std.mem.Allocator, graph: *EGraph) Bridge {
        return .{
            .allocator = allocator,
            .graph = graph,
        };
    }

    /// Рекурсивно добавляет AST узел в E-graph
    pub fn astToEGraph(self: *Bridge, node: *const AstNode) !EClassId {
        return switch (node.kind) {
            .literal_int => {
                const val = std.fmt.parseInt(i64, node.token.lexeme(self.graph.source), 10) catch 0;
                return try self.graph.add(ENode.constInt(val));
            },
            .literal_float => {
                const val = std.fmt.parseFloat(f64, node.token.lexeme(self.graph.source)) catch 0.0;
                return try self.graph.add(ENode.constFloat(val));
            },
            .identifier => {
                const name = node.token.lexeme(self.graph.source);
                if (std.mem.eql(u8, name, "phi")) return try self.graph.add(ENode.constPhi());
                if (std.mem.eql(u8, name, "pi")) return try self.graph.add(ENode.constPi());
                if (std.mem.eql(u8, name, "e")) return try self.graph.add(ENode.constE());

                var enode = ENode.init(.var_ref);
                enode.var_name = name;
                return try self.graph.add(enode);
            },
            .binary_expr => {
                if (node.children.items.len < 3) return error.MalformedAst;
                const left = try self.astToEGraph(&node.children.items[0]);
                const op_tok = node.children.items[1].token;
                const right = try self.astToEGraph(&node.children.items[2]);

                const op: ENodeOp = switch (op_tok.kind) {
                    .op_plus => .add,
                    .op_minus => .sub,
                    .op_star => .mul,
                    .op_slash => .div,
                    else => .add, // Fallback
                };

                return try self.graph.add(ENode.withChildren(op, left, right));
            },
            else => {
                // Для сложных узлов (программы, функции) возвращаем дефолт или игнорируем
                // В полноценной реализации здесь будет обход всех детей
                return error.UnsupportedNodeForEGraph;
            },
        };
    }

    /// Извлекает лучший (наиболее "священный") вариант дерева
    pub fn extractBest(self: *Bridge, class_id: EClassId) !*AstNode {
        const best_enode = try self.graph.extractBest(class_id);

        switch (best_enode.op) {
            .const_int => {
                const node = try self.createDummyNode(.literal_int);
                // В реальности тут нужно создать токен с правильным лексемом
                return node;
            },
            .const_phi => {
                const node = try self.createDummyNode(.identifier);
                return node;
            },
            .add => {
                const node = try self.createDummyNode(.binary_expr);
                if (best_enode.children[0]) |left_id| {
                    try node.addChild(try self.extractBest(left_id));
                }
                // Оператор +
                if (best_enode.children[1]) |right_id| {
                    try node.addChild(try self.extractBest(right_id));
                }
                return node;
            },
            else => return error.ExtractionNotImplemented,
        }
    }

    fn createDummyNode(self: *Bridge, kind: NodeKind) !*AstNode {
        const node = try self.allocator.create(AstNode);
        node.* = AstNode.init(kind, .{
            .kind = .invalid,
            .start = 0,
            .len = 0,
            .line = 0,
            .column = 0,
        }, self.allocator);
        return node;
    }
};

test "ast to egraph basics" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    graph.source = "x + 42";
    defer graph.deinit();

    _ = Bridge.init(allocator, &graph);
}
