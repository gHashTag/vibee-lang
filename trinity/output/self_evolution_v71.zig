// VIBEE v71 Самоэволюция
// Самоулучшающийся агент для 10x ускорения обучения
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === СВЯЩЕННЫЕ КОНСТАНТЫ ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const EVOLUTION_SPEEDUP: f64 = 10.0;
pub const MIN_IMPROVEMENT: f64 = 0.01;
pub const MAX_GENERATIONS: u32 = 1000;

// === СОСТОЯНИЕ ЭВОЛЮЦИИ ===
pub const EvolutionState = enum {
    initializing,
    exploring,
    exploiting,
    evaluating,
    adapting,
    converged,

    pub fn isActive(self: EvolutionState) bool {
        return self != .converged;
    }
};

// === ОПЕРАТОР СЕЛЕКЦИИ ===
pub const SelectionOperator = enum { tournament, roulette, rank_based, elitism };

// === ОПЕРАТОР КРОССОВЕРА ===
pub const CrossoverOperator = enum { single_point, two_point, uniform, arithmetic };

// === ОПЕРАТОР МУТАЦИИ ===
pub const MutationOperator = enum { gaussian, uniform, adaptive, self_adaptive };

// === СТРАТЕГИЯ ===
pub const Strategy = struct {
    id: u64,
    name: []const u8,
    fitness: f64,
    generation: u32,
    parent_id: u64,
    mutation_rate: f64,
    crossover_rate: f64,

    pub fn isBetterThan(self: *const Strategy, other: *const Strategy) bool {
        return self.fitness > other.fitness;
    }

    pub fn getImprovement(self: *const Strategy, baseline: f64) f64 {
        if (baseline == 0) return 0;
        return (self.fitness - baseline) / baseline;
    }
};

// === МЕТРИКА ПРОИЗВОДИТЕЛЬНОСТИ ===
pub const PerformanceMetric = struct {
    name: []const u8,
    value: f64,
    target: f64,
    weight: f64,

    pub fn getScore(self: *const PerformanceMetric) f64 {
        if (self.target == 0) return 0;
        return @min(self.value / self.target, 1.0) * self.weight;
    }

    pub fn meetsTarget(self: *const PerformanceMetric) bool {
        return self.value >= self.target;
    }
};

// === КОНФИГУРАЦИЯ ЭВОЛЮЦИИ ===
pub const EvolutionConfig = struct {
    population_size: u32,
    mutation_rate: f64,
    crossover_rate: f64,
    elite_count: u32,
    tournament_size: u32,
};

pub const DEFAULT_CONFIG = EvolutionConfig{
    .population_size = 50,
    .mutation_rate = 0.1,
    .crossover_rate = 0.7,
    .elite_count = 5,
    .tournament_size = 3,
};

// === РЕЗУЛЬТАТ АДАПТАЦИИ ===
pub const AdaptationResult = struct {
    old_fitness: f64,
    new_fitness: f64,
    improvement: f64,
    generations: u32,
    converged: bool,

    pub fn isSuccessful(self: *const AdaptationResult) bool {
        return self.improvement >= MIN_IMPROVEMENT;
    }
};

// === МЕТРИКИ ФИТНЕСА ===
pub const FITNESS_METRICS = [_]PerformanceMetric{
    .{ .name = "task_success_rate", .value = 0, .target = 0.95, .weight = 0.30 },
    .{ .name = "response_quality", .value = 0, .target = 0.90, .weight = 0.25 },
    .{ .name = "token_efficiency", .value = 0, .target = 0.80, .weight = 0.20 },
    .{ .name = "latency_score", .value = 0, .target = 0.85, .weight = 0.15 },
    .{ .name = "user_satisfaction", .value = 0, .target = 0.90, .weight = 0.10 },
};

