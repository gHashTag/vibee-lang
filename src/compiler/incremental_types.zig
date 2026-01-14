// Incremental Type Checking for VIBEE
// Based on Salsa (Matsakis, 2018) and demand-driven evaluation
// Part of PAS Phase 2 implementation

const std = @import("std");
const parser = @import("parser.zig");

// ============================================================================
// TYPE SYSTEM
// ============================================================================

pub const Type = union(enum) {
    // Primitive types
    void_type,
    bool_type,
    int_type: IntType,
    float_type: FloatType,
    string_type,
    
    // Compound types
    array_type: *const ArrayType,
    slice_type: *const SliceType,
    optional_type: *const Type,
    error_union: *const ErrorUnion,
    
    // User-defined types
    struct_type: *const StructType,
    enum_type: *const EnumType,
    union_type: *const UnionType,
    
    // Function types
    function_type: *const FunctionType,
    
    // Special
    any_type,
    unknown_type,
    error_type,

    pub fn eql(self: Type, other: Type) bool {
        return switch (self) {
            .void_type => other == .void_type,
            .bool_type => other == .bool_type,
            .string_type => other == .string_type,
            .any_type => other == .any_type,
            .unknown_type => other == .unknown_type,
            .error_type => other == .error_type,
            .int_type => |i| switch (other) {
                .int_type => |j| i.bits == j.bits and i.signed == j.signed,
                else => false,
            },
            .float_type => |f| switch (other) {
                .float_type => |g| f.bits == g.bits,
                else => false,
            },
            else => false, // Complex types need deep comparison
        };
    }

    pub fn format(self: Type, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .void_type => try writer.writeAll("void"),
            .bool_type => try writer.writeAll("bool"),
            .string_type => try writer.writeAll("str"),
            .any_type => try writer.writeAll("any"),
            .unknown_type => try writer.writeAll("?"),
            .error_type => try writer.writeAll("error"),
            .int_type => |i| try writer.print("{s}{d}", .{ if (i.signed) "i" else "u", i.bits }),
            .float_type => |f| try writer.print("f{d}", .{f.bits}),
            .array_type => |a| try writer.print("[{d}]{}", .{ a.len, a.elem_type }),
            .slice_type => |s| try writer.print("[]{}", .{s.elem_type}),
            .optional_type => |o| try writer.print("?{}", .{o.*}),
            .struct_type => |s| try writer.print("struct {s}", .{s.name}),
            .enum_type => |e| try writer.print("enum {s}", .{e.name}),
            .function_type => |f| {
                try writer.writeAll("fn(");
                for (f.params, 0..) |p, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try writer.print("{}", .{p});
                }
                try writer.print(") {}", .{f.return_type});
            },
            else => try writer.writeAll("<complex>"),
        }
    }
};

pub const IntType = struct {
    bits: u16,
    signed: bool,
};

pub const FloatType = struct {
    bits: u16,
};

pub const ArrayType = struct {
    elem_type: Type,
    len: usize,
};

pub const SliceType = struct {
    elem_type: Type,
};

pub const ErrorUnion = struct {
    error_type: Type,
    payload_type: Type,
};

pub const StructType = struct {
    name: []const u8,
    fields: []const StructField,
};

pub const StructField = struct {
    name: []const u8,
    field_type: Type,
    default_value: ?[]const u8,
};

pub const EnumType = struct {
    name: []const u8,
    variants: []const []const u8,
    tag_type: ?Type,
};

pub const UnionType = struct {
    name: []const u8,
    variants: []const UnionVariant,
    tag_type: ?Type,
};

pub const UnionVariant = struct {
    name: []const u8,
    payload_type: ?Type,
};

pub const FunctionType = struct {
    params: []const Type,
    return_type: Type,
};

// ============================================================================
// SYMBOL TABLE
// ============================================================================

pub const Symbol = struct {
    name: []const u8,
    symbol_type: Type,
    scope: ScopeId,
    definition_loc: Location,
    is_mutable: bool,
    is_public: bool,
};

pub const ScopeId = u32;

pub const Location = struct {
    file: []const u8,
    line: u32,
    column: u32,
};

