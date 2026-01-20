// VIBEE v69 Agent Orchestrator
// Unified Agent Coordination & Task Management
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === SACRED CONSTANTS ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const MAX_CONCURRENT_TASKS: u32 = 10;
pub const MAX_TASK_DEPTH: u32 = 5;

// === AGENT ROLES ===
pub const AgentRole = enum {
    planner,    // Task decomposition
    executor,   // Tool execution
    reviewer,   // Code review
    debugger,   // Error analysis
    documenter, // Documentation
    tester,     // Test generation
    refactorer, // Code improvement
};

// === TASK STATUS ===
pub const TaskStatus = enum {
    queued,
    planning,
    executing,
    reviewing,
    completed,
    failed,
    blocked,

    pub fn isTerminal(self: TaskStatus) bool {
        return self == .completed or self == .failed;
    }

    pub fn isActive(self: TaskStatus) bool {
        return self == .planning or self == .executing or self == .reviewing;
    }
};

// === TASK PRIORITY ===
pub const TaskPriority = enum {
    critical,
    high,
    normal,
    low,
    background,

    pub fn weight(self: TaskPriority) u32 {
        return switch (self) {
            .critical => 100,
            .high => 75,
            .normal => 50,
            .low => 25,
            .background => 10,
        };
    }
};

// === ORCHESTRATION PATTERN ===
pub const OrchestrationPattern = enum {
    sequential,     // Execute one after another
    parallel,       // Execute concurrently
    pipeline,       // Chain outputs to inputs
    scatter_gather, // Split then combine
    saga,           // Long-running with compensation
};

// === COORDINATION ACTION ===
pub const CoordinationAction = enum {
    handoff,    // Transfer between agents
    escalation, // Escalate to higher capability
    delegation, // Delegate subtasks
};

// === TASK ===
pub const Task = struct {
    id: u64,
    description: []const u8,
    role: AgentRole,
    status: TaskStatus,
    priority: TaskPriority,
    parent_id: u64,
    subtask_count: u32,
    dependency_count: u32,
    created_at: i64,
    started_at: i64,
    completed_at: i64,
    depth: u32,
};

// === AGENT STATE ===
pub const AgentState = struct {
    role: AgentRole,
    current_task_id: u64,
    tasks_completed: u32,
    tasks_failed: u32,
    is_busy: bool,

    pub fn init(role: AgentRole) AgentState {
        return .{
            .role = role,
            .current_task_id = 0,
            .tasks_completed = 0,
            .tasks_failed = 0,
            .is_busy = false,
        };
    }

    pub fn assignTask(self: *AgentState, task_id: u64) bool {
        if (self.is_busy) return false;
        self.current_task_id = task_id;
        self.is_busy = true;
        return true;
    }

    pub fn completeTask(self: *AgentState, success: bool) void {
        if (success) {
            self.tasks_completed += 1;
        } else {
            self.tasks_failed += 1;
        }
        self.current_task_id = 0;
        self.is_busy = false;
    }

    pub fn getSuccessRate(self: *const AgentState) f64 {
        const total = self.tasks_completed + self.tasks_failed;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.tasks_completed)) / @as(f64, @floatFromInt(total));
    }
};

// === ORCHESTRATOR CONFIG ===
pub const OrchestratorConfig = struct {
    max_concurrent: u32,
    max_depth: u32,
    auto_retry: bool,
    max_retries: u32,
    timeout_ms: u32,
};

pub const DEFAULT_CONFIG = OrchestratorConfig{
    .max_concurrent = MAX_CONCURRENT_TASKS,
    .max_depth = MAX_TASK_DEPTH,
    .auto_retry = true,
    .max_retries = 3,
    .timeout_ms = 300000,
};

