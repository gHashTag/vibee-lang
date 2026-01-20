// VIBEE v71 Распределённые Агенты
// Мульти-агентная координация для 5x масштабирования
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === СВЯЩЕННЫЕ КОНСТАНТЫ ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const SCALING_FACTOR: f64 = 5.0;
pub const MAX_AGENTS: u32 = 100;
pub const CONSENSUS_THRESHOLD: f64 = 0.67;

// === СТАТУС АГЕНТА ===
pub const AgentStatus = enum {
    idle,
    working,
    waiting,
    syncing,
    failed,
    offline,

    pub fn isAvailable(self: AgentStatus) bool {
        return self == .idle;
    }

    pub fn isActive(self: AgentStatus) bool {
        return self == .idle or self == .working or self == .waiting or self == .syncing;
    }
};

// === ТИП СООБЩЕНИЯ ===
pub const MessageType = enum {
    task_assign,
    task_complete,
    heartbeat,
    sync_request,
    sync_response,
    consensus_vote,
    leader_election,
};

// === ТОПОЛОГИЯ КЛАСТЕРА ===
pub const ClusterTopology = enum {
    star,
    mesh,
    hierarchical,
    ring,
};

// === АЛГОРИТМ КОНСЕНСУСА ===
pub const ConsensusAlgorithm = enum {
    raft,
    pbft,
    simple_majority,
};

// === СТРАТЕГИЯ БАЛАНСИРОВКИ ===
pub const LoadBalanceStrategy = enum {
    round_robin,
    least_loaded,
    capability_based,
    locality_aware,
};

// === АГЕНТ ===
pub const Agent = struct {
    id: u64,
    role: []const u8,
    status: AgentStatus,
    current_task_id: u64,
    tasks_completed: u32,
    tasks_failed: u32,
    last_heartbeat: i64,
    capability_count: u32,

    pub fn init(id: u64, role: []const u8) Agent {
        return .{
            .id = id,
            .role = role,
            .status = .idle,
            .current_task_id = 0,
            .tasks_completed = 0,
            .tasks_failed = 0,
            .last_heartbeat = 0,
            .capability_count = 0,
        };
    }

    pub fn assignTask(self: *Agent, task_id: u64) bool {
        if (!self.status.isAvailable()) return false;
        self.current_task_id = task_id;
        self.status = .working;
        return true;
    }

    pub fn completeTask(self: *Agent, success: bool) void {
        if (success) {
            self.tasks_completed += 1;
        } else {
            self.tasks_failed += 1;
        }
        self.current_task_id = 0;
        self.status = .idle;
    }

    pub fn updateHeartbeat(self: *Agent, timestamp: i64) void {
        self.last_heartbeat = timestamp;
    }

    pub fn getSuccessRate(self: *const Agent) f64 {
        const total = self.tasks_completed + self.tasks_failed;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.tasks_completed)) / @as(f64, @floatFromInt(total));
    }
};

// === ЗАДАЧА ===
pub const Task = struct {
    id: u64,
    priority: u32,
    assigned_to: u64,
    dependency_count: u32,
    is_completed: bool,
    is_failed: bool,
};

// === СООБЩЕНИЕ ===
pub const Message = struct {
    id: u64,
    msg_type: MessageType,
    sender_id: u64,
    receiver_id: u64,
    timestamp: i64,
};

// === СОСТОЯНИЕ КЛАСТЕРА ===
pub const ClusterState = struct {
    leader_id: u64,
    has_leader: bool,
    agent_count: u32,
    active_count: u32,
    pending_tasks: u32,
    completed_tasks: u32,
};

