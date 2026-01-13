// CONSTANTS_EXTENDED.ZIG - Расширенный набор физических констант
// 30+ констант для глубокого поиска

const std = @import("std");

pub const Constant = struct {
    name: []const u8,
    symbol: []const u8,
    value: f64,
    uncertainty: f64,  // относительная погрешность
    dim: [5]i8,        // M, L, T, Q, K
    category: Category,
};

pub const Category = enum {
    fundamental,      // фундаментальные
    particle_mass,    // массы частиц
    cosmological,     // космологические
    electromagnetic,  // электромагнитные
    atomic,           // атомные
    nuclear,          // ядерные
    derived,          // производные
};

// ============================================================================
// ПОЛНЫЙ НАБОР КОНСТАНТ (32 штуки)
// ============================================================================

pub const ALL_CONSTANTS = [_]Constant{
    // === ФУНДАМЕНТАЛЬНЫЕ (6) ===
    .{ .name = "speed_of_light", .symbol = "c", .value = 299792458, .uncertainty = 0, .dim = .{ 0, 1, -1, 0, 0 }, .category = .fundamental },
    .{ .name = "gravitational", .symbol = "G", .value = 6.67430e-11, .uncertainty = 2.2e-5, .dim = .{ -1, 3, -2, 0, 0 }, .category = .fundamental },
    .{ .name = "planck", .symbol = "ℏ", .value = 1.054571817e-34, .uncertainty = 0, .dim = .{ 1, 2, -1, 0, 0 }, .category = .fundamental },
    .{ .name = "boltzmann", .symbol = "kB", .value = 1.380649e-23, .uncertainty = 0, .dim = .{ 1, 2, -2, 0, -1 }, .category = .fundamental },
    .{ .name = "electron_charge", .symbol = "e", .value = 1.602176634e-19, .uncertainty = 0, .dim = .{ 0, 0, 1, 1, 0 }, .category = .fundamental },
    .{ .name = "avogadro", .symbol = "NA", .value = 6.02214076e23, .uncertainty = 0, .dim = .{ 0, 0, 0, 0, 0 }, .category = .fundamental },

    // === МАССЫ ЧАСТИЦ (10) ===
    .{ .name = "electron_mass", .symbol = "me", .value = 9.1093837015e-31, .uncertainty = 3e-10, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "proton_mass", .symbol = "mp", .value = 1.67262192369e-27, .uncertainty = 3e-10, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "neutron_mass", .symbol = "mn", .value = 1.67492749804e-27, .uncertainty = 5e-10, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "muon_mass", .symbol = "mμ", .value = 1.883531627e-28, .uncertainty = 2.5e-8, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "tau_mass", .symbol = "mτ", .value = 3.16754e-27, .uncertainty = 9e-5, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "W_boson_mass", .symbol = "mW", .value = 1.43296e-25, .uncertainty = 1.5e-4, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "Z_boson_mass", .symbol = "mZ", .value = 1.62536e-25, .uncertainty = 2.5e-5, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "higgs_mass", .symbol = "mH", .value = 2.2256e-25, .uncertainty = 2e-3, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "planck_mass", .symbol = "mP", .value = 2.176434e-8, .uncertainty = 1.1e-5, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },
    .{ .name = "atomic_mass_unit", .symbol = "u", .value = 1.66053906660e-27, .uncertainty = 3e-10, .dim = .{ 1, 0, 0, 0, 0 }, .category = .particle_mass },

    // === КОСМОЛОГИЧЕСКИЕ (6) ===
    .{ .name = "hubble_constant", .symbol = "H₀", .value = 2.2e-18, .uncertainty = 0.05, .dim = .{ 0, 0, -1, 0, 0 }, .category = .cosmological },
    .{ .name = "cosmological_constant", .symbol = "Λ", .value = 1.1056e-52, .uncertainty = 0.02, .dim = .{ 0, -2, 0, 0, 0 }, .category = .cosmological },
    .{ .name = "critical_density", .symbol = "ρc", .value = 9.47e-27, .uncertainty = 0.05, .dim = .{ 1, -3, 0, 0, 0 }, .category = .cosmological },
    .{ .name = "CMB_temperature", .symbol = "TCMB", .value = 2.7255, .uncertainty = 2e-4, .dim = .{ 0, 0, 0, 0, 1 }, .category = .cosmological },
    .{ .name = "hubble_length", .symbol = "lH", .value = 1.36e26, .uncertainty = 0.05, .dim = .{ 0, 1, 0, 0, 0 }, .category = .cosmological },
    .{ .name = "hubble_mass", .symbol = "MH", .value = 1.84e53, .uncertainty = 0.1, .dim = .{ 1, 0, 0, 0, 0 }, .category = .cosmological },

    // === ЭЛЕКТРОМАГНИТНЫЕ (4) ===
    .{ .name = "vacuum_permittivity", .symbol = "ε₀", .value = 8.8541878128e-12, .uncertainty = 0, .dim = .{ -1, -3, 4, 2, 0 }, .category = .electromagnetic },
    .{ .name = "vacuum_permeability", .symbol = "μ₀", .value = 1.25663706212e-6, .uncertainty = 0, .dim = .{ 1, 1, -2, -2, 0 }, .category = .electromagnetic },
    .{ .name = "coulomb_constant", .symbol = "ke", .value = 8.9875517923e9, .uncertainty = 0, .dim = .{ 1, 3, -4, -2, 0 }, .category = .electromagnetic },
    .{ .name = "fine_structure", .symbol = "α", .value = 7.2973525693e-3, .uncertainty = 1.5e-10, .dim = .{ 0, 0, 0, 0, 0 }, .category = .electromagnetic },

    // === АТОМНЫЕ (4) ===
    .{ .name = "bohr_radius", .symbol = "a₀", .value = 5.29177210903e-11, .uncertainty = 8e-13, .dim = .{ 0, 1, 0, 0, 0 }, .category = .atomic },
    .{ .name = "compton_wavelength", .symbol = "λC", .value = 2.42631023867e-12, .uncertainty = 7e-22, .dim = .{ 0, 1, 0, 0, 0 }, .category = .atomic },
    .{ .name = "rydberg_energy", .symbol = "Ry", .value = 2.1798723611035e-18, .uncertainty = 4e-30, .dim = .{ 1, 2, -2, 0, 0 }, .category = .atomic },
    .{ .name = "bohr_magneton", .symbol = "μB", .value = 9.2740100783e-24, .uncertainty = 3e-33, .dim = .{ 0, 2, 0, 1, 0 }, .category = .atomic },

    // === ЯДЕРНЫЕ (2) ===
    .{ .name = "nuclear_magneton", .symbol = "μN", .value = 5.0507837461e-27, .uncertainty = 1.5e-36, .dim = .{ 0, 2, 0, 1, 0 }, .category = .nuclear },
    .{ .name = "fermi_coupling", .symbol = "GF", .value = 1.1663787e-5, .uncertainty = 6e-12, .dim = .{ -2, 0, 0, 0, 0 }, .category = .nuclear },
};

