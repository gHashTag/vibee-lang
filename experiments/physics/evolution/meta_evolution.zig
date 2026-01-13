// META_EVOLUTION.ZIG - Эволюция самой эволюции
// Система улучшает свои собственные алгоритмы поиска

const std = @import("std");
const genome = @import("genome.zig");
const heuristics = @import("heuristics.zig");
const mutator = @import("mutator.zig");
const fitness = @import("fitness.zig");

// ============================================================================
// МЕТА-ГЕНОМ: Кодирует стратегию поиска
// ============================================================================

pub const MetaGenome = struct {
    // Веса эвристик
    heuristic_weights: [9]f64,
    
    // Параметры эволюции
    mutation_rate: f64,
    crossover_rate: f64,
    elite_ratio: f64,
    tournament_size: u32,
    
    // Стратегия поиска
    prefer_dimensionless: f64,
    prefer_simple: f64,
    prefer_cosmological: f64,
    exploration_vs_exploitation: f64,  // 0 = exploit, 1 = explore
    
    // Метаданные
    meta_fitness: f64,
    discoveries_made: u32,
    generations_run: u32,
    
    const Self = @This();

    pub fn init() Self {
        return .{
            .heuristic_weights = [_]f64{1.0} ** 9,
            .mutation_rate = 0.3,
            .crossover_rate = 0.7,
            .elite_ratio = 0.1,
            .tournament_size = 5,
            .prefer_dimensionless = 0.5,
            .prefer_simple = 0.5,
            .prefer_cosmological = 0.5,
            .exploration_vs_exploitation = 0.5,
            .meta_fitness = 0,
            .discoveries_made = 0,
            .generations_run = 0,
        };
    }

    pub fn random(rng: *std.Random) Self {
        var mg = Self.init();
        
        for (&mg.heuristic_weights) |*w| {
            w.* = 0.5 + rng.float(f64) * 1.5;
        }
        
        mg.mutation_rate = 0.1 + rng.float(f64) * 0.5;
        mg.crossover_rate = 0.4 + rng.float(f64) * 0.5;
        mg.elite_ratio = 0.05 + rng.float(f64) * 0.2;
        mg.tournament_size = 3 + rng.intRangeAtMost(u32, 0, 7);
        
        mg.prefer_dimensionless = rng.float(f64);
        mg.prefer_simple = rng.float(f64);
        mg.prefer_cosmological = rng.float(f64);
        mg.exploration_vs_exploitation = rng.float(f64);
        
        return mg;
    }

    pub fn mutate(self: *Self, rng: *std.Random) void {
        // Мутируем случайный параметр
        const choice = rng.intRangeAtMost(u32, 0, 10);
        
        switch (choice) {
            0...8 => {
                // Мутация веса эвристики
                const idx = rng.intRangeAtMost(usize, 0, 8);
                self.heuristic_weights[idx] *= 0.8 + rng.float(f64) * 0.4;
                self.heuristic_weights[idx] = @max(0.1, @min(3.0, self.heuristic_weights[idx]));
            },
            9 => {
                self.mutation_rate *= 0.8 + rng.float(f64) * 0.4;
                self.mutation_rate = @max(0.05, @min(0.8, self.mutation_rate));
            },
            10 => {
                self.exploration_vs_exploitation += (rng.float(f64) - 0.5) * 0.2;
                self.exploration_vs_exploitation = @max(0, @min(1, self.exploration_vs_exploitation));
            },
            else => {},
        }
    }

    pub fn crossover(self: *const Self, other: *const Self, rng: *std.Random) Self {
        var child = Self.init();
        
        for (0..9) |i| {
            child.heuristic_weights[i] = if (rng.boolean()) 
                self.heuristic_weights[i] else other.heuristic_weights[i];
        }
        
        child.mutation_rate = if (rng.boolean()) self.mutation_rate else other.mutation_rate;
        child.crossover_rate = if (rng.boolean()) self.crossover_rate else other.crossover_rate;
        child.exploration_vs_exploitation = (self.exploration_vs_exploitation + other.exploration_vs_exploitation) / 2;
        
        return child;
    }

    pub fn applyToHeuristics(self: *const Self, hs: *heuristics.HeuristicSet) void {
        for (0..9) |i| {
            hs.heuristics[i].weight = self.heuristic_weights[i];
        }
    }
};

// ============================================================================
// МЕТА-ПОПУЛЯЦИЯ
// ============================================================================

pub const MetaPopulation = struct {
    strategies: std.ArrayList(MetaGenome),
    generation: u32,
    best_strategy: ?MetaGenome,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .strategies = std.ArrayList(MetaGenome).init(allocator),
            .generation = 0,
            .best_strategy = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.strategies.deinit();
    }

    pub fn randomInit(self: *Self, size: usize, rng: *std.Random) !void {
        for (0..size) |_| {
            try self.strategies.append(MetaGenome.random(rng));
        }
    }
};

// ============================================================================
// МЕТА-ЭВОЛЮЦИЯ
// ============================================================================

