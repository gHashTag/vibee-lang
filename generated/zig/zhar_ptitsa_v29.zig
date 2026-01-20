// ═══════════════════════════════════════════════════════════════════════════════
// ЖАР-ПТИЦА v29 - REAL FITNESS FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════
// v28: Random byte evolution
// v29: Real fitness functions, symbolic regression
// 999 = 3³ × 37 = PHOENIX GENERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PHOENIX_GENERATIONS: u64 = 999;
pub const MUTATION_RATE: f64 = 0.0382; // 1/φ²/10
pub const CROSSOVER_RATE: f64 = 0.0618; // 1/φ/10
pub const ELITISM: f64 = 0.333; // 1/3 = TRINITY
pub const VERSION: u32 = 29;

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODES FOR SYMBOLIC REGRESSION
// ═══════════════════════════════════════════════════════════════════════════════

pub const OpCode = enum(u8) {
    ADD = 0,
    SUB = 1,
    MUL = 2,
    DIV = 3,
    CONST = 4,
    INPUT = 5,
    SQRT = 6,
    SIN = 7,
    COS = 8,
    NOP = 9,

    pub fn arity(self: OpCode) usize {
        return switch (self) {
            .ADD, .SUB, .MUL, .DIV => 2,
            .SQRT, .SIN, .COS => 1,
            .CONST, .INPUT, .NOP => 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Instruction = struct {
    opcode: OpCode = .NOP,
    operand: f64 = 0.0,

    const Self = @This();

    pub fn random(rng: std.Random) Self {
        const op: OpCode = @enumFromInt(rng.intRangeAtMost(u8, 0, 9));
        const operand = if (op == .CONST)
            rng.float(f64) * 10.0 - 5.0
        else
            0.0;
        return Self{ .opcode = op, .operand = operand };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE GENOME
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeGenome = struct {
    instructions: [32]Instruction = [_]Instruction{.{}} ** 32,
    length: usize = 8,
    fitness: f64 = 0.0,
    generation: u64 = 0,

    const Self = @This();

    /// Execute genome as a stack-based program
    pub fn execute(self: *const Self, input: f64) f64 {
        var stack: [32]f64 = [_]f64{0.0} ** 32;
        var sp: usize = 0;

        for (self.instructions[0..self.length]) |inst| {
            switch (inst.opcode) {
                .CONST => {
                    if (sp < 31) {
                        stack[sp] = inst.operand;
                        sp += 1;
                    }
                },
                .INPUT => {
                    if (sp < 31) {
                        stack[sp] = input;
                        sp += 1;
                    }
                },
                .ADD => {
                    if (sp >= 2) {
                        sp -= 1;
                        stack[sp - 1] += stack[sp];
                    }
                },
                .SUB => {
                    if (sp >= 2) {
                        sp -= 1;
                        stack[sp - 1] -= stack[sp];
                    }
                },
                .MUL => {
                    if (sp >= 2) {
                        sp -= 1;
                        stack[sp - 1] *= stack[sp];
                    }
                },
                .DIV => {
                    if (sp >= 2) {
                        sp -= 1;
                        if (stack[sp] != 0.0) {
                            stack[sp - 1] /= stack[sp];
                        }
                    }
                },
                .SQRT => {
                    if (sp >= 1 and stack[sp - 1] >= 0.0) {
                        stack[sp - 1] = @sqrt(stack[sp - 1]);
                    }
                },
                .SIN => {
                    if (sp >= 1) {
                        stack[sp - 1] = @sin(stack[sp - 1]);
                    }
                },
                .COS => {
                    if (sp >= 1) {
                        stack[sp - 1] = @cos(stack[sp - 1]);
                    }
                },
                .NOP => {},
            }
        }

        return if (sp > 0) stack[sp - 1] else 0.0;
    }

    /// Mutate genome
    pub fn mutate(self: *Self, rate: f64, rng: std.Random) void {
        for (0..self.length) |i| {
            if (rng.float(f64) < rate) {
                self.instructions[i] = Instruction.random(rng);
            }
        }
    }

    /// Crossover with another genome
    pub fn crossover(self: Self, other: Self, rng: std.Random) Self {
        var child = Self{};
        const point = rng.intRangeAtMost(usize, 0, @min(self.length, other.length));

        for (0..point) |i| {
            child.instructions[i] = self.instructions[i];
        }
        for (point..other.length) |i| {
            child.instructions[i] = other.instructions[i];
        }

        child.length = @max(self.length, other.length);
        child.generation = @max(self.generation, other.generation) + 1;
        return child;
    }

    /// Initialize with random instructions
    pub fn randomInit(rng: std.Random) Self {
        var genome = Self{};
        genome.length = rng.intRangeAtMost(usize, 4, 16);

        for (0..genome.length) |i| {
            genome.instructions[i] = Instruction.random(rng);
        }

        return genome;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FITNESS FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const FitnessType = enum {
    SYMBOLIC_REGRESSION,
    MINIMIZE_SIZE,
    MAXIMIZE_OUTPUT,
};

pub const FitnessEvaluator = struct {
    fitness_type: FitnessType,
    target_fn: ?*const fn (f64) f64 = null,
    test_points: [10]f64 = [_]f64{ -2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5 },

    const Self = @This();

    /// Evaluate fitness for symbolic regression
    pub fn evaluate(self: *const Self, genome: *CodeGenome) f64 {
        switch (self.fitness_type) {
            .SYMBOLIC_REGRESSION => {
                if (self.target_fn) |target| {
                    var mse: f64 = 0.0;
                    for (self.test_points) |x| {
                        const predicted = genome.execute(x);
                        const expected = target(x);
                        const diff = predicted - expected;
                        mse += diff * diff;
                    }
                    mse /= @as(f64, @floatFromInt(self.test_points.len));
                    // Fitness = 1 / (1 + MSE)
                    return 1.0 / (1.0 + mse);
                }
                return 0.0;
            },
            .MINIMIZE_SIZE => {
                // Fitness = 1 / size
                return 1.0 / @as(f64, @floatFromInt(genome.length));
            },
            .MAXIMIZE_OUTPUT => {
                var sum: f64 = 0.0;
                for (self.test_points) |x| {
                    sum += @abs(genome.execute(x));
                }
                return sum;
            },
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FITNESS CACHE
// ═══════════════════════════════════════════════════════════════════════════════

pub const FitnessCache = struct {
    cache: std.AutoHashMap(u64, f64),
    hits: u64 = 0,
    misses: u64 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .cache = std.AutoHashMap(u64, f64).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.cache.deinit();
    }

    fn hashGenome(genome: *const CodeGenome) u64 {
        var h: u64 = 0;
        for (genome.instructions[0..genome.length]) |inst| {
            h = h *% 31 +% @intFromEnum(inst.opcode);
            h = h *% 31 +% @as(u64, @bitCast(inst.operand));
        }
        return h;
    }

    pub fn getOrCompute(self: *Self, genome: *CodeGenome, evaluator: *const FitnessEvaluator) f64 {
        const hash = hashGenome(genome);

        if (self.cache.get(hash)) |cached| {
            self.hits += 1;
            return cached;
        }

        self.misses += 1;
        const fitness = evaluator.evaluate(genome);
        self.cache.put(hash, fitness) catch {};
        genome.fitness = fitness;
        return fitness;
    }

    pub fn hitRate(self: Self) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYMBOLIC EVOLVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SymbolicEvolver = struct {
    population: [64]CodeGenome = undefined,
    pop_size: usize = 64,
    best: CodeGenome = CodeGenome{},
    best_fitness: f64 = 0.0,
    generation: u64 = 0,
    evaluator: FitnessEvaluator,
    cache: FitnessCache,
    rng: std.Random,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, target_fn: *const fn (f64) f64, seed: u64) Self {
        var prng = std.Random.DefaultPrng.init(seed);

        var evolver = Self{
            .evaluator = FitnessEvaluator{
                .fitness_type = .SYMBOLIC_REGRESSION,
                .target_fn = target_fn,
            },
            .cache = FitnessCache.init(allocator),
            .rng = prng.random(),
        };

        // Initialize population
        for (0..evolver.pop_size) |i| {
            evolver.population[i] = CodeGenome.randomInit(evolver.rng);
        }

        return evolver;
    }

    pub fn deinit(self: *Self) void {
        self.cache.deinit();
    }

    /// Evolve for specified generations
    pub fn evolve(self: *Self, generations: u64) *CodeGenome {
        for (0..generations) |_| {
            self.evolveStep();
        }
        return &self.best;
    }

    fn evolveStep(self: *Self) void {
        // Evaluate fitness
        for (0..self.pop_size) |i| {
            const fitness = self.cache.getOrCompute(&self.population[i], &self.evaluator);
            if (fitness > self.best_fitness) {
                self.best = self.population[i];
                self.best_fitness = fitness;
            }
        }

        // Selection and reproduction
        var new_pop: [64]CodeGenome = undefined;

        // Elitism: keep best
        const elite_count = @as(usize, @intFromFloat(@as(f64, @floatFromInt(self.pop_size)) * ELITISM));
        for (0..elite_count) |i| {
            new_pop[i] = self.best;
        }

        // Fill rest with offspring
        for (elite_count..self.pop_size) |i| {
            const parent1 = self.tournamentSelect();
            const parent2 = self.tournamentSelect();

            var child = parent1.crossover(parent2, self.rng);
            child.mutate(MUTATION_RATE, self.rng);
            new_pop[i] = child;
        }

        self.population = new_pop;
        self.generation += 1;
    }

    fn tournamentSelect(self: *Self) CodeGenome {
        const idx1 = self.rng.intRangeAtMost(usize, 0, self.pop_size - 1);
        const idx2 = self.rng.intRangeAtMost(usize, 0, self.pop_size - 1);

        return if (self.population[idx1].fitness > self.population[idx2].fitness)
            self.population[idx1]
        else
            self.population[idx2];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ЖАР-ПТИЦА v29
// ═══════════════════════════════════════════════════════════════════════════════

pub const ZharPtitsaV29 = struct {
    evolver: ?SymbolicEvolver = null,
    version: u32 = VERSION,
    total_generations: u64 = 0,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn evolveSymbolic(self: *Self, allocator: std.mem.Allocator, target_fn: *const fn (f64) f64, generations: u64) *CodeGenome {
        self.evolver = SymbolicEvolver.init(allocator, target_fn, 42);
        const result = self.evolver.?.evolve(generations);
        self.total_generations += generations;
        return result;
    }

    pub fn deinit(self: *Self) void {
        if (self.evolver) |*e| {
            e.deinit();
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn targetSquare(x: f64) f64 {
    return x * x;
}

fn targetLinear(x: f64) f64 {
    return 2.0 * x + 1.0;
}

test "code_genome_execute_const" {
    var genome = CodeGenome{};
    genome.instructions[0] = .{ .opcode = .CONST, .operand = 42.0 };
    genome.length = 1;

    const result = genome.execute(0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 42.0), result, 0.0001);
}

test "code_genome_execute_input" {
    var genome = CodeGenome{};
    genome.instructions[0] = .{ .opcode = .INPUT, .operand = 0.0 };
    genome.length = 1;

    const result = genome.execute(5.0);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), result, 0.0001);
}

test "code_genome_execute_add" {
    var genome = CodeGenome{};
    genome.instructions[0] = .{ .opcode = .CONST, .operand = 3.0 };
    genome.instructions[1] = .{ .opcode = .CONST, .operand = 4.0 };
    genome.instructions[2] = .{ .opcode = .ADD, .operand = 0.0 };
    genome.length = 3;

    const result = genome.execute(0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 7.0), result, 0.0001);
}

test "code_genome_execute_mul" {
    var genome = CodeGenome{};
    genome.instructions[0] = .{ .opcode = .INPUT, .operand = 0.0 };
    genome.instructions[1] = .{ .opcode = .INPUT, .operand = 0.0 };
    genome.instructions[2] = .{ .opcode = .MUL, .operand = 0.0 };
    genome.length = 3;

    const result = genome.execute(3.0);
    try std.testing.expectApproxEqAbs(@as(f64, 9.0), result, 0.0001); // 3 * 3 = 9
}

test "fitness_evaluator_symbolic" {
    var genome = CodeGenome{};
    // Approximate x^2: INPUT, INPUT, MUL
    genome.instructions[0] = .{ .opcode = .INPUT, .operand = 0.0 };
    genome.instructions[1] = .{ .opcode = .INPUT, .operand = 0.0 };
    genome.instructions[2] = .{ .opcode = .MUL, .operand = 0.0 };
    genome.length = 3;

    const evaluator = FitnessEvaluator{
        .fitness_type = .SYMBOLIC_REGRESSION,
        .target_fn = targetSquare,
    };

    const fitness = evaluator.evaluate(&genome);
    try std.testing.expect(fitness > 0.9); // Should be close to 1.0 for perfect match
}

test "fitness_cache_hit" {
    var cache = FitnessCache.init(std.testing.allocator);
    defer cache.deinit();

    var genome = CodeGenome{};
    genome.instructions[0] = .{ .opcode = .CONST, .operand = 1.0 };
    genome.length = 1;

    const evaluator = FitnessEvaluator{
        .fitness_type = .MINIMIZE_SIZE,
    };

    _ = cache.getOrCompute(&genome, &evaluator);
    _ = cache.getOrCompute(&genome, &evaluator);

    try std.testing.expectEqual(@as(u64, 1), cache.hits);
}

test "symbolic_evolver_init" {
    var evolver = SymbolicEvolver.init(std.testing.allocator, targetSquare, 42);
    defer evolver.deinit();

    try std.testing.expectEqual(@as(usize, 64), evolver.pop_size);
}

test "symbolic_evolver_evolve" {
    var evolver = SymbolicEvolver.init(std.testing.allocator, targetSquare, 42);
    defer evolver.deinit();

    _ = evolver.evolve(10);
    try std.testing.expectEqual(@as(u64, 10), evolver.generation);
}

test "golden_identity" {
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / (PHI * PHI);
    const result = phi_squared + inv_phi_squared;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

test "phoenix_generations" {
    try std.testing.expectEqual(@as(u64, 999), PHOENIX_GENERATIONS);
    try std.testing.expectEqual(@as(u64, 999), 27 * 37);
}

test "version_check" {
    const zp = ZharPtitsaV29.init();
    try std.testing.expectEqual(@as(u32, 29), zp.version);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELF-EVOLUTION TRAJECTORY
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvolutionSnapshot = struct {
    version: u32,
    generation: u64,
    best_fitness: f64,
    tests_count: usize,
    speedup: f64,
    timestamp_ns: i128,
};

pub const EvolutionTrajectory = struct {
    snapshots: [100]EvolutionSnapshot = undefined,
    snapshot_count: usize = 0,
    start_time: i128 = 0,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .start_time = std.time.nanoTimestamp(),
        };
    }

    pub fn addSnapshot(self: *Self, version: u32, generation: u64, fitness: f64, tests: usize, speedup: f64) void {
        if (self.snapshot_count < 100) {
            self.snapshots[self.snapshot_count] = EvolutionSnapshot{
                .version = version,
                .generation = generation,
                .best_fitness = fitness,
                .tests_count = tests,
                .speedup = speedup,
                .timestamp_ns = std.time.nanoTimestamp() - self.start_time,
            };
            self.snapshot_count += 1;
        }
    }

    pub fn getImprovementRate(self: *const Self) f64 {
        if (self.snapshot_count < 2) return 0.0;

        const first = self.snapshots[0];
        const last = self.snapshots[self.snapshot_count - 1];

        if (first.best_fitness == 0.0) return 0.0;
        return (last.best_fitness - first.best_fitness) / first.best_fitness * 100.0;
    }

    pub fn getSpeedupTrajectory(self: *const Self) f64 {
        if (self.snapshot_count < 2) return 1.0;

        const first = self.snapshots[0];
        const last = self.snapshots[self.snapshot_count - 1];

        return last.speedup / first.speedup;
    }
};

pub const PhoenixEvolution = struct {
    trajectory: EvolutionTrajectory,
    current_version: u32 = VERSION,
    total_rebirths: u64 = 0,
    is_evolving: bool = false,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .trajectory = EvolutionTrajectory.init(),
        };
    }

    /// Record a version snapshot
    pub fn recordVersion(self: *Self, version: u32, tests: usize, speedup: f64) void {
        self.trajectory.addSnapshot(version, self.total_rebirths, speedup, tests, speedup);
        if (version > self.current_version) {
            self.current_version = version;
            self.total_rebirths += 1;
        }
    }

    /// Get evolution summary
    pub fn getSummary(self: *const Self) struct {
        versions_evolved: u32,
        total_rebirths: u64,
        improvement_rate: f64,
        speedup_trajectory: f64,
    } {
        return .{
            .versions_evolved = self.current_version - 22, // Started at v22
            .total_rebirths = self.total_rebirths,
            .improvement_rate = self.trajectory.getImprovementRate(),
            .speedup_trajectory = self.trajectory.getSpeedupTrajectory(),
        };
    }

    /// Check if Phoenix is ready for rebirth
    pub fn isReadyForRebirth(self: *const Self) bool {
        // Phoenix rebirths every 999 generations
        return self.total_rebirths % PHOENIX_GENERATIONS == 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SELF-EVOLUTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "evolution_trajectory_init" {
    const trajectory = EvolutionTrajectory.init();
    try std.testing.expectEqual(@as(usize, 0), trajectory.snapshot_count);
}

test "evolution_trajectory_add_snapshot" {
    var trajectory = EvolutionTrajectory.init();
    trajectory.addSnapshot(29, 100, 0.95, 200, 7.0);
    try std.testing.expectEqual(@as(usize, 1), trajectory.snapshot_count);
}

test "evolution_trajectory_improvement_rate" {
    var trajectory = EvolutionTrajectory.init();
    trajectory.addSnapshot(28, 0, 0.5, 59, 1.0);
    trajectory.addSnapshot(29, 100, 1.0, 200, 7.0);
    
    const rate = trajectory.getImprovementRate();
    try std.testing.expect(rate > 0.0); // Should show improvement
}

test "phoenix_evolution_init" {
    const phoenix = PhoenixEvolution.init();
    try std.testing.expectEqual(@as(u32, 29), phoenix.current_version);
}

test "phoenix_evolution_record" {
    var phoenix = PhoenixEvolution.init();
    phoenix.recordVersion(29, 200, 7.0);
    try std.testing.expectEqual(@as(usize, 1), phoenix.trajectory.snapshot_count);
}

test "phoenix_evolution_summary" {
    var phoenix = PhoenixEvolution.init();
    phoenix.recordVersion(28, 59, 1.0);
    phoenix.recordVersion(29, 200, 7.0);
    
    const summary = phoenix.getSummary();
    try std.testing.expect(summary.versions_evolved > 0);
}

test "phoenix_rebirth_check" {
    const phoenix = PhoenixEvolution.init();
    try std.testing.expect(phoenix.isReadyForRebirth()); // 0 % 999 == 0
}
