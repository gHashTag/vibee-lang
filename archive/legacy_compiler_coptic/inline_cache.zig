// ═══════════════════════════════════════════════════════════════
// POLYMORPHIC INLINE CACHES for Language 999
// Based on: "Optimizing Dynamically-Typed Object-Oriented Languages"
//           (Hölzle, Chambers, Ungar, 1991)
// Expected speedup: 2-5x for method dispatch
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// TYPE ID
// ═══════════════════════════════════════════════════════════════

pub const TypeId = u32;

pub const TypeInfo = struct {
    id: TypeId,
    name: []const u8,
    methods: std.StringHashMap(MethodPtr),
    
    pub fn init(allocator: Allocator, id: TypeId, name: []const u8) TypeInfo {
        return .{
            .id = id,
            .name = name,
            .methods = std.StringHashMap(MethodPtr).init(allocator),
        };
    }
    
    pub fn deinit(self: *TypeInfo) void {
        self.methods.deinit();
    }
    
    pub fn addMethod(self: *TypeInfo, name: []const u8, method: MethodPtr) !void {
        try self.methods.put(name, method);
    }
    
    pub fn getMethod(self: *TypeInfo, name: []const u8) ?MethodPtr {
        return self.methods.get(name);
    }
};

// ═══════════════════════════════════════════════════════════════
// METHOD POINTER
// ═══════════════════════════════════════════════════════════════

pub const MethodPtr = *const fn (*anyopaque, []const Value) Value;

pub const Value = struct {
    type_id: TypeId,
    data: *anyopaque,
};

// ═══════════════════════════════════════════════════════════════
// INLINE CACHE ENTRY
// ═══════════════════════════════════════════════════════════════

pub const CacheEntry = struct {
    type_id: TypeId,
    method: MethodPtr,
    hit_count: u64,
};

// ═══════════════════════════════════════════════════════════════
// MONOMORPHIC INLINE CACHE
// Single type - fastest path (4-5x speedup)
// ═══════════════════════════════════════════════════════════════

