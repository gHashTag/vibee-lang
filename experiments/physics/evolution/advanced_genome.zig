// ADVANCED_GENOME.ZIG - Расширенный геном с новыми операциями
// Поддержка сумм, логарифмов, экспонент

const std = @import("std");
const math = std.math;
const constants = @import("constants_extended.zig");

// ============================================================================
// ТИПЫ ОПЕРАЦИЙ
// ============================================================================

pub const OperationType = enum {
    product,      // Произведение констант (базовый)
    sum,          // Сумма двух произведений
    ratio,        // Отношение двух произведений
    log,          // Логарифм произведения
    exp,          // Экспонента от безразмерного
    sqrt,         // Корень
    power,        // Степень (дробная)
};

// ============================================================================
// ТЕРМ - одно произведение констант
// ============================================================================

pub const Term = struct {
    powers: [16]i8,  // Степени для 16 констант
    coefficient: f64,
    
    const Self = @This();

    pub fn init() Self {
        return .{
            .powers = [_]i8{0} ** 16,
            .coefficient = 1.0,
        };
    }

    pub fn compute(self: *const Self) f64 {
        var result = self.coefficient;
        
        for (0..@min(constants.NUM_CONSTANTS, 16)) |i| {
            const p = self.powers[i];
            if (p != 0) {
                result *= math.pow(f64, constants.ALL_CONSTANTS[i].value, @floatFromInt(p));
            }
        }
        
        return result;
    }

    pub fn computeDimension(self: *const Self) [5]i8 {
        var dim = [_]i8{0} ** 5;
        
        for (0..@min(constants.NUM_CONSTANTS, 16)) |i| {
            const p = self.powers[i];
            if (p != 0) {
                for (0..5) |d| {
                    dim[d] += p * constants.ALL_CONSTANTS[i].dim[d];
                }
            }
        }
        
        return dim;
    }

    pub fn random(rng: *std.Random) Self {
        var t = Self.init();
        
        // Выбираем 2-4 случайные константы
        const num_consts = 2 + rng.intRangeAtMost(usize, 0, 2);
        for (0..num_consts) |_| {
            const idx = rng.intRangeAtMost(usize, 0, 15);
            t.powers[idx] = @as(i8, @intCast(rng.intRangeAtMost(i32, -3, 3)));
            if (t.powers[idx] == 0) t.powers[idx] = 1;
        }
        
        // Случайный коэффициент
        const coeffs = [_]f64{ 0.5, 1.0, 2.0, 3.0, 4.0, 0.25, 0.333, 0.667 };
        t.coefficient = coeffs[rng.intRangeAtMost(usize, 0, coeffs.len - 1)];
        
        return t;
    }
};

// ============================================================================
// РАСШИРЕННЫЙ ГЕНОМ
// ============================================================================

