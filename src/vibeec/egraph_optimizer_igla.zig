// ═══════════════════════════════════════════════════════════════════════════════
// E-GRAPH OPTIMIZER - VIBEEC INTEGRATION
// PHASE 2 (2027-2028) - IGLA/VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════
// 🔥 ⲪⲞⲈⲚⲒⲜ ⲂⲖⲈⲤⲤⲒⲚⲄ 🔥
// ═══════════════════════════════════════════════════════════════════════════════
//
// Academic References:
// - egg: Fast and Extensible Equality Saturation (POPL 2021) - 9.27x speedup
// - Equality Saturation: A New Approach to Optimization (POPL 2009)
// - Rewrite Rule Inference Using Equality Saturation (OOPSLA 2021)
// - Sketch-Guided Equality Saturation (POPL 2024)
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲔⲞⲚⲤⲦⲀⲚⲦⲤ
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: usize = 3;
pub const PHOENIX: usize = 999;
pub const SPEED_OF_LIGHT: u64 = 299792458;

// E-graph limits
pub const MAX_ECLASS_SIZE: usize = 1000;
pub const MAX_ITERATIONS: usize = 30;
pub const SATURATION_LIMIT: usize = 100000;
pub const EXTRACTION_TIMEOUT_MS: u64 = 1000;

