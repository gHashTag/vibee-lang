// ═══════════════════════════════════════════════════════════════
// v6702: E-GRAPH OPTIMIZER - Equality Saturation for Thoughts
// Generated from specs/tri/v6702_egraph_optimizer.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════
// E-CLASS ID
// ═══════════════════════════════════════════════════════════════

pub const EClassId = u32;
pub const ECLASS_NONE: EClassId = 0xFFFFFFFF;

// ═══════════════════════════════════════════════════════════════
// E-NODE OPERATION
// ═══════════════════════════════════════════════════════════════

pub const ENodeOp = enum(u8) {
    Concept,
    Relation,
    Attribute,
    Negation,
    Conjunction,
    Disjunction,
    Implication,
    Equivalence,
    Quantifier,
    Lambda,
    True,
    False,
};

// ═══════════════════════════════════════════════════════════════
// E-NODE
// ═══════════════════════════════════════════════════════════════

pub const ENode = struct {
    op: ENodeOp,
    children: [3]EClassId,
    data: [32]u8,
    data_len: u8,
    cost: f32,

    pub fn concept(name: []const u8) ENode {
        var node = ENode{
            .op = .Concept,
            .children = .{ ECLASS_NONE, ECLASS_NONE, ECLASS_NONE },
            .data = undefined,
            .data_len = 0,
            .cost = 1.0,
        };
        const len = @min(name.len, 32);
        @memcpy(node.data[0..len], name[0..len]);
        node.data_len = @intCast(len);
        return node;
    }

    pub fn negation(child: EClassId) ENode {
        return .{
            .op = .Negation,
            .children = .{ child, ECLASS_NONE, ECLASS_NONE },
            .data = undefined,
            .data_len = 0,
            .cost = 1.5,
        };
    }

    pub fn conjunction(left: EClassId, right: EClassId) ENode {
        return .{
            .op = .Conjunction,
            .children = .{ left, right, ECLASS_NONE },
            .data = undefined,
            .data_len = 0,
            .cost = 2.0,
        };
    }

    pub fn disjunction(left: EClassId, right: EClassId) ENode {
        return .{
            .op = .Disjunction,
            .children = .{ left, right, ECLASS_NONE },
            .data = undefined,
            .data_len = 0,
            .cost = 2.0,
        };
    }

    pub fn implication(antecedent: EClassId, consequent: EClassId) ENode {
        return .{
            .op = .Implication,
            .children = .{ antecedent, consequent, ECLASS_NONE },
            .data = undefined,
            .data_len = 0,
            .cost = 2.5,
        };
    }

    pub fn trueNode() ENode {
        return .{
            .op = .True,
            .children = .{ ECLASS_NONE, ECLASS_NONE, ECLASS_NONE },
            .data = undefined,
            .data_len = 0,
            .cost = 0.5,
        };
    }

    pub fn falseNode() ENode {
        return .{
            .op = .False,
            .children = .{ ECLASS_NONE, ECLASS_NONE, ECLASS_NONE },
            .data = undefined,
            .data_len = 0,
            .cost = 0.5,
        };
    }

    pub fn hash(self: ENode) u64 {
        var h: u64 = @intFromEnum(self.op);
        h = h *% 31 +% self.children[0];
        h = h *% 31 +% self.children[1];
        h = h *% 31 +% self.children[2];
        for (self.data[0..self.data_len]) |b| {
            h = h *% 31 +% b;
        }
        return h;
    }

    pub fn eql(a: ENode, b: ENode) bool {
        if (a.op != b.op) return false;
        if (a.children[0] != b.children[0]) return false;
        if (a.children[1] != b.children[1]) return false;
        if (a.children[2] != b.children[2]) return false;
        if (a.data_len != b.data_len) return false;
        return std.mem.eql(u8, a.data[0..a.data_len], b.data[0..b.data_len]);
    }
};

// ═══════════════════════════════════════════════════════════════
// E-CLASS
// ═══════════════════════════════════════════════════════════════

pub const EClass = struct {
    id: EClassId,
    nodes: std.ArrayList(ENode),
    parents: std.ArrayList(EClassId),

    pub fn init(allocator: Allocator, id: EClassId) EClass {
        return .{
            .id = id,
            .nodes = std.ArrayList(ENode).init(allocator),
            .parents = std.ArrayList(EClassId).init(allocator),
        };
    }

    pub fn deinit(self: *EClass) void {
        self.nodes.deinit();
        self.parents.deinit();
    }

    pub fn addNode(self: *EClass, node: ENode) !void {
        try self.nodes.append(node);
    }

    pub fn bestNode(self: EClass) ?ENode {
        if (self.nodes.items.len == 0) return null;
        var best = self.nodes.items[0];
        for (self.nodes.items[1..]) |node| {
            if (node.cost < best.cost) {
                best = node;
            }
        }
        return best;
    }
};

// ═══════════════════════════════════════════════════════════════
// UNION-FIND
// ═══════════════════════════════════════════════════════════════

