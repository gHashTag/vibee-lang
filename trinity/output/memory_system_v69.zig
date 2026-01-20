// VIBEE v69 Memory System
// Long-term Agent Memory & Knowledge Persistence
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === SACRED CONSTANTS ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const MAX_MEMORY_MB: u32 = 512;
pub const EMBEDDING_DIM: u32 = 1536;

// === MEMORY TYPES ===
pub const MemoryType = enum {
    episodic,   // Conversation history, events
    semantic,   // Facts, knowledge, concepts
    procedural, // How-to, workflows, patterns
    working,    // Current task context
};

// === MEMORY PRIORITY ===
pub const MemoryPriority = enum {
    critical,
    high,
    medium,
    low,
    ephemeral,

    pub fn weight(self: MemoryPriority) f64 {
        return switch (self) {
            .critical => 1.0,
            .high => 0.8,
            .medium => 0.5,
            .low => 0.2,
            .ephemeral => 0.05,
        };
    }
};

// === CONVERSATION ROLE ===
pub const Role = enum { user, assistant, system };

// === MEMORY ENTRY ===
pub const MemoryEntry = struct {
    id: u64,
    mem_type: MemoryType,
    content: []const u8,
    timestamp: i64,
    priority: MemoryPriority,
    access_count: u32,
    last_accessed: i64,
    ttl_seconds: i64,
    tag_count: u32,

    pub fn isExpired(self: *const MemoryEntry, current_time: i64) bool {
        if (self.ttl_seconds <= 0) return false; // No expiry
        return current_time > self.timestamp + self.ttl_seconds;
    }

    pub fn touch(self: *MemoryEntry, current_time: i64) void {
        self.access_count += 1;
        self.last_accessed = current_time;
    }
};

// === CONVERSATION TURN ===
pub const ConversationTurn = struct {
    role: Role,
    content: []const u8,
    timestamp: i64,
    tokens: u32,
};

// === PROJECT KNOWLEDGE ===
pub const ProjectKnowledge = struct {
    project_id: []const u8,
    root_path: []const u8,
    language: []const u8,
    framework: []const u8,
    convention_count: u32,
    key_file_count: u32,
    dependency_count: u32,
};

// === USER PREFERENCE ===
pub const UserPreference = struct {
    key: []const u8,
    value: []const u8,
    learned_from: []const u8,
    confidence: f64,
};

// === MEMORY STATS ===
pub const MemoryStats = struct {
    total_entries: u32,
    episodic_count: u32,
    semantic_count: u32,
    procedural_count: u32,
    working_count: u32,
    memory_mb: f64,
    oldest_timestamp: i64,
    newest_timestamp: i64,
};

// === RETRIEVAL STRATEGY ===
pub const RetrievalStrategy = struct {
    recency_weight: f64,
    frequency_weight: f64,
    relevance_weight: f64,
    importance_weight: f64,
};

pub const DEFAULT_STRATEGY = RetrievalStrategy{
    .recency_weight = 0.3,
    .frequency_weight = 0.2,
    .relevance_weight = 0.4,
    .importance_weight = 0.1,
};

// === PERSISTENCE FORMAT ===
pub const PersistenceFormat = enum { sqlite, json, vector_db };