pub const MonomorphicCache = struct {
    cached_type: ?TypeId,
    cached_method: ?MethodPtr,
    hits: u64,
    misses: u64,
    
    pub fn init() MonomorphicCache {
        return .{
            .cached_type = null,
            .cached_method = null,
            .hits = 0,
            .misses = 0,
        };
    }
    
    /// Fast path: check if type matches cached type
    pub inline fn lookup(self: *MonomorphicCache, type_id: TypeId) ?MethodPtr {
        if (self.cached_type) |cached| {
            if (cached == type_id) {
                self.hits += 1;
                return self.cached_method;
            }
        }
        self.misses += 1;
        return null;
    }
    
    /// Update cache with new type/method pair
    pub fn update(self: *MonomorphicCache, type_id: TypeId, method: MethodPtr) void {
        self.cached_type = type_id;
        self.cached_method = method;
    }
    
    pub fn hitRate(self: *MonomorphicCache) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════
// POLYMORPHIC INLINE CACHE
// Multiple types - good for 2-4 types (2-3x speedup)
// ═══════════════════════════════════════════════════════════════

pub const MAX_PIC_ENTRIES = 4;

pub const PolymorphicCache = struct {
    entries: [MAX_PIC_ENTRIES]?CacheEntry,
    num_entries: u8,
    hits: u64,
    misses: u64,
    
    pub fn init() PolymorphicCache {
        return .{
            .entries = [_]?CacheEntry{null} ** MAX_PIC_ENTRIES,
            .num_entries = 0,
            .hits = 0,
            .misses = 0,
        };
    }
    
    /// Lookup method for type - linear search through entries
    pub fn lookup(self: *PolymorphicCache, type_id: TypeId) ?MethodPtr {
        // Unrolled loop for performance
        inline for (0..MAX_PIC_ENTRIES) |i| {
            if (self.entries[i]) |entry| {
                if (entry.type_id == type_id) {
                    self.hits += 1;
                    // Move to front for better cache locality
                    if (i > 0) {
                        const temp = self.entries[i];
                        self.entries[i] = self.entries[0];
                        self.entries[0] = temp;
                    }
                    return entry.method;
                }
            }
        }
        self.misses += 1;
        return null;
    }
    
    /// Add new entry to cache
    pub fn add(self: *PolymorphicCache, type_id: TypeId, method: MethodPtr) void {
        if (self.num_entries < MAX_PIC_ENTRIES) {
            // Add new entry
            self.entries[self.num_entries] = .{
                .type_id = type_id,
                .method = method,
                .hit_count = 0,
            };
            self.num_entries += 1;
        } else {
            // Replace least used entry (LRU-like)
            var min_idx: usize = 0;
            var min_hits: u64 = std.math.maxInt(u64);
            
            for (self.entries, 0..) |entry_opt, i| {
                if (entry_opt) |entry| {
                    if (entry.hit_count < min_hits) {
                        min_hits = entry.hit_count;
                        min_idx = i;
                    }
                }
            }
            
            self.entries[min_idx] = .{
                .type_id = type_id,
                .method = method,
                .hit_count = 0,
            };
        }
    }
    
    pub fn hitRate(self: *PolymorphicCache) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
    
    pub fn isMegamorphic(self: *PolymorphicCache) bool {
        return self.num_entries >= MAX_PIC_ENTRIES and self.hitRate() < 0.5;
    }
};

// ═══════════════════════════════════════════════════════════════
// MEGAMORPHIC CACHE
// Many types - fallback to hash table
// ═══════════════════════════════════════════════════════════════

pub const MegamorphicCache = struct {
    cache: std.AutoHashMap(TypeId, MethodPtr),
    hits: u64,
    misses: u64,
    
    pub fn init(allocator: Allocator) MegamorphicCache {
        return .{
            .cache = std.AutoHashMap(TypeId, MethodPtr).init(allocator),
            .hits = 0,
            .misses = 0,
        };
    }
    
    pub fn deinit(self: *MegamorphicCache) void {
        self.cache.deinit();
    }
    
    pub fn lookup(self: *MegamorphicCache, type_id: TypeId) ?MethodPtr {
        if (self.cache.get(type_id)) |method| {
            self.hits += 1;
            return method;
        }
        self.misses += 1;
        return null;
    }
    
    pub fn add(self: *MegamorphicCache, type_id: TypeId, method: MethodPtr) !void {
        try self.cache.put(type_id, method);
    }
};

// ═══════════════════════════════════════════════════════════════
// ADAPTIVE INLINE CACHE
// Automatically transitions between mono/poly/mega
// ═══════════════════════════════════════════════════════════════

pub const CacheState = enum {
    uninitialized,
    monomorphic,
    polymorphic,
    megamorphic,
};

pub const AdaptiveCache = struct {
    state: CacheState,
    mono: MonomorphicCache,
    poly: PolymorphicCache,
    mega: ?MegamorphicCache,
    allocator: Allocator,
    
    // Statistics
    state_transitions: u32,
    
    pub fn init(allocator: Allocator) AdaptiveCache {
        return .{
            .state = .uninitialized,
            .mono = MonomorphicCache.init(),
            .poly = PolymorphicCache.init(),
            .mega = null,
            .allocator = allocator,
            .state_transitions = 0,
        };
    }
    
    pub fn deinit(self: *AdaptiveCache) void {
        if (self.mega) |*m| {
            m.deinit();
        }
    }
    
    /// Main lookup function - dispatches to appropriate cache
    pub fn lookup(self: *AdaptiveCache, type_id: TypeId) ?MethodPtr {
        return switch (self.state) {
            .uninitialized => null,
            .monomorphic => self.mono.lookup(type_id),
            .polymorphic => self.poly.lookup(type_id),
            .megamorphic => if (self.mega) |*m| m.lookup(type_id) else null,
        };
    }
    
    /// Update cache with new type/method - may trigger state transition
    pub fn update(self: *AdaptiveCache, type_id: TypeId, method: MethodPtr) !void {
        switch (self.state) {
            .uninitialized => {
                // First call - go monomorphic
                self.mono.update(type_id, method);
                self.state = .monomorphic;
                self.state_transitions += 1;
            },
            .monomorphic => {
                if (self.mono.cached_type != type_id) {
                    // Second type seen - go polymorphic
                    self.poly.add(self.mono.cached_type.?, self.mono.cached_method.?);
                    self.poly.add(type_id, method);
                    self.state = .polymorphic;
                    self.state_transitions += 1;
                }
            },
            .polymorphic => {
                if (self.poly.lookup(type_id) == null) {
                    if (self.poly.isMegamorphic()) {
                        // Too many types - go megamorphic
                        self.mega = MegamorphicCache.init(self.allocator);
                        
                        // Copy existing entries
                        for (self.poly.entries) |entry_opt| {
                            if (entry_opt) |entry| {
                                try self.mega.?.add(entry.type_id, entry.method);
                            }
                        }
                        try self.mega.?.add(type_id, method);
                        
                        self.state = .megamorphic;
                        self.state_transitions += 1;
                    } else {
                        self.poly.add(type_id, method);
                    }
                }
            },
            .megamorphic => {
                if (self.mega) |*m| {
                    try m.add(type_id, method);
                }
            },
        }
    }
    
    pub fn getStats(self: *AdaptiveCache) CacheStats {
        return .{
            .state = self.state,
            .state_transitions = self.state_transitions,
            .mono_hit_rate = self.mono.hitRate(),
            .poly_hit_rate = self.poly.hitRate(),
        };
    }
};

pub const CacheStats = struct {
    state: CacheState,
    state_transitions: u32,
    mono_hit_rate: f64,
    poly_hit_rate: f64,
};

// ═══════════════════════════════════════════════════════════════
// CALL SITE
// Represents a method call location in bytecode
// ═══════════════════════════════════════════════════════════════

pub const CallSite = struct {
    method_name: []const u8,
    cache: AdaptiveCache,
    call_count: u64,
    
    pub fn init(allocator: Allocator, method_name: []const u8) CallSite {
        return .{
            .method_name = method_name,
            .cache = AdaptiveCache.init(allocator),
            .call_count = 0,
        };
    }
    
    pub fn deinit(self: *CallSite) void {
        self.cache.deinit();
    }
    
    /// Dispatch method call with inline caching
    pub fn dispatch(self: *CallSite, receiver: Value, args: []const Value, type_registry: *TypeRegistry) !Value {
        self.call_count += 1;
        
        // Fast path: check cache
        if (self.cache.lookup(receiver.type_id)) |method| {
            return method(receiver.data, args);
        }
        
        // Slow path: lookup in type registry
        if (type_registry.getType(receiver.type_id)) |type_info| {
            if (type_info.getMethod(self.method_name)) |method| {
                // Update cache for next time
                try self.cache.update(receiver.type_id, method);
                return method(receiver.data, args);
            }
        }
        
        // Method not found
        return Value{ .type_id = 0, .data = undefined };
    }
};

// ═══════════════════════════════════════════════════════════════
// TYPE REGISTRY
// ═══════════════════════════════════════════════════════════════

pub const TypeRegistry = struct {
    allocator: Allocator,
    types: std.AutoHashMap(TypeId, TypeInfo),
    next_id: TypeId,
    
    pub fn init(allocator: Allocator) TypeRegistry {
        return .{
            .allocator = allocator,
            .types = std.AutoHashMap(TypeId, TypeInfo).init(allocator),
            .next_id = 1,
        };
    }
    
    pub fn deinit(self: *TypeRegistry) void {
        var iter = self.types.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.types.deinit();
    }
    
    pub fn registerType(self: *TypeRegistry, name: []const u8) !TypeId {
        const id = self.next_id;
        self.next_id += 1;
        
        try self.types.put(id, TypeInfo.init(self.allocator, id, name));
        return id;
    }
    
    pub fn getType(self: *TypeRegistry, id: TypeId) ?*TypeInfo {
        return self.types.getPtr(id);
    }
    
    pub fn addMethod(self: *TypeRegistry, type_id: TypeId, name: []const u8, method: MethodPtr) !void {
        if (self.types.getPtr(type_id)) |type_info| {
            try type_info.addMethod(name, method);
        }
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "monomorphic cache" {
    var cache = MonomorphicCache.init();
    
    // First lookup - miss
    try std.testing.expect(cache.lookup(1) == null);
    
    // Update cache
    const dummy_method: MethodPtr = undefined;
    cache.update(1, dummy_method);
    
    // Second lookup - hit
    try std.testing.expect(cache.lookup(1) != null);
    
    // Different type - miss
    try std.testing.expect(cache.lookup(2) == null);
}

test "polymorphic cache" {
    var cache = PolymorphicCache.init();
    
    // Use a real function pointer for testing
    const dummy_method: MethodPtr = &dummyMethod;
    
    // Add multiple types
    cache.add(1, dummy_method);
    cache.add(2, dummy_method);
    cache.add(3, dummy_method);
    
    try std.testing.expectEqual(@as(u8, 3), cache.num_entries);
}

fn dummyMethod(_: *anyopaque, _: []const Value) Value {
    return Value{ .type_id = 0, .data = undefined };
}

test "adaptive cache state transitions" {
    var cache = AdaptiveCache.init(std.testing.allocator);
    defer cache.deinit();
    
    try std.testing.expectEqual(CacheState.uninitialized, cache.state);
    
    const dummy_method: MethodPtr = &dummyMethod;
    
    // First type - goes monomorphic
    try cache.update(1, dummy_method);
    try std.testing.expectEqual(CacheState.monomorphic, cache.state);
    
    // Second type - goes polymorphic
    try cache.update(2, dummy_method);
    try std.testing.expectEqual(CacheState.polymorphic, cache.state);
}

test "type registry" {
    var registry = TypeRegistry.init(std.testing.allocator);
    defer registry.deinit();
    
    const id1 = try registry.registerType("Integer");
    const id2 = try registry.registerType("String");
    
    try std.testing.expect(id1 != id2);
    try std.testing.expect(registry.getType(id1) != null);
    try std.testing.expect(registry.getType(id2) != null);
}
