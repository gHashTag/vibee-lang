// MUTATOR.ZIG - Мутации и эволюция популяции
// Операторы мутации, кроссовера, селекции

const std = @import("std");
const genome = @import("genome.zig");
const heuristics = @import("heuristics.zig");

// ============================================================================
// ПАРАМЕТРЫ ЭВОЛЮЦИИ (тоже эволюционируют!)
// ============================================================================

pub const EvolutionParams = struct {
    population_size: u32 = 100,
    elite_size: u32 = 10,
    mutation_rate: f64 = 0.3,
    crossover_rate: f64 = 0.7,
    power_mutation_range: i8 = 2,
    tournament_size: u32 = 5,
    
    // Мета-параметры
    generation: u32 = 0,
    
    const Self = @This();

    pub fn mutate(self: *Self, rng: *std.Random) void {
        // Мутируем параметры эволюции
        if (rng.float(f64) < 0.1) {
            self.mutation_rate = @max(0.05, @min(0.8, self.mutation_rate + (rng.float(f64) - 0.5) * 0.1));
        }
        if (rng.float(f64) < 0.1) {
            self.crossover_rate = @max(0.3, @min(0.95, self.crossover_rate + (rng.float(f64) - 0.5) * 0.1));
        }
        if (rng.float(f64) < 0.05) {
            const delta = rng.intRangeAtMost(i32, -1, 1);
            self.power_mutation_range = @max(1, @min(4, @as(i8, @intCast(@as(i32, self.power_mutation_range) + delta))));
        }
        self.generation += 1;
    }
};

// ============================================================================
// МУТАЦИИ ГЕНОМА
// ============================================================================

pub const MutationType = enum {
    power_change,      // изменение степени
    power_swap,        // обмен степеней
    coefficient_change,// изменение коэффициента
    sqrt_toggle,       // вкл/выкл корня
    reset_power,       // сброс степени в 0
    random_power,      // случайная степень
};

pub fn mutateLaw(law: *genome.LawGenome, params: *const EvolutionParams, rng: *std.Random) void {
    const mutation_type = rng.enumValue(MutationType);
    
    switch (mutation_type) {
        .power_change => {
            const idx = rng.intRangeAtMost(usize, 0, genome.NUM_CONSTANTS - 1);
            const delta = rng.intRangeAtMost(i8, -params.power_mutation_range, params.power_mutation_range);
            law.powers[idx] = @max(-genome.MAX_POWER, @min(genome.MAX_POWER, law.powers[idx] + delta));
        },
        .power_swap => {
            const idx1 = rng.intRangeAtMost(usize, 0, genome.NUM_CONSTANTS - 1);
            const idx2 = rng.intRangeAtMost(usize, 0, genome.NUM_CONSTANTS - 1);
            const tmp = law.powers[idx1];
            law.powers[idx1] = law.powers[idx2];
            law.powers[idx2] = tmp;
        },
        .coefficient_change => {
            const coeffs = [_]f64{ 0.5, 1.0, 2.0, 3.0, 4.0, 0.25, 0.333, 0.667, 1.5, 2.5 };
            law.numerator_coeff = coeffs[rng.intRangeAtMost(usize, 0, coeffs.len - 1)];
        },
        .sqrt_toggle => {
            law.sqrt_applied = !law.sqrt_applied;
        },
        .reset_power => {
            const idx = rng.intRangeAtMost(usize, 0, genome.NUM_CONSTANTS - 1);
            law.powers[idx] = 0;
        },
        .random_power => {
            const idx = rng.intRangeAtMost(usize, 0, genome.NUM_CONSTANTS - 1);
            law.powers[idx] = @as(i8, @intCast(rng.intRangeAtMost(i32, -genome.MAX_POWER, genome.MAX_POWER)));
        },
    }
    
    law.mutations += 1;
}

// ============================================================================
// КРОССОВЕР
// ============================================================================