// ============================================================================
// DEPENDENCY GRAPH
// ============================================================================

pub const DependencyGraph = struct {
    allocator: std.mem.Allocator,
    // Symbol -> Symbols it depends on
    dependencies: std.StringHashMap(std.ArrayList([]const u8)),
    // Symbol -> Symbols that depend on it
    dependents: std.StringHashMap(std.ArrayList([]const u8)),

    pub fn init(allocator: std.mem.Allocator) DependencyGraph {
        return .{
            .allocator = allocator,
            .dependencies = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .dependents = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
        };
    }

    pub fn deinit(self: *DependencyGraph) void {
        var dep_it = self.dependencies.valueIterator();
        while (dep_it.next()) |list| {
            list.deinit();
        }
        self.dependencies.deinit();

        var rev_it = self.dependents.valueIterator();
        while (rev_it.next()) |list| {
            list.deinit();
        }
        self.dependents.deinit();
    }

    /// Add a dependency: `from` depends on `to`
    pub fn addDependency(self: *DependencyGraph, from: []const u8, to: []const u8) !void {
        // Add forward edge
        const deps = try self.dependencies.getOrPut(from);
        if (!deps.found_existing) {
            deps.value_ptr.* = std.ArrayList([]const u8).init(self.allocator);
        }
        try deps.value_ptr.append(to);

        // Add reverse edge
        const rev = try self.dependents.getOrPut(to);
        if (!rev.found_existing) {
            rev.value_ptr.* = std.ArrayList([]const u8).init(self.allocator);
        }
        try rev.value_ptr.append(from);
    }

    /// Get all symbols that depend on the given symbol
    pub fn getDependents(self: *DependencyGraph, symbol: []const u8) []const []const u8 {
        if (self.dependents.get(symbol)) |list| {
            return list.items;
        }
        return &[_][]const u8{};
    }

    /// Get all symbols that the given symbol depends on
    pub fn getDependencies(self: *DependencyGraph, symbol: []const u8) []const []const u8 {
        if (self.dependencies.get(symbol)) |list| {
            return list.items;
        }
        return &[_][]const u8{};
    }

    /// Get transitive closure of dependents (all affected symbols)
    pub fn getTransitiveDependents(self: *DependencyGraph, symbols: []const []const u8) ![][]const u8 {
        var visited = std.StringHashMap(void).init(self.allocator);
        defer visited.deinit();

        var result = std.ArrayList([]const u8).init(self.allocator);

        var queue = std.ArrayList([]const u8).init(self.allocator);
        defer queue.deinit();

        // Initialize queue with input symbols
        for (symbols) |s| {
            try queue.append(s);
        }

        // BFS
        while (queue.items.len > 0) {
            const current = queue.orderedRemove(0);

            if (visited.contains(current)) continue;
            try visited.put(current, {});
            try result.append(current);

            // Add dependents to queue
            for (self.getDependents(current)) |dep| {
                if (!visited.contains(dep)) {
                    try queue.append(dep);
                }
            }
        }

        return result.toOwnedSlice();
    }
};

// ============================================================================
// INCREMENTAL TYPE CHECKER
// ============================================================================

pub const TypeCheckResult = struct {
    symbol: []const u8,
    inferred_type: Type,
    errors: []const TypeError,
    dependencies: []const []const u8,
};

pub const TypeError = struct {
    message: []const u8,
    location: Location,
    severity: Severity,

    pub const Severity = enum {
        error,
        warning,
        hint,
    };
};

pub const CacheEntry = struct {
    result: TypeCheckResult,
    is_dirty: bool,
    version: u64,
};

