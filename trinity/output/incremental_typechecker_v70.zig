// VIBEE v70 Инкрементальный Type Checker
// Инкрементальная проверка типов для 5x ускорения
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === СВЯЩЕННЫЕ КОНСТАНТЫ ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const SPEEDUP_TARGET: f64 = 5.0;
pub const CACHE_HIT_TARGET: f64 = 0.85;

// === ВИДЫ ТИПОВ ===
pub const TypeKind = enum {
    primitive,
    @"struct",
    @"enum",
    @"union",
    array,
    slice,
    pointer,
    optional,
    function,
    generic,
    unknown,
};

// === ИНФОРМАЦИЯ О ТИПЕ ===
pub const TypeInfo = struct {
    id: u64,
    kind: TypeKind,
    name: []const u8,
    size_bytes: u32,
    alignment: u32,
    is_mutable: bool,
    hash: u64,
};

// === РЕЗУЛЬТАТ ПРОВЕРКИ ===
pub const TypeCheckResult = struct {
    success: bool,
    error_count: u32,
    warning_count: u32,
    checked_count: u32,
    cached_count: u32,
    check_time_ns: u64,

    pub fn getCacheHitRate(self: *const TypeCheckResult) f64 {
        const total = self.checked_count + self.cached_count;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.cached_count)) / @as(f64, @floatFromInt(total));
    }
};

// === УЗЕЛ ЗАВИСИМОСТИ ===
pub const DependencyNode = struct {
    file_path: []const u8,
    hash: u64,
    dependency_count: u32,
    dependent_count: u32,
    last_checked: i64,
    is_dirty: bool,
};

// === СТРАТЕГИЯ КЭШИРОВАНИЯ ===
pub const CacheStrategy = enum {
    lru,      // Least Recently Used
    lfu,      // Least Frequently Used
    adaptive, // Адаптивный выбор
};

// === ГРАНУЛЯРНОСТЬ ПРОВЕРКИ ===
pub const CheckGranularity = enum {
    file_level,
    function_level,
    expression_level,
};

// === КЭШ ТИПОВ ===
pub const TypeCache = struct {
    entries: u32,
    hits: u32,
    misses: u32,
    evictions: u32,
    memory_bytes: u64,
    strategy: CacheStrategy,

    pub fn init() TypeCache {
        return .{
            .entries = 0,
            .hits = 0,
            .misses = 0,
            .evictions = 0,
            .memory_bytes = 0,
            .strategy = .lru,
        };
    }

    pub fn recordHit(self: *TypeCache) void {
        self.hits += 1;
    }

    pub fn recordMiss(self: *TypeCache) void {
        self.misses += 1;
    }

    pub fn addEntry(self: *TypeCache, size: u32) void {
        self.entries += 1;
        self.memory_bytes += size;
    }

    pub fn evict(self: *TypeCache, size: u32) void {
        if (self.entries > 0) {
            self.entries -= 1;
            self.evictions += 1;
            if (self.memory_bytes >= size) {
                self.memory_bytes -= size;
            }
        }
    }

    pub fn getHitRate(self: *const TypeCache) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }

    pub fn clear(self: *TypeCache) void {
        self.entries = 0;
        self.hits = 0;
        self.misses = 0;
        self.evictions = 0;
        self.memory_bytes = 0;
    }
};

