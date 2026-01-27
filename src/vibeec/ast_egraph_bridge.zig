//! VIBEE AST ↔ E-Graph Bridge (v3)
//! Преобразование AstNode в E-Classes и обратно после оптимизации
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_parser = @import("coptic_parser_real.zig");
const egraph = @import("egraph_v3.zig");

const AstNode = coptic_parser.AstNode;
const NodeKind = coptic_parser.NodeKind;
const EGraph = egraph.EGraph;
const ENode = egraph.ENode;
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
                const val = std.fmt.parseInt(i64, node.token.lexeme(self.graph.source.?), 10) catch 0;
                return try self.graph.add(ENode{ .constant = val });
            },
            .literal_float => {
                // For now, float constants are not fully supported in ENode optimization logic
                // Simplified behavior: treat as 0 or handle separately
                return error.UnsupportedNodeForEGraph;
            },
            .identifier => {
                const name = node.token.lexeme(self.graph.source.?);
                if (std.mem.eql(u8, name, "phi")) {
                    // TODO: Special Phi node? For now variable
                }
                return try self.graph.add(ENode{ .variable = name });
            },
            .binary_expr => {
                if (node.children.items.len < 3) return error.MalformedAst;
                const left = try self.astToEGraph(&node.children.items[0]);
                const op_tok = node.children.items[1].token;
                const right = try self.astToEGraph(&node.children.items[2]);

                const enode = switch (op_tok.kind) {
                    .op_plus => ENode{ .add = .{ left, right } },
                    .op_minus => ENode{ .sub = .{ left, right } },
                    .op_star => ENode{ .mul = .{ left, right } },
                    // .op_slash => .div, // Not in ENode yet
                    else => return error.UnsupportedNodeForEGraph,
                };

                return try self.graph.add(enode);
            },
            else => {
                // Return generic error for unsupported nodes
                return error.UnsupportedNodeForEGraph;
            },
        };
    }

    /// Извлекает лучший (наиболее "священный") вариант дерева
    pub fn extractBest(self: *Bridge, class_id: EClassId) !*AstNode {
        const best_enode = try self.graph.extractBest(class_id);

        switch (best_enode) {
            .constant => |_| {
                const node = try self.createDummyNode(.literal_int);
                // Assuming we can set token lexeme somehow or re-parse,
                // but for backend compilation we usually need AstNode structure.
                // This is a simplified reconstruction.
                return node;
            },
            .variable => |_| {
                const node = try self.createDummyNode(.identifier);
                return node;
            },
            .add => |ids| {
                const node = try self.createDummyNode(.binary_expr);
                try node.children.append((try self.extractBest(ids[0])).*);
                // Operator token reconstruction omitted for brevity
                try node.children.append((try self.createDummyTokenNode(.op_plus)).*);
                try node.children.append((try self.extractBest(ids[1])).*);
                return node;
            },
            .mul => |ids| {
                const node = try self.createDummyNode(.binary_expr);
                try node.children.append((try self.extractBest(ids[0])).*);
                try node.children.append((try self.createDummyTokenNode(.op_star)).*);
                try node.children.append((try self.extractBest(ids[1])).*);
                return node;
            },
            .sub => |ids| {
                const node = try self.createDummyNode(.binary_expr);
                try node.children.append((try self.extractBest(ids[0])).*);
                try node.children.append((try self.createDummyTokenNode(.op_minus)).*);
                try node.children.append((try self.extractBest(ids[1])).*);
                return node;
            },
            .tri_shift => |ids| {
                // Convert Trinity ops back to AST calls or special syntax?
                // For now, map to mul for visualization or special intrinsic
                const node = try self.createDummyNode(.binary_expr);
                try node.children.append((try self.extractBest(ids[0])).*);
                try node.children.append((try self.createDummyTokenNode(.op_bitwise_shl)).*); // Assuming shl token exists
                try node.children.append((try self.extractBest(ids[1])).*);
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

    fn createDummyTokenNode(self: *Bridge, token_kind: coptic_parser.TokenKind) !*AstNode {
        // Helper to create a node wrapping a token (for operators)
        const node = try self.allocator.create(AstNode);
        node.* = AstNode.init(.invalid, .{ // AST doesn't usually have operator as node, but binary expr has child tokens
            .kind = token_kind,
            .start = 0,
            .len = 0,
            .line = 0,
            .column = 0,
        }, self.allocator);
        return node;
    }
};