// === РАСПРЕДЕЛЁННЫЙ КЛАСТЕР ===
pub const DistributedCluster = struct {
    topology: ClusterTopology,
    consensus: ConsensusAlgorithm,
    load_balance: LoadBalanceStrategy,
    agent_count: u32,
    active_agents: u32,
    leader_id: u64,
    has_leader: bool,
    total_tasks: u32,
    completed_tasks: u32,
    failed_tasks: u32,
    messages_sent: u32,
    next_agent_id: u64,
    next_task_id: u64,

    pub fn init() DistributedCluster {
        return .{
            .topology = .star,
            .consensus = .raft,
            .load_balance = .round_robin,
            .agent_count = 0,
            .active_agents = 0,
            .leader_id = 0,
            .has_leader = false,
            .total_tasks = 0,
            .completed_tasks = 0,
            .failed_tasks = 0,
            .messages_sent = 0,
            .next_agent_id = 1,
            .next_task_id = 1,
        };
    }

    pub fn setTopology(self: *DistributedCluster, topology: ClusterTopology) void {
        self.topology = topology;
    }

    pub fn setConsensus(self: *DistributedCluster, consensus: ConsensusAlgorithm) void {
        self.consensus = consensus;
    }

    pub fn setLoadBalance(self: *DistributedCluster, strategy: LoadBalanceStrategy) void {
        self.load_balance = strategy;
    }

    pub fn addAgent(self: *DistributedCluster) u64 {
        if (self.agent_count >= MAX_AGENTS) return 0;
        const id = self.next_agent_id;
        self.next_agent_id += 1;
        self.agent_count += 1;
        self.active_agents += 1;
        return id;
    }

    pub fn removeAgent(self: *DistributedCluster, is_leader: bool) void {
        if (self.agent_count == 0) return;
        self.agent_count -= 1;
        if (self.active_agents > 0) self.active_agents -= 1;
        if (is_leader) self.has_leader = false;
    }

    pub fn electLeader(self: *DistributedCluster, agent_id: u64) void {
        self.leader_id = agent_id;
        self.has_leader = true;
    }

    pub fn submitTask(self: *DistributedCluster) u64 {
        const id = self.next_task_id;
        self.next_task_id += 1;
        self.total_tasks += 1;
        return id;
    }

    pub fn completeTask(self: *DistributedCluster, success: bool) void {
        if (success) {
            self.completed_tasks += 1;
        } else {
            self.failed_tasks += 1;
        }
    }

    pub fn sendMessage(self: *DistributedCluster) void {
        self.messages_sent += 1;
    }

    pub fn getScalingEfficiency(self: *const DistributedCluster) f64 {
        if (self.agent_count == 0) return 0;
        // Идеальное масштабирование = agent_count, реальное немного меньше
        const ideal = @as(f64, @floatFromInt(self.agent_count));
        const overhead = 0.1 * @as(f64, @floatFromInt(self.agent_count - 1)); // 10% накладные расходы на координацию
        return @max(1.0, ideal - overhead);
    }

    pub fn getCompletionRate(self: *const DistributedCluster) f64 {
        if (self.total_tasks == 0) return 0;
        return @as(f64, @floatFromInt(self.completed_tasks)) / @as(f64, @floatFromInt(self.total_tasks));
    }

    pub fn getState(self: *const DistributedCluster) ClusterState {
        return ClusterState{
            .leader_id = self.leader_id,
            .has_leader = self.has_leader,
            .agent_count = self.agent_count,
            .active_count = self.active_agents,
            .pending_tasks = self.total_tasks - self.completed_tasks - self.failed_tasks,
            .completed_tasks = self.completed_tasks,
        };
    }

    pub fn reset(self: *DistributedCluster) void {
        self.agent_count = 0;
        self.active_agents = 0;
        self.leader_id = 0;
        self.has_leader = false;
        self.total_tasks = 0;
        self.completed_tasks = 0;
        self.failed_tasks = 0;
        self.messages_sent = 0;
    }
};

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
pub fn checkConsensus(votes: u32, total: u32) bool {
    if (total == 0) return false;
    const ratio = @as(f64, @floatFromInt(votes)) / @as(f64, @floatFromInt(total));
    return ratio >= CONSENSUS_THRESHOLD;
}

pub fn calculateScaling(agents: u32) f64 {
    if (agents == 0) return 0;
    // Закон Амдала: ускорение ограничено последовательной частью
    const parallel_fraction: f64 = 0.9; // 90% параллелизуемо
    const n = @as(f64, @floatFromInt(agents));
    return 1.0 / ((1.0 - parallel_fraction) + parallel_fraction / n);
}

// ============================================================
// ТЕСТЫ: СВЯЩЕННЫЕ КОНСТАНТЫ
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "SCALING_FACTOR" { try testing.expectApproxEqAbs(@as(f64, 5.0), SCALING_FACTOR, 0.01); }
test "MAX_AGENTS" { try testing.expectEqual(@as(u32, 100), MAX_AGENTS); }
test "CONSENSUS_THRESHOLD" { try testing.expectApproxEqAbs(@as(f64, 0.67), CONSENSUS_THRESHOLD, 0.01); }