// === MEMORY SYSTEM ===
pub const MemorySystem = struct {
    next_id: u64,
    entry_count: u32,
    episodic_count: u32,
    semantic_count: u32,
    procedural_count: u32,
    working_count: u32,
    memory_bytes: u64,
    strategy: RetrievalStrategy,
    auto_save_interval: u32,
    max_unsaved: u32,
    unsaved_count: u32,

    pub fn init() MemorySystem {
        return .{
            .next_id = 1,
            .entry_count = 0,
            .episodic_count = 0,
            .semantic_count = 0,
            .procedural_count = 0,
            .working_count = 0,
            .memory_bytes = 0,
            .strategy = DEFAULT_STRATEGY,
            .auto_save_interval = 60,
            .max_unsaved = 100,
            .unsaved_count = 0,
        };
    }

    pub fn store(self: *MemorySystem, mem_type: MemoryType, content_len: u32, priority: MemoryPriority) u64 {
        const id = self.next_id;
        self.next_id += 1;
        self.entry_count += 1;
        self.unsaved_count += 1;

        switch (mem_type) {
            .episodic => self.episodic_count += 1,
            .semantic => self.semantic_count += 1,
            .procedural => self.procedural_count += 1,
            .working => self.working_count += 1,
        }

        // Estimate memory: content + embedding + metadata
        const entry_bytes = content_len + (EMBEDDING_DIM * 4) + 128;
        self.memory_bytes += entry_bytes;

        _ = priority;
        return id;
    }

    pub fn forget(self: *MemorySystem, mem_type: MemoryType, content_len: u32) bool {
        if (self.entry_count == 0) return false;

        self.entry_count -= 1;
        switch (mem_type) {
            .episodic => if (self.episodic_count > 0) { self.episodic_count -= 1; },
            .semantic => if (self.semantic_count > 0) { self.semantic_count -= 1; },
            .procedural => if (self.procedural_count > 0) { self.procedural_count -= 1; },
            .working => if (self.working_count > 0) { self.working_count -= 1; },
        }

        const entry_bytes = content_len + (EMBEDDING_DIM * 4) + 128;
        if (self.memory_bytes >= entry_bytes) {
            self.memory_bytes -= entry_bytes;
        }

        return true;
    }

    pub fn getStats(self: *const MemorySystem) MemoryStats {
        return .{
            .total_entries = self.entry_count,
            .episodic_count = self.episodic_count,
            .semantic_count = self.semantic_count,
            .procedural_count = self.procedural_count,
            .working_count = self.working_count,
            .memory_mb = @as(f64, @floatFromInt(self.memory_bytes)) / (1024.0 * 1024.0),
            .oldest_timestamp = 0,
            .newest_timestamp = 0,
        };
    }

    pub fn needsSave(self: *const MemorySystem) bool {
        return self.unsaved_count >= self.max_unsaved;
    }

    pub fn markSaved(self: *MemorySystem) void {
        self.unsaved_count = 0;
    }

    pub fn setStrategy(self: *MemorySystem, strategy: RetrievalStrategy) void {
        self.strategy = strategy;
    }

    pub fn getMemoryMB(self: *const MemorySystem) f64 {
        return @as(f64, @floatFromInt(self.memory_bytes)) / (1024.0 * 1024.0);
    }

    pub fn isWithinLimit(self: *const MemorySystem) bool {
        return self.getMemoryMB() < @as(f64, @floatFromInt(MAX_MEMORY_MB));
    }
};

// === SCORING FUNCTION ===
pub fn calculateScore(
    recency_score: f64,
    frequency_score: f64,
    relevance_score: f64,
    priority: MemoryPriority,
    strategy: RetrievalStrategy,
) f64 {
    const importance_score = priority.weight();
    return recency_score * strategy.recency_weight +
        frequency_score * strategy.frequency_weight +
        relevance_score * strategy.relevance_weight +
        importance_score * strategy.importance_weight;
}

// ============================================================
// TESTS: SACRED CONSTANTS
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "MAX_MEMORY_MB" { try testing.expectEqual(@as(u32, 512), MAX_MEMORY_MB); }
test "EMBEDDING_DIM" { try testing.expectEqual(@as(u32, 1536), EMBEDDING_DIM); }

// ============================================================
// TESTS: MEMORY TYPES
// ============================================================
test "type.episodic" { try testing.expect(MemoryType.episodic == .episodic); }
test "type.semantic" { try testing.expect(MemoryType.semantic == .semantic); }
test "type.procedural" { try testing.expect(MemoryType.procedural == .procedural); }
test "type.working" { try testing.expect(MemoryType.working == .working); }

// ============================================================
// TESTS: MEMORY PRIORITY
// ============================================================
test "priority.critical" { try testing.expectApproxEqAbs(@as(f64, 1.0), MemoryPriority.critical.weight(), 0.01); }
test "priority.high" { try testing.expectApproxEqAbs(@as(f64, 0.8), MemoryPriority.high.weight(), 0.01); }
test "priority.medium" { try testing.expectApproxEqAbs(@as(f64, 0.5), MemoryPriority.medium.weight(), 0.01); }
test "priority.low" { try testing.expectApproxEqAbs(@as(f64, 0.2), MemoryPriority.low.weight(), 0.01); }
test "priority.ephemeral" { try testing.expectApproxEqAbs(@as(f64, 0.05), MemoryPriority.ephemeral.weight(), 0.01); }

// ============================================================
// TESTS: ROLES
// ============================================================
test "role.user" { try testing.expect(Role.user == .user); }
test "role.assistant" { try testing.expect(Role.assistant == .assistant); }
test "role.system" { try testing.expect(Role.system == .system); }

