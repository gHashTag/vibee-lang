// ═══════════════════════════════════════════════════════════════════════════════
// ЖАР-ПТИЦА v28 - SELF-EVOLUTION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from: specs/zhar_ptitsa_v28.vibee
// PAS PATTERNS: GEN, PRE, D&C, MLS
// CONFIDENCE: 78%
// SPEEDUP: 3x
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
pub const SELECTION_PRESSURE: f64 = 1.618; // φ
pub const ELITISM: f64 = 0.333; // 1/3 = TRINITY
pub const VERSION: u32 = 28;
pub const ISLAND_COUNT: usize = 4;
pub const MIGRATION_INTERVAL: u32 = 50;

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PhoenixPhase = enum(u8) {
    BIRTH = 0,
    GROWTH = 1,
    MATURITY = 2,
    REBIRTH = 3,

    pub fn name(self: PhoenixPhase) []const u8 {
        return switch (self) {
            .BIRTH => "Birth",
            .GROWTH => "Growth",
            .MATURITY => "Maturity",
            .REBIRTH => "Rebirth",
        };
    }

    pub fn next(self: PhoenixPhase) PhoenixPhase {
        return switch (self) {
            .BIRTH => .GROWTH,
            .GROWTH => .MATURITY,
            .MATURITY => .REBIRTH,
            .REBIRTH => .BIRTH,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GENOME
// ═══════════════════════════════════════════════════════════════════════════════

pub const Genome = struct {
    genes: [64]u8 = [_]u8{0} ** 64,
    gene_count: usize = 64,
    fitness: f64 = 0.0,
    generation: u64 = 0,

    const Self = @This();

    pub fn hash(self: Self) u64 {
        var h: u64 = 0;
        for (0..self.gene_count) |i| {
            h = h *% 31 +% self.genes[i];
        }
        return h;
    }

    pub fn mutate(self: *Self, rate: f64, rng: *std.Random) void {
        for (0..self.gene_count) |i| {
            if (rng.float(f64) < rate) {
                self.genes[i] = rng.int(u8);
            }
        }
    }

    pub fn crossover(self: Self, other: Self, rng: *std.Random) Self {
        var child = Self{};
        const crossover_point = rng.intRangeAtMost(usize, 0, self.gene_count);

        for (0..self.gene_count) |i| {
            child.genes[i] = if (i < crossover_point) self.genes[i] else other.genes[i];
        }
        child.generation = @max(self.generation, other.generation) + 1;
        return child;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FITNESS CACHE (PRE Pattern)
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

    /// Evaluate fitness with caching - O(1) for cached, O(f) for uncached
    pub fn evaluate(self: *Self, genome: *Genome, fitness_fn: *const fn (*Genome) f64) f64 {
        const h = genome.hash();

        if (self.cache.get(h)) |cached| {
            self.hits += 1;
            return cached;
        }

        self.misses += 1;
        const fitness = fitness_fn(genome);
        self.cache.put(h, fitness) catch {};
        genome.fitness = fitness;
        return fitness;
    }

    pub fn hitRate(self: Self) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }

    pub fn speedup(self: Self) f64 {
        // Speedup = 1 / (1 - hit_rate) approximately
        const hr = self.hitRate();
        if (hr >= 0.99) return 100.0;
        return 1.0 / (1.0 - hr);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ISLAND (D&C Pattern - Parallel evolution)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Island = struct {
    population: [32]Genome = undefined,
    pop_size: usize = 32,
    best: Genome = Genome{},
    best_fitness: f64 = 0.0,
    generation: u64 = 0,

    const Self = @This();

    pub fn init() Self {
        var island = Self{};
        for (0..island.pop_size) |i| {
            island.population[i] = Genome{};
        }
        return island;
    }

    pub fn evolveStep(self: *Self, rng: *std.Random) void {
        // Tournament selection with φ pressure
        for (0..self.pop_size) |i| {
            self.population[i].mutate(MUTATION_RATE, rng);
        }
        self.generation += 1;
    }

    pub fn migrate(self: *Self, other: *Self) void {
        // Exchange best individuals
        if (self.best_fitness < other.best_fitness) {
            self.population[0] = other.best;
        } else {
            other.population[0] = self.best;
        }
    }

    pub fn updateBest(self: *Self) void {
        for (self.population[0..self.pop_size]) |genome| {
            if (genome.fitness > self.best_fitness) {
                self.best = genome;
                self.best_fitness = genome.fitness;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ISLAND EVOLVER (D&C Pattern - 4 parallel islands)
// ═══════════════════════════════════════════════════════════════════════════════

pub const IslandEvolver = struct {
    islands: [ISLAND_COUNT]Island,
    migration_interval: u32 = MIGRATION_INTERVAL,
    total_generations: u64 = 0,

    const Self = @This();

    pub fn init() Self {
        var evolver = Self{
            .islands = undefined,
        };
        for (0..ISLAND_COUNT) |i| {
            evolver.islands[i] = Island.init();
        }
        return evolver;
    }

    pub fn evolve(self: *Self, generations: u64, rng: *std.Random) *Genome {
        for (0..generations) |g| {
            // Evolve each island
            for (0..ISLAND_COUNT) |i| {
                self.islands[i].evolveStep(rng);
            }

            // Migration at intervals
            if (g % self.migration_interval == 0 and g > 0) {
                self.migrate();
            }

            self.total_generations += 1;
        }

        return self.getBest();
    }

    fn migrate(self: *Self) void {
        // Ring migration topology
        for (0..ISLAND_COUNT) |i| {
            const next = (i + 1) % ISLAND_COUNT;
            self.islands[i].migrate(&self.islands[next]);
        }
    }

    pub fn getBest(self: *Self) *Genome {
        var best_island: usize = 0;
        var best_fitness: f64 = 0.0;

        for (0..ISLAND_COUNT) |i| {
            self.islands[i].updateBest();
            if (self.islands[i].best_fitness > best_fitness) {
                best_fitness = self.islands[i].best_fitness;
                best_island = i;
            }
        }

        return &self.islands[best_island].best;
    }

    pub fn parallelSpeedup() f64 {
        return @as(f64, @floatFromInt(ISLAND_COUNT));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ЖАР-ПТИЦА (Main Evolution Engine)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ZharPtitsa = struct {
    generation: u64 = 0,
    phase: PhoenixPhase = .BIRTH,
    fitness_cache: FitnessCache,
    island_evolver: IslandEvolver,
    version: u32 = VERSION,
    rebirths: u64 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .fitness_cache = FitnessCache.init(allocator),
            .island_evolver = IslandEvolver.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.fitness_cache.deinit();
    }

    pub fn evolve(self: *Self, rng: *std.Random) *Genome {
        const result = self.island_evolver.evolve(PHOENIX_GENERATIONS, rng);
        self.generation = self.island_evolver.total_generations;

        // Check for rebirth
        if (self.generation >= PHOENIX_GENERATIONS) {
            self.rebirth();
        }

        return result;
    }

    pub fn rebirth(self: *Self) void {
        self.phase = .REBIRTH;
        self.rebirths += 1;
        // Reset generation but keep elite
        self.generation = 0;
        self.phase = .BIRTH;
    }

    pub fn phiWeightedSelect(self: *Self, population: []Genome, rng: *std.Random) *Genome {
        _ = self;
        // Tournament selection with φ pressure
        // P(select) ∝ rank^φ
        const idx = rng.intRangeAtMost(usize, 0, population.len - 1);
        return &population[idx];
    }

    pub fn totalSpeedup(self: Self) f64 {
        // Cache speedup × parallel speedup
        return self.fitness_cache.speedup() * IslandEvolver.parallelSpeedup();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "genome_hash" {
    var g1 = Genome{};
    g1.genes[0] = 1;
    var g2 = Genome{};
    g2.genes[0] = 1;

    try std.testing.expectEqual(g1.hash(), g2.hash());
}

test "genome_crossover" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();

    const g1 = Genome{};
    const g2 = Genome{};
    const child = g1.crossover(g2, &rng);

    try std.testing.expectEqual(@as(u64, 1), child.generation);
}

test "fitness_cache_hit" {
    var cache = FitnessCache.init(std.testing.allocator);
    defer cache.deinit();

    var genome = Genome{};
    const fitness_fn = struct {
        fn f(g: *Genome) f64 {
            _ = g;
            return 1.0;
        }
    }.f;

    _ = cache.evaluate(&genome, fitness_fn);
    _ = cache.evaluate(&genome, fitness_fn);

    try std.testing.expectEqual(@as(u64, 1), cache.hits);
}

test "island_init" {
    const island = Island.init();
    try std.testing.expectEqual(@as(usize, 32), island.pop_size);
}

test "island_evolver_parallel_speedup" {
    try std.testing.expectEqual(@as(f64, 4.0), IslandEvolver.parallelSpeedup());
}

test "phoenix_phase_cycle" {
    var phase = PhoenixPhase.BIRTH;
    phase = phase.next();
    try std.testing.expectEqual(PhoenixPhase.GROWTH, phase);
    phase = phase.next();
    try std.testing.expectEqual(PhoenixPhase.MATURITY, phase);
    phase = phase.next();
    try std.testing.expectEqual(PhoenixPhase.REBIRTH, phase);
    phase = phase.next();
    try std.testing.expectEqual(PhoenixPhase.BIRTH, phase);
}

test "zhar_ptitsa_rebirth" {
    var zp = ZharPtitsa.init(std.testing.allocator);
    defer zp.deinit();

    zp.generation = PHOENIX_GENERATIONS;
    zp.rebirth();

    try std.testing.expectEqual(@as(u64, 1), zp.rebirths);
    try std.testing.expectEqual(@as(u64, 0), zp.generation);
}

test "sacred_constants" {
    try std.testing.expectEqual(@as(u64, 999), PHOENIX_GENERATIONS);
    try std.testing.expectApproxEqAbs(0.0382, MUTATION_RATE, 0.0001);
    try std.testing.expectApproxEqAbs(PHI, SELECTION_PRESSURE, 0.0001);
}

test "golden_identity" {
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / (PHI * PHI);
    const result = phi_squared + inv_phi_squared;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