// === ИНКРЕМЕНТАЛЬНЫЙ TYPE CHECKER ===
pub const IncrementalTypeChecker = struct {
    cache: TypeCache,
    granularity: CheckGranularity,
    total_files: u32,
    dirty_files: u32,
    checked_files: u32,
    parallel_enabled: bool,

    pub fn init() IncrementalTypeChecker {
        return .{
            .cache = TypeCache.init(),
            .granularity = .file_level,
            .total_files = 0,
            .dirty_files = 0,
            .checked_files = 0,
            .parallel_enabled = true,
        };
    }

    pub fn setGranularity(self: *IncrementalTypeChecker, granularity: CheckGranularity) void {
        self.granularity = granularity;
    }

    pub fn markDirty(self: *IncrementalTypeChecker, count: u32) void {
        self.dirty_files += count;
    }

    pub fn setTotalFiles(self: *IncrementalTypeChecker, count: u32) void {
        self.total_files = count;
    }

    pub fn check(self: *IncrementalTypeChecker) TypeCheckResult {
        const start_time = std.time.nanoTimestamp();

        // Симуляция инкрементальной проверки
        const to_check = self.dirty_files;
        const from_cache = self.total_files - self.dirty_files;

        // Обновляем кэш
        for (0..from_cache) |_| {
            self.cache.recordHit();
        }
        for (0..to_check) |_| {
            self.cache.recordMiss();
            self.cache.addEntry(1024); // ~1KB на файл
        }

        self.checked_files = to_check;

        const end_time = std.time.nanoTimestamp();
        const duration: u64 = @intCast(end_time - start_time);

        return TypeCheckResult{
            .success = true,
            .error_count = 0,
            .warning_count = 0,
            .checked_count = to_check,
            .cached_count = from_cache,
            .check_time_ns = duration,
        };
    }

    pub fn getSpeedup(self: *const IncrementalTypeChecker) f64 {
        if (self.total_files == 0) return 1.0;
        const ratio = @as(f64, @floatFromInt(self.total_files)) / @as(f64, @floatFromInt(@max(self.dirty_files, 1)));
        return @min(ratio, SPEEDUP_TARGET);
    }

    pub fn invalidateDependents(self: *IncrementalTypeChecker, count: u32) void {
        self.dirty_files += count;
        // Инвалидируем записи в кэше
        for (0..count) |_| {
            self.cache.evict(1024);
        }
    }

    pub fn reset(self: *IncrementalTypeChecker) void {
        self.cache.clear();
        self.total_files = 0;
        self.dirty_files = 0;
        self.checked_files = 0;
    }
};

// === ГРАФ ЗАВИСИМОСТЕЙ ===
pub const DependencyGraph = struct {
    node_count: u32,
    edge_count: u32,
    dirty_count: u32,

    pub fn init() DependencyGraph {
        return .{
            .node_count = 0,
            .edge_count = 0,
            .dirty_count = 0,
        };
    }

    pub fn addNode(self: *DependencyGraph) void {
        self.node_count += 1;
    }

    pub fn addEdge(self: *DependencyGraph) void {
        self.edge_count += 1;
    }

    pub fn markDirty(self: *DependencyGraph, count: u32) void {
        self.dirty_count += count;
    }

    pub fn getDirtyRatio(self: *const DependencyGraph) f64 {
        if (self.node_count == 0) return 0;
        return @as(f64, @floatFromInt(self.dirty_count)) / @as(f64, @floatFromInt(self.node_count));
    }
};

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
pub fn calculateSpeedup(total: u32, checked: u32) f64 {
    if (checked == 0) return SPEEDUP_TARGET;
    return @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(checked));
}

pub fn meetsSpeedupTarget(speedup: f64) bool {
    return speedup >= SPEEDUP_TARGET * 0.8;
}

pub fn meetsCacheHitTarget(hit_rate: f64) bool {
    return hit_rate >= CACHE_HIT_TARGET;
}

// ============================================================
// ТЕСТЫ: СВЯЩЕННЫЕ КОНСТАНТЫ
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "SPEEDUP_TARGET" { try testing.expectApproxEqAbs(@as(f64, 5.0), SPEEDUP_TARGET, 0.01); }
test "CACHE_HIT_TARGET" { try testing.expectApproxEqAbs(@as(f64, 0.85), CACHE_HIT_TARGET, 0.01); }