pub const IncrementalTypeChecker = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap(CacheEntry),
    dependency_graph: DependencyGraph,
    current_version: u64,
    
    // Statistics
    cache_hits: u64,
    cache_misses: u64,
    symbols_checked: u64,

    pub fn init(allocator: std.mem.Allocator) IncrementalTypeChecker {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap(CacheEntry).init(allocator),
            .dependency_graph = DependencyGraph.init(allocator),
            .current_version = 0,
            .cache_hits = 0,
            .cache_misses = 0,
            .symbols_checked = 0,
        };
    }

    pub fn deinit(self: *IncrementalTypeChecker) void {
        self.cache.deinit();
        self.dependency_graph.deinit();
    }

    /// Check type of a symbol (with caching)
    pub fn checkSymbol(self: *IncrementalTypeChecker, symbol: []const u8, spec: *const parser.Spec) !TypeCheckResult {
        // Check cache
        if (self.cache.get(symbol)) |entry| {
            if (!entry.is_dirty) {
                self.cache_hits += 1;
                return entry.result;
            }
        }

        self.cache_misses += 1;
        self.symbols_checked += 1;

        // Compute type
        const result = try self.computeType(symbol, spec);

        // Cache result
        try self.cache.put(symbol, .{
            .result = result,
            .is_dirty = false,
            .version = self.current_version,
        });

        return result;
    }

    /// Invalidate symbols affected by changes
    pub fn invalidate(self: *IncrementalTypeChecker, changed_symbols: []const []const u8) !void {
        self.current_version += 1;

        // Get all affected symbols
        const affected = try self.dependency_graph.getTransitiveDependents(changed_symbols);
        defer self.allocator.free(affected);

        // Mark as dirty
        for (affected) |symbol| {
            if (self.cache.getPtr(symbol)) |entry| {
                entry.is_dirty = true;
            }
        }
    }

    /// Recheck all dirty symbols
    pub fn recheckDirty(self: *IncrementalTypeChecker, spec: *const parser.Spec) ![]TypeCheckResult {
        var results = std.ArrayList(TypeCheckResult).init(self.allocator);

        var it = self.cache.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.is_dirty) {
                const result = try self.checkSymbol(entry.key_ptr.*, spec);
                try results.append(result);
            }
        }

        return results.toOwnedSlice();
    }

    fn computeType(self: *IncrementalTypeChecker, symbol: []const u8, spec: *const parser.Spec) !TypeCheckResult {
        var errors = std.ArrayList(TypeError).init(self.allocator);
        var dependencies = std.ArrayList([]const u8).init(self.allocator);

        // Find symbol in spec
        var inferred_type: Type = .unknown_type;

        // Check types
        for (spec.types) |t| {
            if (std.mem.eql(u8, t.name, symbol)) {
                inferred_type = .{ .struct_type = &StructType{
                    .name = t.name,
                    .fields = &[_]StructField{},
                } };

                // Add dependencies on field types
                for (t.fields) |field| {
                    try dependencies.append(field.type_name);
                    try self.dependency_graph.addDependency(symbol, field.type_name);
                }
                break;
            }
        }

        // Check functions
        for (spec.functions) |f| {
            if (std.mem.eql(u8, f.name, symbol)) {
                inferred_type = .{ .function_type = &FunctionType{
                    .params = &[_]Type{},
                    .return_type = try self.resolveTypeName(f.returns),
                } };

                // Add dependencies on param and return types
                for (f.params) |param| {
                    try dependencies.append(param.type_name);
                    try self.dependency_graph.addDependency(symbol, param.type_name);
                }
                try dependencies.append(f.returns);
                try self.dependency_graph.addDependency(symbol, f.returns);
                break;
            }
        }

        // Check behaviors
        for (spec.behaviors) |b| {
            if (std.mem.eql(u8, b.name, symbol)) {
                // Behaviors are implicitly function types
                inferred_type = .{ .function_type = &FunctionType{
                    .params = &[_]Type{},
                    .return_type = .void_type,
                } };
                break;
            }
        }

        if (inferred_type == .unknown_type) {
            try errors.append(.{
                .message = "Unknown symbol",
                .location = .{ .file = "", .line = 0, .column = 0 },
                .severity = .error,
            });
        }

        return .{
            .symbol = symbol,
            .inferred_type = inferred_type,
            .errors = try errors.toOwnedSlice(),
            .dependencies = try dependencies.toOwnedSlice(),
        };
    }

    fn resolveTypeName(self: *IncrementalTypeChecker, name: []const u8) !Type {
        _ = self;
        
        // Built-in types
        if (std.mem.eql(u8, name, "void")) return .void_type;
        if (std.mem.eql(u8, name, "bool")) return .bool_type;
        if (std.mem.eql(u8, name, "str")) return .string_type;
        if (std.mem.eql(u8, name, "any")) return .any_type;

        // Integer types
        if (std.mem.startsWith(u8, name, "i") or std.mem.startsWith(u8, name, "u")) {
            const signed = name[0] == 'i';
            const bits = std.fmt.parseInt(u16, name[1..], 10) catch return .unknown_type;
            return .{ .int_type = .{ .bits = bits, .signed = signed } };
        }

        // Float types
        if (std.mem.startsWith(u8, name, "f")) {
            const bits = std.fmt.parseInt(u16, name[1..], 10) catch return .unknown_type;
            return .{ .float_type = .{ .bits = bits } };
        }

        return .unknown_type;
    }

    /// Get statistics
    pub fn getStats(self: *IncrementalTypeChecker) struct {
        cache_hits: u64,
        cache_misses: u64,
        hit_rate: f64,
        symbols_checked: u64,
    } {
        const total = self.cache_hits + self.cache_misses;
        const hit_rate = if (total > 0) @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(total)) else 0.0;

        return .{
            .cache_hits = self.cache_hits,
            .cache_misses = self.cache_misses,
            .hit_rate = hit_rate,
            .symbols_checked = self.symbols_checked,
        };
    }
};