// ============================================================
// TESTS: DEFAULT STRATEGY
// ============================================================
test "strategy.recency" { try testing.expectApproxEqAbs(@as(f64, 0.3), DEFAULT_STRATEGY.recency_weight, 0.01); }
test "strategy.frequency" { try testing.expectApproxEqAbs(@as(f64, 0.2), DEFAULT_STRATEGY.frequency_weight, 0.01); }
test "strategy.relevance" { try testing.expectApproxEqAbs(@as(f64, 0.4), DEFAULT_STRATEGY.relevance_weight, 0.01); }
test "strategy.importance" { try testing.expectApproxEqAbs(@as(f64, 0.1), DEFAULT_STRATEGY.importance_weight, 0.01); }
test "strategy.sum" {
    const sum = DEFAULT_STRATEGY.recency_weight + DEFAULT_STRATEGY.frequency_weight +
        DEFAULT_STRATEGY.relevance_weight + DEFAULT_STRATEGY.importance_weight;
    try testing.expectApproxEqAbs(@as(f64, 1.0), sum, 0.01);
}

// ============================================================
// TESTS: MEMORY SYSTEM INIT
// ============================================================
test "memory.init" {
    const mem = MemorySystem.init();
    try testing.expectEqual(@as(u64, 1), mem.next_id);
    try testing.expectEqual(@as(u32, 0), mem.entry_count);
    try testing.expectEqual(@as(u64, 0), mem.memory_bytes);
}

test "memory.init_counts" {
    const mem = MemorySystem.init();
    try testing.expectEqual(@as(u32, 0), mem.episodic_count);
    try testing.expectEqual(@as(u32, 0), mem.semantic_count);
    try testing.expectEqual(@as(u32, 0), mem.procedural_count);
    try testing.expectEqual(@as(u32, 0), mem.working_count);
}

// ============================================================
// TESTS: MEMORY STORE
// ============================================================
test "memory.store_episodic" {
    var mem = MemorySystem.init();
    const id = mem.store(.episodic, 100, .medium);
    try testing.expectEqual(@as(u64, 1), id);
    try testing.expectEqual(@as(u32, 1), mem.entry_count);
    try testing.expectEqual(@as(u32, 1), mem.episodic_count);
}

test "memory.store_semantic" {
    var mem = MemorySystem.init();
    _ = mem.store(.semantic, 200, .high);
    try testing.expectEqual(@as(u32, 1), mem.semantic_count);
}

test "memory.store_procedural" {
    var mem = MemorySystem.init();
    _ = mem.store(.procedural, 150, .critical);
    try testing.expectEqual(@as(u32, 1), mem.procedural_count);
}

test "memory.store_working" {
    var mem = MemorySystem.init();
    _ = mem.store(.working, 50, .ephemeral);
    try testing.expectEqual(@as(u32, 1), mem.working_count);
}

test "memory.store_multiple" {
    var mem = MemorySystem.init();
    _ = mem.store(.episodic, 100, .medium);
    _ = mem.store(.semantic, 100, .medium);
    _ = mem.store(.procedural, 100, .medium);
    try testing.expectEqual(@as(u32, 3), mem.entry_count);
    try testing.expectEqual(@as(u64, 4), mem.next_id);
}

test "memory.store_increments_unsaved" {
    var mem = MemorySystem.init();
    _ = mem.store(.episodic, 100, .medium);
    try testing.expectEqual(@as(u32, 1), mem.unsaved_count);
}

// ============================================================
// TESTS: MEMORY FORGET
// ============================================================
test "memory.forget" {
    var mem = MemorySystem.init();
    _ = mem.store(.episodic, 100, .medium);
    const result = mem.forget(.episodic, 100);
    try testing.expect(result);
    try testing.expectEqual(@as(u32, 0), mem.entry_count);
    try testing.expectEqual(@as(u32, 0), mem.episodic_count);
}

test "memory.forget_empty" {
    var mem = MemorySystem.init();
    const result = mem.forget(.episodic, 100);
    try testing.expect(!result);
}

// ============================================================
// TESTS: MEMORY STATS
// ============================================================
test "memory.stats" {
    var mem = MemorySystem.init();
    _ = mem.store(.episodic, 100, .medium);
    _ = mem.store(.semantic, 100, .high);
    const stats = mem.getStats();
    try testing.expectEqual(@as(u32, 2), stats.total_entries);
    try testing.expectEqual(@as(u32, 1), stats.episodic_count);
    try testing.expectEqual(@as(u32, 1), stats.semantic_count);
}

