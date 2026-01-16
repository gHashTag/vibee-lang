// E-Graph Based Optimization for VIBEE Code Generator
// Based on egg library (Willsey et al., 2021)
// Part of PAS Phase 3 implementation

const std = @import("std");

// ============================================================================
// EXPRESSION TYPES
// ============================================================================

pub const ExprTag = enum {
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
    land,
    lor,
    lnot,
    
    // Control
    ternary,
    call,
};

pub const Expr = struct {
    tag: ExprTag,
    children: []const EClassId,
    value: ?i64, // For constants
    name: ?[]const u8, // For variables and calls

    pub fn isConstant(self: Expr) bool {
        return self.tag == .constant;
    }

    pub fn isVariable(self: Expr) bool {
        return self.tag == .variable;
    }

    pub fn arity(self: Expr) usize {
        return self.children.len;
    }
};

pub const EClassId = u32;

// ============================================================================
// E-CLASS (Equivalence Class)
// ============================================================================

pub const EClass = struct {
    id: EClassId,
    nodes: std.ArrayList(Expr),
    parents: std.ArrayList(EClassId),

    pub fn init(allocator: std.mem.Allocator, id: EClassId) EClass {
        return .{
            .id = id,
            .nodes = std.ArrayList(Expr).init(allocator),
            .parents = std.ArrayList(EClassId).init(allocator),
        };
    }

    pub fn deinit(self: *EClass) void {
        self.nodes.deinit();
        self.parents.deinit();
    }

    pub fn addNode(self: *EClass, expr: Expr) !void {
        try self.nodes.append(expr);
    }
};

// ============================================================================
// REWRITE RULES
// ============================================================================

pub const RewriteRule = struct {
    name: []const u8,
    pattern: Pattern,
    replacement: Pattern,
    condition: ?*const fn (EGraph, []const EClassId) bool,
};

pub const Pattern = struct {
    tag: PatternTag,
    children: []const Pattern,
    var_name: ?[]const u8,
    const_value: ?i64,
};

pub const PatternTag = enum {
    // Match any expression
    wildcard,
    // Match specific expression type
    expr,
    // Match constant
    constant,
    // Match variable binding
    var_binding,
};

// ============================================================================
// E-GRAPH
// ============================================================================

