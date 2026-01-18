//! VIBEE Partial Escape Analysis (PEA) - PAS DAEMON V42
//! Based on CGO 2014 "Partial Escape Analysis and Scalar Replacement for Java"
//! Паттерны: D&C (path-sensitive analysis), PRE (materialization points), HSH (state caching)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3
//! Target: Additional 10-15% allocation reduction beyond basic escape analysis

const std = @import("std");
const Allocator = std.mem.Allocator;
const escape = @import("escape_analysis.zig");

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// VIRTUAL OBJECT STATE - Path-sensitive object representation
// ═══════════════════════════════════════════════════════════════════════════════

pub const VirtualState = enum(u8) {
    /// Object is virtual (not yet materialized)
    virtual = 0,
    /// Object is materialized (allocated on heap)
    materialized = 1,
    /// Object is dead (no longer needed)
    dead = 2,
};

pub const VirtualObject = struct {
    id: u32,
    type_id: u32,
    state: VirtualState = .virtual,
    field_count: u8,
    
    // Virtual field values (for scalar replacement)
    field_values: std.ArrayList(FieldValue),
    
    // Materialization point (if materialized)
    materialization_point: ?u32 = null,
    
    // Lock state for synchronization analysis
    is_locked: bool = false,
    
    pub fn init(allocator: Allocator, id: u32, type_id: u32, fields: u8) VirtualObject {
        return .{
            .id = id,
            .type_id = type_id,
            .field_count = fields,
            .field_values = std.ArrayList(FieldValue).init(allocator),
        };
    }
    
    pub fn deinit(self: *VirtualObject) void {
        self.field_values.deinit();
    }
    
    pub fn setField(self: *VirtualObject, index: u8, value: FieldValue) !void {
        while (self.field_values.items.len <= index) {
            try self.field_values.append(.{ .kind = .undefined });
        }
        self.field_values.items[index] = value;
    }
    
    pub fn getField(self: *const VirtualObject, index: u8) ?FieldValue {
        if (index < self.field_values.items.len) {
            return self.field_values.items[index];
        }
        return null;
    }
    
    pub fn isVirtual(self: *const VirtualObject) bool {
        return self.state == .virtual;
    }
    
    pub fn materialize(self: *VirtualObject, point: u32) void {
        self.state = .materialized;
        self.materialization_point = point;
    }
};

pub const FieldValueKind = enum(u8) {
    undefined,
    constant_int,
    constant_float,
    virtual_ref,
    materialized_ref,
    phi_value,
};

pub const FieldValue = struct {
    kind: FieldValueKind,
    data: union {
        int: i64,
        float: f64,
        ref: u32,
        phi: PhiValue,
    } = .{ .int = 0 },
    
    pub fn constInt(v: i64) FieldValue {
        return .{ .kind = .constant_int, .data = .{ .int = v } };
    }
    
    pub fn constFloat(v: f64) FieldValue {
        return .{ .kind = .constant_float, .data = .{ .float = v } };
    }
    
    pub fn virtualRef(id: u32) FieldValue {
        return .{ .kind = .virtual_ref, .data = .{ .ref = id } };
    }
};