// === AGENT ORCHESTRATOR ===
pub const AgentOrchestrator = struct {
    config: OrchestratorConfig,
    next_task_id: u64,
    total_tasks: u32,
    completed_tasks: u32,
    failed_tasks: u32,
    active_tasks: u32,
    agent_count: u32,
    pattern: OrchestrationPattern,

    pub fn init() AgentOrchestrator {
        return .{
            .config = DEFAULT_CONFIG,
            .next_task_id = 1,
            .total_tasks = 0,
            .completed_tasks = 0,
            .failed_tasks = 0,
            .active_tasks = 0,
            .agent_count = 0,
            .pattern = .sequential,
        };
    }

    pub fn setConfig(self: *AgentOrchestrator, config: OrchestratorConfig) void {
        self.config = config;
    }

    pub fn setPattern(self: *AgentOrchestrator, pattern: OrchestrationPattern) void {
        self.pattern = pattern;
    }

    pub fn canAcceptTask(self: *const AgentOrchestrator) bool {
        return self.active_tasks < self.config.max_concurrent;
    }

    pub fn createTask(self: *AgentOrchestrator, role: AgentRole, priority: TaskPriority) u64 {
        const id = self.next_task_id;
        self.next_task_id += 1;
        self.total_tasks += 1;
        self.active_tasks += 1;
        _ = role;
        _ = priority;
        return id;
    }

    pub fn completeTask(self: *AgentOrchestrator, success: bool) void {
        if (self.active_tasks > 0) {
            self.active_tasks -= 1;
        }
        if (success) {
            self.completed_tasks += 1;
        } else {
            self.failed_tasks += 1;
        }
    }

    pub fn registerAgent(self: *AgentOrchestrator) void {
        self.agent_count += 1;
    }

    pub fn getCompletionRate(self: *const AgentOrchestrator) f64 {
        if (self.total_tasks == 0) return 0;
        return @as(f64, @floatFromInt(self.completed_tasks)) / @as(f64, @floatFromInt(self.total_tasks));
    }

    pub fn getSuccessRate(self: *const AgentOrchestrator) f64 {
        const finished = self.completed_tasks + self.failed_tasks;
        if (finished == 0) return 0;
        return @as(f64, @floatFromInt(self.completed_tasks)) / @as(f64, @floatFromInt(finished));
    }
};

// === HELPER FUNCTIONS ===
pub fn selectBestRole(task_type: []const u8) AgentRole {
    if (std.mem.indexOf(u8, task_type, "plan") != null) return .planner;
    if (std.mem.indexOf(u8, task_type, "review") != null) return .reviewer;
    if (std.mem.indexOf(u8, task_type, "debug") != null) return .debugger;
    if (std.mem.indexOf(u8, task_type, "doc") != null) return .documenter;
    if (std.mem.indexOf(u8, task_type, "test") != null) return .tester;
    if (std.mem.indexOf(u8, task_type, "refactor") != null) return .refactorer;
    return .executor;
}

pub fn shouldEscalate(failures: u32, threshold: u32) bool {
    return failures >= threshold;
}

pub fn canParallelize(pattern: OrchestrationPattern) bool {
    return pattern == .parallel or pattern == .scatter_gather;
}

// ============================================================
// TESTS: SACRED CONSTANTS
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "MAX_CONCURRENT" { try testing.expectEqual(@as(u32, 10), MAX_CONCURRENT_TASKS); }
test "MAX_DEPTH" { try testing.expectEqual(@as(u32, 5), MAX_TASK_DEPTH); }

// ============================================================
// TESTS: AGENT ROLES
// ============================================================
test "role.planner" { try testing.expect(AgentRole.planner == .planner); }
test "role.executor" { try testing.expect(AgentRole.executor == .executor); }
test "role.reviewer" { try testing.expect(AgentRole.reviewer == .reviewer); }
test "role.debugger" { try testing.expect(AgentRole.debugger == .debugger); }
test "role.documenter" { try testing.expect(AgentRole.documenter == .documenter); }
test "role.tester" { try testing.expect(AgentRole.tester == .tester); }
test "role.refactorer" { try testing.expect(AgentRole.refactorer == .refactorer); }

