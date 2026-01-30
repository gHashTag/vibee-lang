//! VIBEE Function Inliner - PAS DAEMON V40
//! Паттерны: MLS (cost model), PRE (cached bodies), D&C (recursive inlining)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// INLINING CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const InlineConfig = struct {
    // Cost thresholds
    max_inline_cost: u32 = 100,
    call_overhead: u32 = 10,
    
    // Size limits
    max_function_size: u32 = 500,
    max_inline_depth: u32 = 5,
    
    // Heuristics
    always_inline_threshold: u32 = 20,
    hot_call_bonus: u32 = 50,
    
    // Sacred threshold: use φ for balance
    sacred_threshold_factor: f64 = PHI,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION REPRESENTATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const FunctionInfo = struct {
    name: []const u8,
    instruction_count: u32,
    param_count: u8,
    has_side_effects: bool,
    is_recursive: bool,
    call_count: u32 = 0,
    inline_cost: u32 = 0,
    
    // Attributes
    always_inline: bool = false,
    never_inline: bool = false,
    
    pub fn init(name: []const u8, inst_count: u32, params: u8) FunctionInfo {
        return .{
            .name = name,
            .instruction_count = inst_count,
            .param_count = params,
            .has_side_effects = false,
            .is_recursive = false,
        };
    }
    
    pub fn computeCost(self: *FunctionInfo, config: *const InlineConfig) void {
        // Base cost is instruction count
        var cost: u32 = self.instruction_count;
        
        // Add parameter passing cost
        cost += @as(u32, self.param_count) * 2;
        
        // Penalty for side effects
        if (self.has_side_effects) {
            cost += 20;
        }
        
        // Recursive functions have high cost
        if (self.is_recursive) {
            cost += 100;
        }
        
        self.inline_cost = cost;
        _ = config;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALL SITE
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallSite = struct {
    caller: []const u8,
    callee: []const u8,
    call_id: u32,
    arg_count: u8,
    
    // Profiling info
    call_frequency: u32 = 1,
    is_hot: bool = false,
    
    // Inlining decision
    should_inline: bool = false,
    inline_benefit: i32 = 0,
    
    pub fn init(caller: []const u8, callee: []const u8, call_id: u32, args: u8) CallSite {
        return .{
            .caller = caller,
            .callee = callee,
            .call_id = call_id,
            .arg_count = args,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE COST MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const InlineCostModel = struct {
    config: InlineConfig,
    
    pub fn init(config: InlineConfig) InlineCostModel {
        return .{ .config = config };
    }
    
    /// Compute benefit of inlining at call site
    pub fn computeBenefit(self: *const InlineCostModel, callee: *const FunctionInfo, site: *const CallSite) i32 {
        // Base benefit: eliminate call overhead
        var benefit: i32 = @intCast(self.config.call_overhead);
        
        // Hot call bonus
        if (site.is_hot) {
            benefit += @intCast(self.config.hot_call_bonus);
        }
        
        // Frequency bonus
        benefit += @intCast(site.call_frequency);
        
        // Cost of inlining
        const cost: i32 = @intCast(callee.inline_cost);
        
        return benefit - cost;
    }
    
    /// Decide whether to inline
    pub fn shouldInline(self: *const InlineCostModel, callee: *const FunctionInfo, site: *CallSite) bool {
        // Never inline recursive functions
        if (callee.is_recursive) return false;
        
        // Respect attributes
        if (callee.never_inline) return false;
        if (callee.always_inline) {
            site.should_inline = true;
            return true;
        }
        
        // Always inline tiny functions
        if (callee.instruction_count <= self.config.always_inline_threshold) {
            site.should_inline = true;
            return true;
        }
        
        // Size limit
        if (callee.instruction_count > self.config.max_function_size) {
            return false;
        }
        
        // Cost-benefit analysis
        const benefit = self.computeBenefit(callee, site);
        site.inline_benefit = benefit;
        
        // Use sacred threshold: benefit > cost * φ
        const threshold: i32 = @intFromFloat(@as(f64, @floatFromInt(callee.inline_cost)) / self.config.sacred_threshold_factor);
        
        site.should_inline = benefit > threshold;
        return site.should_inline;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INLINER - Main inlining engine
// ═══════════════════════════════════════════════════════════════════════════════

pub const Inliner = struct {
    allocator: Allocator,
    config: InlineConfig,
    cost_model: InlineCostModel,
    
    // Function registry (HSH pattern)
    functions: std.StringHashMap(FunctionInfo),
    
    // Call sites
    call_sites: std.ArrayList(CallSite),
    
    // Inlining cache (PRE pattern)
    inline_cache: std.StringHashMap(bool),
    
    // Statistics
    stats: InlinerStats = .{},
    
    pub fn init(allocator: Allocator, config: InlineConfig) Inliner {
        return .{
            .allocator = allocator,
            .config = config,
            .cost_model = InlineCostModel.init(config),
            .functions = std.StringHashMap(FunctionInfo).init(allocator),
            .call_sites = std.ArrayList(CallSite).init(allocator),
            .inline_cache = std.StringHashMap(bool).init(allocator),
        };
    }
    
    pub fn deinit(self: *Inliner) void {
        self.functions.deinit();
        self.call_sites.deinit();
        self.inline_cache.deinit();
    }
    
    /// Register function
    pub fn registerFunction(self: *Inliner, info: FunctionInfo) !void {
        var mutable_info = info;
        mutable_info.computeCost(&self.config);
        try self.functions.put(info.name, mutable_info);
    }
    
    /// Add call site
    pub fn addCallSite(self: *Inliner, site: CallSite) !void {
        try self.call_sites.append(site);
    }
    
    /// Analyze all call sites and decide inlining
    pub fn analyze(self: *Inliner) !void {
        for (self.call_sites.items) |*site| {
            // Check cache first (PRE pattern)
            const cache_key = site.callee;
            if (self.inline_cache.get(cache_key)) |cached| {
                site.should_inline = cached;
                if (cached) self.stats.cache_hits += 1;
                continue;
            }
            
            // Get callee info
            if (self.functions.getPtr(site.callee)) |callee| {
                const should = self.cost_model.shouldInline(callee, site);
                try self.inline_cache.put(cache_key, should);
                
                if (should) {
                    self.stats.inlined_calls += 1;
                } else {
                    self.stats.rejected_calls += 1;
                }
            }
        }
    }
    
    /// Get inlining decisions
    pub fn getInlineDecisions(self: *const Inliner) []const CallSite {
        return self.call_sites.items;
    }
    
    /// Get statistics
    pub fn getStats(self: *const Inliner) InlinerStats {
        return self.stats;
    }
    
    /// Check if function should be inlined at any call site
    pub fn shouldInlineFunction(self: *const Inliner, name: []const u8) bool {
        for (self.call_sites.items) |site| {
            if (std.mem.eql(u8, site.callee, name) and site.should_inline) {
                return true;
            }
        }
        return false;
    }
};

pub const InlinerStats = struct {
    inlined_calls: u64 = 0,
    rejected_calls: u64 = 0,
    cache_hits: u64 = 0,
    total_benefit: i64 = 0,
    
    pub fn inlineRatio(self: *const InlinerStats) f64 {
        const total = self.inlined_calls + self.rejected_calls;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.inlined_calls)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALL GRAPH - For recursive detection
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallGraph = struct {
    allocator: Allocator,
    edges: std.StringHashMap(std.ArrayList([]const u8)),
    
    pub fn init(allocator: Allocator) CallGraph {
        return .{
            .allocator = allocator,
            .edges = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
        };
    }
    
    pub fn deinit(self: *CallGraph) void {
        var iter = self.edges.valueIterator();
        while (iter.next()) |list| {
            list.deinit();
        }
        self.edges.deinit();
    }
    
    pub fn addEdge(self: *CallGraph, caller: []const u8, callee: []const u8) !void {
        const result = try self.edges.getOrPut(caller);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList([]const u8).init(self.allocator);
        }
        try result.value_ptr.append(callee);
    }
    
    /// Check if function is recursive (direct or indirect)
    pub fn isRecursive(self: *const CallGraph, func: []const u8) bool {
        var visited = std.StringHashMap(void).init(self.allocator);
        defer visited.deinit();
        return self.dfsRecursive(func, func, &visited);
    }
    
    fn dfsRecursive(self: *const CallGraph, start: []const u8, current: []const u8, visited: *std.StringHashMap(void)) bool {
        if (visited.contains(current)) return false;
        visited.put(current, {}) catch return false;
        
        if (self.edges.get(current)) |callees| {
            for (callees.items) |callee| {
                if (std.mem.eql(u8, callee, start)) return true;
                if (self.dfsRecursive(start, callee, visited)) return true;
            }
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Inliner tiny function" {
    const allocator = std.testing.allocator;
    var inliner = Inliner.init(allocator, .{});
    defer inliner.deinit();
    
    // Tiny function should always be inlined
    const tiny = FunctionInfo.init("tiny", 5, 1);
    try inliner.registerFunction(tiny);
    
    try inliner.addCallSite(CallSite.init("main", "tiny", 0, 1));
    try inliner.analyze();
    
    try std.testing.expect(inliner.shouldInlineFunction("tiny"));
    try std.testing.expectEqual(@as(u64, 1), inliner.stats.inlined_calls);
}

test "Inliner large function rejected" {
    const allocator = std.testing.allocator;
    var inliner = Inliner.init(allocator, .{ .max_function_size = 100 });
    defer inliner.deinit();
    
    // Large function should not be inlined
    const large = FunctionInfo.init("large", 200, 5);
    try inliner.registerFunction(large);
    
    try inliner.addCallSite(CallSite.init("main", "large", 0, 5));
    try inliner.analyze();
    
    try std.testing.expect(!inliner.shouldInlineFunction("large"));
    try std.testing.expectEqual(@as(u64, 1), inliner.stats.rejected_calls);
}

test "Inliner recursive function" {
    const allocator = std.testing.allocator;
    var inliner = Inliner.init(allocator, .{});
    defer inliner.deinit();
    
    var recursive = FunctionInfo.init("factorial", 10, 1);
    recursive.is_recursive = true;
    try inliner.registerFunction(recursive);
    
    try inliner.addCallSite(CallSite.init("main", "factorial", 0, 1));
    try inliner.analyze();
    
    try std.testing.expect(!inliner.shouldInlineFunction("factorial"));
}

test "Inliner always_inline attribute" {
    const allocator = std.testing.allocator;
    var inliner = Inliner.init(allocator, .{});
    defer inliner.deinit();
    
    var func = FunctionInfo.init("force_inline", 100, 3);
    func.always_inline = true;
    try inliner.registerFunction(func);
    
    try inliner.addCallSite(CallSite.init("main", "force_inline", 0, 3));
    try inliner.analyze();
    
    try std.testing.expect(inliner.shouldInlineFunction("force_inline"));
}

test "Inliner hot call bonus" {
    const allocator = std.testing.allocator;
    var inliner = Inliner.init(allocator, .{});
    defer inliner.deinit();
    
    const func = FunctionInfo.init("medium", 50, 2);
    try inliner.registerFunction(func);
    
    var site = CallSite.init("main", "medium", 0, 2);
    site.is_hot = true;
    site.call_frequency = 100;
    try inliner.addCallSite(site);
    
    try inliner.analyze();
    
    // Hot call should be inlined due to bonus
    try std.testing.expect(inliner.shouldInlineFunction("medium"));
}

test "CallGraph recursive detection" {
    const allocator = std.testing.allocator;
    var graph = CallGraph.init(allocator);
    defer graph.deinit();
    
    // Direct recursion: a -> a
    try graph.addEdge("a", "a");
    try std.testing.expect(graph.isRecursive("a"));
    
    // Indirect recursion: b -> c -> b
    try graph.addEdge("b", "c");
    try graph.addEdge("c", "b");
    try std.testing.expect(graph.isRecursive("b"));
    
    // Non-recursive: d -> e
    try graph.addEdge("d", "e");
    try std.testing.expect(!graph.isRecursive("d"));
}

test "InlineCostModel benefit calculation" {
    const config = InlineConfig{};
    const model = InlineCostModel.init(config);
    
    var func = FunctionInfo.init("test", 30, 2);
    func.inline_cost = 35;
    
    var site = CallSite.init("main", "test", 0, 2);
    site.is_hot = true;
    site.call_frequency = 10;
    
    const benefit = model.computeBenefit(&func, &site);
    // benefit = call_overhead(10) + hot_bonus(50) + frequency(10) - cost(35) = 35
    try std.testing.expectEqual(@as(i32, 35), benefit);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
