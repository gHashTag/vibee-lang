const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");

// Import Yuroboros Engine from Phi-Engine
const yuroboros = @import("phi-engine/src/core/learning/yuroboros.zig");

// ═════════════════════════════════════════════════════════
// TVC YUROBOROS INTEGRATION
// Integrates Yuroboros Engine with TVC for task difficulty,
// program complexity balancing, and reward calculation.
// ═════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════
// TVC TASK COMPLEXITY EVALUATION
// ═════════════════════════════════════════════════════════

pub const TVCTaskComplexity = struct {
    // Complexity Metrics
    instruction_count: u32,
    block_count: u32,
    nesting_depth: u32,
    trinary_complexity: u32,

    // Complexity Score (0.0 to 999.0)
    complexity_score: f64,

    // Calculate complexity from TVC Module
    pub fn calculateComplexity(module: *const tvc_ir.TVCModule) TVCTaskComplexity {
        var instruction_count: u32 = 0;
        var block_count: u32 = 0;
        var max_nesting: u32 = 0;

        for (module.functions.items) |func| {
            block_count += @as(u32, @intCast(func.blocks.items.len));

            for (func.blocks.items) |block| {
                instruction_count += @as(u32, @intCast(block.instructions.items.len));

                // Calculate nesting depth
                var current_nesting: u32 = 0;
                for (block.instructions.items) |inst| {
                    switch (inst.opcode) {
                        .label => current_nesting += 1,
                        .branch => current_nesting += 1,
                        .call => current_nesting += 1,
                        .ret => current_nesting -|= 1,
                        else => {},
                    }
                }

                if (current_nesting > max_nesting) {
                    max_nesting = current_nesting;
                }
            }
        }

        // Calculate trinary complexity (number of trinary operations)
        var trinary_complexity: u32 = 0;
        for (module.functions.items) |func| {
            for (func.blocks.items) |block| {
                for (block.instructions.items) |inst| {
                    switch (inst.opcode) {
                        .t_not, .t_and, .t_or, .t_xor, .t_implies => trinary_complexity += 1,
                        .t_add, .t_sub, .t_mul => trinary_complexity += 1,
                        else => {},
                    }
                }
            }
        }

        // Calculate complexity score (0.0 to 999.0)
        // Weight factors (tuned for TVC programs)
        const instruction_weight = 0.1;
        const block_weight = 1.0;
        const nesting_weight = 2.0;
        const trinary_weight = 0.5;

        const base_score = @as(f64, @floatFromInt(instruction_count)) * instruction_weight;
        const block_score = @as(f64, @floatFromInt(block_count)) * block_weight;
        const nesting_score = @as(f64, @floatFromInt(max_nesting)) * nesting_weight;
        const trinary_score = @as(f64, @floatFromInt(trinary_complexity)) * trinary_weight;

        const total_score = base_score + block_score + nesting_score + trinary_score;

        // Normalize to 0.0 to 999.0
        const normalized_score = if (total_score > 1000.0) 999.0 else if (total_score < 1.0) 1.0 else total_score;

        return TVCTaskComplexity{
            .instruction_count = instruction_count,
            .block_count = block_count,
            .nesting_depth = max_nesting,
            .trinary_complexity = trinary_complexity,
            .complexity_score = normalized_score,
        };
    }

    // Get complexity rating
    pub fn getRating(self: *const TVCTaskComplexity) yuroboros.DifficultyRating {
        if (self.complexity_score < 10.0) return .EASY else if (self.complexity_score < 50.0) return .NORMAL else if (self.complexity_score < 100.0) return .HARD else if (self.complexity_score < 500.0) return .EXPERT else return .GODLIKE;
    }

    pub fn getRatingString(self: *const TVCTaskComplexity) []const u8 {
        return switch (self.getRating()) {
            .EASY => "EASY",
            .NORMAL => "NORMAL",
            .HARD => "HARD",
            .EXPERT => "EXPERT",
            .GODLIKE => "GODLIKE",
        };
    }
};

// ═════════════════════════════════════════════════════════
// TVC YUROBOROS INTEGRATION ENGINE
// ═════════════════════════════════════════════════════════