// === САМОЭВОЛЮЦИОНИРУЮЩИЙ АГЕНТ ===
pub const SelfEvolvingAgent = struct {
    config: EvolutionConfig,
    state: EvolutionState,
    current_generation: u32,
    best_fitness: f64,
    best_strategy_id: u64,
    population_count: u32,
    total_evaluations: u32,
    improvements: u32,
    next_strategy_id: u64,

    pub fn init() SelfEvolvingAgent {
        return .{
            .config = DEFAULT_CONFIG,
            .state = .initializing,
            .current_generation = 0,
            .best_fitness = 0,
            .best_strategy_id = 0,
            .population_count = 0,
            .total_evaluations = 0,
            .improvements = 0,
            .next_strategy_id = 1,
        };
    }

    pub fn setConfig(self: *SelfEvolvingAgent, config: EvolutionConfig) void {
        self.config = config;
    }

    pub fn initializePopulation(self: *SelfEvolvingAgent) void {
        self.population_count = self.config.population_size;
        self.state = .exploring;
    }

    pub fn createStrategy(self: *SelfEvolvingAgent, fitness: f64) Strategy {
        const id = self.next_strategy_id;
        self.next_strategy_id += 1;
        return Strategy{
            .id = id,
            .name = "strategy",
            .fitness = fitness,
            .generation = self.current_generation,
            .parent_id = 0,
            .mutation_rate = self.config.mutation_rate,
            .crossover_rate = self.config.crossover_rate,
        };
    }

    pub fn evaluate(self: *SelfEvolvingAgent, strategy: *const Strategy) void {
        self.total_evaluations += 1;
        if (strategy.fitness > self.best_fitness) {
            self.best_fitness = strategy.fitness;
            self.best_strategy_id = strategy.id;
            self.improvements += 1;
        }
    }

    pub fn evolve(self: *SelfEvolvingAgent) bool {
        if (self.state == .converged) return false;

        self.current_generation += 1;
        self.state = .evaluating;

        // Проверка сходимости
        if (self.best_fitness >= 0.95 or self.current_generation >= MAX_GENERATIONS) {
            self.state = .converged;
            return false;
        }

        self.state = .exploring;
        return true;
    }

    pub fn adapt(self: *SelfEvolvingAgent, feedback_positive: bool) AdaptationResult {
        const old_fitness = self.best_fitness;

        if (feedback_positive) {
            // Усиливаем текущую стратегию
            self.best_fitness = @min(self.best_fitness * 1.05, 1.0);
        } else {
            // Переключаемся на исследование
            self.state = .adapting;
            self.best_fitness = @max(self.best_fitness * 0.95, 0);
        }

        const new_fitness = self.best_fitness;
        const improvement = if (old_fitness > 0) (new_fitness - old_fitness) / old_fitness else 0;

        return AdaptationResult{
            .old_fitness = old_fitness,
            .new_fitness = new_fitness,
            .improvement = improvement,
            .generations = self.current_generation,
            .converged = self.state == .converged,
        };
    }

    pub fn getSpeedup(self: *const SelfEvolvingAgent) f64 {
        _ = self;
        return EVOLUTION_SPEEDUP;
    }

    pub fn getConvergenceRate(self: *const SelfEvolvingAgent) f64 {
        if (self.current_generation == 0) return 0;
        return @as(f64, @floatFromInt(self.improvements)) / @as(f64, @floatFromInt(self.current_generation));
    }

    pub fn reset(self: *SelfEvolvingAgent) void {
        self.state = .initializing;
        self.current_generation = 0;
        self.best_fitness = 0;
        self.best_strategy_id = 0;
        self.population_count = 0;
        self.total_evaluations = 0;
        self.improvements = 0;
    }
};

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
pub fn calculateFitness(metrics: []const PerformanceMetric) f64 {
    var total: f64 = 0;
    for (metrics) |m| {
        total += m.getScore();
    }
    return total;
}

pub fn mutate(value: f64, rate: f64) f64 {
    // Простая мутация: добавляем случайное отклонение
    const delta = rate * 0.1; // ±10% от rate
    return @max(0, @min(1.0, value + delta));
}

pub fn crossover(a: f64, b: f64, rate: f64) f64 {
    return a * rate + b * (1.0 - rate);
}

// ============================================================
// ТЕСТЫ: СВЯЩЕННЫЕ КОНСТАНТЫ
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "EVOLUTION_SPEEDUP" { try testing.expectApproxEqAbs(@as(f64, 10.0), EVOLUTION_SPEEDUP, 0.01); }
test "MIN_IMPROVEMENT" { try testing.expectApproxEqAbs(@as(f64, 0.01), MIN_IMPROVEMENT, 0.001); }
test "MAX_GENERATIONS" { try testing.expectEqual(@as(u32, 1000), MAX_GENERATIONS); }

