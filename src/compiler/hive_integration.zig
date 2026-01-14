// ============================================================================
// VIBEEC HIVE INTEGRATION
// Integrates evolutionary optimizer with the Hive System (bee colony)
// ============================================================================

const std = @import("std");
const evolution = @import("evolution.zig");
const predictor = @import("performance_predictor.zig");
const validation = @import("validation.zig");

// ============================================================================
// HIVE SYSTEM TYPES
// ============================================================================

/// Bee types in the hive
pub const BeeType = enum {
    Queen,      // Orchestrates evolution
    Scout,      // Scans repository for manual code
    Worker,     // Generates code from specs
    Guard,      // Validates generated code
    Nurse,      // Generates specs from manual code
    Drone,      // Optimizes code performance
};

/// Bee status
pub const BeeStatus = enum {
    Idle,
    Working,
    Completed,
    Error,
};

/// Individual bee in the hive
pub const Bee = struct {
    id: u32,
    bee_type: BeeType,
    status: BeeStatus,
    tasks_completed: u32,
    tasks_failed: u32,
    current_genome: ?evolution.CodegenGenome,
    fitness_score: f64,
};

/// Evolution phase in the hive
pub const EvolutionPhase = enum {
    Scouting,       // Phase 1: Scan repository
    Analysis,       // Phase 2: Analyze code structure
    Specification,  // Phase 3: Generate specs
    Generation,     // Phase 4: Generate code
    Validation,     // Phase 5: Validate code
    Optimization,   // Phase 6: Optimize with genetic algorithm
    Cleanup,        // Phase 7: Final cleanup
};

/// Hive metrics
pub const HiveMetrics = struct {
    manual_code_percent: f64,
    generated_code_percent: f64,
    spec_coverage: f64,
    evolution_generation: u32,
    overall_health: f64,
    active_bees: u32,
    tasks_completed: u32,
    tasks_failed: u32,
    best_fitness: f64,
    avg_fitness: f64,
};

/// Complete Hive System
pub const HiveSystem = struct {
    hive_id: []const u8,
    queen: Bee,
    scouts: []Bee,
    workers: []Bee,
    guards: []Bee,
    nurses: []Bee,
    drones: []Bee,
    current_phase: EvolutionPhase,
    metrics: HiveMetrics,
    best_genome: ?evolution.CodegenGenome,
    population: []evolution.CodegenGenome,
    allocator: std.mem.Allocator,
};

// ============================================================================
// HIVE CREATION AND MANAGEMENT
// ============================================================================

/// Create a new hive system
pub fn createHive(hive_id: []const u8, allocator: std.mem.Allocator) !*HiveSystem {
    var hive = try allocator.create(HiveSystem);
    
    // Create queen
    hive.queen = Bee{
        .id = 0,
        .bee_type = .Queen,
        .status = .Idle,
        .tasks_completed = 0,
        .tasks_failed = 0,
        .current_genome = null,
        .fitness_score = 0,
    };
    
    // Create scouts (5)
    hive.scouts = try allocator.alloc(Bee, 5);
    for (hive.scouts, 0..) |*scout, i| {
        scout.* = Bee{
            .id = @intCast(i + 1),
            .bee_type = .Scout,
            .status = .Idle,
            .tasks_completed = 0,
            .tasks_failed = 0,
            .current_genome = null,
            .fitness_score = 0,
        };
    }
    
    // Create workers (10)
    hive.workers = try allocator.alloc(Bee, 10);
    for (hive.workers, 0..) |*worker, i| {
        worker.* = Bee{
            .id = @intCast(i + 6),
            .bee_type = .Worker,
            .status = .Idle,
            .tasks_completed = 0,
            .tasks_failed = 0,
            .current_genome = null,
            .fitness_score = 0,
        };
    }
    
    // Create guards (5)
    hive.guards = try allocator.alloc(Bee, 5);
    for (hive.guards, 0..) |*guard, i| {
        guard.* = Bee{
            .id = @intCast(i + 16),
            .bee_type = .Guard,
            .status = .Idle,
            .tasks_completed = 0,
            .tasks_failed = 0,
            .current_genome = null,
            .fitness_score = 0,
        };
    }
    
    // Create nurses (5)
    hive.nurses = try allocator.alloc(Bee, 5);
    for (hive.nurses, 0..) |*nurse, i| {
        nurse.* = Bee{
            .id = @intCast(i + 21),
            .bee_type = .Nurse,
            .status = .Idle,
            .tasks_completed = 0,
            .tasks_failed = 0,
            .current_genome = null,
            .fitness_score = 0,
        };
    }
    
    // Create drones (3) - these handle optimization
    hive.drones = try allocator.alloc(Bee, 3);
    for (hive.drones, 0..) |*drone, i| {
        drone.* = Bee{
            .id = @intCast(i + 26),
            .bee_type = .Drone,
            .status = .Idle,
            .tasks_completed = 0,
            .tasks_failed = 0,
            .current_genome = null,
            .fitness_score = 0,
        };
    }
    
    hive.hive_id = hive_id;
    hive.current_phase = .Scouting;
    hive.metrics = HiveMetrics{
        .manual_code_percent = 100.0,
        .generated_code_percent = 0.0,
        .spec_coverage = 0.0,
        .evolution_generation = 0,
        .overall_health = 1.0,
        .active_bees = 0,
        .tasks_completed = 0,
        .tasks_failed = 0,
        .best_fitness = 0.0,
        .avg_fitness = 0.0,
    };
    hive.best_genome = null;
    hive.population = try allocator.alloc(evolution.CodegenGenome, 0);
    hive.allocator = allocator;
    
    return hive;
}