pub const NUM_CONSTANTS = ALL_CONSTANTS.len;

// ============================================================================
// ИЗВЕСТНЫЕ СООТНОШЕНИЯ (для проверки на новизну)
// ============================================================================

pub const KnownRelation = struct {
    name: []const u8,
    value: f64,
    formula: []const u8,
};

pub const KNOWN_RELATIONS = [_]KnownRelation{
    // Планковские единицы
    .{ .name = "planck_length", .value = 1.616255e-35, .formula = "√(ℏG/c³)" },
    .{ .name = "planck_time", .value = 5.391247e-44, .formula = "√(ℏG/c⁵)" },
    .{ .name = "planck_mass", .value = 2.176434e-8, .formula = "√(ℏc/G)" },
    .{ .name = "planck_temperature", .value = 1.416784e32, .formula = "√(ℏc⁵/GkB²)" },
    .{ .name = "planck_energy", .value = 1.9561e9, .formula = "√(ℏc⁵/G)" },
    
    // Атомные
    .{ .name = "bohr_radius", .value = 5.292e-11, .formula = "ℏ²/(me·e²·ke)" },
    .{ .name = "compton_wavelength", .value = 2.426e-12, .formula = "ℏ/(me·c)" },
    .{ .name = "classical_electron_radius", .value = 2.818e-15, .formula = "e²·ke/(me·c²)" },
    
    // Безразмерные
    .{ .name = "fine_structure", .value = 7.297e-3, .formula = "e²·ke/(ℏc)" },
    .{ .name = "inverse_fine_structure", .value = 137.036, .formula = "ℏc/(e²·ke)" },
    .{ .name = "proton_electron_ratio", .value = 1836.15, .formula = "mp/me" },
    .{ .name = "gravitational_coupling", .value = 5.906e-39, .formula = "G·mp²/(ℏc)" },
    
    // Космологические
    .{ .name = "hubble_planck_ratio", .value = 8.4e60, .formula = "tH/tP" },
    
    // НАШЕ ОТКРЫТИЕ!
    .{ .name = "hubble_relation", .value = 0.48, .formula = "ℏ²H₀/(cG·me·mp²)" },
};