// ═══════════════════════════════════════════════════════════════════════════════
// OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Operation = enum(u8) {
    // Arithmetic
    add = 0,
    sub = 1,
    mul = 2,
    div = 3,
    neg = 4,
    
    // Bitwise
    shift_left = 5,
    shift_right = 6,
    bit_and = 7,
    bit_or = 8,
    bit_xor = 9,
    
    // Terminals
    constant = 10,
    variable = 11,
    
    pub fn arity(self: Operation) u8 {
        return switch (self) {
            .constant, .variable => 0,
            .neg => 1,
            else => 2,
        };
    }
    
    pub fn isCommutative(self: Operation) bool {
        return switch (self) {
            .add, .mul, .bit_and, .bit_or, .bit_xor => true,
            else => false,
        };
    }
    
    pub fn cost(self: Operation) u64 {
        return switch (self) {
            .constant, .variable => 0,
            .add, .sub, .neg => 1,
            .shift_left, .shift_right => 1,
            .bit_and, .bit_or, .bit_xor => 1,
            .mul => 3,
            .div => 10,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// E-CLASS ID
// ═══════════════════════════════════════════════════════════════════════════════

pub const EClassId = u32;

// ═══════════════════════════════════════════════════════════════════════════════
// E-NODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ENode = struct {
    op: Operation,
    children: [2]EClassId,
    value: ?i64, // For constants
    name: ?[]const u8, // For variables
    
    pub fn init(op: Operation) ENode {
        return .{
            .op = op,
            .children = [_]EClassId{0} ** 2,
            .value = null,
            .name = null,
        };
    }
    
    pub fn initConstant(value: i64) ENode {
        return .{
            .op = .constant,
            .children = [_]EClassId{0} ** 2,
            .value = value,
            .name = null,
        };
    }
    
    pub fn initVariable(name: []const u8) ENode {
        return .{
            .op = .variable,
            .children = [_]EClassId{0} ** 2,
            .value = null,
            .name = name,
        };
    }
    
    pub fn initBinary(op: Operation, left: EClassId, right: EClassId) ENode {
        return .{
            .op = op,
            .children = [_]EClassId{ left, right },
            .value = null,
            .name = null,
        };
    }
    
    pub fn initUnary(op: Operation, child: EClassId) ENode {
        return .{
            .op = op,
            .children = [_]EClassId{ child, 0 },
            .value = null,
            .name = null,
        };
    }
    
    pub fn cost(self: *const ENode) u64 {
        return self.op.cost();
    }
    
    pub fn eql(self: *const ENode, other: *const ENode) bool {
        if (self.op != other.op) return false;
        if (self.value != other.value) return false;
        
        const arity = self.op.arity();
        for (0..arity) |i| {
            if (self.children[i] != other.children[i]) return false;
        }
        
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// E-CLASS
// ═══════════════════════════════════════════════════════════════════════════════

pub const EClass = struct {
    id: EClassId,
    nodes: std.ArrayList(ENode),
    best_cost: u64,
    best_node_idx: ?usize,
    constant_value: ?i64, // Analysis: constant folding
    
    pub fn init(allocator: std.mem.Allocator, id: EClassId) EClass {
        return .{
            .id = id,
            .nodes = std.ArrayList(ENode).init(allocator),
            .best_cost = std.math.maxInt(u64),
            .best_node_idx = null,
            .constant_value = null,
        };
    }
    
    pub fn deinit(self: *EClass) void {
        self.nodes.deinit();
    }
    
    pub fn addNode(self: *EClass, node: ENode) !void {
        // Check for duplicates
        for (self.nodes.items) |existing| {
            if (existing.eql(&node)) return;
        }
        
        try self.nodes.append(node);
        
        // Update best cost
        const node_cost = node.cost();
        if (node_cost < self.best_cost) {
            self.best_cost = node_cost;
            self.best_node_idx = self.nodes.items.len - 1;
        }
        
        // Update constant analysis
        if (node.op == .constant) {
            self.constant_value = node.value;
        }
    }
    
    pub fn getBestNode(self: *const EClass) ?ENode {
        if (self.best_node_idx) |idx| {
            return self.nodes.items[idx];
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNION-FIND
// ═══════════════════════════════════════════════════════════════════════════════

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
    
    pub fn find(self: *UnionFind, id: EClassId) EClassId {
        if (self.parent.items[id] != id) {
            // Path compression
            self.parent.items[id] = self.find(self.parent.items[id]);
        }
        return self.parent.items[id];
    }
    
    pub fn union_(self: *UnionFind, a: EClassId, b: EClassId) EClassId {
        const root_a = self.find(a);
        const root_b = self.find(b);
        
        if (root_a == root_b) return root_a;
        
        // Union by rank
        if (self.rank.items[root_a] < self.rank.items[root_b]) {
            self.parent.items[root_a] = root_b;
            return root_b;
        } else if (self.rank.items[root_a] > self.rank.items[root_b]) {
            self.parent.items[root_b] = root_a;
            return root_a;
        } else {
            self.parent.items[root_b] = root_a;
            self.rank.items[root_a] += 1;
            return root_a;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWRITE RULES
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewriteRule = struct {
    name: []const u8,
    apply: *const fn (*EGraph, EClassId) ?EClassId,
    
    pub fn init(name: []const u8, apply: *const fn (*EGraph, EClassId) ?EClassId) RewriteRule {
        return .{
            .name = name,
            .apply = apply,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// E-GRAPH
// ═══════════════════════════════════════════════════════════════════════════════

pub const EGraph = struct {
    classes: std.AutoHashMap(EClassId, EClass),
    union_find: UnionFind,
    allocator: std.mem.Allocator,
    dirty: std.ArrayList(EClassId),
    
    pub fn init(allocator: std.mem.Allocator) EGraph {
        return .{
            .classes = std.AutoHashMap(EClassId, EClass).init(allocator),
            .union_find = UnionFind.init(allocator),
            .allocator = allocator,
            .dirty = std.ArrayList(EClassId).init(allocator),
        };
    }
    
    pub fn deinit(self: *EGraph) void {
        var iter = self.classes.valueIterator();
        while (iter.next()) |class| {
            class.deinit();
        }
        self.classes.deinit();
        self.union_find.deinit();
        self.dirty.deinit();
    }
    
    pub fn add(self: *EGraph, node: ENode) !EClassId {
        // Create new e-class
        const id = try self.union_find.makeSet();
        var class = EClass.init(self.allocator, id);
        try class.addNode(node);
        try self.classes.put(id, class);
        return id;
    }
    
    pub fn addConstant(self: *EGraph, value: i64) !EClassId {
        return self.add(ENode.initConstant(value));
    }
    
    pub fn addVariable(self: *EGraph, name: []const u8) !EClassId {
        return self.add(ENode.initVariable(name));
    }
    
    pub fn addBinary(self: *EGraph, op: Operation, left: EClassId, right: EClassId) !EClassId {
        return self.add(ENode.initBinary(op, left, right));
    }
    
    pub fn merge(self: *EGraph, a: EClassId, b: EClassId) !EClassId {
        const root_a = self.union_find.find(a);
        const root_b = self.union_find.find(b);
        
        if (root_a == root_b) return root_a;
        
        const new_root = self.union_find.union_(root_a, root_b);
        
        // Merge e-class contents
        const other_root = if (new_root == root_a) root_b else root_a;
        
        if (self.classes.getPtr(other_root)) |other_class| {
            if (self.classes.getPtr(new_root)) |root_class| {
                for (other_class.nodes.items) |node| {
                    try root_class.addNode(node);
                }
                
                // Merge constant analysis
                if (other_class.constant_value) |val| {
                    root_class.constant_value = val;
                }
            }
        }
        
        try self.dirty.append(new_root);
        return new_root;
    }
    
    pub fn find(self: *EGraph, id: EClassId) EClassId {
        return self.union_find.find(id);
    }
    
    pub fn getClass(self: *EGraph, id: EClassId) ?*EClass {
        const canonical = self.find(id);
        return self.classes.getPtr(canonical);
    }
    
    pub fn rebuild(self: *EGraph) !void {
        while (self.dirty.items.len > 0) {
            const id = self.dirty.pop();
            _ = self.find(id); // Ensure path compression
        }
    }
    
    pub fn saturate(self: *EGraph, rules: []const RewriteRule, max_iterations: usize) !usize {
        var iterations: usize = 0;
        var changed = true;
        
        while (changed and iterations < max_iterations) {
            changed = false;
            iterations += 1;
            
            // Collect all class IDs
            var class_ids = std.ArrayList(EClassId).init(self.allocator);
            defer class_ids.deinit();
            
            var iter = self.classes.keyIterator();
            while (iter.next()) |id| {
                try class_ids.append(id.*);
            }
            
            // Apply rules to each class
            for (class_ids.items) |class_id| {
                for (rules) |rule| {
                    if (rule.apply(self, class_id)) |new_id| {
                        _ = try self.merge(class_id, new_id);
                        changed = true;
                    }
                }
            }
            
            try self.rebuild();
        }
        
        return iterations;
    }
    
    pub fn extract(self: *EGraph, root: EClassId) ?ENode {
        const class = self.getClass(root) orelse return null;
        return class.getBestNode();
    }
    
    pub fn extractCost(self: *EGraph, root: EClassId) u64 {
        const class = self.getClass(root) orelse return std.math.maxInt(u64);
        return class.best_cost;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STANDARD REWRITE RULES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn ruleAddZero(egraph: *EGraph, class_id: EClassId) ?EClassId {
    const class = egraph.getClass(class_id) orelse return null;
    
    for (class.nodes.items) |node| {
        if (node.op == .add) {
            // Check if either child is zero
            if (egraph.getClass(node.children[0])) |left_class| {
                if (left_class.constant_value) |val| {
                    if (val == 0) return node.children[1];
                }
            }
            if (egraph.getClass(node.children[1])) |right_class| {
                if (right_class.constant_value) |val| {
                    if (val == 0) return node.children[0];
                }
            }
        }
    }
    return null;
}

pub fn ruleMulOne(egraph: *EGraph, class_id: EClassId) ?EClassId {
    const class = egraph.getClass(class_id) orelse return null;
    
    for (class.nodes.items) |node| {
        if (node.op == .mul) {
            if (egraph.getClass(node.children[0])) |left_class| {
                if (left_class.constant_value) |val| {
                    if (val == 1) return node.children[1];
                }
            }
            if (egraph.getClass(node.children[1])) |right_class| {
                if (right_class.constant_value) |val| {
                    if (val == 1) return node.children[0];
                }
            }
        }
    }
    return null;
}

pub fn ruleMulZero(egraph: *EGraph, class_id: EClassId) ?EClassId {
    const class = egraph.getClass(class_id) orelse return null;
    
    for (class.nodes.items) |node| {
        if (node.op == .mul) {
            if (egraph.getClass(node.children[0])) |left_class| {
                if (left_class.constant_value) |val| {
                    if (val == 0) return egraph.addConstant(0) catch null;
                }
            }
            if (egraph.getClass(node.children[1])) |right_class| {
                if (right_class.constant_value) |val| {
                    if (val == 0) return egraph.addConstant(0) catch null;
                }
            }
        }
    }
    return null;
}

pub fn ruleMulPow2(egraph: *EGraph, class_id: EClassId) ?EClassId {
    const class = egraph.getClass(class_id) orelse return null;
    
    for (class.nodes.items) |node| {
        if (node.op == .mul) {
            // Check if multiplying by power of 2
            if (egraph.getClass(node.children[1])) |right_class| {
                if (right_class.constant_value) |val| {
                    if (val > 0 and @popCount(@as(u64, @intCast(val))) == 1) {
                        // val is power of 2, replace with shift
                        const shift_amount = @ctz(@as(u64, @intCast(val)));
                        const shift_const = egraph.addConstant(shift_amount) catch return null;
                        return egraph.addBinary(.shift_left, node.children[0], shift_const) catch null;
                    }
                }
            }
        }
    }
    return null;
}

pub const STANDARD_RULES = [_]RewriteRule{
    RewriteRule.init("add_zero", ruleAddZero),
    RewriteRule.init("mul_one", ruleMulOne),
    RewriteRule.init("mul_zero", ruleMulZero),
    RewriteRule.init("mul_pow2", ruleMulPow2),
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden_identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

test "phoenix_number" {
    try std.testing.expectEqual(@as(usize, 999), PHOENIX);
    try std.testing.expectEqual(@as(usize, 27 * 37), PHOENIX);
}

test "egraph_add_nodes" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    const x = try egraph.addVariable("x");
    const zero = try egraph.addConstant(0);
    const add_x_0 = try egraph.addBinary(.add, x, zero);
    
    try std.testing.expect(x != zero);
    try std.testing.expect(add_x_0 != x);
}

test "egraph_merge" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    const x = try egraph.addVariable("x");
    const zero = try egraph.addConstant(0);
    const add_x_0 = try egraph.addBinary(.add, x, zero);
    
    // Merge (x + 0) with x
    _ = try egraph.merge(add_x_0, x);
    
    // They should now be in the same class
    try std.testing.expectEqual(egraph.find(add_x_0), egraph.find(x));
}

test "egraph_saturation" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    const x = try egraph.addVariable("x");
    const zero = try egraph.addConstant(0);
    _ = try egraph.addBinary(.add, x, zero);
    
    // Run saturation with add_zero rule
    const iterations = try egraph.saturate(&STANDARD_RULES, 10);
    
    try std.testing.expect(iterations > 0);
}

test "egraph_extraction" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();
    
    const x = try egraph.addVariable("x");
    const two = try egraph.addConstant(2);
    const mul_x_2 = try egraph.addBinary(.mul, x, two);
    
    // Run saturation - should find x << 1
    _ = try egraph.saturate(&STANDARD_RULES, 10);
    
    // Extract best
    const best = egraph.extract(mul_x_2);
    try std.testing.expect(best != null);
}

test "union_find" {
    const allocator = std.testing.allocator;
    var uf = UnionFind.init(allocator);
    defer uf.deinit();
    
    const a = try uf.makeSet();
    const b = try uf.makeSet();
    const c = try uf.makeSet();
    
    // Initially all separate
    try std.testing.expect(uf.find(a) != uf.find(b));
    
    // Union a and b
    _ = uf.union_(a, b);
    try std.testing.expectEqual(uf.find(a), uf.find(b));
    
    // c still separate
    try std.testing.expect(uf.find(a) != uf.find(c));
}
