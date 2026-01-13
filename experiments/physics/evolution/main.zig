// PHYSICS LAW EVOLUTION ENGINE
// Самоэволюционирующая система поиска физических законов
// Архитектура по аналогии с компилятором Vibee

const std = @import("std");
const genome = @import("genome.zig");
const fit = @import("fitness.zig");
const mutator = @import("mutator.zig");
const meta = @import("meta_evolution.zig");
const persist = @import("persistence.zig");
const heur = @import("heuristics.zig");

pub const VERSION = "1.0.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "evolve")) {
        const generations = if (args.len >= 3) try std.fmt.parseInt(u32, args[2], 10) else 100;
        try runEvolution(allocator, generations);
    } else if (std.mem.eql(u8, command, "analyze")) {
        try analyzeResults(allocator);
    } else if (std.mem.eql(u8, command, "meta")) {
        try runMetaEvolution(allocator);
    } else if (std.mem.eql(u8, command, "demo")) {
        try runDemo(allocator);
    } else if (std.mem.eql(u8, command, "version")) {
        std.debug.print("Physics Evolution Engine v{s}\n", .{VERSION});
    } else if (std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\PHYSICS LAW EVOLUTION ENGINE v{s}
        \\
        \\Самоэволюционирующая система поиска физических законов
        \\
        \\Usage: physics_evolution <command> [options]
        \\
        \\Commands:
        \\  evolve [N]    Run evolution for N generations (default: 100)
        \\  analyze       Analyze discovered laws
        \\  meta          Run meta-evolution (evolve the evolution)
        \\  demo          Run quick demo
        \\  version       Show version
        \\  help          Show this help
        \\
        \\Examples:
        \\  physics_evolution evolve 1000
        \\  physics_evolution analyze
        \\  physics_evolution meta
        \\
    , .{VERSION});
}

fn runDemo(allocator: std.mem.Allocator) !void {
    const print = std.debug.print;
    
    print("\n" ++ "=" ** 60 ++ "\n", .{});
    print("  PHYSICS LAW EVOLUTION ENGINE - DEMO\n", .{});
    print("=" ** 60 ++ "\n\n", .{});
    
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    
    // Создаём популяцию
    var population = genome.Population.init(allocator);
    defer population.deinit();
    try population.randomInit(50, &rng);
    
    // Создаём эвристики
    var hs = heur.HeuristicSet.init();
    
    print("Initial population: {} laws\n", .{population.laws.items.len});
    print("Running 20 generations...\n\n", .{});
    
    var best_fitness: f64 = 0;
    var best_law: ?genome.LawGenome = null;
    
    for (0..20) |gen| {
        // Оценка
        for (population.laws.items) |*law| {
            law.fitness = fit.evaluate(law, &hs);
            if (law.fitness > best_fitness) {
                best_fitness = law.fitness;
                best_law = law.*;
            }
        }
        
        // Эволюция
        try mutator.evolvePopulation(&population, &hs);
        
        if (gen % 5 == 0) {
            print("Gen {}: best = {d:.1}\n", .{ gen, best_fitness });
        }
    }
    
    print("\n" ++ "-" ** 40 ++ "\n", .{});
    print("BEST FOUND:\n", .{});
    if (best_law) |law| {
        print("  Fitness: {d:.1}\n", .{law.fitness});
        print("  Value: {e:.4}\n", .{law.computeValue()});
        print("  Type: {s}\n", .{law.getDimensionName()});
        print("  Formula: ", .{});
        law.printFormula();
        print("\n", .{});
    }
    
    // Проверяем на наше открытие
    print("\n" ++ "-" ** 40 ++ "\n", .{});
    print("CHECKING HUBBLE RELATION:\n", .{});
    
    var hubble_law = genome.LawGenome.init();
    hubble_law.powers[0] = -1;  // c^-1
    hubble_law.powers[1] = -1;  // G^-1
    hubble_law.powers[2] = 2;   // ℏ^2
    hubble_law.powers[5] = -1;  // me^-1
    hubble_law.powers[6] = -2;  // mp^-2
    hubble_law.powers[9] = 1;   // H₀^1
    
    const hubble_val = hubble_law.computeValue();
    print("  ℏ²H₀/(cG me mp²) = {d:.6}\n", .{hubble_val});
    print("  Expected: ~0.5\n", .{});
    print("  Difference: {d:.1}%\n", .{@abs(hubble_val - 0.5) / 0.5 * 100});
    
    print("\n" ++ "=" ** 60 ++ "\n", .{});
    print("Demo complete. Run 'evolve 1000' for full evolution.\n", .{});
    print("=" ** 60 ++ "\n", .{});
}