// ============================================================================
// ЦЕЛЕВЫЕ ЗНАЧЕНИЯ (что ищем)
// ============================================================================

pub const TARGET_VALUES = [_]struct { val: f64, name: []const u8, importance: u8 }{
    // Простые дроби
    .{ .val = 0.5, .name = "1/2", .importance = 10 },
    .{ .val = 0.333333, .name = "1/3", .importance = 9 },
    .{ .val = 0.25, .name = "1/4", .importance = 8 },
    .{ .val = 0.2, .name = "1/5", .importance = 7 },
    .{ .val = 0.666667, .name = "2/3", .importance = 9 },
    .{ .val = 0.75, .name = "3/4", .importance = 8 },
    
    // Целые
    .{ .val = 1.0, .name = "1", .importance = 10 },
    .{ .val = 2.0, .name = "2", .importance = 9 },
    .{ .val = 3.0, .name = "3", .importance = 8 },
    .{ .val = 4.0, .name = "4", .importance = 7 },
    .{ .val = 6.0, .name = "6", .importance = 6 },
    .{ .val = 8.0, .name = "8", .importance = 6 },
    .{ .val = 10.0, .name = "10", .importance = 6 },
    
    // Математические константы
    .{ .val = 3.14159265, .name = "π", .importance = 10 },
    .{ .val = 2.71828183, .name = "e", .importance = 9 },
    .{ .val = 1.41421356, .name = "√2", .importance = 8 },
    .{ .val = 1.73205081, .name = "√3", .importance = 7 },
    .{ .val = 1.61803399, .name = "φ (golden)", .importance = 9 },
    .{ .val = 2.50662827, .name = "√(2π)", .importance = 7 },
    
    // Степени 10 (космологические масштабы)
    .{ .val = 1e40, .name = "10^40 (Dirac)", .importance = 10 },
    .{ .val = 1e60, .name = "10^60 (Planck/Hubble)", .importance = 10 },
    .{ .val = 1e80, .name = "10^80 (Eddington)", .importance = 9 },
    .{ .val = 1e122, .name = "10^122 (CC problem)", .importance = 10 },
};

// ============================================================================
// ФУНКЦИИ
// ============================================================================

pub fn isKnownValue(val: f64, tolerance: f64) ?[]const u8 {
    for (KNOWN_RELATIONS) |rel| {
        const ratio = val / rel.value;
        if (ratio > 1 - tolerance and ratio < 1 + tolerance) {
            return rel.name;
        }
    }
    return null;
}

pub fn findNearestTarget(val: f64, tolerance: f64) ?struct { name: []const u8, importance: u8, diff: f64 } {
    var best: ?struct { name: []const u8, importance: u8, diff: f64 } = null;
    
    for (TARGET_VALUES) |target| {
        const diff = @abs(val - target.val) / @abs(target.val);
        if (diff < tolerance) {
            if (best == null or target.importance > best.?.importance) {
                best = .{ .name = target.name, .importance = target.importance, .diff = diff };
            }
        }
    }
    
    return best;
}

pub fn getConstantsByCategory(category: Category) []const Constant {
    var count: usize = 0;
    for (ALL_CONSTANTS) |c| {
        if (c.category == category) count += 1;
    }
    
    // Возвращаем срез (в реальности нужен аллокатор)
    return &[_]Constant{};
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "constants_count" {
    try std.testing.expectEqual(NUM_CONSTANTS, 32);
}

test "known_value_detection" {
    const result = isKnownValue(137.0, 0.01);
    try std.testing.expect(result != null);
}

test "target_detection" {
    const result = findNearestTarget(0.49, 0.05);
    try std.testing.expect(result != null);
    try std.testing.expect(std.mem.eql(u8, result.?.name, "1/2"));
}