pub const PhiValue = struct {
    values: [4]?u32 = .{ null, null, null, null },
    count: u8 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ABSTRACT STATE - Per-program-point state
// ═══════════════════════════════════════════════════════════════════════════════

pub const AbstractState = struct {
    allocator: Allocator,
    
    // Virtual objects at this program point
    virtual_objects: std.AutoHashMap(u32, VirtualObject),
    
    // Value -> VirtualObject mapping
    value_to_object: std.AutoHashMap(u32, u32),
    
    // Materialization decisions
    materializations: std.ArrayList(Materialization),
    
    pub fn init(allocator: Allocator) AbstractState {
        return .{
            .allocator = allocator,
            .virtual_objects = std.AutoHashMap(u32, VirtualObject).init(allocator),
            .value_to_object = std.AutoHashMap(u32, u32).init(allocator),
            .materializations = std.ArrayList(Materialization).init(allocator),
        };
    }
    
    pub fn deinit(self: *AbstractState) void {
        var iter = self.virtual_objects.valueIterator();
        while (iter.next()) |obj| {
            obj.deinit();
        }
        self.virtual_objects.deinit();
        self.value_to_object.deinit();
        self.materializations.deinit();
    }
    
    pub fn clone(self: *const AbstractState, allocator: Allocator) !AbstractState {
        var new_state = AbstractState.init(allocator);
        
        var iter = self.virtual_objects.iterator();
        while (iter.next()) |entry| {
            var obj = VirtualObject.init(allocator, entry.value_ptr.id, 
                                         entry.value_ptr.type_id, 
                                         entry.value_ptr.field_count);
            obj.state = entry.value_ptr.state;
            obj.materialization_point = entry.value_ptr.materialization_point;
            
            for (entry.value_ptr.field_values.items) |fv| {
                try obj.field_values.append(fv);
            }
            
            try new_state.virtual_objects.put(entry.key_ptr.*, obj);
        }
        
        var val_iter = self.value_to_object.iterator();
        while (val_iter.next()) |entry| {
            try new_state.value_to_object.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        
        return new_state;
    }
    
    /// Merge two states at control flow join
    pub fn merge(self: *AbstractState, other: *const AbstractState) !void {
        // For each virtual object in other
        var iter = other.virtual_objects.iterator();
        while (iter.next()) |entry| {
            if (self.virtual_objects.getPtr(entry.key_ptr.*)) |self_obj| {
                // Both have the object - merge states
                if (self_obj.state != entry.value_ptr.state) {
                    // Different states - must materialize
                    self_obj.state = .materialized;
                }
            } else {
                // Only in other - must materialize in other path
                try self.materializations.append(.{
                    .object_id = entry.key_ptr.*,
                    .point = 0, // Will be set during transformation
                    .reason = .control_flow_merge,
                });
            }
        }
    }
    
    /// Add virtual object
    pub fn addVirtualObject(self: *AbstractState, obj: VirtualObject) !void {
        try self.virtual_objects.put(obj.id, obj);
    }
    
    /// Get virtual object
    pub fn getVirtualObject(self: *AbstractState, id: u32) ?*VirtualObject {
        return self.virtual_objects.getPtr(id);
    }
    
    /// Check if value refers to virtual object
    pub fn isVirtualRef(self: *const AbstractState, value_id: u32) bool {
        if (self.value_to_object.get(value_id)) |obj_id| {
            if (self.virtual_objects.get(obj_id)) |obj| {
                return obj.state == .virtual;
            }
        }
        return false;
    }
};

pub const Materialization = struct {
    object_id: u32,
    point: u32,
    reason: MaterializationReason,
};

pub const MaterializationReason = enum {
    escape_to_call,
    escape_to_return,
    escape_to_store,
    control_flow_merge,
    synchronization,
    unknown_use,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARTIAL ESCAPE ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const PartialEscapeAnalyzer = struct {
    allocator: Allocator,
    
    // State per basic block
    block_states: std.AutoHashMap(u32, AbstractState),
    
    // Global virtual object counter
    next_object_id: u32 = 0,
    
    // Statistics
    stats: PEAStats = .{},
    
    // Configuration
    config: PEAConfig,
    
    pub fn init(allocator: Allocator, config: PEAConfig) PartialEscapeAnalyzer {
        return .{
            .allocator = allocator,
            .block_states = std.AutoHashMap(u32, AbstractState).init(allocator),
            .config = config,
        };
    }
    
    pub fn deinit(self: *PartialEscapeAnalyzer) void {
        var iter = self.block_states.valueIterator();
        while (iter.next()) |state| {
            state.deinit();
        }
        self.block_states.deinit();
    }
    
    /// Process allocation instruction
    pub fn processAllocation(self: *PartialEscapeAnalyzer, block_id: u32, 
                             inst_id: u32, type_id: u32, fields: u8) !u32 {
        const obj_id = self.next_object_id;
        self.next_object_id += 1;
        
        // Get or create block state
        const result = try self.block_states.getOrPut(block_id);
        if (!result.found_existing) {
            result.value_ptr.* = AbstractState.init(self.allocator);
        }
        
        // Create virtual object
        const obj = VirtualObject.init(self.allocator, obj_id, type_id, fields);
        try result.value_ptr.addVirtualObject(obj);
        try result.value_ptr.value_to_object.put(inst_id, obj_id);
        
        self.stats.allocations_virtualized += 1;
        return obj_id;
    }
    
    /// Process field store
    pub fn processStore(self: *PartialEscapeAnalyzer, block_id: u32,
                        base_value: u32, field_idx: u8, stored_value: FieldValue) !void {
        if (self.block_states.getPtr(block_id)) |state| {
            if (state.value_to_object.get(base_value)) |obj_id| {
                if (state.getVirtualObject(obj_id)) |obj| {
                    if (obj.isVirtual()) {
                        try obj.setField(field_idx, stored_value);
                        self.stats.stores_virtualized += 1;
                        return;
                    }
                }
            }
        }
        // Not virtual - normal store
    }
    
    /// Process field load
    pub fn processLoad(self: *PartialEscapeAnalyzer, block_id: u32,
                       base_value: u32, field_idx: u8) ?FieldValue {
        if (self.block_states.getPtr(block_id)) |state| {
            if (state.value_to_object.get(base_value)) |obj_id| {
                if (state.getVirtualObject(obj_id)) |obj| {
                    if (obj.isVirtual()) {
                        self.stats.loads_virtualized += 1;
                        return obj.getField(field_idx);
                    }
                }
            }
        }
        return null;
    }
    
    /// Process call - may cause materialization
    pub fn processCall(self: *PartialEscapeAnalyzer, block_id: u32,
                       arg_values: []const u32) !void {
        if (self.block_states.getPtr(block_id)) |state| {
            for (arg_values) |arg| {
                if (state.value_to_object.get(arg)) |obj_id| {
                    if (state.getVirtualObject(obj_id)) |obj| {
                        if (obj.isVirtual()) {
                            // Must materialize before call
                            obj.materialize(0); // Point will be set later
                            try state.materializations.append(.{
                                .object_id = obj_id,
                                .point = 0,
                                .reason = .escape_to_call,
                            });
                            self.stats.materializations += 1;
                        }
                    }
                }
            }
        }
    }
    
    /// Process return - may cause materialization
    pub fn processReturn(self: *PartialEscapeAnalyzer, block_id: u32,
                         return_value: ?u32) !void {
        if (return_value) |ret| {
            if (self.block_states.getPtr(block_id)) |state| {
                if (state.value_to_object.get(ret)) |obj_id| {
                    if (state.getVirtualObject(obj_id)) |obj| {
                        if (obj.isVirtual()) {
                            obj.materialize(0);
                            try state.materializations.append(.{
                                .object_id = obj_id,
                                .point = 0,
                                .reason = .escape_to_return,
                            });
                            self.stats.materializations += 1;
                        }
                    }
                }
            }
        }
    }
    
    /// Merge states at control flow join
    pub fn mergeStates(self: *PartialEscapeAnalyzer, target_block: u32,
                       source_blocks: []const u32) !void {
        if (source_blocks.len == 0) return;
        
        // Start with clone of first source
        if (self.block_states.get(source_blocks[0])) |first| {
            var merged = try first.clone(self.allocator);
            
            // Merge remaining sources
            for (source_blocks[1..]) |src| {
                if (self.block_states.getPtr(src)) |src_state| {
                    try merged.merge(src_state);
                }
            }
            
            try self.block_states.put(target_block, merged);
        }
    }
    
    /// Get materialization decisions for block
    pub fn getMaterializations(self: *const PartialEscapeAnalyzer, block_id: u32) ?[]const Materialization {
        if (self.block_states.get(block_id)) |state| {
            return state.materializations.items;
        }
        return null;
    }
    
    /// Get statistics
    pub fn getStats(self: *const PartialEscapeAnalyzer) PEAStats {
        return self.stats;
    }
    
    /// Calculate virtualization ratio
    pub fn virtualizationRatio(self: *const PartialEscapeAnalyzer) f64 {
        const total = self.stats.allocations_virtualized;
        if (total == 0) return 0.0;
        const remaining = total - self.stats.materializations;
        return @as(f64, @floatFromInt(remaining)) / @as(f64, @floatFromInt(total)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION AND STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PEAConfig = struct {
    /// Maximum virtual object fields
    max_virtual_fields: u8 = 32,
    /// Maximum virtual objects per block
    max_virtual_objects: u32 = 100,
    /// Enable lock elision
    enable_lock_elision: bool = true,
    /// Sacred threshold
    sacred_threshold: f64 = PHI,
};

pub const PEAStats = struct {
    allocations_virtualized: u64 = 0,
    materializations: u64 = 0,
    stores_virtualized: u64 = 0,
    loads_virtualized: u64 = 0,
    locks_elided: u64 = 0,
    
    pub fn virtualizationRatio(self: *const PEAStats) f64 {
        if (self.allocations_virtualized == 0) return 0.0;
        const remaining = self.allocations_virtualized - self.materializations;
        return @as(f64, @floatFromInt(remaining)) / 
               @as(f64, @floatFromInt(self.allocations_virtualized)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IMMIX GC INTEGRATION - Allocation hints
// ═══════════════════════════════════════════════════════════════════════════════

pub const AllocationHint = struct {
    /// Suggested allocation strategy
    strategy: AllocationStrategy,
    /// Expected lifetime (in GC cycles)
    expected_lifetime: u8 = 1,
    /// Size class hint
    size_class: SizeClass = .small,
    /// Thread-local hint
    thread_local: bool = false,
};

pub const AllocationStrategy = enum {
    /// Allocate on stack (no GC involvement)
    stack,
    /// Scalar replace (no allocation)
    scalar,
    /// Allocate in nursery (young generation)
    nursery,
    /// Allocate directly in old generation
    tenured,
    /// Large object space
    large,
};

pub const SizeClass = enum {
    tiny,   // <= 16 bytes
    small,  // <= 128 bytes
    medium, // <= 2KB
    large,  // > 2KB
};

/// Generate allocation hints from escape analysis
pub fn generateAllocationHints(
    escape_analyzer: *const escape.EscapeAnalyzer,
    pea: *const PartialEscapeAnalyzer,
    alloc_id: u32,
    size: u32
) AllocationHint {
    var hint = AllocationHint{
        .strategy = .nursery,
    };
    
    // Determine size class
    hint.size_class = if (size <= 16) .tiny
        else if (size <= 128) .small
        else if (size <= 2048) .medium
        else .large;
    
    // Check escape analysis decision
    if (escape_analyzer.getDecision(alloc_id)) |decision| {
        if (decision.scalar_replace) {
            hint.strategy = .scalar;
            return hint;
        }
        if (decision.stack_allocate) {
            hint.strategy = .stack;
            return hint;
        }
    }
    
    // Check PEA virtualization
    _ = pea; // PEA integration would check virtualization state
    
    // Large objects go to large object space
    if (hint.size_class == .large) {
        hint.strategy = .large;
    }
    
    return hint;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VirtualObject field operations" {
    const allocator = std.testing.allocator;
    var obj = VirtualObject.init(allocator, 0, 1, 4);
    defer obj.deinit();
    
    try obj.setField(0, FieldValue.constInt(42));
    try obj.setField(2, FieldValue.constFloat(3.14));
    
    const f0 = obj.getField(0).?;
    try std.testing.expectEqual(FieldValueKind.constant_int, f0.kind);
    try std.testing.expectEqual(@as(i64, 42), f0.data.int);
    
    const f2 = obj.getField(2).?;
    try std.testing.expectEqual(FieldValueKind.constant_float, f2.kind);
}

test "AbstractState merge" {
    const allocator = std.testing.allocator;
    var state1 = AbstractState.init(allocator);
    defer state1.deinit();
    
    var state2 = AbstractState.init(allocator);
    defer state2.deinit();
    
    // Add object to state1 only
    const obj1 = VirtualObject.init(allocator, 0, 1, 2);
    try state1.addVirtualObject(obj1);
    
    // Add different object to state2 (will cause materialization on merge)
    const obj2 = VirtualObject.init(allocator, 1, 1, 2);
    try state2.addVirtualObject(obj2);
    
    // Merge state2 into state1
    try state1.merge(&state2);
    
    // Object from state2 should be marked for materialization since it's not in state1
    try std.testing.expectEqual(@as(usize, 1), state1.materializations.items.len);
}

test "PartialEscapeAnalyzer basic" {
    const allocator = std.testing.allocator;
    var pea = PartialEscapeAnalyzer.init(allocator, .{});
    defer pea.deinit();
    
    // Allocate virtual object
    const obj_id = try pea.processAllocation(0, 100, 1, 4);
    try std.testing.expectEqual(@as(u32, 0), obj_id);
    
    // Store to field
    try pea.processStore(0, 100, 0, FieldValue.constInt(42));
    
    // Load from field
    const loaded = pea.processLoad(0, 100, 0);
    try std.testing.expect(loaded != null);
    try std.testing.expectEqual(@as(i64, 42), loaded.?.data.int);
    
    // Check stats
    try std.testing.expectEqual(@as(u64, 1), pea.stats.allocations_virtualized);
    try std.testing.expectEqual(@as(u64, 1), pea.stats.stores_virtualized);
    try std.testing.expectEqual(@as(u64, 1), pea.stats.loads_virtualized);
}

test "AllocationHint generation" {
    const allocator = std.testing.allocator;
    var ea = escape.EscapeAnalyzer.init(allocator, .{
        .max_scalar_fields = 2, // Limit scalar replacement
    });
    defer ea.deinit();
    
    const pea_inst = PartialEscapeAnalyzer.init(allocator, .{});
    defer @constCast(&pea_inst).deinit();
    
    // Register non-escaping allocation with more fields than scalar limit
    const alloc_id = try ea.registerAllocation(0, 1, 64, 8);
    try ea.analyze();
    
    const hint = generateAllocationHints(&ea, &pea_inst, alloc_id, 64);
    // With 8 fields > max_scalar_fields(2), should stack allocate not scalar replace
    try std.testing.expectEqual(AllocationStrategy.stack, hint.strategy);
    try std.testing.expectEqual(SizeClass.small, hint.size_class);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
