// E-Graph Optimizer V2 - Equality Saturation
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37
// Based on egg (e-graphs good) algorithm

const std = @import("std");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const GOLDEN_IDENTITY: f64 = 3.0;

// E-class ID
pub const EClassId = u32;
pub const ECLASS_NONE: EClassId = 0xFFFFFFFF;

// E-node operations
pub const ENodeOp = enum(u8) {
    // Literals
    num,
    var_ref,
    
    // Arithmetic
    add,
    sub,
    mul,
    div,
    neg,
    
    // Comparison
    eq,
    lt,
    
    // Control
    if_then_else,
    
    // Special
    phi,      // Golden ratio
    trinity,  // 3
};

// E-node: represents an expression
pub const ENode = struct {
    op: ENodeOp,
    children: [3]EClassId,
    value: i64, // For num nodes
    
    pub fn num(value: i64) ENode {
        return .{ .op = .num, .children = .{ ECLASS_NONE, ECLASS_NONE, ECLASS_NONE }, .value = value };
    }
    
    pub fn varRef(id: EClassId) ENode {
        return .{ .op = .var_ref, .children = .{ id, ECLASS_NONE, ECLASS_NONE }, .value = 0 };
    }
    
    pub fn binop(op: ENodeOp, left: EClassId, right: EClassId) ENode {
        return .{ .op = op, .children = .{ left, right, ECLASS_NONE }, .value = 0 };
    }
    
    pub fn unop(op: ENodeOp, child: EClassId) ENode {
        return .{ .op = op, .children = .{ child, ECLASS_NONE, ECLASS_NONE }, .value = 0 };
    }
    
    pub fn hash(self: ENode) u64 {
        var h: u64 = @intFromEnum(self.op);
        h = h *% 31 +% self.children[0];
        h = h *% 31 +% self.children[1];
        h = h *% 31 +% self.children[2];
        h = h *% 31 +% @as(u64, @bitCast(self.value));
        return h;
    }
    
    pub fn eql(a: ENode, b: ENode) bool {
        return a.op == b.op and 
               a.children[0] == b.children[0] and
               a.children[1] == b.children[1] and
               a.children[2] == b.children[2] and
               a.value == b.value;
    }
};

// Parent reference
pub const ParentRef = struct { node: ENode, eclass: EClassId };

// E-class: equivalence class of expressions
pub const EClass = struct {
    id: EClassId,
    nodes: std.ArrayList(ENode),
    parents: std.ArrayList(ParentRef),
    
    pub fn init(allocator: std.mem.Allocator, id: EClassId) EClass {
        return .{
            .id = id,
            .nodes = std.ArrayList(ENode).init(allocator),
            .parents = std.ArrayList(ParentRef).init(allocator),
        };
    }
    
    pub fn deinit(self: *EClass) void {
        self.nodes.deinit();
        self.parents.deinit();
    }
};