pub const TVCYuroborosEngine = struct {
    allocator: std.mem.Allocator,
    yuroboros_engine: yuroboros.YuroborosEngine,
    task_rewards: std.ArrayList(f64),
    task_count: u64,

    pub fn init(allocator: std.mem.Allocator) !TVCYuroborosEngine {
        const yuroboros_engine = try yuroboros.YuroborosEngine.init(allocator);
        const task_rewards = std.ArrayList(f64).init(allocator);

        return TVCYuroborosEngine{
            .allocator = allocator,
            .yuroboros_engine = yuroboros_engine,
            .task_rewards = task_rewards,
            .task_count = 0,
        };
    }

    // Evaluate TVC task complexity
    pub fn evaluateTask(self: *TVCYuroborosEngine, module: *const tvc_ir.TVCModule) !TVCTaskComplexity {
        return TVCTaskComplexity.calculateComplexity(module);
    }

    // Execute TVC program with Yuroboros balancing
    pub fn executeProgram(self: *TVCYuroborosEngine, module: *const tvc_ir.TVCModule, execution_fn: fn (*const tvc_ir.TVCModule) !void) !void {
        const start_time = std.time.timestamp();

        // Execute program
        try execution_fn(module);

        const end_time = std.time.timestamp();
        const execution_time = end_time - start_time;

        // Evaluate complexity
        const complexity = TVCTaskComplexity.calculateComplexity(module);

        // Add task to Yuroboros
        try self.yuroboros_engine.addTask(@as(u64, @intFromFloat(std.time.timestamp())), complexity.complexity_score);

        // Complete task
        try self.yuroboros_engine.completeTask(@as(u64, @intFromFloat(std.time.timestamp())));

        // Increment task count
        self.task_count += 1;

        // Calculate reward
        const reward = complexity.complexity_score * 0.1;
        try self.task_rewards.append(reward);
    }

    // Get Yuroboros network statistics
    pub fn getNetworkStats(self: *const TVCYuroborosEngine) yuroboros.NetworkStats {
        return self.yuroboros_engine.getNetworkStats();
    }

    // Get TVC program difficulty
    pub fn getProgramDifficulty(self: *const TVCYuroborosEngine, module: *const tvc_ir.TVCModule) !f64 {
        const complexity = TVCTaskComplexity.calculateComplexity(module);
        return complexity.complexity_score;
    }

    // Get program difficulty rating
    pub fn getProgramDifficultyRating(self: *const TVCYuroborosEngine, module: *const tvc_ir.TVCModule) !yuroboros.DifficultyRating {
        const complexity = TVCTaskComplexity.calculateComplexity(module);
        return complexity.getRating();
    }

    // Get program difficulty rating string
    pub fn getProgramDifficultyRatingString(self: *const TVCYuroborosEngine, module: *const tvc_ir.TVCModule) ![]const u8 {
        const complexity = TVCTaskComplexity.calculateComplexity(module);
        return complexity.getRatingString();
    }

    // Get total rewards
    pub fn getTotalRewards(self: *const TVCYuroborosEngine) f64 {
        var total: f64 = 0.0;
        for (self.task_rewards.items) |reward| {
            total += reward;
        }
        return total;
    }

    // Get average reward
    pub fn getAverageReward(self: *const TVCYuroborosEngine) f64 {
        if (self.task_count == 0) return 0.0;
        return self.getTotalRewards() / @as(f64, @floatFromInt(self.task_count));
    }

    // Deallocate
    pub fn deinit(self: *TVCYuroborosEngine) void {
        self.yuroboros_engine.deinit();
        self.task_rewards.deinit();
    }
};

// ═════════════════════════════════════════════════════════
// DEMONSTRATION
// ═════════════════════════════════════════════════════════

