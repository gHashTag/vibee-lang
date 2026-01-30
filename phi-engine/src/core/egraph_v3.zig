const std = @import("std");
const Allocator = std.mem.Allocator;
const sacred_math = @import("sacred_math.zig");

/// TRINITY E-GRAPH ENGINE V3.0
/// "The Code That Rewrites Itself"
pub const EClassId = u32;

pub const ENode = union(enum) {
    constant: i64,
    variable: []const u8,
    // Operations
    add: [2]EClassId,
    mul: [2]EClassId,
    sub: [2]EClassId,
    // Trinity specific
    tri_shift: [2]EClassId, // << (ternary shift)
    tri_mac: [3]EClassId, // a * b + c (hardware native)
    tri_consensus: [2]EClassId, // max(a, b) logical
};

/// Custom Context for Hashing ENode (handling slices)
pub const ENodeContext = struct {
    pub fn hash(self: @This(), node: ENode) u64 {
        _ = self;
        var accessible_hasher = std.hash.Wyhash.init(0);
        switch (node) {
            .constant => |v| {
                accessible_hasher.update("constant");
                std.hash.autoHash(&accessible_hasher, v);
            },
            .variable => |name| {
                accessible_hasher.update("variable");
                accessible_hasher.update(name);
            },
            .add => |ids| {
                accessible_hasher.update("add");
                std.hash.autoHash(&accessible_hasher, ids);
            },
            .mul => |ids| {
                accessible_hasher.update("mul");
                std.hash.autoHash(&accessible_hasher, ids);
            },
            .sub => |ids| {
                accessible_hasher.update("sub");
                std.hash.autoHash(&accessible_hasher, ids);
            },
            .tri_shift => |ids| {
                accessible_hasher.update("tri_shift");
                std.hash.autoHash(&accessible_hasher, ids);
            },
            .tri_mac => |ids| {
                accessible_hasher.update("tri_mac");
                std.hash.autoHash(&accessible_hasher, ids);
            },
            .tri_consensus => |ids| {
                accessible_hasher.update("tri_consensus");
                std.hash.autoHash(&accessible_hasher, ids);
            },
        }
        return accessible_hasher.final();
    }

    pub fn eql(self: @This(), a: ENode, b: ENode) bool {
        _ = self;
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        switch (a) {
            .constant => |v| return v == b.constant,
            .variable => |name| return std.mem.eql(u8, name, b.variable),
            .add => |ids| return std.mem.eql(u32, &ids, &b.add),
            .mul => |ids| return std.mem.eql(u32, &ids, &b.mul),
            .sub => |ids| return std.mem.eql(u32, &ids, &b.sub),
            .tri_shift => |ids| return std.mem.eql(u32, &ids, &b.tri_shift),
            .tri_mac => |ids| return std.mem.eql(u32, &ids, &b.tri_mac),
            .tri_consensus => |ids| return std.mem.eql(u32, &ids, &b.tri_consensus),
        }
    }
};

pub const EClass = struct {
    id: EClassId,
    /// All equivalent nodes in this class
    nodes: std.ArrayListUnmanaged(ENode),
    /// Inverted index for upward merging (parents)
    parents: std.ArrayListUnmanaged(u32),

    pub fn init(allocator: Allocator, id: EClassId) EClass {
        _ = allocator;
        return EClass{
            .id = id,
            .nodes = .{},
            .parents = .{},
        };
    }

    pub fn deinit(self: *EClass, allocator: Allocator) void {
        self.nodes.deinit(allocator);
        self.parents.deinit(allocator);
    }
};