// Union-Find for e-class merging
pub const UnionFind = struct {
    parent: std.ArrayList(EClassId),
    rank: std.ArrayList(u32),
    
    pub fn init(allocator: std.mem.Allocator) UnionFind {
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
    
    pub fn union_(self: *UnionFind, x: EClassId, y: EClassId) EClassId {
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

// Hash context for ENode
pub const ENodeContext = struct {
    pub fn hash(_: ENodeContext, key: ENode) u64 {
        return key.hash();
    }
    pub fn eql(_: ENodeContext, a: ENode, b: ENode) bool {
        return a.eql(b);
    }
};

// E-Graph
pub const EGraph = struct {
    allocator: std.mem.Allocator,
    classes: std.AutoHashMap(EClassId, EClass),
    hashcons: std.HashMap(ENode, EClassId, ENodeContext, std.hash_map.default_max_load_percentage),
    uf: UnionFind,
    worklist: std.ArrayList(EClassId),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .classes = std.AutoHashMap(EClassId, EClass).init(allocator),
            .hashcons = std.HashMap(ENode, EClassId, ENodeContext, std.hash_map.default_max_load_percentage).init(allocator),
            .uf = UnionFind.init(allocator),
            .worklist = std.ArrayList(EClassId).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.classes.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.classes.deinit();
        self.hashcons.deinit();
        self.uf.deinit();
        self.worklist.deinit();
    }
    
    // Canonicalize e-node (update children to canonical e-class ids)
    fn canonicalize(self: *Self, node: ENode) ENode {
        var canon = node;
        for (&canon.children) |*child| {
            if (child.* != ECLASS_NONE) {
                child.* = self.uf.find(child.*);
            }
        }
        return canon;
    }
    
    // Add e-node to e-graph, return e-class id
    pub fn add(self: *Self, node: ENode) !EClassId {
        const canon = self.canonicalize(node);
        
        // Check if already exists
        if (self.hashcons.get(canon)) |id| {
            return self.uf.find(id);
        }
        
        // Create new e-class
        const id = try self.uf.makeSet();
        var eclass = EClass.init(self.allocator, id);
        try eclass.nodes.append(canon);
        try self.classes.put(id, eclass);
        try self.hashcons.put(canon, id);
        
        return id;
    }
    
    // Merge two e-classes
    pub fn merge(self: *Self, id1: EClassId, id2: EClassId) !EClassId {
        const root1 = self.uf.find(id1);
        const root2 = self.uf.find(id2);
        
        if (root1 == root2) return root1;
        
        const new_root = self.uf.union_(root1, root2);
        try self.worklist.append(new_root);
        
        return new_root;
    }
    
    // Rebuild e-graph after merges
    pub fn rebuild(self: *Self) !void {
        while (self.worklist.items.len > 0) {
            const id = self.worklist.pop();
            _ = id;
            // Repair hashcons and parents
            // (simplified - full implementation would update all references)
        }
    }
};

// Rewrite Rules
pub const RewriteRule = struct {
    name: []const u8,
    apply: *const fn (*EGraph, EClassId) ?EClassId,
};

// Algebraic rewrite rules
pub const AlgebraicRules = struct {
    
    // x + 0 = x
    pub fn addZero(egraph: *EGraph, id: EClassId) ?EClassId {
        const eclass = egraph.classes.get(egraph.uf.find(id)) orelse return null;
        
        for (eclass.nodes.items) |node| {
            if (node.op == .add) {
                // Check if right child is 0
                const right_class = egraph.classes.get(egraph.uf.find(node.children[1])) orelse continue;
                for (right_class.nodes.items) |rnode| {
                    if (rnode.op == .num and rnode.value == 0) {
                        return node.children[0];
                    }
                }
                // Check if left child is 0
                const left_class = egraph.classes.get(egraph.uf.find(node.children[0])) orelse continue;
                for (left_class.nodes.items) |lnode| {
                    if (lnode.op == .num and lnode.value == 0) {
                        return node.children[1];
                    }
                }
            }
        }
        return null;
    }
    
    // x * 1 = x
    pub fn mulOne(egraph: *EGraph, id: EClassId) ?EClassId {
        const eclass = egraph.classes.get(egraph.uf.find(id)) orelse return null;
        
        for (eclass.nodes.items) |node| {
            if (node.op == .mul) {
                const right_class = egraph.classes.get(egraph.uf.find(node.children[1])) orelse continue;
                for (right_class.nodes.items) |rnode| {
                    if (rnode.op == .num and rnode.value == 1) {
                        return node.children[0];
                    }
                }
                const left_class = egraph.classes.get(egraph.uf.find(node.children[0])) orelse continue;
                for (left_class.nodes.items) |lnode| {
                    if (lnode.op == .num and lnode.value == 1) {
                        return node.children[1];
                    }
                }
            }
        }
        return null;
    }
    
    // x * 0 = 0
    pub fn mulZero(egraph: *EGraph, id: EClassId) ?EClassId {
        const eclass = egraph.classes.get(egraph.uf.find(id)) orelse return null;
        
        for (eclass.nodes.items) |node| {
            if (node.op == .mul) {
                const right_class = egraph.classes.get(egraph.uf.find(node.children[1])) orelse continue;
                for (right_class.nodes.items) |rnode| {
                    if (rnode.op == .num and rnode.value == 0) {
                        return egraph.add(ENode.num(0)) catch null;
                    }
                }
                const left_class = egraph.classes.get(egraph.uf.find(node.children[0])) orelse continue;
                for (left_class.nodes.items) |lnode| {
                    if (lnode.op == .num and lnode.value == 0) {
                        return egraph.add(ENode.num(0)) catch null;
                    }
                }
            }
        }
        return null;
    }
    
    // x - x = 0
    pub fn subSelf(egraph: *EGraph, id: EClassId) ?EClassId {
        const eclass = egraph.classes.get(egraph.uf.find(id)) orelse return null;
        
        for (eclass.nodes.items) |node| {
            if (node.op == .sub) {
                if (egraph.uf.find(node.children[0]) == egraph.uf.find(node.children[1])) {
                    return egraph.add(ENode.num(0)) catch null;
                }
            }
        }
        return null;
    }
    
    // x + x = 2 * x (strength reduction inverse)
    pub fn addSelf(egraph: *EGraph, id: EClassId) ?EClassId {
        const eclass = egraph.classes.get(egraph.uf.find(id)) orelse return null;
        
        for (eclass.nodes.items) |node| {
            if (node.op == .add) {
                if (egraph.uf.find(node.children[0]) == egraph.uf.find(node.children[1])) {
                    const two = egraph.add(ENode.num(2)) catch return null;
                    return egraph.add(ENode.binop(.mul, two, node.children[0])) catch null;
                }
            }
        }
        return null;
    }
    
    // Constant folding
    pub fn constFold(egraph: *EGraph, id: EClassId) ?EClassId {
        const eclass = egraph.classes.get(egraph.uf.find(id)) orelse return null;
        
        for (eclass.nodes.items) |node| {
            switch (node.op) {
                .add, .sub, .mul, .div => {
                    const left_class = egraph.classes.get(egraph.uf.find(node.children[0])) orelse continue;
                    const right_class = egraph.classes.get(egraph.uf.find(node.children[1])) orelse continue;
                    
                    var left_val: ?i64 = null;
                    var right_val: ?i64 = null;
                    
                    for (left_class.nodes.items) |lnode| {
                        if (lnode.op == .num) left_val = lnode.value;
                    }
                    for (right_class.nodes.items) |rnode| {
                        if (rnode.op == .num) right_val = rnode.value;
                    }
                    
                    if (left_val != null and right_val != null) {
                        const result = switch (node.op) {
                            .add => left_val.? + right_val.?,
                            .sub => left_val.? - right_val.?,
                            .mul => left_val.? * right_val.?,
                            .div => if (right_val.? != 0) @divTrunc(left_val.?, right_val.?) else left_val.?,
                            else => unreachable,
                        };
                        return egraph.add(ENode.num(result)) catch null;
                    }
                },
                else => {},
            }
        }
        return null;
    }
};

// Equality Saturation Runner
pub const EqSatRunner = struct {
    egraph: *EGraph,
    rules: []const RewriteRule,
    iterations: u32,
    max_iterations: u32,
    
    pub fn init(egraph: *EGraph, rules: []const RewriteRule) EqSatRunner {
        return .{
            .egraph = egraph,
            .rules = rules,
            .iterations = 0,
            .max_iterations = 30,
        };
    }
    
    pub fn run(self: *EqSatRunner) !u32 {
        var total_merges: u32 = 0;
        
        while (self.iterations < self.max_iterations) {
            self.iterations += 1;
            var merges_this_iter: u32 = 0;
            
            // Apply all rules to all e-classes
            var iter = self.egraph.classes.iterator();
            while (iter.next()) |entry| {
                const id = entry.key_ptr.*;
                
                for (self.rules) |rule| {
                    if (rule.apply(self.egraph, id)) |new_id| {
                        _ = self.egraph.merge(id, new_id) catch continue;
                        merges_this_iter += 1;
                    }
                }
            }
            
            try self.egraph.rebuild();
            total_merges += merges_this_iter;
            
            if (merges_this_iter == 0) break;
        }
        
        return total_merges;
    }
};

// Tests
test "E-graph basic" {
    const allocator = std.testing.allocator;
    
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    // Add: 1 + 2
    const one = try egraph.add(ENode.num(1));
    const two = try egraph.add(ENode.num(2));
    const sum = try egraph.add(ENode.binop(.add, one, two));
    
    try std.testing.expect(one != two);
    try std.testing.expect(sum != one);
    try std.testing.expect(sum != two);
}

test "E-graph merge" {
    const allocator = std.testing.allocator;
    
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    const a = try egraph.add(ENode.num(1));
    const b = try egraph.add(ENode.num(1)); // Same value, different e-class initially
    
    // They should be the same due to hashcons
    try std.testing.expectEqual(a, b);
}

test "Algebraic rules - add zero" {
    const allocator = std.testing.allocator;
    
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    const x = try egraph.add(ENode.num(42));
    const zero = try egraph.add(ENode.num(0));
    const sum = try egraph.add(ENode.binop(.add, x, zero));
    
    const result = AlgebraicRules.addZero(&egraph, sum);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(x, result.?);
}

test "Algebraic rules - const fold" {
    const allocator = std.testing.allocator;
    
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    const ten = try egraph.add(ENode.num(10));
    const twenty = try egraph.add(ENode.num(20));
    const sum = try egraph.add(ENode.binop(.add, ten, twenty));
    
    const result = AlgebraicRules.constFold(&egraph, sum);
    try std.testing.expect(result != null);
    
    // Result should be e-class containing 30
    const result_class = egraph.classes.get(egraph.uf.find(result.?)).?;
    var found_30 = false;
    for (result_class.nodes.items) |node| {
        if (node.op == .num and node.value == 30) found_30 = true;
    }
    try std.testing.expect(found_30);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