// ============================================================================
// PARALLEL CONSTRAINT SOLVER
// ============================================================================

pub const Constraint = struct {
    lhs: Type,
    rhs: Type,
    location: Location,
};

pub const Substitution = struct {
    allocator: std.mem.Allocator,
    mappings: std.StringHashMap(Type),

    pub fn init(allocator: std.mem.Allocator) Substitution {
        return .{
            .allocator = allocator,
            .mappings = std.StringHashMap(Type).init(allocator),
        };
    }

    pub fn deinit(self: *Substitution) void {
        self.mappings.deinit();
    }

    pub fn apply(self: *Substitution, ty: Type) Type {
        _ = self;
        // For now, just return the type as-is
        // Full implementation would substitute type variables
        return ty;
    }

    pub fn compose(self: *Substitution, other: *const Substitution) !void {
        var it = other.mappings.iterator();
        while (it.next()) |entry| {
            try self.mappings.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
};

pub const UnificationError = error{
    TypeMismatch,
    OccursCheck,
    OutOfMemory,
};

pub const ParallelConstraintSolver = struct {
    allocator: std.mem.Allocator,
    thread_count: usize,

    pub fn init(allocator: std.mem.Allocator) ParallelConstraintSolver {
        return .{
            .allocator = allocator,
            .thread_count = @min(std.Thread.getCpuCount() catch 1, 8),
        };
    }

    /// Solve constraints (potentially in parallel)
    pub fn solve(self: *ParallelConstraintSolver, constraints: []const Constraint) !Substitution {
        if (constraints.len < 10 or self.thread_count == 1) {
            // Sequential solving for small constraint sets
            return self.solveSequential(constraints);
        }

        // Partition constraints into independent groups
        const partitions = try self.partitionConstraints(constraints);
        defer self.allocator.free(partitions);

        // For now, solve sequentially (parallel implementation would use threads)
        var result = Substitution.init(self.allocator);

        for (partitions) |partition| {
            const partial = try self.solveSequential(partition);
            defer partial.deinit();
            try result.compose(&partial);
        }

        return result;
    }

    fn solveSequential(self: *ParallelConstraintSolver, constraints: []const Constraint) !Substitution {
        var subst = Substitution.init(self.allocator);

        for (constraints) |constraint| {
            try self.unify(&subst, constraint.lhs, constraint.rhs);
        }

        return subst;
    }

    fn unify(self: *ParallelConstraintSolver, subst: *Substitution, t1: Type, t2: Type) !void {
        _ = self;

        const s1 = subst.apply(t1);
        const s2 = subst.apply(t2);

        if (s1.eql(s2)) return;

        // Handle specific type combinations
        switch (s1) {
            .unknown_type => {
                // Type variable - bind it
                // In full implementation, would add to substitution
                return;
            },
            .any_type => return, // any matches anything
            else => {},
        }

        switch (s2) {
            .unknown_type => return,
            .any_type => return,
            else => {},
        }

        // Types don't match
        return UnificationError.TypeMismatch;
    }

    fn partitionConstraints(self: *ParallelConstraintSolver, constraints: []const Constraint) ![][]const Constraint {
        // Simple partitioning: split into chunks
        const chunk_size = @max(1, constraints.len / self.thread_count);
        var partitions = std.ArrayList([]const Constraint).init(self.allocator);

        var i: usize = 0;
        while (i < constraints.len) {
            const end = @min(i + chunk_size, constraints.len);
            try partitions.append(constraints[i..end]);
            i = end;
        }

        return partitions.toOwnedSlice();
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "type equality" {
    const t1 = Type{ .int_type = .{ .bits = 32, .signed = true } };
    const t2 = Type{ .int_type = .{ .bits = 32, .signed = true } };
    const t3 = Type{ .int_type = .{ .bits = 64, .signed = true } };

    try std.testing.expect(t1.eql(t2));
    try std.testing.expect(!t1.eql(t3));
}

test "dependency graph" {
    const allocator = std.testing.allocator;
    var graph = DependencyGraph.init(allocator);
    defer graph.deinit();

    try graph.addDependency("A", "B");
    try graph.addDependency("A", "C");
    try graph.addDependency("B", "D");

    const deps = graph.getDependencies("A");
    try std.testing.expect(deps.len == 2);

    const dependents = graph.getDependents("B");
    try std.testing.expect(dependents.len == 1);
    try std.testing.expectEqualStrings("A", dependents[0]);
}

test "transitive dependents" {
    const allocator = std.testing.allocator;
    var graph = DependencyGraph.init(allocator);
    defer graph.deinit();

    // A -> B -> C
    try graph.addDependency("A", "B");
    try graph.addDependency("B", "C");

    const affected = try graph.getTransitiveDependents(&[_][]const u8{"C"});
    defer allocator.free(affected);

    // Should include C, B, A
    try std.testing.expect(affected.len == 3);
}

test "incremental type checker init" {
    const allocator = std.testing.allocator;
    var checker = IncrementalTypeChecker.init(allocator);
    defer checker.deinit();

    const stats = checker.getStats();
    try std.testing.expect(stats.cache_hits == 0);
    try std.testing.expect(stats.cache_misses == 0);
}

test "substitution" {
    const allocator = std.testing.allocator;
    var subst = Substitution.init(allocator);
    defer subst.deinit();

    const t = Type{ .int_type = .{ .bits = 32, .signed = true } };
    const applied = subst.apply(t);

    try std.testing.expect(applied.eql(t));
}

test "parallel constraint solver" {
    const allocator = std.testing.allocator;
    var solver = ParallelConstraintSolver.init(allocator);

    const constraints = [_]Constraint{
        .{
            .lhs = .{ .int_type = .{ .bits = 32, .signed = true } },
            .rhs = .{ .int_type = .{ .bits = 32, .signed = true } },
            .location = .{ .file = "", .line = 0, .column = 0 },
        },
    };

    var subst = try solver.solve(&constraints);
    defer subst.deinit();

    // Should succeed without errors
    try std.testing.expect(subst.mappings.count() == 0);
}

test "resolve type name" {
    const allocator = std.testing.allocator;
    var checker = IncrementalTypeChecker.init(allocator);
    defer checker.deinit();

    const void_type = try checker.resolveTypeName("void");
    try std.testing.expect(void_type == .void_type);

    const i32_type = try checker.resolveTypeName("i32");
    try std.testing.expect(i32_type == .int_type);
    try std.testing.expect(i32_type.int_type.bits == 32);
    try std.testing.expect(i32_type.int_type.signed == true);

    const f64_type = try checker.resolveTypeName("f64");
    try std.testing.expect(f64_type == .float_type);
    try std.testing.expect(f64_type.float_type.bits == 64);
}