pub const AdvancedGenome = struct {
    operation: OperationType,
    term1: Term,
    term2: Term,  // Для sum, ratio
    exponent: f64,  // Для power
    
    // Метаданные
    fitness: f64,
    generation: u32,
    
    const Self = @This();

    pub fn init() Self {
        return .{
            .operation = .product,
            .term1 = Term.init(),
            .term2 = Term.init(),
            .exponent = 1.0,
            .fitness = 0,
            .generation = 0,
        };
    }

    pub fn random(rng: *std.Random) Self {
        var g = Self.init();
        
        // Случайная операция (с весами)
        const op_choice = rng.intRangeAtMost(u32, 0, 100);
        if (op_choice < 50) {
            g.operation = .product;
        } else if (op_choice < 65) {
            g.operation = .sqrt;
        } else if (op_choice < 75) {
            g.operation = .sum;
        } else if (op_choice < 85) {
            g.operation = .ratio;
        } else if (op_choice < 92) {
            g.operation = .log;
        } else if (op_choice < 97) {
            g.operation = .exp;
        } else {
            g.operation = .power;
        }
        
        g.term1 = Term.random(rng);
        
        if (g.operation == .sum or g.operation == .ratio) {
            g.term2 = Term.random(rng);
        }
        
        if (g.operation == .power) {
            const exps = [_]f64{ 0.5, 1.5, 2.5, 0.333, 0.667, 1.333 };
            g.exponent = exps[rng.intRangeAtMost(usize, 0, exps.len - 1)];
        }
        
        return g;
    }

    pub fn compute(self: *const Self) f64 {
        const v1 = self.term1.compute();
        
        return switch (self.operation) {
            .product => v1,
            .sqrt => if (v1 > 0) @sqrt(v1) else math.nan(f64),
            .sum => v1 + self.term2.compute(),
            .ratio => blk: {
                const v2 = self.term2.compute();
                break :blk if (v2 != 0) v1 / v2 else math.nan(f64);
            },
            .log => if (v1 > 0) @log(v1) else math.nan(f64),
            .exp => @exp(v1),
            .power => if (v1 > 0) math.pow(f64, v1, self.exponent) else math.nan(f64),
        };
    }

    pub fn isDimensionless(self: *const Self) bool {
        const dim1 = self.term1.computeDimension();
        
        switch (self.operation) {
            .product, .sqrt, .power => {
                for (dim1) |d| {
                    if (d != 0) return false;
                }
                return true;
            },
            .sum => {
                const dim2 = self.term2.computeDimension();
                // Сумма безразмерна если оба терма безразмерны
                for (0..5) |i| {
                    if (dim1[i] != 0 or dim2[i] != 0) return false;
                }
                return true;
            },
            .ratio => {
                const dim2 = self.term2.computeDimension();
                // Отношение безразмерно если размерности равны
                for (0..5) |i| {
                    if (dim1[i] != dim2[i]) return false;
                }
                return true;
            },
            .log, .exp => {
                // log и exp требуют безразмерного аргумента
                for (dim1) |d| {
                    if (d != 0) return false;
                }
                return true;
            },
        }
    }

    pub fn printFormula(self: *const Self) void {
        const print = std.debug.print;
        
        switch (self.operation) {
            .product => self.printTerm(&self.term1),
            .sqrt => {
                print("√(", .{});
                self.printTerm(&self.term1);
                print(")", .{});
            },
            .sum => {
                print("(", .{});
                self.printTerm(&self.term1);
                print(" + ", .{});
                self.printTerm(&self.term2);
                print(")", .{});
            },
            .ratio => {
                print("(", .{});
                self.printTerm(&self.term1);
                print(") / (", .{});
                self.printTerm(&self.term2);
                print(")", .{});
            },
            .log => {
                print("ln(", .{});
                self.printTerm(&self.term1);
                print(")", .{});
            },
            .exp => {
                print("exp(", .{});
                self.printTerm(&self.term1);
                print(")", .{});
            },
            .power => {
                print("(", .{});
                self.printTerm(&self.term1);
                print(")^{d:.2}", .{self.exponent});
            },
        }
    }

    fn printTerm(self: *const Self, term: *const Term) void {
        _ = self;
        const print = std.debug.print;
        
        if (term.coefficient != 1.0) {
            print("{d}×", .{term.coefficient});
        }
        
        var first = true;
        for (0..@min(constants.NUM_CONSTANTS, 16)) |i| {
            const p = term.powers[i];
            if (p != 0) {
                if (!first) print("×", .{});
                print("{s}", .{constants.ALL_CONSTANTS[i].symbol});
                if (p != 1) print("^{}", .{p});
                first = false;
            }
        }
    }

    pub fn complexity(self: *const Self) u32 {
        var c: u32 = 0;
        
        // Сложность операции
        c += switch (self.operation) {
            .product => 0,
            .sqrt => 1,
            .sum, .ratio => 2,
            .log, .exp => 3,
            .power => 2,
        };
        
        // Сложность термов
        for (self.term1.powers) |p| {
            if (p != 0) c += 1;
            c += @as(u32, @intCast(if (p < 0) -p else p));
        }
        
        if (self.operation == .sum or self.operation == .ratio) {
            for (self.term2.powers) |p| {
                if (p != 0) c += 1;
                c += @as(u32, @intCast(if (p < 0) -p else p));
            }
        }
        
        return c;
    }
};

