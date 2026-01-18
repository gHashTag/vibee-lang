//! VIBEE Dead Code Eliminator - PAS DAEMON V40
//! Паттерны: D&C (reverse post-order traversal), HSH (live set), PRE (cached liveness)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// INSTRUCTION REPRESENTATION (simplified for DCE)
// ═══════════════════════════════════════════════════════════════════════════════

pub const InstrKind = enum {
    // Pure (no side effects)
    add,
    sub,
    mul,
    div,
    cmp,
    phi,
    load,
    
    // Side effects (always live)
    store,
    call,
    ret,
    br,
    br_cond,
    
    // Constants
    const_int,
    const_float,
};

pub const Instruction = struct {
    id: u32,
    kind: InstrKind,
    result: ?u32 = null,      // Result value ID
    operands: [4]?u32 = .{ null, null, null, null },
    operand_count: u8 = 0,
    block_id: u32 = 0,
    is_dead: bool = false,
    
    pub fn init(id: u32, kind: InstrKind) Instruction {
        return .{ .id = id, .kind = kind };
    }
    
    pub fn withResult(id: u32, kind: InstrKind, result: u32) Instruction {
        var inst = Instruction.init(id, kind);
        inst.result = result;
        return inst;
    }
    
    pub fn addOperand(self: *Instruction, op: u32) void {
        if (self.operand_count < 4) {
            self.operands[self.operand_count] = op;
            self.operand_count += 1;
        }
    }
    
    pub fn hasSideEffects(self: *const Instruction) bool {
        return switch (self.kind) {
            .store, .call, .ret, .br, .br_cond => true,
            else => false,
        };
    }
    
    pub fn isTerminator(self: *const Instruction) bool {
        return self.kind == .ret or self.kind == .br or self.kind == .br_cond;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BASIC BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

pub const BasicBlock = struct {
    id: u32,
    instructions: std.ArrayList(Instruction),
    predecessors: std.ArrayList(u32),
    successors: std.ArrayList(u32),
    is_reachable: bool = true,
    
    pub fn init(allocator: Allocator, id: u32) BasicBlock {
        return .{
            .id = id,
            .instructions = std.ArrayList(Instruction).init(allocator),
            .predecessors = std.ArrayList(u32).init(allocator),
            .successors = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *BasicBlock) void {
        self.instructions.deinit();
        self.predecessors.deinit();
        self.successors.deinit();
    }
    
    pub fn append(self: *BasicBlock, inst: Instruction) !void {
        var mutable_inst = inst;
        mutable_inst.block_id = self.id;
        try self.instructions.append(mutable_inst);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Function = struct {
    allocator: Allocator,
    name: []const u8,
    blocks: std.ArrayList(BasicBlock),
    entry_block: u32 = 0,
    
    pub fn init(allocator: Allocator, name: []const u8) Function {
        return .{
            .allocator = allocator,
            .name = name,
            .blocks = std.ArrayList(BasicBlock).init(allocator),
        };
    }
    
    pub fn deinit(self: *Function) void {
        for (self.blocks.items) |*block| {
            block.deinit();
        }
        self.blocks.deinit();
    }
    
    pub fn createBlock(self: *Function) !*BasicBlock {
        const id: u32 = @truncate(self.blocks.items.len);
        try self.blocks.append(BasicBlock.init(self.allocator, id));
        return &self.blocks.items[self.blocks.items.len - 1];
    }
    
    pub fn getBlock(self: *Function, id: u32) ?*BasicBlock {
        if (id < self.blocks.items.len) {
            return &self.blocks.items[id];
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEAD CODE ELIMINATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const DeadCodeEliminator = struct {
    allocator: Allocator,
    
    // Live values (HSH pattern)
    live_values: std.AutoHashMap(u32, void),
    
    // Worklist for iterative analysis
    worklist: std.ArrayList(u32),
    
    // Statistics
    stats: DCEStats = .{},
    
    pub fn init(allocator: Allocator) DeadCodeEliminator {
        return .{
            .allocator = allocator,
            .live_values = std.AutoHashMap(u32, void).init(allocator),
            .worklist = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *DeadCodeEliminator) void {
        self.live_values.deinit();
        self.worklist.deinit();
    }
    
    /// Eliminate dead code from function
    pub fn eliminate(self: *DeadCodeEliminator, func: *Function) !void {
        // Phase 1: Mark unreachable blocks
        try self.markReachableBlocks(func);
        
        // Phase 2: Mark live values (reverse traversal - D&C pattern)
        try self.markLiveValues(func);
        
        // Phase 3: Sweep dead instructions
        self.sweepDeadInstructions(func);
    }
    
    /// Mark reachable blocks from entry (D&C pattern)
    fn markReachableBlocks(self: *DeadCodeEliminator, func: *Function) !void {
        // Reset all blocks to unreachable
        for (func.blocks.items) |*block| {
            block.is_reachable = false;
        }
        
        // BFS from entry
        self.worklist.clearRetainingCapacity();
        try self.worklist.append(func.entry_block);
        
        while (self.worklist.items.len > 0) {
            const block_id = self.worklist.pop();
            
            if (func.getBlock(block_id)) |block| {
                if (block.is_reachable) continue;
                block.is_reachable = true;
                
                for (block.successors.items) |succ_id| {
                    try self.worklist.append(succ_id);
                }
            }
        }
        
        // Count unreachable blocks
        for (func.blocks.items) |block| {
            if (!block.is_reachable) {
                self.stats.unreachable_blocks += 1;
            }
        }
    }
    
    /// Mark live values using reverse traversal
    fn markLiveValues(self: *DeadCodeEliminator, func: *Function) !void {
        self.live_values.clearRetainingCapacity();
        self.worklist.clearRetainingCapacity();
        
        // Initial: all side-effecting instructions are live
        for (func.blocks.items) |block| {
            if (!block.is_reachable) continue;
            
            for (block.instructions.items) |inst| {
                if (inst.hasSideEffects()) {
                    // Mark operands as live
                    for (0..inst.operand_count) |i| {
                        if (inst.operands[i]) |op| {
                            if (!self.live_values.contains(op)) {
                                try self.live_values.put(op, {});
                                try self.worklist.append(op);
                            }
                        }
                    }
                }
            }
        }
        
        // Propagate liveness backwards
        while (self.worklist.items.len > 0) {
            const value_id = self.worklist.pop();
            
            // Find defining instruction
            for (func.blocks.items) |block| {
                if (!block.is_reachable) continue;
                
                for (block.instructions.items) |inst| {
                    if (inst.result == value_id) {
                        // Mark operands as live
                        for (0..inst.operand_count) |i| {
                            if (inst.operands[i]) |op| {
                                if (!self.live_values.contains(op)) {
                                    try self.live_values.put(op, {});
                                    try self.worklist.append(op);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Remove dead instructions
    fn sweepDeadInstructions(self: *DeadCodeEliminator, func: *Function) void {
        for (func.blocks.items) |*block| {
            if (!block.is_reachable) {
                // Remove all instructions from unreachable blocks
                self.stats.dead_instructions += block.instructions.items.len;
                block.instructions.clearRetainingCapacity();
                continue;
            }
            
            // Mark dead instructions
            for (block.instructions.items) |*inst| {
                if (inst.result) |result| {
                    if (!inst.hasSideEffects() and !self.live_values.contains(result)) {
                        inst.is_dead = true;
                        self.stats.dead_instructions += 1;
                    }
                }
            }
            
            // Remove dead instructions (in-place filter)
            var write_idx: usize = 0;
            for (block.instructions.items) |inst| {
                if (!inst.is_dead) {
                    block.instructions.items[write_idx] = inst;
                    write_idx += 1;
                }
            }
            block.instructions.shrinkRetainingCapacity(write_idx);
        }
    }
    
    /// Get statistics
    pub fn getStats(self: *const DeadCodeEliminator) DCEStats {
        return self.stats;
    }
    
    /// Reset for reuse
    pub fn reset(self: *DeadCodeEliminator) void {
        self.live_values.clearRetainingCapacity();
        self.worklist.clearRetainingCapacity();
        self.stats = .{};
    }
};

pub const DCEStats = struct {
    dead_instructions: u64 = 0,
    unreachable_blocks: u64 = 0,
    
    pub fn totalEliminated(self: *const DCEStats) u64 {
        return self.dead_instructions;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AGGRESSIVE DCE - More aggressive elimination
// ═══════════════════════════════════════════════════════════════════════════════

pub const AggressiveDCE = struct {
    allocator: Allocator,
    live_instructions: std.AutoHashMap(u32, void),
    
    pub fn init(allocator: Allocator) AggressiveDCE {
        return .{
            .allocator = allocator,
            .live_instructions = std.AutoHashMap(u32, void).init(allocator),
        };
    }
    
    pub fn deinit(self: *AggressiveDCE) void {
        self.live_instructions.deinit();
    }
    
    /// Mark instruction as live
    pub fn markLive(self: *AggressiveDCE, inst_id: u32) !void {
        try self.live_instructions.put(inst_id, {});
    }
    
    /// Check if instruction is live
    pub fn isLive(self: *const AggressiveDCE, inst_id: u32) bool {
        return self.live_instructions.contains(inst_id);
    }
    
    /// Get live instruction count
    pub fn liveCount(self: *const AggressiveDCE) usize {
        return self.live_instructions.count();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "DCE basic elimination" {
    const allocator = std.testing.allocator;
    var func = Function.init(allocator, "test");
    defer func.deinit();
    
    const entry = try func.createBlock();
    
    // Live: used by return
    const inst1 = Instruction.withResult(0, .const_int, 0);
    try entry.append(inst1);
    
    // Dead: result never used
    var inst2 = Instruction.withResult(1, .add, 1);
    inst2.addOperand(0);
    inst2.addOperand(0);
    try entry.append(inst2);
    
    // Live: return (side effect)
    var ret = Instruction.init(2, .ret);
    ret.addOperand(0);
    try entry.append(ret);
    
    var dce = DeadCodeEliminator.init(allocator);
    defer dce.deinit();
    
    try dce.eliminate(&func);
    
    // Dead instruction should be eliminated
    try std.testing.expectEqual(@as(u64, 1), dce.stats.dead_instructions);
    try std.testing.expectEqual(@as(usize, 2), entry.instructions.items.len);
}

test "DCE unreachable block" {
    const allocator = std.testing.allocator;
    var func = Function.init(allocator, "test");
    defer func.deinit();
    
    const entry = try func.createBlock();
    const unreachable_block = try func.createBlock();
    
    // Entry block with return
    const ret = Instruction.init(0, .ret);
    try entry.append(ret);
    
    // Unreachable block with instructions
    const dead_inst = Instruction.withResult(1, .add, 1);
    try unreachable_block.append(dead_inst);
    
    var dce = DeadCodeEliminator.init(allocator);
    defer dce.deinit();
    
    try dce.eliminate(&func);
    
    try std.testing.expectEqual(@as(u64, 1), dce.stats.unreachable_blocks);
    try std.testing.expectEqual(@as(usize, 0), unreachable_block.instructions.items.len);
}

test "DCE preserves side effects" {
    const allocator = std.testing.allocator;
    var func = Function.init(allocator, "test");
    defer func.deinit();
    
    const entry = try func.createBlock();
    
    // Store (side effect) - should be preserved
    var store = Instruction.init(0, .store);
    store.addOperand(0);
    try entry.append(store);
    
    // Call (side effect) - should be preserved
    const call = Instruction.init(1, .call);
    try entry.append(call);
    
    // Return
    const ret = Instruction.init(2, .ret);
    try entry.append(ret);
    
    var dce = DeadCodeEliminator.init(allocator);
    defer dce.deinit();
    
    try dce.eliminate(&func);
    
    // All instructions should be preserved
    try std.testing.expectEqual(@as(usize, 3), entry.instructions.items.len);
}

test "DCE chain elimination" {
    const allocator = std.testing.allocator;
    var func = Function.init(allocator, "test");
    defer func.deinit();
    
    const entry = try func.createBlock();
    
    // Dead chain: a = 1, b = a + 1, c = b + 1 (none used)
    const inst_a = Instruction.withResult(0, .const_int, 0);
    try entry.append(inst_a);
    
    var inst_b = Instruction.withResult(1, .add, 1);
    inst_b.addOperand(0);
    try entry.append(inst_b);
    
    var inst_c = Instruction.withResult(2, .add, 2);
    inst_c.addOperand(1);
    try entry.append(inst_c);
    
    // Return without using any of the above
    const ret = Instruction.init(3, .ret);
    try entry.append(ret);
    
    var dce = DeadCodeEliminator.init(allocator);
    defer dce.deinit();
    
    try dce.eliminate(&func);
    
    // All dead instructions should be eliminated
    try std.testing.expectEqual(@as(u64, 3), dce.stats.dead_instructions);
    try std.testing.expectEqual(@as(usize, 1), entry.instructions.items.len);
}

test "AggressiveDCE" {
    const allocator = std.testing.allocator;
    var adce = AggressiveDCE.init(allocator);
    defer adce.deinit();
    
    try adce.markLive(1);
    try adce.markLive(3);
    try adce.markLive(5);
    
    try std.testing.expect(adce.isLive(1));
    try std.testing.expect(!adce.isLive(2));
    try std.testing.expect(adce.isLive(3));
    try std.testing.expectEqual(@as(usize, 3), adce.liveCount());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