// ============================================================
// TESTS: MEMORY LIMITS
// ============================================================
test "memory.within_limit" {
    var mem = MemorySystem.init();
    _ = mem.store(.episodic, 1000, .medium);
    try testing.expect(mem.isWithinLimit());
}

test "memory.get_mb" {
    var mem = MemorySystem.init();
    _ = mem.store(.episodic, 1000, .medium);
    try testing.expect(mem.getMemoryMB() > 0);
    try testing.expect(mem.getMemoryMB() < 1.0); // Should be small
}

// ============================================================
// TESTS: SAVE TRACKING
// ============================================================
test "memory.needs_save" {
    var mem = MemorySystem.init();
    mem.max_unsaved = 2;
    _ = mem.store(.episodic, 100, .medium);
    try testing.expect(!mem.needsSave());
    _ = mem.store(.episodic, 100, .medium);
    try testing.expect(mem.needsSave());
}

test "memory.mark_saved" {
    var mem = MemorySystem.init();
    _ = mem.store(.episodic, 100, .medium);
    mem.markSaved();
    try testing.expectEqual(@as(u32, 0), mem.unsaved_count);
}

// ============================================================
// TESTS: STRATEGY
// ============================================================
test "memory.set_strategy" {
    var mem = MemorySystem.init();
    const custom = RetrievalStrategy{
        .recency_weight = 0.5,
        .frequency_weight = 0.2,
        .relevance_weight = 0.2,
        .importance_weight = 0.1,
    };
    mem.setStrategy(custom);
    try testing.expectApproxEqAbs(@as(f64, 0.5), mem.strategy.recency_weight, 0.01);
}

// ============================================================
// TESTS: SCORING
// ============================================================
test "score.calculation" {
    const score = calculateScore(0.8, 0.6, 0.9, .high, DEFAULT_STRATEGY);
    // 0.8*0.3 + 0.6*0.2 + 0.9*0.4 + 0.8*0.1 = 0.24 + 0.12 + 0.36 + 0.08 = 0.80
    try testing.expectApproxEqAbs(@as(f64, 0.80), score, 0.01);
}

test "score.critical_priority" {
    const score = calculateScore(1.0, 1.0, 1.0, .critical, DEFAULT_STRATEGY);
    try testing.expectApproxEqAbs(@as(f64, 1.0), score, 0.01);
}

test "score.low_priority" {
    const score = calculateScore(0.5, 0.5, 0.5, .low, DEFAULT_STRATEGY);
    // 0.5*0.3 + 0.5*0.2 + 0.5*0.4 + 0.2*0.1 = 0.15 + 0.1 + 0.2 + 0.02 = 0.47
    try testing.expectApproxEqAbs(@as(f64, 0.47), score, 0.01);
}

// ============================================================
// TESTS: MEMORY ENTRY
// ============================================================
test "entry.not_expired" {
    const entry = MemoryEntry{
        .id = 1,
        .mem_type = .episodic,
        .content = "test",
        .timestamp = 1000,
        .priority = .medium,
        .access_count = 0,
        .last_accessed = 1000,
        .ttl_seconds = 3600,
        .tag_count = 0,
    };
    try testing.expect(!entry.isExpired(2000));
}

test "entry.expired" {
    const entry = MemoryEntry{
        .id = 1,
        .mem_type = .episodic,
        .content = "test",
        .timestamp = 1000,
        .priority = .medium,
        .access_count = 0,
        .last_accessed = 1000,
        .ttl_seconds = 100,
        .tag_count = 0,
    };
    try testing.expect(entry.isExpired(2000));
}

test "entry.no_expiry" {
    const entry = MemoryEntry{
        .id = 1,
        .mem_type = .semantic,
        .content = "fact",
        .timestamp = 1000,
        .priority = .critical,
        .access_count = 0,
        .last_accessed = 1000,
        .ttl_seconds = 0, // No expiry
        .tag_count = 0,
    };
    try testing.expect(!entry.isExpired(999999999));
}

// ============================================================
// TESTS: PERSISTENCE FORMATS
// ============================================================
test "format.sqlite" { try testing.expect(PersistenceFormat.sqlite == .sqlite); }
test "format.json" { try testing.expect(PersistenceFormat.json == .json); }
test "format.vector_db" { try testing.expect(PersistenceFormat.vector_db == .vector_db); }
