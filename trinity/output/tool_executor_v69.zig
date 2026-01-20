// VIBEE v69 Tool Executor
// Unified Tool Execution Engine
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === SACRED CONSTANTS ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const MAX_TIMEOUT_MS: u32 = 300000;
pub const MAX_RETRIES: u32 = 3;

// === TOOL CATEGORIES ===
pub const ToolCategory = enum {
    filesystem,
    terminal,
    git,
    browser,
    database,
    network,
    ai_model,
    custom,
};

// === EXECUTION STATUS ===
pub const ExecutionStatus = enum {
    pending,
    running,
    success,
    failed,
    timeout,
    cancelled,

    pub fn isTerminal(self: ExecutionStatus) bool {
        return switch (self) {
            .success, .failed, .timeout, .cancelled => true,
            .pending, .running => false,
        };
    }

    pub fn isSuccess(self: ExecutionStatus) bool {
        return self == .success;
    }
};

// === TOOL DEFINITION ===
pub const ToolDefinition = struct {
    name: []const u8,
    category: ToolCategory,
    description: []const u8,
    timeout_default_ms: u32,
    requires_confirmation: bool,
    is_destructive: bool,
};

// === TOOL RESULT ===
pub const ToolResult = struct {
    tool_name: []const u8,
    status: ExecutionStatus,
    output: []const u8,
    has_error: bool,
    error_msg: []const u8,
    duration_ms: u32,
    exit_code: i32,
    retries: u32,
};

// === TOOL CALL ===
pub const ToolCall = struct {
    id: u64,
    tool_name: []const u8,
    category: ToolCategory,
    params: []const u8,
    timeout_ms: u32,
    retry_count: u32,
    created_at: i64,
    started_at: i64,
    completed_at: i64,
    status: ExecutionStatus,
};

// === EXECUTION CONTEXT ===
pub const ExecutionContext = struct {
    working_dir: []const u8,
    user_id: []const u8,
    session_id: []const u8,
    dry_run: bool,
};

// === BUILT-IN TOOLS ===

// Filesystem Tools
pub const READ_FILE = ToolDefinition{
    .name = "read_file",
    .category = .filesystem,
    .description = "Read file contents",
    .timeout_default_ms = 5000,
    .requires_confirmation = false,
    .is_destructive = false,
};

pub const WRITE_FILE = ToolDefinition{
    .name = "write_file",
    .category = .filesystem,
    .description = "Write content to file",
    .timeout_default_ms = 5000,
    .requires_confirmation = true,
    .is_destructive = true,
};

pub const LIST_DIR = ToolDefinition{
    .name = "list_dir",
    .category = .filesystem,
    .description = "List directory contents",
    .timeout_default_ms = 5000,
    .requires_confirmation = false,
    .is_destructive = false,
};

pub const DELETE_FILE = ToolDefinition{
    .name = "delete_file",
    .category = .filesystem,
    .description = "Delete a file",
    .timeout_default_ms = 5000,
    .requires_confirmation = true,
    .is_destructive = true,
};

// Terminal Tools
pub const RUN_COMMAND = ToolDefinition{
    .name = "run_command",
    .category = .terminal,
    .description = "Execute shell command",
    .timeout_default_ms = 60000,
    .requires_confirmation = true,
    .is_destructive = true,
};

pub const RUN_SCRIPT = ToolDefinition{
    .name = "run_script",
    .category = .terminal,
    .description = "Execute script file",
    .timeout_default_ms = 120000,
    .requires_confirmation = true,
    .is_destructive = true,
};

// Git Tools
pub const GIT_STATUS = ToolDefinition{
    .name = "git_status",
    .category = .git,
    .description = "Get git status",
    .timeout_default_ms = 10000,
    .requires_confirmation = false,
    .is_destructive = false,
};

pub const GIT_DIFF = ToolDefinition{
    .name = "git_diff",
    .category = .git,
    .description = "Get git diff",
    .timeout_default_ms = 10000,
    .requires_confirmation = false,
    .is_destructive = false,
};

