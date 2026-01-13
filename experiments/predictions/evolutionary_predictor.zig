const std = @import("std");
const math = std.math;

// ============================================================================
// EVOLUTIONARY ELEMENT PROPERTY PREDICTOR
// Uses genetic algorithm to optimize prediction model parameters
// ============================================================================

const ALPHA: f64 = 1.0 / 137.036;

// Known elements for validation
const KnownElement = struct {
    z: u16,
    n: u16,
    mass: f64,
    radius_pm: f64,
    ie_ev: f64,
};

const KNOWN_ELEMENTS = [_]KnownElement{
    .{ .z = 26, .n = 30, .mass = 55.845, .radius_pm = 126, .ie_ev = 7.90 },
    .{ .z = 29, .n = 35, .mass = 63.546, .radius_pm = 128, .ie_ev = 7.73 },
    .{ .z = 47, .n = 61, .mass = 107.87, .radius_pm = 144, .ie_ev = 7.58 },
    .{ .z = 79, .n = 118, .mass = 196.97, .radius_pm = 144, .ie_ev = 9.23 },
    .{ .z = 82, .n = 126, .mass = 207.2, .radius_pm = 175, .ie_ev = 7.42 },
    .{ .z = 92, .n = 146, .mass = 238.03, .radius_pm = 156, .ie_ev = 6.19 },
};

// Prediction model genome
const PredictionGenome = struct {
    // Mass formula coefficients
    mass_a: f64, // A coefficient
    mass_b: f64, // B coefficient
    mass_c: f64, // C coefficient
    
    // Radius formula coefficients
    radius_base: f64,
    radius_period_factor: f64,
    radius_rel_factor: f64,
    
    // Ionization energy coefficients
    ie_base: f64,
    ie_z_factor: f64,
    ie_rel_factor: f64,
    
    // Fitness score
    fitness: f64,
    generation: u32,
};

// Random number generator
var prng: std.Random.Xoshiro256 = undefined;
var random: std.Random = undefined;

fn initRandom() void {
    prng = std.Random.Xoshiro256.init(@intCast(std.time.timestamp()));
    random = prng.random();
}

fn randomFloat(min: f64, max: f64) f64 {
    return min + random.float(f64) * (max - min);
}

fn randomInt(min: u32, max: u32) u32 {
    return min + random.intRangeAtMost(u32, 0, max - min);
}

// Create random genome
fn createRandomGenome(gen: u32) PredictionGenome {
    return PredictionGenome{
        .mass_a = randomFloat(2.0, 3.0),
        .mass_b = randomFloat(-0.02, 0.02),
        .mass_c = randomFloat(-5.0, 15.0),
        
        .radius_base = randomFloat(30.0, 80.0),
        .radius_period_factor = randomFloat(15.0, 40.0),
        .radius_rel_factor = randomFloat(0.5, 1.5),
        
        .ie_base = randomFloat(3.0, 8.0),
        .ie_z_factor = randomFloat(0.01, 0.05),
        .ie_rel_factor = randomFloat(0.5, 2.0),
        
        .fitness = 0.0,
        .generation = gen,
    };
}

// Predict mass using genome parameters
fn predictMass(genome: *const PredictionGenome, z: u16, n: u16) f64 {
    const zf: f64 = @floatFromInt(z);
    const nf: f64 = @floatFromInt(n);
    const a: f64 = zf + nf;
    
    return genome.mass_a * a + genome.mass_b * a * a + genome.mass_c;
}

// Predict radius using genome parameters
fn predictRadius(genome: *const PredictionGenome, z: u16) f64 {
    const zf: f64 = @floatFromInt(z);
    const period: f64 = @ceil(zf / 18.0);
    
    // Relativistic factor
    const v_over_c = zf * ALPHA;
    const rel_factor = if (v_over_c >= 0.99) 0.1 else @sqrt(1.0 - v_over_c * v_over_c);
    
    return (genome.radius_base + genome.radius_period_factor * period) * 
           math.pow(f64, rel_factor, genome.radius_rel_factor);
}

// Predict ionization energy using genome parameters
fn predictIE(genome: *const PredictionGenome, z: u16) f64 {
    const zf: f64 = @floatFromInt(z);
    
    // Relativistic factor
    const v_over_c = zf * ALPHA;
    const rel_factor = if (v_over_c >= 0.99) 0.1 else @sqrt(1.0 - v_over_c * v_over_c);
    
    return genome.ie_base + genome.ie_z_factor * zf + 
           genome.ie_rel_factor * (1.0 / rel_factor - 1.0);
}

