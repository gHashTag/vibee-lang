const std = @import("std");
const math = std.math;

/// Periodic Table Module - Integrated with Unified Theory
/// Combines element data with energy calculations and molecular predictions

pub const PI: f64 = 3.14159265358979323846;

// ═══════════════════════════════════════════════════════════════
// ELEMENT DATA STRUCTURE
// ═══════════════════════════════════════════════════════════════

pub const ElementCategory = enum {
    AlkaliMetal,
    AlkalineEarthMetal,
    TransitionMetal,
    PostTransitionMetal,
    Metalloid,
    NonMetal,
    Halogen,
    NobleGas,
    Lanthanide,
    Actinide,
};

pub const Element = struct {
    symbol: []const u8,
    name: []const u8,
    atomic_number: u8,
    atomic_mass: f64,
    period: u8,
    group: u8,
    category: ElementCategory,
    electronegativity: f64,
    ionization_energy: f64, // kJ/mol
    electron_affinity: f64, // kJ/mol
    covalent_radius: f64, // pm
    atomic_radius: f64, // pm
    density: f64, // g/cm³
    melting_point: f64, // K
    boiling_point: f64, // K
    electron_config: []const u8,
    
    /// Calculate effective nuclear charge using Slater's rules
    pub fn zEffective(self: Element) f64 {
        const z = @as(f64, @floatFromInt(self.atomic_number));
        if (self.atomic_number <= 2) {
            return z - 0.30 * (z - 1.0);
        } else if (self.atomic_number <= 10) {
            return z - 2.0 * 0.85 - (z - 3.0) * 0.35;
        } else if (self.atomic_number <= 18) {
            return z - 2.0 - 8.0 * 0.85 - (z - 11.0) * 0.35;
        } else {
            return z - 10.0 - 8.0 * 0.85 - (z - 19.0) * 0.35;
        }
    }
    
    /// Predict ionization energy using unified pattern
    pub fn predictedIonizationEnergy(self: Element) f64 {
        const z_eff = self.zEffective();
        const n = @as(f64, @floatFromInt(self.period));
        return 1312.0 * (z_eff * z_eff) / (n * n);
    }
    
    /// Check if element is metal
    pub fn isMetal(self: Element) bool {
        return switch (self.category) {
            .AlkaliMetal, .AlkalineEarthMetal, .TransitionMetal, .PostTransitionMetal, .Lanthanide, .Actinide => true,
            else => false,
        };
    }
    
    /// Get oxidation states (simplified)
    pub fn commonOxidationStates(self: Element) []const i8 {
        return switch (self.group) {
            1 => &[_]i8{1},
            2 => &[_]i8{2},
            17 => &[_]i8{ -1, 1, 3, 5, 7 },
            18 => &[_]i8{0},
            else => &[_]i8{0},
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// PERIODIC TABLE DATA
// ═══════════════════════════════════════════════════════════════

pub const elements = [_]Element{
    // Period 1
    .{
        .symbol = "H",
        .name = "Hydrogen",
        .atomic_number = 1,
        .atomic_mass = 1.008,
        .period = 1,
        .group = 1,
        .category = .NonMetal,
        .electronegativity = 2.20,
        .ionization_energy = 1312.0,
        .electron_affinity = -72.8,
        .covalent_radius = 31,
        .atomic_radius = 53,
        .density = 0.00008988,
        .melting_point = 14.01,
        .boiling_point = 20.28,
        .electron_config = "1s¹",
    },
    .{
        .symbol = "He",
        .name = "Helium",
        .atomic_number = 2,
        .atomic_mass = 4.0026,
        .period = 1,
        .group = 18,
        .category = .NobleGas,
        .electronegativity = 0,
        .ionization_energy = 2372.3,
        .electron_affinity = 0,
        .covalent_radius = 28,
        .atomic_radius = 31,
        .density = 0.0001785,
        .melting_point = 0.95,
        .boiling_point = 4.22,
        .electron_config = "1s²",
    },
    // Period 2
    .{
        .symbol = "Li",
        .name = "Lithium",
        .atomic_number = 3,
        .atomic_mass = 6.94,
        .period = 2,
        .group = 1,
        .category = .AlkaliMetal,
        .electronegativity = 0.98,
        .ionization_energy = 520.2,
        .electron_affinity = -59.6,
        .covalent_radius = 128,
        .atomic_radius = 167,
        .density = 0.534,
        .melting_point = 453.69,
        .boiling_point = 1615,
        .electron_config = "[He] 2s¹",
    },
    .{
        .symbol = "Be",
        .name = "Beryllium",
        .atomic_number = 4,
        .atomic_mass = 9.0122,
        .period = 2,
        .group = 2,
        .category = .AlkalineEarthMetal,
        .electronegativity = 1.57,
        .ionization_energy = 899.5,
        .electron_affinity = 0,
        .covalent_radius = 96,
        .atomic_radius = 112,
        .density = 1.85,
        .melting_point = 1560,
        .boiling_point = 2742,
        .electron_config = "[He] 2s²",
    },
    .{
        .symbol = "B",
        .name = "Boron",
        .atomic_number = 5,
        .atomic_mass = 10.81,
        .period = 2,
        .group = 13,
        .category = .Metalloid,
        .electronegativity = 2.04,
        .ionization_energy = 800.6,
        .electron_affinity = -26.7,
        .covalent_radius = 84,
        .atomic_radius = 87,
        .density = 2.34,
        .melting_point = 2349,
        .boiling_point = 4200,
        .electron_config = "[He] 2s² 2p¹",
    },
    .{
        .symbol = "C",
        .name = "Carbon",
        .atomic_number = 6,
        .atomic_mass = 12.011,
        .period = 2,
        .group = 14,
        .category = .NonMetal,
        .electronegativity = 2.55,
        .ionization_energy = 1086.5,
        .electron_affinity = -121.8,
        .covalent_radius = 76,
        .atomic_radius = 67,
        .density = 2.267,
        .melting_point = 3823,
        .boiling_point = 4098,
        .electron_config = "[He] 2s² 2p²",
    },
    .{
        .symbol = "N",
        .name = "Nitrogen",
        .atomic_number = 7,
        .atomic_mass = 14.007,
        .period = 2,
        .group = 15,
        .category = .NonMetal,
        .electronegativity = 3.04,
        .ionization_energy = 1402.3,
        .electron_affinity = 7.0,
        .covalent_radius = 71,
        .atomic_radius = 56,
        .density = 0.0012506,
        .melting_point = 63.15,
        .boiling_point = 77.36,
        .electron_config = "[He] 2s² 2p³",
    },
    .{
        .symbol = "O",
        .name = "Oxygen",
        .atomic_number = 8,
        .atomic_mass = 15.999,
        .period = 2,
        .group = 16,
        .category = .NonMetal,
        .electronegativity = 3.44,
        .ionization_energy = 1313.9,
        .electron_affinity = -141.0,
        .covalent_radius = 66,
        .atomic_radius = 48,
        .density = 0.001429,
        .melting_point = 54.36,
        .boiling_point = 90.20,
        .electron_config = "[He] 2s² 2p⁴",
    },
    .{
        .symbol = "F",
        .name = "Fluorine",
        .atomic_number = 9,
        .atomic_mass = 18.998,
        .period = 2,
        .group = 17,
        .category = .Halogen,
        .electronegativity = 3.98,
        .ionization_energy = 1681.0,
        .electron_affinity = -328.0,
        .covalent_radius = 57,
        .atomic_radius = 42,
        .density = 0.001696,
        .melting_point = 53.53,
        .boiling_point = 85.03,
        .electron_config = "[He] 2s² 2p⁵",
    },
    .{
        .symbol = "Ne",
        .name = "Neon",
        .atomic_number = 10,
        .atomic_mass = 20.180,
        .period = 2,
        .group = 18,
        .category = .NobleGas,
        .electronegativity = 0,
        .ionization_energy = 2080.7,
        .electron_affinity = 0,
        .covalent_radius = 58,
        .atomic_radius = 38,
        .density = 0.0008999,
        .melting_point = 24.56,
        .boiling_point = 27.07,
        .electron_config = "[He] 2s² 2p⁶",
    },
    // Period 3
    .{
        .symbol = "Na",
        .name = "Sodium",
        .atomic_number = 11,
        .atomic_mass = 22.990,
        .period = 3,
        .group = 1,
        .category = .AlkaliMetal,
        .electronegativity = 0.93,
        .ionization_energy = 495.8,
        .electron_affinity = -52.8,
        .covalent_radius = 166,
        .atomic_radius = 190,
        .density = 0.971,
        .melting_point = 370.87,
        .boiling_point = 1156,
        .electron_config = "[Ne] 3s¹",
    },
    .{
        .symbol = "Mg",
        .name = "Magnesium",
        .atomic_number = 12,
        .atomic_mass = 24.305,
        .period = 3,
        .group = 2,
        .category = .AlkalineEarthMetal,
        .electronegativity = 1.31,
        .ionization_energy = 737.7,
        .electron_affinity = 0,
        .covalent_radius = 141,
        .atomic_radius = 145,
        .density = 1.738,
        .melting_point = 923,
        .boiling_point = 1363,
        .electron_config = "[Ne] 3s²",
    },
    .{
        .symbol = "Al",
        .name = "Aluminum",
        .atomic_number = 13,
        .atomic_mass = 26.982,
        .period = 3,
        .group = 13,
        .category = .PostTransitionMetal,
        .electronegativity = 1.61,
        .ionization_energy = 577.5,
        .electron_affinity = -42.5,
        .covalent_radius = 121,
        .atomic_radius = 118,
        .density = 2.698,
        .melting_point = 933.47,
        .boiling_point = 2792,
        .electron_config = "[Ne] 3s² 3p¹",
    },
    .{
        .symbol = "Si",
        .name = "Silicon",
        .atomic_number = 14,
        .atomic_mass = 28.086,
        .period = 3,
        .group = 14,
        .category = .Metalloid,
        .electronegativity = 1.90,
        .ionization_energy = 786.5,
        .electron_affinity = -133.6,
        .covalent_radius = 111,
        .atomic_radius = 111,
        .density = 2.3296,
        .melting_point = 1687,
        .boiling_point = 3538,
        .electron_config = "[Ne] 3s² 3p²",
    },
    .{
        .symbol = "P",
        .name = "Phosphorus",
        .atomic_number = 15,
        .atomic_mass = 30.974,
        .period = 3,
        .group = 15,
        .category = .NonMetal,
        .electronegativity = 2.19,
        .ionization_energy = 1011.8,
        .electron_affinity = -72.0,
        .covalent_radius = 107,
        .atomic_radius = 98,
        .density = 1.82,
        .melting_point = 317.30,
        .boiling_point = 553.65,
        .electron_config = "[Ne] 3s² 3p³",
    },
    .{
        .symbol = "S",
        .name = "Sulfur",
        .atomic_number = 16,
        .atomic_mass = 32.06,
        .period = 3,
        .group = 16,
        .category = .NonMetal,
        .electronegativity = 2.58,
        .ionization_energy = 999.6,
        .electron_affinity = -200.4,
        .covalent_radius = 105,
        .atomic_radius = 88,
        .density = 2.067,
        .melting_point = 388.36,
        .boiling_point = 717.87,
        .electron_config = "[Ne] 3s² 3p⁴",
    },
    .{
        .symbol = "Cl",
        .name = "Chlorine",
        .atomic_number = 17,
        .atomic_mass = 35.45,
        .period = 3,
        .group = 17,
        .category = .Halogen,
        .electronegativity = 3.16,
        .ionization_energy = 1251.2,
        .electron_affinity = -349.0,
        .covalent_radius = 102,
        .atomic_radius = 79,
        .density = 0.003214,
        .melting_point = 171.65,
        .boiling_point = 239.11,
        .electron_config = "[Ne] 3s² 3p⁵",
    },
    .{
        .symbol = "Ar",
        .name = "Argon",
        .atomic_number = 18,
        .atomic_mass = 39.948,
        .period = 3,
        .group = 18,
        .category = .NobleGas,
        .electronegativity = 0,
        .ionization_energy = 1520.6,
        .electron_affinity = 0,
        .covalent_radius = 106,
        .atomic_radius = 71,
        .density = 0.0017837,
        .melting_point = 83.80,
        .boiling_point = 87.30,
        .electron_config = "[Ne] 3s² 3p⁶",
    },
    // Period 4 (first few)
    .{
        .symbol = "K",
        .name = "Potassium",
        .atomic_number = 19,
        .atomic_mass = 39.098,
        .period = 4,
        .group = 1,
        .category = .AlkaliMetal,
        .electronegativity = 0.82,
        .ionization_energy = 418.8,
        .electron_affinity = -48.4,
        .covalent_radius = 203,
        .atomic_radius = 243,
        .density = 0.862,
        .melting_point = 336.53,
        .boiling_point = 1032,
        .electron_config = "[Ar] 4s¹",
    },
    .{
        .symbol = "Ca",
        .name = "Calcium",
        .atomic_number = 20,
        .atomic_mass = 40.078,
        .period = 4,
        .group = 2,
        .category = .AlkalineEarthMetal,
        .electronegativity = 1.00,
        .ionization_energy = 589.8,
        .electron_affinity = -2.37,
        .covalent_radius = 176,
        .atomic_radius = 194,
        .density = 1.54,
        .melting_point = 1115,
        .boiling_point = 1757,
        .electron_config = "[Ar] 4s²",
    },
};

// ═══════════════════════════════════════════════════════════════
// LOOKUP FUNCTIONS
// ═══════════════════════════════════════════════════════════════

/// Get element by atomic number
pub fn getByAtomicNumber(z: u8) ?Element {
    for (elements) |elem| {
        if (elem.atomic_number == z) return elem;
    }
    return null;
}

/// Get element by symbol
pub fn getBySymbol(symbol: []const u8) ?Element {
    for (elements) |elem| {
        if (std.mem.eql(u8, elem.symbol, symbol)) return elem;
    }
    return null;
}

/// Get all elements in a period
pub fn getElementsByPeriod(period: u8) []const Element {
    var count: usize = 0;
    for (elements) |elem| {
        if (elem.period == period) count += 1;
    }
    
    // Return slice (simplified - in real code would use allocator)
    var result: [20]Element = undefined;
    var idx: usize = 0;
    for (elements) |elem| {
        if (elem.period == period and idx < 20) {
            result[idx] = elem;
            idx += 1;
        }
    }
    return result[0..idx];
}

/// Get all elements in a group
pub fn getElementsByGroup(group: u8) []const Element {
    var result: [10]Element = undefined;
    var idx: usize = 0;
    for (elements) |elem| {
        if (elem.group == group and idx < 10) {
            result[idx] = elem;
            idx += 1;
        }
    }
    return result[0..idx];
}

// ═══════════════════════════════════════════════════════════════
// UNIFIED THEORY PREDICTIONS
// ═══════════════════════════════════════════════════════════════

/// Predict atomic radius using unified pattern
pub fn predictAtomicRadius(z: u8) f64 {
    const n = getPrincipalQuantumNumber(z);
    const z_eff = calculateZeff(z);
    
    // r ∝ n² / Z_eff (Bohr model relationship)
    const a0: f64 = 52.9; // Bohr radius in pm
    return a0 * @as(f64, @floatFromInt(n * n)) / z_eff;
}

/// Predict electronegativity using Mulliken scale
pub fn predictElectronegativity(z: u8) f64 {
    const elem = getByAtomicNumber(z) orelse return 2.0;
    // χ = (IE + EA) / 2 (Mulliken definition, scaled)
    return (elem.ionization_energy + @abs(elem.electron_affinity)) / 1000.0;
}

fn getPrincipalQuantumNumber(z: u8) u8 {
    if (z <= 2) return 1;
    if (z <= 10) return 2;
    if (z <= 18) return 3;
    if (z <= 36) return 4;
    if (z <= 54) return 5;
    return 6;
}

fn calculateZeff(z: u8) f64 {
    const atomic_num = @as(f64, @floatFromInt(z));
    if (z <= 2) {
        return atomic_num - 0.30 * (atomic_num - 1.0);
    } else if (z <= 10) {
        return atomic_num - 2.0 * 0.85 - (atomic_num - 3.0) * 0.35;
    } else if (z <= 18) {
        return atomic_num - 2.0 - 8.0 * 0.85 - (atomic_num - 11.0) * 0.35;
    } else {
        return atomic_num - 10.0 - 8.0 * 0.85 - (atomic_num - 19.0) * 0.35;
    }
}

// ═══════════════════════════════════════════════════════════════
// PERIODIC TRENDS
// ═══════════════════════════════════════════════════════════════

pub const TrendDirection = enum {
    Increases,
    Decreases,
    Varies,
};

pub const PeriodicTrend = struct {
    property: []const u8,
    across_period: TrendDirection,
    down_group: TrendDirection,
    explanation: []const u8,
};

pub const periodic_trends = [_]PeriodicTrend{
    .{
        .property = "Atomic Radius",
        .across_period = .Decreases,
        .down_group = .Increases,
        .explanation = "Z_eff increases across period; more shells down group",
    },
    .{
        .property = "Ionization Energy",
        .across_period = .Increases,
        .down_group = .Decreases,
        .explanation = "Higher Z_eff across period; electrons farther down group",
    },
    .{
        .property = "Electronegativity",
        .across_period = .Increases,
        .down_group = .Decreases,
        .explanation = "Follows ionization energy trend",
    },
    .{
        .property = "Electron Affinity",
        .across_period = .Varies,
        .down_group = .Decreases,
        .explanation = "Generally increases across but with exceptions",
    },
    .{
        .property = "Metallic Character",
        .across_period = .Decreases,
        .down_group = .Increases,
        .explanation = "Metals lose electrons easily; easier down group",
    },
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "element lookup by atomic number" {
    const carbon = getByAtomicNumber(6).?;
    try std.testing.expectEqualStrings("C", carbon.symbol);
    try std.testing.expectEqualStrings("Carbon", carbon.name);
}

test "element lookup by symbol" {
    const oxygen = getBySymbol("O").?;
    try std.testing.expectEqual(@as(u8, 8), oxygen.atomic_number);
}

test "element properties" {
    const fluorine = getByAtomicNumber(9).?;
    try std.testing.expectApproxEqAbs(@as(f64, 3.98), fluorine.electronegativity, 0.01);
    try std.testing.expect(fluorine.category == .Halogen);
}

test "z effective calculation" {
    const sodium = getByAtomicNumber(11).?;
    const z_eff = sodium.zEffective();
    try std.testing.expect(z_eff > 1.0 and z_eff < 5.0);
}

test "atomic radius prediction" {
    const h_radius = predictAtomicRadius(1);
    try std.testing.expect(h_radius > 30 and h_radius < 80);
    
    const na_radius = predictAtomicRadius(11);
    try std.testing.expect(na_radius > h_radius); // Na should be larger
}

// ═══════════════════════════════════════════════════════════════
// MAIN - Demo output
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("{s}\n", .{
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║                    PERIODIC TABLE MODULE                                     ║
        \\║                    Integrated with Unified Theory                            ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
    });
    
    // Display first 20 elements
    try stdout.print("\n═══ ELEMENTS (Z=1-20) ═══\n\n", .{});
    try stdout.print("{s:<3} {s:<12} {s:>8} {s:>6} {s:>6} {s:>8} {s:>10}\n", .{
        "Z", "Name", "Mass", "Per", "Grp", "EN", "IE (kJ)",
    });
    try stdout.print("{s}\n", .{"-" ** 60});
    
    for (elements) |elem| {
        try stdout.print("{d:<3} {s:<12} {d:>8.3} {d:>6} {d:>6} {d:>8.2} {d:>10.1}\n", .{
            elem.atomic_number,
            elem.name,
            elem.atomic_mass,
            elem.period,
            elem.group,
            elem.electronegativity,
            elem.ionization_energy,
        });
    }
    
    // Periodic trends
    try stdout.print("\n═══ PERIODIC TRENDS ═══\n\n", .{});
    for (periodic_trends) |trend| {
        try stdout.print("{s}:\n", .{trend.property});
        try stdout.print("  Across period: {s}\n", .{@tagName(trend.across_period)});
        try stdout.print("  Down group: {s}\n", .{@tagName(trend.down_group)});
        try stdout.print("  Reason: {s}\n\n", .{trend.explanation});
    }
    
    // Predictions vs actual
    try stdout.print("═══ ATOMIC RADIUS PREDICTIONS ═══\n\n", .{});
    try stdout.print("{s:<4} {s:>12} {s:>12} {s:>10}\n", .{ "Elem", "Actual (pm)", "Predicted", "Error%" });
    try stdout.print("{s}\n", .{"-" ** 42});
    
    for (elements[0..10]) |elem| {
        const predicted = predictAtomicRadius(elem.atomic_number);
        const err = @abs(predicted - elem.atomic_radius) / elem.atomic_radius * 100.0;
        try stdout.print("{s:<4} {d:>12.0} {d:>12.1} {d:>9.1}%\n", .{
            elem.symbol, elem.atomic_radius, predicted, err,
        });
    }
    
    // Group analysis
    try stdout.print("\n═══ ALKALI METALS (Group 1) ═══\n\n", .{});
    for (elements) |elem| {
        if (elem.group == 1 and elem.category == .AlkaliMetal) {
            try stdout.print("{s}: IE={d:.1} kJ/mol, EN={d:.2}, r={d:.0} pm\n", .{
                elem.symbol, elem.ionization_energy, elem.electronegativity, elem.atomic_radius,
            });
        }
    }
    
    try stdout.print("\n═══ HALOGENS (Group 17) ═══\n\n", .{});
    for (elements) |elem| {
        if (elem.group == 17) {
            try stdout.print("{s}: IE={d:.1} kJ/mol, EN={d:.2}, EA={d:.1} kJ/mol\n", .{
                elem.symbol, elem.ionization_energy, elem.electronegativity, elem.electron_affinity,
            });
        }
    }
    
    try stdout.print("\n✅ Periodic table integration complete\n", .{});
}