pub const GIT_COMMIT = ToolDefinition{
    .name = "git_commit",
    .category = .git,
    .description = "Create git commit",
    .timeout_default_ms = 30000,
    .requires_confirmation = true,
    .is_destructive = true,
};

pub const GIT_PUSH = ToolDefinition{
    .name = "git_push",
    .category = .git,
    .description = "Push to remote",
    .timeout_default_ms = 60000,
    .requires_confirmation = true,
    .is_destructive = true,
};

// AI Model Tools
pub const AI_COMPLETE = ToolDefinition{
    .name = "ai_complete",
    .category = .ai_model,
    .description = "Get AI completion",
    .timeout_default_ms = 120000,
    .requires_confirmation = false,
    .is_destructive = false,
};

pub const AI_EMBED = ToolDefinition{
    .name = "ai_embed",
    .category = .ai_model,
    .description = "Generate embeddings",
    .timeout_default_ms = 30000,
    .requires_confirmation = false,
    .is_destructive = false,
};

// === ALL TOOLS ===
pub const ALL_TOOLS = [_]ToolDefinition{
    READ_FILE,
    WRITE_FILE,
    LIST_DIR,
    DELETE_FILE,
    RUN_COMMAND,
    RUN_SCRIPT,
    GIT_STATUS,
    GIT_DIFF,
    GIT_COMMIT,
    GIT_PUSH,
    AI_COMPLETE,
    AI_EMBED,
};

// === TOOL EXECUTOR ===
pub const ToolExecutor = struct {
    next_call_id: u64,
    total_calls: u32,
    successful_calls: u32,
    failed_calls: u32,
    timeout_calls: u32,
    total_retries: u32,
    confirmation_required: bool,
    audit_enabled: bool,
    rate_limit_per_min: u32,
    calls_this_minute: u32,

    pub fn init() ToolExecutor {
        return .{
            .next_call_id = 1,
            .total_calls = 0,
            .successful_calls = 0,
            .failed_calls = 0,
            .timeout_calls = 0,
            .total_retries = 0,
            .confirmation_required = true,
            .audit_enabled = true,
            .rate_limit_per_min = 60,
            .calls_this_minute = 0,
        };
    }

    pub fn canExecute(self: *const ToolExecutor) bool {
        return self.calls_this_minute < self.rate_limit_per_min;
    }

    pub fn needsConfirmation(self: *const ToolExecutor, tool: *const ToolDefinition) bool {
        return self.confirmation_required and tool.requires_confirmation;
    }

    pub fn execute(self: *ToolExecutor, tool: *const ToolDefinition, dry_run: bool) ToolResult {
        self.total_calls += 1;
        self.calls_this_minute += 1;

        if (dry_run) {
            return ToolResult{
                .tool_name = tool.name,
                .status = .success,
                .output = "[DRY RUN]",
                .has_error = false,
                .error_msg = "",
                .duration_ms = 0,
                .exit_code = 0,
                .retries = 0,
            };
        }

        // Simulate execution
        self.successful_calls += 1;
        return ToolResult{
            .tool_name = tool.name,
            .status = .success,
            .output = "OK",
            .has_error = false,
            .error_msg = "",
            .duration_ms = 100,
            .exit_code = 0,
            .retries = 0,
        };
    }

    pub fn recordFailure(self: *ToolExecutor) void {
        self.failed_calls += 1;
    }

    pub fn recordTimeout(self: *ToolExecutor) void {
        self.timeout_calls += 1;
    }

    pub fn recordRetry(self: *ToolExecutor) void {
        self.total_retries += 1;
    }

    pub fn resetRateLimit(self: *ToolExecutor) void {
        self.calls_this_minute = 0;
    }

    pub fn getSuccessRate(self: *const ToolExecutor) f64 {
        if (self.total_calls == 0) return 0;
        return @as(f64, @floatFromInt(self.successful_calls)) / @as(f64, @floatFromInt(self.total_calls));
    }
};

