// ═══════════════════════════════════════════════════════════════
// v6713: MEMORY INTEGRATION - Long-term Dialog Memory
// Generated from specs/tri/v6713_memory_integration.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════
// MEMORY TYPES
// ═══════════════════════════════════════════════════════════════

pub const MemoryType = enum {
    ShortTerm, // Current conversation
    Working, // Active context
    LongTerm, // Persistent facts
    Episodic, // Past conversations
    Semantic, // General knowledge

    pub fn decayRate(self: MemoryType) f64 {
        return switch (self) {
            .ShortTerm => 0.9, // Fast decay
            .Working => 0.95,
            .LongTerm => 0.999, // Very slow decay
            .Episodic => 0.99,
            .Semantic => 1.0, // No decay
        };
    }

    pub fn maxCapacity(self: MemoryType) usize {
        return switch (self) {
            .ShortTerm => 10,
            .Working => 50,
            .LongTerm => 1000,
            .Episodic => 500,
            .Semantic => 10000,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// MEMORY ENTRY
// ═══════════════════════════════════════════════════════════════

pub const MemoryEntry = struct {
    id: u64,
    content: [256]u8,
    content_len: u16,
    memory_type: MemoryType,
    importance: f64,
    access_count: u32,
    created_at: i64,
    last_accessed: i64,
    embedding: [64]f32, // Simplified embedding

    pub fn init(id: u64, content: []const u8, memory_type: MemoryType) MemoryEntry {
        var entry = MemoryEntry{
            .id = id,
            .content = undefined,
            .content_len = 0,
            .memory_type = memory_type,
            .importance = 0.5,
            .access_count = 0,
            .created_at = std.time.milliTimestamp(),
            .last_accessed = std.time.milliTimestamp(),
            .embedding = [_]f32{0} ** 64,
        };

        const len = @min(content.len, 256);
        @memcpy(entry.content[0..len], content[0..len]);
        entry.content_len = @intCast(len);

        // Simple hash-based embedding
        entry.computeEmbedding();

        return entry;
    }

    pub fn getContent(self: MemoryEntry) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn computeEmbedding(self: *MemoryEntry) void {
        // Simple hash-based embedding (real impl would use model)
        const content = self.getContent();
        var hash: u64 = 0;
        for (content) |c| {
            hash = hash *% 31 +% c;
        }

        for (&self.embedding, 0..) |*e, i| {
            const seed = hash +% i;
            e.* = @as(f32, @floatFromInt(seed % 1000)) / 1000.0 - 0.5;
        }
    }

    pub fn access(self: *MemoryEntry) void {
        self.access_count += 1;
        self.last_accessed = std.time.milliTimestamp();
        // Increase importance with access (bounded by φ)
        self.importance = @min(self.importance * 1.1, PHI);
    }

    pub fn decay(self: *MemoryEntry) void {
        const rate = self.memory_type.decayRate();
        self.importance *= rate;
    }

    pub fn relevanceScore(self: MemoryEntry, query_embedding: []const f32) f64 {
        // Cosine similarity
        var dot: f64 = 0;
        var norm_a: f64 = 0;
        var norm_b: f64 = 0;

        const len = @min(self.embedding.len, query_embedding.len);
        for (self.embedding[0..len], query_embedding[0..len]) |a, b| {
            dot += @as(f64, a) * @as(f64, b);
            norm_a += @as(f64, a) * @as(f64, a);
            norm_b += @as(f64, b) * @as(f64, b);
        }

        if (norm_a == 0 or norm_b == 0) return 0;
        const similarity = dot / (@sqrt(norm_a) * @sqrt(norm_b));

        // Combine with importance using φ weighting
        return similarity * PHI_INV + self.importance * (1 - PHI_INV);
    }
};

// ═══════════════════════════════════════════════════════════════
// MEMORY STORE
// ═══════════════════════════════════════════════════════════════

pub const MemoryStore = struct {
    allocator: Allocator,
    entries: std.AutoHashMap(u64, MemoryEntry),
    next_id: u64,
    total_accesses: u64,

    pub fn init(allocator: Allocator) MemoryStore {
        return .{
            .allocator = allocator,
            .entries = std.AutoHashMap(u64, MemoryEntry).init(allocator),
            .next_id = 1,
            .total_accesses = 0,
        };
    }

    pub fn deinit(self: *MemoryStore) void {
        self.entries.deinit();
    }

    pub fn add(self: *MemoryStore, content: []const u8, memory_type: MemoryType) !u64 {
        const id = self.next_id;
        self.next_id += 1;

        const entry = MemoryEntry.init(id, content, memory_type);
        try self.entries.put(id, entry);

        // Enforce capacity limits
        try self.enforceCapacity(memory_type);

        return id;
    }

    pub fn get(self: *MemoryStore, id: u64) ?*MemoryEntry {
        if (self.entries.getPtr(id)) |entry| {
            entry.access();
            self.total_accesses += 1;
            return entry;
        }
        return null;
    }

    pub fn remove(self: *MemoryStore, id: u64) bool {
        return self.entries.remove(id);
    }

    pub fn search(self: *MemoryStore, query: []const u8, max_results: usize) ![]u64 {
        // Compute query embedding
        var query_embedding: [64]f32 = undefined;
        var hash: u64 = 0;
        for (query) |c| {
            hash = hash *% 31 +% c;
        }
        for (&query_embedding, 0..) |*e, i| {
            const seed = hash +% i;
            e.* = @as(f32, @floatFromInt(seed % 1000)) / 1000.0 - 0.5;
        }

        // Score all entries
        var scored = std.ArrayList(struct { id: u64, score: f64 }).init(self.allocator);
        defer scored.deinit();

        var iter = self.entries.iterator();
        while (iter.next()) |kv| {
            const score = kv.value_ptr.relevanceScore(&query_embedding);
            try scored.append(.{ .id = kv.key_ptr.*, .score = score });
        }

        // Sort by score (descending)
        std.mem.sort(
            @TypeOf(scored.items[0]),
            scored.items,
            {},
            struct {
                fn lessThan(_: void, a: @TypeOf(scored.items[0]), b: @TypeOf(scored.items[0])) bool {
                    return a.score > b.score;
                }
            }.lessThan,
        );

        // Return top results
        const result_count = @min(max_results, scored.items.len);
        var results = try self.allocator.alloc(u64, result_count);
        for (scored.items[0..result_count], 0..) |item, i| {
            results[i] = item.id;
        }

        return results;
    }

    pub fn decayAll(self: *MemoryStore) void {
        var iter = self.entries.valueIterator();
        while (iter.next()) |entry| {
            entry.decay();
        }
    }

    fn enforceCapacity(self: *MemoryStore, memory_type: MemoryType) !void {
        const max = memory_type.maxCapacity();

        // Count entries of this type
        var type_count: usize = 0;
        var min_importance: f64 = 1000;
        var min_id: ?u64 = null;

        var iter = self.entries.iterator();
        while (iter.next()) |kv| {
            if (kv.value_ptr.memory_type == memory_type) {
                type_count += 1;
                if (kv.value_ptr.importance < min_importance) {
                    min_importance = kv.value_ptr.importance;
                    min_id = kv.key_ptr.*;
                }
            }
        }

        // Remove least important if over capacity
        if (type_count > max) {
            if (min_id) |id| {
                _ = self.entries.remove(id);
            }
        }
    }

    pub fn count(self: MemoryStore) usize {
        return self.entries.count();
    }

    pub fn countByType(self: *MemoryStore, memory_type: MemoryType) usize {
        var type_count: usize = 0;
        var iter = self.entries.valueIterator();
        while (iter.next()) |entry| {
            if (entry.memory_type == memory_type) {
                type_count += 1;
            }
        }
        return type_count;
    }
};

// ═══════════════════════════════════════════════════════════════
// MEMORY MANAGER
// ═══════════════════════════════════════════════════════════════

pub const MemoryManager = struct {
    allocator: Allocator,
    short_term: MemoryStore,
    working: MemoryStore,
    long_term: MemoryStore,
    episodic: MemoryStore,
    semantic: MemoryStore,

    pub fn init(allocator: Allocator) MemoryManager {
        return .{
            .allocator = allocator,
            .short_term = MemoryStore.init(allocator),
            .working = MemoryStore.init(allocator),
            .long_term = MemoryStore.init(allocator),
            .episodic = MemoryStore.init(allocator),
            .semantic = MemoryStore.init(allocator),
        };
    }

    pub fn deinit(self: *MemoryManager) void {
        self.short_term.deinit();
        self.working.deinit();
        self.long_term.deinit();
        self.episodic.deinit();
        self.semantic.deinit();
    }

    pub fn remember(self: *MemoryManager, content: []const u8, memory_type: MemoryType) !u64 {
        return switch (memory_type) {
            .ShortTerm => try self.short_term.add(content, memory_type),
            .Working => try self.working.add(content, memory_type),
            .LongTerm => try self.long_term.add(content, memory_type),
            .Episodic => try self.episodic.add(content, memory_type),
            .Semantic => try self.semantic.add(content, memory_type),
        };
    }

    pub fn recall(self: *MemoryManager, query: []const u8, max_results: usize) ![]u64 {
        // Search all stores and combine results
        var all_results = std.ArrayList(u64).init(self.allocator);
        defer all_results.deinit();

        // Search each store
        const stores = [_]*MemoryStore{
            &self.short_term,
            &self.working,
            &self.long_term,
            &self.episodic,
            &self.semantic,
        };

        for (stores) |store| {
            const results = try store.search(query, max_results);
            defer self.allocator.free(results);
            try all_results.appendSlice(results);
        }

        // Return combined (could dedupe and re-rank)
        const final_count = @min(max_results, all_results.items.len);
        return try self.allocator.dupe(u64, all_results.items[0..final_count]);
    }

    pub fn consolidate(self: *MemoryManager) !void {
        // Move important short-term memories to working memory
        var to_promote = std.ArrayList(u64).init(self.allocator);
        defer to_promote.deinit();

        var iter = self.short_term.entries.iterator();
        while (iter.next()) |kv| {
            if (kv.value_ptr.importance > 0.8) {
                try to_promote.append(kv.key_ptr.*);
            }
        }

        for (to_promote.items) |id| {
            if (self.short_term.entries.get(id)) |entry| {
                _ = try self.working.add(entry.getContent(), .Working);
                _ = self.short_term.remove(id);
            }
        }
    }

    pub fn tick(self: *MemoryManager) !void {
        // Decay all memories
        self.short_term.decayAll();
        self.working.decayAll();
        self.long_term.decayAll();
        self.episodic.decayAll();
        // Semantic doesn't decay

        // Consolidate
        try self.consolidate();
    }

    pub fn totalMemories(self: *MemoryManager) usize {
        return self.short_term.count() +
            self.working.count() +
            self.long_term.count() +
            self.episodic.count() +
            self.semantic.count();
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "memory entry init" {
    const entry = MemoryEntry.init(1, "Hello world", .ShortTerm);
    try testing.expect(entry.id == 1);
    try testing.expect(std.mem.eql(u8, entry.getContent(), "Hello world"));
}

test "memory entry access" {
    var entry = MemoryEntry.init(1, "Test", .ShortTerm);
    const initial_importance = entry.importance;

    entry.access();

    try testing.expect(entry.access_count == 1);
    try testing.expect(entry.importance > initial_importance);
}

test "memory entry decay" {
    var entry = MemoryEntry.init(1, "Test", .ShortTerm);
    entry.importance = 1.0;

    entry.decay();

    try testing.expect(entry.importance < 1.0);
}

test "memory store add" {
    var store = MemoryStore.init(testing.allocator);
    defer store.deinit();

    const id = try store.add("Test memory", .ShortTerm);
    try testing.expect(id == 1);
    try testing.expect(store.count() == 1);
}

test "memory store get" {
    var store = MemoryStore.init(testing.allocator);
    defer store.deinit();

    const id = try store.add("Test memory", .ShortTerm);
    const entry = store.get(id);

    try testing.expect(entry != null);
    try testing.expect(entry.?.access_count == 1);
}

test "memory store search" {
    var store = MemoryStore.init(testing.allocator);
    defer store.deinit();

    _ = try store.add("Hello world", .ShortTerm);
    _ = try store.add("Goodbye world", .ShortTerm);
    _ = try store.add("Hello there", .ShortTerm);

    const results = try store.search("Hello", 2);
    defer testing.allocator.free(results);

    try testing.expect(results.len <= 2);
}

test "memory manager init" {
    var manager = MemoryManager.init(testing.allocator);
    defer manager.deinit();

    try testing.expect(manager.totalMemories() == 0);
}

test "memory manager remember" {
    var manager = MemoryManager.init(testing.allocator);
    defer manager.deinit();

    _ = try manager.remember("Short term fact", .ShortTerm);
    _ = try manager.remember("Long term fact", .LongTerm);

    try testing.expect(manager.totalMemories() == 2);
}

test "memory manager recall" {
    var manager = MemoryManager.init(testing.allocator);
    defer manager.deinit();

    _ = try manager.remember("The sky is blue", .Semantic);
    _ = try manager.remember("Water is wet", .Semantic);

    const results = try manager.recall("sky", 5);
    defer testing.allocator.free(results);

    try testing.expect(results.len > 0);
}

test "memory type decay rates" {
    try testing.expect(MemoryType.ShortTerm.decayRate() < MemoryType.LongTerm.decayRate());
    try testing.expect(MemoryType.Semantic.decayRate() == 1.0);
}
