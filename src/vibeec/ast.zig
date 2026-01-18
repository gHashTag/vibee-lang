// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC AST - ABSTRACT SYNTAX TREE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V36 - Proper Tree Structure with Source Spans
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: D&C (Tree Traversal), HSH (Node Lookup)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// SOURCE SPAN - LOCATION TRACKING
// ═══════════════════════════════════════════════════════════════════════════════

pub const SourceSpan = struct {
    start_line: u32,
    start_col: u32,
    end_line: u32,
    end_col: u32,
    start_offset: usize,
    end_offset: usize,

    pub fn empty() SourceSpan {
        return .{
            .start_line = 0,
            .start_col = 0,
            .end_line = 0,
            .end_col = 0,
            .start_offset = 0,
            .end_offset = 0,
        };
    }

    pub fn merge(a: SourceSpan, b: SourceSpan) SourceSpan {
        return .{
            .start_line = @min(a.start_line, b.start_line),
            .start_col = if (a.start_line <= b.start_line) a.start_col else b.start_col,
            .end_line = @max(a.end_line, b.end_line),
            .end_col = if (a.end_line >= b.end_line) a.end_col else b.end_col,
            .start_offset = @min(a.start_offset, b.start_offset),
            .end_offset = @max(a.end_offset, b.end_offset),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AST NODE ID
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeId = u32;
pub const INVALID_NODE: NodeId = std.math.maxInt(NodeId);

// ═══════════════════════════════════════════════════════════════════════════════
// AST NODE KINDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeKind = enum(u8) {
    // Root
    specification,

    // Metadata
    metadata,

    // Creation Pattern
    creation_pattern,

    // Behaviors
    behavior_list,
    behavior,
    test_case_list,
    test_case,

    // Types
    type_list,
    type_def,
    field_list,
    field,
    method_list,
    method,
    value_list,

    // PAS Analysis
    pas_analysis,
    improvement_list,
    improvement,

    // Sacred Formula
    sacred_formula,

    // Constants
    constant_list,
    constant,

    // Expressions (for future use)
    literal_string,
    literal_int,
    literal_float,
    literal_bool,
    identifier,
    binary_op,
    unary_op,
    call,
};

// ═══════════════════════════════════════════════════════════════════════════════
// AST NODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const AstNode = struct {
    id: NodeId,
    kind: NodeKind,
    span: SourceSpan,
    parent: NodeId,
    first_child: NodeId,
    next_sibling: NodeId,
    // Data stored as string for simplicity
    data: []const u8,

    pub fn isLeaf(self: AstNode) bool {
        return self.first_child == INVALID_NODE;
    }

    pub fn hasParent(self: AstNode) bool {
        return self.parent != INVALID_NODE;
    }

    pub fn hasSibling(self: AstNode) bool {
        return self.next_sibling != INVALID_NODE;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AST - TREE STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Ast = struct {
    allocator: Allocator,
    nodes: ArrayList(AstNode),
    root: NodeId,

    // Metadata cache (HSH pattern)
    name: []const u8,
    version: []const u8,
    language: []const u8,
    module: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .nodes = ArrayList(AstNode).init(allocator),
            .root = INVALID_NODE,
            .name = "",
            .version = "",
            .language = "",
            .module = "",
        };
    }

    pub fn deinit(self: *Self) void {
        self.nodes.deinit();
    }

    pub fn addNode(self: *Self, kind: NodeKind, span: SourceSpan, data: []const u8) !NodeId {
        const id: NodeId = @intCast(self.nodes.items.len);
        try self.nodes.append(.{
            .id = id,
            .kind = kind,
            .span = span,
            .parent = INVALID_NODE,
            .first_child = INVALID_NODE,
            .next_sibling = INVALID_NODE,
            .data = data,
        });
        return id;
    }

    pub fn setRoot(self: *Self, node_id: NodeId) void {
        self.root = node_id;
    }

    pub fn addChild(self: *Self, parent_id: NodeId, child_id: NodeId) void {
        if (parent_id == INVALID_NODE or child_id == INVALID_NODE) return;

        self.nodes.items[child_id].parent = parent_id;

        if (self.nodes.items[parent_id].first_child == INVALID_NODE) {
            self.nodes.items[parent_id].first_child = child_id;
        } else {
            // Find last sibling
            var sibling = self.nodes.items[parent_id].first_child;
            while (self.nodes.items[sibling].next_sibling != INVALID_NODE) {
                sibling = self.nodes.items[sibling].next_sibling;
            }
            self.nodes.items[sibling].next_sibling = child_id;
        }
    }

    pub fn getNode(self: *Self, id: NodeId) ?*AstNode {
        if (id == INVALID_NODE or id >= self.nodes.items.len) return null;
        return &self.nodes.items[id];
    }

    pub fn getNodeConst(self: *const Self, id: NodeId) ?*const AstNode {
        if (id == INVALID_NODE or id >= self.nodes.items.len) return null;
        return &self.nodes.items[id];
    }

    /// D&C Pattern: Iterate children
    pub fn children(self: *const Self, parent_id: NodeId) ChildIterator {
        return ChildIterator{
            .ast = self,
            .current = if (parent_id != INVALID_NODE and parent_id < self.nodes.items.len)
                self.nodes.items[parent_id].first_child
            else
                INVALID_NODE,
        };
    }

    pub const ChildIterator = struct {
        ast: *const Ast,
        current: NodeId,

        pub fn next(self: *ChildIterator) ?*const AstNode {
            if (self.current == INVALID_NODE) return null;
            const node = &self.ast.nodes.items[self.current];
            self.current = node.next_sibling;
            return node;
        }
    };

    /// Count total nodes
    pub fn nodeCount(self: *const Self) usize {
        return self.nodes.items.len;
    }

    /// Pretty print for debugging
    pub fn prettyPrint(self: *const Self, writer: anytype) !void {
        if (self.root == INVALID_NODE) {
            try writer.writeAll("(empty AST)\n");
            return;
        }
        try self.printNode(writer, self.root, 0);
    }

    fn printNode(self: *const Self, writer: anytype, node_id: NodeId, depth: usize) !void {
        if (node_id == INVALID_NODE) return;

        const node = &self.nodes.items[node_id];

        // Indent
        var i: usize = 0;
        while (i < depth) : (i += 1) {
            try writer.writeAll("  ");
        }

        // Node info
        try writer.print("{s}", .{@tagName(node.kind)});
        if (node.data.len > 0) {
            try writer.print(": \"{s}\"", .{node.data});
        }
        try writer.print(" [{d}:{d}]\n", .{ node.span.start_line, node.span.start_col });

        // Children (D&C: recurse into subtrees)
        var child_iter = self.children(node_id);
        while (child_iter.next()) |child| {
            try self.printNode(writer, child.id, depth + 1);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AST BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const AstBuilder = struct {
    allocator: Allocator,
    ast: Ast,
    current_line: u32,
    current_col: u32,
    current_offset: usize,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .ast = Ast.init(allocator),
            .current_line = 1,
            .current_col = 1,
            .current_offset = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.ast.deinit();
    }

    pub fn build(self: *Self, source: []const u8) !*Ast {
        // Create root specification node
        const root_span = SourceSpan{
            .start_line = 1,
            .start_col = 1,
            .end_line = 1,
            .end_col = 1,
            .start_offset = 0,
            .end_offset = source.len,
        };

        const root_id = try self.ast.addNode(.specification, root_span, "");
        self.ast.setRoot(root_id);

        // Parse source line by line
        var lines = std.mem.splitScalar(u8, source, '\n');
        var line_num: u32 = 1;

        var current_section: NodeId = INVALID_NODE;
        var current_item: NodeId = INVALID_NODE;

        while (lines.next()) |line| {
            defer line_num += 1;

            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            const is_list_item = std.mem.startsWith(u8, trimmed, "- ");
            const content = if (is_list_item) trimmed[2..] else trimmed;

            if (std.mem.indexOf(u8, content, ":")) |colon_pos| {
                const key = std.mem.trim(u8, content[0..colon_pos], " \t");
                const value = if (colon_pos + 1 < content.len)
                    std.mem.trim(u8, content[colon_pos + 1 ..], " \t\"")
                else
                    "";

                const span = SourceSpan{
                    .start_line = line_num,
                    .start_col = 1,
                    .end_line = line_num,
                    .end_col = @intCast(line.len),
                    .start_offset = self.current_offset,
                    .end_offset = self.current_offset + line.len,
                };

                // Handle top-level keys
                if (std.mem.eql(u8, key, "name")) {
                    self.ast.name = value;
                    const node = try self.ast.addNode(.metadata, span, value);
                    self.ast.addChild(root_id, node);
                } else if (std.mem.eql(u8, key, "version")) {
                    self.ast.version = value;
                } else if (std.mem.eql(u8, key, "language")) {
                    self.ast.language = value;
                } else if (std.mem.eql(u8, key, "module")) {
                    self.ast.module = value;
                } else if (std.mem.eql(u8, key, "creation_pattern")) {
                    current_section = try self.ast.addNode(.creation_pattern, span, "");
                    self.ast.addChild(root_id, current_section);
                } else if (std.mem.eql(u8, key, "behaviors")) {
                    current_section = try self.ast.addNode(.behavior_list, span, "");
                    self.ast.addChild(root_id, current_section);
                } else if (std.mem.eql(u8, key, "types")) {
                    current_section = try self.ast.addNode(.type_list, span, "");
                    self.ast.addChild(root_id, current_section);
                } else if (std.mem.eql(u8, key, "pas_analysis")) {
                    current_section = try self.ast.addNode(.pas_analysis, span, "");
                    self.ast.addChild(root_id, current_section);
                } else if (std.mem.eql(u8, key, "sacred_formula")) {
                    current_section = try self.ast.addNode(.sacred_formula, span, "");
                    self.ast.addChild(root_id, current_section);
                } else if (std.mem.eql(u8, key, "constants")) {
                    current_section = try self.ast.addNode(.constant_list, span, "");
                    self.ast.addChild(root_id, current_section);
                } else if (is_list_item and std.mem.eql(u8, key, "name")) {
                    // New list item
                    if (current_section != INVALID_NODE) {
                        const section_kind = self.ast.nodes.items[current_section].kind;
                        const item_kind: NodeKind = switch (section_kind) {
                            .behavior_list => .behavior,
                            .type_list => .type_def,
                            .constant_list => .constant,
                            else => .metadata,
                        };
                        current_item = try self.ast.addNode(item_kind, span, value);
                        self.ast.addChild(current_section, current_item);
                    }
                } else if (current_item != INVALID_NODE) {
                    // Add field to current item
                    const field_node = try self.ast.addNode(.field, span, value);
                    self.ast.addChild(current_item, field_node);
                } else if (current_section != INVALID_NODE) {
                    // Add to current section
                    const child_node = try self.ast.addNode(.metadata, span, value);
                    self.ast.addChild(current_section, child_node);
                }
            }

            self.current_offset += line.len + 1; // +1 for newline
        }

        return &self.ast;
    }

    pub fn getAst(self: *Self) *Ast {
        return &self.ast;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VISITOR PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn Visitor(comptime Context: type) type {
    return struct {
        context: Context,
        ast: *const Ast,

        const Self = @This();

        pub fn init(ast: *const Ast, context: Context) Self {
            return Self{
                .ast = ast,
                .context = context,
            };
        }

        /// D&C Pattern: Visit all nodes recursively
        pub fn visitAll(self: *Self, visit_fn: *const fn (*Self, *const AstNode) void) void {
            if (self.ast.root == INVALID_NODE) return;
            self.visitNode(self.ast.root, visit_fn);
        }

        fn visitNode(self: *Self, node_id: NodeId, visit_fn: *const fn (*Self, *const AstNode) void) void {
            if (node_id == INVALID_NODE) return;

            const node = &self.ast.nodes.items[node_id];
            visit_fn(self, node);

            // Visit children
            var child_iter = self.ast.children(node_id);
            while (child_iter.next()) |child| {
                self.visitNode(child.id, visit_fn);
            }
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Ast basic operations" {
    const allocator = std.testing.allocator;
    var ast = Ast.init(allocator);
    defer ast.deinit();

    const root = try ast.addNode(.specification, SourceSpan.empty(), "test");
    ast.setRoot(root);

    const child1 = try ast.addNode(.metadata, SourceSpan.empty(), "child1");
    const child2 = try ast.addNode(.metadata, SourceSpan.empty(), "child2");

    ast.addChild(root, child1);
    ast.addChild(root, child2);

    try std.testing.expectEqual(@as(usize, 3), ast.nodeCount());
    try std.testing.expectEqual(root, ast.root);
}

test "Ast child iteration" {
    const allocator = std.testing.allocator;
    var ast = Ast.init(allocator);
    defer ast.deinit();

    const root = try ast.addNode(.specification, SourceSpan.empty(), "root");
    ast.setRoot(root);

    _ = try ast.addNode(.metadata, SourceSpan.empty(), "c1");
    const c1 = ast.nodes.items.len - 1;
    _ = try ast.addNode(.metadata, SourceSpan.empty(), "c2");
    const c2 = ast.nodes.items.len - 1;
    _ = try ast.addNode(.metadata, SourceSpan.empty(), "c3");
    const c3 = ast.nodes.items.len - 1;

    ast.addChild(root, @intCast(c1));
    ast.addChild(root, @intCast(c2));
    ast.addChild(root, @intCast(c3));

    var count: usize = 0;
    var iter = ast.children(root);
    while (iter.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "AstBuilder basic" {
    const allocator = std.testing.allocator;
    var builder = AstBuilder.init(allocator);
    defer builder.deinit();

    const source =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
        \\module: test
    ;

    const ast = try builder.build(source);

    try std.testing.expectEqualStrings("test_spec", ast.name);
    try std.testing.expectEqualStrings("1.0.0", ast.version);
    try std.testing.expectEqualStrings("zig", ast.language);
    try std.testing.expectEqualStrings("test", ast.module);
}

test "AstBuilder with sections" {
    const allocator = std.testing.allocator;
    var builder = AstBuilder.init(allocator);
    defer builder.deinit();

    const source =
        \\name: test
        \\behaviors:
        \\  - name: behavior1
        \\types:
        \\  - name: Type1
    ;

    const ast = try builder.build(source);

    try std.testing.expect(ast.nodeCount() > 1);
    try std.testing.expect(ast.root != INVALID_NODE);
}

test "SourceSpan merge" {
    const a = SourceSpan{
        .start_line = 1,
        .start_col = 5,
        .end_line = 1,
        .end_col = 10,
        .start_offset = 5,
        .end_offset = 10,
    };

    const b = SourceSpan{
        .start_line = 2,
        .start_col = 1,
        .end_line = 2,
        .end_col = 20,
        .start_offset = 15,
        .end_offset = 35,
    };

    const merged = SourceSpan.merge(a, b);

    try std.testing.expectEqual(@as(u32, 1), merged.start_line);
    try std.testing.expectEqual(@as(u32, 2), merged.end_line);
    try std.testing.expectEqual(@as(usize, 5), merged.start_offset);
    try std.testing.expectEqual(@as(usize, 35), merged.end_offset);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