/// Destroy hive and free resources
pub fn destroyHive(hive: *HiveSystem) void {
    hive.allocator.free(hive.scouts);
    hive.allocator.free(hive.workers);
    hive.allocator.free(hive.guards);
    hive.allocator.free(hive.nurses);
    hive.allocator.free(hive.drones);
    hive.allocator.free(hive.population);
    hive.allocator.destroy(hive);
}

// ============================================================================
// EVOLUTION INTEGRATION
// ============================================================================

/// Initialize population for drones (optimization bees)
pub fn initializePopulation(hive: *HiveSystem, population_size: usize) !void {
    hive.allocator.free(hive.population);
    hive.population = try hive.allocator.alloc(evolution.CodegenGenome, population_size);
    
    for (hive.population, 0..) |*genome, i| {
        genome.* = evolution.createRandomGenome(@intCast(i), 0);
        evolution.evaluateFitness(genome, evolution.FitnessWeights{});
    }
    
    // Sort by fitness
    std.mem.sort(evolution.CodegenGenome, hive.population, {}, compareFitness);
    
    // Update metrics
    if (hive.population.len > 0) {
        hive.best_genome = hive.population[0];
        hive.metrics.best_fitness = hive.population[0].fitness;
        
        var sum: f64 = 0;
        for (hive.population) |genome| {
            sum += genome.fitness;
        }
        hive.metrics.avg_fitness = sum / @as(f64, @floatFromInt(hive.population.len));
    }
}

fn compareFitness(context: void, a: evolution.CodegenGenome, b: evolution.CodegenGenome) bool {
    _ = context;
    return a.fitness > b.fitness;
}

