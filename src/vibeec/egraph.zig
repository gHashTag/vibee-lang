//! VIBEE E-Graph Pattern Matcher - PAS DAEMON V40
//! Паттерны: ALG (algebraic rewrites), HSH (hash-consing), PRE (canonical forms)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// E-NODE - Expression node in E-graph
// ═══════════════════════════════════════════════════════════════════════════════

pub const ENodeOp = enum(u8) {
    // Constants
    const_int,
    const_float,
    const_phi,    // Sacred φ
    const_pi,     // Sacred π
    const_e,      // Sacred e
    
    // Arithmetic
    add,
    sub,
    mul,
    div,
    neg,
    
    // Power/Log
    pow,
    sqrt,
    ln,
    exp,
    
    // Comparison
    eq,
    lt,
    
    // Variables
    var_ref,
    
    // Control
    phi_node,
    select,
};

pub const ENode = struct {
    op: ENodeOp,
    children: [3]?EClassId = .{ null, null, null },
    child_count: u8 = 0,
    
    // For constants
    const_value: ConstValue = .{ .int = 0 },
    
    // For variables
    var_name: ?[]const u8 = null,
    
    pub fn init(op: ENodeOp) ENode {
        return .{ .op = op };
    }
    
    pub fn withChildren(op: ENodeOp, c1: EClassId, c2: ?EClassId) ENode {
        var node = ENode.init(op);
        node.children[0] = c1;
        node.child_count = 1;
        if (c2) |c| {
            node.children[1] = c;
            node.child_count = 2;
        }
        return node;
    }
    
    pub fn constInt(value: i64) ENode {
        var node = ENode.init(.const_int);
        node.const_value = .{ .int = value };
        return node;
    }
    
    pub fn constFloat(value: f64) ENode {
        var node = ENode.init(.const_float);
        node.const_value = .{ .float = value };
        return node;
    }
    
    pub fn constPhi() ENode {
        var node = ENode.init(.const_phi);
        node.const_value = .{ .float = PHI };
        return node;
    }
    
    pub fn constPi() ENode {
        var node = ENode.init(.const_pi);
        node.const_value = .{ .float = PI };
        return node;
    }
    
    pub fn constE() ENode {
        var node = ENode.init(.const_e);
        node.const_value = .{ .float = E };
        return node;
    }
    
    /// Hash for hash-consing (HSH pattern)
    pub fn hash(self: *const ENode) u64 {
        var h: u64 = @intFromEnum(self.op);
        for (self.children[0..self.child_count]) |child| {
            if (child) |c| {
                h = h *% 31 +% c;
            }
        }
        switch (self.const_value) {
            .int => |v| h = h *% 31 +% @as(u64, @bitCast(v)),
            .float => |v| h = h *% 31 +% @as(u64, @bitCast(v)),
        }
        return h;
    }
    
    pub fn eql(self: *const ENode, other: *const ENode) bool {
        if (self.op != other.op) return false;
        if (self.child_count != other.child_count) return false;
        for (0..self.child_count) |i| {
            if (self.children[i] != other.children[i]) return false;
        }
        return switch (self.const_value) {
            .int => |v| other.const_value.int == v,
            .float => |v| other.const_value.float == v,
        };
    }
};

pub const ConstValue = union(enum) {
    int: i64,
    float: f64,
};

pub const EClassId = u32;

// ═══════════════════════════════════════════════════════════════════════════════
// E-CLASS - Equivalence class of expressions
// ═══════════════════════════════════════════════════════════════════════════════

