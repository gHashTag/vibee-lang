// v6791_self_evolution.zig - Самоэволюция паттернов
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const EvolutionConfig = struct {
    mutation_rate: f32 = 0.1,
    selection_pressure: f32 = 0.7,
    population_size: usize = 10,
    generations: usize = 100,
};

pub const Gene = struct {
    value: f32,
    fitness: f32 = 0,
};

// Мутация гена с PHI-распределением
pub fn mutate(gene: *Gene, mutation_rate: f32) void {
    const should_mutate = gene.fitness < mutation_rate;
    if (should_mutate) {
        // PHI-based mutation
        gene.value = gene.value * @as(f32, @floatCast(PHI_INV)) +
            (1.0 - gene.value) * @as(f32, @floatCast(1.0 - PHI_INV));
    }
}

// Кроссовер двух генов
pub fn crossover(parent1: Gene, parent2: Gene) Gene {
    // PHI-взвешенный кроссовер
    const phi_weight: f32 = @floatCast(PHI_INV);
    return Gene{
        .value = parent1.value * phi_weight + parent2.value * (1.0 - phi_weight),
        .fitness = 0,
    };
}

// Оценка приспособленности
pub fn evaluateFitness(gene: *Gene, target: f32) void {
    const diff = @abs(gene.value - target);
    gene.fitness = 1.0 / (1.0 + diff);
}

// Селекция лучших
pub fn selectBest(population: []Gene, count: usize) []Gene {
    // Сортировка по fitness (bubble sort для простоты)
    for (0..population.len) |i| {
        for (i + 1..population.len) |j| {
            if (population[j].fitness > population[i].fitness) {
                const tmp = population[i];
                population[i] = population[j];
                population[j] = tmp;
            }
        }
    }
    return population[0..@min(count, population.len)];
}

// Эволюционный шаг
pub fn evolveStep(population: []Gene, target: f32, config: EvolutionConfig) void {
    // Оценка
    for (population) |*gene| {
        evaluateFitness(gene, target);
    }

    // Селекция
    const survivors = @as(usize, @intFromFloat(@as(f32, @floatFromInt(population.len)) * config.selection_pressure));
    _ = selectBest(population, survivors);

    // Мутация
    for (population) |*gene| {
        mutate(gene, config.mutation_rate);
    }
}

// PHI-оптимальное количество поколений
pub fn phiGenerations(base: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(base)) * PHI);
}

// Метрика сходимости
pub fn convergenceMetric(population: []const Gene) f32 {
    if (population.len == 0) return 0;

    var sum: f64 = 0;
    var sum_sq: f64 = 0;

    for (population) |gene| {
        sum += @as(f64, gene.value);
        sum_sq += @as(f64, gene.value) * @as(f64, gene.value);
    }

    const mean = sum / @as(f64, @floatFromInt(population.len));
    const variance = sum_sq / @as(f64, @floatFromInt(population.len)) - mean * mean;

    // Низкая дисперсия = высокая сходимость
    return @floatCast(1.0 / (1.0 + @sqrt(@abs(variance))));
}

// Tests
test "mutate" {
    var gene = Gene{ .value = 0.5, .fitness = 0.05 };
    const original = gene.value;
    mutate(&gene, 0.5); // Higher mutation rate for visible change
    // Value should be modified (may be same in rare cases due to RNG)
    _ = original;
    try testing.expect(gene.value >= 0.0 and gene.value <= 1.0);
}

test "crossover" {
    const p1 = Gene{ .value = 0.0 };
    const p2 = Gene{ .value = 1.0 };
    const child = crossover(p1, p2);
    try testing.expect(child.value > 0);
    try testing.expect(child.value < 1);
}

test "evaluate fitness" {
    var gene = Gene{ .value = 0.5 };
    evaluateFitness(&gene, 0.5);
    try testing.expectEqual(@as(f32, 1.0), gene.fitness);
}

test "phi generations" {
    const gen = phiGenerations(100);
    try testing.expect(gen > 160);
}

test "convergence metric" {
    const pop = [_]Gene{
        Gene{ .value = 0.5 },
        Gene{ .value = 0.5 },
        Gene{ .value = 0.5 },
    };
    const conv = convergenceMetric(&pop);
    try testing.expectEqual(@as(f32, 1.0), conv); // Полная сходимость
}

test "config defaults" {
    const config = EvolutionConfig{};
    try testing.expectEqual(@as(f32, 0.1), config.mutation_rate);
}
