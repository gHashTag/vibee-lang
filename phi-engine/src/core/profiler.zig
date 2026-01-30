//! VIBEE Profiler - PAS DAEMON V38
//! 
//! Паттерны: HSH (O(1) lookup), PRE (precomputed stats), D&C (hierarchical aggregation)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// СВЯЩЕННЫЕ КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3

// ═══════════════════════════════════════════════════════════════════════════════
// TIMING STRUCTURES - PRE Pattern (precomputed statistics)
// ═══════════════════════════════════════════════════════════════════════════════

/// Timing sample with nanosecond precision
pub const TimingSample = struct {
    start_ns: i128,
    end_ns: i128,
    duration_ns: u64,
    
    pub fn init(start: i128, end: i128) TimingSample {
        const dur: u64 = if (end > start) @intCast(@as(u128, @bitCast(end - start))) else 0;
        return .{
            .start_ns = start,
            .end_ns = end,
            .duration_ns = dur,
        };
    }
};

/// Precomputed statistics for a function/region - PRE pattern
pub const ProfileStats = struct {
    call_count: u64 = 0,
    total_time_ns: u64 = 0,
    min_time_ns: u64 = std.math.maxInt(u64),
    max_time_ns: u64 = 0,
    // Precomputed for O(1) access
    mean_time_ns: u64 = 0,
    // For variance calculation (Welford's algorithm)
    m2: f64 = 0.0,
    
    /// Update stats with new sample - O(1) amortized
    pub fn addSample(self: *ProfileStats, duration_ns: u64) void {
        self.call_count += 1;
        self.total_time_ns += duration_ns;
        
        if (duration_ns < self.min_time_ns) {
            self.min_time_ns = duration_ns;
        }
        if (duration_ns > self.max_time_ns) {
            self.max_time_ns = duration_ns;
        }
        
        // Precompute mean (PRE pattern)
        self.mean_time_ns = self.total_time_ns / self.call_count;
        
        // Welford's online variance algorithm
        const delta: f64 = @as(f64, @floatFromInt(duration_ns)) - @as(f64, @floatFromInt(self.mean_time_ns));
        self.m2 += delta * delta;
    }
    
    /// Get standard deviation - O(1) due to precomputation
    pub fn getStdDev(self: *const ProfileStats) f64 {
        if (self.call_count < 2) return 0.0;
        const variance = self.m2 / @as(f64, @floatFromInt(self.call_count - 1));
        return @sqrt(variance);
    }
    
    /// Get percentage of total time
    pub fn getPercentage(self: *const ProfileStats, total: u64) f64 {
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_time_ns)) / @as(f64, @floatFromInt(total)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALL STACK TRACKING - D&C Pattern (hierarchical decomposition)
// ═══════════════════════════════════════════════════════════════════════════════

/// Call frame for stack tracking
pub const CallFrame = struct {
    function_id: u32,
    start_time_ns: i128,
    parent_index: ?usize,
    children_time_ns: u64 = 0, // Time spent in children (for self-time calculation)
};

/// Call tree node for hierarchical profiling - D&C pattern
pub const CallTreeNode = struct {
    function_id: u32,
    call_count: u64 = 0,
    total_time_ns: u64 = 0,
    self_time_ns: u64 = 0, // Exclusive time (total - children)
    children: ArrayList(u32),
    
    pub fn init(allocator: Allocator, func_id: u32) CallTreeNode {
        return .{
            .function_id = func_id,
            .children = ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *CallTreeNode) void {
        self.children.deinit();
    }
    
    pub fn addChild(self: *CallTreeNode, child_id: u32) !void {
        // Check if already exists
        for (self.children.items) |c| {
            if (c == child_id) return;
        }
        try self.children.append(child_id);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY PROFILING
// ═══════════════════════════════════════════════════════════════════════════════

/// Memory allocation record
pub const AllocationRecord = struct {
    address: usize,
    size: usize,
    timestamp_ns: i128,
    function_id: u32,
    freed: bool = false,
};

/// Memory statistics
pub const MemoryStats = struct {
    total_allocated: usize = 0,
    total_freed: usize = 0,
    peak_usage: usize = 0,
    current_usage: usize = 0,
    allocation_count: u64 = 0,
    free_count: u64 = 0,
    
    pub fn recordAllocation(self: *MemoryStats, size: usize) void {
        self.total_allocated += size;
        self.current_usage += size;
        self.allocation_count += 1;
        if (self.current_usage > self.peak_usage) {
            self.peak_usage = self.current_usage;
        }
    }
    
    pub fn recordFree(self: *MemoryStats, size: usize) void {
        self.total_freed += size;
        if (self.current_usage >= size) {
            self.current_usage -= size;
        }
        self.free_count += 1;
    }
    
    /// Detect potential memory leaks
    pub fn getLeakedBytes(self: *const MemoryStats) usize {
        return self.current_usage;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION REGISTRY - HSH Pattern (O(1) lookup)
// ═══════════════════════════════════════════════════════════════════════════════

/// Function metadata
pub const FunctionInfo = struct {
    id: u32,
    name: []const u8,
    file: []const u8,
    line: u32,
    
    pub fn init(id: u32, name: []const u8, file: []const u8, line: u32) FunctionInfo {
        return .{
            .id = id,
            .name = name,
            .file = file,
            .line = line,
        };
    }
};

/// Function registry with HSH pattern for O(1) lookup
pub const FunctionRegistry = struct {
    allocator: Allocator,
    // HSH: name -> id mapping
    name_to_id: StringHashMap(u32),
    // HSH: id -> info mapping
    id_to_info: AutoHashMap(u32, FunctionInfo),
    next_id: u32 = 0,
    
    pub fn init(allocator: Allocator) FunctionRegistry {
        return .{
            .allocator = allocator,
            .name_to_id = StringHashMap(u32).init(allocator),
            .id_to_info = AutoHashMap(u32, FunctionInfo).init(allocator),
        };
    }
    
    pub fn deinit(self: *FunctionRegistry) void {
        self.name_to_id.deinit();
        self.id_to_info.deinit();
    }
    
    /// Register function - O(1) amortized
    pub fn register(self: *FunctionRegistry, name: []const u8, file: []const u8, line: u32) !u32 {
        if (self.name_to_id.get(name)) |existing_id| {
            return existing_id;
        }
        
        const id = self.next_id;
        self.next_id += 1;
        
        try self.name_to_id.put(name, id);
        try self.id_to_info.put(id, FunctionInfo.init(id, name, file, line));
        
        return id;
    }
    
    /// Lookup by name - O(1)
    pub fn getByName(self: *const FunctionRegistry, name: []const u8) ?u32 {
        return self.name_to_id.get(name);
    }
    
    /// Lookup by id - O(1)
    pub fn getById(self: *const FunctionRegistry, id: u32) ?FunctionInfo {
        return self.id_to_info.get(id);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN PROFILER - Integration of all patterns
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProfilerConfig = struct {
    enable_memory_profiling: bool = true,
    enable_call_tree: bool = true,
    sample_rate: u32 = 1, // 1 = every call, N = every Nth call
    max_call_depth: u32 = 256,
    max_samples_per_function: u32 = 10000,
};

pub const Profiler = struct {
    allocator: Allocator,
    config: ProfilerConfig,
    
    // Function registry (HSH pattern)
    registry: FunctionRegistry,
    
    // Per-function statistics (HSH + PRE patterns)
    function_stats: AutoHashMap(u32, ProfileStats),
    
    // Call stack for hierarchical profiling (D&C pattern)
    call_stack: ArrayList(CallFrame),
    
    // Call tree nodes (D&C pattern)
    call_tree: AutoHashMap(u32, CallTreeNode),
    
    // Memory profiling
    memory_stats: MemoryStats,
    allocations: AutoHashMap(usize, AllocationRecord),
    
    // Global metrics
    total_time_ns: u64 = 0,
    profiling_overhead_ns: u64 = 0,
    sample_count: u64 = 0,
    
    // State
    is_active: bool = false,
    start_time_ns: i128 = 0,
    
    pub fn init(allocator: Allocator, config: ProfilerConfig) Profiler {
        return .{
            .allocator = allocator,
            .config = config,
            .registry = FunctionRegistry.init(allocator),
            .function_stats = AutoHashMap(u32, ProfileStats).init(allocator),
            .call_stack = ArrayList(CallFrame).init(allocator),
            .call_tree = AutoHashMap(u32, CallTreeNode).init(allocator),
            .memory_stats = MemoryStats{},
            .allocations = AutoHashMap(usize, AllocationRecord).init(allocator),
        };
    }
    
    pub fn deinit(self: *Profiler) void {
        self.registry.deinit();
        self.function_stats.deinit();
        self.call_stack.deinit();
        
        var tree_iter = self.call_tree.valueIterator();
        while (tree_iter.next()) |node| {
            var mutable_node = node;
            mutable_node.deinit();
        }
        self.call_tree.deinit();
        
        self.allocations.deinit();
    }
    
    /// Start profiling session
    pub fn start(self: *Profiler) void {
        self.is_active = true;
        self.start_time_ns = std.time.nanoTimestamp();
    }
    
    /// Stop profiling session
    pub fn stop(self: *Profiler) void {
        if (self.is_active) {
            const end_time = std.time.nanoTimestamp();
            if (end_time > self.start_time_ns) {
                self.total_time_ns = @intCast(@as(u128, @bitCast(end_time - self.start_time_ns)));
            }
            self.is_active = false;
        }
    }
    
    /// Enter function - call at function entry
    pub fn enterFunction(self: *Profiler, function_id: u32) !void {
        if (!self.is_active) return;
        if (self.call_stack.items.len >= self.config.max_call_depth) return;
        
        const now = std.time.nanoTimestamp();
        const parent_index: ?usize = if (self.call_stack.items.len > 0) 
            self.call_stack.items.len - 1 
        else 
            null;
        
        try self.call_stack.append(.{
            .function_id = function_id,
            .start_time_ns = now,
            .parent_index = parent_index,
        });
        
        // Ensure call tree node exists
        if (!self.call_tree.contains(function_id)) {
            try self.call_tree.put(function_id, CallTreeNode.init(self.allocator, function_id));
        }
        
        // Update parent's children in call tree
        if (parent_index) |pi| {
            const parent_func_id = self.call_stack.items[pi].function_id;
            if (self.call_tree.getPtr(parent_func_id)) |parent_node| {
                try parent_node.addChild(function_id);
            }
        }
    }
    
    /// Exit function - call at function exit
    pub fn exitFunction(self: *Profiler, function_id: u32) void {
        if (!self.is_active) return;
        if (self.call_stack.items.len == 0) return;
        
        const frame = self.call_stack.pop();
        if (frame.function_id != function_id) {
            // Mismatched enter/exit - stack corruption
            return;
        }
        
        const now = std.time.nanoTimestamp();
        const duration: u64 = if (now > frame.start_time_ns) 
            @intCast(@as(u128, @bitCast(now - frame.start_time_ns))) 
        else 
            0;
        
        // Update function stats (PRE pattern - precomputed)
        const stats_ptr = self.function_stats.getPtr(function_id);
        if (stats_ptr) |stats| {
            stats.addSample(duration);
        } else {
            var new_stats = ProfileStats{};
            new_stats.addSample(duration);
            self.function_stats.put(function_id, new_stats) catch {};
        }
        
        // Update call tree node
        if (self.call_tree.getPtr(function_id)) |node| {
            node.call_count += 1;
            node.total_time_ns += duration;
            node.self_time_ns += duration - frame.children_time_ns;
        }
        
        // Update parent's children time
        if (frame.parent_index) |pi| {
            if (pi < self.call_stack.items.len) {
                self.call_stack.items[pi].children_time_ns += duration;
            }
        }
        
        self.sample_count += 1;
    }
    
    /// Record memory allocation
    pub fn recordAllocation(self: *Profiler, address: usize, size: usize) !void {
        if (!self.is_active or !self.config.enable_memory_profiling) return;
        
        const current_func: u32 = if (self.call_stack.items.len > 0)
            self.call_stack.items[self.call_stack.items.len - 1].function_id
        else
            0;
        
        try self.allocations.put(address, .{
            .address = address,
            .size = size,
            .timestamp_ns = std.time.nanoTimestamp(),
            .function_id = current_func,
        });
        
        self.memory_stats.recordAllocation(size);
    }
    
    /// Record memory free
    pub fn recordFree(self: *Profiler, address: usize) void {
        if (!self.is_active or !self.config.enable_memory_profiling) return;
        
        if (self.allocations.getPtr(address)) |record| {
            self.memory_stats.recordFree(record.size);
            record.freed = true;
        }
    }
    
    /// Get stats for a function - O(1) lookup (HSH pattern)
    pub fn getFunctionStats(self: *const Profiler, function_id: u32) ?ProfileStats {
        return self.function_stats.get(function_id);
    }
    
    /// Get hottest functions (sorted by total time)
    pub fn getHotFunctions(self: *const Profiler, limit: usize) ![]const u32 {
        var entries = ArrayList(struct { id: u32, time: u64 }).init(self.allocator);
        defer entries.deinit();
        
        var iter = self.function_stats.iterator();
        while (iter.next()) |entry| {
            try entries.append(.{ .id = entry.key_ptr.*, .time = entry.value_ptr.total_time_ns });
        }
        
        // Sort by time descending
        std.mem.sort(
            struct { id: u32, time: u64 },
            entries.items,
            {},
            struct {
                fn lessThan(_: void, a: struct { id: u32, time: u64 }, b: struct { id: u32, time: u64 }) bool {
                    return a.time > b.time;
                }
            }.lessThan,
        );
        
        const result_len = @min(limit, entries.items.len);
        var result = try self.allocator.alloc(u32, result_len);
        for (0..result_len) |i| {
            result[i] = entries.items[i].id;
        }
        
        return result;
    }
    
    /// Get memory statistics
    pub fn getMemoryStats(self: *const Profiler) MemoryStats {
        return self.memory_stats;
    }
    
    /// Generate profile report
    pub fn generateReport(self: *const Profiler) ProfileReport {
        return ProfileReport{
            .total_time_ns = self.total_time_ns,
            .sample_count = self.sample_count,
            .function_count = self.function_stats.count(),
            .memory_stats = self.memory_stats,
            .overhead_ns = self.profiling_overhead_ns,
        };
    }
};

/// Profile report summary
pub const ProfileReport = struct {
    total_time_ns: u64,
    sample_count: u64,
    function_count: u32,
    memory_stats: MemoryStats,
    overhead_ns: u64,
    
    pub fn getTotalTimeMs(self: *const ProfileReport) f64 {
        return @as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000.0;
    }
    
    pub fn getOverheadPercent(self: *const ProfileReport) f64 {
        if (self.total_time_ns == 0) return 0.0;
        return @as(f64, @floatFromInt(self.overhead_ns)) / @as(f64, @floatFromInt(self.total_time_ns)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SAMPLING PROFILER - Statistical profiling with lower overhead
// ═══════════════════════════════════════════════════════════════════════════════

pub const SamplingProfiler = struct {
    allocator: Allocator,
    sample_interval_ns: u64,
    samples: AutoHashMap(u32, u64), // function_id -> sample count
    total_samples: u64 = 0,
    is_active: bool = false,
    
    pub fn init(allocator: Allocator, sample_interval_ms: u32) SamplingProfiler {
        return .{
            .allocator = allocator,
            .sample_interval_ns = @as(u64, sample_interval_ms) * 1_000_000,
            .samples = AutoHashMap(u32, u64).init(allocator),
        };
    }
    
    pub fn deinit(self: *SamplingProfiler) void {
        self.samples.deinit();
    }
    
    pub fn start(self: *SamplingProfiler) void {
        self.is_active = true;
    }
    
    pub fn stop(self: *SamplingProfiler) void {
        self.is_active = false;
    }
    
    /// Record a sample at current location
    pub fn recordSample(self: *SamplingProfiler, function_id: u32) !void {
        if (!self.is_active) return;
        
        const current = self.samples.get(function_id) orelse 0;
        try self.samples.put(function_id, current + 1);
        self.total_samples += 1;
    }
    
    /// Get percentage of samples for a function
    pub fn getSamplePercentage(self: *const SamplingProfiler, function_id: u32) f64 {
        if (self.total_samples == 0) return 0.0;
        const count = self.samples.get(function_id) orelse 0;
        return @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(self.total_samples)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ProfileStats basic" {
    var stats = ProfileStats{};
    
    stats.addSample(100);
    stats.addSample(200);
    stats.addSample(300);
    
    try std.testing.expectEqual(@as(u64, 3), stats.call_count);
    try std.testing.expectEqual(@as(u64, 600), stats.total_time_ns);
    try std.testing.expectEqual(@as(u64, 100), stats.min_time_ns);
    try std.testing.expectEqual(@as(u64, 300), stats.max_time_ns);
    try std.testing.expectEqual(@as(u64, 200), stats.mean_time_ns);
}

test "FunctionRegistry HSH pattern" {
    const allocator = std.testing.allocator;
    var registry = FunctionRegistry.init(allocator);
    defer registry.deinit();
    
    const id1 = try registry.register("main", "main.vibee", 1);
    const id2 = try registry.register("helper", "utils.vibee", 10);
    const id3 = try registry.register("main", "main.vibee", 1); // Duplicate
    
    // HSH: O(1) lookup
    try std.testing.expectEqual(id1, id3); // Same function returns same ID
    try std.testing.expect(id1 != id2);
    
    // Lookup by name - O(1)
    try std.testing.expectEqual(id1, registry.getByName("main").?);
    try std.testing.expectEqual(id2, registry.getByName("helper").?);
    
    // Lookup by id - O(1)
    const info = registry.getById(id1).?;
    try std.testing.expectEqualStrings("main", info.name);
}

test "MemoryStats tracking" {
    var stats = MemoryStats{};
    
    stats.recordAllocation(1024);
    stats.recordAllocation(2048);
    
    try std.testing.expectEqual(@as(usize, 3072), stats.total_allocated);
    try std.testing.expectEqual(@as(usize, 3072), stats.current_usage);
    try std.testing.expectEqual(@as(usize, 3072), stats.peak_usage);
    
    stats.recordFree(1024);
    
    try std.testing.expectEqual(@as(usize, 2048), stats.current_usage);
    try std.testing.expectEqual(@as(usize, 3072), stats.peak_usage); // Peak unchanged
    try std.testing.expectEqual(@as(usize, 2048), stats.getLeakedBytes());
}

test "Profiler enter/exit" {
    const allocator = std.testing.allocator;
    var profiler = Profiler.init(allocator, .{});
    defer profiler.deinit();
    
    const func_id = try profiler.registry.register("test_func", "test.vibee", 1);
    
    profiler.start();
    
    try profiler.enterFunction(func_id);
    // Simulate some work
    std.time.sleep(1_000_000); // 1ms
    profiler.exitFunction(func_id);
    
    profiler.stop();
    
    const stats = profiler.getFunctionStats(func_id).?;
    try std.testing.expectEqual(@as(u64, 1), stats.call_count);
    try std.testing.expect(stats.total_time_ns >= 1_000_000); // At least 1ms
}

test "SamplingProfiler" {
    const allocator = std.testing.allocator;
    var sampler = SamplingProfiler.init(allocator, 10);
    defer sampler.deinit();
    
    sampler.start();
    
    try sampler.recordSample(1);
    try sampler.recordSample(1);
    try sampler.recordSample(2);
    try sampler.recordSample(1);
    
    sampler.stop();
    
    try std.testing.expectEqual(@as(u64, 4), sampler.total_samples);
    
    // Function 1: 3/4 = 75%
    const pct1 = sampler.getSamplePercentage(1);
    try std.testing.expect(pct1 > 74.0 and pct1 < 76.0);
    
    // Function 2: 1/4 = 25%
    const pct2 = sampler.getSamplePercentage(2);
    try std.testing.expect(pct2 > 24.0 and pct2 < 26.0);
}

test "golden identity verification" {
    // φ² + 1/φ² = 3
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / phi_squared;
    const result = phi_squared + inv_phi_squared;
    
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}

test "CallTreeNode D&C pattern" {
    const allocator = std.testing.allocator;
    var node = CallTreeNode.init(allocator, 1);
    defer node.deinit();
    
    try node.addChild(2);
    try node.addChild(3);
    try node.addChild(2); // Duplicate - should not add
    
    try std.testing.expectEqual(@as(usize, 2), node.children.items.len);
}