pub const EClass = struct {
    id: EClassId,
    nodes: std.ArrayList(ENode),
    parents: std.ArrayList(ParentRef),
    
    // Canonical representative (PRE pattern)
    canonical: ?*ENode = null,
    
    pub fn init(allocator: Allocator, id: EClassId) EClass {
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
    
    pub fn addNode(self: *EClass, node: ENode) !void {
        try self.nodes.append(node);
        if (self.canonical == null) {
            self.canonical = &self.nodes.items[self.nodes.items.len - 1];
        }
    }
};

pub const ParentRef = struct {
    node_idx: usize,
    class_id: EClassId,
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWRITE RULE - Pattern matching rule
// ═══════════════════════════════════════════════════════════════════════════════

pub const Pattern = struct {
    op: ?ENodeOp,
    children: [2]?*Pattern,
    is_var: bool = false,
    var_id: u8 = 0,
    const_match: ?ConstValue = null,
    
    pub fn op_pattern(op: ENodeOp, left: ?*Pattern, right: ?*Pattern) Pattern {
        return .{
            .op = op,
            .children = .{ left, right },
        };
    }
    
    pub fn var_pattern(id: u8) Pattern {
        return .{
            .op = null,
            .children = .{ null, null },
            .is_var = true,
            .var_id = id,
        };
    }
    
    pub fn const_pattern(value: ConstValue) Pattern {
        return .{
            .op = null,
            .children = .{ null, null },
            .const_match = value,
        };
    }
};

pub const RewriteRule = struct {
    name: []const u8,
    lhs: Pattern,
    rhs: Pattern,
    condition: ?*const fn (*const EGraph, EClassId) bool = null,
    
    pub fn init(name: []const u8, lhs: Pattern, rhs: Pattern) RewriteRule {
        return .{
            .name = name,
            .lhs = lhs,
            .rhs = rhs,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// E-GRAPH - Main equality graph structure
// ═══════════════════════════════════════════════════════════════════════════════

pub const EGraph = struct {
    allocator: Allocator,
    
    // E-classes
    classes: std.AutoHashMap(EClassId, EClass),
    next_class_id: EClassId = 0,
    
    // Hash-consing (HSH pattern)
    hashcons: std.AutoHashMap(u64, EClassId),
    
    // Union-find for merging
    union_find: std.AutoHashMap(EClassId, EClassId),
    
    // Rewrite rules
    rules: std.ArrayList(RewriteRule),
    
    // Statistics
    stats: EGraphStats = .{},
    
    pub fn init(allocator: Allocator) EGraph {
        return .{
            .allocator = allocator,
            .classes = std.AutoHashMap(EClassId, EClass).init(allocator),
            .hashcons = std.AutoHashMap(u64, EClassId).init(allocator),
            .union_find = std.AutoHashMap(EClassId, EClassId).init(allocator),
            .rules = std.ArrayList(RewriteRule).init(allocator),
        };
    }
    
    pub fn deinit(self: *EGraph) void {
        var iter = self.classes.valueIterator();
        while (iter.next()) |class| {
            var mutable_class = class;
            mutable_class.deinit();
        }
        self.classes.deinit();
        self.hashcons.deinit();
        self.union_find.deinit();
        self.rules.deinit();
    }
    
    /// Add node to e-graph, return e-class id
    pub fn add(self: *EGraph, node: ENode) !EClassId {
        // Check hash-cons (HSH pattern)
        const h = node.hash();
        if (self.hashcons.get(h)) |existing| {
            self.stats.hashcons_hits += 1;
            return self.find(existing);
        }
        
        // Create new e-class
        const id = self.next_class_id;
        self.next_class_id += 1;
        
        var class = EClass.init(self.allocator, id);
        try class.addNode(node);
        try self.classes.put(id, class);
        try self.hashcons.put(h, id);
        try self.union_find.put(id, id);
        
        self.stats.nodes_added += 1;
        return id;
    }
    
    /// Find canonical e-class id (union-find)
    pub fn find(self: *EGraph, id: EClassId) EClassId {
        const parent = self.union_find.get(id) orelse id;
        if (parent == id) return id;
        
        // Path compression
        const root = self.find(parent);
        self.union_find.put(id, root) catch {};
        return root;
    }
    
    /// Merge two e-classes
    pub fn merge(self: *EGraph, id1: EClassId, id2: EClassId) !EClassId {
        const root1 = self.find(id1);
        const root2 = self.find(id2);
        
        if (root1 == root2) return root1;
        
        // Merge smaller into larger
        try self.union_find.put(root2, root1);
        
        // Merge nodes
        if (self.classes.getPtr(root2)) |class2| {
            if (self.classes.getPtr(root1)) |class1| {
                for (class2.nodes.items) |node| {
                    try class1.addNode(node);
                }
            }
        }
        
        self.stats.merges += 1;
        return root1;
    }
    
    /// Add rewrite rule
    pub fn addRule(self: *EGraph, rule: RewriteRule) !void {
        try self.rules.append(rule);
    }
    
    /// Run equality saturation
    pub fn saturate(self: *EGraph, max_iterations: u32) !void {
        var iteration: u32 = 0;
        while (iteration < max_iterations) : (iteration += 1) {
            var changed = false;
            
            for (self.rules.items) |rule| {
                if (try self.applyRule(rule)) {
                    changed = true;
                }
            }
            
            if (!changed) break;
            self.stats.iterations += 1;
        }
    }
    
    /// Apply single rewrite rule
    fn applyRule(self: *EGraph, rule: RewriteRule) !bool {
        var changed = false;
        
        var class_iter = self.classes.iterator();
        while (class_iter.next()) |entry| {
            const class_id = entry.key_ptr.*;
            
            // Try to match LHS pattern
            var bindings: [8]?EClassId = .{null} ** 8;
            if (self.matchPattern(&rule.lhs, class_id, &bindings)) {
                // Check condition if present
                if (rule.condition) |cond| {
                    if (!cond(self, class_id)) continue;
                }
                
                // Build RHS and merge
                if (try self.buildPattern(&rule.rhs, &bindings)) |rhs_id| {
                    _ = try self.merge(class_id, rhs_id);
                    changed = true;
                    self.stats.rewrites += 1;
                }
            }
        }
        
        return changed;
    }
    
    /// Match pattern against e-class
    fn matchPattern(self: *EGraph, pattern: *const Pattern, class_id: EClassId, bindings: *[8]?EClassId) bool {
        const root = self.find(class_id);
        
        // Variable pattern - bind or check
        if (pattern.is_var) {
            if (bindings[pattern.var_id]) |bound| {
                return self.find(bound) == root;
            }
            bindings[pattern.var_id] = root;
            return true;
        }
        
        // Constant pattern
        if (pattern.const_match) |expected| {
            const class = self.classes.get(root) orelse return false;
            for (class.nodes.items) |node| {
                if (node.op == .const_int or node.op == .const_float) {
                    switch (expected) {
                        .int => |v| if (node.const_value.int == v) return true,
                        .float => |v| if (@abs(node.const_value.float - v) < 0.0001) return true,
                    }
                }
            }
            return false;
        }
        
        // Operator pattern
        if (pattern.op) |op| {
            const class = self.classes.get(root) orelse return false;
            for (class.nodes.items) |node| {
                if (node.op == op) {
                    var matches = true;
                    
                    if (pattern.children[0]) |child_pat| {
                        if (node.children[0]) |child_id| {
                            if (!self.matchPattern(child_pat, child_id, bindings)) {
                                matches = false;
                            }
                        } else matches = false;
                    }
                    
                    if (matches and pattern.children[1] != null) {
                        if (pattern.children[1]) |child_pat| {
                            if (node.children[1]) |child_id| {
                                if (!self.matchPattern(child_pat, child_id, bindings)) {
                                    matches = false;
                                }
                            } else matches = false;
                        }
                    }
                    
                    if (matches) return true;
                }
            }
        }
        
        return false;
    }
    
    /// Build expression from pattern
    fn buildPattern(self: *EGraph, pattern: *const Pattern, bindings: *[8]?EClassId) !?EClassId {
        if (pattern.is_var) {
            return bindings[pattern.var_id];
        }
        
        if (pattern.const_match) |value| {
            return switch (value) {
                .int => |v| try self.add(ENode.constInt(v)),
                .float => |v| try self.add(ENode.constFloat(v)),
            };
        }
        
        if (pattern.op) |op| {
            var node = ENode.init(op);
            
            if (pattern.children[0]) |child_pat| {
                if (try self.buildPattern(child_pat, bindings)) |child_id| {
                    node.children[0] = child_id;
                    node.child_count = 1;
                }
            }
            
            if (pattern.children[1]) |child_pat| {
                if (try self.buildPattern(child_pat, bindings)) |child_id| {
                    node.children[1] = child_id;
                    node.child_count = 2;
                }
            }
            
            return try self.add(node);
        }
        
        return null;
    }
    
    /// Get e-class
    pub fn getClass(self: *const EGraph, id: EClassId) ?*const EClass {
        const root = @constCast(self).find(id);
        return self.classes.getPtr(root);
    }
    
    /// Get statistics
    pub fn getStats(self: *const EGraph) EGraphStats {
        return self.stats;
    }
};

pub const EGraphStats = struct {
    nodes_added: u64 = 0,
    merges: u64 = 0,
    rewrites: u64 = 0,
    iterations: u64 = 0,
    hashcons_hits: u64 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED RULES - Algebraic rules for sacred constants
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredRules = struct {
    // Static patterns to avoid stack issues
    var x_var_storage: Pattern = Pattern.var_pattern(0);
    var zero_storage: Pattern = Pattern.const_pattern(.{ .int = 0 });
    var one_storage: Pattern = Pattern.const_pattern(.{ .int = 1 });
    
    /// Initialize e-graph with sacred algebraic rules
    pub fn addSacredRules(graph: *EGraph) !void {
        // x + 0 = x
        try graph.addRule(RewriteRule.init(
            "add_zero",
            Pattern.op_pattern(.add, &x_var_storage, &zero_storage),
            x_var_storage,
        ));
        
        // x * 1 = x
        try graph.addRule(RewriteRule.init(
            "mul_one",
            Pattern.op_pattern(.mul, &x_var_storage, &one_storage),
            x_var_storage,
        ));
        
        // x * 0 = 0
        try graph.addRule(RewriteRule.init(
            "mul_zero",
            Pattern.op_pattern(.mul, &x_var_storage, &zero_storage),
            zero_storage,
        ));
    }
    
    /// Verify golden identity: φ² + 1/φ² = 3
    pub fn verifyGoldenIdentity() bool {
        const phi_sq = PHI * PHI;
        const inv_phi_sq = 1.0 / phi_sq;
        const result = phi_sq + inv_phi_sq;
        return @abs(result - GOLDEN_IDENTITY) < 0.0001;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "EGraph basic operations" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();
    
    const c1 = try graph.add(ENode.constInt(42));
    const c2 = try graph.add(ENode.constInt(10));
    
    const add_node = ENode.withChildren(.add, c1, c2);
    const add_id = try graph.add(add_node);
    
    try std.testing.expect(add_id != c1);
    try std.testing.expect(add_id != c2);
}

test "EGraph hash-consing" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();
    
    const c1 = try graph.add(ENode.constInt(42));
    const c2 = try graph.add(ENode.constInt(42));
    
    // Same constant should return same e-class
    try std.testing.expectEqual(c1, c2);
    try std.testing.expect(graph.stats.hashcons_hits > 0);
}

test "EGraph merge" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();
    
    const c1 = try graph.add(ENode.constInt(1));
    const c2 = try graph.add(ENode.constInt(2));
    
    const merged = try graph.merge(c1, c2);
    
    try std.testing.expectEqual(graph.find(c1), graph.find(c2));
    try std.testing.expectEqual(merged, graph.find(c1));
}

test "EGraph sacred constants" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();
    
    const phi_id = try graph.add(ENode.constPhi());
    const pi_id = try graph.add(ENode.constPi());
    const e_id = try graph.add(ENode.constE());
    
    const phi_class = graph.getClass(phi_id).?;
    try std.testing.expect(@abs(phi_class.nodes.items[0].const_value.float - PHI) < 0.0001);
    
    _ = pi_id;
    _ = e_id;
}

test "EGraph rewrite rules" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();
    
    try SacredRules.addSacredRules(&graph);
    
    // Build x + 0
    const x = try graph.add(ENode.constInt(42));
    const zero = try graph.add(ENode.constInt(0));
    const add_node = ENode.withChildren(.add, x, zero);
    const add_id = try graph.add(add_node);
    
    // Saturate
    try graph.saturate(10);
    
    // x + 0 should be equivalent to x
    try std.testing.expectEqual(graph.find(add_id), graph.find(x));
}

test "EGraph mul_zero rule" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();
    
    try SacredRules.addSacredRules(&graph);
    
    const x = try graph.add(ENode.constInt(999));
    const zero = try graph.add(ENode.constInt(0));
    const mul_node = ENode.withChildren(.mul, x, zero);
    const mul_id = try graph.add(mul_node);
    
    try graph.saturate(10);
    
    // x * 0 should be equivalent to 0
    try std.testing.expectEqual(graph.find(mul_id), graph.find(zero));
}

test "golden identity verification" {
    try std.testing.expect(SacredRules.verifyGoldenIdentity());
}

test "EGraph statistics" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();
    
    _ = try graph.add(ENode.constInt(1));
    _ = try graph.add(ENode.constInt(2));
    _ = try graph.add(ENode.constInt(1)); // Hash-cons hit
    
    const stats = graph.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.nodes_added);
    try std.testing.expectEqual(@as(u64, 1), stats.hashcons_hits);
}