/// Run one generation of evolution (drone task)
pub fn evolveGeneration(hive: *HiveSystem) !void {
    if (hive.population.len == 0) return;
    
    const config = evolution.EvolutionConfig{
        .population_size = hive.population.len,
        .mutation_rate = 0.15,
        .crossover_rate = 0.80,
        .elite_count = @min(5, hive.population.len),
        .tournament_size = 3,
    };
    
    // Mark drones as working
    for (hive.drones) |*drone| {
        drone.status = .Working;
    }
    hive.metrics.active_bees = @intCast(hive.drones.len);
    
    // Create next generation
    var new_population = try hive.allocator.alloc(evolution.CodegenGenome, hive.population.len);
    var next_id: u32 = hive.metrics.evolution_generation * @as(u32, @intCast(hive.population.len));
    
    // Keep elite
    for (0..config.elite_count) |i| {
        new_population[i] = hive.population[i];
        new_population[i].generation = hive.metrics.evolution_generation + 1;
    }
    
    // Generate rest through crossover and mutation
    var idx: usize = config.elite_count;
    while (idx < hive.population.len) : (idx += 1) {
        const parent_a_idx = tournamentSelect(hive.population, config.tournament_size);
        const parent_b_idx = tournamentSelect(hive.population, config.tournament_size);
        
        var child = evolution.crossover(&hive.population[parent_a_idx], &hive.population[parent_b_idx], next_id, hive.metrics.evolution_generation + 1);
        next_id += 1;
        
        evolution.mutate(&child, config.mutation_rate);
        evolution.evaluateFitness(&child, evolution.FitnessWeights{});
        
        new_population[idx] = child;
    }
    
    // Sort by fitness
    std.mem.sort(evolution.CodegenGenome, new_population, {}, compareFitness);
    
    // Update hive
    hive.allocator.free(hive.population);
    hive.population = new_population;
    hive.metrics.evolution_generation += 1;
    
    // Update best genome
    if (new_population[0].fitness > hive.metrics.best_fitness) {
        hive.best_genome = new_population[0];
        hive.metrics.best_fitness = new_population[0].fitness;
    }
    
    // Update average fitness
    var sum: f64 = 0;
    for (hive.population) |genome| {
        sum += genome.fitness;
    }
    hive.metrics.avg_fitness = sum / @as(f64, @floatFromInt(hive.population.len));
    
    // Mark drones as completed
    for (hive.drones) |*drone| {
        drone.status = .Completed;
        drone.tasks_completed += 1;
    }
    hive.metrics.tasks_completed += 1;
    hive.metrics.active_bees = 0;
}

fn tournamentSelect(population: []const evolution.CodegenGenome, tournament_size: usize) usize {
    var prng = std.Random.Xoshiro256.init(@intCast(std.time.timestamp()));
    var random = prng.random();
    
    var best_idx: usize = random.intRangeAtMost(usize, 0, population.len - 1);
    var best_fitness = population[best_idx].fitness;
    
    for (1..tournament_size) |_| {
        const idx = random.intRangeAtMost(usize, 0, population.len - 1);
        if (population[idx].fitness > best_fitness) {
            best_idx = idx;
            best_fitness = population[idx].fitness;
        }
    }
    
    return best_idx;
}

/// Assign best genome to workers for code generation
pub fn assignGenomeToWorkers(hive: *HiveSystem) void {
    if (hive.best_genome) |genome| {
        for (hive.workers) |*worker| {
            worker.current_genome = genome;
        }
    }
}

/// Run complete evolution cycle
pub fn runEvolutionCycle(hive: *HiveSystem, generations: u32) !evolution.EvolutionResult {
    const initial_fitness = if (hive.population.len > 0) hive.population[0].fitness else 0;
    
    for (0..generations) |_| {
        try evolveGeneration(hive);
    }
    
    const final_fitness = hive.metrics.best_fitness;
    const improvement = if (initial_fitness > 0) 
        (final_fitness - initial_fitness) / initial_fitness * 100.0 
    else 0;
    
    return evolution.EvolutionResult{
        .best_genome = hive.best_genome orelse evolution.createRandomGenome(0, 0),
        .generations_run = generations,
        .initial_fitness = initial_fitness,
        .final_fitness = final_fitness,
        .improvement_percent = improvement,
    };
}

// ============================================================================
// PHASE MANAGEMENT
// ============================================================================

/// Advance to next evolution phase
pub fn advancePhase(hive: *HiveSystem) void {
    hive.current_phase = switch (hive.current_phase) {
        .Scouting => .Analysis,
        .Analysis => .Specification,
        .Specification => .Generation,
        .Generation => .Validation,
        .Validation => .Optimization,
        .Optimization => .Cleanup,
        .Cleanup => .Scouting, // Cycle back
    };
}

/// Get phase name
pub fn getPhaseName(phase: EvolutionPhase) []const u8 {
    return switch (phase) {
        .Scouting => "Scouting",
        .Analysis => "Analysis",
        .Specification => "Specification",
        .Generation => "Generation",
        .Validation => "Validation",
        .Optimization => "Optimization",
        .Cleanup => "Cleanup",
    };
}

// ============================================================================
// HIVE HEALTH AND REPORTING
// ============================================================================

