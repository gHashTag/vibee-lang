// ГЕНЕТИЧЕСКИЙ АЛГОРИТМ ПОИСКА ФИЗИЧЕСКИХ ЗАКОНОВ
// Эволюционный поиск оптимальных комбинаций констант

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// ПОЛНЫЙ НАБОР КОНСТАНТ (20 штук)
// ============================================================================

const NUM_CONSTANTS = 20;

const Constant = struct {
    name: []const u8,
    symbol: []const u8,
    value: f64,
    dim: [5]i8,  // M, L, T, Q, K
};

const ALL_CONSTANTS = [NUM_CONSTANTS]Constant{
    // Фундаментальные
    .{ .name = "скорость света", .symbol = "c", .value = 299792458, .dim = .{ 0, 1, -1, 0, 0 } },
    .{ .name = "гравитационная", .symbol = "G", .value = 6.674e-11, .dim = .{ -1, 3, -2, 0, 0 } },
    .{ .name = "Планка", .symbol = "h", .value = 1.055e-34, .dim = .{ 1, 2, -1, 0, 0 } },
    .{ .name = "Больцмана", .symbol = "kB", .value = 1.381e-23, .dim = .{ 1, 2, -2, 0, -1 } },
    .{ .name = "заряд электрона", .symbol = "e", .value = 1.602e-19, .dim = .{ 0, 0, 1, 1, 0 } },

    // Массы частиц
    .{ .name = "масса электрона", .symbol = "me", .value = 9.109e-31, .dim = .{ 1, 0, 0, 0, 0 } },
    .{ .name = "масса протона", .symbol = "mp", .value = 1.673e-27, .dim = .{ 1, 0, 0, 0, 0 } },
    .{ .name = "масса нейтрона", .symbol = "mn", .value = 1.675e-27, .dim = .{ 1, 0, 0, 0, 0 } },
    .{ .name = "масса мюона", .symbol = "mmu", .value = 1.884e-28, .dim = .{ 1, 0, 0, 0, 0 } },
    .{ .name = "масса тау", .symbol = "mtau", .value = 3.168e-27, .dim = .{ 1, 0, 0, 0, 0 } },

    // Электромагнитные
    .{ .name = "eps0", .symbol = "e0", .value = 8.854e-12, .dim = .{ -1, -3, 4, 2, 0 } },
    .{ .name = "mu0", .symbol = "u0", .value = 1.257e-6, .dim = .{ 1, 1, -2, -2, 0 } },
    .{ .name = "кулоновская", .symbol = "ke", .value = 8.99e9, .dim = .{ 1, 3, -4, -2, 0 } },

    // Космологические
    .{ .name = "Хаббла", .symbol = "H0", .value = 2.2e-18, .dim = .{ 0, 0, -1, 0, 0 } },
    .{ .name = "космол. постоянная", .symbol = "Lam", .value = 1.1e-52, .dim = .{ 0, -2, 0, 0, 0 } },
    .{ .name = "крит. плотность", .symbol = "rho", .value = 9.5e-27, .dim = .{ 1, -3, 0, 0, 0 } },

    // Производные (важные)
    .{ .name = "тонкая структура", .symbol = "alp", .value = 7.297e-3, .dim = .{ 0, 0, 0, 0, 0 } },
    .{ .name = "Ридберг", .symbol = "Ry", .value = 2.18e-18, .dim = .{ 1, 2, -2, 0, 0 } },
    .{ .name = "Боровский радиус", .symbol = "a0", .value = 5.292e-11, .dim = .{ 0, 1, 0, 0, 0 } },
    .{ .name = "магнетон Бора", .symbol = "muB", .value = 9.274e-24, .dim = .{ 0, 2, 0, 1, 0 } },
};

// ============================================================================
// ГЕНОМ: Набор степеней для каждой константы
// ============================================================================

const GENOME_SIZE = 8;  // используем 8 констант