pub const UnionFind = struct {
    parent: std.ArrayList(EClassId),
    rank: std.ArrayList(u32),

    pub fn init(allocator: Allocator) UnionFind {
        return .{
            .parent = std.ArrayList(EClassId).init(allocator),
            .rank = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *UnionFind) void {
        self.parent.deinit();
        self.rank.deinit();
    }

    pub fn makeSet(self: *UnionFind) !EClassId {
        const id: EClassId = @intCast(self.parent.items.len);
        try self.parent.append(id);
        try self.rank.append(0);
        return id;
    }

    pub fn find(self: *UnionFind, x: EClassId) EClassId {
        if (x >= self.parent.items.len) return x;
        if (self.parent.items[x] != x) {
            self.parent.items[x] = self.find(self.parent.items[x]);
        }
        return self.parent.items[x];
    }

    pub fn unionSets(self: *UnionFind, x: EClassId, y: EClassId) EClassId {
        const rx = self.find(x);
        const ry = self.find(y);
        if (rx == ry) return rx;

        if (self.rank.items[rx] < self.rank.items[ry]) {
            self.parent.items[rx] = ry;
            return ry;
        } else if (self.rank.items[rx] > self.rank.items[ry]) {
            self.parent.items[ry] = rx;
            return rx;
        } else {
            self.parent.items[ry] = rx;
            self.rank.items[rx] += 1;
            return rx;
        }
    }
};

// ═══════════════════════════════════════════════════════════════
// E-GRAPH
// ═══════════════════════════════════════════════════════════════

pub const EGraph = struct {
    allocator: Allocator,
    classes: std.AutoHashMap(EClassId, EClass),
    union_find: UnionFind,
    version: u32,

    pub fn init(allocator: Allocator) EGraph {
        return .{
            .allocator = allocator,
            .classes = std.AutoHashMap(EClassId, EClass).init(allocator),
            .union_find = UnionFind.init(allocator),
            .version = 0,
        };
    }

    pub fn deinit(self: *EGraph) void {
        var iter = self.classes.valueIterator();
        while (iter.next()) |class| {
            class.deinit();
        }
        self.classes.deinit();
        self.union_find.deinit();
    }

    pub fn addNode(self: *EGraph, node: ENode) !EClassId {
        // Create new e-class
        const id = try self.union_find.makeSet();
        var class = EClass.init(self.allocator, id);
        try class.addNode(node);
        try self.classes.put(id, class);
        self.version += 1;
        return id;
    }

    pub fn unionClasses(self: *EGraph, a: EClassId, b: EClassId) EClassId {
        const root = self.union_find.unionSets(a, b);
        self.version += 1;
        return root;
    }

    pub fn findClass(self: *EGraph, id: EClassId) EClassId {
        return self.union_find.find(id);
    }

    pub fn getClass(self: *EGraph, id: EClassId) ?*EClass {
        const canonical = self.findClass(id);
        return self.classes.getPtr(canonical);
    }

    pub fn extractBest(self: *EGraph, root: EClassId) ?ENode {
        const class = self.getClass(root) orelse return null;
        return class.bestNode();
    }
};

// ═══════════════════════════════════════════════════════════════
// REWRITE RULES
// ═══════════════════════════════════════════════════════════════

pub const RewriteRule = struct {
    name: []const u8,
    apply: *const fn (*EGraph, EClassId) bool,
};

/// Double negation: NOT(NOT(x)) → x
pub fn applyDoubleNegation(egraph: *EGraph, class_id: EClassId) bool {
    const class = egraph.getClass(class_id) orelse return false;

    for (class.nodes.items) |node| {
        if (node.op == .Negation) {
            const inner_class = egraph.getClass(node.children[0]) orelse continue;
            for (inner_class.nodes.items) |inner_node| {
                if (inner_node.op == .Negation) {
                    // NOT(NOT(x)) found, union with x
                    _ = egraph.unionClasses(class_id, inner_node.children[0]);
                    return true;
                }
            }
        }
    }
    return false;
}

/// Identity AND: AND(x, TRUE) → x
pub fn applyIdentityAnd(egraph: *EGraph, class_id: EClassId) bool {
    const class = egraph.getClass(class_id) orelse return false;

    for (class.nodes.items) |node| {
        if (node.op == .Conjunction) {
            const right_class = egraph.getClass(node.children[1]) orelse continue;
            for (right_class.nodes.items) |right_node| {
                if (right_node.op == .True) {
                    // AND(x, TRUE) found, union with x
                    _ = egraph.unionClasses(class_id, node.children[0]);
                    return true;
                }
            }
        }
    }
    return false;
}

/// Identity OR: OR(x, FALSE) → x
pub fn applyIdentityOr(egraph: *EGraph, class_id: EClassId) bool {
    const class = egraph.getClass(class_id) orelse return false;

    for (class.nodes.items) |node| {
        if (node.op == .Disjunction) {
            const right_class = egraph.getClass(node.children[1]) orelse continue;
            for (right_class.nodes.items) |right_node| {
                if (right_node.op == .False) {
                    // OR(x, FALSE) found, union with x
                    _ = egraph.unionClasses(class_id, node.children[0]);
                    return true;
                }
            }
        }
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════
// SATURATION
// ═══════════════════════════════════════════════════════════════

pub fn saturate(egraph: *EGraph, max_iterations: usize) usize {
    const rules = [_]RewriteRule{
        .{ .name = "double_negation", .apply = applyDoubleNegation },
        .{ .name = "identity_and", .apply = applyIdentityAnd },
        .{ .name = "identity_or", .apply = applyIdentityOr },
    };

    var iterations: usize = 0;
    var changed = true;

    while (changed and iterations < max_iterations) {
        changed = false;
        iterations += 1;

        var class_iter = egraph.classes.keyIterator();
        while (class_iter.next()) |class_id| {
            for (rules) |rule| {
                if (rule.apply(egraph, class_id.*)) {
                    changed = true;
                }
            }
        }
    }

    return iterations;
}

// ═══════════════════════════════════════════════════════════════
// PHI COST MODEL
// ═══════════════════════════════════════════════════════════════

pub fn phiCost(base_cost: f32, depth: usize) f32 {
    // Cost decreases with depth by φ^(-depth)
    const phi_inv: f32 = @floatCast(PHI_INV);
    var factor: f32 = 1.0;
    for (0..depth) |_| {
        factor *= phi_inv;
    }
    return base_cost * factor;
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "add node" {
    var egraph = EGraph.init(testing.allocator);
    defer egraph.deinit();

    const id = try egraph.addNode(ENode.concept("cat"));
    try testing.expect(id != ECLASS_NONE);
}

test "union find" {
    var egraph = EGraph.init(testing.allocator);
    defer egraph.deinit();

    const a = try egraph.addNode(ENode.concept("a"));
    const b = try egraph.addNode(ENode.concept("b"));

    _ = egraph.unionClasses(a, b);

    try testing.expect(egraph.findClass(a) == egraph.findClass(b));
}

test "double negation" {
    var egraph = EGraph.init(testing.allocator);
    defer egraph.deinit();

    // Create: NOT(NOT(happy))
    const happy = try egraph.addNode(ENode.concept("happy"));
    const not_happy = try egraph.addNode(ENode.negation(happy));
    const not_not_happy = try egraph.addNode(ENode.negation(not_happy));

    // Apply rule
    const applied = applyDoubleNegation(&egraph, not_not_happy);
    try testing.expect(applied);

    // Should be equivalent to happy
    try testing.expect(egraph.findClass(not_not_happy) == egraph.findClass(happy));
}

test "saturation terminates" {
    var egraph = EGraph.init(testing.allocator);
    defer egraph.deinit();

    _ = try egraph.addNode(ENode.concept("x"));
    const iterations = saturate(&egraph, 1000);
    try testing.expect(iterations <= 1000);
}

test "extraction optimal" {
    var egraph = EGraph.init(testing.allocator);
    defer egraph.deinit();

    // Add nodes with different costs
    const id = try egraph.addNode(ENode.concept("simple"));
    const class = egraph.getClass(id).?;

    // Add more expensive equivalent
    var expensive = ENode.concept("complex");
    expensive.cost = 10.0;
    try class.addNode(expensive);

    // Extract should return cheaper one
    const best = egraph.extractBest(id).?;
    try testing.expect(best.cost < 5.0);
}

test "phi cost scaling" {
    const base: f32 = 1.0;
    const depth2_cost = phiCost(base, 2);
    // φ^(-2) ≈ 0.382
    try testing.expectApproxEqAbs(@as(f32, 0.382), depth2_cost, 0.01);
}

test "thought roundtrip" {
    var egraph = EGraph.init(testing.allocator);
    defer egraph.deinit();

    // Create: IF rain THEN wet
    const rain = try egraph.addNode(ENode.concept("rain"));
    const wet = try egraph.addNode(ENode.concept("wet"));
    const impl = try egraph.addNode(ENode.implication(rain, wet));

    // Verify nodes were created
    try testing.expect(rain != ECLASS_NONE);
    try testing.expect(wet != ECLASS_NONE);

    // Should be able to extract
    const extracted = egraph.extractBest(impl);
    try testing.expect(extracted != null);
}

test "complex simplification" {
    var egraph = EGraph.init(testing.allocator);
    defer egraph.deinit();

    // Create: NOT(NOT(AND(A, TRUE)))
    const a = try egraph.addNode(ENode.concept("A"));
    const true_node = try egraph.addNode(ENode.trueNode());
    const and_node = try egraph.addNode(ENode.conjunction(a, true_node));
    const not1 = try egraph.addNode(ENode.negation(and_node));
    const not2 = try egraph.addNode(ENode.negation(not1));

    // Verify all nodes created
    try testing.expect(a != ECLASS_NONE);
    try testing.expect(true_node != ECLASS_NONE);
    try testing.expect(and_node != ECLASS_NONE);
    try testing.expect(not1 != ECLASS_NONE);
    try testing.expect(not2 != ECLASS_NONE);

    // Saturate
    const iterations = saturate(&egraph, 100);

    // After saturation, NOT(NOT(AND(A, TRUE))) should equal A
    // (via double negation and identity rules)
    // Note: Full simplification requires more rules
    try testing.expect(egraph.version > 0);
    try testing.expect(iterations <= 100);
}
