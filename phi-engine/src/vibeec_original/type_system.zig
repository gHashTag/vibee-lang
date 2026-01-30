//! VIBEE Type System with Inference - PAS DAEMON V39
//! Паттерны: HSH (O(1) type lookup), PRE (cached unification), D&C (constraint solving)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE KINDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeKind = enum(u8) {
    // Primitives
    void_type,
    bool_type,
    i8_type,
    i16_type,
    i32_type,
    i64_type,
    u8_type,
    u16_type,
    u32_type,
    u64_type,
    f32_type,
    f64_type,
    
    // Sacred types
    phi_type,      // Golden ratio type
    sacred_type,   // Sacred number type
    
    // Compound types
    string_type,
    array_type,
    slice_type,
    pointer_type,
    optional_type,
    error_union_type,
    
    // User-defined
    struct_type,
    enum_type,
    union_type,
    function_type,
    
    // Type inference
    type_var,      // Unbound type variable
    any_type,      // Any type (for generics)
    never_type,    // Bottom type (never returns)
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Type = struct {
    kind: TypeKind,
    id: u32,
    
    // For compound types
    inner: ?*Type = null,
    params: ?[]const *Type = null,
    
    // For named types
    name: ?[]const u8 = null,
    
    // For type variables (inference)
    bound_to: ?*Type = null,
    
    // Metadata
    size: u32 = 0,
    alignment: u32 = 0,
    
    pub fn isPrimitive(self: *const Type) bool {
        return @intFromEnum(self.kind) <= @intFromEnum(TypeKind.f64_type);
    }
    
    pub fn isNumeric(self: *const Type) bool {
        return @intFromEnum(self.kind) >= @intFromEnum(TypeKind.i8_type) and
               @intFromEnum(self.kind) <= @intFromEnum(TypeKind.f64_type);
    }
    
    pub fn isInteger(self: *const Type) bool {
        return @intFromEnum(self.kind) >= @intFromEnum(TypeKind.i8_type) and
               @intFromEnum(self.kind) <= @intFromEnum(TypeKind.u64_type);
    }
    
    pub fn isFloat(self: *const Type) bool {
        return self.kind == .f32_type or self.kind == .f64_type;
    }
    
    pub fn isSacred(self: *const Type) bool {
        return self.kind == .phi_type or self.kind == .sacred_type;
    }
    
    pub fn isTypeVar(self: *const Type) bool {
        return self.kind == .type_var;
    }
    
    /// Follow type variable chain to find actual type
    pub fn resolve(self: *Type) *Type {
        if (self.kind == .type_var and self.bound_to != null) {
            return self.bound_to.?.resolve();
        }
        return self;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE CONSTRAINT - For inference
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConstraintKind = enum {
    equal,        // T1 = T2
    subtype,      // T1 <: T2
    supertype,    // T1 :> T2
    numeric,      // T must be numeric
    callable,     // T must be callable
    indexable,    // T must be indexable
};

pub const TypeConstraint = struct {
    kind: ConstraintKind,
    left: *Type,
    right: ?*Type,
    location: u32, // Source location for error reporting
    
    pub fn equal(left: *Type, right: *Type, loc: u32) TypeConstraint {
        return .{ .kind = .equal, .left = left, .right = right, .location = loc };
    }
    
    pub fn numeric(t: *Type, loc: u32) TypeConstraint {
        return .{ .kind = .numeric, .left = t, .right = null, .location = loc };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE ENVIRONMENT - HSH pattern for O(1) lookup
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeEnv = struct {
    allocator: Allocator,
    
    // HSH: name -> type mapping
    bindings: std.StringHashMap(*Type),
    
    // Parent scope for lexical scoping
    parent: ?*TypeEnv,
    
    // Type variable counter
    next_type_var: u32 = 0,
    
    // Track allocated type vars for cleanup
    type_vars: std.ArrayList(*Type),
    
    pub fn init(allocator: Allocator, parent: ?*TypeEnv) TypeEnv {
        return .{
            .allocator = allocator,
            .bindings = std.StringHashMap(*Type).init(allocator),
            .parent = parent,
            .type_vars = std.ArrayList(*Type).init(allocator),
        };
    }
    
    pub fn deinit(self: *TypeEnv) void {
        for (self.type_vars.items) |tv| {
            self.allocator.destroy(tv);
        }
        self.type_vars.deinit();
        self.bindings.deinit();
    }
    
    /// Bind name to type - O(1)
    pub fn bind(self: *TypeEnv, name: []const u8, t: *Type) !void {
        try self.bindings.put(name, t);
    }
    
    /// Lookup type by name - O(1) per scope level
    pub fn lookup(self: *const TypeEnv, name: []const u8) ?*Type {
        if (self.bindings.get(name)) |t| return t;
        if (self.parent) |p| return p.lookup(name);
        return null;
    }
    
    /// Create fresh type variable
    pub fn freshTypeVar(self: *TypeEnv) !*Type {
        const t = try self.allocator.create(Type);
        t.* = .{
            .kind = .type_var,
            .id = self.next_type_var,
        };
        self.next_type_var += 1;
        try self.type_vars.append(t);
        return t;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE INFERENCE ENGINE - D&C pattern for constraint solving
// ═══════════════════════════════════════════════════════════════════════════════

pub const InferenceError = error{
    TypeMismatch,
    OccursCheck,
    UnboundVariable,
    NotCallable,
    NotIndexable,
    OutOfMemory,
};

pub const TypeInference = struct {
    allocator: Allocator,
    constraints: std.ArrayList(TypeConstraint),
    
    // PRE: Cached unification results
    unification_cache: std.AutoHashMap(u64, *Type),
    
    // Statistics
    unifications: u64 = 0,
    cache_hits: u64 = 0,
    
    pub fn init(allocator: Allocator) TypeInference {
        return .{
            .allocator = allocator,
            .constraints = std.ArrayList(TypeConstraint).init(allocator),
            .unification_cache = std.AutoHashMap(u64, *Type).init(allocator),
        };
    }
    
    pub fn deinit(self: *TypeInference) void {
        self.constraints.deinit();
        self.unification_cache.deinit();
    }
    
    /// Add constraint
    pub fn addConstraint(self: *TypeInference, constraint: TypeConstraint) !void {
        try self.constraints.append(constraint);
    }
    
    /// Solve all constraints - D&C pattern
    pub fn solve(self: *TypeInference) InferenceError!void {
        for (self.constraints.items) |constraint| {
            try self.solveConstraint(constraint);
        }
    }
    
    fn solveConstraint(self: *TypeInference, constraint: TypeConstraint) InferenceError!void {
        switch (constraint.kind) {
            .equal => {
                if (constraint.right) |right| {
                    try self.unify(constraint.left, right);
                }
            },
            .numeric => {
                const resolved = constraint.left.resolve();
                if (!resolved.isNumeric() and resolved.kind != .type_var) {
                    return InferenceError.TypeMismatch;
                }
            },
            .subtype, .supertype => {
                // Simplified: treat as equality for now
                if (constraint.right) |right| {
                    try self.unify(constraint.left, right);
                }
            },
            .callable => {
                const resolved = constraint.left.resolve();
                if (resolved.kind != .function_type and resolved.kind != .type_var) {
                    return InferenceError.NotCallable;
                }
            },
            .indexable => {
                const resolved = constraint.left.resolve();
                if (resolved.kind != .array_type and 
                    resolved.kind != .slice_type and 
                    resolved.kind != .type_var) {
                    return InferenceError.NotIndexable;
                }
            },
        }
    }
    
    /// Unify two types - core of Hindley-Milner
    pub fn unify(self: *TypeInference, t1: *Type, t2: *Type) InferenceError!void {
        self.unifications += 1;
        
        // Check cache (PRE pattern)
        const cache_key = @as(u64, t1.id) << 32 | @as(u64, t2.id);
        if (self.unification_cache.contains(cache_key)) {
            self.cache_hits += 1;
            return;
        }
        
        const r1 = t1.resolve();
        const r2 = t2.resolve();
        
        // Same type
        if (r1 == r2) return;
        
        // Type variable binding
        if (r1.kind == .type_var) {
            try self.occursCheck(r1, r2);
            r1.bound_to = r2;
            self.unification_cache.put(cache_key, r2) catch {};
            return;
        }
        
        if (r2.kind == .type_var) {
            try self.occursCheck(r2, r1);
            r2.bound_to = r1;
            self.unification_cache.put(cache_key, r1) catch {};
            return;
        }
        
        // Same kind
        if (r1.kind != r2.kind) {
            return InferenceError.TypeMismatch;
        }
        
        // Unify inner types for compound types
        if (r1.inner != null and r2.inner != null) {
            try self.unify(r1.inner.?, r2.inner.?);
        }
        
        // Unify parameters
        if (r1.params != null and r2.params != null) {
            if (r1.params.?.len != r2.params.?.len) {
                return InferenceError.TypeMismatch;
            }
            for (r1.params.?, r2.params.?) |p1, p2| {
                try self.unify(p1, p2);
            }
        }
        
        self.unification_cache.put(cache_key, r1) catch {};
    }
    
    /// Occurs check - prevent infinite types
    fn occursCheck(self: *TypeInference, tv: *Type, t: *Type) InferenceError!void {
        _ = self;
        const resolved = t.resolve();
        if (resolved == tv) {
            return InferenceError.OccursCheck;
        }
        
        if (resolved.inner) |inner| {
            if (inner == tv) return InferenceError.OccursCheck;
        }
        
        if (resolved.params) |params| {
            for (params) |p| {
                if (p == tv) return InferenceError.OccursCheck;
            }
        }
    }
    
    /// Get inference statistics
    pub fn getStats(self: *const TypeInference) InferenceStats {
        return .{
            .constraint_count = self.constraints.items.len,
            .unifications = self.unifications,
            .cache_hits = self.cache_hits,
            .cache_hit_ratio = if (self.unifications > 0)
                @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(self.unifications))
            else 0.0,
        };
    }
};

pub const InferenceStats = struct {
    constraint_count: usize,
    unifications: u64,
    cache_hits: u64,
    cache_hit_ratio: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE REGISTRY - Global type storage with HSH
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeRegistry = struct {
    allocator: Allocator,
    
    // Primitive types (singleton)
    void_type: *Type,
    bool_type: *Type,
    i32_type: *Type,
    i64_type: *Type,
    f32_type: *Type,
    f64_type: *Type,
    string_type: *Type,
    phi_type: *Type,
    sacred_type: *Type,
    
    // HSH: Named types
    named_types: std.StringHashMap(*Type),
    
    // All allocated types
    all_types: std.ArrayList(*Type),
    
    next_id: u32 = 0,
    
    pub fn init(allocator: Allocator) !TypeRegistry {
        var reg = TypeRegistry{
            .allocator = allocator,
            .void_type = undefined,
            .bool_type = undefined,
            .i32_type = undefined,
            .i64_type = undefined,
            .f32_type = undefined,
            .f64_type = undefined,
            .string_type = undefined,
            .phi_type = undefined,
            .sacred_type = undefined,
            .named_types = std.StringHashMap(*Type).init(allocator),
            .all_types = std.ArrayList(*Type).init(allocator),
        };
        
        // Initialize primitive types
        reg.void_type = try reg.createPrimitive(.void_type, 0, 1);
        reg.bool_type = try reg.createPrimitive(.bool_type, 1, 1);
        reg.i32_type = try reg.createPrimitive(.i32_type, 4, 4);
        reg.i64_type = try reg.createPrimitive(.i64_type, 8, 8);
        reg.f32_type = try reg.createPrimitive(.f32_type, 4, 4);
        reg.f64_type = try reg.createPrimitive(.f64_type, 8, 8);
        reg.string_type = try reg.createPrimitive(.string_type, 16, 8);
        reg.phi_type = try reg.createPrimitive(.phi_type, 8, 8);
        reg.sacred_type = try reg.createPrimitive(.sacred_type, 8, 8);
        
        return reg;
    }
    
    pub fn deinit(self: *TypeRegistry) void {
        for (self.all_types.items) |t| {
            self.allocator.destroy(t);
        }
        self.all_types.deinit();
        self.named_types.deinit();
    }
    
    fn createPrimitive(self: *TypeRegistry, kind: TypeKind, size: u32, alignment: u32) !*Type {
        const t = try self.allocator.create(Type);
        t.* = .{
            .kind = kind,
            .id = self.next_id,
            .size = size,
            .alignment = alignment,
        };
        self.next_id += 1;
        try self.all_types.append(t);
        return t;
    }
    
    /// Create array type
    pub fn arrayType(self: *TypeRegistry, elem: *Type) !*Type {
        const t = try self.allocator.create(Type);
        t.* = .{
            .kind = .array_type,
            .id = self.next_id,
            .inner = elem,
            .size = 0, // Dynamic
            .alignment = elem.alignment,
        };
        self.next_id += 1;
        try self.all_types.append(t);
        return t;
    }
    
    /// Create function type
    pub fn functionType(self: *TypeRegistry, params: []const *Type, ret: *Type) !*Type {
        const t = try self.allocator.create(Type);
        t.* = .{
            .kind = .function_type,
            .id = self.next_id,
            .inner = ret,
            .params = params,
            .size = 8,
            .alignment = 8,
        };
        self.next_id += 1;
        try self.all_types.append(t);
        return t;
    }
    
    /// Create optional type
    pub fn optionalType(self: *TypeRegistry, inner: *Type) !*Type {
        const t = try self.allocator.create(Type);
        t.* = .{
            .kind = .optional_type,
            .id = self.next_id,
            .inner = inner,
            .size = inner.size + 1,
            .alignment = inner.alignment,
        };
        self.next_id += 1;
        try self.all_types.append(t);
        return t;
    }
    
    /// Register named type - O(1)
    pub fn registerNamed(self: *TypeRegistry, name: []const u8, t: *Type) !void {
        t.name = name;
        try self.named_types.put(name, t);
    }
    
    /// Lookup named type - O(1)
    pub fn lookupNamed(self: *const TypeRegistry, name: []const u8) ?*Type {
        return self.named_types.get(name);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TypeRegistry primitives" {
    const allocator = std.testing.allocator;
    var reg = try TypeRegistry.init(allocator);
    defer reg.deinit();
    
    try std.testing.expectEqual(TypeKind.i32_type, reg.i32_type.kind);
    try std.testing.expectEqual(@as(u32, 4), reg.i32_type.size);
    try std.testing.expect(reg.i32_type.isInteger());
    try std.testing.expect(reg.f64_type.isFloat());
    try std.testing.expect(reg.phi_type.isSacred());
}

test "TypeEnv binding and lookup" {
    const allocator = std.testing.allocator;
    var reg = try TypeRegistry.init(allocator);
    defer reg.deinit();
    
    var env = TypeEnv.init(allocator, null);
    defer env.deinit();
    
    try env.bind("x", reg.i32_type);
    try env.bind("y", reg.f64_type);
    
    try std.testing.expectEqual(reg.i32_type, env.lookup("x").?);
    try std.testing.expectEqual(reg.f64_type, env.lookup("y").?);
    try std.testing.expect(env.lookup("z") == null);
}

test "TypeEnv scoping" {
    const allocator = std.testing.allocator;
    var reg = try TypeRegistry.init(allocator);
    defer reg.deinit();
    
    var parent = TypeEnv.init(allocator, null);
    defer parent.deinit();
    try parent.bind("x", reg.i32_type);
    
    var child = TypeEnv.init(allocator, &parent);
    defer child.deinit();
    try child.bind("y", reg.f64_type);
    
    // Child can see parent's bindings
    try std.testing.expectEqual(reg.i32_type, child.lookup("x").?);
    try std.testing.expectEqual(reg.f64_type, child.lookup("y").?);
    
    // Parent cannot see child's bindings
    try std.testing.expect(parent.lookup("y") == null);
}

test "TypeInference unification" {
    const allocator = std.testing.allocator;
    var reg = try TypeRegistry.init(allocator);
    defer reg.deinit();
    
    var env = TypeEnv.init(allocator, null);
    defer env.deinit();
    
    var inference = TypeInference.init(allocator);
    defer inference.deinit();
    
    // Create type variable
    const tv = try env.freshTypeVar();
    
    // Unify with concrete type
    try inference.unify(tv, reg.i32_type);
    
    // Type variable should now be bound
    try std.testing.expectEqual(reg.i32_type, tv.resolve());
}

test "TypeInference constraint solving" {
    const allocator = std.testing.allocator;
    var reg = try TypeRegistry.init(allocator);
    defer reg.deinit();
    
    var env = TypeEnv.init(allocator, null);
    defer env.deinit();
    
    var inference = TypeInference.init(allocator);
    defer inference.deinit();
    
    const tv1 = try env.freshTypeVar();
    const tv2 = try env.freshTypeVar();
    
    // Add constraints: tv1 = i32, tv2 = tv1
    try inference.addConstraint(TypeConstraint.equal(tv1, reg.i32_type, 0));
    try inference.addConstraint(TypeConstraint.equal(tv2, tv1, 0));
    
    // Solve
    try inference.solve();
    
    // Both should resolve to i32
    try std.testing.expectEqual(reg.i32_type, tv1.resolve());
    try std.testing.expectEqual(reg.i32_type, tv2.resolve());
}

test "TypeInference occurs check" {
    const allocator = std.testing.allocator;
    var reg = try TypeRegistry.init(allocator);
    defer reg.deinit();
    
    var env = TypeEnv.init(allocator, null);
    defer env.deinit();
    
    var inference = TypeInference.init(allocator);
    defer inference.deinit();
    
    const tv = try env.freshTypeVar();
    
    // Create array of tv
    const arr = try reg.arrayType(tv);
    
    // Unifying tv with array(tv) should fail (infinite type)
    const result = inference.unify(tv, arr);
    try std.testing.expectError(InferenceError.OccursCheck, result);
}

test "compound types" {
    const allocator = std.testing.allocator;
    var reg = try TypeRegistry.init(allocator);
    defer reg.deinit();
    
    const arr = try reg.arrayType(reg.i32_type);
    try std.testing.expectEqual(TypeKind.array_type, arr.kind);
    try std.testing.expectEqual(reg.i32_type, arr.inner.?);
    
    const opt = try reg.optionalType(reg.string_type);
    try std.testing.expectEqual(TypeKind.optional_type, opt.kind);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