pub fn crossover(parent1: *const genome.LawGenome, parent2: *const genome.LawGenome, rng: *std.Random) genome.LawGenome {
    var child = genome.LawGenome.init();
    
    // Uniform crossover для степеней
    for (0..genome.NUM_CONSTANTS) |i| {
        child.powers[i] = if (rng.boolean()) parent1.powers[i] else parent2.powers[i];
    }
    
    // Наследуем коэффициент от одного из родителей
    child.numerator_coeff = if (rng.boolean()) parent1.numerator_coeff else parent2.numerator_coeff;
    
    // Корень — от любого
    child.sqrt_applied = if (rng.boolean()) parent1.sqrt_applied else parent2.sqrt_applied;
    
    // Метаданные
    child.generation = @max(parent1.generation, parent2.generation) + 1;
    child.parent_id = if (parent1.fitness > parent2.fitness) parent1.parent_id else parent2.parent_id;
    
    return child;
}

// ============================================================================
// СЕЛЕКЦИЯ
// ============================================================================

pub fn tournamentSelect(population: *const genome.Population, params: *const EvolutionParams, rng: *std.Random) *const genome.LawGenome {
    var best: ?*const genome.LawGenome = null;
    var best_fitness: f64 = -std.math.inf(f64);
    
    for (0..params.tournament_size) |_| {
        const idx = rng.intRangeAtMost(usize, 0, population.laws.items.len - 1);
        const candidate = &population.laws.items[idx];
        if (candidate.fitness > best_fitness) {
            best_fitness = candidate.fitness;
            best = candidate;
        }
    }
    
    return best.?;
}

// ============================================================================
// ЭВОЛЮЦИЯ ПОПУЛЯЦИИ
// ============================================================================

pub fn evolvePopulation(population: *genome.Population, hs: *heuristics.HeuristicSet) !void {
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    var rng = prng.random();
    
    var params = EvolutionParams{};
    
    // Оценка фитнеса
    for (population.laws.items) |*law| {
        law.fitness = hs.evaluate(law);
    }
    
    // Сортировка по фитнесу
    std.mem.sort(genome.LawGenome, population.laws.items, {}, struct {
        fn lessThan(_: void, a: genome.LawGenome, b: genome.LawGenome) bool {
            return a.fitness > b.fitness;
        }
    }.lessThan);
    
    // Сохраняем открытия
    for (population.laws.items[0..@min(5, population.laws.items.len)]) |law| {
        if (law.fitness > 50 and law.isDimensionless()) {
            try population.addDiscovery(law);
        }
    }
    
    // Создаём новое поколение
    var new_laws = std.ArrayList(genome.LawGenome).init(population.allocator);
    defer new_laws.deinit();
    
    // Элита
    for (population.laws.items[0..@min(params.elite_size, population.laws.items.len)]) |law| {
        try new_laws.append(law);
    }
    
    // Остальные через кроссовер и мутацию
    while (new_laws.items.len < params.population_size) {
        if (rng.float(f64) < params.crossover_rate) {
            const p1 = tournamentSelect(population, &params, &rng);
            const p2 = tournamentSelect(population, &params, &rng);
            var child = crossover(p1, p2, &rng);
            
            if (rng.float(f64) < params.mutation_rate) {
                mutateLaw(&child, &params, &rng);
            }
            
            child.generation = population.generation + 1;
            try new_laws.append(child);
        } else {
            // Новый случайный
            var law = genome.LawGenome.random(&rng);
            law.generation = population.generation + 1;
            try new_laws.append(law);
        }
    }
    
    // Заменяем популяцию
    population.laws.clearRetainingCapacity();
    try population.laws.appendSlice(new_laws.items);
    population.generation += 1;
    
    // Обновляем лучший фитнес
    if (population.laws.items.len > 0) {
        population.best_fitness = population.laws.items[0].fitness;
    }
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "mutation" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    var params = EvolutionParams{};
    
    var law = genome.LawGenome.init();
    law.powers[0] = 1;
    
    mutateLaw(&law, &params, &rng);
    
    try std.testing.expect(law.mutations == 1);
}

test "crossover" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    
    var p1 = genome.LawGenome.init();
    p1.powers[0] = 2;
    
    var p2 = genome.LawGenome.init();
    p2.powers[1] = 3;
    
    const child = crossover(&p1, &p2, &rng);
    
    // Ребёнок должен унаследовать что-то от родителей
    try std.testing.expect(child.powers[0] == 2 or child.powers[0] == 0);
}
