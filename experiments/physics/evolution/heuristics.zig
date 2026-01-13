// HEURISTICS.ZIG - Эволюционирующие эвристики
// Сами правила поиска эволюционируют!

const std = @import("std");
const genome = @import("genome.zig");

// ============================================================================
// ЭВРИСТИКА - правило оценки/поиска
// ============================================================================

pub const HeuristicType = enum {
    dimensionless_bonus,      // бонус за безразмерность
    simplicity_bonus,         // бонус за простоту
    near_integer_bonus,       // бонус за близость к целому
    near_simple_fraction,     // бонус за близость к простой дроби
    known_value_penalty,      // штраф за известные значения
    extreme_value_penalty,    // штраф за экстремальные значения
    physical_dimension_bonus, // бонус за физически осмысленную размерность
    cosmological_bonus,       // бонус за связь с космологией
    quantum_gravity_bonus,    // бонус за связь квантов и гравитации
};

pub const Heuristic = struct {
    htype: HeuristicType,
    weight: f64,           // вес эвристики (эволюционирует)
    threshold: f64,        // порог срабатывания (эволюционирует)
    enabled: bool,
    
    // Статистика эффективности
    times_triggered: u64,
    discoveries_contributed: u64,
    
    const Self = @This();

    pub fn apply(self: *Self, law: *const genome.LawGenome) f64 {
        if (!self.enabled) return 0;
        
        const score = switch (self.htype) {
            .dimensionless_bonus => self.evalDimensionless(law),
            .simplicity_bonus => self.evalSimplicity(law),
            .near_integer_bonus => self.evalNearInteger(law),
            .near_simple_fraction => self.evalNearFraction(law),
            .known_value_penalty => self.evalKnownPenalty(law),
            .extreme_value_penalty => self.evalExtremePenalty(law),
            .physical_dimension_bonus => self.evalPhysicalDim(law),
            .cosmological_bonus => self.evalCosmological(law),
            .quantum_gravity_bonus => self.evalQuantumGravity(law),
        };
        
        if (score != 0) self.times_triggered += 1;
        return score * self.weight;
    }

    fn evalDimensionless(self: *Self, law: *const genome.LawGenome) f64 {
        _ = self;
        return if (law.isDimensionless()) 50.0 else 0.0;
    }

    fn evalSimplicity(self: *Self, law: *const genome.LawGenome) f64 {
        const c = law.complexity();
        if (c <= @as(u32, @intFromFloat(self.threshold))) {
            return 30.0 - @as(f64, @floatFromInt(c)) * 2.0;
        }
        return 0;
    }

    fn evalNearInteger(self: *Self, law: *const genome.LawGenome) f64 {
        const val = law.computeValue();
        if (val <= 0 or std.math.isNan(val) or std.math.isInf(val)) return 0;
        
        const integers = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
        for (integers) |n| {
            const diff = @abs(val - n) / n;
            if (diff < self.threshold) {
                return 40.0 * (1.0 - diff / self.threshold);
            }
        }
        return 0;
    }

    fn evalNearFraction(self: *Self, law: *const genome.LawGenome) f64 {
        const val = law.computeValue();
        if (val <= 0 or std.math.isNan(val) or std.math.isInf(val)) return 0;
        
        const fractions = [_]f64{ 0.5, 0.25, 0.333, 0.667, 0.75, 1.5, 2.5 };
        for (fractions) |f| {
            const diff = @abs(val - f) / f;
            if (diff < self.threshold) {
                return 35.0 * (1.0 - diff / self.threshold);
            }
        }
        return 0;
    }

    fn evalKnownPenalty(self: *Self, law: *const genome.LawGenome) f64 {
        _ = self;
        const val = law.computeValue();
        
        const known = [_]f64{
            1.616e-35, 5.391e-44, 2.176e-8, 1.417e32,  // Планковские
            5.292e-11, 2.426e-12, 137.036, 1836.15,    // атомные
        };
        
        for (known) |k| {
            const ratio = val / k;
            if (ratio > 0.99 and ratio < 1.01) return -50.0;
        }
        return 0;
    }

    fn evalExtremePenalty(self: *Self, law: *const genome.LawGenome) f64 {
        const val = law.computeValue();
        if (std.math.isNan(val) or std.math.isInf(val)) return -100.0;
        
        const log_val = @abs(@log10(val));
        if (log_val > self.threshold) {
            return -20.0 * (log_val - self.threshold);
        }
        return 0;
    }

    fn evalPhysicalDim(self: *Self, law: *const genome.LawGenome) f64 {
        _ = self;
        const dim_name = law.getDimensionName();
        
        if (std.mem.eql(u8, dim_name, "энергия")) return 15.0;
        if (std.mem.eql(u8, dim_name, "сила")) return 15.0;
        if (std.mem.eql(u8, dim_name, "длина")) return 10.0;
        if (std.mem.eql(u8, dim_name, "время")) return 10.0;
        if (std.mem.eql(u8, dim_name, "частота")) return 12.0;
        
        return 0;
    }

    fn evalCosmological(self: *Self, law: *const genome.LawGenome) f64 {
        _ = self;
        // Бонус если используется H₀
        if (law.powers[9] != 0) return 20.0;
        return 0;
    }

    fn evalQuantumGravity(self: *Self, law: *const genome.LawGenome) f64 {
        _ = self;
        // Бонус если используются и ℏ и G
        const has_hbar = law.powers[2] != 0;
        const has_G = law.powers[1] != 0;
        if (has_hbar and has_G) return 25.0;
        return 0;
    }
};