// ============================================================
// ТЕСТЫ: ВИДЫ ТИПОВ
// ============================================================
test "type.primitive" { try testing.expect(TypeKind.primitive == .primitive); }
test "type.struct" { try testing.expect(TypeKind.@"struct" == .@"struct"); }
test "type.enum" { try testing.expect(TypeKind.@"enum" == .@"enum"); }
test "type.union" { try testing.expect(TypeKind.@"union" == .@"union"); }
test "type.array" { try testing.expect(TypeKind.array == .array); }
test "type.slice" { try testing.expect(TypeKind.slice == .slice); }
test "type.pointer" { try testing.expect(TypeKind.pointer == .pointer); }
test "type.optional" { try testing.expect(TypeKind.optional == .optional); }
test "type.function" { try testing.expect(TypeKind.function == .function); }
test "type.generic" { try testing.expect(TypeKind.generic == .generic); }
test "type.unknown" { try testing.expect(TypeKind.unknown == .unknown); }

// ============================================================
// ТЕСТЫ: СТРАТЕГИИ КЭШИРОВАНИЯ
// ============================================================
test "strategy.lru" { try testing.expect(CacheStrategy.lru == .lru); }
test "strategy.lfu" { try testing.expect(CacheStrategy.lfu == .lfu); }
test "strategy.adaptive" { try testing.expect(CacheStrategy.adaptive == .adaptive); }

// ============================================================
// ТЕСТЫ: ГРАНУЛЯРНОСТЬ
// ============================================================
test "granularity.file" { try testing.expect(CheckGranularity.file_level == .file_level); }
test "granularity.function" { try testing.expect(CheckGranularity.function_level == .function_level); }
test "granularity.expression" { try testing.expect(CheckGranularity.expression_level == .expression_level); }

// ============================================================
// ТЕСТЫ: КЭШ ТИПОВ
// ============================================================
test "cache.init" {
    const cache = TypeCache.init();
    try testing.expectEqual(@as(u32, 0), cache.entries);
    try testing.expectEqual(@as(u32, 0), cache.hits);
    try testing.expect(cache.strategy == .lru);
}

test "cache.hit" {
    var cache = TypeCache.init();
    cache.recordHit();
    cache.recordHit();
    try testing.expectEqual(@as(u32, 2), cache.hits);
}

test "cache.miss" {
    var cache = TypeCache.init();
    cache.recordMiss();
    try testing.expectEqual(@as(u32, 1), cache.misses);
}

test "cache.add_entry" {
    var cache = TypeCache.init();
    cache.addEntry(1024);
    try testing.expectEqual(@as(u32, 1), cache.entries);
    try testing.expectEqual(@as(u64, 1024), cache.memory_bytes);
}

test "cache.evict" {
    var cache = TypeCache.init();
    cache.addEntry(1024);
    cache.evict(1024);
    try testing.expectEqual(@as(u32, 0), cache.entries);
    try testing.expectEqual(@as(u32, 1), cache.evictions);
}

test "cache.hit_rate" {
    var cache = TypeCache.init();
    cache.recordHit();
    cache.recordHit();
    cache.recordHit();
    cache.recordMiss();
    try testing.expectApproxEqAbs(@as(f64, 0.75), cache.getHitRate(), 0.01);
}

test "cache.clear" {
    var cache = TypeCache.init();
    cache.addEntry(1024);
    cache.recordHit();
    cache.clear();
    try testing.expectEqual(@as(u32, 0), cache.entries);
    try testing.expectEqual(@as(u32, 0), cache.hits);
}

// ============================================================
// ТЕСТЫ: ИНКРЕМЕНТАЛЬНЫЙ TYPE CHECKER
// ============================================================
test "checker.init" {
    const checker = IncrementalTypeChecker.init();
    try testing.expectEqual(@as(u32, 0), checker.total_files);
    try testing.expect(checker.parallel_enabled);
    try testing.expect(checker.granularity == .file_level);
}

