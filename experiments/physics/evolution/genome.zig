// GENOME.ZIG - Геном физического закона
// Кодирует комбинацию констант и операций

const std = @import("std");
const math = std.math;

// ============================================================================
// ФИЗИЧЕСКИЕ КОНСТАНТЫ
// ============================================================================

pub const Constant = struct {
    name: []const u8,
    symbol: []const u8,
    value: f64,
    dim: [5]i8,  // M, L, T, Q, K
};

pub const CONSTANTS = [_]Constant{
    .{ .name = "speed_of_light", .symbol = "c", .value = 299792458, .dim = .{ 0, 1, -1, 0, 0 } },
    .{ .name = "gravitational", .symbol = "G", .value = 6.67430e-11, .dim = .{ -1, 3, -2, 0, 0 } },
    .{ .name = "planck", .symbol = "ℏ", .value = 1.054571817e-34, .dim = .{ 1, 2, -1, 0, 0 } },
    .{ .name = "boltzmann", .symbol = "kB", .value = 1.380649e-23, .dim = .{ 1, 2, -2, 0, -1 } },
    .{ .name = "electron_charge", .symbol = "e", .value = 1.602176634e-19, .dim = .{ 0, 0, 1, 1, 0 } },
    .{ .name = "electron_mass", .symbol = "me", .value = 9.1093837015e-31, .dim = .{ 1, 0, 0, 0, 0 } },
    .{ .name = "proton_mass", .symbol = "mp", .value = 1.67262192369e-27, .dim = .{ 1, 0, 0, 0, 0 } },
    .{ .name = "neutron_mass", .symbol = "mn", .value = 1.67492749804e-27, .dim = .{ 1, 0, 0, 0, 0 } },
    .{ .name = "fine_structure", .symbol = "α", .value = 7.2973525693e-3, .dim = .{ 0, 0, 0, 0, 0 } },
    .{ .name = "hubble", .symbol = "H₀", .value = 2.2e-18, .dim = .{ 0, 0, -1, 0, 0 } },
    .{ .name = "vacuum_permittivity", .symbol = "ε₀", .value = 8.8541878128e-12, .dim = .{ -1, -3, 4, 2, 0 } },
    .{ .name = "vacuum_permeability", .symbol = "μ₀", .value = 1.25663706212e-6, .dim = .{ 1, 1, -2, -2, 0 } },
};

pub const NUM_CONSTANTS = CONSTANTS.len;
pub const MAX_POWER = 4;

// ============================================================================
// ГЕНОМ ЗАКОНА
// ============================================================================

