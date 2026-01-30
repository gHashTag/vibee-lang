//! VIBEE Escape Analysis and Scalar Replacement - PAS DAEMON V42
//! Паттерны: HSH (O(1) escape state lookup), D&C (interprocedural analysis), PRE (cached results)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3
//! Target: 30% allocation overhead reduction via stack allocation and scalar replacement

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// ESCAPE STATE - Lattice for escape analysis
// ═══════════════════════════════════════════════════════════════════════════════

/// Escape lattice: NoEscape < ArgEscape < GlobalEscape
pub const EscapeState = enum(u8) {
    /// Object does not escape - can be stack allocated or scalar replaced
    no_escape = 0,
    /// Object escapes only through arguments - may be stack allocated with care
    arg_escape = 1,
    /// Object escapes to heap/global - must be heap allocated
    global_escape = 2,
    /// Unknown state (bottom of lattice)
    unknown = 3,

    pub fn join(self: EscapeState, other: EscapeState) EscapeState {
        return @enumFromInt(@max(@intFromEnum(self), @intFromEnum(other)));
    }

    pub fn canStackAllocate(self: EscapeState) bool {
        return self == .no_escape;
    }

    pub fn canScalarReplace(self: EscapeState) bool {
        return self == .no_escape;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALLOCATION SITE - Represents an allocation in the program
// ═══════════════════════════════════════════════════════════════════════════════

pub const AllocationSite = struct {
    id: u32,
    instruction_id: u32,
    type_id: u32,
    size: u32,
    field_count: u8,
    escape_state: EscapeState = .unknown,
    
    // Optimization decisions
    stack_allocate: bool = false,
    scalar_replace: bool = false,
    
    // For scalar replacement
    field_values: ?[]u32 = null,
    
    pub fn init(id: u32, inst_id: u32, type_id: u32, size: u32, fields: u8) AllocationSite {
        return .{
            .id = id,
            .instruction_id = inst_id,
            .type_id = type_id,
            .size = size,
            .field_count = fields,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONNECTION GRAPH - For interprocedural escape analysis
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeKind = enum(u8) {
    object,      // Allocation site
    reference,   // Reference/pointer
    field,       // Object field
    phantom,     // Unknown external object
};

pub const GraphNode = struct {
    id: u32,
    kind: NodeKind,
    escape_state: EscapeState = .unknown,
    allocation_site: ?u32 = null,
    field_index: ?u8 = null,
    edges: std.ArrayList(u32),
    
    pub fn init(allocator: Allocator, id: u32, kind: NodeKind) GraphNode {
        return .{
            .id = id,
            .kind = kind,
            .edges = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *GraphNode) void {
        self.edges.deinit();
    }
    
    pub fn addEdge(self: *GraphNode, target: u32) !void {
        // Avoid duplicates
        for (self.edges.items) |e| {
            if (e == target) return;
        }
        try self.edges.append(target);
    }
};

pub const ConnectionGraph = struct {
    allocator: Allocator,
    nodes: std.ArrayList(GraphNode),
    node_map: std.AutoHashMap(u32, u32), // value_id -> node_id
    
    pub fn init(allocator: Allocator) ConnectionGraph {
        return .{
            .allocator = allocator,
            .nodes = std.ArrayList(GraphNode).init(allocator),
            .node_map = std.AutoHashMap(u32, u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *ConnectionGraph) void {
        for (self.nodes.items) |*node| {
            node.deinit();
        }
        self.nodes.deinit();
        self.node_map.deinit();
    }
    
    pub fn addNode(self: *ConnectionGraph, kind: NodeKind) !u32 {
        const id: u32 = @intCast(self.nodes.items.len);
        try self.nodes.append(GraphNode.init(self.allocator, id, kind));
        return id;
    }
    
    pub fn addEdge(self: *ConnectionGraph, from: u32, to: u32) !void {
        if (from < self.nodes.items.len) {
            try self.nodes.items[from].addEdge(to);
        }
    }
    
    pub fn getNode(self: *ConnectionGraph, id: u32) ?*GraphNode {
        if (id < self.nodes.items.len) {
            return &self.nodes.items[id];
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ESCAPE ANALYZER - Main analysis engine
// ═══════════════════════════════════════════════════════════════════════════════

pub const EscapeAnalyzer = struct {
    allocator: Allocator,
    
    // Allocation sites
    allocations: std.ArrayList(AllocationSite),
    
    // Connection graph for interprocedural analysis
    graph: ConnectionGraph,
    
    // Cache for function summaries (PRE pattern)
    function_summaries: std.StringHashMap(FunctionSummary),
    
    // Worklist for fixed-point iteration
    worklist: std.ArrayList(u32),
    
    // Statistics
    stats: EscapeStats = .{},
    
    // Configuration
    config: EscapeConfig,
    
    pub fn init(allocator: Allocator, config: EscapeConfig) EscapeAnalyzer {
        return .{
            .allocator = allocator,
            .allocations = std.ArrayList(AllocationSite).init(allocator),
            .graph = ConnectionGraph.init(allocator),
            .function_summaries = std.StringHashMap(FunctionSummary).init(allocator),
            .worklist = std.ArrayList(u32).init(allocator),
            .config = config,
        };
    }
    
    pub fn deinit(self: *EscapeAnalyzer) void {
        self.allocations.deinit();
        self.graph.deinit();
        var iter = self.function_summaries.valueIterator();
        while (iter.next()) |summary| {
            summary.deinit();
        }
        self.function_summaries.deinit();
        self.worklist.deinit();
    }
    
    /// Register an allocation site
    pub fn registerAllocation(self: *EscapeAnalyzer, inst_id: u32, type_id: u32, size: u32, fields: u8) !u32 {
        const id: u32 = @intCast(self.allocations.items.len);
        try self.allocations.append(AllocationSite.init(id, inst_id, type_id, size, fields));
        
        // Create graph node for allocation
        const node_id = try self.graph.addNode(.object);
        if (self.graph.getNode(node_id)) |node| {
            node.allocation_site = id;
        }
        
        self.stats.total_allocations += 1;
        return id;
    }
    
    /// Mark allocation as escaping through return
    pub fn markReturnEscape(self: *EscapeAnalyzer, alloc_id: u32) void {
        if (alloc_id < self.allocations.items.len) {
            self.allocations.items[alloc_id].escape_state = 
                self.allocations.items[alloc_id].escape_state.join(.global_escape);
        }
    }
    
    /// Mark allocation as escaping through argument
    pub fn markArgEscape(self: *EscapeAnalyzer, alloc_id: u32) void {
        if (alloc_id < self.allocations.items.len) {
            self.allocations.items[alloc_id].escape_state = 
                self.allocations.items[alloc_id].escape_state.join(.arg_escape);
        }
    }
    
    /// Mark allocation as escaping to global/heap
    pub fn markGlobalEscape(self: *EscapeAnalyzer, alloc_id: u32) void {
        if (alloc_id < self.allocations.items.len) {
            self.allocations.items[alloc_id].escape_state = .global_escape;
        }
    }
    
    /// Run escape analysis - fixed-point iteration
    pub fn analyze(self: *EscapeAnalyzer) !void {
        // Initialize all allocations to no_escape
        for (self.allocations.items) |*alloc| {
            if (alloc.escape_state == .unknown) {
                alloc.escape_state = .no_escape;
            }
        }
        
        // Add all allocations to worklist
        self.worklist.clearRetainingCapacity();
        for (0..self.allocations.items.len) |i| {
            try self.worklist.append(@intCast(i));
        }
        
        // Fixed-point iteration
        var iterations: u32 = 0;
        const max_iterations = self.config.max_iterations;
        
        while (self.worklist.items.len > 0 and iterations < max_iterations) {
            iterations += 1;
            const alloc_id = self.worklist.pop();
            
            // Propagate escape state through graph
            try self.propagateEscape(alloc_id);
        }
        
        self.stats.analysis_iterations = iterations;
        
        // Make optimization decisions
        self.makeOptimizationDecisions();
    }
    
    /// Propagate escape state through connection graph
    fn propagateEscape(self: *EscapeAnalyzer, alloc_id: u32) !void {
        if (alloc_id >= self.allocations.items.len) return;
        
        const alloc = &self.allocations.items[alloc_id];
        const old_state = alloc.escape_state;
        
        // Find corresponding graph node
        for (self.graph.nodes.items) |*node| {
            if (node.allocation_site == alloc_id) {
                // Propagate to connected nodes
                for (node.edges.items) |edge_id| {
                    if (self.graph.getNode(edge_id)) |target| {
                        const new_state = target.escape_state.join(alloc.escape_state);
                        if (@intFromEnum(new_state) > @intFromEnum(target.escape_state)) {
                            target.escape_state = new_state;
                            
                            // If target is an allocation, add to worklist
                            if (target.allocation_site) |target_alloc| {
                                if (target_alloc < self.allocations.items.len) {
                                    self.allocations.items[target_alloc].escape_state = new_state;
                                    try self.worklist.append(target_alloc);
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Check if state changed
        if (@intFromEnum(alloc.escape_state) > @intFromEnum(old_state)) {
            // Re-add to worklist for further propagation
            try self.worklist.append(alloc_id);
        }
    }
    
    /// Make optimization decisions based on escape analysis
    fn makeOptimizationDecisions(self: *EscapeAnalyzer) void {
        for (self.allocations.items) |*alloc| {
            // Stack allocation decision
            if (alloc.escape_state.canStackAllocate() and 
                alloc.size <= self.config.max_stack_alloc_size) {
                alloc.stack_allocate = true;
                self.stats.stack_allocated += 1;
            }
            
            // Scalar replacement decision
            if (alloc.escape_state.canScalarReplace() and
                alloc.field_count <= self.config.max_scalar_fields and
                alloc.size <= self.config.max_scalar_size) {
                alloc.scalar_replace = true;
                self.stats.scalar_replaced += 1;
            }
        }
    }
    
    /// Get optimization decision for allocation
    pub fn getDecision(self: *const EscapeAnalyzer, alloc_id: u32) ?OptimizationDecision {
        if (alloc_id >= self.allocations.items.len) return null;
        
        const alloc = &self.allocations.items[alloc_id];
        return .{
            .escape_state = alloc.escape_state,
            .stack_allocate = alloc.stack_allocate,
            .scalar_replace = alloc.scalar_replace,
        };
    }
    
    /// Get statistics
    pub fn getStats(self: *const EscapeAnalyzer) EscapeStats {
        return self.stats;
    }
    
    /// Calculate allocation reduction percentage
    pub fn allocationReduction(self: *const EscapeAnalyzer) f64 {
        if (self.stats.total_allocations == 0) return 0.0;
        const optimized = self.stats.stack_allocated + self.stats.scalar_replaced;
        return @as(f64, @floatFromInt(optimized)) / 
               @as(f64, @floatFromInt(self.stats.total_allocations)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION SUMMARY - For interprocedural analysis
// ═══════════════════════════════════════════════════════════════════════════════

pub const FunctionSummary = struct {
    name: []const u8,
    param_escape: std.ArrayList(EscapeState),
    return_escape: EscapeState = .no_escape,
    allocations: std.ArrayList(u32),
    
    pub fn init(allocator: Allocator, name: []const u8) FunctionSummary {
        return .{
            .name = name,
            .param_escape = std.ArrayList(EscapeState).init(allocator),
            .allocations = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *FunctionSummary) void {
        self.param_escape.deinit();
        self.allocations.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCALAR REPLACEMENT - Field decomposition
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScalarReplacer = struct {
    allocator: Allocator,
    replacements: std.AutoHashMap(u32, ScalarReplacement),
    stats: ScalarStats = .{},
    
    pub fn init(allocator: Allocator) ScalarReplacer {
        return .{
            .allocator = allocator,
            .replacements = std.AutoHashMap(u32, ScalarReplacement).init(allocator),
        };
    }
    
    pub fn deinit(self: *ScalarReplacer) void {
        var iter = self.replacements.valueIterator();
        while (iter.next()) |rep| {
            rep.field_vars.deinit();
        }
        self.replacements.deinit();
    }
    
    /// Replace allocation with scalar variables
    pub fn replace(self: *ScalarReplacer, alloc_id: u32, field_count: u8) !void {
        var rep = ScalarReplacement{
            .alloc_id = alloc_id,
            .field_vars = std.ArrayList(u32).init(self.allocator),
        };
        
        // Create virtual registers for each field
        for (0..field_count) |i| {
            const var_id = self.stats.vars_created;
            try rep.field_vars.append(var_id);
            self.stats.vars_created += 1;
            _ = i;
        }
        
        try self.replacements.put(alloc_id, rep);
        self.stats.objects_replaced += 1;
    }
    
    /// Get field variable for replaced allocation
    pub fn getFieldVar(self: *const ScalarReplacer, alloc_id: u32, field_idx: u8) ?u32 {
        if (self.replacements.get(alloc_id)) |rep| {
            if (field_idx < rep.field_vars.items.len) {
                return rep.field_vars.items[field_idx];
            }
        }
        return null;
    }
    
    /// Check if allocation was replaced
    pub fn isReplaced(self: *const ScalarReplacer, alloc_id: u32) bool {
        return self.replacements.contains(alloc_id);
    }
};

pub const ScalarReplacement = struct {
    alloc_id: u32,
    field_vars: std.ArrayList(u32),
};

pub const ScalarStats = struct {
    objects_replaced: u64 = 0,
    vars_created: u32 = 0,
    loads_eliminated: u64 = 0,
    stores_eliminated: u64 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// STACK ALLOCATOR - Stack allocation transformation
// ═══════════════════════════════════════════════════════════════════════════════

pub const StackAllocator = struct {
    allocator: Allocator,
    stack_slots: std.ArrayList(StackSlot),
    current_offset: u32 = 0,
    stats: StackStats = .{},
    
    pub fn init(allocator: Allocator) StackAllocator {
        return .{
            .allocator = allocator,
            .stack_slots = std.ArrayList(StackSlot).init(allocator),
        };
    }
    
    pub fn deinit(self: *StackAllocator) void {
        self.stack_slots.deinit();
    }
    
    /// Allocate object on stack
    pub fn allocate(self: *StackAllocator, alloc_id: u32, size: u32, alignment: u32) !u32 {
        // Align offset
        const aligned_offset = std.mem.alignForward(u32, self.current_offset, alignment);
        
        const slot = StackSlot{
            .alloc_id = alloc_id,
            .offset = aligned_offset,
            .size = size,
        };
        
        try self.stack_slots.append(slot);
        self.current_offset = aligned_offset + size;
        self.stats.stack_bytes += size;
        self.stats.allocations_moved += 1;
        
        return aligned_offset;
    }
    
    /// Get stack offset for allocation
    pub fn getOffset(self: *const StackAllocator, alloc_id: u32) ?u32 {
        for (self.stack_slots.items) |slot| {
            if (slot.alloc_id == alloc_id) {
                return slot.offset;
            }
        }
        return null;
    }
    
    /// Get total stack frame size
    pub fn frameSize(self: *const StackAllocator) u32 {
        return std.mem.alignForward(u32, self.current_offset, 16);
    }
};

pub const StackSlot = struct {
    alloc_id: u32,
    offset: u32,
    size: u32,
};

pub const StackStats = struct {
    allocations_moved: u64 = 0,
    stack_bytes: u64 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION AND STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const EscapeConfig = struct {
    /// Maximum size for stack allocation (bytes)
    max_stack_alloc_size: u32 = 4096,
    /// Maximum fields for scalar replacement
    max_scalar_fields: u8 = 16,
    /// Maximum size for scalar replacement (bytes)
    max_scalar_size: u32 = 256,
    /// Maximum analysis iterations
    max_iterations: u32 = 100,
    /// Enable interprocedural analysis
    interprocedural: bool = true,
    /// Sacred threshold factor (φ-based)
    sacred_threshold: f64 = PHI,
};

pub const EscapeStats = struct {
    total_allocations: u64 = 0,
    stack_allocated: u64 = 0,
    scalar_replaced: u64 = 0,
    global_escapes: u64 = 0,
    arg_escapes: u64 = 0,
    analysis_iterations: u32 = 0,
    
    pub fn heapReduction(self: *const EscapeStats) f64 {
        if (self.total_allocations == 0) return 0.0;
        const optimized = self.stack_allocated + self.scalar_replaced;
        return @as(f64, @floatFromInt(optimized)) / 
               @as(f64, @floatFromInt(self.total_allocations)) * 100.0;
    }
};

pub const OptimizationDecision = struct {
    escape_state: EscapeState,
    stack_allocate: bool,
    scalar_replace: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "EscapeState lattice" {
    try std.testing.expectEqual(EscapeState.no_escape, EscapeState.no_escape.join(.no_escape));
    try std.testing.expectEqual(EscapeState.arg_escape, EscapeState.no_escape.join(.arg_escape));
    try std.testing.expectEqual(EscapeState.global_escape, EscapeState.arg_escape.join(.global_escape));
    try std.testing.expect(EscapeState.no_escape.canStackAllocate());
    try std.testing.expect(!EscapeState.global_escape.canStackAllocate());
}

test "EscapeAnalyzer basic" {
    const allocator = std.testing.allocator;
    var analyzer = EscapeAnalyzer.init(allocator, .{});
    defer analyzer.deinit();
    
    // Register allocations
    const alloc1 = try analyzer.registerAllocation(0, 1, 64, 4);
    const alloc2 = try analyzer.registerAllocation(1, 2, 128, 8);
    
    // Mark alloc2 as escaping
    analyzer.markGlobalEscape(alloc2);
    
    // Run analysis
    try analyzer.analyze();
    
    // Check decisions
    const dec1 = analyzer.getDecision(alloc1).?;
    const dec2 = analyzer.getDecision(alloc2).?;
    
    try std.testing.expect(dec1.stack_allocate);
    try std.testing.expect(!dec2.stack_allocate);
}

test "ScalarReplacer" {
    const allocator = std.testing.allocator;
    var replacer = ScalarReplacer.init(allocator);
    defer replacer.deinit();
    
    try replacer.replace(0, 4);
    
    try std.testing.expect(replacer.isReplaced(0));
    try std.testing.expect(!replacer.isReplaced(1));
    try std.testing.expect(replacer.getFieldVar(0, 0) != null);
    try std.testing.expect(replacer.getFieldVar(0, 3) != null);
    try std.testing.expect(replacer.getFieldVar(0, 4) == null);
}

test "StackAllocator" {
    const allocator = std.testing.allocator;
    var stack = StackAllocator.init(allocator);
    defer stack.deinit();
    
    const off1 = try stack.allocate(0, 64, 8);
    const off2 = try stack.allocate(1, 32, 8);
    
    try std.testing.expectEqual(@as(u32, 0), off1);
    try std.testing.expectEqual(@as(u32, 64), off2);
    try std.testing.expectEqual(@as(u32, 96), stack.current_offset);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
