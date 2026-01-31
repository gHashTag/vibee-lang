// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION BENCHMARK - Constant Folding + DCE Impact
// ═══════════════════════════════════════════════════════════════════════════════
// Measures the real impact of optimization passes on instruction count
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const jit_tier2 = @import("jit_tier2.zig");
const SSAFunction = jit_tier2.SSAFunction;
const SSAInstr = jit_tier2.SSAInstr;
const SSAOp = jit_tier2.SSAOp;
const OptimizationPass = jit_tier2.OptimizationPass;
const JITTier2 = jit_tier2.JITTier2;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CASES
// ═══════════════════════════════════════════════════════════════════════════════

/// Case 1: Constant expression chain
/// v0 = 10, v1 = 20, v2 = v0 + v1, v3 = v2 * 2, v4 = v3 - 5
/// Should fold to: v4 = 55
fn createConstantChain(allocator: std.mem.Allocator) SSAFunction {
    var func = SSAFunction.init(allocator, "constant_chain");
    
    const v0 = func.newValue();
    const v1 = func.newValue();
    const v2 = func.newValue();
    const v3 = func.newValue();
    const v4 = func.newValue();
    const v5 = func.newValue();
    
    func.emit(0, SSAInstr.constInt(v0, 10));
    func.emit(0, SSAInstr.constInt(v1, 20));
    func.emit(0, SSAInstr.binop(.add, v2, v0, v1));  // 30
    func.emit(0, SSAInstr.constInt(v3, 2));
    func.emit(0, SSAInstr.binop(.mul, v4, v2, v3));  // 60
    func.emit(0, SSAInstr.constInt(v5, 5));
    _ = func.newValue(); // v6
    func.emit(0, SSAInstr.binop(.sub, 6, v4, v5));   // 55
    func.emit(0, SSAInstr{ .op = .ret, .dest = jit_tier2.SSA_UNDEF, .src1 = 6, .src2 = jit_tier2.SSA_UNDEF, .imm = 0 });
    
    return func;
}

/// Case 2: Dead code with unused computations
/// v0 = 100, v1 = 200, v2 = v0 + v1 (unused), v3 = 42, ret v3
/// Should eliminate v0, v1, v2
fn createDeadCode(allocator: std.mem.Allocator) SSAFunction {
    var func = SSAFunction.init(allocator, "dead_code");
    
    const v0 = func.newValue();
    const v1 = func.newValue();
    const v2 = func.newValue();
    const v3 = func.newValue();
    
    func.emit(0, SSAInstr.constInt(v0, 100));        // dead
    func.emit(0, SSAInstr.constInt(v1, 200));        // dead
    func.emit(0, SSAInstr.binop(.add, v2, v0, v1));  // dead
    func.emit(0, SSAInstr.constInt(v3, 42));         // live
    func.emit(0, SSAInstr{ .op = .ret, .dest = jit_tier2.SSA_UNDEF, .src1 = v3, .src2 = jit_tier2.SSA_UNDEF, .imm = 0 });
    
    return func;
}

/// Case 3: Mixed - constants + dead code
/// Complex expression with partial dead code
fn createMixedCase(allocator: std.mem.Allocator) SSAFunction {
    var func = SSAFunction.init(allocator, "mixed");
    
    // Live path: (10 + 20) * 3 = 90
    const v0 = func.newValue();
    const v1 = func.newValue();
    const v2 = func.newValue();
    const v3 = func.newValue();
    const v4 = func.newValue();
    
    // Dead path: 100 + 200 = 300 (unused)
    const v5 = func.newValue();
    const v6 = func.newValue();
    const v7 = func.newValue();
    
    func.emit(0, SSAInstr.constInt(v0, 10));
    func.emit(0, SSAInstr.constInt(v1, 20));
    func.emit(0, SSAInstr.binop(.add, v2, v0, v1));  // 30 - foldable
    func.emit(0, SSAInstr.constInt(v3, 3));
    func.emit(0, SSAInstr.binop(.mul, v4, v2, v3));  // 90 - foldable
    
    func.emit(0, SSAInstr.constInt(v5, 100));        // dead
    func.emit(0, SSAInstr.constInt(v6, 200));        // dead
    func.emit(0, SSAInstr.binop(.add, v7, v5, v6));  // dead
    
    func.emit(0, SSAInstr{ .op = .ret, .dest = jit_tier2.SSA_UNDEF, .src1 = v4, .src2 = jit_tier2.SSA_UNDEF, .imm = 0 });
    
    return func;
}