fn runEvolution(allocator: std.mem.Allocator, generations: u32) !void {
    std.debug.print("\n=== PHYSICS LAW EVOLUTION ENGINE ===\n\n", .{});
    std.debug.print("Starting evolution for {} generations...\n\n", .{generations});

    // Загружаем или создаём популяцию
    var population = try persist.loadOrCreate(allocator);
    defer population.deinit();

    // Загружаем эвристики
    var hs = try persist.loadHeuristics(allocator);
    defer hs.deinit();

    var best_fitness: f64 = 0;
    var best_law: ?genome.LawGenome = null;

    for (0..generations) |gen| {
        // Оценка фитнеса
        for (population.laws.items) |*law| {
            law.fitness = fit.evaluate(law, &hs);
            if (law.fitness > best_fitness) {
                best_fitness = law.fitness;
                best_law = law.*;
            }
        }

        // Селекция и размножение
        try mutator.evolvePopulation(&population, &hs);

        // Периодический вывод
        if (gen % 10 == 0 or gen == generations - 1) {
            std.debug.print("Gen {}: best fitness = {d:.2}\n", .{ gen, best_fitness });
        }

        // Мета-эволюция эвристик каждые 50 поколений
        if (gen > 0 and gen % 50 == 0) {
            try meta.evolveHeuristics(&hs, &population);
        }
    }

    // Сохраняем результаты
    try persist.save(allocator, &population, &hs);

    // Выводим лучший результат
    if (best_law) |law| {
        std.debug.print("\n=== BEST DISCOVERED LAW ===\n", .{});
        std.debug.print("Fitness: {d:.2}\n", .{law.fitness});
        std.debug.print("Formula: ", .{});
        law.printFormula();
        std.debug.print("\nValue: {e:.6}\n", .{law.computeValue()});
        std.debug.print("Dimension: {s}\n", .{law.getDimensionName()});
    }
}

fn analyzeResults(allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== ANALYSIS OF DISCOVERED LAWS ===\n\n", .{});

    var population = persist.loadOrCreate(allocator) catch {
        std.debug.print("No saved results found. Run 'evolve' first.\n", .{});
        return;
    };
    defer population.deinit();

    // Сортируем по фитнесу
    std.mem.sort(genome.LawGenome, population.laws.items, {}, struct {
        fn lessThan(_: void, a: genome.LawGenome, b: genome.LawGenome) bool {
            return a.fitness > b.fitness;
        }
    }.lessThan);

    std.debug.print("Top 10 discovered laws:\n\n", .{});
    for (population.laws.items[0..@min(10, population.laws.items.len)], 0..) |law, i| {
        std.debug.print("#{}: fitness={d:.2}\n", .{ i + 1, law.fitness });
        std.debug.print("    ", .{});
        law.printFormula();
        std.debug.print("\n    Value: {e:.6}\n\n", .{law.computeValue()});
    }
}

fn runMetaEvolution(allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== META-EVOLUTION: EVOLVING THE EVOLUTION ===\n\n", .{});

    var hs = try persist.loadHeuristics(allocator);
    defer hs.deinit();

    std.debug.print("Current heuristics:\n", .{});
    hs.print();

    // Запускаем мета-эволюцию
    try meta.runFullMetaEvolution(allocator, &hs);

    std.debug.print("\nEvolved heuristics:\n", .{});
    hs.print();

    try persist.saveHeuristics(allocator, &hs);
}