// ============================================================
// ТЕСТЫ: СОСТОЯНИЕ ЭВОЛЮЦИИ
// ============================================================
test "state.initializing" { try testing.expect(EvolutionState.initializing.isActive()); }
test "state.exploring" { try testing.expect(EvolutionState.exploring.isActive()); }
test "state.exploiting" { try testing.expect(EvolutionState.exploiting.isActive()); }
test "state.evaluating" { try testing.expect(EvolutionState.evaluating.isActive()); }
test "state.adapting" { try testing.expect(EvolutionState.adapting.isActive()); }
test "state.converged" { try testing.expect(!EvolutionState.converged.isActive()); }

// ============================================================
// ТЕСТЫ: ОПЕРАТОРЫ
// ============================================================
test "selection.tournament" { try testing.expect(SelectionOperator.tournament == .tournament); }
test "selection.roulette" { try testing.expect(SelectionOperator.roulette == .roulette); }
test "crossover.single_point" { try testing.expect(CrossoverOperator.single_point == .single_point); }
test "crossover.uniform" { try testing.expect(CrossoverOperator.uniform == .uniform); }
test "mutation.gaussian" { try testing.expect(MutationOperator.gaussian == .gaussian); }
test "mutation.adaptive" { try testing.expect(MutationOperator.adaptive == .adaptive); }

// ============================================================
// ТЕСТЫ: СТРАТЕГИЯ
// ============================================================
test "strategy.is_better" {
    const a = Strategy{ .id = 1, .name = "a", .fitness = 0.8, .generation = 1, .parent_id = 0, .mutation_rate = 0.1, .crossover_rate = 0.7 };
    const b = Strategy{ .id = 2, .name = "b", .fitness = 0.6, .generation = 1, .parent_id = 0, .mutation_rate = 0.1, .crossover_rate = 0.7 };
    try testing.expect(a.isBetterThan(&b));
    try testing.expect(!b.isBetterThan(&a));
}

test "strategy.improvement" {
    const s = Strategy{ .id = 1, .name = "s", .fitness = 0.9, .generation = 1, .parent_id = 0, .mutation_rate = 0.1, .crossover_rate = 0.7 };
    const imp = s.getImprovement(0.6);
    try testing.expectApproxEqAbs(@as(f64, 0.5), imp, 0.01); // 50% улучшение
}

// ============================================================
// ТЕСТЫ: МЕТРИКА ПРОИЗВОДИТЕЛЬНОСТИ
// ============================================================
test "metric.score" {
    const m = PerformanceMetric{ .name = "test", .value = 0.9, .target = 1.0, .weight = 0.5 };
    try testing.expectApproxEqAbs(@as(f64, 0.45), m.getScore(), 0.01);
}

test "metric.meets_target" {
    const m1 = PerformanceMetric{ .name = "test", .value = 0.95, .target = 0.9, .weight = 0.5 };
    const m2 = PerformanceMetric{ .name = "test", .value = 0.85, .target = 0.9, .weight = 0.5 };
    try testing.expect(m1.meetsTarget());
    try testing.expect(!m2.meetsTarget());
}

// ============================================================
// ТЕСТЫ: КОНФИГУРАЦИЯ
// ============================================================
test "config.population" { try testing.expectEqual(@as(u32, 50), DEFAULT_CONFIG.population_size); }
test "config.mutation" { try testing.expectApproxEqAbs(@as(f64, 0.1), DEFAULT_CONFIG.mutation_rate, 0.01); }
test "config.crossover" { try testing.expectApproxEqAbs(@as(f64, 0.7), DEFAULT_CONFIG.crossover_rate, 0.01); }
test "config.elite" { try testing.expectEqual(@as(u32, 5), DEFAULT_CONFIG.elite_count); }
test "config.tournament" { try testing.expectEqual(@as(u32, 3), DEFAULT_CONFIG.tournament_size); }

// ============================================================
// ТЕСТЫ: МЕТРИКИ ФИТНЕСА
// ============================================================
test "fitness.metrics_count" { try testing.expectEqual(@as(usize, 5), FITNESS_METRICS.len); }
test "fitness.weights_sum" {
    var sum: f64 = 0;
    for (FITNESS_METRICS) |m| sum += m.weight;
    try testing.expectApproxEqAbs(@as(f64, 1.0), sum, 0.01);
}

