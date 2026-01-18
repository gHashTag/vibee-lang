// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC OPTIMIZER - E-GRAPH BASED OPTIMIZATION
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V36 - Equality Saturation and Algebraic Simplification
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: ALG (Algebraic Rewriting), MLS (Cost Model)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// EXPRESSION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExprTag = enum(u8) {
    // Literals
    constant,
    variable,

    // Arithmetic
    add,
    sub,
    mul,
    div,
    mod,
    neg,

    // Bitwise
    shl,
    shr,
    band,
    bor,
    bxor,
    bnot,

    // Comparison
    eq,
    ne,
    lt,
    le,
    gt,
    ge,

    // Logical
    not,
    land,
    lor,

    // Sacred
    phi,
    pi,
    e_const,
    golden_identity,
};

pub const EClassId = u32;
pub const INVALID_ECLASS: EClassId = std.math.maxInt(EClassId);

pub const Expr = struct {
    tag: ExprTag,
    children: [2]EClassId,
    value: i64, // For constants
    name: []const u8, // For variables

    pub fn constant(value: i64) Expr {
        return .{
            .tag = .constant,
            .children = .{ INVALID_ECLASS, INVALID_ECLASS },
            .value = value,
            .name = "",
        };
    }

    pub fn variable(name: []const u8) Expr {
        return .{
            .tag = .variable,
            .children = .{ INVALID_ECLASS, INVALID_ECLASS },
            .value = 0,
            .name = name,
        };
    }

    pub fn binary(tag: ExprTag, left: EClassId, right: EClassId) Expr {
        return .{
            .tag = tag,
            .children = .{ left, right },
            .value = 0,
            .name = "",
        };
    }

    pub fn unary(tag: ExprTag, child: EClassId) Expr {
        return .{
            .tag = tag,
            .children = .{ child, INVALID_ECLASS },
            .value = 0,
            .name = "",
        };
    }

    pub fn sacred(tag: ExprTag) Expr {
        return .{
            .tag = tag,
            .children = .{ INVALID_ECLASS, INVALID_ECLASS },
            .value = 0,
            .name = "",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// E-CLASS
// ═══════════════════════════════════════════════════════════════════════════════

pub const EClass = struct {
    id: EClassId,
    nodes: ArrayList(Expr),
    parent: EClassId, // Union-find parent

    pub fn init(allocator: Allocator, id: EClassId) EClass {
        return .{
            .id = id,
            .nodes = ArrayList(Expr).init(allocator),
            .parent = id, // Initially points to self
        };
    }

    pub fn deinit(self: *EClass) void {
        self.nodes.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// E-GRAPH
// ═══════════════════════════════════════════════════════════════════════════════

pub const EGraph = struct {
    allocator: Allocator,
    classes: ArrayList(EClass),
    // Hash-consing for deduplication
    expr_to_class: AutoHashMap(u64, EClassId),

    // Metrics
    merges: u64,
    nodes_added: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .classes = ArrayList(EClass).init(allocator),
            .expr_to_class = AutoHashMap(u64, EClassId).init(allocator),
            .merges = 0,
            .nodes_added = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.classes.items) |*class| {
            class.deinit();
        }
        self.classes.deinit();
        self.expr_to_class.deinit();
    }

    /// Add expression to e-graph, returns e-class ID
    pub fn add(self: *Self, expr: Expr) !EClassId {
        // Canonicalize children
        var canonical_expr = expr;
        if (expr.children[0] != INVALID_ECLASS) {
            canonical_expr.children[0] = self.find(expr.children[0]);
        }
        if (expr.children[1] != INVALID_ECLASS) {
            canonical_expr.children[1] = self.find(expr.children[1]);
        }

        // Check if expression already exists (hash-consing)
        const hash = self.hashExpr(canonical_expr);
        if (self.expr_to_class.get(hash)) |existing| {
            return existing;
        }

        // Create new e-class
        const id: EClassId = @intCast(self.classes.items.len);
        var class = EClass.init(self.allocator, id);
        try class.nodes.append(canonical_expr);
        try self.classes.append(class);

        try self.expr_to_class.put(hash, id);
        self.nodes_added += 1;

        return id;
    }

    /// Union-find: find canonical representative
    pub fn find(self: *Self, id: EClassId) EClassId {
        if (id >= self.classes.items.len) return id;

        var current = id;
        while (self.classes.items[current].parent != current) {
            // Path compression
            const parent = self.classes.items[current].parent;
            self.classes.items[current].parent = self.classes.items[parent].parent;
            current = parent;
        }
        return current;
    }

    /// Merge two e-classes
    pub fn merge(self: *Self, a: EClassId, b: EClassId) EClassId {
        const root_a = self.find(a);
        const root_b = self.find(b);

        if (root_a == root_b) return root_a;

        // Union by rank (simplified: always merge b into a)
        self.classes.items[root_b].parent = root_a;

        // Move nodes from b to a
        for (self.classes.items[root_b].nodes.items) |node| {
            self.classes.items[root_a].nodes.append(node) catch {};
        }

        self.merges += 1;
        return root_a;
    }

    fn hashExpr(self: *Self, expr: Expr) u64 {
        _ = self;
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&expr.tag));
        hasher.update(std.mem.asBytes(&expr.children));
        hasher.update(std.mem.asBytes(&expr.value));
        return hasher.final();
    }

    pub fn getClass(self: *Self, id: EClassId) ?*EClass {
        const canonical = self.find(id);
        if (canonical >= self.classes.items.len) return null;
        return &self.classes.items[canonical];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWRITE RULES - ALG PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewriteRule = struct {
    name: []const u8,
    apply: *const fn (*EGraph, EClassId) ?EClassId,
};

pub const StandardRules = struct {
    /// x + 0 => x
    pub fn addZero(graph: *EGraph, id: EClassId) ?EClassId {
        const class = graph.getClass(id) orelse return null;

        for (class.nodes.items) |node| {
            if (node.tag == .add) {
                // Check if right child is 0
                if (graph.getClass(node.children[1])) |right_class| {
                    for (right_class.nodes.items) |right_node| {
                        if (right_node.tag == .constant and right_node.value == 0) {
                            return node.children[0];
                        }
                    }
                }
                // Check if left child is 0
                if (graph.getClass(node.children[0])) |left_class| {
                    for (left_class.nodes.items) |left_node| {
                        if (left_node.tag == .constant and left_node.value == 0) {
                            return node.children[1];
                        }
                    }
                }
            }
        }
        return null;
    }

    /// x * 1 => x
    pub fn mulOne(graph: *EGraph, id: EClassId) ?EClassId {
        const class = graph.getClass(id) orelse return null;

        for (class.nodes.items) |node| {
            if (node.tag == .mul) {
                if (graph.getClass(node.children[1])) |right_class| {
                    for (right_class.nodes.items) |right_node| {
                        if (right_node.tag == .constant and right_node.value == 1) {
                            return node.children[0];
                        }
                    }
                }
                if (graph.getClass(node.children[0])) |left_class| {
                    for (left_class.nodes.items) |left_node| {
                        if (left_node.tag == .constant and left_node.value == 1) {
                            return node.children[1];
                        }
                    }
                }
            }
        }
        return null;
    }

    /// x * 0 => 0
    pub fn mulZero(graph: *EGraph, id: EClassId) ?EClassId {
        const class = graph.getClass(id) orelse return null;

        for (class.nodes.items) |node| {
            if (node.tag == .mul) {
                if (graph.getClass(node.children[1])) |right_class| {
                    for (right_class.nodes.items) |right_node| {
                        if (right_node.tag == .constant and right_node.value == 0) {
                            return graph.add(Expr.constant(0)) catch null;
                        }
                    }
                }
                if (graph.getClass(node.children[0])) |left_class| {
                    for (left_class.nodes.items) |left_node| {
                        if (left_node.tag == .constant and left_node.value == 0) {
                            return graph.add(Expr.constant(0)) catch null;
                        }
                    }
                }
            }
        }
        return null;
    }

    /// x * 2 => x << 1 (strength reduction)
    pub fn mulTwoToShl(graph: *EGraph, id: EClassId) ?EClassId {
        const class = graph.getClass(id) orelse return null;

        for (class.nodes.items) |node| {
            if (node.tag == .mul) {
                if (graph.getClass(node.children[1])) |right_class| {
                    for (right_class.nodes.items) |right_node| {
                        if (right_node.tag == .constant and right_node.value == 2) {
                            const one = graph.add(Expr.constant(1)) catch return null;
                            return graph.add(Expr.binary(.shl, node.children[0], one)) catch null;
                        }
                    }
                }
            }
        }
        return null;
    }

    /// x - x => 0
    pub fn subSelf(graph: *EGraph, id: EClassId) ?EClassId {
        const class = graph.getClass(id) orelse return null;

        for (class.nodes.items) |node| {
            if (node.tag == .sub) {
                if (graph.find(node.children[0]) == graph.find(node.children[1])) {
                    return graph.add(Expr.constant(0)) catch null;
                }
            }
        }
        return null;
    }

    /// --x => x (double negation)
    pub fn doubleNeg(graph: *EGraph, id: EClassId) ?EClassId {
        const class = graph.getClass(id) orelse return null;

        for (class.nodes.items) |node| {
            if (node.tag == .neg) {
                if (graph.getClass(node.children[0])) |child_class| {
                    for (child_class.nodes.items) |child_node| {
                        if (child_node.tag == .neg) {
                            return child_node.children[0];
                        }
                    }
                }
            }
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COST MODEL - MLS PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const CostModel = struct {
    /// Default cost based on instruction latency
    pub fn defaultCost(expr: Expr) u32 {
        return switch (expr.tag) {
            .constant => 0,
            .variable => 1,
            .add, .sub => 1,
            .mul => 3,
            .div, .mod => 20,
            .shl, .shr => 1,
            .band, .bor, .bxor, .bnot => 1,
            .neg, .not => 1,
            .eq, .ne, .lt, .le, .gt, .ge => 1,
            .land, .lor => 1,
            .phi, .pi, .e_const => 0, // Sacred constants are free
            .golden_identity => 2, // φ² + 1/φ² computation
        };
    }

    /// Size-based cost for code size optimization
    pub fn sizeCost(expr: Expr) u32 {
        return switch (expr.tag) {
            .constant => if (expr.value >= -128 and expr.value <= 127) 1 else 4,
            else => 1,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Optimizer = struct {
    allocator: Allocator,
    graph: EGraph,
    rules: ArrayList(RewriteRule),
    max_iterations: u32,

    // Metrics
    rules_applied: u64,
    iterations_run: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        var opt = Self{
            .allocator = allocator,
            .graph = EGraph.init(allocator),
            .rules = ArrayList(RewriteRule).init(allocator),
            .max_iterations = 100,
            .rules_applied = 0,
            .iterations_run = 0,
        };

        // Add standard rules
        opt.addStandardRules() catch {};

        return opt;
    }

    pub fn deinit(self: *Self) void {
        self.graph.deinit();
        self.rules.deinit();
    }

    fn addStandardRules(self: *Self) !void {
        try self.rules.append(.{ .name = "add_zero", .apply = StandardRules.addZero });
        try self.rules.append(.{ .name = "mul_one", .apply = StandardRules.mulOne });
        try self.rules.append(.{ .name = "mul_zero", .apply = StandardRules.mulZero });
        try self.rules.append(.{ .name = "mul_2_to_shl", .apply = StandardRules.mulTwoToShl });
        try self.rules.append(.{ .name = "sub_self", .apply = StandardRules.subSelf });
        try self.rules.append(.{ .name = "double_neg", .apply = StandardRules.doubleNeg });
    }

    /// Add expression to optimizer
    pub fn addExpr(self: *Self, expr: Expr) !EClassId {
        return self.graph.add(expr);
    }

    /// Run equality saturation
    pub fn saturate(self: *Self) void {
        var iteration: u32 = 0;
        var changed = true;

        while (changed and iteration < self.max_iterations) {
            changed = false;
            iteration += 1;

            // Apply all rules to all e-classes
            for (0..self.graph.classes.items.len) |i| {
                const id: EClassId = @intCast(i);

                for (self.rules.items) |rule| {
                    if (rule.apply(&self.graph, id)) |new_id| {
                        if (new_id != id) {
                            _ = self.graph.merge(id, new_id);
                            self.rules_applied += 1;
                            changed = true;
                        }
                    }
                }
            }
        }

        self.iterations_run = iteration;
    }

    /// Extract lowest-cost expression from e-class
    pub fn extract(self: *Self, id: EClassId) ?Expr {
        const class = self.graph.getClass(id) orelse return null;

        var best_expr: ?Expr = null;
        var best_cost: u32 = std.math.maxInt(u32);

        for (class.nodes.items) |node| {
            const cost = CostModel.defaultCost(node);
            if (cost < best_cost) {
                best_cost = cost;
                best_expr = node;
            }
        }

        return best_expr;
    }

    pub fn getMetrics(self: *const Self) OptimizerMetrics {
        return .{
            .rules_applied = self.rules_applied,
            .iterations_run = self.iterations_run,
            .merges = self.graph.merges,
            .nodes_added = self.graph.nodes_added,
            .classes_count = self.graph.classes.items.len,
        };
    }
};

pub const OptimizerMetrics = struct {
    rules_applied: u64,
    iterations_run: u64,
    merges: u64,
    nodes_added: u64,
    classes_count: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "EGraph basic" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();

    const c1 = try graph.add(Expr.constant(42));
    const c2 = try graph.add(Expr.constant(42));

    try std.testing.expectEqual(c1, c2); // Same constant = same e-class
}

test "EGraph merge" {
    const allocator = std.testing.allocator;
    var graph = EGraph.init(allocator);
    defer graph.deinit();

    const a = try graph.add(Expr.constant(1));
    const b = try graph.add(Expr.constant(2));

    const merged = graph.merge(a, b);
    try std.testing.expectEqual(graph.find(a), graph.find(b));
    try std.testing.expectEqual(merged, graph.find(a));
}

test "Optimizer add_zero rule" {
    const allocator = std.testing.allocator;
    var opt = Optimizer.init(allocator);
    defer opt.deinit();

    // x + 0
    const x = try opt.addExpr(Expr.variable("x"));
    const zero = try opt.addExpr(Expr.constant(0));
    const add = try opt.addExpr(Expr.binary(.add, x, zero));

    opt.saturate();

    // After saturation, add should be equivalent to x
    try std.testing.expectEqual(opt.graph.find(add), opt.graph.find(x));
}

test "Optimizer mul_zero rule" {
    const allocator = std.testing.allocator;
    var opt = Optimizer.init(allocator);
    defer opt.deinit();

    // x * 0
    const x = try opt.addExpr(Expr.variable("x"));
    const zero = try opt.addExpr(Expr.constant(0));
    _ = try opt.addExpr(Expr.binary(.mul, x, zero));

    opt.saturate();

    try std.testing.expect(opt.rules_applied > 0);
}

test "Optimizer strength reduction" {
    const allocator = std.testing.allocator;
    var opt = Optimizer.init(allocator);
    defer opt.deinit();

    // x * 2 => x << 1
    const x = try opt.addExpr(Expr.variable("x"));
    const two = try opt.addExpr(Expr.constant(2));
    const mul = try opt.addExpr(Expr.binary(.mul, x, two));

    opt.saturate();

    // Check that shift was added
    const class = opt.graph.getClass(mul);
    try std.testing.expect(class != null);
    try std.testing.expect(class.?.nodes.items.len > 1);
}

test "CostModel" {
    try std.testing.expectEqual(@as(u32, 0), CostModel.defaultCost(Expr.constant(42)));
    try std.testing.expectEqual(@as(u32, 1), CostModel.defaultCost(Expr.variable("x")));
    try std.testing.expectEqual(@as(u32, 3), CostModel.defaultCost(Expr.binary(.mul, 0, 1)));
    try std.testing.expectEqual(@as(u32, 20), CostModel.defaultCost(Expr.binary(.div, 0, 1)));
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
