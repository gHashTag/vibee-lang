// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC TYPE CHECKER - INCREMENTAL TYPE SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V35 - Type Checker with Caching and Incremental Validation
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: INC (Incremental), PRE (Precomputation), HSH (Hashing)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const parser = @import("parser_v3.zig");
const Specification = parser.Specification;
const TypeDef = parser.TypeDef;
const TypeKind = parser.TypeKind;
const error_reporter = @import("error_reporter.zig");
const ErrorReporter = error_reporter.ErrorReporter;
const DiagnosticCode = error_reporter.DiagnosticCode;
const SourceSpan = error_reporter.SourceSpan;
const SourceLocation = error_reporter.SourceLocation;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE REPRESENTATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Type = union(enum) {
    // Primitives
    void_type,
    bool_type,
    int_type: IntType,
    float_type: FloatType,
    string_type,
    any_type,
    unknown_type,
    error_type,

    // Compound types
    array_type: ArrayType,
    slice_type: SliceType,
    optional_type: OptionalType,
    error_union: ErrorUnion,

    // User-defined types
    struct_type: StructType,
    enum_type: EnumType,
    union_type: UnionType,
    function_type: FunctionType,

    // Sacred types
    sacred_computation,
    evolution_state,
    quantum_neuro_state,

    pub fn toString(self: Type, allocator: Allocator) ![]const u8 {
        return switch (self) {
            .void_type => try allocator.dupe(u8, "void"),
            .bool_type => try allocator.dupe(u8, "bool"),
            .int_type => |i| try std.fmt.allocPrint(allocator, "{s}{d}", .{ if (i.signed) "i" else "u", i.bits }),
            .float_type => |f| try std.fmt.allocPrint(allocator, "f{d}", .{f.bits}),
            .string_type => try allocator.dupe(u8, "[]const u8"),
            .any_type => try allocator.dupe(u8, "anytype"),
            .unknown_type => try allocator.dupe(u8, "unknown"),
            .error_type => try allocator.dupe(u8, "error"),
            .array_type => |a| try std.fmt.allocPrint(allocator, "[{d}]{s}", .{ a.len, "T" }),
            .slice_type => try allocator.dupe(u8, "[]T"),
            .optional_type => try allocator.dupe(u8, "?T"),
            .error_union => try allocator.dupe(u8, "!T"),
            .struct_type => |s| try allocator.dupe(u8, s.name),
            .enum_type => |e| try allocator.dupe(u8, e.name),
            .union_type => |u| try allocator.dupe(u8, u.name),
            .function_type => try allocator.dupe(u8, "fn"),
            .sacred_computation => try allocator.dupe(u8, "SacredComputation"),
            .evolution_state => try allocator.dupe(u8, "EvolutionState"),
            .quantum_neuro_state => try allocator.dupe(u8, "QuantumNeuroState"),
        };
    }

    pub fn isNumeric(self: Type) bool {
        return switch (self) {
            .int_type, .float_type => true,
            else => false,
        };
    }

    pub fn isSacred(self: Type) bool {
        return switch (self) {
            .sacred_computation, .evolution_state, .quantum_neuro_state => true,
            else => false,
        };
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
    element_type: *const Type,
    len: usize,
};

pub const SliceType = struct {
    element_type: *const Type,
};

pub const OptionalType = struct {
    child_type: *const Type,
};

pub const ErrorUnion = struct {
    error_set: ?*const Type,
    payload: *const Type,
};

pub const StructType = struct {
    name: []const u8,
    fields: []const FieldInfo,
};

pub const EnumType = struct {
    name: []const u8,
    values: []const []const u8,
};

pub const UnionType = struct {
    name: []const u8,
    variants: []const FieldInfo,
};

pub const FunctionType = struct {
    params: []const Type,
    return_type: *const Type,
};

pub const FieldInfo = struct {
    name: []const u8,
    field_type: Type,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE REGISTRY - HSH PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeRegistry = struct {
    types: StringHashMap(Type),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        var self = Self{
            .types = StringHashMap(Type).init(allocator),
            .allocator = allocator,
        };

        // Register built-in types
        self.registerBuiltins() catch {};

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.types.deinit();
    }

    fn registerBuiltins(self: *Self) !void {
        // Primitives
        try self.types.put("void", .void_type);
        try self.types.put("bool", .bool_type);
        try self.types.put("string", .string_type);
        try self.types.put("[]const u8", .string_type);
        try self.types.put("anytype", .any_type);

        // Integers
        try self.types.put("i8", .{ .int_type = .{ .bits = 8, .signed = true } });
        try self.types.put("i16", .{ .int_type = .{ .bits = 16, .signed = true } });
        try self.types.put("i32", .{ .int_type = .{ .bits = 32, .signed = true } });
        try self.types.put("i64", .{ .int_type = .{ .bits = 64, .signed = true } });
        try self.types.put("u8", .{ .int_type = .{ .bits = 8, .signed = false } });
        try self.types.put("u16", .{ .int_type = .{ .bits = 16, .signed = false } });
        try self.types.put("u32", .{ .int_type = .{ .bits = 32, .signed = false } });
        try self.types.put("u64", .{ .int_type = .{ .bits = 64, .signed = false } });
        try self.types.put("usize", .{ .int_type = .{ .bits = 64, .signed = false } });

        // Floats
        try self.types.put("f16", .{ .float_type = .{ .bits = 16 } });
        try self.types.put("f32", .{ .float_type = .{ .bits = 32 } });
        try self.types.put("f64", .{ .float_type = .{ .bits = 64 } });

        // Sacred types
        try self.types.put("SacredComputation", .sacred_computation);
        try self.types.put("EvolutionState", .evolution_state);
        try self.types.put("QuantumNeuroState", .quantum_neuro_state);
    }

    pub fn lookup(self: *Self, name: []const u8) ?Type {
        return self.types.get(name);
    }

    pub fn register(self: *Self, name: []const u8, t: Type) !void {
        try self.types.put(name, t);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE CHECK RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeCheckResult = struct {
    success: bool,
    resolved_type: ?Type,
    errors: ArrayList(TypeError),

    pub fn init(allocator: Allocator) TypeCheckResult {
        return .{
            .success = true,
            .resolved_type = null,
            .errors = ArrayList(TypeError).init(allocator),
        };
    }

    pub fn deinit(self: *TypeCheckResult) void {
        self.errors.deinit();
    }

    pub fn addError(self: *TypeCheckResult, err: TypeError) !void {
        self.success = false;
        try self.errors.append(err);
    }
};

pub const TypeError = struct {
    code: TypeErrorCode,
    message: []const u8,
    location: ?SourceLocation,
};

pub const TypeErrorCode = enum {
    undefined_type,
    type_mismatch,
    duplicate_definition,
    missing_field,
    invalid_field_type,
    circular_reference,
    sacred_type_violation,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE CHECKER - INC PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeChecker = struct {
    allocator: Allocator,
    registry: TypeRegistry,
    cache: StringHashMap(CacheEntry),
    current_version: u64,

    // Metrics
    cache_hits: u64,
    cache_misses: u64,
    types_checked: u64,

    const Self = @This();

    const CacheEntry = struct {
        result: TypeCheckResult,
        version: u64,
        is_dirty: bool,
    };

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .registry = TypeRegistry.init(allocator),
            .cache = StringHashMap(CacheEntry).init(allocator),
            .current_version = 0,
            .cache_hits = 0,
            .cache_misses = 0,
            .types_checked = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.result.deinit();
        }
        self.cache.deinit();
        self.registry.deinit();
    }

    pub fn check(self: *Self, spec: *const Specification) !TypeCheckResult {
        var result = TypeCheckResult.init(self.allocator);

        // Register all types first (forward declarations)
        for (spec.types.items) |type_def| {
            const t = self.convertTypeDef(&type_def);
            try self.registry.register(type_def.name, t);
        }

        // Check each type definition
        for (spec.types.items) |type_def| {
            try self.checkTypeDef(&type_def, &result);
            self.types_checked += 1;
        }

        // Check behaviors
        for (spec.behaviors.items) |behavior| {
            try self.checkBehavior(&behavior, &result);
        }

        // Check creation pattern
        if (spec.creation_pattern) |cp| {
            try self.checkCreationPattern(&cp, &result);
        }

        return result;
    }

    fn convertTypeDef(self: *Self, type_def: *const TypeDef) Type {
        _ = self;
        return switch (type_def.kind) {
            .struct_type => .{ .struct_type = .{ .name = type_def.name, .fields = &.{} } },
            .enum_type => .{ .enum_type = .{ .name = type_def.name, .values = &.{} } },
            .union_type => .{ .union_type = .{ .name = type_def.name, .variants = &.{} } },
        };
    }

    fn checkTypeDef(self: *Self, type_def: *const TypeDef, result: *TypeCheckResult) !void {
        // Check for duplicate definition
        if (self.cache.get(type_def.name)) |entry| {
            if (!entry.is_dirty) {
                self.cache_hits += 1;
                return;
            }
        }
        self.cache_misses += 1;

        // Check fields
        for (type_def.fields.items) |field| {
            if (field.type_name.len > 0) {
                // Resolve type
                const resolved = self.resolveTypeName(field.type_name);
                if (resolved == null) {
                    try result.addError(.{
                        .code = .undefined_type,
                        .message = field.type_name,
                        .location = null,
                    });
                }
            }
        }
    }

    fn checkBehavior(self: *Self, behavior: *const parser.Behavior, result: *TypeCheckResult) !void {
        _ = self;
        // Behaviors should have given/when/then
        if (behavior.given.len == 0) {
            try result.addError(.{
                .code = .missing_field,
                .message = "behavior missing 'given' clause",
                .location = null,
            });
        }
        if (behavior.when.len == 0) {
            try result.addError(.{
                .code = .missing_field,
                .message = "behavior missing 'when' clause",
                .location = null,
            });
        }
        if (behavior.then.len == 0) {
            try result.addError(.{
                .code = .missing_field,
                .message = "behavior missing 'then' clause",
                .location = null,
            });
        }
    }

    fn checkCreationPattern(self: *Self, cp: *const parser.CreationPattern, result: *TypeCheckResult) !void {
        _ = self;
        // Creation pattern should have source/transformer/result
        if (cp.source.len == 0) {
            try result.addError(.{
                .code = .missing_field,
                .message = "creation pattern missing 'source'",
                .location = null,
            });
        }
        if (cp.transformer.len == 0) {
            try result.addError(.{
                .code = .missing_field,
                .message = "creation pattern missing 'transformer'",
                .location = null,
            });
        }
        if (cp.result.len == 0) {
            try result.addError(.{
                .code = .missing_field,
                .message = "creation pattern missing 'result'",
                .location = null,
            });
        }
    }

    pub fn resolveTypeName(self: *Self, name: []const u8) ?Type {
        // Handle optional types
        if (name.len > 0 and name[0] == '?') {
            if (self.resolveTypeName(name[1..])) |_| {
                return .{ .optional_type = .{ .child_type = undefined } };
            }
            return null;
        }

        // Handle error union types
        if (name.len > 0 and name[0] == '!') {
            if (self.resolveTypeName(name[1..])) |_| {
                return .{ .error_union = .{ .error_set = null, .payload = undefined } };
            }
            return null;
        }

        // Handle slice types
        if (std.mem.startsWith(u8, name, "[]")) {
            return .{ .slice_type = .{ .element_type = undefined } };
        }

        // Handle array types [N]T
        if (name.len > 0 and name[0] == '[') {
            if (std.mem.indexOf(u8, name, "]")) |_| {
                return .{ .array_type = .{ .element_type = undefined, .len = 0 } };
            }
        }

        // Lookup in registry
        return self.registry.lookup(name);
    }

    pub fn invalidate(self: *Self, name: []const u8) void {
        if (self.cache.getPtr(name)) |entry| {
            entry.is_dirty = true;
        }
        self.current_version += 1;
    }

    pub fn getMetrics(self: Self) TypeCheckMetrics {
        return .{
            .cache_hits = self.cache_hits,
            .cache_misses = self.cache_misses,
            .types_checked = self.types_checked,
            .registered_types = self.registry.types.count(),
        };
    }
};

pub const TypeCheckMetrics = struct {
    cache_hits: u64,
    cache_misses: u64,
    types_checked: u64,
    registered_types: usize,

    pub fn hitRatio(self: TypeCheckMetrics) f64 {
        const total = self.cache_hits + self.cache_misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TypeRegistry builtins" {
    const allocator = std.testing.allocator;
    var registry = TypeRegistry.init(allocator);
    defer registry.deinit();

    try std.testing.expect(registry.lookup("i32") != null);
    try std.testing.expect(registry.lookup("f64") != null);
    try std.testing.expect(registry.lookup("bool") != null);
    try std.testing.expect(registry.lookup("void") != null);
    try std.testing.expect(registry.lookup("SacredComputation") != null);
}

test "TypeRegistry sacred types" {
    const allocator = std.testing.allocator;
    var registry = TypeRegistry.init(allocator);
    defer registry.deinit();

    const sacred = registry.lookup("SacredComputation");
    try std.testing.expect(sacred != null);
    try std.testing.expect(sacred.?.isSacred());
}

test "TypeChecker basic" {
    const allocator = std.testing.allocator;

    var p = parser.ParserV3.init(allocator);
    defer p.deinit();

    const source =
        \\name: test
        \\version: "1.0.0"
        \\
        \\creation_pattern:
        \\  source: Input
        \\  transformer: Process
        \\  result: Output
        \\
        \\behaviors:
        \\  - name: test_behavior
        \\    given: precondition
        \\    when: action
        \\    then: result
    ;

    var spec = try p.parse(source);
    defer spec.deinit();

    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    var result = try checker.check(&spec);
    defer result.deinit();

    try std.testing.expect(result.success);
}

test "TypeChecker resolves types" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    try std.testing.expect(checker.resolveTypeName("i32") != null);
    try std.testing.expect(checker.resolveTypeName("f64") != null);
    try std.testing.expect(checker.resolveTypeName("?i32") != null);
    try std.testing.expect(checker.resolveTypeName("!i32") != null);
    try std.testing.expect(checker.resolveTypeName("[]u8") != null);
    try std.testing.expect(checker.resolveTypeName("nonexistent") == null);
}

test "Type isNumeric" {
    const int_type: Type = .{ .int_type = .{ .bits = 32, .signed = true } };
    const float_type: Type = .{ .float_type = .{ .bits = 64 } };
    const bool_type: Type = .bool_type;

    try std.testing.expect(int_type.isNumeric());
    try std.testing.expect(float_type.isNumeric());
    try std.testing.expect(!bool_type.isNumeric());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