pub fn evolveHeuristics(hs: *heuristics.HeuristicSet, population: *const genome.Population) !void {
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    var rng = prng.random();
    
    // Анализируем эффективность текущих эвристик
    var total_triggered: u64 = 0;
    var total_discoveries: u64 = 0;
    
    for (hs.heuristics) |h| {
        total_triggered += h.times_triggered;
        total_discoveries += h.discoveries_contributed;
    }
    
    // Адаптируем веса на основе эффективности
    for (&hs.heuristics) |*h| {
        if (h.times_triggered > 0) {
            const effectiveness = @as(f64, @floatFromInt(h.discoveries_contributed)) / 
                                 @as(f64, @floatFromInt(h.times_triggered));
            
            // Увеличиваем вес эффективных эвристик
            if (effectiveness > 0.1) {
                h.weight *= 1.1;
            } else if (effectiveness < 0.01 and h.times_triggered > 100) {
                h.weight *= 0.9;
            }
            
            h.weight = @max(0.1, @min(3.0, h.weight));
        }
    }
    
    // Случайная мутация для исследования
    if (rng.float(f64) < 0.2) {
        hs.mutate(&rng);
    }
    
    // Обновляем статистику на основе открытий
    for (population.discoveries.items) |discovery| {
        // Определяем какие эвристики способствовали открытию
        if (discovery.isDimensionless()) {
            hs.heuristics[0].discoveries_contributed += 1;
        }
        if (discovery.complexity() < 10) {
            hs.heuristics[1].discoveries_contributed += 1;
        }
        if (discovery.powers[9] != 0) {  // H₀
            hs.heuristics[7].discoveries_contributed += 1;
        }
        if (discovery.powers[1] != 0 and discovery.powers[2] != 0) {  // G и ℏ
            hs.heuristics[8].discoveries_contributed += 1;
        }
    }
    
    hs.generation += 1;
}

pub fn runFullMetaEvolution(allocator: std.mem.Allocator, hs: *heuristics.HeuristicSet) !void {
    const print = std.debug.print;
    
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    var rng = prng.random();
    
    print("Running meta-evolution...\n", .{});
    
    // Создаём мета-популяцию
    var meta_pop = MetaPopulation.init(allocator);
    defer meta_pop.deinit();
    
    try meta_pop.randomInit(20, &rng);
    
    // Эволюция мета-стратегий
    for (0..10) |meta_gen| {
        print("Meta-generation {}...\n", .{meta_gen});
        
        // Оцениваем каждую стратегию
        for (meta_pop.strategies.items) |*strategy| {
            // Применяем стратегию к эвристикам
            strategy.applyToHeuristics(hs);
            
            // Запускаем короткую эволюцию
            var test_pop = genome.Population.init(allocator);
            defer test_pop.deinit();
            
            try test_pop.randomInit(50, &rng);
            
            for (0..20) |_| {
                try mutator.evolvePopulation(&test_pop, hs);
            }
            
            // Оцениваем результат
            strategy.meta_fitness = test_pop.best_fitness;
            strategy.discoveries_made = @as(u32, @intCast(test_pop.discoveries.items.len));
            strategy.generations_run += 20;
        }
        
        // Сортируем по мета-фитнесу
        std.mem.sort(MetaGenome, meta_pop.strategies.items, {}, struct {
            fn lessThan(_: void, a: MetaGenome, b: MetaGenome) bool {
                return a.meta_fitness > b.meta_fitness;
            }
        }.lessThan);
        
        // Сохраняем лучшую
        meta_pop.best_strategy = meta_pop.strategies.items[0];
        
        print("  Best meta-fitness: {d:.2}\n", .{meta_pop.strategies.items[0].meta_fitness});
        
        // Эволюция мета-популяции
        var new_strategies = std.ArrayList(MetaGenome).init(allocator);
        defer new_strategies.deinit();
        
        // Элита
        for (meta_pop.strategies.items[0..5]) |s| {
            try new_strategies.append(s);
        }
        
        // Остальные через кроссовер
        while (new_strategies.items.len < 20) {
            const p1 = &meta_pop.strategies.items[rng.intRangeAtMost(usize, 0, 9)];
            const p2 = &meta_pop.strategies.items[rng.intRangeAtMost(usize, 0, 9)];
            var child = p1.crossover(p2, &rng);
            
            if (rng.float(f64) < 0.3) {
                child.mutate(&rng);
            }
            
            try new_strategies.append(child);
        }
        
        meta_pop.strategies.clearRetainingCapacity();
        try meta_pop.strategies.appendSlice(new_strategies.items);
        meta_pop.generation += 1;
    }
    
    // Применяем лучшую стратегию
    if (meta_pop.best_strategy) |best| {
        best.applyToHeuristics(hs);
        print("\nApplied best meta-strategy:\n", .{});
        print("  mutation_rate: {d:.3}\n", .{best.mutation_rate});
        print("  exploration: {d:.3}\n", .{best.exploration_vs_exploitation});
    }
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "meta_genome_init" {
    const mg = MetaGenome.init();
    try std.testing.expectEqual(mg.mutation_rate, 0.3);
}

test "meta_genome_mutate" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    
    var mg = MetaGenome.init();
    mg.mutate(&rng);
    
    // Что-то должно измениться
    var changed = false;
    for (mg.heuristic_weights) |w| {
        if (w != 1.0) changed = true;
    }
    if (mg.mutation_rate != 0.3) changed = true;
    
    try std.testing.expect(changed);
}