/// Calculate overall hive health
pub fn calculateHealth(hive: *HiveSystem) f64 {
    var health: f64 = 1.0;
    
    // Factor in task success rate
    const total_tasks = hive.metrics.tasks_completed + hive.metrics.tasks_failed;
    if (total_tasks > 0) {
        const success_rate = @as(f64, @floatFromInt(hive.metrics.tasks_completed)) / @as(f64, @floatFromInt(total_tasks));
        health *= success_rate;
    }
    
    // Factor in fitness improvement
    if (hive.metrics.best_fitness > 0.8) {
        health *= 1.0;
    } else if (hive.metrics.best_fitness > 0.6) {
        health *= 0.9;
    } else {
        health *= 0.8;
    }
    
    // Factor in spec coverage
    health *= (hive.metrics.spec_coverage / 100.0 * 0.2 + 0.8);
    
    hive.metrics.overall_health = health;
    return health;
}

/// Count active bees
pub fn countActiveBees(hive: *HiveSystem) u32 {
    var count: u32 = 0;
    
    if (hive.queen.status == .Working) count += 1;
    
    for (hive.scouts) |scout| {
        if (scout.status == .Working) count += 1;
    }
    for (hive.workers) |worker| {
        if (worker.status == .Working) count += 1;
    }
    for (hive.guards) |guard| {
        if (guard.status == .Working) count += 1;
    }
    for (hive.nurses) |nurse| {
        if (nurse.status == .Working) count += 1;
    }
    for (hive.drones) |drone| {
        if (drone.status == .Working) count += 1;
    }
    
    hive.metrics.active_bees = count;
    return count;
}

/// Print hive status report
pub fn printHiveReport(hive: *HiveSystem, writer: anytype) !void {
    try writer.print("\n", .{});
    try writer.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try writer.print("║                        HIVE SYSTEM STATUS                                   ║\n", .{});
    try writer.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    try writer.print("Hive ID: {s}\n", .{hive.hive_id});
    try writer.print("Current Phase: {s}\n\n", .{getPhaseName(hive.current_phase)});

    try writer.print("Bee Colony:\n", .{});
    try writer.print("  Queen: 1 ({s})\n", .{@tagName(hive.queen.status)});
    try writer.print("  Scouts: {d}\n", .{hive.scouts.len});
    try writer.print("  Workers: {d}\n", .{hive.workers.len});
    try writer.print("  Guards: {d}\n", .{hive.guards.len});
    try writer.print("  Nurses: {d}\n", .{hive.nurses.len});
    try writer.print("  Drones: {d}\n", .{hive.drones.len});
    try writer.print("  Total: {d}\n\n", .{1 + hive.scouts.len + hive.workers.len + hive.guards.len + hive.nurses.len + hive.drones.len});

    try writer.print("Evolution Metrics:\n", .{});
    try writer.print("  Generation: {d}\n", .{hive.metrics.evolution_generation});
    try writer.print("  Best Fitness: {d:.4}\n", .{hive.metrics.best_fitness});
    try writer.print("  Avg Fitness: {d:.4}\n", .{hive.metrics.avg_fitness});
    try writer.print("  Population Size: {d}\n\n", .{hive.population.len});

    try writer.print("Code Metrics:\n", .{});
    try writer.print("  Manual Code: {d:.1}%\n", .{hive.metrics.manual_code_percent});
    try writer.print("  Generated Code: {d:.1}%\n", .{hive.metrics.generated_code_percent});
    try writer.print("  Spec Coverage: {d:.1}%\n\n", .{hive.metrics.spec_coverage});

    try writer.print("Task Metrics:\n", .{});
    try writer.print("  Tasks Completed: {d}\n", .{hive.metrics.tasks_completed});
    try writer.print("  Tasks Failed: {d}\n", .{hive.metrics.tasks_failed});
    try writer.print("  Active Bees: {d}\n\n", .{countActiveBees(hive)});

    try writer.print("Overall Health: {d:.1}%\n\n", .{calculateHealth(hive) * 100});

    if (hive.best_genome) |genome| {
        try writer.print("Best Genome Parameters:\n", .{});
        try writer.print("  optimization_level: {d}\n", .{genome.optimization_level});
        try writer.print("  inline_threshold: {d}\n", .{genome.inline_threshold});
        try writer.print("  loop_unroll_factor: {d}\n", .{genome.loop_unroll_factor});
        try writer.print("  use_simd: {s}\n", .{if (genome.use_simd) "true" else "false"});
        try writer.print("  register_allocation: {s}\n", .{@tagName(genome.register_allocation)});
        try writer.print("  code_layout: {s}\n", .{@tagName(genome.code_layout)});
    }
}