pub const EGraph = struct {
    allocator: std.mem.Allocator,
    classes: std.AutoHashMap(EClassId, EClass),
    union_find: std.AutoHashMap(EClassId, EClassId),
    hashcons: std.StringHashMap(EClassId),
    next_id: EClassId,
    
    // Statistics
    merges: u64,
    nodes_added: u64,

    pub fn init(allocator: std.mem.Allocator) EGraph {
        return .{
            .allocator = allocator,
            .classes = std.AutoHashMap(EClassId, EClass).init(allocator),
            .union_find = std.AutoHashMap(EClassId, EClassId).init(allocator),
            .hashcons = std.StringHashMap(EClassId).init(allocator),
            .next_id = 0,
            .merges = 0,
            .nodes_added = 0,
        };
    }

    pub fn deinit(self: *EGraph) void {
        var it = self.classes.valueIterator();
        while (it.next()) |class| {
            @constCast(class).deinit();
        }
        self.classes.deinit();
        self.union_find.deinit();
        
        // Free hashcons keys (they were duplicated)
        var key_it = self.hashcons.keyIterator();
        while (key_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.hashcons.deinit();
    }

    /// Find the canonical representative of an e-class
    pub fn find(self: *EGraph, id: EClassId) EClassId {
        if (self.union_find.get(id)) |parent| {
            if (parent != id) {
                // Path compression
                const root = self.find(parent);
                self.union_find.put(id, root) catch {};
                return root;
            }
        }
        return id;
    }

    /// Add an expression to the e-graph, return its e-class id
    pub fn add(self: *EGraph, expr: Expr) !EClassId {
        // Canonicalize children
        var canonical_children = try self.allocator.alloc(EClassId, expr.children.len);
        defer self.allocator.free(canonical_children);
        
        for (expr.children, 0..) |child, i| {
            canonical_children[i] = self.find(child);
        }

        // Check if expression already exists (hashcons)
        const hash_key = try self.hashExpr(expr, canonical_children);
        defer self.allocator.free(hash_key);
        
        if (self.hashcons.get(hash_key)) |existing_id| {
            return self.find(existing_id);
        }

        // Create new e-class
        const id = self.next_id;
        self.next_id += 1;

        var class = EClass.init(self.allocator, id);
        
        // Create expression with canonical children
        const new_expr = Expr{
            .tag = expr.tag,
            .children = try self.allocator.dupe(EClassId, canonical_children),
            .value = expr.value,
            .name = expr.name,
        };
        
        try class.addNode(new_expr);
        try self.classes.put(id, class);
        try self.union_find.put(id, id);
        try self.hashcons.put(try self.allocator.dupe(u8, hash_key), id);

        self.nodes_added += 1;

        return id;
    }

    /// Merge two e-classes
    pub fn merge(self: *EGraph, id1: EClassId, id2: EClassId) !EClassId {
        const root1 = self.find(id1);
        const root2 = self.find(id2);

        if (root1 == root2) return root1;

        // Union by rank (simplified: always merge into root1)
        try self.union_find.put(root2, root1);

        // Merge nodes from root2 into root1
        if (self.classes.getPtr(root2)) |class2| {
            if (self.classes.getPtr(root1)) |class1| {
                for (class2.nodes.items) |node| {
                    try class1.addNode(node);
                }
            }
        }

        self.merges += 1;

        return root1;
    }

    /// Apply a rewrite rule to the e-graph
    pub fn applyRule(self: *EGraph, rule: RewriteRule) !bool {
        var changed = false;
        
        // Find all matches for the pattern
        var matches = std.ArrayList(Match).init(self.allocator);
        defer matches.deinit();
        
        try self.findMatches(rule.pattern, &matches);

        // Apply replacement for each match
        for (matches.items) |match| {
            // Check condition if present
            if (rule.condition) |cond| {
                if (!cond(self.*, match.bindings)) continue;
            }

            // Build replacement expression
            const replacement_id = try self.buildFromPattern(rule.replacement, match.bindings);
            
            // Merge with matched e-class
            _ = try self.merge(match.root, replacement_id);
            changed = true;
        }

        return changed;
    }

    /// Run equality saturation with given rules
    pub fn saturate(self: *EGraph, rules: []const RewriteRule, max_iterations: u32) !void {
        var iteration: u32 = 0;
        var changed = true;

        while (changed and iteration < max_iterations) {
            changed = false;
            
            for (rules) |rule| {
                if (try self.applyRule(rule)) {
                    changed = true;
                }
            }
            
            iteration += 1;
        }
    }

    /// Extract the best (lowest cost) expression from an e-class
    pub fn extract(self: *EGraph, root: EClassId, cost_fn: *const fn (Expr) u64) Expr {
        const canonical_root = self.find(root);
        
        if (self.classes.get(canonical_root)) |class| {
            var best_expr: ?Expr = null;
            var best_cost: u64 = std.math.maxInt(u64);

            for (class.nodes.items) |expr| {
                const cost = cost_fn(expr);
                if (cost < best_cost) {
                    best_cost = cost;
                    best_expr = expr;
                }
            }

            if (best_expr) |expr| {
                return expr;
            }
        }

        // Return a placeholder if nothing found
        return Expr{
            .tag = .constant,
            .children = &[_]EClassId{},
            .value = 0,
            .name = null,
        };
    }

    // Helper functions

    fn hashExpr(self: *EGraph, expr: Expr, children: []const EClassId) ![]u8 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&expr.tag));
        
        for (children) |child| {
            hasher.update(std.mem.asBytes(&child));
        }
        
        if (expr.value) |v| {
            hasher.update(std.mem.asBytes(&v));
        }
        
        const hash = hasher.final();
        var buf: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{x}", .{hash}) catch unreachable;
        
        return try self.allocator.dupe(u8, &buf);
    }

    /// Find all matches for a pattern in the e-graph
    fn findMatches(self: *EGraph, pattern: Pattern, matches: *std.ArrayList(Match)) !void {
        // Iterate over all e-classes to find pattern matches
        var class_iter = self.classes.iterator();
        while (class_iter.next()) |entry| {
            const class_id = entry.key_ptr.*;
            const class = entry.value_ptr.*;
            
            // Try to match pattern against each node in the class
            for (class.nodes.items) |node| {
                var bindings = std.ArrayList(EClassId).init(self.allocator);
                defer bindings.deinit();
                
                if (try self.matchPattern(pattern, node, &bindings)) {
                    try matches.append(.{
                        .root = class_id,
                        .bindings = try bindings.toOwnedSlice(),
                    });
                }
            }
        }
    }

    /// Match a pattern against an expression, collecting variable bindings
    fn matchPattern(self: *EGraph, pattern: Pattern, expr: Expr, bindings: *std.ArrayList(EClassId)) !bool {
        switch (pattern.tag) {
            .wildcard => {
                // Wildcard matches anything - bind the variable
                if (expr.children.len > 0) {
                    try bindings.append(self.find(expr.children[0]));
                }
                return true;
            },
            .constant => {
                // Match constant value
                if (expr.tag != .constant) return false;
                if (pattern.const_value) |pv| {
                    if (expr.value) |ev| {
                        return pv == ev;
                    }
                }
                return false;
            },
            .var_binding => {
                // Variable binding - just record the match
                return true;
            },
            .expr => {
                // Match expression structure
                if (pattern.children.len != expr.children.len) return false;
                
                // Recursively match children
                for (pattern.children, 0..) |child_pattern, i| {
                    if (i >= expr.children.len) return false;
                    
                    const child_class_id = expr.children[i];
                    const child_class = self.classes.get(self.find(child_class_id)) orelse return false;
                    
                    // Try to match against any node in the child class
                    var matched = false;
                    for (child_class.nodes.items) |child_node| {
                        if (try self.matchPattern(child_pattern, child_node, bindings)) {
                            matched = true;
                            break;
                        }
                    }
                    if (!matched) return false;
                }
                return true;
            },
        }
    }

    fn buildFromPattern(self: *EGraph, pattern: Pattern, bindings: []const EClassId) !EClassId {
        _ = bindings;
        
        switch (pattern.tag) {
            .constant => {
                return try self.add(.{
                    .tag = .constant,
                    .children = &[_]EClassId{},
                    .value = pattern.const_value,
                    .name = null,
                });
            },
            else => {
                // TODO: Implement full pattern building
                return 0;
            },
        }
    }
};

