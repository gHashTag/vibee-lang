//! VIBEE Garbage Collector - PAS DAEMON V38
//! Паттерны: HSH (O(1) object lookup), D&C (generational collection), PRE (write barriers)

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// GC CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const GCConfig = struct {
    initial_heap_size: usize = 1024 * 1024,
    max_heap_size: usize = 64 * 1024 * 1024,
    young_gen_ratio: f32 = 0.25,
    gc_threshold: f32 = 0.75,
    enable_incremental: bool = true,
    enable_concurrent: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// OBJECT HEADER - Memory layout for managed objects
// ═══════════════════════════════════════════════════════════════════════════════

pub const ObjectColor = enum(u2) {
    white = 0, // Not visited (garbage candidate)
    gray = 1,  // Visited, children not scanned
    black = 2, // Visited, children scanned
};

pub const Generation = enum(u2) {
    young = 0,
    survivor = 1,
    old = 2,
};

pub const ObjectHeader = packed struct {
    mark: ObjectColor = .white,
    generation: Generation = .young,
    pinned: bool = false,
    finalized: bool = false,
    _reserved: u4 = 0,
    size: u24,
    type_id: u32,
    
    pub fn init(size: usize, type_id: u32) ObjectHeader {
        return .{
            .size = @truncate(size),
            .type_id = type_id,
        };
    }
    
    pub fn totalSize(self: ObjectHeader) usize {
        return @sizeOf(ObjectHeader) + self.size;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GC OBJECT - Managed object wrapper
// ═══════════════════════════════════════════════════════════════════════════════

pub const GCObject = struct {
    header: ObjectHeader,
    // Data follows header in memory
    
    pub fn getData(self: *GCObject) []u8 {
        const ptr: [*]u8 = @ptrCast(self);
        return ptr[@sizeOf(ObjectHeader)..][0..self.header.size];
    }
    
    pub fn fromPtr(ptr: *anyopaque) *GCObject {
        const byte_ptr: [*]u8 = @ptrCast(ptr);
        return @ptrCast(@alignCast(byte_ptr - @sizeOf(ObjectHeader)));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT SET - GC roots tracking
// ═══════════════════════════════════════════════════════════════════════════════

pub const RootSet = struct {
    allocator: Allocator,
    roots: std.ArrayList(*GCObject),
    
    pub fn init(allocator: Allocator) RootSet {
        return .{
            .allocator = allocator,
            .roots = std.ArrayList(*GCObject).init(allocator),
        };
    }
    
    pub fn deinit(self: *RootSet) void {
        self.roots.deinit();
    }
    
    pub fn addRoot(self: *RootSet, obj: *GCObject) !void {
        try self.roots.append(obj);
    }
    
    pub fn removeRoot(self: *RootSet, obj: *GCObject) void {
        for (self.roots.items, 0..) |root, i| {
            if (root == obj) {
                _ = self.roots.swapRemove(i);
                return;
            }
        }
    }
    
    pub fn clear(self: *RootSet) void {
        self.roots.clearRetainingCapacity();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WRITE BARRIER - PRE pattern for incremental GC
// ═══════════════════════════════════════════════════════════════════════════════

pub const WriteBarrier = struct {
    dirty_cards: std.AutoHashMap(usize, void),
    card_size: usize = 512,
    enabled: bool = true,
    
    pub fn init(allocator: Allocator) WriteBarrier {
        return .{
            .dirty_cards = std.AutoHashMap(usize, void).init(allocator),
        };
    }
    
    pub fn deinit(self: *WriteBarrier) void {
        self.dirty_cards.deinit();
    }
    
    pub fn recordWrite(self: *WriteBarrier, addr: usize) !void {
        if (!self.enabled) return;
        const card = addr / self.card_size;
        try self.dirty_cards.put(card, {});
    }
    
    pub fn clearDirtyCards(self: *WriteBarrier) void {
        self.dirty_cards.clearRetainingCapacity();
    }
    
    pub fn isDirty(self: *const WriteBarrier, addr: usize) bool {
        const card = addr / self.card_size;
        return self.dirty_cards.contains(card);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HEAP REGION - Memory region for allocation
// ═══════════════════════════════════════════════════════════════════════════════

pub const HeapRegion = struct {
    allocator: Allocator,
    memory: []u8,
    bump_ptr: usize = 0,
    generation: Generation,
    object_count: usize = 0,
    
    pub fn init(allocator: Allocator, size: usize, gen: Generation) !HeapRegion {
        const memory = try allocator.alloc(u8, size);
        return .{
            .allocator = allocator,
            .memory = memory,
            .generation = gen,
        };
    }
    
    pub fn deinit(self: *HeapRegion) void {
        self.allocator.free(self.memory);
    }
    
    pub fn allocate(self: *HeapRegion, size: usize, type_id: u32) ?*GCObject {
        const total_size = @sizeOf(ObjectHeader) + size;
        const aligned_size = std.mem.alignForward(usize, total_size, 8);
        
        if (self.bump_ptr + aligned_size > self.memory.len) {
            return null;
        }
        
        const obj_ptr: *GCObject = @ptrCast(@alignCast(self.memory.ptr + self.bump_ptr));
        obj_ptr.header = ObjectHeader.init(size, type_id);
        obj_ptr.header.generation = self.generation;
        
        self.bump_ptr += aligned_size;
        self.object_count += 1;
        
        return obj_ptr;
    }
    
    pub fn reset(self: *HeapRegion) void {
        self.bump_ptr = 0;
        self.object_count = 0;
        @memset(self.memory, 0);
    }
    
    pub fn usedBytes(self: *const HeapRegion) usize {
        return self.bump_ptr;
    }
    
    pub fn freeBytes(self: *const HeapRegion) usize {
        return self.memory.len - self.bump_ptr;
    }
    
    pub fn utilizationRatio(self: *const HeapRegion) f32 {
        return @as(f32, @floatFromInt(self.bump_ptr)) / @as(f32, @floatFromInt(self.memory.len));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GC STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const GCStats = struct {
    total_allocations: u64 = 0,
    total_bytes_allocated: u64 = 0,
    total_collections: u64 = 0,
    young_collections: u64 = 0,
    full_collections: u64 = 0,
    total_freed_bytes: u64 = 0,
    total_gc_time_ns: u64 = 0,
    peak_heap_size: usize = 0,
    
    pub fn recordAllocation(self: *GCStats, size: usize) void {
        self.total_allocations += 1;
        self.total_bytes_allocated += size;
    }
    
    pub fn recordCollection(self: *GCStats, freed: usize, duration_ns: u64, is_full: bool) void {
        self.total_collections += 1;
        self.total_freed_bytes += freed;
        self.total_gc_time_ns += duration_ns;
        if (is_full) {
            self.full_collections += 1;
        } else {
            self.young_collections += 1;
        }
    }
    
    pub fn getAverageGCTime(self: *const GCStats) u64 {
        if (self.total_collections == 0) return 0;
        return self.total_gc_time_ns / self.total_collections;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GARBAGE COLLECTOR - Main GC implementation
// ═══════════════════════════════════════════════════════════════════════════════

pub const GarbageCollector = struct {
    allocator: Allocator,
    config: GCConfig,
    
    // Generational heaps (D&C pattern)
    young_gen: HeapRegion,
    survivor_space: HeapRegion,
    old_gen: HeapRegion,
    
    // Root tracking
    roots: RootSet,
    
    // Write barrier (PRE pattern)
    write_barrier: WriteBarrier,
    
    // Object tracking (HSH pattern)
    all_objects: std.AutoHashMap(usize, *GCObject),
    
    // Gray set for tri-color marking
    gray_set: std.ArrayList(*GCObject),
    
    // Statistics
    stats: GCStats,
    
    // State
    is_collecting: bool = false,
    
    pub fn init(allocator: Allocator, config: GCConfig) !GarbageCollector {
        const young_size = @as(usize, @intFromFloat(@as(f32, @floatFromInt(config.initial_heap_size)) * config.young_gen_ratio));
        const survivor_size = young_size / 2;
        const old_size = config.initial_heap_size - young_size - survivor_size;
        
        return .{
            .allocator = allocator,
            .config = config,
            .young_gen = try HeapRegion.init(allocator, young_size, .young),
            .survivor_space = try HeapRegion.init(allocator, survivor_size, .survivor),
            .old_gen = try HeapRegion.init(allocator, old_size, .old),
            .roots = RootSet.init(allocator),
            .write_barrier = WriteBarrier.init(allocator),
            .all_objects = std.AutoHashMap(usize, *GCObject).init(allocator),
            .gray_set = std.ArrayList(*GCObject).init(allocator),
            .stats = GCStats{},
        };
    }
    
    pub fn deinit(self: *GarbageCollector) void {
        self.young_gen.deinit();
        self.survivor_space.deinit();
        self.old_gen.deinit();
        self.roots.deinit();
        self.write_barrier.deinit();
        self.all_objects.deinit();
        self.gray_set.deinit();
    }
    
    /// Allocate new object
    pub fn allocate(self: *GarbageCollector, size: usize, type_id: u32) !*GCObject {
        // Try young generation first
        if (self.young_gen.allocate(size, type_id)) |obj| {
            try self.all_objects.put(@intFromPtr(obj), obj);
            self.stats.recordAllocation(size);
            return obj;
        }
        
        // Young gen full - trigger minor GC
        try self.collectYoung();
        
        // Retry allocation
        if (self.young_gen.allocate(size, type_id)) |obj| {
            try self.all_objects.put(@intFromPtr(obj), obj);
            self.stats.recordAllocation(size);
            return obj;
        }
        
        // Still no space - try old gen
        if (self.old_gen.allocate(size, type_id)) |obj| {
            obj.header.generation = .old;
            try self.all_objects.put(@intFromPtr(obj), obj);
            self.stats.recordAllocation(size);
            return obj;
        }
        
        // Full GC needed
        try self.collectFull();
        
        // Final attempt
        if (self.young_gen.allocate(size, type_id)) |obj| {
            try self.all_objects.put(@intFromPtr(obj), obj);
            self.stats.recordAllocation(size);
            return obj;
        }
        
        return error.OutOfMemory;
    }
    
    /// Add GC root
    pub fn addRoot(self: *GarbageCollector, obj: *GCObject) !void {
        try self.roots.addRoot(obj);
    }
    
    /// Remove GC root
    pub fn removeRoot(self: *GarbageCollector, obj: *GCObject) void {
        self.roots.removeRoot(obj);
    }
    
    /// Record pointer write for write barrier
    pub fn writeBarrier(self: *GarbageCollector, addr: usize) !void {
        try self.write_barrier.recordWrite(addr);
    }
    
    /// Minor GC - collect young generation only
    pub fn collectYoung(self: *GarbageCollector) !void {
        if (self.is_collecting) return;
        self.is_collecting = true;
        defer self.is_collecting = false;
        
        const start_time = std.time.nanoTimestamp();
        const before_used = self.young_gen.usedBytes();
        
        // Mark phase
        try self.markFromRoots();
        
        // Sweep young gen
        self.sweepGeneration(.young);
        
        const after_used = self.young_gen.usedBytes();
        const freed = if (before_used > after_used) before_used - after_used else 0;
        const duration: u64 = @intCast(@as(u128, @bitCast(std.time.nanoTimestamp() - start_time)));
        
        self.stats.recordCollection(freed, duration, false);
        self.write_barrier.clearDirtyCards();
    }
    
    /// Full GC - collect all generations
    pub fn collectFull(self: *GarbageCollector) !void {
        if (self.is_collecting) return;
        self.is_collecting = true;
        defer self.is_collecting = false;
        
        const start_time = std.time.nanoTimestamp();
        const before_used = self.totalUsedBytes();
        
        // Mark phase
        try self.markFromRoots();
        
        // Sweep all generations
        self.sweepGeneration(.young);
        self.sweepGeneration(.survivor);
        self.sweepGeneration(.old);
        
        const after_used = self.totalUsedBytes();
        const freed = if (before_used > after_used) before_used - after_used else 0;
        const duration: u64 = @intCast(@as(u128, @bitCast(std.time.nanoTimestamp() - start_time)));
        
        self.stats.recordCollection(freed, duration, true);
        self.write_barrier.clearDirtyCards();
    }
    
    /// Mark phase - tri-color marking
    fn markFromRoots(self: *GarbageCollector) !void {
        // Reset all objects to white
        var iter = self.all_objects.valueIterator();
        while (iter.next()) |obj| {
            obj.*.header.mark = .white;
        }
        
        // Add roots to gray set
        self.gray_set.clearRetainingCapacity();
        for (self.roots.roots.items) |root| {
            root.header.mark = .gray;
            try self.gray_set.append(root);
        }
        
        // Process gray set
        while (self.gray_set.items.len > 0) {
            const obj = self.gray_set.pop();
            obj.header.mark = .black;
            // In real impl, would scan object for references and add to gray set
        }
    }
    
    /// Sweep phase - remove white objects
    fn sweepGeneration(self: *GarbageCollector, gen: Generation) void {
        var to_remove = std.ArrayList(usize).init(self.allocator);
        defer to_remove.deinit();
        
        var iter = self.all_objects.iterator();
        while (iter.next()) |entry| {
            const obj = entry.value_ptr.*;
            if (obj.header.generation == gen and obj.header.mark == .white) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }
        
        for (to_remove.items) |addr| {
            _ = self.all_objects.remove(addr);
        }
    }
    
    /// Get total used bytes across all generations
    pub fn totalUsedBytes(self: *const GarbageCollector) usize {
        return self.young_gen.usedBytes() + 
               self.survivor_space.usedBytes() + 
               self.old_gen.usedBytes();
    }
    
    /// Get total heap size
    pub fn totalHeapSize(self: *const GarbageCollector) usize {
        return self.young_gen.memory.len + 
               self.survivor_space.memory.len + 
               self.old_gen.memory.len;
    }
    
    /// Get GC statistics
    pub fn getStats(self: *const GarbageCollector) GCStats {
        return self.stats;
    }
    
    /// Check if GC should run
    pub fn shouldCollect(self: *const GarbageCollector) bool {
        const ratio = @as(f32, @floatFromInt(self.totalUsedBytes())) / 
                      @as(f32, @floatFromInt(self.totalHeapSize()));
        return ratio >= self.config.gc_threshold;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ObjectHeader size calculation" {
    const header = ObjectHeader.init(100, 1);
    try std.testing.expectEqual(@as(u24, 100), header.size);
    try std.testing.expectEqual(@as(usize, 100 + @sizeOf(ObjectHeader)), header.totalSize());
}

test "HeapRegion allocation" {
    const allocator = std.testing.allocator;
    var region = try HeapRegion.init(allocator, 4096, .young);
    defer region.deinit();
    
    const obj1 = region.allocate(64, 1).?;
    const obj2 = region.allocate(128, 2).?;
    
    try std.testing.expectEqual(@as(u24, 64), obj1.header.size);
    try std.testing.expectEqual(@as(u24, 128), obj2.header.size);
    try std.testing.expectEqual(@as(usize, 2), region.object_count);
}

test "WriteBarrier PRE pattern" {
    const allocator = std.testing.allocator;
    var barrier = WriteBarrier.init(allocator);
    defer barrier.deinit();
    
    try barrier.recordWrite(1000);
    try barrier.recordWrite(1200);
    
    try std.testing.expect(barrier.isDirty(1000));
    try std.testing.expect(barrier.isDirty(1200));
    try std.testing.expect(!barrier.isDirty(2000));
    
    barrier.clearDirtyCards();
    try std.testing.expect(!barrier.isDirty(1000));
}

test "RootSet management" {
    const allocator = std.testing.allocator;
    var roots = RootSet.init(allocator);
    defer roots.deinit();
    
    var region = try HeapRegion.init(allocator, 4096, .young);
    defer region.deinit();
    
    const obj = region.allocate(32, 1).?;
    try roots.addRoot(obj);
    
    try std.testing.expectEqual(@as(usize, 1), roots.roots.items.len);
    
    roots.removeRoot(obj);
    try std.testing.expectEqual(@as(usize, 0), roots.roots.items.len);
}

test "GarbageCollector allocation" {
    const allocator = std.testing.allocator;
    var gc = try GarbageCollector.init(allocator, .{
        .initial_heap_size = 16384,
    });
    defer gc.deinit();
    
    const obj1 = try gc.allocate(64, 1);
    const obj2 = try gc.allocate(128, 2);
    
    try std.testing.expectEqual(@as(u24, 64), obj1.header.size);
    try std.testing.expectEqual(@as(u24, 128), obj2.header.size);
    try std.testing.expectEqual(@as(u64, 2), gc.stats.total_allocations);
}

test "GarbageCollector roots" {
    const allocator = std.testing.allocator;
    var gc = try GarbageCollector.init(allocator, .{
        .initial_heap_size = 16384,
    });
    defer gc.deinit();
    
    const obj = try gc.allocate(32, 1);
    try gc.addRoot(obj);
    
    try std.testing.expectEqual(@as(usize, 1), gc.roots.roots.items.len);
}

test "GCStats tracking" {
    var stats = GCStats{};
    
    stats.recordAllocation(100);
    stats.recordAllocation(200);
    
    try std.testing.expectEqual(@as(u64, 2), stats.total_allocations);
    try std.testing.expectEqual(@as(u64, 300), stats.total_bytes_allocated);
    
    stats.recordCollection(150, 1000, false);
    
    try std.testing.expectEqual(@as(u64, 1), stats.young_collections);
    try std.testing.expectEqual(@as(u64, 150), stats.total_freed_bytes);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