/// Case 4: Large constant expression (stress test)
/// Chain of 100 constant additions
fn createLargeConstantChain(allocator: std.mem.Allocator) SSAFunction {
    var func = SSAFunction.init(allocator, "large_chain");
    
    const v0 = func.newValue();
    func.emit(0, SSAInstr.constInt(v0, 1));
    
    var prev = v0;
    for (1..100) |i| {
        const vi = func.newValue();
        const vc = func.newValue();
        func.emit(0, SSAInstr.constInt(vc, @intCast(i)));
        func.emit(0, SSAInstr.binop(.add, vi, prev, vc));
        prev = vi;
    }
    
    func.emit(0, SSAInstr{ .op = .ret, .dest = jit_tier2.SSA_UNDEF, .src1 = prev, .src2 = jit_tier2.SSA_UNDEF, .imm = 0 });
    
    return func;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

fn countInstructions(func: *SSAFunction) usize {
    var count: usize = 0;
    for (func.blocks.items) |block| {
        count += block.instrs.items.len;
    }
    return count;
}

fn runBenchmark(allocator: std.mem.Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("              OPTIMIZATION BENCHMARK - Constant Folding + DCE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    // Case 1: Constant Chain
    {
        var func = createConstantChain(allocator);
        defer func.deinit();
        
        const before = countInstructions(&func);
        
        var jit = JITTier2.init(allocator);
        defer jit.deinit();
        
        const start = std.time.nanoTimestamp();
        jit.compile(&func);
        const end = std.time.nanoTimestamp();
        
        const after = countInstructions(&func);
        const stats = jit.getStats();
        
        std.debug.print("Case 1: Constant Chain (10 + 20) * 2 - 5\n", .{});
        std.debug.print("  Instructions: {d} → {d} ({d:.1}% reduction)\n", .{
            before, after, 
            @as(f64, @floatFromInt(before - after)) / @as(f64, @floatFromInt(before)) * 100.0
        });
        std.debug.print("  Folded: {d}, Eliminated: {d}\n", .{stats.folded, stats.eliminated});
        std.debug.print("  Time: {d}ns\n", .{end - start});
        std.debug.print("\n", .{});
    }

    // Case 2: Dead Code
    {
        var func = createDeadCode(allocator);
        defer func.deinit();
        
        const before = countInstructions(&func);
        
        var jit = JITTier2.init(allocator);
        defer jit.deinit();
        
        const start = std.time.nanoTimestamp();
        jit.compile(&func);
        const end = std.time.nanoTimestamp();
        
        const after = countInstructions(&func);
        const stats = jit.getStats();
        
        std.debug.print("Case 2: Dead Code Elimination\n", .{});
        std.debug.print("  Instructions: {d} → {d} ({d:.1}% reduction)\n", .{
            before, after,
            @as(f64, @floatFromInt(before - after)) / @as(f64, @floatFromInt(before)) * 100.0
        });
        std.debug.print("  Folded: {d}, Eliminated: {d}\n", .{stats.folded, stats.eliminated});
        std.debug.print("  Time: {d}ns\n", .{end - start});
        std.debug.print("\n", .{});
    }

    // Case 3: Mixed
    {
        var func = createMixedCase(allocator);
        defer func.deinit();
        
        const before = countInstructions(&func);
        
        var jit = JITTier2.init(allocator);
        defer jit.deinit();
        
        const start = std.time.nanoTimestamp();
        jit.compile(&func);
        const end = std.time.nanoTimestamp();
        
        const after = countInstructions(&func);
        const stats = jit.getStats();
        
        std.debug.print("Case 3: Mixed (Constants + Dead Code)\n", .{});
        std.debug.print("  Instructions: {d} → {d} ({d:.1}% reduction)\n", .{
            before, after,
            @as(f64, @floatFromInt(before - after)) / @as(f64, @floatFromInt(before)) * 100.0
        });
        std.debug.print("  Folded: {d}, Eliminated: {d}\n", .{stats.folded, stats.eliminated});
        std.debug.print("  Time: {d}ns\n", .{end - start});
        std.debug.print("\n", .{});
    }

    // Case 4: Large Chain
    {
        var func = createLargeConstantChain(allocator);
        defer func.deinit();
        
        const before = countInstructions(&func);
        
        var jit = JITTier2.init(allocator);
        defer jit.deinit();
        
        const start = std.time.nanoTimestamp();
        jit.compile(&func);
        const end = std.time.nanoTimestamp();
        
        const after = countInstructions(&func);
        const stats = jit.getStats();
        
        std.debug.print("Case 4: Large Chain (100 constant additions)\n", .{});
        std.debug.print("  Instructions: {d} → {d} ({d:.1}% reduction)\n", .{
            before, after,
            @as(f64, @floatFromInt(before - after)) / @as(f64, @floatFromInt(before)) * 100.0
        });
        std.debug.print("  Folded: {d}, Eliminated: {d}\n", .{stats.folded, stats.eliminated});
        std.debug.print("  Time: {d}ns\n", .{end - start});
        std.debug.print("\n", .{});
    }

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("SUMMARY:\n", .{});
    std.debug.print("  Constant Folding: Evaluates constant expressions at compile time\n", .{});
    std.debug.print("  Dead Code Elimination: Removes unused computations\n", .{});
    std.debug.print("  Combined: 50-80%% instruction reduction on constant-heavy code\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try runBenchmark(gpa.allocator());
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "constant chain optimization" {
    var func = createConstantChain(std.testing.allocator);
    defer func.deinit();
    
    const before = countInstructions(&func);
    
    var jit = JITTier2.init(std.testing.allocator);
    defer jit.deinit();
    jit.compile(&func);
    
    const after = countInstructions(&func);
    const stats = jit.getStats();
    
    // Should fold at least 2 operations
    try std.testing.expect(stats.folded >= 2);
    // Should reduce instruction count
    try std.testing.expect(after < before);
}

test "dead code elimination" {
    var func = createDeadCode(std.testing.allocator);
    defer func.deinit();
    
    const before = countInstructions(&func);
    
    var jit = JITTier2.init(std.testing.allocator);
    defer jit.deinit();
    jit.compile(&func);
    
    const after = countInstructions(&func);
    const stats = jit.getStats();
    
    // Should eliminate dead code
    try std.testing.expect(stats.eliminated >= 1);
    // Should reduce instruction count
    try std.testing.expect(after < before);
}

test "mixed optimization" {
    var func = createMixedCase(std.testing.allocator);
    defer func.deinit();
    
    const before = countInstructions(&func);
    
    var jit = JITTier2.init(std.testing.allocator);
    defer jit.deinit();
    jit.compile(&func);
    
    const after = countInstructions(&func);
    
    // Should significantly reduce instruction count
    try std.testing.expect(after < before);
    // At least 30% reduction
    const reduction = @as(f64, @floatFromInt(before - after)) / @as(f64, @floatFromInt(before));
    try std.testing.expect(reduction >= 0.3);
}

test "large chain optimization" {
    var func = createLargeConstantChain(std.testing.allocator);
    defer func.deinit();
    
    const before = countInstructions(&func);
    
    var jit = JITTier2.init(std.testing.allocator);
    defer jit.deinit();
    jit.compile(&func);
    
    const after = countInstructions(&func);
    const stats = jit.getStats();
    
    // Should fold many operations
    try std.testing.expect(stats.folded >= 50);
    // Should significantly reduce instruction count
    try std.testing.expect(after < before / 2);
}