const Match = struct {
    root: EClassId,
    bindings: []const EClassId,
};

// ============================================================================
// STANDARD OPTIMIZATION RULES
// ============================================================================

pub const StandardRules = struct {
    /// Strength reduction rules
    pub const strength_reduction = [_]RewriteRule{
        // x * 2 => x << 1
        .{
            .name = "mul_2_to_shl",
            .pattern = .{ .tag = .expr, .children = &[_]Pattern{
                .{ .tag = .wildcard, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
                .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 2 },
            }, .var_name = null, .const_value = null },
            .replacement = .{ .tag = .expr, .children = &[_]Pattern{
                .{ .tag = .var_binding, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
                .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 1 },
            }, .var_name = null, .const_value = null },
            .condition = null,
        },
        // x * 4 => x << 2
        .{
            .name = "mul_4_to_shl",
            .pattern = .{ .tag = .expr, .children = &[_]Pattern{
                .{ .tag = .wildcard, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
                .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 4 },
            }, .var_name = null, .const_value = null },
            .replacement = .{ .tag = .expr, .children = &[_]Pattern{
                .{ .tag = .var_binding, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
                .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 2 },
            }, .var_name = null, .const_value = null },
            .condition = null,
        },
    };

    /// Algebraic simplification rules
    pub const algebraic = [_]RewriteRule{
        // x + 0 => x
        .{
            .name = "add_zero",
            .pattern = .{ .tag = .expr, .children = &[_]Pattern{
                .{ .tag = .wildcard, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
                .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 0 },
            }, .var_name = null, .const_value = null },
            .replacement = .{ .tag = .var_binding, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
            .condition = null,
        },
        // x * 1 => x
        .{
            .name = "mul_one",
            .pattern = .{ .tag = .expr, .children = &[_]Pattern{
                .{ .tag = .wildcard, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
                .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 1 },
            }, .var_name = null, .const_value = null },
            .replacement = .{ .tag = .var_binding, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
            .condition = null,
        },
        // x * 0 => 0
        .{
            .name = "mul_zero",
            .pattern = .{ .tag = .expr, .children = &[_]Pattern{
                .{ .tag = .wildcard, .children = &[_]Pattern{}, .var_name = "x", .const_value = null },
                .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 0 },
            }, .var_name = null, .const_value = null },
            .replacement = .{ .tag = .constant, .children = &[_]Pattern{}, .var_name = null, .const_value = 0 },
            .condition = null,
        },
    };
};

// ============================================================================
// COST MODEL
// ============================================================================

pub const CostModel = struct {
    /// Default cost function based on instruction latency
    pub fn defaultCost(expr: Expr) u64 {
        return switch (expr.tag) {
            .constant => 0,
            .variable => 1,
            .add, .sub => 1,
            .mul => 3,
            .div, .mod => 20,
            .shl, .shr => 1,
            .band, .bor, .bxor, .bnot => 1,
            .neg => 1,
            .eq, .ne, .lt, .le, .gt, .ge => 1,
            .land, .lor, .lnot => 1,
            .ternary => 2,
            .call => 10,
        };
    }

    /// Cost function optimizing for code size
    pub fn sizeCost(expr: Expr) u64 {
        return switch (expr.tag) {
            .constant => if (expr.value) |v| (if (v >= -128 and v <= 127) @as(u64, 1) else 4) else 4,
            .variable => 1,
            else => 1,
        };
    }
};

// ============================================================================
// OPTIMIZER INTERFACE
// ============================================================================

pub const Optimizer = struct {
    allocator: std.mem.Allocator,
    egraph: EGraph,
    rules: []const RewriteRule,

    pub fn init(allocator: std.mem.Allocator) Optimizer {
        // Combine all standard rules
        const all_rules = StandardRules.strength_reduction ++ StandardRules.algebraic;
        
        return .{
            .allocator = allocator,
            .egraph = EGraph.init(allocator),
            .rules = &all_rules,
        };
    }

    pub fn deinit(self: *Optimizer) void {
        self.egraph.deinit();
    }

    /// Optimize an expression
    pub fn optimize(self: *Optimizer, expr: Expr) !Expr {
        // Add expression to e-graph
        const root = try self.egraph.add(expr);

        // Run equality saturation
        try self.egraph.saturate(self.rules, 100);

        // Extract optimal expression
        return self.egraph.extract(root, CostModel.defaultCost);
    }

    /// Get optimization statistics
    pub fn getStats(self: *Optimizer) struct { merges: u64, nodes: u64 } {
        return .{
            .merges = self.egraph.merges,
            .nodes = self.egraph.nodes_added,
        };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "e-graph initialization" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();

    try std.testing.expect(egraph.next_id == 0);
}

test "e-graph add constant" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();

    const id = try egraph.add(.{
        .tag = .constant,
        .children = &[_]EClassId{},
        .value = 42,
        .name = null,
    });

    try std.testing.expect(id == 0);
    try std.testing.expect(egraph.nodes_added == 1);
}

test "e-graph add variable" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();

    const id = try egraph.add(.{
        .tag = .variable,
        .children = &[_]EClassId{},
        .value = null,
        .name = "x",
    });

    try std.testing.expect(id == 0);
}