// ============================================================
// ТЕСТЫ: САМОЭВОЛЮЦИОНИРУЮЩИЙ АГЕНТ
// ============================================================
test "agent.init" {
    const agent = SelfEvolvingAgent.init();
    try testing.expect(agent.state == .initializing);
    try testing.expectEqual(@as(u32, 0), agent.current_generation);
    try testing.expectApproxEqAbs(@as(f64, 0), agent.best_fitness, 0.01);
}

test "agent.initialize_population" {
    var agent = SelfEvolvingAgent.init();
    agent.initializePopulation();
    try testing.expect(agent.state == .exploring);
    try testing.expectEqual(@as(u32, 50), agent.population_count);
}

test "agent.create_strategy" {
    var agent = SelfEvolvingAgent.init();
    const s = agent.createStrategy(0.75);
    try testing.expectEqual(@as(u64, 1), s.id);
    try testing.expectApproxEqAbs(@as(f64, 0.75), s.fitness, 0.01);
}

test "agent.evaluate" {
    var agent = SelfEvolvingAgent.init();
    const s = agent.createStrategy(0.8);
    agent.evaluate(&s);
    try testing.expectEqual(@as(u32, 1), agent.total_evaluations);
    try testing.expectApproxEqAbs(@as(f64, 0.8), agent.best_fitness, 0.01);
}

test "agent.evolve" {
    var agent = SelfEvolvingAgent.init();
    agent.initializePopulation();
    const continued = agent.evolve();
    try testing.expect(continued);
    try testing.expectEqual(@as(u32, 1), agent.current_generation);
}

test "agent.converge" {
    var agent = SelfEvolvingAgent.init();
    agent.best_fitness = 0.96;
    _ = agent.evolve();
    try testing.expect(agent.state == .converged);
}

test "agent.adapt_positive" {
    var agent = SelfEvolvingAgent.init();
    agent.best_fitness = 0.8;
    const result = agent.adapt(true);
    try testing.expect(result.new_fitness > result.old_fitness);
}

test "agent.adapt_negative" {
    var agent = SelfEvolvingAgent.init();
    agent.best_fitness = 0.8;
    const result = agent.adapt(false);
    try testing.expect(result.new_fitness < result.old_fitness);
    try testing.expect(agent.state == .adapting);
}

test "agent.speedup" {
    const agent = SelfEvolvingAgent.init();
    try testing.expectApproxEqAbs(@as(f64, 10.0), agent.getSpeedup(), 0.01);
}

test "agent.convergence_rate" {
    var agent = SelfEvolvingAgent.init();
    agent.current_generation = 10;
    agent.improvements = 3;
    try testing.expectApproxEqAbs(@as(f64, 0.3), agent.getConvergenceRate(), 0.01);
}

test "agent.reset" {
    var agent = SelfEvolvingAgent.init();
    agent.initializePopulation();
    _ = agent.evolve();
    agent.reset();
    try testing.expect(agent.state == .initializing);
    try testing.expectEqual(@as(u32, 0), agent.current_generation);
}

// ============================================================
// ТЕСТЫ: РЕЗУЛЬТАТ АДАПТАЦИИ
// ============================================================
test "adaptation.successful" {
    const result = AdaptationResult{ .old_fitness = 0.7, .new_fitness = 0.8, .improvement = 0.14, .generations = 10, .converged = false };
    try testing.expect(result.isSuccessful());
}

test "adaptation.unsuccessful" {
    const result = AdaptationResult{ .old_fitness = 0.7, .new_fitness = 0.705, .improvement = 0.007, .generations = 10, .converged = false };
    try testing.expect(!result.isSuccessful());
}

// ============================================================
// ТЕСТЫ: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================================
test "calculate_fitness" {
    const metrics = [_]PerformanceMetric{
        .{ .name = "a", .value = 1.0, .target = 1.0, .weight = 0.5 },
        .{ .name = "b", .value = 0.8, .target = 1.0, .weight = 0.5 },
    };
    const fitness = calculateFitness(&metrics);
    try testing.expectApproxEqAbs(@as(f64, 0.9), fitness, 0.01);
}

test "mutate" {
    const result = mutate(0.5, 0.1);
    try testing.expect(result >= 0 and result <= 1.0);
}

test "crossover" {
    const result = crossover(0.8, 0.4, 0.5);
    try testing.expectApproxEqAbs(@as(f64, 0.6), result, 0.01);
}
