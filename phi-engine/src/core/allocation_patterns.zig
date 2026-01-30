//! VIBEE Allocation Pattern Analyzer - PAS DAEMON V42
//! Identifies common allocation patterns for targeted optimization
//! Паттерны: HSH (pattern matching), MLS (ML-guided heuristics), PRE (cached patterns)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3
//! Target: Pattern-specific optimizations for 30% allocation reduction

const std = @import("std");
const Allocator = std.mem.Allocator;
const escape = @import("escape_analysis.zig");
const pea = @import("partial_escape.zig");

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// ALLOCATION PATTERNS - Common patterns that can be optimized
// ═══════════════════════════════════════════════════════════════════════════════

pub const AllocationPattern = enum(u8) {
    /// Temporary object used only within a single basic block
    /// Optimization: Stack allocation or scalar replacement
    temporary_local,
    
    /// Object created and immediately returned
    /// Optimization: Return value optimization (RVO)
    return_value,
    
    /// Object created in loop, not escaping loop
    /// Optimization: Loop-invariant allocation hoisting
    loop_local,
    
    /// Object created for iteration (iterator pattern)
    /// Optimization: Iterator fusion, stack allocation
    iterator,
    
    /// Builder pattern (StringBuilder, etc.)
    /// Optimization: Pre-sized allocation, in-place mutation
    builder,
    
    /// Closure/lambda capture
    /// Optimization: Inline closure, stack-allocate captures
    closure_capture,
    
    /// Tuple/pair for multiple return values
    /// Optimization: Scalar replacement into registers
    multi_return,
    
    /// Optional/Maybe wrapper
    /// Optimization: Null-check elimination, scalar replacement
    optional_wrapper,
    
    /// Result/Either for error handling
    /// Optimization: Exception-style unwinding, scalar replacement
    result_wrapper,
    
    /// Array/slice temporary
    /// Optimization: Stack array, small vector optimization
    array_temporary,
    
    /// Object pool candidate
    /// Optimization: Pool allocation
    poolable,
    
    /// Singleton pattern
    /// Optimization: Static allocation
    singleton,
    
    /// Unknown pattern
    unknown,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN SIGNATURE - Characteristics that identify a pattern
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternSignature = struct {
    /// Number of uses of the allocated object
    use_count: u32 = 0,
    /// Number of stores to the object
    store_count: u32 = 0,
    /// Number of loads from the object
    load_count: u32 = 0,
    /// Is returned from function
    is_returned: bool = false,
    /// Is passed to other functions
    is_passed: bool = false,
    /// Is stored to heap/global
    is_stored_global: bool = false,
    /// Is used in loop
    in_loop: bool = false,
    /// Loop depth (0 = not in loop)
    loop_depth: u8 = 0,
    /// Basic blocks where object is live
    live_blocks: u32 = 1,
    /// Object size in bytes
    size: u32 = 0,
    /// Number of fields
    field_count: u8 = 0,
    /// Type category
    type_category: TypeCategory = .unknown,
    
    pub fn matchPattern(self: *const PatternSignature) AllocationPattern {
        // Temporary local: single block, no escape
        if (self.live_blocks == 1 and !self.is_returned and 
            !self.is_passed and !self.is_stored_global) {
            return .temporary_local;
        }
        
        // Return value: created and returned, minimal other use
        if (self.is_returned and self.use_count <= 3 and 
            !self.is_passed and !self.is_stored_global) {
            return .return_value;
        }
        
        // Loop local: in loop but doesn't escape
        if (self.in_loop and !self.is_returned and 
            !self.is_passed and !self.is_stored_global) {
            return .loop_local;
        }
        
        // Iterator: specific type category
        if (self.type_category == .iterator) {
            return .iterator;
        }
        
        // Builder: many stores, grows
        if (self.type_category == .builder or 
            (self.store_count > 5 and self.field_count <= 3)) {
            return .builder;
        }
        
        // Closure capture
        if (self.type_category == .closure) {
            return .closure_capture;
        }
        
        // Multi-return tuple
        if (self.type_category == .tuple and self.is_returned and 
            self.field_count <= 4) {
            return .multi_return;
        }
        
        // Optional wrapper
        if (self.type_category == .optional) {
            return .optional_wrapper;
        }
        
        // Result wrapper
        if (self.type_category == .result) {
            return .result_wrapper;
        }
        
        // Array temporary
        if (self.type_category == .array and !self.is_stored_global) {
            return .array_temporary;
        }
        
        // Poolable: frequently allocated same type
        if (self.size <= 256 and self.use_count >= 10) {
            return .poolable;
        }
        
        return .unknown;
    }
};

pub const TypeCategory = enum(u8) {
    primitive,
    struct_type,
    array,
    tuple,
    optional,
    result,
    iterator,
    builder,
    closure,
    unknown,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternAnalyzer = struct {
    allocator: Allocator,
    
    // Allocation signatures
    signatures: std.AutoHashMap(u32, PatternSignature),
    
    // Detected patterns
    patterns: std.AutoHashMap(u32, AllocationPattern),
    
    // Pattern-specific optimizations
    optimizations: std.ArrayList(PatternOptimization),
    
    // Statistics
    stats: PatternStats = .{},
    
    pub fn init(allocator: Allocator) PatternAnalyzer {
        return .{
            .allocator = allocator,
            .signatures = std.AutoHashMap(u32, PatternSignature).init(allocator),
            .patterns = std.AutoHashMap(u32, AllocationPattern).init(allocator),
            .optimizations = std.ArrayList(PatternOptimization).init(allocator),
        };
    }
    
    pub fn deinit(self: *PatternAnalyzer) void {
        self.signatures.deinit();
        self.patterns.deinit();
        self.optimizations.deinit();
    }
    
    /// Register allocation for pattern analysis
    pub fn registerAllocation(self: *PatternAnalyzer, alloc_id: u32, 
                              size: u32, fields: u8, type_cat: TypeCategory) !void {
        try self.signatures.put(alloc_id, .{
            .size = size,
            .field_count = fields,
            .type_category = type_cat,
        });
    }
    
    /// Record use of allocation
    pub fn recordUse(self: *PatternAnalyzer, alloc_id: u32) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.use_count += 1;
        }
    }
    
    /// Record store to allocation
    pub fn recordStore(self: *PatternAnalyzer, alloc_id: u32) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.store_count += 1;
        }
    }
    
    /// Record load from allocation
    pub fn recordLoad(self: *PatternAnalyzer, alloc_id: u32) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.load_count += 1;
        }
    }
    
    /// Record return of allocation
    pub fn recordReturn(self: *PatternAnalyzer, alloc_id: u32) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.is_returned = true;
        }
    }
    
    /// Record passing allocation to function
    pub fn recordPass(self: *PatternAnalyzer, alloc_id: u32) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.is_passed = true;
        }
    }
    
    /// Record storing allocation to global/heap
    pub fn recordGlobalStore(self: *PatternAnalyzer, alloc_id: u32) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.is_stored_global = true;
        }
    }
    
    /// Record loop context
    pub fn recordLoopContext(self: *PatternAnalyzer, alloc_id: u32, depth: u8) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.in_loop = true;
            sig.loop_depth = depth;
        }
    }
    
    /// Record live block count
    pub fn recordLiveBlocks(self: *PatternAnalyzer, alloc_id: u32, blocks: u32) void {
        if (self.signatures.getPtr(alloc_id)) |sig| {
            sig.live_blocks = blocks;
        }
    }
    
    /// Analyze all allocations and detect patterns
    pub fn analyze(self: *PatternAnalyzer) !void {
        var iter = self.signatures.iterator();
        while (iter.next()) |entry| {
            const pattern = entry.value_ptr.matchPattern();
            try self.patterns.put(entry.key_ptr.*, pattern);
            
            // Generate optimization for pattern
            const opt = self.generateOptimization(entry.key_ptr.*, pattern, entry.value_ptr);
            if (opt) |o| {
                try self.optimizations.append(o);
            }
            
            // Update statistics
            self.updateStats(pattern);
        }
    }
    
    /// Generate optimization for detected pattern
    fn generateOptimization(self: *PatternAnalyzer, alloc_id: u32, 
                            pattern: AllocationPattern, sig: *const PatternSignature) ?PatternOptimization {
        _ = self;
        
        return switch (pattern) {
            .temporary_local => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .stack_allocate,
                .estimated_savings = sig.size,
            },
            .return_value => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .return_value_opt,
                .estimated_savings = sig.size,
            },
            .loop_local => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .hoist_allocation,
                .estimated_savings = sig.size * @as(u32, @intCast(sig.loop_depth + 1)) * 10,
            },
            .iterator => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .stack_allocate,
                .estimated_savings = sig.size,
            },
            .builder => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .presize_allocation,
                .estimated_savings = sig.size / 2,
            },
            .closure_capture => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .inline_closure,
                .estimated_savings = sig.size,
            },
            .multi_return => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .scalar_replace,
                .estimated_savings = sig.size,
            },
            .optional_wrapper => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .scalar_replace,
                .estimated_savings = sig.size,
            },
            .result_wrapper => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .scalar_replace,
                .estimated_savings = sig.size,
            },
            .array_temporary => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = if (sig.size <= 256) .stack_allocate else .pool_allocate,
                .estimated_savings = sig.size,
            },
            .poolable => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .pool_allocate,
                .estimated_savings = sig.size / 4,
            },
            .singleton => .{
                .alloc_id = alloc_id,
                .pattern = pattern,
                .action = .static_allocate,
                .estimated_savings = sig.size,
            },
            .unknown => null,
        };
    }
    
    fn updateStats(self: *PatternAnalyzer, pattern: AllocationPattern) void {
        self.stats.total_analyzed += 1;
        switch (pattern) {
            .temporary_local => self.stats.temporary_local += 1,
            .return_value => self.stats.return_value += 1,
            .loop_local => self.stats.loop_local += 1,
            .iterator => self.stats.iterator += 1,
            .builder => self.stats.builder += 1,
            .closure_capture => self.stats.closure_capture += 1,
            .multi_return => self.stats.multi_return += 1,
            .optional_wrapper => self.stats.optional_wrapper += 1,
            .result_wrapper => self.stats.result_wrapper += 1,
            .array_temporary => self.stats.array_temporary += 1,
            .poolable => self.stats.poolable += 1,
            .singleton => self.stats.singleton += 1,
            .unknown => self.stats.unknown += 1,
        }
    }
    
    /// Get pattern for allocation
    pub fn getPattern(self: *const PatternAnalyzer, alloc_id: u32) ?AllocationPattern {
        return self.patterns.get(alloc_id);
    }
    
    /// Get all optimizations
    pub fn getOptimizations(self: *const PatternAnalyzer) []const PatternOptimization {
        return self.optimizations.items;
    }
    
    /// Calculate estimated total savings
    pub fn estimatedSavings(self: *const PatternAnalyzer) u64 {
        var total: u64 = 0;
        for (self.optimizations.items) |opt| {
            total += opt.estimated_savings;
        }
        return total;
    }
    
    /// Get statistics
    pub fn getStats(self: *const PatternAnalyzer) PatternStats {
        return self.stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN OPTIMIZATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const OptimizationAction = enum {
    stack_allocate,
    scalar_replace,
    return_value_opt,
    hoist_allocation,
    presize_allocation,
    inline_closure,
    pool_allocate,
    static_allocate,
    none,
};

pub const PatternOptimization = struct {
    alloc_id: u32,
    pattern: AllocationPattern,
    action: OptimizationAction,
    estimated_savings: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternStats = struct {
    total_analyzed: u64 = 0,
    temporary_local: u64 = 0,
    return_value: u64 = 0,
    loop_local: u64 = 0,
    iterator: u64 = 0,
    builder: u64 = 0,
    closure_capture: u64 = 0,
    multi_return: u64 = 0,
    optional_wrapper: u64 = 0,
    result_wrapper: u64 = 0,
    array_temporary: u64 = 0,
    poolable: u64 = 0,
    singleton: u64 = 0,
    unknown: u64 = 0,
    
    pub fn optimizableRatio(self: *const PatternStats) f64 {
        if (self.total_analyzed == 0) return 0.0;
        const optimizable = self.total_analyzed - self.unknown;
        return @as(f64, @floatFromInt(optimizable)) / 
               @as(f64, @floatFromInt(self.total_analyzed)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMBINED OPTIMIZER - Integrates all escape analysis components
// ═══════════════════════════════════════════════════════════════════════════════

pub const AllocationOptimizer = struct {
    allocator: Allocator,
    
    // Component analyzers
    escape_analyzer: escape.EscapeAnalyzer,
    partial_escape: pea.PartialEscapeAnalyzer,
    pattern_analyzer: PatternAnalyzer,
    
    // Combined statistics
    stats: CombinedStats = .{},
    
    pub fn init(allocator: Allocator) AllocationOptimizer {
        return .{
            .allocator = allocator,
            .escape_analyzer = escape.EscapeAnalyzer.init(allocator, .{}),
            .partial_escape = pea.PartialEscapeAnalyzer.init(allocator, .{}),
            .pattern_analyzer = PatternAnalyzer.init(allocator),
        };
    }
    
    pub fn deinit(self: *AllocationOptimizer) void {
        self.escape_analyzer.deinit();
        self.partial_escape.deinit();
        self.pattern_analyzer.deinit();
    }
    
    /// Run all analyses
    pub fn analyze(self: *AllocationOptimizer) !void {
        // Run escape analysis
        try self.escape_analyzer.analyze();
        
        // Run pattern analysis
        try self.pattern_analyzer.analyze();
        
        // Collect combined statistics
        self.collectStats();
    }
    
    fn collectStats(self: *AllocationOptimizer) void {
        const ea_stats = self.escape_analyzer.getStats();
        const pea_stats = self.partial_escape.getStats();
        const pat_stats = self.pattern_analyzer.getStats();
        
        self.stats.total_allocations = ea_stats.total_allocations;
        self.stats.stack_allocated = ea_stats.stack_allocated;
        self.stats.scalar_replaced = ea_stats.scalar_replaced;
        self.stats.virtualized = pea_stats.allocations_virtualized - pea_stats.materializations;
        self.stats.pattern_optimized = pat_stats.total_analyzed - pat_stats.unknown;
        self.stats.estimated_savings = self.pattern_analyzer.estimatedSavings();
    }
    
    /// Get combined optimization decision
    pub fn getOptimization(self: *const AllocationOptimizer, alloc_id: u32) OptimizationResult {
        var result = OptimizationResult{};
        
        // Check escape analysis
        if (self.escape_analyzer.getDecision(alloc_id)) |ea_dec| {
            result.escape_state = ea_dec.escape_state;
            result.stack_allocate = ea_dec.stack_allocate;
            result.scalar_replace = ea_dec.scalar_replace;
        }
        
        // Check pattern analysis
        if (self.pattern_analyzer.getPattern(alloc_id)) |pattern| {
            result.pattern = pattern;
        }
        
        return result;
    }
    
    /// Calculate overall allocation reduction
    pub fn allocationReduction(self: *const AllocationOptimizer) f64 {
        if (self.stats.total_allocations == 0) return 0.0;
        const optimized = self.stats.stack_allocated + 
                         self.stats.scalar_replaced + 
                         self.stats.virtualized;
        return @as(f64, @floatFromInt(optimized)) / 
               @as(f64, @floatFromInt(self.stats.total_allocations)) * 100.0;
    }
    
    /// Get statistics
    pub fn getStats(self: *const AllocationOptimizer) CombinedStats {
        return self.stats;
    }
};

pub const OptimizationResult = struct {
    escape_state: escape.EscapeState = .unknown,
    stack_allocate: bool = false,
    scalar_replace: bool = false,
    pattern: AllocationPattern = .unknown,
};

pub const CombinedStats = struct {
    total_allocations: u64 = 0,
    stack_allocated: u64 = 0,
    scalar_replaced: u64 = 0,
    virtualized: u64 = 0,
    pattern_optimized: u64 = 0,
    estimated_savings: u64 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PatternSignature matching" {
    // Temporary local pattern
    var sig1 = PatternSignature{
        .live_blocks = 1,
        .use_count = 3,
        .is_returned = false,
        .is_passed = false,
        .is_stored_global = false,
    };
    try std.testing.expectEqual(AllocationPattern.temporary_local, sig1.matchPattern());
    
    // Return value pattern
    var sig2 = PatternSignature{
        .live_blocks = 2,
        .use_count = 2,
        .is_returned = true,
        .is_passed = false,
        .is_stored_global = false,
    };
    try std.testing.expectEqual(AllocationPattern.return_value, sig2.matchPattern());
    
    // Loop local pattern - needs multiple blocks to not match temporary_local first
    var sig3 = PatternSignature{
        .live_blocks = 3,  // Multiple blocks so it doesn't match temporary_local
        .in_loop = true,
        .loop_depth = 1,
        .is_returned = false,
        .is_passed = false,
        .is_stored_global = false,
    };
    try std.testing.expectEqual(AllocationPattern.loop_local, sig3.matchPattern());
}

test "PatternAnalyzer" {
    const allocator = std.testing.allocator;
    var analyzer = PatternAnalyzer.init(allocator);
    defer analyzer.deinit();
    
    // Register temporary local allocation
    try analyzer.registerAllocation(0, 64, 4, .struct_type);
    analyzer.recordUse(0);
    analyzer.recordStore(0);
    analyzer.recordLiveBlocks(0, 1);
    
    // Register return value allocation
    try analyzer.registerAllocation(1, 32, 2, .tuple);
    analyzer.recordReturn(1);
    analyzer.recordLiveBlocks(1, 2);
    
    // Analyze
    try analyzer.analyze();
    
    // Check patterns
    try std.testing.expectEqual(AllocationPattern.temporary_local, analyzer.getPattern(0).?);
    try std.testing.expectEqual(AllocationPattern.return_value, analyzer.getPattern(1).?);
    
    // Check optimizations generated
    try std.testing.expect(analyzer.getOptimizations().len >= 2);
}

test "AllocationOptimizer" {
    const allocator = std.testing.allocator;
    var optimizer = AllocationOptimizer.init(allocator);
    defer optimizer.deinit();
    
    // Register allocation in escape analyzer
    _ = try optimizer.escape_analyzer.registerAllocation(0, 1, 64, 4);
    
    // Register in pattern analyzer
    try optimizer.pattern_analyzer.registerAllocation(0, 64, 4, .struct_type);
    optimizer.pattern_analyzer.recordLiveBlocks(0, 1);
    
    // Run analysis
    try optimizer.analyze();
    
    // Check combined result
    const result = optimizer.getOptimization(0);
    try std.testing.expect(result.stack_allocate);
    try std.testing.expectEqual(AllocationPattern.temporary_local, result.pattern);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