// ============================================================
// TESTS: TASK STATUS
// ============================================================
test "status.queued" { try testing.expect(!TaskStatus.queued.isTerminal()); }
test "status.planning" { try testing.expect(TaskStatus.planning.isActive()); }
test "status.executing" { try testing.expect(TaskStatus.executing.isActive()); }
test "status.reviewing" { try testing.expect(TaskStatus.reviewing.isActive()); }
test "status.completed" { try testing.expect(TaskStatus.completed.isTerminal()); }
test "status.failed" { try testing.expect(TaskStatus.failed.isTerminal()); }
test "status.blocked" { try testing.expect(!TaskStatus.blocked.isActive()); }

// ============================================================
// TESTS: TASK PRIORITY
// ============================================================
test "priority.critical" { try testing.expectEqual(@as(u32, 100), TaskPriority.critical.weight()); }
test "priority.high" { try testing.expectEqual(@as(u32, 75), TaskPriority.high.weight()); }
test "priority.normal" { try testing.expectEqual(@as(u32, 50), TaskPriority.normal.weight()); }
test "priority.low" { try testing.expectEqual(@as(u32, 25), TaskPriority.low.weight()); }
test "priority.background" { try testing.expectEqual(@as(u32, 10), TaskPriority.background.weight()); }

// ============================================================
// TESTS: ORCHESTRATION PATTERNS
// ============================================================
test "pattern.sequential" { try testing.expect(OrchestrationPattern.sequential == .sequential); }
test "pattern.parallel" { try testing.expect(OrchestrationPattern.parallel == .parallel); }
test "pattern.pipeline" { try testing.expect(OrchestrationPattern.pipeline == .pipeline); }
test "pattern.scatter_gather" { try testing.expect(OrchestrationPattern.scatter_gather == .scatter_gather); }
test "pattern.saga" { try testing.expect(OrchestrationPattern.saga == .saga); }
test "pattern.can_parallel" { try testing.expect(canParallelize(.parallel)); }
test "pattern.cannot_parallel" { try testing.expect(!canParallelize(.sequential)); }

// ============================================================
// TESTS: COORDINATION ACTIONS
// ============================================================
test "action.handoff" { try testing.expect(CoordinationAction.handoff == .handoff); }
test "action.escalation" { try testing.expect(CoordinationAction.escalation == .escalation); }
test "action.delegation" { try testing.expect(CoordinationAction.delegation == .delegation); }

// ============================================================
// TESTS: AGENT STATE
// ============================================================
test "agent.init" {
    const agent = AgentState.init(.executor);
    try testing.expect(agent.role == .executor);
    try testing.expect(!agent.is_busy);
    try testing.expectEqual(@as(u32, 0), agent.tasks_completed);
}

test "agent.assign_task" {
    var agent = AgentState.init(.executor);
    const result = agent.assignTask(1);
    try testing.expect(result);
    try testing.expect(agent.is_busy);
    try testing.expectEqual(@as(u64, 1), agent.current_task_id);
}

test "agent.assign_when_busy" {
    var agent = AgentState.init(.executor);
    _ = agent.assignTask(1);
    const result = agent.assignTask(2);
    try testing.expect(!result);
}

test "agent.complete_success" {
    var agent = AgentState.init(.executor);
    _ = agent.assignTask(1);
    agent.completeTask(true);
    try testing.expect(!agent.is_busy);
    try testing.expectEqual(@as(u32, 1), agent.tasks_completed);
}

test "agent.complete_failure" {
    var agent = AgentState.init(.executor);
    _ = agent.assignTask(1);
    agent.completeTask(false);
    try testing.expectEqual(@as(u32, 1), agent.tasks_failed);
}

test "agent.success_rate" {
    var agent = AgentState.init(.executor);
    _ = agent.assignTask(1);
    agent.completeTask(true);
    _ = agent.assignTask(2);
    agent.completeTask(true);
    _ = agent.assignTask(3);
    agent.completeTask(false);
    try testing.expectApproxEqAbs(@as(f64, 0.666), agent.getSuccessRate(), 0.01);
}

