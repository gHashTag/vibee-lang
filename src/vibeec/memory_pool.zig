//! VIBEE Memory Pool Allocator - PAS DAEMON V39
//! Паттерны: PRE (preallocated blocks), HSH (O(1) free list), AMR (φ-based growth)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// POOL CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const PoolConfig = struct {
    initial_block_count: usize = 64,
    max_block_count: usize = 65536,
    growth_factor: f64 = PHI, // AMR pattern: golden ratio growth
    alignment: usize = 8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FREE LIST NODE - Intrusive linked list
// ═══════════════════════════════════════════════════════════════════════════════

const FreeNode = struct {
    next: ?*FreeNode,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY POOL - Fixed-size object pool with O(1) alloc/free
// ═══════════════════════════════════════════════════════════════════════════════

pub fn MemoryPool(comptime T: type) type {
    return struct {
        const Self = @This();
        const ITEM_SIZE = @max(@sizeOf(T), @sizeOf(FreeNode));
        const ALIGNMENT = @max(@alignOf(T), @alignOf(FreeNode));
        
        backing_allocator: Allocator,
        config: PoolConfig,
        
        // Free list head (HSH pattern - O(1) access)
        free_list: ?*FreeNode = null,
        
        // All allocated chunks for cleanup
        chunks: std.ArrayList([]align(ALIGNMENT) u8),
        
        // Statistics
        stats: PoolStats = .{},
        
        pub fn init(backing_allocator: Allocator, config: PoolConfig) Self {
            return .{
                .backing_allocator = backing_allocator,
                .config = config,
                .chunks = std.ArrayList([]align(ALIGNMENT) u8).init(backing_allocator),
            };
        }
        
        pub fn deinit(self: *Self) void {
            for (self.chunks.items) |chunk| {
                self.backing_allocator.free(chunk);
            }
            self.chunks.deinit();
        }
        
        /// Allocate single object - O(1) amortized
        pub fn create(self: *Self) !*T {
            // Try free list first (O(1))
            if (self.free_list) |node| {
                self.free_list = node.next;
                self.stats.free_list_hits += 1;
                self.stats.active_count += 1;
                return @ptrCast(@alignCast(node));
            }
            
            // Need to allocate new chunk
            try self.growPool();
            
            // Now free list should have items
            if (self.free_list) |node| {
                self.free_list = node.next;
                self.stats.active_count += 1;
                return @ptrCast(@alignCast(node));
            }
            
            return error.OutOfMemory;
        }
        
        /// Free single object - O(1)
        pub fn destroy(self: *Self, ptr: *T) void {
            const node: *FreeNode = @ptrCast(@alignCast(ptr));
            node.next = self.free_list;
            self.free_list = node;
            self.stats.active_count -= 1;
            self.stats.total_frees += 1;
        }
        
        /// Grow pool using φ-based growth (AMR pattern)
        fn growPool(self: *Self) !void {
            const current_capacity = self.stats.total_capacity;
            const new_count: usize = if (current_capacity == 0)
                self.config.initial_block_count
            else
                @intFromFloat(@as(f64, @floatFromInt(current_capacity)) * self.config.growth_factor);
            
            const capped_count = @min(new_count, self.config.max_block_count);
            if (capped_count == current_capacity) {
                return error.OutOfMemory;
            }
            
            const items_to_add = capped_count - current_capacity;
            const chunk_size = items_to_add * ITEM_SIZE;
            
            const chunk = try self.backing_allocator.alignedAlloc(u8, ALIGNMENT, chunk_size);
            try self.chunks.append(chunk);
            
            // Add all items to free list
            var i: usize = 0;
            while (i < items_to_add) : (i += 1) {
                const offset = i * ITEM_SIZE;
                const node: *FreeNode = @ptrCast(@alignCast(chunk.ptr + offset));
                node.next = self.free_list;
                self.free_list = node;
            }
            
            self.stats.total_capacity = capped_count;
            self.stats.chunk_count += 1;
            self.stats.total_allocations += items_to_add;
        }
        
        /// Get pool statistics
        pub fn getStats(self: *const Self) PoolStats {
            return self.stats;
        }
        
        /// Reset pool (keep memory, reset free list)
        pub fn reset(self: *Self) void {
            self.free_list = null;
            
            // Rebuild free list from all chunks
            for (self.chunks.items) |chunk| {
                const items = chunk.len / ITEM_SIZE;
                var i: usize = 0;
                while (i < items) : (i += 1) {
                    const offset = i * ITEM_SIZE;
                    const node: *FreeNode = @ptrCast(@alignCast(chunk.ptr + offset));
                    node.next = self.free_list;
                    self.free_list = node;
                }
            }
            
            self.stats.active_count = 0;
        }
        
        /// Get allocator interface
        pub fn allocator(self: *Self) Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }
        
        fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            _ = ret_addr;
            _ = ptr_align;
            if (len != @sizeOf(T)) return null;
            
            const self: *Self = @ptrCast(@alignCast(ctx));
            const ptr = self.create() catch return null;
            return @ptrCast(ptr);
        }
        
        fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            _ = ctx;
            _ = buf;
            _ = buf_align;
            _ = new_len;
            _ = ret_addr;
            return false; // Pool doesn't support resize
        }
        
        fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
            _ = buf_align;
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(ctx));
            const ptr: *T = @ptrCast(@alignCast(buf.ptr));
            self.destroy(ptr);
        }
    };
}

