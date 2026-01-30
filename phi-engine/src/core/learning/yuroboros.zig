const std = @import("std");
const level0 = @import("level0.zig");

// Import Sacred Constants
pub const PHI = level0.PHI;
pub const TRINITY = level0.TRINITY;

// ═══════════════════════════════════════════════════════════
// LEVEL 2: YUROBOROS ENGINE (Уровень Балансировки)
// Dynamic Difficulty & Network Balancing for VIBEE
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// YUROBOROS DIFFICULTY SYSTEM
// ═══════════════════════════════════════════════════════════

pub const DifficultyRating = enum(u16) {
    EASY = 1,
    NORMAL = 10,
    HARD = 50,
    EXPERT = 100,
    GODLIKE = 500,
};

pub const YuroborosDifficulty = struct {
    // Base Difficulty (базовая сложность)
    base: f64 = 1.0,

    // Scaling Factor (коэффициент масштабирования)
    scaling: f64 = 1.0,

    // Adaptive Difficulty (адаптивная сложность)
    adaptive: f64 = 0.0,

    // Target Difficulty (целевая сложность)
    target: f64 = 100.0,

    // Difficulty Rating (оценка сложности 1-999)
    pub fn getRating(self: *const YuroborosDifficulty) DifficultyRating {
        const D = self.adaptive;
        if (D < 1.0) return .EASY else if (D < 10.0) return .NORMAL else if (D < 50.0) return .HARD else if (D < 100.0) return .EXPERT else if (D < 500.0) return .GODLIKE else return .GODLIKE;
    }

    pub fn getRatingString(self: *const YuroborosDifficulty) []const u8 {
        return switch (self.getRating()) {
            .EASY => "EASY",
            .NORMAL => "NORMAL",
            .HARD => "HARD",
            .EXPERT => "EXPERT",
            .GODLIKE => "GODLIKE",
        };
    }
};

// ═══════════════════════════════════════════════════════════
// YUROBOROS NETWORK STATE
// ═══════════════════════════════════════════════════════════

pub const YuroborosNetworkState = struct {
    // Total Tasks (общее количество задач)
    total_tasks: u64 = 0,

    // Pending Tasks (ожидающие выполнения)
    pending_tasks: u64 = 0,

    // Completed Tasks (выполненные задачи)
    completed_tasks: u64 = 0,

    // Network Utility (полезность сети 0.0 to 1.0)
    utility: f64 = 1.0,

    // Calculate network utility based on task completion
    pub fn update(self: *YuroborosNetworkState, completed: u64, total: u64) void {
        self.total_tasks = total;
        self.completed_tasks = completed;
        self.pending_tasks = total - completed;

        // Calculate utility (0.0 to 1.0)
        if (total == 0) {
            self.utility = 1.0;
        } else {
            self.utility = @as(f64, @floatFromInt(completed)) / @as(f64, @floatFromInt(total));
        }
    }

    // Get network status
    pub fn getStatus(self: *const YuroborosNetworkState) []const u8 {
        const utilization = self.utility * 100.0;
        if (utilization < 20.0) return "IDLE" else if (utilization < 50.0) return "LOW" else if (utilization < 80.0) return "MEDIUM" else if (utilization < 100.0) return "HIGH" else return "OVERLOAD";
    }
};

// ═══════════════════════════════════════════════════════════
// YUROBOROS TASK
// ═══════════════════════════════════════════════════════════

pub const YuroborosTask = struct {
    id: u64,
    difficulty: f64,
    base_reward: f64,
    actual_reward: f64,
    timestamp: i64,
};

// ═══════════════════════════════════════════════════════════
// YUROBOROS ENGINE (Основной компонент)
// ═══════════════════════════════════════════════════════════

