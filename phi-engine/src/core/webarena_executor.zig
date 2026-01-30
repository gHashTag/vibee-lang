// VIBEE WebArena Executor
// Connects Browser API to WebArena tasks
// Uses ReAct pattern for task execution
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const browser = @import("browser.zig");
const task_mod = @import("webarena_task.zig");

pub const ExecutorError = error{
    BrowserError,
    TaskError,
    Timeout,
    MaxStepsExceeded,
    InvalidAction,
    OutOfMemory,
};

pub const ExecutionStatus = enum {
    pending,
    running,
    success,
    failure,
    timeout,
};

pub const ActionType = enum {
    click,
    type_text,
    navigate,
    scroll,
    wait,
    screenshot,
    stop,

    pub fn fromString(s: []const u8) ?ActionType {
        if (std.mem.startsWith(u8, s, "click")) return .click;
        if (std.mem.startsWith(u8, s, "type")) return .type_text;
        if (std.mem.startsWith(u8, s, "goto") or std.mem.startsWith(u8, s, "navigate")) return .navigate;
        if (std.mem.startsWith(u8, s, "scroll")) return .scroll;
        if (std.mem.startsWith(u8, s, "wait")) return .wait;
        if (std.mem.startsWith(u8, s, "screenshot")) return .screenshot;
        if (std.mem.startsWith(u8, s, "stop")) return .stop;
        return null;
    }
};

pub const Action = struct {
    action_type: ActionType,
    selector: ?[]const u8,
    value: ?[]const u8,
    x: ?f64,
    y: ?f64,
};

pub const ExecutionResult = struct {
    task_id: i64,
    status: ExecutionStatus,
    steps_taken: u32,
    final_answer: ?[]const u8,
    screenshot: ?[]const u8,
    error_message: ?[]const u8,
    elapsed_ms: u64,
};

pub const ExecutorConfig = struct {
    max_steps: u32 = 30,
    timeout_ms: u64 = 60000,
    screenshot_on_error: bool = true,
    verbose: bool = false,
};

pub const WebArenaExecutor = struct {
    allocator: Allocator,
    config: ExecutorConfig,
    browser_instance: ?*browser.Browser,
    current_step: u32,
    start_time: i64,

    const Self = @This();

    pub fn init(allocator: Allocator, config: ExecutorConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .browser_instance = null,
            .current_step = 0,
            .start_time = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Set browser instance
    pub fn setBrowser(self: *Self, b: *browser.Browser) void {
        self.browser_instance = b;
    }

    /// Execute a WebArena task
    pub fn executeTask(self: *Self, task: *const task_mod.WebArenaTask) ExecutorError!ExecutionResult {
        self.current_step = 0;
        self.start_time = std.time.milliTimestamp();

        const b = self.browser_instance orelse return ExecutorError.BrowserError;

        // Navigate to start URL
        b.goto(task.getStartUrl()) catch return ExecutorError.BrowserError;
        self.current_step += 1;

        // Main execution loop would go here
        // In a real implementation, this would:
        // 1. Get observation from browser
        // 2. Send to LLM with task intent
        // 3. Parse action from LLM response
        // 4. Execute action
        // 5. Check if task is complete
        // 6. Repeat until done or max steps

        const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - self.start_time));

        return ExecutionResult{
            .task_id = task.task_id,
            .status = .pending,
            .steps_taken = self.current_step,
            .final_answer = null,
            .screenshot = null,
            .error_message = null,
            .elapsed_ms = elapsed,
        };
    }

    /// Parse action string from LLM
    pub fn parseAction(self: *Self, action_str: []const u8) ExecutorError!Action {
        _ = self;

        const action_type = ActionType.fromString(action_str) orelse return ExecutorError.InvalidAction;

        // Parse parameters based on action type
        var selector: ?[]const u8 = null;
        var value: ?[]const u8 = null;
        var x: ?f64 = null;
        var y: ?f64 = null;

        // Simple parsing - look for common patterns
        // click [selector] or click(x, y)
        // type "text"
        // goto "url"

        if (std.mem.indexOf(u8, action_str, "[")) |start| {
            if (std.mem.indexOf(u8, action_str[start..], "]")) |end| {
                selector = action_str[start + 1 .. start + end];
            }
        }

        if (std.mem.indexOf(u8, action_str, "\"")) |start| {
            const rest = action_str[start + 1 ..];
            if (std.mem.indexOf(u8, rest, "\"")) |end| {
                value = rest[0..end];
            }
        }

        // Parse coordinates for click(x, y)
        if (std.mem.indexOf(u8, action_str, "(")) |start| {
            if (std.mem.indexOf(u8, action_str[start..], ",")) |comma| {
                if (std.mem.indexOf(u8, action_str[start..], ")")) |end| {
                    const x_str = std.mem.trim(u8, action_str[start + 1 .. start + comma], " ");
                    const y_str = std.mem.trim(u8, action_str[start + comma + 1 .. start + end], " ");
                    x = std.fmt.parseFloat(f64, x_str) catch null;
                    y = std.fmt.parseFloat(f64, y_str) catch null;
                }
            }
        }

        return Action{
            .action_type = action_type,
            .selector = selector,
            .value = value,
            .x = x,
            .y = y,
        };
    }

    /// Perform a single action
    pub fn performAction(self: *Self, action: Action) ExecutorError!void {
        const b = self.browser_instance orelse return ExecutorError.BrowserError;

        switch (action.action_type) {
            .click => {
                if (action.x != null and action.y != null) {
                    b.click(action.x.?, action.y.?) catch return ExecutorError.BrowserError;
                } else if (action.selector) |sel| {
                    b.clickSelector(sel) catch return ExecutorError.BrowserError;
                }
            },
            .type_text => {
                if (action.value) |text| {
                    b.typeText(text) catch return ExecutorError.BrowserError;
                }
            },
            .navigate => {
                if (action.value) |url| {
                    b.goto(url) catch return ExecutorError.BrowserError;
                }
            },
            .scroll => {
                // Scroll via JavaScript
                _ = b.evaluate("window.scrollBy(0, 500)") catch return ExecutorError.BrowserError;
            },
            .wait => {
                std.time.sleep(1 * std.time.ns_per_s);
            },
            .screenshot => {
                _ = b.screenshot() catch return ExecutorError.BrowserError;
            },
            .stop => {
                // Task complete
            },
        }

        self.current_step += 1;
    }

    /// Get current observation from browser
    pub fn getObservation(self: *Self) ExecutorError![]const u8 {
        const b = self.browser_instance orelse return ExecutorError.BrowserError;
        return b.getVisibleText() catch return ExecutorError.BrowserError;
    }

    /// Check if task is complete
    pub fn evaluateTask(self: *Self, task: *const task_mod.WebArenaTask, response: []const u8) bool {
        const b = self.browser_instance orelse return false;
        const current_url = b.current_url;
        return task.evaluate(response, current_url);
    }

    /// Check if execution should stop
    pub fn shouldStop(self: *Self) bool {
        if (self.current_step >= self.config.max_steps) return true;

        const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - self.start_time));
        if (elapsed >= self.config.timeout_ms) return true;

        return false;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "executor initialization" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    try std.testing.expectEqual(@as(u32, 30), executor.config.max_steps);
    try std.testing.expectEqual(@as(u64, 60000), executor.config.timeout_ms);
}