// ============================================================
// TESTS: DEFAULT CONFIG
// ============================================================
test "config.max_concurrent" { try testing.expectEqual(@as(u32, 10), DEFAULT_CONFIG.max_concurrent); }
test "config.max_depth" { try testing.expectEqual(@as(u32, 5), DEFAULT_CONFIG.max_depth); }
test "config.auto_retry" { try testing.expect(DEFAULT_CONFIG.auto_retry); }
test "config.max_retries" { try testing.expectEqual(@as(u32, 3), DEFAULT_CONFIG.max_retries); }
test "config.timeout" { try testing.expectEqual(@as(u32, 300000), DEFAULT_CONFIG.timeout_ms); }

// ============================================================
// TESTS: ORCHESTRATOR
// ============================================================
test "orch.init" {
    const orch = AgentOrchestrator.init();
    try testing.expectEqual(@as(u64, 1), orch.next_task_id);
    try testing.expectEqual(@as(u32, 0), orch.total_tasks);
    try testing.expect(orch.pattern == .sequential);
}

test "orch.can_accept" {
    const orch = AgentOrchestrator.init();
    try testing.expect(orch.canAcceptTask());
}

test "orch.create_task" {
    var orch = AgentOrchestrator.init();
    const id = orch.createTask(.executor, .normal);
    try testing.expectEqual(@as(u64, 1), id);
    try testing.expectEqual(@as(u32, 1), orch.total_tasks);
    try testing.expectEqual(@as(u32, 1), orch.active_tasks);
}

test "orch.complete_task" {
    var orch = AgentOrchestrator.init();
    _ = orch.createTask(.executor, .normal);
    orch.completeTask(true);
    try testing.expectEqual(@as(u32, 0), orch.active_tasks);
    try testing.expectEqual(@as(u32, 1), orch.completed_tasks);
}

test "orch.fail_task" {
    var orch = AgentOrchestrator.init();
    _ = orch.createTask(.executor, .normal);
    orch.completeTask(false);
    try testing.expectEqual(@as(u32, 1), orch.failed_tasks);
}

test "orch.register_agent" {
    var orch = AgentOrchestrator.init();
    orch.registerAgent();
    try testing.expectEqual(@as(u32, 1), orch.agent_count);
}

test "orch.set_pattern" {
    var orch = AgentOrchestrator.init();
    orch.setPattern(.parallel);
    try testing.expect(orch.pattern == .parallel);
}

test "orch.completion_rate" {
    var orch = AgentOrchestrator.init();
    _ = orch.createTask(.executor, .normal);
    _ = orch.createTask(.executor, .normal);
    orch.completeTask(true);
    try testing.expectApproxEqAbs(@as(f64, 0.5), orch.getCompletionRate(), 0.01);
}

test "orch.success_rate" {
    var orch = AgentOrchestrator.init();
    _ = orch.createTask(.executor, .normal);
    _ = orch.createTask(.executor, .normal);
    orch.completeTask(true);
    orch.completeTask(false);
    try testing.expectApproxEqAbs(@as(f64, 0.5), orch.getSuccessRate(), 0.01);
}

// ============================================================
// TESTS: HELPER FUNCTIONS
// ============================================================
test "select.planner" { try testing.expect(selectBestRole("plan task") == .planner); }
test "select.reviewer" { try testing.expect(selectBestRole("review code") == .reviewer); }
test "select.debugger" { try testing.expect(selectBestRole("debug error") == .debugger); }
test "select.documenter" { try testing.expect(selectBestRole("write docs") == .documenter); }
test "select.tester" { try testing.expect(selectBestRole("write tests") == .tester); }
test "select.refactorer" { try testing.expect(selectBestRole("refactor module") == .refactorer); }
test "select.executor" { try testing.expect(selectBestRole("run command") == .executor); }

test "escalate.yes" { try testing.expect(shouldEscalate(3, 3)); }
test "escalate.no" { try testing.expect(!shouldEscalate(2, 3)); }