pub const YuroborosEngine = struct {
    allocator: std.mem.Allocator,
    difficulty: YuroborosDifficulty,
    network: YuroborosNetworkState,
    tasks: std.ArrayList(YuroborosTask),

    // Initialize Yuroboros Engine
    pub fn init(allocator: std.mem.Allocator) !YuroborosEngine {
        const difficulty = YuroborosDifficulty{};
        const network = YuroborosNetworkState{};
        const tasks = try std.ArrayList(YuroborosTask).initCapacity(allocator, 0);

        return YuroborosEngine{
            .allocator = allocator,
            .difficulty = difficulty,
            .network = network,
            .tasks = tasks,
        };
    }

    // Calculate Difficulty based on network state
    pub fn calculateDifficulty(self: *YuroborosEngine, base_difficulty: f64) f64 {
        _ = base_difficulty; // Use self.difficulty.base instead
        const S = self.difficulty.base * self.difficulty.scaling * self.network.utility;

        // Adaptive difficulty adjustment
        const target_utility = 0.5; // Optimal network utilization
        const utility_gap = target_utility - self.network.utility;

        // Gradual adjustment with φ factor
        const phi_factor = (PHI - 1.0) / PHI; // 0.382
        self.difficulty.adaptive = S * (1.0 + utility_gap * phi_factor);

        // Clamp adaptive difficulty to target range
        const adaptive_clamped = std.math.clamp(self.difficulty.adaptive, 0.1, self.difficulty.target);

        // Final difficulty D = ⌊S_adaptive⌋ (clamp to 1-999)
        const D = std.math.floor(adaptive_clamped);
        const D_clamped = std.math.clamp(D, 1.0, 999.0);

        return D_clamped;
    }

    // Update Network State based on task completion
    pub fn updateNetworkState(self: *YuroborosEngine, tasks_completed: u64, total_tasks: u64) void {
        self.network.update(tasks_completed, total_tasks);

        // Adjust scaling factor based on network status
        const network_status = self.network.getStatus();
        const status_slice: []const u8 = network_status;

        if (std.mem.eql(u8, status_slice, "IDLE")) {
            // Network is idle, increase difficulty faster
            self.difficulty.scaling *= 1.02;
        } else if (std.mem.eql(u8, status_slice, "OVERLOAD")) {
            // Network is overloaded, decrease difficulty faster
            self.difficulty.scaling *= 0.98;
        }

        // Clamp scaling factor
        self.difficulty.scaling = std.math.clamp(self.difficulty.scaling, 0.5, 2.0);
    }

    // Get current difficulty level (1-999)
    pub fn getDifficulty(self: *const YuroborosEngine) u32 {
        return @intFromFloat(self.difficulty.adaptive);
    }

    // Get difficulty rating (EASY, NORMAL, HARD, EXPERT, GODLIKE)
    pub fn getDifficultyRating(self: *const YuroborosEngine) DifficultyRating {
        return self.difficulty.getRating();
    }

    // Get difficulty rating string
    pub fn getDifficultyRatingString(self: *const YuroborosEngine) []const u8 {
        return self.difficulty.getRatingString();
    }

    // Calculate task reward based on difficulty and network state
    pub fn calculateTaskReward(self: *const YuroborosEngine, task_difficulty: f64) f64 {
        const base_reward = 10.0;
        const difficulty_multiplier = task_difficulty / 100.0;
        const network_multiplier = self.network.utility;

        const reward = base_reward * difficulty_multiplier * network_multiplier;
        return reward;
    }

    // Add task to queue
    pub fn addTask(self: *YuroborosEngine, task_id: u64, task_difficulty: f64) !void {
        const task = YuroborosTask{
            .id = task_id,
            .difficulty = task_difficulty,
            .base_reward = self.calculateTaskReward(task_difficulty),
            .actual_reward = 0.0,
            .timestamp = std.time.timestamp(),
        };

        try self.tasks.append(self.allocator, task);

        // Update total tasks
        self.network.total_tasks = self.network.total_tasks + 1;
        self.network.pending_tasks = self.network.total_tasks - self.network.completed_tasks;
    }

    // Complete task and update state
    pub fn completeTask(self: *YuroborosEngine, task_id: u64) !void {
        var task_index: ?usize = null;

        for (self.tasks.items, 0..) |task, i| {
            if (task.id == task_id) {
                task_index = i;
                break;
            }
        }

        if (task_index == null) {
            return error.TaskNotFound;
        }

        const task = &self.tasks.items[task_index.?];

        // Calculate actual reward based on time taken
        const time_taken = std.time.timestamp() - task.timestamp;
        const time_threshold = @as(i64, 3600.0);
        const time_penalty_f: f64 = if (time_taken > time_threshold) 0.5 else 1.0;
        const time_penalty = if (time_penalty_f > 0.75) @as(f64, 1.0) else time_penalty_f;
        task.actual_reward = task.base_reward * time_penalty;

        // Update network state
        self.updateNetworkState(self.network.completed_tasks + 1, self.network.total_tasks);

        // Rebalance difficulty based on completed tasks
        const D = self.calculateDifficulty(self.difficulty.base);
        self.difficulty.adaptive = D;
    }

    // Get current network statistics
    pub fn getNetworkStats(self: *const YuroborosEngine) NetworkStats {
        return NetworkStats{
            .total_tasks = self.network.total_tasks,
            .completed_tasks = self.network.completed_tasks,
            .pending_tasks = self.network.pending_tasks,
            .network_utility = self.network.utility,
            .network_status = self.network.getStatus(),
            .difficulty = self.getDifficulty(),
            .difficulty_rating = self.getDifficultyRating(),
            .difficulty_rating_string = self.getDifficultyRatingString(),
        };
    }

    // Deallocate engine
    pub fn deinit(self: *YuroborosEngine) void {
        self.tasks.deinit(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════
// NETWORK STATISTICS
// ═══════════════════════════════════════════════════════════

pub const NetworkStats = struct {
    total_tasks: u64,
    completed_tasks: u64,
    pending_tasks: u64,
    network_utility: f64,
    network_status: []const u8,
    difficulty: u32,
    difficulty_rating: DifficultyRating,
    difficulty_rating_string: []const u8,
};

// ═══════════════════════════════════════════════════════════
// YUROBOROS DEMONSTRATION
// ═══════════════════════════════════════════════════════════

pub fn main() !void {
    try demo();
}

pub fn demo() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("╔══════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           YUROBOROS ENGINE DEMO               ║\n", .{});
    std.debug.print("║         Dynamic Difficulty & Network Balancing  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});

    var engine = try YuroborosEngine.init(allocator);
    defer engine.deinit();

    // Add some tasks
    std.debug.print("Adding tasks...\n", .{});
    try engine.addTask(1, 500.0); // Godlike difficulty
    try engine.addTask(2, 100.0); // Expert difficulty
    try engine.addTask(3, 50.0); // Hard difficulty
    try engine.addTask(4, 10.0); // Easy difficulty

    std.debug.print("\nInitial state:\n", .{});
    const initial_stats = engine.getNetworkStats();
    printNetworkStats(&initial_stats);

    // Simulate task completion
    std.debug.print("\nCompleting tasks...\n", .{});
    try engine.completeTask(1);
    try engine.completeTask(2);
    try engine.completeTask(3);

    std.debug.print("\nFinal state:\n", .{});
    const final_stats = engine.getNetworkStats();
    printNetworkStats(&final_stats);

    std.debug.print("\n╔══════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                   DEMO COMPLETE                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});
    std.debug.print("🎯 YUROBOROS SUCCESSFULLY:\n", .{});
    std.debug.print("  ✓ Dynamic Difficulty Engine\n", .{});
    std.debug.print("  ✓ Network Balancing\n", .{});
    std.debug.print("  ✓ Adaptive Difficulty\n", .{});
    std.debug.print("  ✓ Task Reward Calculation\n", .{});
}

pub fn printNetworkStats(stats: *const NetworkStats) void {
    std.debug.print("  Network Stats:\n", .{});
    std.debug.print("    Total Tasks: {d}\n", .{stats.total_tasks});
    std.debug.print("    Completed: {d}\n", .{stats.completed_tasks});
    std.debug.print("    Pending: {d}\n", .{stats.pending_tasks});
    std.debug.print("    Utility: {d:.2}\n", .{stats.network_utility});
    std.debug.print("    Status: {s}\n", .{stats.network_status});
    std.debug.print("\n  Difficulty Stats:\n", .{});
    std.debug.print("    Level: {d}\n", .{stats.difficulty});
    std.debug.print("    Rating: {s}\n", .{stats.difficulty_rating_string});
}