test "parse click action with selector" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const action = try executor.parseAction("click [#submit-button]");
    try std.testing.expectEqual(ActionType.click, action.action_type);
    try std.testing.expectEqualStrings("#submit-button", action.selector.?);
}

test "parse click action with coordinates" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const action = try executor.parseAction("click(100, 200)");
    try std.testing.expectEqual(ActionType.click, action.action_type);
    try std.testing.expectApproxEqAbs(100.0, action.x.?, 0.001);
    try std.testing.expectApproxEqAbs(200.0, action.y.?, 0.001);
}

test "parse type action" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const action = try executor.parseAction("type \"hello world\"");
    try std.testing.expectEqual(ActionType.type_text, action.action_type);
    try std.testing.expectEqualStrings("hello world", action.value.?);
}

test "parse navigate action" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const action = try executor.parseAction("goto \"https://example.com\"");
    try std.testing.expectEqual(ActionType.navigate, action.action_type);
    try std.testing.expectEqualStrings("https://example.com", action.value.?);
}

test "ActionType fromString" {
    try std.testing.expectEqual(ActionType.click, ActionType.fromString("click").?);
    try std.testing.expectEqual(ActionType.type_text, ActionType.fromString("type").?);
    try std.testing.expectEqual(ActionType.navigate, ActionType.fromString("goto").?);
    try std.testing.expectEqual(ActionType.navigate, ActionType.fromString("navigate").?);
    try std.testing.expectEqual(ActionType.scroll, ActionType.fromString("scroll").?);
    try std.testing.expectEqual(ActionType.wait, ActionType.fromString("wait").?);
    try std.testing.expectEqual(ActionType.screenshot, ActionType.fromString("screenshot").?);
    try std.testing.expectEqual(ActionType.stop, ActionType.fromString("stop").?);
    try std.testing.expect(ActionType.fromString("invalid") == null);
}

test "ExecutionStatus enum" {
    const status: ExecutionStatus = .running;
    try std.testing.expect(status == .running);
}

test "ExecutorConfig defaults" {
    const config = ExecutorConfig{};
    try std.testing.expectEqual(@as(u32, 30), config.max_steps);
    try std.testing.expectEqual(@as(u64, 60000), config.timeout_ms);
    try std.testing.expect(config.screenshot_on_error);
    try std.testing.expect(!config.verbose);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "parse scroll action" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const action = try executor.parseAction("scroll down");
    try std.testing.expectEqual(ActionType.scroll, action.action_type);
}

test "parse wait action" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const action = try executor.parseAction("wait 2s");
    try std.testing.expectEqual(ActionType.wait, action.action_type);
}

test "parse stop action" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const action = try executor.parseAction("stop \"final answer\"");
    try std.testing.expectEqual(ActionType.stop, action.action_type);
    try std.testing.expectEqualStrings("final answer", action.value.?);
}

test "invalid action returns error" {
    const allocator = std.testing.allocator;
    var executor = WebArenaExecutor.init(allocator, .{});
    defer executor.deinit();

    const result = executor.parseAction("invalid_action");
    try std.testing.expectError(ExecutorError.InvalidAction, result);
}

test "ExecutionResult struct" {
    const result = ExecutionResult{
        .task_id = 42,
        .status = .success,
        .steps_taken = 5,
        .final_answer = "The answer is 42",
        .screenshot = null,
        .error_message = null,
        .elapsed_ms = 1500,
    };
    try std.testing.expectEqual(@as(i64, 42), result.task_id);
    try std.testing.expectEqual(ExecutionStatus.success, result.status);
    try std.testing.expectEqual(@as(u32, 5), result.steps_taken);
}

test "custom ExecutorConfig" {
    const config = ExecutorConfig{
        .max_steps = 50,
        .timeout_ms = 120000,
        .screenshot_on_error = false,
        .verbose = true,
    };
    try std.testing.expectEqual(@as(u32, 50), config.max_steps);
    try std.testing.expectEqual(@as(u64, 120000), config.timeout_ms);
    try std.testing.expect(!config.screenshot_on_error);
    try std.testing.expect(config.verbose);
}