test "e-graph merge" {
    const allocator = std.testing.allocator;
    var egraph = EGraph.init(allocator);
    defer egraph.deinit();

    const id1 = try egraph.add(.{
        .tag = .constant,
        .children = &[_]EClassId{},
        .value = 1,
        .name = null,
    });

    const id2 = try egraph.add(.{
        .tag = .constant,
        .children = &[_]EClassId{},
        .value = 2,
        .name = null,
    });

    const merged = try egraph.merge(id1, id2);
    
    try std.testing.expect(egraph.find(id1) == merged);
    try std.testing.expect(egraph.find(id2) == merged);
    try std.testing.expect(egraph.merges == 1);
}

test "optimizer initialization" {
    const allocator = std.testing.allocator;
    var optimizer = Optimizer.init(allocator);
    defer optimizer.deinit();

    const stats = optimizer.getStats();
    try std.testing.expect(stats.merges == 0);
    try std.testing.expect(stats.nodes == 0);
}

test "cost model" {
    const add_expr = Expr{
        .tag = .add,
        .children = &[_]EClassId{},
        .value = null,
        .name = null,
    };
    
    const mul_expr = Expr{
        .tag = .mul,
        .children = &[_]EClassId{},
        .value = null,
        .name = null,
    };
    
    const div_expr = Expr{
        .tag = .div,
        .children = &[_]EClassId{},
        .value = null,
        .name = null,
    };

    try std.testing.expect(CostModel.defaultCost(add_expr) == 1);
    try std.testing.expect(CostModel.defaultCost(mul_expr) == 3);
    try std.testing.expect(CostModel.defaultCost(div_expr) == 20);
}