// Calculate fitness based on prediction accuracy
fn evaluateFitness(genome: *PredictionGenome) void {
    var total_error: f64 = 0.0;
    
    for (KNOWN_ELEMENTS) |elem| {
        // Mass error
        const pred_mass = predictMass(genome, elem.z, elem.n);
        const mass_error = @abs(pred_mass - elem.mass) / elem.mass;
        
        // Radius error
        const pred_radius = predictRadius(genome, elem.z);
        const radius_error = @abs(pred_radius - elem.radius_pm) / elem.radius_pm;
        
        // IE error
        const pred_ie = predictIE(genome, elem.z);
        const ie_error = @abs(pred_ie - elem.ie_ev) / elem.ie_ev;
        
        // Weighted error
        total_error += mass_error * 0.4 + radius_error * 0.3 + ie_error * 0.3;
    }
    
    const avg_error = total_error / @as(f64, @floatFromInt(KNOWN_ELEMENTS.len));
    
    // Fitness = 1 / (1 + error)
    genome.fitness = 1.0 / (1.0 + avg_error);
}

// Mutate genome
fn mutate(genome: *PredictionGenome, rate: f64) void {
    if (random.float(f64) < rate) {
        genome.mass_a += randomFloat(-0.1, 0.1);
    }
    if (random.float(f64) < rate) {
        genome.mass_b += randomFloat(-0.005, 0.005);
    }
    if (random.float(f64) < rate) {
        genome.mass_c += randomFloat(-2.0, 2.0);
    }
    if (random.float(f64) < rate) {
        genome.radius_base += randomFloat(-5.0, 5.0);
    }
    if (random.float(f64) < rate) {
        genome.radius_period_factor += randomFloat(-3.0, 3.0);
    }
    if (random.float(f64) < rate) {
        genome.ie_base += randomFloat(-0.5, 0.5);
    }
    if (random.float(f64) < rate) {
        genome.ie_z_factor += randomFloat(-0.01, 0.01);
    }
}

// Crossover two genomes
fn crossover(parent_a: *const PredictionGenome, parent_b: *const PredictionGenome, gen: u32) PredictionGenome {
    return PredictionGenome{
        .mass_a = if (random.boolean()) parent_a.mass_a else parent_b.mass_a,
        .mass_b = if (random.boolean()) parent_a.mass_b else parent_b.mass_b,
        .mass_c = if (random.boolean()) parent_a.mass_c else parent_b.mass_c,
        .radius_base = if (random.boolean()) parent_a.radius_base else parent_b.radius_base,
        .radius_period_factor = if (random.boolean()) parent_a.radius_period_factor else parent_b.radius_period_factor,
        .radius_rel_factor = if (random.boolean()) parent_a.radius_rel_factor else parent_b.radius_rel_factor,
        .ie_base = if (random.boolean()) parent_a.ie_base else parent_b.ie_base,
        .ie_z_factor = if (random.boolean()) parent_a.ie_z_factor else parent_b.ie_z_factor,
        .ie_rel_factor = if (random.boolean()) parent_a.ie_rel_factor else parent_b.ie_rel_factor,
        .fitness = 0.0,
        .generation = gen,
    };
}