pub fn demo() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("╔══════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║       TVC YUROBOROS INTEGRATION DEMO             ║\n", .{});
    std.debug.print("║  Integrating Yuroboros Engine with TVC               ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});

    var engine = try TVCYuroborosEngine.init(allocator);
    defer engine.deinit();

    // Create simple TVC module for demo
    var module = try createTestModule(allocator);
    defer module.deinit();

    // Evaluate task complexity
    std.debug.print("Evaluating TVC Task Complexity:\n", .{});
    const complexity = try engine.evaluateTask(&module);
    printComplexity(&complexity);

    // Get program difficulty
    std.debug.print("\nCalculating TVC Program Difficulty:\n", .{});
    const difficulty = try engine.getProgramDifficulty(&module);
    std.debug.print("  Difficulty: {d:.2}\n", .{difficulty});

    const rating = try engine.getProgramDifficultyRating(&module);
    const rating_string = try engine.getProgramDifficultyRatingString(&module);
    std.debug.print("  Rating: {s}\n", .{rating_string});

    // Simulate program execution
    std.debug.print("\nSimulating TVC Program Execution with Yuroboros:\n", .{});
    try engine.executeProgram(&module, executeTestModule);

    // Get network statistics
    std.debug.print("\nYuroboros Network Stats:\n", .{});
    const stats = engine.getNetworkStats();
    printNetworkStats(&stats);

    // Get rewards
    std.debug.print("\nTVC Task Rewards:\n", .{});
    const total_rewards = engine.getTotalRewards();
    const average_reward = engine.getAverageReward();
    std.debug.print("  Total Rewards: {d:.2}\n", .{total_rewards});
    std.debug.print("  Average Reward: {d:.2}\n", .{average_reward});
    std.debug.print("  Tasks Completed: {d}\n", .{engine.task_count});

    std.debug.print("\n╔══════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    DEMO COMPLETE                     ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});
    std.debug.print("🎯 TVC YUROBOROS SUCCESSFULLY:\n", .{});
    std.debug.print("  ✓ Task Complexity Evaluation\n", .{});
    std.debug.print("  ✓ Program Difficulty Balancing (with Yuroboros)\n", .{});
    std.debug.print("  ✓ Task Reward Calculation\n", .{});
    std.debug.print("  ✓ Integration with Yuroboros Engine\n", .{});
    std.debug.print("  ✓ Integration with TVC IR\n", .{});
}

pub fn createTestModule(allocator: std.mem.Allocator) !tvc_ir.TVCModule {
    var functions = std.ArrayList(tvc_ir.TVCFunction).init(allocator);

    // Create simple function
    var func = tvc_ir.TVCFunction{
        .name = "test_function",
        .args = &[_]tvc_ir.TVCSymbol{},
        .return_type = .i64_trit,
        .blocks = std.ArrayList(tvc_ir.TVCBlock).init(allocator),
        .entry_block = null,
    };

    // Create entry block
    var block = tvc_ir.TVCBlock{
        .name = "entry",
        .instructions = std.ArrayList(tvc_ir.TVCInstruction).init(allocator),
        .exit_point = 0,
    };

    // Add trinary operations
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_not,
        .operands = &[_]u64{0},
        .location = 0,
    });
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_and,
        .operands = &[_]u64{ 0, 1 },
        .location = 1,
    });
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_or,
        .operands = &[_]u64{ 0, 1 },
        .location = 2,
    });

    // Set exit point
    block.exit_point = @intCast(block.instructions.items.len - 1);

    // Add block to function
    try func.blocks.append(block);

    // Set entry block
    func.entry_block = &func.blocks.items[0];

    // Add function to module
    try functions.append(func);

    return tvc_ir.TVCModule{
        .name = "test_module",
        .functions = functions,
    };
}

pub fn executeTestModule(_module: *const tvc_ir.TVCModule) !void {
    // Simulate execution
    std.debug.print("  Executing TVC module...\n", .{});
    std.debug.print("  Function: {s}\n", .{_module.functions.items[0].name});
    std.debug.print("  Instructions: {d}\n", .{_module.functions.items[0].blocks.items[0].instructions.items.len});
}

pub fn printComplexity(complexity: *const TVCTaskComplexity) void {
    std.debug.print("  Instruction Count: {d}\n", .{complexity.instruction_count});
    std.debug.print("  Block Count: {d}\n", .{complexity.block_count});
    std.debug.print("  Nesting Depth: {d}\n", .{complexity.nesting_depth});
    std.debug.print("  Trinary Complexity: {d}\n", .{complexity.trinary_complexity});
    std.debug.print("  Complexity Score: {d:.2}\n", .{complexity.complexity_score});
    std.debug.print("  Complexity Rating: {s}\n", .{complexity.getRatingString()});
}

pub fn printNetworkStats(stats: *const yuroboros.NetworkStats) void {
    std.debug.print("  Total Tasks: {d}\n", .{stats.total_tasks});
    std.debug.print("  Completed: {d}\n", .{stats.completed_tasks});
    std.debug.print("  Pending: {d}\n", .{stats.pending_tasks});
    std.debug.print("  Utility: {d:.2}\n", .{stats.network_utility});
    std.debug.print("  Status: {s}\n", .{stats.network_status});
    std.debug.print("  Difficulty: {d}\n", .{stats.difficulty});
    std.debug.print("  Rating: {s}\n", .{stats.difficulty_rating_string});
}