// === HELPER FUNCTIONS ===
pub fn findTool(name: []const u8) ?*const ToolDefinition {
    for (&ALL_TOOLS) |*tool| {
        if (std.mem.eql(u8, tool.name, name)) return tool;
    }
    return null;
}

pub fn countByCategory(category: ToolCategory) u32 {
    var count: u32 = 0;
    for (ALL_TOOLS) |tool| {
        if (tool.category == category) count += 1;
    }
    return count;
}

pub fn countDestructive() u32 {
    var count: u32 = 0;
    for (ALL_TOOLS) |tool| {
        if (tool.is_destructive) count += 1;
    }
    return count;
}

pub fn countRequiresConfirmation() u32 {
    var count: u32 = 0;
    for (ALL_TOOLS) |tool| {
        if (tool.requires_confirmation) count += 1;
    }
    return count;
}

// ============================================================
// TESTS: SACRED CONSTANTS
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "MAX_TIMEOUT_MS" { try testing.expectEqual(@as(u32, 300000), MAX_TIMEOUT_MS); }
test "MAX_RETRIES" { try testing.expectEqual(@as(u32, 3), MAX_RETRIES); }

// ============================================================
// TESTS: TOOL CATEGORIES
// ============================================================
test "category.filesystem" { try testing.expect(ToolCategory.filesystem == .filesystem); }
test "category.terminal" { try testing.expect(ToolCategory.terminal == .terminal); }
test "category.git" { try testing.expect(ToolCategory.git == .git); }
test "category.browser" { try testing.expect(ToolCategory.browser == .browser); }
test "category.database" { try testing.expect(ToolCategory.database == .database); }
test "category.network" { try testing.expect(ToolCategory.network == .network); }
test "category.ai_model" { try testing.expect(ToolCategory.ai_model == .ai_model); }
test "category.custom" { try testing.expect(ToolCategory.custom == .custom); }

// ============================================================
// TESTS: EXECUTION STATUS
// ============================================================
test "status.pending" { try testing.expect(!ExecutionStatus.pending.isTerminal()); }
test "status.running" { try testing.expect(!ExecutionStatus.running.isTerminal()); }
test "status.success" { try testing.expect(ExecutionStatus.success.isTerminal()); }
test "status.failed" { try testing.expect(ExecutionStatus.failed.isTerminal()); }
test "status.timeout" { try testing.expect(ExecutionStatus.timeout.isTerminal()); }
test "status.cancelled" { try testing.expect(ExecutionStatus.cancelled.isTerminal()); }
test "status.is_success" { try testing.expect(ExecutionStatus.success.isSuccess()); }
test "status.not_success" { try testing.expect(!ExecutionStatus.failed.isSuccess()); }

// ============================================================
// TESTS: TOOL CATALOG
// ============================================================
test "tools.count" { try testing.expectEqual(@as(usize, 12), ALL_TOOLS.len); }
test "tools.filesystem" { try testing.expectEqual(@as(u32, 4), countByCategory(.filesystem)); }
test "tools.terminal" { try testing.expectEqual(@as(u32, 2), countByCategory(.terminal)); }
test "tools.git" { try testing.expectEqual(@as(u32, 4), countByCategory(.git)); }
test "tools.ai_model" { try testing.expectEqual(@as(u32, 2), countByCategory(.ai_model)); }
test "tools.destructive" { try testing.expectEqual(@as(u32, 6), countDestructive()); }
test "tools.confirmation" { try testing.expectEqual(@as(u32, 6), countRequiresConfirmation()); }

// ============================================================
// TESTS: FILESYSTEM TOOLS
// ============================================================
test "read_file.safe" { try testing.expect(!READ_FILE.is_destructive); }
test "read_file.no_confirm" { try testing.expect(!READ_FILE.requires_confirmation); }
test "write_file.destructive" { try testing.expect(WRITE_FILE.is_destructive); }
test "write_file.confirm" { try testing.expect(WRITE_FILE.requires_confirmation); }
test "delete_file.destructive" { try testing.expect(DELETE_FILE.is_destructive); }