// ============================================================================
// MAIN - Demonstrate Hive Integration
// ============================================================================

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              VIBEEC HIVE INTEGRATION                                        ║\n", .{});
    try stdout.print("║              Evolutionary Optimizer + Bee Colony System                     ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Create hive
    try stdout.print("Creating hive system...\n", .{});
    var hive = try createHive("vibee-hive-001", allocator);
    defer destroyHive(hive);

    // Initialize population
    try stdout.print("Initializing population (50 genomes)...\n", .{});
    try initializePopulation(hive, 50);

    // Print initial status
    try printHiveReport(hive, stdout);

    // Run evolution phases
    try stdout.print("\n═══ RUNNING EVOLUTION CYCLE ═══\n\n", .{});

    // Advance through phases
    for (0..6) |_| {
        try stdout.print("Phase: {s}\n", .{getPhaseName(hive.current_phase)});
        
        if (hive.current_phase == .Optimization) {
            // Run 20 generations of evolution
            try stdout.print("  Running 20 generations of evolution...\n", .{});
            const result = try runEvolutionCycle(hive, 20);
            try stdout.print("  Improvement: {d:.1}%\n", .{result.improvement_percent});
        }
        
        advancePhase(hive);
    }

    // Assign best genome to workers
    assignGenomeToWorkers(hive);

    // Update metrics (simulate progress)
    hive.metrics.manual_code_percent = 30.0;
    hive.metrics.generated_code_percent = 70.0;
    hive.metrics.spec_coverage = 85.0;

    // Print final status
    try stdout.print("\n═══ FINAL STATUS ═══\n", .{});
    try printHiveReport(hive, stdout);

    try stdout.print("✅ Hive integration complete\n", .{});
}

// ============================================================================
// TESTS
// ============================================================================

test "create hive system" {
    const hive = try createHive("test-hive", std.testing.allocator);
    defer destroyHive(hive);
    
    try std.testing.expect(hive.scouts.len == 5);
    try std.testing.expect(hive.workers.len == 10);
    try std.testing.expect(hive.guards.len == 5);
    try std.testing.expect(hive.nurses.len == 5);
    try std.testing.expect(hive.drones.len == 3);
}

test "initialize population" {
    const hive = try createHive("test-hive", std.testing.allocator);
    defer destroyHive(hive);
    
    try initializePopulation(hive, 20);
    
    try std.testing.expect(hive.population.len == 20);
    try std.testing.expect(hive.best_genome != null);
    try std.testing.expect(hive.metrics.best_fitness > 0);
}

test "evolve generation" {
    const hive = try createHive("test-hive", std.testing.allocator);
    defer destroyHive(hive);
    
    try initializePopulation(hive, 20);
    const initial_gen = hive.metrics.evolution_generation;
    
    try evolveGeneration(hive);
    
    try std.testing.expect(hive.metrics.evolution_generation == initial_gen + 1);
}

test "advance phase" {
    const hive = try createHive("test-hive", std.testing.allocator);
    defer destroyHive(hive);
    
    try std.testing.expect(hive.current_phase == .Scouting);
    advancePhase(hive);
    try std.testing.expect(hive.current_phase == .Analysis);
    advancePhase(hive);
    try std.testing.expect(hive.current_phase == .Specification);
}

test "calculate health" {
    const hive = try createHive("test-hive", std.testing.allocator);
    defer destroyHive(hive);
    
    try initializePopulation(hive, 20);
    hive.metrics.tasks_completed = 100;
    hive.metrics.tasks_failed = 5;
    
    const health = calculateHealth(hive);
    try std.testing.expect(health > 0 and health <= 1);
}