// ============================================================================
// НАБОР ЭВРИСТИК (эволюционирует как единое целое)
// ============================================================================

pub const HeuristicSet = struct {
    heuristics: [9]Heuristic,
    generation: u32,
    total_fitness_produced: f64,
    
    const Self = @This();

    pub fn init() Self {
        return .{
            .heuristics = [_]Heuristic{
                .{ .htype = .dimensionless_bonus, .weight = 1.0, .threshold = 0, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .simplicity_bonus, .weight = 1.0, .threshold = 10, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .near_integer_bonus, .weight = 1.0, .threshold = 0.1, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .near_simple_fraction, .weight = 1.0, .threshold = 0.1, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .known_value_penalty, .weight = 1.0, .threshold = 0, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .extreme_value_penalty, .weight = 1.0, .threshold = 50, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .physical_dimension_bonus, .weight = 1.0, .threshold = 0, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .cosmological_bonus, .weight = 1.0, .threshold = 0, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
                .{ .htype = .quantum_gravity_bonus, .weight = 1.0, .threshold = 0, .enabled = true, .times_triggered = 0, .discoveries_contributed = 0 },
            },
            .generation = 0,
            .total_fitness_produced = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn evaluate(self: *Self, law: *const genome.LawGenome) f64 {
        var total: f64 = 0;
        for (&self.heuristics) |*h| {
            total += h.apply(law);
        }
        self.total_fitness_produced += total;
        return total;
    }

    pub fn mutate(self: *Self, rng: *std.Random) void {
        // Мутируем случайную эвристику
        const idx = rng.intRangeAtMost(usize, 0, self.heuristics.len - 1);
        var h = &self.heuristics[idx];
        
        // Мутация веса
        const weight_delta = (rng.float(f64) - 0.5) * 0.4;
        h.weight = @max(0.1, @min(3.0, h.weight + weight_delta));
        
        // Мутация порога
        if (h.threshold > 0) {
            const thresh_delta = (rng.float(f64) - 0.5) * h.threshold * 0.3;
            h.threshold = @max(0.01, h.threshold + thresh_delta);
        }
        
        // Иногда включаем/выключаем
        if (rng.float(f64) < 0.05) {
            h.enabled = !h.enabled;
        }
        
        self.generation += 1;
    }

    pub fn crossover(self: *const Self, other: *const Self, rng: *std.Random) Self {
        var child = Self.init();
        
        for (0..self.heuristics.len) |i| {
            if (rng.boolean()) {
                child.heuristics[i] = self.heuristics[i];
            } else {
                child.heuristics[i] = other.heuristics[i];
            }
            // Сбрасываем статистику
            child.heuristics[i].times_triggered = 0;
            child.heuristics[i].discoveries_contributed = 0;
        }
        
        child.generation = @max(self.generation, other.generation) + 1;
        return child;
    }

    pub fn print(self: *const Self) void {
        const p = std.debug.print;
        p("Heuristic Set (gen {}):\n", .{self.generation});
        for (self.heuristics) |h| {
            const status = if (h.enabled) "ON " else "OFF";
            p("  [{s}] {s}: weight={d:.2}, threshold={d:.2}, triggered={}\n", .{
                status,
                @tagName(h.htype),
                h.weight,
                h.threshold,
                h.times_triggered,
            });
        }
    }

    pub fn effectiveness(self: *const Self) f64 {
        var total_discoveries: u64 = 0;
        var total_triggers: u64 = 0;
        for (self.heuristics) |h| {
            total_discoveries += h.discoveries_contributed;
            total_triggers += h.times_triggered;
        }
        if (total_triggers == 0) return 0;
        return @as(f64, @floatFromInt(total_discoveries)) / @as(f64, @floatFromInt(total_triggers));
    }
};

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "heuristic_dimensionless" {
    var hs = HeuristicSet.init();
    
    var law = genome.LawGenome.init();
    law.powers[8] = 1;  // α (безразмерная)
    
    const score = hs.evaluate(&law);
    try std.testing.expect(score > 0);
}

test "heuristic_mutation" {
    var hs = HeuristicSet.init();
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    
    hs.mutate(&rng);
    
    // Что-то должно измениться
    try std.testing.expect(hs.generation == 1);
}