pub const EGraph = struct {
    allocator: Allocator,
    source: ?[]const u8 = null,
    classes: std.ArrayListUnmanaged(EClass),
    memo: std.HashMap(ENode, EClassId, ENodeContext, std.hash_map.default_max_load_percentage), // Hash consing with context
    union_find: std.AutoHashMap(EClassId, EClassId),

    pub fn init(allocator: Allocator) EGraph {
        return EGraph{
            .allocator = allocator,
            .source = null,
            .classes = .{},
            .memo = std.HashMap(ENode, EClassId, ENodeContext, std.hash_map.default_max_load_percentage).init(allocator),
            .union_find = std.AutoHashMap(EClassId, EClassId).init(allocator),
        };
    }

    pub fn deinit(self: *EGraph) void {
        for (self.classes.items) |*c| c.deinit(self.allocator);
        self.classes.deinit(self.allocator);
        self.memo.deinit();
        self.union_find.deinit();
    }

    /// Add a node to the graph. If it exists (canonically), return existing ID.
    pub fn add(self: *EGraph, node: ENode) !EClassId {
        const canonical_node = self.canonicalize(node);
        if (self.memo.get(canonical_node)) |id| {
            return self.find(id);
        }

        const id = @as(EClassId, @intCast(self.classes.items.len));
        var new_class = EClass.init(self.allocator, id);
        try new_class.nodes.append(self.allocator, canonical_node);
        try self.classes.append(self.allocator, new_class);
        try self.memo.put(canonical_node, id);
        // Initialize disjoint set
        try self.union_find.put(id, id);

        return id;
    }

    /// Find canonical ID (Union-Find path compression)
    pub fn find(self: *EGraph, id: EClassId) EClassId {
        var current = id;
        while (self.union_find.get(current)) |parent| {
            if (parent == current) break;
            current = parent;
        }
        return current;
    }

    /// Merge two E-Classes
    pub fn union_sets(self: *EGraph, id1: EClassId, id2: EClassId) !void {
        const root1 = self.find(id1);
        const root2 = self.find(id2);

        if (root1 == root2) return;

        // Naive merge: point root2 to root1
        try self.union_find.put(root2, root1);

        // Move all nodes from cluster 2 to cluster 1
        var class1 = &self.classes.items[root1];
        const class2 = &self.classes.items[root2];

        for (class2.nodes.items) |node| {
            try class1.nodes.append(self.allocator, node);
            // Re-memoize pointing to new root
            try self.memo.put(node, root1);
        }
    }

    fn canonicalize(self: *EGraph, node: ENode) ENode {
        var new_node = node;
        switch (new_node) {
            .add => |*ids| {
                ids[0] = self.find(ids[0]);
                ids[1] = self.find(ids[1]);
            },
            .mul => |*ids| {
                ids[0] = self.find(ids[0]);
                ids[1] = self.find(ids[1]);
            },
            .sub => |*ids| {
                ids[0] = self.find(ids[0]);
                ids[1] = self.find(ids[1]);
            },
            .tri_shift => |*ids| {
                ids[0] = self.find(ids[0]);
                ids[1] = self.find(ids[1]);
            },
            .tri_mac => |*ids| {
                ids[0] = self.find(ids[0]);
                ids[1] = self.find(ids[1]);
                ids[2] = self.find(ids[2]);
            },
            .tri_consensus => |*ids| {
                ids[0] = self.find(ids[0]);
                ids[1] = self.find(ids[1]);
            },
            else => {},
        }
        return new_node;
    }

    /// Extract the best node from a class (Simple greedy extraction)
    pub fn extractBest(self: *EGraph, id: EClassId) !ENode {
        const root = self.find(id);
        const class = &self.classes.items[root];

        if (class.nodes.items.len == 0) return error.EmptyEClass;

        return class.nodes.items[class.nodes.items.len - 1];
    }
};

/// Rewrite Rule Structure
pub const RewriteRule = struct {
    name: []const u8,
    apply: *const fn (graph: *EGraph, root: EClassId) bool,
};

/// The Sacred Loop of Optimization
pub fn saturate(graph: *EGraph, rules: []const RewriteRule) !void {
    const MAX_SHOUTS = 27; // Sacred limit (3^3)
    var changed = true;
    var iter: usize = 0;

    while (changed and iter < MAX_SHOUTS) : (iter += 1) {
        changed = false;

        const num_classes = graph.classes.items.len;
        for (rules) |rule| {
            for (0..num_classes) |i| {
                const id = @as(EClassId, @intCast(i));
                // Skip if not canonical leader or if class is "dead" (merged into another)
                if (graph.find(id) != id) continue;

                if (rule.apply(graph, id)) {
                    changed = true;
                }
            }
        }
    }
}