// ============================================================
// ТЕСТЫ: СТАТУС АГЕНТА
// ============================================================
test "status.idle" { try testing.expect(AgentStatus.idle.isAvailable()); }
test "status.working" { try testing.expect(!AgentStatus.working.isAvailable()); }
test "status.working_active" { try testing.expect(AgentStatus.working.isActive()); }
test "status.failed" { try testing.expect(!AgentStatus.failed.isActive()); }
test "status.offline" { try testing.expect(!AgentStatus.offline.isActive()); }

// ============================================================
// ТЕСТЫ: ТИПЫ СООБЩЕНИЙ
// ============================================================
test "msg.task_assign" { try testing.expect(MessageType.task_assign == .task_assign); }
test "msg.task_complete" { try testing.expect(MessageType.task_complete == .task_complete); }
test "msg.heartbeat" { try testing.expect(MessageType.heartbeat == .heartbeat); }
test "msg.consensus_vote" { try testing.expect(MessageType.consensus_vote == .consensus_vote); }
test "msg.leader_election" { try testing.expect(MessageType.leader_election == .leader_election); }

// ============================================================
// ТЕСТЫ: ТОПОЛОГИИ
// ============================================================
test "topology.star" { try testing.expect(ClusterTopology.star == .star); }
test "topology.mesh" { try testing.expect(ClusterTopology.mesh == .mesh); }
test "topology.hierarchical" { try testing.expect(ClusterTopology.hierarchical == .hierarchical); }
test "topology.ring" { try testing.expect(ClusterTopology.ring == .ring); }

// ============================================================
// ТЕСТЫ: КОНСЕНСУС
// ============================================================
test "consensus.raft" { try testing.expect(ConsensusAlgorithm.raft == .raft); }
test "consensus.pbft" { try testing.expect(ConsensusAlgorithm.pbft == .pbft); }
test "consensus.majority" { try testing.expect(ConsensusAlgorithm.simple_majority == .simple_majority); }

// ============================================================
// ТЕСТЫ: БАЛАНСИРОВКА
// ============================================================
test "balance.round_robin" { try testing.expect(LoadBalanceStrategy.round_robin == .round_robin); }
test "balance.least_loaded" { try testing.expect(LoadBalanceStrategy.least_loaded == .least_loaded); }
test "balance.capability" { try testing.expect(LoadBalanceStrategy.capability_based == .capability_based); }
test "balance.locality" { try testing.expect(LoadBalanceStrategy.locality_aware == .locality_aware); }

// ============================================================
// ТЕСТЫ: АГЕНТ
// ============================================================
test "agent.init" {
    const agent = Agent.init(1, "worker");
    try testing.expectEqual(@as(u64, 1), agent.id);
    try testing.expect(agent.status == .idle);
}

test "agent.assign_task" {
    var agent = Agent.init(1, "worker");
    const result = agent.assignTask(100);
    try testing.expect(result);
    try testing.expect(agent.status == .working);
    try testing.expectEqual(@as(u64, 100), agent.current_task_id);
}

test "agent.assign_when_busy" {
    var agent = Agent.init(1, "worker");
    _ = agent.assignTask(100);
    const result = agent.assignTask(200);
    try testing.expect(!result);
}

test "agent.complete_success" {
    var agent = Agent.init(1, "worker");
    _ = agent.assignTask(100);
    agent.completeTask(true);
    try testing.expect(agent.status == .idle);
    try testing.expectEqual(@as(u32, 1), agent.tasks_completed);
}

test "agent.complete_failure" {
    var agent = Agent.init(1, "worker");
    _ = agent.assignTask(100);
    agent.completeTask(false);
    try testing.expectEqual(@as(u32, 1), agent.tasks_failed);
}

test "agent.success_rate" {
    var agent = Agent.init(1, "worker");
    _ = agent.assignTask(1);
    agent.completeTask(true);
    _ = agent.assignTask(2);
    agent.completeTask(true);
    _ = agent.assignTask(3);
    agent.completeTask(false);
    try testing.expectApproxEqAbs(@as(f64, 0.666), agent.getSuccessRate(), 0.01);
}