pub const LawGenome = struct {
    // Степени для каждой константы: -MAX_POWER..MAX_POWER
    powers: [NUM_CONSTANTS]i8,
    
    // Дополнительные параметры
    numerator_coeff: f64,    // числовой коэффициент в числителе
    sqrt_applied: bool,      // применён ли корень
    
    // Метаданные
    fitness: f64,
    generation: u32,
    parent_id: u32,
    mutations: u32,
    
    const Self = @This();

    pub fn init() Self {
        return .{
            .powers = [_]i8{0} ** NUM_CONSTANTS,
            .numerator_coeff = 1.0,
            .sqrt_applied = false,
            .fitness = 0,
            .generation = 0,
            .parent_id = 0,
            .mutations = 0,
        };
    }

    pub fn random(rng: *std.Random) Self {
        var g = Self.init();
        
        // Случайные степени
        for (&g.powers) |*p| {
            p.* = @as(i8, @intCast(rng.intRangeAtMost(i32, -MAX_POWER, MAX_POWER)));
        }
        
        // Гарантируем хотя бы одну ненулевую
        const idx = rng.intRangeAtMost(usize, 0, NUM_CONSTANTS - 1);
        if (g.powers[idx] == 0) g.powers[idx] = 1;
        
        // Случайный коэффициент (простые числа)
        const coeffs = [_]f64{ 0.5, 1.0, 2.0, 3.0, 4.0, 0.25, 0.333, 1.5 };
        g.numerator_coeff = coeffs[rng.intRangeAtMost(usize, 0, coeffs.len - 1)];
        
        g.sqrt_applied = rng.boolean();
        
        return g;
    }

    pub fn computeValue(self: *const Self) f64 {
        var result: f64 = self.numerator_coeff;
        
        for (CONSTANTS, 0..) |c, i| {
            const p = self.powers[i];
            if (p != 0) {
                result *= math.pow(f64, c.value, @floatFromInt(p));
            }
        }
        
        if (self.sqrt_applied and result > 0) {
            result = @sqrt(result);
        }
        
        return result;
    }

    pub fn computeDimension(self: *const Self) [5]i8 {
        var dim = [_]i8{0} ** 5;
        
        for (CONSTANTS, 0..) |c, i| {
            const p = self.powers[i];
            if (p != 0) {
                for (0..5) |d| {
                    dim[d] += p * c.dim[d];
                }
            }
        }
        
        if (self.sqrt_applied) {
            // Корень делит размерности пополам (только если чётные)
            var can_sqrt = true;
            for (dim) |d| {
                if (@mod(d, 2) != 0) can_sqrt = false;
            }
            if (can_sqrt) {
                for (&dim) |*d| {
                    d.* = @divTrunc(d.*, 2);
                }
            }
        }
        
        return dim;
    }

    pub fn isDimensionless(self: *const Self) bool {
        const dim = self.computeDimension();
        for (dim) |d| {
            if (d != 0) return false;
        }
        return true;
    }

    pub fn getDimensionName(self: *const Self) []const u8 {
        const dim = self.computeDimension();
        
        if (dim[0] == 0 and dim[1] == 0 and dim[2] == 0 and dim[3] == 0 and dim[4] == 0) return "безразмерная";
        if (dim[0] == 0 and dim[1] == 1 and dim[2] == 0) return "длина";
        if (dim[0] == 0 and dim[1] == 0 and dim[2] == 1) return "время";
        if (dim[0] == 1 and dim[1] == 0 and dim[2] == 0) return "масса";
        if (dim[0] == 1 and dim[1] == 2 and dim[2] == -2) return "энергия";
        if (dim[0] == 1 and dim[1] == 1 and dim[2] == -2) return "сила";
        if (dim[0] == 0 and dim[1] == -2 and dim[2] == 0) return "1/площадь";
        if (dim[0] == 0 and dim[1] == 0 and dim[2] == -1) return "частота";
        
        return "другая";
    }

    pub fn printFormula(self: *const Self) void {
        const print = std.debug.print;
        
        if (self.sqrt_applied) print("√(", .{});
        if (self.numerator_coeff != 1.0) print("{d}×", .{self.numerator_coeff});
        
        var first = true;
        for (CONSTANTS, 0..) |c, i| {
            const p = self.powers[i];
            if (p != 0) {
                if (!first) print("×", .{});
                print("{s}", .{c.symbol});
                if (p != 1) print("^{}", .{p});
                first = false;
            }
        }
        
        if (self.sqrt_applied) print(")", .{});
    }

    pub fn complexity(self: *const Self) u32 {
        var c: u32 = 0;
        for (self.powers) |p| {
            if (p != 0) c += 1;
            c += @as(u32, @intCast(if (p < 0) -p else p));
        }
        if (self.sqrt_applied) c += 2;
        return c;
    }

    pub fn clone(self: *const Self) Self {
        return self.*;
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        for (0..NUM_CONSTANTS) |i| {
            if (self.powers[i] != other.powers[i]) return false;
        }
        return self.numerator_coeff == other.numerator_coeff and 
               self.sqrt_applied == other.sqrt_applied;
    }
};

// ============================================================================
// ПОПУЛЯЦИЯ
// ============================================================================

pub const Population = struct {
    laws: std.ArrayList(LawGenome),
    generation: u32,
    best_fitness: f64,
    discoveries: std.ArrayList(LawGenome),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .laws = std.ArrayList(LawGenome).init(allocator),
            .generation = 0,
            .best_fitness = 0,
            .discoveries = std.ArrayList(LawGenome).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.laws.deinit();
        self.discoveries.deinit();
    }

    pub fn randomInit(self: *Self, size: usize, rng: *std.Random) !void {
        for (0..size) |_| {
            var law = LawGenome.random(rng);
            law.generation = self.generation;
            try self.laws.append(law);
        }
    }

    pub fn addDiscovery(self: *Self, law: LawGenome) !void {
        // Проверяем на дубликаты
        for (self.discoveries.items) |d| {
            if (law.equals(&d)) return;
        }
        try self.discoveries.append(law);
    }
};

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "genome_value" {
    var g = LawGenome.init();
    g.powers[0] = 1;  // c^1
    const val = g.computeValue();
    try std.testing.expectApproxEqRel(val, 299792458, 0.001);
}

test "genome_dimensionless" {
    var g = LawGenome.init();
    g.powers[8] = 1;  // α (fine structure)
    try std.testing.expect(g.isDimensionless());
}

test "genome_dimension" {
    var g = LawGenome.init();
    g.powers[5] = 1;  // me (mass)
    const dim = g.computeDimension();
    try std.testing.expectEqual(dim[0], 1);  // M = 1
    try std.testing.expectEqual(dim[1], 0);  // L = 0
}