test "checker.set_granularity" {
    var checker = IncrementalTypeChecker.init();
    checker.setGranularity(.function_level);
    try testing.expect(checker.granularity == .function_level);
}

test "checker.mark_dirty" {
    var checker = IncrementalTypeChecker.init();
    checker.markDirty(5);
    try testing.expectEqual(@as(u32, 5), checker.dirty_files);
}

test "checker.set_total" {
    var checker = IncrementalTypeChecker.init();
    checker.setTotalFiles(100);
    try testing.expectEqual(@as(u32, 100), checker.total_files);
}

test "checker.check" {
    var checker = IncrementalTypeChecker.init();
    checker.setTotalFiles(100);
    checker.markDirty(10);
    const result = checker.check();
    try testing.expect(result.success);
    try testing.expectEqual(@as(u32, 10), result.checked_count);
    try testing.expectEqual(@as(u32, 90), result.cached_count);
}

test "checker.speedup" {
    var checker = IncrementalTypeChecker.init();
    checker.setTotalFiles(100);
    checker.markDirty(20);
    try testing.expectApproxEqAbs(@as(f64, 5.0), checker.getSpeedup(), 0.01);
}

test "checker.invalidate" {
    var checker = IncrementalTypeChecker.init();
    checker.setTotalFiles(100);
    checker.markDirty(10);
    _ = checker.check();
    checker.invalidateDependents(5);
    try testing.expectEqual(@as(u32, 15), checker.dirty_files);
}

test "checker.reset" {
    var checker = IncrementalTypeChecker.init();
    checker.setTotalFiles(100);
    checker.markDirty(10);
    checker.reset();
    try testing.expectEqual(@as(u32, 0), checker.total_files);
    try testing.expectEqual(@as(u32, 0), checker.dirty_files);
}

// ============================================================
// ТЕСТЫ: РЕЗУЛЬТАТ ПРОВЕРКИ
// ============================================================
test "result.cache_hit_rate" {
    const result = TypeCheckResult{
        .success = true,
        .error_count = 0,
        .warning_count = 0,
        .checked_count = 10,
        .cached_count = 90,
        .check_time_ns = 1000,
    };
    try testing.expectApproxEqAbs(@as(f64, 0.9), result.getCacheHitRate(), 0.01);
}

// ============================================================
// ТЕСТЫ: ГРАФ ЗАВИСИМОСТЕЙ
// ============================================================
test "graph.init" {
    const graph = DependencyGraph.init();
    try testing.expectEqual(@as(u32, 0), graph.node_count);
}

test "graph.add_node" {
    var graph = DependencyGraph.init();
    graph.addNode();
    graph.addNode();
    try testing.expectEqual(@as(u32, 2), graph.node_count);
}

test "graph.add_edge" {
    var graph = DependencyGraph.init();
    graph.addEdge();
    try testing.expectEqual(@as(u32, 1), graph.edge_count);
}

test "graph.dirty_ratio" {
    var graph = DependencyGraph.init();
    for (0..10) |_| graph.addNode();
    graph.markDirty(2);
    try testing.expectApproxEqAbs(@as(f64, 0.2), graph.getDirtyRatio(), 0.01);
}

// ============================================================
// ТЕСТЫ: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================================
test "speedup.calculation" {
    const speedup = calculateSpeedup(100, 20);
    try testing.expectApproxEqAbs(@as(f64, 5.0), speedup, 0.01);
}

test "speedup.meets_target" {
    try testing.expect(meetsSpeedupTarget(5.0));
    try testing.expect(meetsSpeedupTarget(4.0)); // 80% от 5.0
    try testing.expect(!meetsSpeedupTarget(3.0));
}

test "cache.meets_target" {
    try testing.expect(meetsCacheHitTarget(0.90));
    try testing.expect(meetsCacheHitTarget(0.85));
    try testing.expect(!meetsCacheHitTarget(0.80));
}