// ============================================================
// ТЕСТЫ: КЛАСТЕР
// ============================================================
test "cluster.init" {
    const cluster = DistributedCluster.init();
    try testing.expectEqual(@as(u32, 0), cluster.agent_count);
    try testing.expect(!cluster.has_leader);
    try testing.expect(cluster.topology == .star);
}

test "cluster.add_agent" {
    var cluster = DistributedCluster.init();
    const id = cluster.addAgent();
    try testing.expectEqual(@as(u64, 1), id);
    try testing.expectEqual(@as(u32, 1), cluster.agent_count);
}

test "cluster.max_agents" {
    var cluster = DistributedCluster.init();
    cluster.agent_count = MAX_AGENTS;
    const id = cluster.addAgent();
    try testing.expectEqual(@as(u64, 0), id);
}

test "cluster.remove_agent" {
    var cluster = DistributedCluster.init();
    _ = cluster.addAgent();
    cluster.removeAgent(false);
    try testing.expectEqual(@as(u32, 0), cluster.agent_count);
}

test "cluster.elect_leader" {
    var cluster = DistributedCluster.init();
    const id = cluster.addAgent();
    cluster.electLeader(id);
    try testing.expect(cluster.has_leader);
    try testing.expectEqual(id, cluster.leader_id);
}

test "cluster.submit_task" {
    var cluster = DistributedCluster.init();
    const id = cluster.submitTask();
    try testing.expectEqual(@as(u64, 1), id);
    try testing.expectEqual(@as(u32, 1), cluster.total_tasks);
}

test "cluster.complete_task" {
    var cluster = DistributedCluster.init();
    _ = cluster.submitTask();
    cluster.completeTask(true);
    try testing.expectEqual(@as(u32, 1), cluster.completed_tasks);
}

test "cluster.scaling_efficiency" {
    var cluster = DistributedCluster.init();
    for (0..5) |_| _ = cluster.addAgent();
    const efficiency = cluster.getScalingEfficiency();
    try testing.expect(efficiency >= 4.0); // ~4.6x с 5 агентами
}

test "cluster.completion_rate" {
    var cluster = DistributedCluster.init();
    _ = cluster.submitTask();
    _ = cluster.submitTask();
    cluster.completeTask(true);
    try testing.expectApproxEqAbs(@as(f64, 0.5), cluster.getCompletionRate(), 0.01);
}

test "cluster.get_state" {
    var cluster = DistributedCluster.init();
    _ = cluster.addAgent();
    _ = cluster.addAgent();
    cluster.electLeader(1);
    const state = cluster.getState();
    try testing.expectEqual(@as(u32, 2), state.agent_count);
    try testing.expect(state.has_leader);
}

test "cluster.reset" {
    var cluster = DistributedCluster.init();
    _ = cluster.addAgent();
    _ = cluster.submitTask();
    cluster.reset();
    try testing.expectEqual(@as(u32, 0), cluster.agent_count);
    try testing.expectEqual(@as(u32, 0), cluster.total_tasks);
}

// ============================================================
// ТЕСТЫ: КОНСЕНСУС
// ============================================================
test "consensus.reached" {
    try testing.expect(checkConsensus(4, 5)); // 80% > 67%
    try testing.expect(checkConsensus(3, 4)); // 75% > 67%
    try testing.expect(checkConsensus(7, 10)); // 70% > 67%
}

test "consensus.not_reached" {
    try testing.expect(!checkConsensus(2, 5)); // 40% < 67%
    try testing.expect(!checkConsensus(1, 3)); // 33% < 67%
}

// ============================================================
// ТЕСТЫ: МАСШТАБИРОВАНИЕ
// ============================================================
test "scaling.single" {
    const scaling = calculateScaling(1);
    try testing.expectApproxEqAbs(@as(f64, 1.0), scaling, 0.01);
}

test "scaling.multiple" {
    const scaling = calculateScaling(10);
    try testing.expect(scaling > 5.0); // Должно быть ~5.26x
}

test "scaling.many" {
    const scaling = calculateScaling(100);
    try testing.expect(scaling > 9.0); // Приближается к 10x (1/0.1)
}