const Genome = struct {
    powers: [GENOME_SIZE]i8,
    fitness: f64,
    value: f64,
    dim: [5]i8,

    fn init() Genome {
        return .{
            .powers = [_]i8{0} ** GENOME_SIZE,
            .fitness = 0,
            .value = 0,
            .dim = [_]i8{0} ** 5,
        };
    }

    fn randomize(self: *Genome, prng: *std.Random.Xoshiro256) void {
        var rng = prng.random();
        for (&self.powers) |*p| {
            p.* = @as(i8, @intCast(rng.intRangeAtMost(i32, -3, 3)));
        }
        // Гарантируем хотя бы одну ненулевую степень
        const idx = rng.intRangeAtMost(usize, 0, GENOME_SIZE - 1);
        if (self.powers[idx] == 0) self.powers[idx] = 1;
    }

    fn calculate(self: *Genome) void {
        self.value = 1.0;
        self.dim = [_]i8{0} ** 5;

        const indices = [GENOME_SIZE]usize{ 0, 1, 2, 3, 5, 6, 13, 16 };  // c, G, h, kB, me, mp, H0, alpha

        for (indices, 0..) |const_idx, i| {
            const p = self.powers[i];
            if (p != 0) {
                self.value *= math.pow(f64, ALL_CONSTANTS[const_idx].value, @floatFromInt(p));
                for (0..5) |d| {
                    self.dim[d] += p * ALL_CONSTANTS[const_idx].dim[d];
                }
            }
        }
    }

    fn evaluateFitness(self: *Genome) void {
        self.calculate();

        // Проверка на валидность
        if (math.isNan(self.value) or math.isInf(self.value) or self.value == 0) {
            self.fitness = 0;
            return;
        }

        var score: f64 = 0;

        // 1. Бонус за безразмерность
        var is_dimensionless = true;
        for (self.dim) |d| {
            if (d != 0) is_dimensionless = false;
        }
        if (is_dimensionless) score += 50;

        // 2. Бонус за "красивое" значение
        const log_val = @abs(@log10(self.value));
        if (log_val < 3) score += 30;  // близко к 1
        if (self.value > 0.9 and self.value < 1.1) score += 20;  // очень близко к 1

        // 3. Бонус за простоту (меньше ненулевых степеней)
        var nonzero: u8 = 0;
        for (self.powers) |p| {
            if (p != 0) nonzero += 1;
        }
        score += @as(f64, @floatFromInt(10 - nonzero)) * 2;

        // 4. Бонус за малые степени
        var sum_abs: i16 = 0;
        for (self.powers) |p| {
            sum_abs += if (p < 0) -p else p;
        }
        score += @as(f64, @floatFromInt(20 - sum_abs));

        // 5. Штраф за известные комбинации
        if (isKnownValue(self.value)) score -= 100;

        // 6. Бонус за интересные размерности
        if (self.dim[0] == 0 and self.dim[1] == 1 and self.dim[2] == 0) score += 15;  // длина
        if (self.dim[0] == 1 and self.dim[1] == 2 and self.dim[2] == -2) score += 15;  // энергия
        if (self.dim[0] == 1 and self.dim[1] == 1 and self.dim[2] == -2) score += 15;  // сила

        self.fitness = @max(0, score);
    }
};

fn isKnownValue(val: f64) bool {
    const known = [_]f64{
        1.616e-35, 5.391e-44, 2.176e-8, 1.417e32,  // Планковские
        5.292e-11, 2.426e-12, 2.818e-15,  // атомные
        1836.15, 137.036, 0.00729735,  // безразмерные
        1.0, 2.0, 3.14159, 2.71828,  // математические
    };
    for (known) |k| {
        const ratio = val / k;
        if (ratio > 0.99 and ratio < 1.01) return true;
    }
    return false;
}

// ============================================================================
// ГЕНЕТИЧЕСКИЕ ОПЕРАЦИИ
// ============================================================================

fn crossover(parent1: *const Genome, parent2: *const Genome, prng: *std.Random.Xoshiro256) Genome {
    var rng = prng.random();
    var child = Genome.init();
    const crosspoint = rng.intRangeAtMost(usize, 1, GENOME_SIZE - 1);
    for (0..GENOME_SIZE) |i| {
        child.powers[i] = if (i < crosspoint) parent1.powers[i] else parent2.powers[i];
    }
    return child;
}

fn mutate(genome: *Genome, prng: *std.Random.Xoshiro256) void {
    var rng = prng.random();
    const idx = rng.intRangeAtMost(usize, 0, GENOME_SIZE - 1);
    const delta = @as(i8, @intCast(rng.intRangeAtMost(i32, -2, 2)));
    genome.powers[idx] = @max(-3, @min(3, genome.powers[idx] + delta));
}

// ============================================================================
// ПОПУЛЯЦИЯ
// ============================================================================

const POP_SIZE = 100;
const GENERATIONS = 50;
const ELITE_SIZE = 10;
const MUTATION_RATE = 0.3;

var population: [POP_SIZE]Genome = undefined;
var best_ever: [20]Genome = undefined;
var best_count: usize = 0;

fn initPopulation(prng: *std.Random.Xoshiro256) void {
    for (&population) |*g| {
        g.* = Genome.init();
        g.randomize(prng);
        g.evaluateFitness();
    }
}

fn sortByFitness() void {
    std.mem.sort(Genome, &population, {}, struct {
        fn lessThan(_: void, a: Genome, b: Genome) bool {
            return a.fitness > b.fitness;  // по убыванию
        }
    }.lessThan);
}