pub const PoolStats = struct {
    total_capacity: usize = 0,
    active_count: usize = 0,
    chunk_count: usize = 0,
    total_allocations: usize = 0,
    total_frees: usize = 0,
    free_list_hits: usize = 0,
    
    pub fn utilizationRatio(self: *const PoolStats) f64 {
        if (self.total_capacity == 0) return 0.0;
        return @as(f64, @floatFromInt(self.active_count)) / 
               @as(f64, @floatFromInt(self.total_capacity));
    }
    
    pub fn freeListHitRatio(self: *const PoolStats) f64 {
        const total_allocs = self.free_list_hits + self.chunk_count;
        if (total_allocs == 0) return 0.0;
        return @as(f64, @floatFromInt(self.free_list_hits)) / 
               @as(f64, @floatFromInt(total_allocs));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ARENA ALLOCATOR - Bulk allocation with single free
// ═══════════════════════════════════════════════════════════════════════════════

pub const Arena = struct {
    backing_allocator: Allocator,
    chunks: std.ArrayList([]u8),
    current_chunk: ?[]u8 = null,
    chunk_pos: usize = 0,
    default_chunk_size: usize,
    
    // Statistics
    total_allocated: usize = 0,
    allocation_count: usize = 0,
    
    pub fn init(backing_allocator: Allocator, default_chunk_size: usize) Arena {
        return .{
            .backing_allocator = backing_allocator,
            .chunks = std.ArrayList([]u8).init(backing_allocator),
            .default_chunk_size = default_chunk_size,
        };
    }
    
    pub fn deinit(self: *Arena) void {
        for (self.chunks.items) |chunk| {
            self.backing_allocator.free(chunk);
        }
        self.chunks.deinit();
        if (self.current_chunk) |chunk| {
            self.backing_allocator.free(chunk);
        }
    }
    
    /// Allocate memory - O(1) amortized
    pub fn alloc(self: *Arena, comptime T: type, n: usize) ![]T {
        const byte_count = @sizeOf(T) * n;
        const alignment = @alignOf(T);
        
        const bytes = try self.allocBytes(byte_count, alignment);
        return @as([*]T, @ptrCast(@alignCast(bytes.ptr)))[0..n];
    }
    
    /// Allocate single item
    pub fn create(self: *Arena, comptime T: type) !*T {
        const slice = try self.alloc(T, 1);
        return &slice[0];
    }
    
    fn allocBytes(self: *Arena, size: usize, alignment: usize) ![]u8 {
        // Try current chunk
        if (self.current_chunk) |chunk| {
            const aligned_pos = std.mem.alignForward(usize, self.chunk_pos, alignment);
            if (aligned_pos + size <= chunk.len) {
                const result = chunk[aligned_pos..][0..size];
                self.chunk_pos = aligned_pos + size;
                self.total_allocated += size;
                self.allocation_count += 1;
                return result;
            }
            
            // Current chunk exhausted, save it
            try self.chunks.append(chunk);
        }
        
        // Allocate new chunk with φ-based sizing (AMR pattern)
        const chunk_size = @max(self.default_chunk_size, size);
        const new_size: usize = @intFromFloat(@as(f64, @floatFromInt(chunk_size)) * PHI);
        
        const new_chunk = try self.backing_allocator.alloc(u8, new_size);
        self.current_chunk = new_chunk;
        self.chunk_pos = 0;
        
        const aligned_pos = std.mem.alignForward(usize, 0, alignment);
        const result = new_chunk[aligned_pos..][0..size];
        self.chunk_pos = aligned_pos + size;
        self.total_allocated += size;
        self.allocation_count += 1;
        
        return result;
    }
    
    /// Reset arena (keep memory)
    pub fn reset(self: *Arena) void {
        // Move current chunk to chunks list
        if (self.current_chunk) |chunk| {
            self.chunks.append(chunk) catch {};
            self.current_chunk = null;
        }
        
        // Reset all chunks
        if (self.chunks.items.len > 0) {
            self.current_chunk = self.chunks.pop();
            self.chunk_pos = 0;
        }
        
        self.total_allocated = 0;
        self.allocation_count = 0;
    }
    
    /// Get allocator interface
    pub fn allocator(self: *Arena) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = arenaAlloc,
                .resize = arenaResize,
                .free = arenaFree,
            },
        };
    }
    
    fn arenaAlloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Arena = @ptrCast(@alignCast(ctx));
        const bytes = self.allocBytes(len, @as(usize, 1) << @intCast(ptr_align)) catch return null;
        return bytes.ptr;
    }
    
    fn arenaResize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return false;
    }
    
    fn arenaFree(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
        // Arena doesn't free individual allocations
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SLAB ALLOCATOR - Multiple size classes
// ═══════════════════════════════════════════════════════════════════════════════

pub const SlabAllocator = struct {
    backing_allocator: Allocator,
    
    // Size class pools (powers of 2: 8, 16, 32, 64, 128, 256, 512, 1024)
    pools: [8]SlabPool,
    
    // Large allocation fallback
    large_allocations: std.AutoHashMap(usize, usize), // ptr -> size
    
    pub fn init(backing_allocator: Allocator) SlabAllocator {
        var pools: [8]SlabPool = undefined;
        inline for (0..8) |i| {
            const size: usize = @as(usize, 8) << @intCast(i);
            pools[i] = SlabPool.init(backing_allocator, size);
        }
        
        return .{
            .backing_allocator = backing_allocator,
            .pools = pools,
            .large_allocations = std.AutoHashMap(usize, usize).init(backing_allocator),
        };
    }
    
    pub fn deinit(self: *SlabAllocator) void {
        for (&self.pools) |*pool| {
            pool.deinit();
        }
        
        var iter = self.large_allocations.iterator();
        while (iter.next()) |entry| {
            const ptr: [*]u8 = @ptrFromInt(entry.key_ptr.*);
            self.backing_allocator.free(ptr[0..entry.value_ptr.*]);
        }
        self.large_allocations.deinit();
    }
    
    /// Allocate memory
    pub fn alloc(self: *SlabAllocator, size: usize) ![]u8 {
        if (size == 0) return &[_]u8{};
        
        // Find appropriate size class
        const class = getSizeClass(size);
        if (class) |c| {
            const ptr = try self.pools[c].alloc();
            return ptr[0..size];
        }
        
        // Large allocation
        const mem = try self.backing_allocator.alloc(u8, size);
        try self.large_allocations.put(@intFromPtr(mem.ptr), size);
        return mem;
    }
    
    /// Free memory
    pub fn free(self: *SlabAllocator, ptr: []u8) void {
        if (ptr.len == 0) return;
        
        const class = getSizeClass(ptr.len);
        if (class) |c| {
            self.pools[c].free(ptr.ptr);
            return;
        }
        
        // Large allocation
        if (self.large_allocations.fetchRemove(@intFromPtr(ptr.ptr))) |kv| {
            const full_ptr: [*]u8 = @ptrFromInt(kv.key);
            self.backing_allocator.free(full_ptr[0..kv.value]);
        }
    }
    
    fn getSizeClass(size: usize) ?usize {
        if (size <= 8) return 0;
        if (size <= 16) return 1;
        if (size <= 32) return 2;
        if (size <= 64) return 3;
        if (size <= 128) return 4;
        if (size <= 256) return 5;
        if (size <= 512) return 6;
        if (size <= 1024) return 7;
        return null;
    }
};

const SlabPool = struct {
    backing_allocator: Allocator,
    item_size: usize,
    free_list: ?*FreeNode = null,
    chunks: std.ArrayList([]u8),
    
    pub fn init(backing_allocator: Allocator, item_size: usize) SlabPool {
        return .{
            .backing_allocator = backing_allocator,
            .item_size = item_size,
            .chunks = std.ArrayList([]u8).init(backing_allocator),
        };
    }
    
    pub fn deinit(self: *SlabPool) void {
        for (self.chunks.items) |chunk| {
            self.backing_allocator.free(chunk);
        }
        self.chunks.deinit();
    }
    
    pub fn alloc(self: *SlabPool) ![*]u8 {
        if (self.free_list) |node| {
            self.free_list = node.next;
            return @ptrCast(node);
        }
        
        // Grow pool
        const chunk_items = 64;
        const chunk_size = chunk_items * self.item_size;
        const chunk = try self.backing_allocator.alloc(u8, chunk_size);
        try self.chunks.append(chunk);
        
        // Add to free list
        var i: usize = 1; // Skip first item (we'll return it)
        while (i < chunk_items) : (i += 1) {
            const offset = i * self.item_size;
            const node: *FreeNode = @ptrCast(@alignCast(chunk.ptr + offset));
            node.next = self.free_list;
            self.free_list = node;
        }
        
        return chunk.ptr;
    }
    
    pub fn free(self: *SlabPool, ptr: [*]u8) void {
        const node: *FreeNode = @ptrCast(@alignCast(ptr));
        node.next = self.free_list;
        self.free_list = node;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

const TestStruct = struct {
    a: u64,
    b: u64,
    c: u32,
};

test "MemoryPool basic allocation" {
    const allocator = std.testing.allocator;
    var pool = MemoryPool(TestStruct).init(allocator, .{});
    defer pool.deinit();
    
    const obj1 = try pool.create();
    obj1.a = 42;
    obj1.b = 100;
    
    const obj2 = try pool.create();
    obj2.a = 99;
    
    try std.testing.expectEqual(@as(u64, 42), obj1.a);
    try std.testing.expectEqual(@as(u64, 99), obj2.a);
    
    pool.destroy(obj1);
    pool.destroy(obj2);
}

test "MemoryPool free list reuse" {
    const allocator = std.testing.allocator;
    var pool = MemoryPool(TestStruct).init(allocator, .{});
    defer pool.deinit();
    
    const obj1 = try pool.create();
    const addr1 = @intFromPtr(obj1);
    pool.destroy(obj1);
    
    const obj2 = try pool.create();
    const addr2 = @intFromPtr(obj2);
    
    // Should reuse the same memory
    try std.testing.expectEqual(addr1, addr2);
    
    const stats = pool.getStats();
    try std.testing.expect(stats.free_list_hits > 0);
    
    pool.destroy(obj2);
}

test "MemoryPool φ-based growth" {
    const allocator = std.testing.allocator;
    var pool = MemoryPool(TestStruct).init(allocator, .{ .initial_block_count = 4 });
    defer pool.deinit();
    
    // Allocate more than initial capacity
    var ptrs: [10]*TestStruct = undefined;
    for (0..10) |i| {
        ptrs[i] = try pool.create();
    }
    
    const stats = pool.getStats();
    try std.testing.expect(stats.chunk_count >= 2); // Should have grown
    
    for (ptrs) |ptr| {
        pool.destroy(ptr);
    }
}

test "Arena allocation" {
    const allocator = std.testing.allocator;
    var arena = Arena.init(allocator, 1024);
    defer arena.deinit();
    
    const slice1 = try arena.alloc(u64, 10);
    slice1[0] = 42;
    
    const obj = try arena.create(TestStruct);
    obj.a = 100;
    
    try std.testing.expectEqual(@as(u64, 42), slice1[0]);
    try std.testing.expectEqual(@as(u64, 100), obj.a);
}

test "Arena reset" {
    const allocator = std.testing.allocator;
    var arena = Arena.init(allocator, 1024);
    defer arena.deinit();
    
    _ = try arena.alloc(u8, 100);
    const count1 = arena.allocation_count;
    
    arena.reset();
    
    try std.testing.expectEqual(@as(usize, 0), arena.allocation_count);
    
    _ = try arena.alloc(u8, 100);
    try std.testing.expectEqual(@as(usize, 1), arena.allocation_count);
    _ = count1;
}

test "SlabAllocator size classes" {
    const allocator = std.testing.allocator;
    var slab = SlabAllocator.init(allocator);
    defer slab.deinit();
    
    const small = try slab.alloc(8);
    const medium = try slab.alloc(64);
    const large = try slab.alloc(2048);
    
    try std.testing.expectEqual(@as(usize, 8), small.len);
    try std.testing.expectEqual(@as(usize, 64), medium.len);
    try std.testing.expectEqual(@as(usize, 2048), large.len);
    
    slab.free(small);
    slab.free(medium);
    slab.free(large);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