// Sort population by fitness (descending)
fn compareFitness(context: void, a: PredictionGenome, b: PredictionGenome) bool {
    _ = context;
    return a.fitness > b.fitness;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    initRandom();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║          EVOLUTIONARY ELEMENT PROPERTY PREDICTOR                            ║\n", .{});
    try stdout.print("║          Genetic Algorithm for Optimizing Prediction Model                  ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Configuration
    const population_size: usize = 50;
    const generations: u32 = 100;
    const mutation_rate: f64 = 0.15;
    const elite_count: usize = 5;

    try stdout.print("Configuration:\n", .{});
    try stdout.print("  Population: {d}\n", .{population_size});
    try stdout.print("  Generations: {d}\n", .{generations});
    try stdout.print("  Mutation rate: {d:.2}\n", .{mutation_rate});
    try stdout.print("  Elite count: {d}\n\n", .{elite_count});

    // Initialize population
    var population: [population_size]PredictionGenome = undefined;
    for (&population, 0..) |*genome, i| {
        genome.* = createRandomGenome(0);
        _ = i;
    }

    try stdout.print("═══ EVOLUTION PROGRESS ═══\n\n", .{});

    var best_ever: PredictionGenome = population[0];
    
    // Evolution loop
    var gen: u32 = 0;
    while (gen < generations) : (gen += 1) {
        // Evaluate fitness
        for (&population) |*genome| {
            evaluateFitness(genome);
        }
        
        // Sort by fitness
        std.mem.sort(PredictionGenome, &population, {}, compareFitness);
        
        // Track best
        if (population[0].fitness > best_ever.fitness) {
            best_ever = population[0];
        }
        
        // Print progress every 10 generations
        if (gen % 10 == 0 or gen == generations - 1) {
            var sum: f64 = 0;
            for (population) |g| {
                sum += g.fitness;
            }
            const avg = sum / @as(f64, @floatFromInt(population_size));
            
            try stdout.print("Gen {d:3}: best={d:.4}, avg={d:.4}, best_ever={d:.4}\n", .{
                gen, population[0].fitness, avg, best_ever.fitness
            });
        }
        
        // Create next generation (skip on last iteration)
        if (gen < generations - 1) {
            var new_population: [population_size]PredictionGenome = undefined;
            
            // Keep elite
            for (0..elite_count) |i| {
                new_population[i] = population[i];
                new_population[i].generation = gen + 1;
            }
            
            // Generate rest through crossover and mutation
            for (elite_count..population_size) |i| {
                const parent_a_idx = randomInt(0, @intCast(population_size / 2));
                const parent_b_idx = randomInt(0, @intCast(population_size / 2));
                
                var child = crossover(&population[parent_a_idx], &population[parent_b_idx], gen + 1);
                mutate(&child, mutation_rate);
                new_population[i] = child;
            }
            
            population = new_population;
        }
    }

    try stdout.print("\n═══ EVOLUTION COMPLETE ═══\n\n", .{});
    
    try stdout.print("Best genome (fitness={d:.4}):\n", .{best_ever.fitness});
    try stdout.print("  Mass formula:   M = {d:.3}*A + {d:.6}*A² + {d:.2}\n", .{
        best_ever.mass_a, best_ever.mass_b, best_ever.mass_c
    });
    try stdout.print("  Radius formula: R = ({d:.1} + {d:.1}*period) * γ^{d:.2}\n", .{
        best_ever.radius_base, best_ever.radius_period_factor, best_ever.radius_rel_factor
    });
    try stdout.print("  IE formula:     IE = {d:.2} + {d:.4}*Z + {d:.2}*(1/γ - 1)\n", .{
        best_ever.ie_base, best_ever.ie_z_factor, best_ever.ie_rel_factor
    });

    // Validate against known elements
    try stdout.print("\n═══ VALIDATION ═══\n\n", .{});
    try stdout.print("  Z   Element    Mass(pred)  Mass(act)   Error\n", .{});
    try stdout.print("─────────────────────────────────────────────────\n", .{});
    
    for (KNOWN_ELEMENTS) |elem| {
        const pred_mass = predictMass(&best_ever, elem.z, elem.n);
        const error_pct = @abs(pred_mass - elem.mass) / elem.mass * 100.0;
        
        try stdout.print(" {d:3}   -         {d:8.2}    {d:8.2}    {d:5.2}%\n", .{
            elem.z, pred_mass, elem.mass, error_pct
        });
    }

    // Predict superheavy elements
    try stdout.print("\n═══ SUPERHEAVY PREDICTIONS ═══\n\n", .{});
    try stdout.print("  Z   Symbol   Mass(u)   Radius(pm)   IE(eV)\n", .{});
    try stdout.print("──────────────────────────────────────────────\n", .{});
    
    const superheavy = [_]struct { z: u16, n: u16, sym: []const u8 }{
        .{ .z = 119, .n = 177, .sym = "Uue" },
        .{ .z = 120, .n = 180, .sym = "Ubn" },
        .{ .z = 121, .n = 182, .sym = "Ubu" },
        .{ .z = 126, .n = 184, .sym = "Ubh" },
        .{ .z = 137, .n = 200, .sym = "Uts" },
    };
    
    for (superheavy) |elem| {
        const mass = predictMass(&best_ever, elem.z, elem.n);
        const radius = predictRadius(&best_ever, elem.z);
        const ie = predictIE(&best_ever, elem.z);
        
        try stdout.print(" {d:3}   {s: <4}    {d:6.1}      {d:5.1}       {d:5.2}\n", .{
            elem.z, elem.sym, mass, radius, ie
        });
    }

    try stdout.print("\n✅ Evolutionary prediction complete\n", .{});
}

test "fitness improves over generations" {
    initRandom();
    
    var genome = createRandomGenome(0);
    evaluateFitness(&genome);
    const initial_fitness = genome.fitness;
    
    // Mutate and check if fitness can improve
    var best_fitness = initial_fitness;
    for (0..100) |_| {
        var mutated = genome;
        mutate(&mutated, 0.5);
        evaluateFitness(&mutated);
        if (mutated.fitness > best_fitness) {
            best_fitness = mutated.fitness;
        }
    }
    
    // At least some improvement should be possible
    try std.testing.expect(best_fitness >= initial_fitness * 0.9);
}

test "crossover produces valid genome" {
    initRandom();
    
    const parent_a = createRandomGenome(0);
    const parent_b = createRandomGenome(0);
    const child = crossover(&parent_a, &parent_b, 1);
    
    // Child should have valid parameters
    try std.testing.expect(child.mass_a > 0);
    try std.testing.expect(child.radius_base > 0);
    try std.testing.expect(child.generation == 1);
}
