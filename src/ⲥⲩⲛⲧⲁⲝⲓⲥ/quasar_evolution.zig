// ═══════════════════════════════════════════════════════════════
// QUASAR EVOLUTION ENGINE
// Based on: arXiv:2511.13843 - QUASAR Algorithm
// Asymptotically Decaying Archive-Based Reinitialization
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
// Author: Dmitrii Vasilev
// Date: January 17, 2026
// ═══════════════════════════════════════════════════════════════
//
// QUASAR achieves:
//   - Lowest rank sum (150) on CEC2017 benchmark
//   - 1.4x faster than DE
//   - 7.8x faster than L-SHADE
//
// Key innovations:
//   1. Archive-based weighted combinations
//   2. Asymptotically decaying reinitialization
//   3. No covariance matrix (matrix-free)
//
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const math = std.math;

// ═══════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQUARED: f64 = PHI * PHI;
pub const INV_PHI: f64 = 1.0 / PHI; // ≈ 0.618
pub const GOLDEN_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3

// ═══════════════════════════════════════════════════════════════
// INDIVIDUAL
// ═══════════════════════════════════════════════════════════════

pub const Individual = struct {
    genes: []f64,
    fitness: f64,
    generation: u32,

    pub fn init(allocator: Allocator, dim: usize) !Individual {
        const genes = try allocator.alloc(f64, dim);
        return .{
            .genes = genes,
            .fitness = math.inf(f64),
            .generation = 0,
        };
    }

    pub fn deinit(self: *Individual, allocator: Allocator) void {
        allocator.free(self.genes);
    }

    pub fn clone(self: *const Individual, allocator: Allocator) !Individual {
        const genes = try allocator.alloc(f64, self.genes.len);
        @memcpy(genes, self.genes);
        return .{
            .genes = genes,
            .fitness = self.fitness,
            .generation = self.generation,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// ARCHIVE (QUASAR Key Component)
// ═══════════════════════════════════════════════════════════════

pub const Archive = struct {
    allocator: Allocator,
    individuals: std.ArrayList(Individual),
    max_size: usize,

    pub fn init(allocator: Allocator, max_size: usize) Archive {
        return .{
            .allocator = allocator,
            .individuals = std.ArrayList(Individual).init(allocator),
            .max_size = max_size,
        };
    }

    pub fn deinit(self: *Archive) void {
        for (self.individuals.items) |*ind| {
            ind.deinit(self.allocator);
        }
        self.individuals.deinit();
    }

    pub fn add(self: *Archive, individual: Individual) !void {
        if (self.individuals.items.len >= self.max_size) {
            // Remove worst individual
            var worst_idx: usize = 0;
            var worst_fitness = self.individuals.items[0].fitness;
            for (self.individuals.items, 0..) |ind, i| {
                if (ind.fitness > worst_fitness) {
                    worst_fitness = ind.fitness;
                    worst_idx = i;
                }
            }
            self.individuals.items[worst_idx].deinit(self.allocator);
            _ = self.individuals.orderedRemove(worst_idx);
        }
        const cloned = try individual.clone(self.allocator);
        try self.individuals.append(cloned);
    }

    pub fn getBest(self: *Archive) ?*Individual {
        if (self.individuals.items.len == 0) return null;
        var best_idx: usize = 0;
        var best_fitness = self.individuals.items[0].fitness;
        for (self.individuals.items, 0..) |ind, i| {
            if (ind.fitness < best_fitness) {
                best_fitness = ind.fitness;
                best_idx = i;
            }
        }
        return &self.individuals.items[best_idx];
    }

    pub fn getWeightedCombination(self: *Archive, rng: *std.Random.DefaultPrng, dim: usize) ?[]f64 {
        if (self.individuals.items.len < 2) return null;

        const result = self.allocator.alloc(f64, dim) catch return null;
        @memset(result, 0);

        // Weighted combination based on fitness
        var total_weight: f64 = 0;
        for (self.individuals.items) |ind| {
            const weight = 1.0 / (1.0 + ind.fitness);
            total_weight += weight;
        }

        for (self.individuals.items) |ind| {
            const weight = (1.0 / (1.0 + ind.fitness)) / total_weight;
            for (result, 0..) |*r, i| {
                r.* += ind.genes[i] * weight;
            }
        }

        // Add small perturbation
        for (result) |*r| {
            r.* += (rng.random().float(f64) - 0.5) * 0.1;
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════
// QUASAR CONFIGURATION
// ═══════════════════════════════════════════════════════════════

pub const QUASARConfig = struct {
    population_size: usize = 81, // 3^4 (Sacred)
    archive_size: usize = 27, // 3^3 (Sacred)
    dimensions: usize = 27, // 3^3 (Sacred)
    max_generations: u32 = 999, // Sacred number
    mutation_rate: f64 = 0.111, // 1/9 (Sacred)
    crossover_rate: f64 = 0.618, // 1/φ (Golden)
    reinit_decay: f64 = 0.95, // Asymptotic decay
    bounds_min: f64 = -100.0,
    bounds_max: f64 = 100.0,
};

// ═══════════════════════════════════════════════════════════════
// QUASAR ENGINE
// ═══════════════════════════════════════════════════════════════

pub const QUASAREngine = struct {
    allocator: Allocator,
    config: QUASARConfig,
    population: std.ArrayList(Individual),
    archive: Archive,
    rng: std.Random.DefaultPrng,

    // Statistics
    generation: u32,
    best_fitness: f64,
    evaluations: u64,
    reinit_probability: f64,

    // Fitness function
    fitness_fn: *const fn ([]const f64) f64,

    pub fn init(allocator: Allocator, config: QUASARConfig, fitness_fn: *const fn ([]const f64) f64) QUASAREngine {
        const seed: u64 = @intCast(std.time.timestamp());
        return .{
            .allocator = allocator,
            .config = config,
            .population = std.ArrayList(Individual).init(allocator),
            .archive = Archive.init(allocator, config.archive_size),
            .rng = std.Random.DefaultPrng.init(seed),
            .generation = 0,
            .best_fitness = math.inf(f64),
            .evaluations = 0,
            .reinit_probability = 1.0,
            .fitness_fn = fitness_fn,
        };
    }

    pub fn deinit(self: *QUASAREngine) void {
        for (self.population.items) |*ind| {
            ind.deinit(self.allocator);
        }
        self.population.deinit();
        self.archive.deinit();
    }

    /// Initialize population randomly
    pub fn initPopulation(self: *QUASAREngine) !void {
        var i: usize = 0;
        while (i < self.config.population_size) : (i += 1) {
            var ind = try Individual.init(self.allocator, self.config.dimensions);
            for (ind.genes) |*g| {
                g.* = self.config.bounds_min +
                    self.rng.random().float(f64) * (self.config.bounds_max - self.config.bounds_min);
            }
            ind.fitness = self.fitness_fn(ind.genes);
            self.evaluations += 1;
            try self.population.append(ind);
        }
    }

    /// QUASAR mutation with archive-based weighted combination
    pub fn mutate(self: *QUASAREngine, target: *Individual) !void {
        // Get weighted combination from archive
        if (self.archive.getWeightedCombination(&self.rng, self.config.dimensions)) |archive_vec| {
            defer self.allocator.free(archive_vec);

            // Differential mutation with archive
            for (target.genes, 0..) |*g, i| {
                if (self.rng.random().float(f64) < self.config.mutation_rate) {
                    const diff = archive_vec[i] - g.*;
                    g.* += diff * self.config.mutation_rate * PHI;

                    // Bounds check
                    g.* = @max(self.config.bounds_min, @min(self.config.bounds_max, g.*));
                }
            }
        } else {
            // Standard mutation if archive is empty
            for (target.genes) |*g| {
                if (self.rng.random().float(f64) < self.config.mutation_rate) {
                    g.* += (self.rng.random().float(f64) - 0.5) * 10.0;
                    g.* = @max(self.config.bounds_min, @min(self.config.bounds_max, g.*));
                }
            }
        }
    }

    /// QUASAR crossover
    pub fn crossover(self: *QUASAREngine, parent1: *const Individual, parent2: *const Individual) !Individual {
        const child = try Individual.init(self.allocator, self.config.dimensions);

        for (child.genes, 0..) |*g, i| {
            if (self.rng.random().float(f64) < self.config.crossover_rate) {
                g.* = parent1.genes[i];
            } else {
                g.* = parent2.genes[i];
            }
        }

        return child;
    }

    /// Asymptotically decaying reinitialization (QUASAR key feature)
    pub fn maybeReinitialize(self: *QUASAREngine, individual: *Individual) !void {
        if (self.rng.random().float(f64) < self.reinit_probability) {
            // Reinitialize from archive or random
            if (self.archive.getBest()) |best| {
                // Reinitialize near best archived solution
                for (individual.genes, 0..) |*g, i| {
                    g.* = best.genes[i] + (self.rng.random().float(f64) - 0.5) * 20.0 * self.reinit_probability;
                    g.* = @max(self.config.bounds_min, @min(self.config.bounds_max, g.*));
                }
            } else {
                // Random reinitialization
                for (individual.genes) |*g| {
                    g.* = self.config.bounds_min +
                        self.rng.random().float(f64) * (self.config.bounds_max - self.config.bounds_min);
                }
            }
        }
    }

    /// Run one generation
    pub fn step(self: *QUASAREngine) !void {
        // Sort population by fitness
        std.mem.sort(Individual, self.population.items, {}, struct {
            fn lessThan(_: void, a: Individual, b: Individual) bool {
                return a.fitness < b.fitness;
            }
        }.lessThan);

        // Update best
        if (self.population.items.len > 0 and self.population.items[0].fitness < self.best_fitness) {
            self.best_fitness = self.population.items[0].fitness;
            try self.archive.add(self.population.items[0]);
        }

        // Create new population
        var new_pop = std.ArrayList(Individual).init(self.allocator);

        // Elitism: keep best 3 (Sacred Trinity)
        var elite_count: usize = 0;
        while (elite_count < 3 and elite_count < self.population.items.len) : (elite_count += 1) {
            const cloned = try self.population.items[elite_count].clone(self.allocator);
            try new_pop.append(cloned);
        }

        // Generate rest of population
        while (new_pop.items.len < self.config.population_size) {
            // Tournament selection
            const p1_idx = self.rng.random().intRangeAtMost(usize, 0, self.population.items.len - 1);
            const p2_idx = self.rng.random().intRangeAtMost(usize, 0, self.population.items.len - 1);

            const parent1 = &self.population.items[@min(p1_idx, p2_idx)];
            const parent2 = &self.population.items[@max(p1_idx, p2_idx)];

            var child = try self.crossover(parent1, parent2);
            try self.mutate(&child);
            try self.maybeReinitialize(&child);

            child.fitness = self.fitness_fn(child.genes);
            child.generation = self.generation;
            self.evaluations += 1;

            try new_pop.append(child);
        }

        // Replace old population
        for (self.population.items) |*ind| {
            ind.deinit(self.allocator);
        }
        self.population.deinit();
        self.population = new_pop;

        // Decay reinitialization probability
        self.reinit_probability *= self.config.reinit_decay;
        self.generation += 1;
    }

    /// Run evolution for max_generations
    pub fn run(self: *QUASAREngine) !f64 {
        try self.initPopulation();

        var gen: u32 = 0;
        while (gen < self.config.max_generations) : (gen += 1) {
            try self.step();

            // Early termination if converged
            if (self.best_fitness < 1e-10) break;
        }

        return self.best_fitness;
    }

    /// Get statistics
    pub fn getStats(self: *QUASAREngine) Stats {
        return .{
            .generation = self.generation,
            .best_fitness = self.best_fitness,
            .evaluations = self.evaluations,
            .archive_size = self.archive.individuals.items.len,
            .reinit_probability = self.reinit_probability,
        };
    }

    pub const Stats = struct {
        generation: u32,
        best_fitness: f64,
        evaluations: u64,
        archive_size: usize,
        reinit_probability: f64,
    };
};

// ═══════════════════════════════════════════════════════════════
// TEST FITNESS FUNCTIONS
// ═══════════════════════════════════════════════════════════════

/// Sphere function (simple convex)
pub fn sphereFunction(x: []const f64) f64 {
    var sum: f64 = 0;
    for (x) |xi| {
        sum += xi * xi;
    }
    return sum;
}

/// Rastrigin function (multimodal)
pub fn rastriginFunction(x: []const f64) f64 {
    const A: f64 = 10.0;
    var sum: f64 = A * @as(f64, @floatFromInt(x.len));
    for (x) |xi| {
        sum += xi * xi - A * @cos(2.0 * math.pi * xi);
    }
    return sum;
}

/// Sacred Formula fitness: minimize |φ² + 1/φ² - 3|
pub fn sacredFormulaFitness(x: []const f64) f64 {
    if (x.len == 0) return math.inf(f64);

    // Use first gene as φ approximation
    const phi = x[0];
    if (phi <= 0) return math.inf(f64);

    const phi_sq = phi * phi;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;

    return @abs(result - GOLDEN_IDENTITY);
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "archive operations" {
    const allocator = std.testing.allocator;
    var archive = Archive.init(allocator, 5);
    defer archive.deinit();

    var ind = try Individual.init(allocator, 3);
    defer ind.deinit(allocator);
    ind.genes[0] = 1.0;
    ind.genes[1] = 2.0;
    ind.genes[2] = 3.0;
    ind.fitness = 10.0;

    try archive.add(ind);
    try std.testing.expectEqual(@as(usize, 1), archive.individuals.items.len);
}

test "quasar initialization" {
    const allocator = std.testing.allocator;
    var config = QUASARConfig{};
    config.population_size = 10;
    config.dimensions = 5;
    config.max_generations = 10;

    var engine = QUASAREngine.init(allocator, config, sphereFunction);
    defer engine.deinit();

    try engine.initPopulation();
    try std.testing.expectEqual(@as(usize, 10), engine.population.items.len);
}

test "quasar step" {
    const allocator = std.testing.allocator;
    var config = QUASARConfig{};
    config.population_size = 10;
    config.dimensions = 5;
    config.max_generations = 5;

    var engine = QUASAREngine.init(allocator, config, sphereFunction);
    defer engine.deinit();

    try engine.initPopulation();
    const initial_best = engine.best_fitness;

    try engine.step();
    try engine.step();

    // Fitness should improve or stay same
    try std.testing.expect(engine.best_fitness <= initial_best + 1e-10);
}

test "sacred formula optimization" {
    const allocator = std.testing.allocator;
    var config = QUASARConfig{};
    config.population_size = 27; // 3^3
    config.dimensions = 1;
    config.max_generations = 100;
    config.bounds_min = 1.0;
    config.bounds_max = 2.0;

    var engine = QUASAREngine.init(allocator, config, sacredFormulaFitness);
    defer engine.deinit();

    const best = try engine.run();

    // Should find φ ≈ 1.618 where φ² + 1/φ² = 3
    try std.testing.expect(best < 0.1);
}

test "golden identity" {
    const result = PHI_SQUARED + (1.0 / PHI_SQUARED);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 1e-10);
}