fn evolve(prng: *std.Random.Xoshiro256) void {
    var rng = prng.random();
    sortByFitness();

    // Сохраняем лучших
    if (population[0].fitness > 0) {
        var dominated = false;
        for (best_ever[0..best_count]) |b| {
            var same = true;
            for (0..GENOME_SIZE) |i| {
                if (b.powers[i] != population[0].powers[i]) same = false;
            }
            if (same) dominated = true;
        }
        if (!dominated and best_count < 20) {
            best_ever[best_count] = population[0];
            best_count += 1;
        }
    }

    // Новое поколение
    var new_pop: [POP_SIZE]Genome = undefined;

    // Элита
    for (0..ELITE_SIZE) |i| {
        new_pop[i] = population[i];
    }

    // Остальные через кроссовер и мутацию
    for (ELITE_SIZE..POP_SIZE) |i| {
        const p1_idx = rng.intRangeAtMost(usize, 0, POP_SIZE / 4);
        const p2_idx = rng.intRangeAtMost(usize, 0, POP_SIZE / 4);
        new_pop[i] = crossover(&population[p1_idx], &population[p2_idx], prng);

        if (rng.float(f32) < MUTATION_RATE) {
            mutate(&new_pop[i], prng);
        }
        new_pop[i].evaluateFitness();
    }

    population = new_pop;
}

// ============================================================================
// ГЛАВНАЯ ФУНКЦИЯ
// ============================================================================

pub fn main() !void {
    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("  ГЕНЕТИЧЕСКИЙ АЛГОРИТМ ПОИСКА ФИЗИЧЕСКИХ ЗАКОНОВ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    print("Параметры:\n", .{});
    print("  Констант: {}\n", .{GENOME_SIZE});
    print("  Популяция: {}\n", .{POP_SIZE});
    print("  Поколений: {}\n", .{GENERATIONS});
    print("  Элита: {}\n", .{ELITE_SIZE});
    print("  Мутация: {d:.0}%\n\n", .{MUTATION_RATE * 100});

    var prng = std.Random.Xoshiro256.init(42);

    initPopulation(&prng);

    print("Эволюция:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    for (0..GENERATIONS) |gen| {
        evolve(&prng);
        if (gen % 10 == 0 or gen == GENERATIONS - 1) {
            print("Поколение {}: лучший fitness = {d:.1}\n", .{ gen, population[0].fitness });
        }
    }

    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("  ЛУЧШИЕ НАЙДЕННЫЕ КОМБИНАЦИИ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    // Сортируем лучших
    std.mem.sort(Genome, best_ever[0..best_count], {}, struct {
        fn lessThan(_: void, a: Genome, b: Genome) bool {
            return a.fitness > b.fitness;
        }
    }.lessThan);

    const symbols = [GENOME_SIZE][]const u8{ "c", "G", "h", "kB", "me", "mp", "H0", "α" };

    for (best_ever[0..@min(best_count, 15)], 0..) |g, i| {
        print("#{}: fitness = {d:.1}\n", .{ i + 1, g.fitness });
        print("   Значение: {e:.3}\n", .{g.value});
        print("   Размерность: M^{} L^{} T^{} Q^{} K^{}\n", .{ g.dim[0], g.dim[1], g.dim[2], g.dim[3], g.dim[4] });
        print("   Формула: ", .{});
        var first = true;
        for (0..GENOME_SIZE) |j| {
            if (g.powers[j] != 0) {
                if (!first) print(" × ", .{});
                print("{s}^{}", .{ symbols[j], g.powers[j] });
                first = false;
            }
        }
        print("\n\n", .{});
    }

    // Дополнительный анализ
    print("=" ** 70 ++ "\n", .{});
    print("  АНАЛИЗ БЕЗРАЗМЕРНЫХ КОМБИНАЦИЙ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    for (best_ever[0..best_count]) |g| {
        var is_dim = true;
        for (g.dim) |d| {
            if (d != 0) is_dim = false;
        }
        if (is_dim and g.value > 1e-50 and g.value < 1e50) {
            print("Безразмерная: {e:.6}\n", .{g.value});
            print("  ", .{});
            var first = true;
            for (0..GENOME_SIZE) |j| {
                if (g.powers[j] != 0) {
                    if (!first) print(" × ", .{});
                    print("{s}^{}", .{ symbols[j], g.powers[j] });
                    first = false;
                }
            }
            print("\n\n", .{});
        }
    }

    print("=" ** 70 ++ "\n", .{});
    print("СТАТУС: Генетический поиск завершён.\n", .{});
    print("=" ** 70 ++ "\n", .{});
}

test "genome_calculation" {
    var g = Genome.init();
    g.powers[0] = 1;  // c^1
    g.powers[1] = -1; // G^-1
    g.calculate();
    try std.testing.expect(g.value > 1e18);
}