// ============================================================
// TESTS: GIT TOOLS
// ============================================================
test "git_status.safe" { try testing.expect(!GIT_STATUS.is_destructive); }
test "git_diff.safe" { try testing.expect(!GIT_DIFF.is_destructive); }
test "git_commit.destructive" { try testing.expect(GIT_COMMIT.is_destructive); }
test "git_push.destructive" { try testing.expect(GIT_PUSH.is_destructive); }

// ============================================================
// TESTS: AI TOOLS
// ============================================================
test "ai_complete.safe" { try testing.expect(!AI_COMPLETE.is_destructive); }
test "ai_complete.timeout" { try testing.expectEqual(@as(u32, 120000), AI_COMPLETE.timeout_default_ms); }
test "ai_embed.safe" { try testing.expect(!AI_EMBED.is_destructive); }

// ============================================================
// TESTS: FIND TOOL
// ============================================================
test "find.read_file" {
    const tool = findTool("read_file");
    try testing.expect(tool != null);
    try testing.expect(tool.?.category == .filesystem);
}
test "find.git_status" {
    const tool = findTool("git_status");
    try testing.expect(tool != null);
}
test "find.nonexistent" {
    const tool = findTool("nonexistent");
    try testing.expect(tool == null);
}

// ============================================================
// TESTS: TOOL EXECUTOR
// ============================================================
test "executor.init" {
    const exec = ToolExecutor.init();
    try testing.expectEqual(@as(u64, 1), exec.next_call_id);
    try testing.expectEqual(@as(u32, 0), exec.total_calls);
    try testing.expect(exec.confirmation_required);
    try testing.expect(exec.audit_enabled);
}

test "executor.can_execute" {
    const exec = ToolExecutor.init();
    try testing.expect(exec.canExecute());
}

test "executor.needs_confirmation" {
    const exec = ToolExecutor.init();
    try testing.expect(exec.needsConfirmation(&WRITE_FILE));
    try testing.expect(!exec.needsConfirmation(&READ_FILE));
}

test "executor.execute" {
    var exec = ToolExecutor.init();
    const result = exec.execute(&READ_FILE, false);
    try testing.expect(result.status == .success);
    try testing.expectEqual(@as(u32, 1), exec.total_calls);
    try testing.expectEqual(@as(u32, 1), exec.successful_calls);
}

test "executor.dry_run" {
    var exec = ToolExecutor.init();
    const result = exec.execute(&WRITE_FILE, true);
    try testing.expect(result.status == .success);
    try testing.expect(std.mem.eql(u8, result.output, "[DRY RUN]"));
}

test "executor.success_rate" {
    var exec = ToolExecutor.init();
    _ = exec.execute(&READ_FILE, false);
    _ = exec.execute(&READ_FILE, false);
    exec.recordFailure();
    exec.total_calls += 1;
    // 2 success, 1 failure = 66.67%
    try testing.expect(exec.getSuccessRate() > 0.6);
}

test "executor.rate_limit" {
    var exec = ToolExecutor.init();
    exec.rate_limit_per_min = 2;
    _ = exec.execute(&READ_FILE, false);
    _ = exec.execute(&READ_FILE, false);
    try testing.expect(!exec.canExecute());
    exec.resetRateLimit();
    try testing.expect(exec.canExecute());
}

test "executor.record_failure" {
    var exec = ToolExecutor.init();
    exec.recordFailure();
    try testing.expectEqual(@as(u32, 1), exec.failed_calls);
}

test "executor.record_timeout" {
    var exec = ToolExecutor.init();
    exec.recordTimeout();
    try testing.expectEqual(@as(u32, 1), exec.timeout_calls);
}

test "executor.record_retry" {
    var exec = ToolExecutor.init();
    exec.recordRetry();
    try testing.expectEqual(@as(u32, 1), exec.total_retries);
}