// ============================================================================
// МУТАЦИИ
// ============================================================================

pub fn mutate(g: *AdvancedGenome, rng: *std.Random) void {
    const choice = rng.intRangeAtMost(u32, 0, 10);
    
    switch (choice) {
        0...3 => {
            // Мутация степени в term1
            const idx = rng.intRangeAtMost(usize, 0, 15);
            const delta = @as(i8, @intCast(rng.intRangeAtMost(i32, -2, 2)));
            g.term1.powers[idx] = @max(-4, @min(4, g.term1.powers[idx] + delta));
        },
        4...5 => {
            // Мутация коэффициента
            const coeffs = [_]f64{ 0.5, 1.0, 2.0, 3.0, 4.0, 0.25, 0.333, 0.667, 1.5 };
            g.term1.coefficient = coeffs[rng.intRangeAtMost(usize, 0, coeffs.len - 1)];
        },
        6...7 => {
            // Мутация операции
            const ops = [_]OperationType{ .product, .sqrt, .sum, .ratio, .log };
            g.operation = ops[rng.intRangeAtMost(usize, 0, ops.len - 1)];
        },
        8...9 => {
            // Мутация term2 (если используется)
            if (g.operation == .sum or g.operation == .ratio) {
                const idx = rng.intRangeAtMost(usize, 0, 15);
                const delta = @as(i8, @intCast(rng.intRangeAtMost(i32, -2, 2)));
                g.term2.powers[idx] = @max(-4, @min(4, g.term2.powers[idx] + delta));
            }
        },
        10 => {
            // Мутация экспоненты
            if (g.operation == .power) {
                g.exponent += (rng.float(f64) - 0.5) * 0.5;
                g.exponent = @max(0.1, @min(3.0, g.exponent));
            }
        },
        else => {},
    }
}

pub fn crossover(p1: *const AdvancedGenome, p2: *const AdvancedGenome, rng: *std.Random) AdvancedGenome {
    var child = AdvancedGenome.init();
    
    // Операция от одного из родителей
    child.operation = if (rng.boolean()) p1.operation else p2.operation;
    
    // Термы - uniform crossover
    for (0..16) |i| {
        child.term1.powers[i] = if (rng.boolean()) p1.term1.powers[i] else p2.term1.powers[i];
        child.term2.powers[i] = if (rng.boolean()) p1.term2.powers[i] else p2.term2.powers[i];
    }
    
    child.term1.coefficient = if (rng.boolean()) p1.term1.coefficient else p2.term1.coefficient;
    child.exponent = (p1.exponent + p2.exponent) / 2;
    
    child.generation = @max(p1.generation, p2.generation) + 1;
    
    return child;
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "advanced_genome_product" {
    var g = AdvancedGenome.init();
    g.term1.powers[0] = 1;  // c
    
    const val = g.compute();
    try std.testing.expectApproxEqRel(val, 299792458, 0.001);
}

test "advanced_genome_sqrt" {
    var g = AdvancedGenome.init();
    g.operation = .sqrt;
    g.term1.coefficient = 4.0;
    
    const val = g.compute();
    try std.testing.expectApproxEqRel(val, 2.0, 0.001);
}

test "advanced_genome_ratio" {
    var g = AdvancedGenome.init();
    g.operation = .ratio;
    g.term1.powers[7] = 1;  // mp
    g.term2.powers[6] = 1;  // me
    
    const val = g.compute();
    try std.testing.expect(val > 1800 and val < 1900);  // mp/me ≈ 1836
}
