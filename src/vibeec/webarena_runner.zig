// VIBEE WebArena Runner - Full Pipeline
// Load task → Execute → Evaluate → Report
// For WebArena benchmark submission
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const browser_agent = @import("browser_agent.zig");
const task_mod = @import("webarena_task.zig");
const openai = @import("openai_client.zig");

pub const RunnerError = error{
    TaskLoadError,
    AgentError,
    FileError,
    OutOfMemory,
};

pub const RunnerConfig = struct {
    // LLM settings
    llm_api_key: []const u8,
    llm_provider: openai.Provider = .groq,
    llm_model: []const u8 = openai.GROQ_MODEL,

    // Browser settings
    browser_host: []const u8 = "localhost",
    browser_port: u16 = 9222,

    // Execution settings
    max_steps: u32 = 30,
    timeout_ms: u64 = 120000,
    verbose: bool = false,

    // Output settings
    save_trajectories: bool = true,
    output_dir: []const u8 = "results",
};

pub const TaskResult = struct {
    task_id: i64,
    success: bool,
    final_answer: ?[]const u8,
    steps_taken: u32,
    total_tokens: u32,
    elapsed_ms: u64,
    error_message: ?[]const u8,
};

pub const RunnerStats = struct {
    total_tasks: u32,
    successful_tasks: u32,
    failed_tasks: u32,
    total_steps: u32,
    total_tokens: u32,
    total_time_ms: u64,

    pub fn successRate(self: *const RunnerStats) f64 {
        if (self.total_tasks == 0) return 0;
        return @as(f64, @floatFromInt(self.successful_tasks)) / @as(f64, @floatFromInt(self.total_tasks)) * 100.0;
    }
};

pub const WebArenaRunner = struct {
    allocator: Allocator,
    config: RunnerConfig,
    stats: RunnerStats,
    results: std.ArrayList(TaskResult),

    const Self = @This();

    pub fn init(allocator: Allocator, config: RunnerConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .stats = RunnerStats{
                .total_tasks = 0,
                .successful_tasks = 0,
                .failed_tasks = 0,
                .total_steps = 0,
                .total_tokens = 0,
                .total_time_ms = 0,
            },
            .results = std.ArrayList(TaskResult).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit();
    }

    /// Run a single task from JSON string
    pub fn runTaskJson(self: *Self, task_json: []const u8) RunnerError!TaskResult {
        // Parse task
        var task = task_mod.parseTask(self.allocator, task_json) catch return RunnerError.TaskLoadError;
        defer task.deinit();

        return self.runTask(&task);
    }

    /// Run a single task
    pub fn runTask(self: *Self, task: *const task_mod.WebArenaTask) RunnerError!TaskResult {
        // Create agent
        var agent = browser_agent.BrowserAgent.init(self.allocator, .{
            .llm_api_key = self.config.llm_api_key,
            .llm_provider = self.config.llm_provider,
            .llm_model = self.config.llm_model,
            .browser_host = self.config.browser_host,
            .browser_port = self.config.browser_port,
            .max_steps = self.config.max_steps,
            .timeout_ms = self.config.timeout_ms,
            .verbose = self.config.verbose,
        });
        defer agent.deinit();

        // Connect to browser
        agent.connect() catch {
            return TaskResult{
                .task_id = task.task_id,
                .success = false,
                .final_answer = null,
                .steps_taken = 0,
                .total_tokens = 0,
                .elapsed_ms = 0,
                .error_message = "Failed to connect to browser",
            };
        };

        // Run task
        var result = agent.runTask(task) catch |err| {
            return TaskResult{
                .task_id = task.task_id,
                .success = false,
                .final_answer = null,
                .steps_taken = 0,
                .total_tokens = 0,
                .elapsed_ms = 0,
                .error_message = @errorName(err),
            };
        };
        defer result.deinit();

        // Update stats
        self.stats.total_tasks += 1;
        if (result.success) {
            self.stats.successful_tasks += 1;
        } else {
            self.stats.failed_tasks += 1;
        }
        self.stats.total_steps += result.steps_taken;
        self.stats.total_tokens += result.total_tokens;
        self.stats.total_time_ms += result.elapsed_ms;

        // Copy answer if present
        var final_answer: ?[]const u8 = null;
        if (result.final_answer) |ans| {
            final_answer = self.allocator.dupe(u8, ans) catch null;
        }

        const task_result = TaskResult{
            .task_id = result.task_id,
            .success = result.success,
            .final_answer = final_answer,
            .steps_taken = result.steps_taken,
            .total_tokens = result.total_tokens,
            .elapsed_ms = result.elapsed_ms,
            .error_message = null,
        };

        // Store result
        self.results.append(task_result) catch {};

        return task_result;
    }

    /// Print summary statistics
    pub fn printStats(self: *const Self) void {
        std.debug.print(
            \\
            \\╔══════════════════════════════════════════════════════════════════╗
            \\║                    WEBARENA RESULTS                              ║
            \\╠══════════════════════════════════════════════════════════════════╣
            \\║  Total Tasks:     {d:>6}                                         ║
            \\║  Successful:      {d:>6}                                         ║
            \\║  Failed:          {d:>6}                                         ║
            \\║  Success Rate:    {d:>5.1}%                                       ║
            \\║  ────────────────────────────────────────────────────────────    ║
            \\║  Total Steps:     {d:>6}                                         ║
            \\║  Total Tokens:    {d:>6}                                         ║
            \\║  Total Time:      {d:>6}ms                                       ║
            \\╚══════════════════════════════════════════════════════════════════╝
            \\
        , .{
            self.stats.total_tasks,
            self.stats.successful_tasks,
            self.stats.failed_tasks,
            self.stats.successRate(),
            self.stats.total_steps,
            self.stats.total_tokens,
            self.stats.total_time_ms,
        });
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "WebArenaRunner initialization" {
    const allocator = std.testing.allocator;
    var runner = WebArenaRunner.init(allocator, .{
        .llm_api_key = "test-key",
    });
    defer runner.deinit();

    try std.testing.expectEqual(@as(u32, 0), runner.stats.total_tasks);
    try std.testing.expectEqual(@as(u32, 30), runner.config.max_steps);
}

test "RunnerStats successRate" {
    var stats = RunnerStats{
        .total_tasks = 10,
        .successful_tasks = 7,
        .failed_tasks = 3,
        .total_steps = 100,
        .total_tokens = 5000,
        .total_time_ms = 60000,
    };

    try std.testing.expectApproxEqAbs(70.0, stats.successRate(), 0.001);
}

test "RunnerStats zero tasks" {
    var stats = RunnerStats{
        .total_tasks = 0,
        .successful_tasks = 0,
        .failed_tasks = 0,
        .total_steps = 0,
        .total_tokens = 0,
        .total_time_ms = 0,
    };

    try std.testing.expectApproxEqAbs(0.0, stats.successRate(), 0.001);
}

test "RunnerConfig defaults" {
    const config = RunnerConfig{
        .llm_api_key = "key",
    };
    try std.testing.expectEqual(openai.Provider.groq, config.llm_provider);
    try std.testing.expectEqual(@as(u32, 30), config.max_steps);
    try std.testing.expect(config.save_trajectories);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
