// ═══════════════════════════════════════════════════════════════════════════════
// ⲪⲞⲈⲚⲒⲜ BENCHMARK - EVOLUTION VS STATIC CODE
// ═══════════════════════════════════════════════════════════════════════════════
// Compares:
//   1. Static hand-optimized code
//   2. Phoenix-evolved code
//   3. Random search baseline
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const phoenix = @import("phoenix.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK TARGET: Simple arithmetic optimization
// ═══════════════════════════════════════════════════════════════════════════════

/// Static implementation (baseline)
fn staticCompute(data: []const i32) i64 {
    var sum: i64 = 0;
    for (data) |x| {
        sum += @as(i64, x) * @as(i64, x);
    }
    return sum;
}

/// Evolved fitness function - measures how close genome produces correct result
fn evolvedFitness(genome: *const phoenix.Genome) f64 {
    // Simulate genome execution
    var result: i64 = 0;
    for (genome.genes) |gene| {
        const op = gene.opcode % 4;
        const a = @as(i64, gene.operand1);
        const b = @as(i64, gene.operand2);
        
        result += switch (op) {
            0 => a + b,
            1 => a * b,
            2 => a - b,
            3 => if (b != 0) @divTrunc(a, b) else a,
            else => 0,
        };
    }
    
    // Fitness = inverse of distance from target
    const target: i64 = 1000;
    const distance = @abs(result - target);
    return 1.0 / (1.0 + @as(f64, @floatFromInt(distance)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲪⲞⲈⲚⲒⲜ BENCHMARK - EVOLUTION VS STATIC CODE\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // BENCHMARK 1: Static computation
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("BENCHMARK 1: Static Computation\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    var data: [1000]i32 = undefined;
    for (&data, 0..) |*d, i| {
        d.* = @intCast(i % 100);
    }
    
    var timer = try std.time.Timer.start();
    
    const iterations: usize = 100000;
    var static_result: i64 = 0;
    for (0..iterations) |_| {
        static_result = staticCompute(&data);
    }
    
    const static_time = timer.read();
    try stdout.print("  Result: {d}\n", .{static_result});
    try stdout.print("  Time: {d:.3} ms ({d} iterations)\n", .{
        @as(f64, @floatFromInt(static_time)) / 1_000_000.0,
        iterations,
    });
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // BENCHMARK 2: Phoenix Evolution
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("BENCHMARK 2: Phoenix Evolution\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    try stdout.print("  Population: {d}\n", .{phoenix.POPULATION_SIZE});
    try stdout.print("  Islands: {d}\n", .{phoenix.ISLAND_COUNT});
    try stdout.print("  Mutation rate (μ): {d:.4} (1/φ²/10)\n", .{phoenix.MUTATION_RATE});
    try stdout.print("  Crossover rate (χ): {d:.4} (1/φ/10)\n", .{phoenix.CROSSOVER_RATE});
    try stdout.print("  Elitism (ε): {d:.3} (1/3 Trinity)\n", .{phoenix.ELITISM});
    try stdout.print("\n", .{});
    
    // Run evolution for limited generations
    const evo_generations: u64 = 100;
    
    timer.reset();
    
    // Create population
    var population = try allocator.alloc(phoenix.Genome, phoenix.POPULATION_SIZE);
    defer {
        for (population) |*g| g.deinit();
        allocator.free(population);
    }
    
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    
    for (population) |*genome| {
        genome.* = try phoenix.Genome.init(allocator, 32);
        genome.randomize(rng);
    }
    
    // Evolve
    var best_fitness: f64 = 0.0;
    var gen: u64 = 0;
    while (gen < evo_generations) : (gen += 1) {
        // Evaluate
        for (population) |*genome| {
            genome.fitness = evolvedFitness(genome);
            if (genome.fitness > best_fitness) {
                best_fitness = genome.fitness;
            }
        }
        
        // Select elite
        phoenix.NuDaemon.selectElite(population, 11);
        
        // Mutate non-elite
        for (population[11..]) |*genome| {
            phoenix.LambdaDaemon.mutate(genome, rng);
        }
    }
    
    const evo_time = timer.read();
    
    try stdout.print("  Generations: {d}\n", .{evo_generations});
    try stdout.print("  Best fitness: {d:.6}\n", .{best_fitness});
    try stdout.print("  Evolution time: {d:.3} ms\n", .{
        @as(f64, @floatFromInt(evo_time)) / 1_000_000.0,
    });
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // BENCHMARK 3: Random Search Baseline
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("BENCHMARK 3: Random Search Baseline\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    
    timer.reset();
    
    var random_best: f64 = 0.0;
    const random_samples = evo_generations * phoenix.POPULATION_SIZE;
    
    var random_genome = try phoenix.Genome.init(allocator, 32);
    defer random_genome.deinit();
    
    for (0..random_samples) |_| {
        random_genome.randomize(rng);
        const fitness = evolvedFitness(&random_genome);
        if (fitness > random_best) {
            random_best = fitness;
        }
    }
    
    const random_time = timer.read();
    
    try stdout.print("  Samples: {d}\n", .{random_samples});
    try stdout.print("  Best fitness: {d:.6}\n", .{random_best});
    try stdout.print("  Search time: {d:.3} ms\n", .{
        @as(f64, @floatFromInt(random_time)) / 1_000_000.0,
    });
    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // RESULTS SUMMARY
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("RESULTS SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    
    const improvement = if (random_best > 0) (best_fitness / random_best - 1.0) * 100.0 else 0.0;
    
    try stdout.print("\n", .{});
    try stdout.print("  Phoenix Evolution vs Random Search:\n", .{});
    try stdout.print("    Phoenix fitness:  {d:.6}\n", .{best_fitness});
    try stdout.print("    Random fitness:   {d:.6}\n", .{random_best});
    try stdout.print("    Improvement:      {d:.1}%\n", .{improvement});
    try stdout.print("\n", .{});
    
    try stdout.print("  Sacred Constants Verification:\n", .{});
    try stdout.print("    φ² + 1/φ² = {d:.6} (should be 3.0)\n", .{
        phoenix.PHI_SQ + 1.0 / phoenix.PHI_SQ,
    });
    try stdout.print("    PHOENIX = {d} = 3³ × 37 = {d}\n", .{
        phoenix.PHOENIX,
        @as(u64, 27) * 37,
    });
    try stdout.print("\n", .{});
    
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("ⲪⲞⲈⲚⲒⲜ BENCHMARK COMPLETE\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}
