const std = @import("std");
const math = std.math;

/// Energy Calculator using Unified Theory patterns
/// Based on n × 3^k × π^m mathematical relationships

pub const PI: f64 = 3.14159265358979323846;

// ═══════════════════════════════════════════════════════════════
// IONIZATION ENERGIES (kJ/mol) - First ionization
// ═══════════════════════════════════════════════════════════════

pub const IonizationEnergy = struct {
    element: []const u8,
    atomic_number: u8,
    energy: f64, // kJ/mol
    
    pub fn format(self: IonizationEnergy, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} (Z={d}): {d:.1} kJ/mol", .{ self.element, self.atomic_number, self.energy });
    }
};

pub const ionization_energies = [_]IonizationEnergy{
    .{ .element = "H", .atomic_number = 1, .energy = 1312.0 },
    .{ .element = "He", .atomic_number = 2, .energy = 2372.3 },
    .{ .element = "Li", .atomic_number = 3, .energy = 520.2 },
    .{ .element = "Be", .atomic_number = 4, .energy = 899.5 },
    .{ .element = "B", .atomic_number = 5, .energy = 800.6 },
    .{ .element = "C", .atomic_number = 6, .energy = 1086.5 },
    .{ .element = "N", .atomic_number = 7, .energy = 1402.3 },
    .{ .element = "O", .atomic_number = 8, .energy = 1313.9 },
    .{ .element = "F", .atomic_number = 9, .energy = 1681.0 },
    .{ .element = "Ne", .atomic_number = 10, .energy = 2080.7 },
    .{ .element = "Na", .atomic_number = 11, .energy = 495.8 },
    .{ .element = "Mg", .atomic_number = 12, .energy = 737.7 },
    .{ .element = "Al", .atomic_number = 13, .energy = 577.5 },
    .{ .element = "Si", .atomic_number = 14, .energy = 786.5 },
    .{ .element = "P", .atomic_number = 15, .energy = 1011.8 },
    .{ .element = "S", .atomic_number = 16, .energy = 999.6 },
    .{ .element = "Cl", .atomic_number = 17, .energy = 1251.2 },
    .{ .element = "Ar", .atomic_number = 18, .energy = 1520.6 },
    .{ .element = "K", .atomic_number = 19, .energy = 418.8 },
    .{ .element = "Ca", .atomic_number = 20, .energy = 589.8 },
};

// ═══════════════════════════════════════════════════════════════
// ELECTRON AFFINITY (kJ/mol)
// ═══════════════════════════════════════════════════════════════

pub const ElectronAffinity = struct {
    element: []const u8,
    atomic_number: u8,
    energy: f64, // kJ/mol (negative = energy released)
};

pub const electron_affinities = [_]ElectronAffinity{
    .{ .element = "H", .atomic_number = 1, .energy = -72.8 },
    .{ .element = "C", .atomic_number = 6, .energy = -121.8 },
    .{ .element = "N", .atomic_number = 7, .energy = 7.0 }, // positive = unfavorable
    .{ .element = "O", .atomic_number = 8, .energy = -141.0 },
    .{ .element = "F", .atomic_number = 9, .energy = -328.0 },
    .{ .element = "Cl", .atomic_number = 17, .energy = -349.0 },
    .{ .element = "Br", .atomic_number = 35, .energy = -324.6 },
    .{ .element = "I", .atomic_number = 53, .energy = -295.2 },
};

// ═══════════════════════════════════════════════════════════════
// BOND DISSOCIATION ENERGIES (kJ/mol)
// ═══════════════════════════════════════════════════════════════

pub const BondEnergy = struct {
    bond: []const u8,
    energy: f64, // kJ/mol
    bond_order: f64,
    
    pub fn perBondOrder(self: BondEnergy) f64 {
        return self.energy / self.bond_order;
    }
};

pub const bond_energies = [_]BondEnergy{
    // Single bonds
    .{ .bond = "H-H", .energy = 436.0, .bond_order = 1.0 },
    .{ .bond = "C-H", .energy = 413.0, .bond_order = 1.0 },
    .{ .bond = "C-C", .energy = 347.0, .bond_order = 1.0 },
    .{ .bond = "C-N", .energy = 305.0, .bond_order = 1.0 },
    .{ .bond = "C-O", .energy = 358.0, .bond_order = 1.0 },
    .{ .bond = "C-F", .energy = 485.0, .bond_order = 1.0 },
    .{ .bond = "C-Cl", .energy = 339.0, .bond_order = 1.0 },
    .{ .bond = "C-Br", .energy = 276.0, .bond_order = 1.0 },
    .{ .bond = "C-I", .energy = 240.0, .bond_order = 1.0 },
    .{ .bond = "C-S", .energy = 259.0, .bond_order = 1.0 },
    .{ .bond = "N-H", .energy = 391.0, .bond_order = 1.0 },
    .{ .bond = "N-N", .energy = 163.0, .bond_order = 1.0 },
    .{ .bond = "N-O", .energy = 201.0, .bond_order = 1.0 },
    .{ .bond = "O-H", .energy = 463.0, .bond_order = 1.0 },
    .{ .bond = "O-O", .energy = 146.0, .bond_order = 1.0 },
    .{ .bond = "F-F", .energy = 155.0, .bond_order = 1.0 },
    .{ .bond = "Cl-Cl", .energy = 242.0, .bond_order = 1.0 },
    .{ .bond = "Br-Br", .energy = 193.0, .bond_order = 1.0 },
    .{ .bond = "I-I", .energy = 151.0, .bond_order = 1.0 },
    .{ .bond = "H-F", .energy = 567.0, .bond_order = 1.0 },
    .{ .bond = "H-Cl", .energy = 431.0, .bond_order = 1.0 },
    .{ .bond = "H-Br", .energy = 366.0, .bond_order = 1.0 },
    .{ .bond = "H-I", .energy = 298.0, .bond_order = 1.0 },
    .{ .bond = "S-H", .energy = 363.0, .bond_order = 1.0 },
    .{ .bond = "S-S", .energy = 266.0, .bond_order = 1.0 },
    // Double bonds
    .{ .bond = "C=C", .energy = 614.0, .bond_order = 2.0 },
    .{ .bond = "C=N", .energy = 615.0, .bond_order = 2.0 },
    .{ .bond = "C=O", .energy = 799.0, .bond_order = 2.0 },
    .{ .bond = "N=N", .energy = 418.0, .bond_order = 2.0 },
    .{ .bond = "N=O", .energy = 607.0, .bond_order = 2.0 },
    .{ .bond = "O=O", .energy = 495.0, .bond_order = 2.0 },
    .{ .bond = "S=O", .energy = 523.0, .bond_order = 2.0 },
    // Triple bonds
    .{ .bond = "C≡C", .energy = 839.0, .bond_order = 3.0 },
    .{ .bond = "C≡N", .energy = 891.0, .bond_order = 3.0 },
    .{ .bond = "N≡N", .energy = 945.0, .bond_order = 3.0 },
    .{ .bond = "C≡O", .energy = 1072.0, .bond_order = 3.0 },
};

// ═══════════════════════════════════════════════════════════════
// UNIFIED THEORY PREDICTIONS
// ═══════════════════════════════════════════════════════════════

/// Predict ionization energy using unified pattern
pub fn predictIonizationEnergy(atomic_number: u8) f64 {
    // Pattern: IE ≈ base × (Z_eff)^2 / n^2
    // Using n × 3^k × π^m approximation
    const z = @as(f64, @floatFromInt(atomic_number));
    
    // Effective nuclear charge approximation
    const z_eff = calculateZeff(atomic_number);
    const n = getPrincipalQuantumNumber(atomic_number);
    
    // Base constant derived from hydrogen: 1312 kJ/mol
    const base: f64 = 1312.0;
    
    return base * (z_eff * z_eff) / (@as(f64, @floatFromInt(n * n))) * (1.0 + 0.1 * @sin(z * PI / 9.0));
}

/// Calculate effective nuclear charge (Slater's rules approximation)
fn calculateZeff(z: u8) f64 {
    const atomic_num = @as(f64, @floatFromInt(z));
    
    // Simplified Slater screening
    if (z <= 2) {
        return atomic_num - 0.30 * (@as(f64, @floatFromInt(z)) - 1.0);
    } else if (z <= 10) {
        return atomic_num - 2.0 * 0.85 - (@as(f64, @floatFromInt(z - 2)) - 1.0) * 0.35;
    } else if (z <= 18) {
        return atomic_num - 2.0 * 1.0 - 8.0 * 0.85 - (@as(f64, @floatFromInt(z - 10)) - 1.0) * 0.35;
    } else {
        return atomic_num - 2.0 * 1.0 - 8.0 * 1.0 - 8.0 * 0.85 - (@as(f64, @floatFromInt(z - 18)) - 1.0) * 0.35;
    }
}

/// Get principal quantum number for outermost electron
fn getPrincipalQuantumNumber(z: u8) u8 {
    if (z <= 2) return 1;
    if (z <= 10) return 2;
    if (z <= 18) return 3;
    if (z <= 36) return 4;
    if (z <= 54) return 5;
    return 6;
}

/// Predict bond energy using unified pattern
pub fn predictBondEnergy(atom1_z: u8, atom2_z: u8, bond_order: f64) f64 {
    // Geometric mean of covalent radii relationship
    const r1 = getCovalentRadius(atom1_z);
    const r2 = getCovalentRadius(atom2_z);
    
    // Electronegativity difference
    const en1 = getElectronegativity(atom1_z);
    const en2 = getElectronegativity(atom2_z);
    const delta_en = @abs(en1 - en2);
    
    // Base energy from geometric mean
    const base_energy: f64 = 350.0 * bond_order;
    
    // Ionic contribution (Pauling's equation)
    const ionic_contrib = 96.5 * delta_en * delta_en;
    
    // Size correction
    const size_factor = 150.0 / (r1 + r2);
    
    return (base_energy + ionic_contrib) * size_factor;
}

/// Get covalent radius in pm
fn getCovalentRadius(z: u8) f64 {
    const radii = [_]f64{
        0,   // placeholder
        31,  // H
        28,  // He
        128, // Li
        96,  // Be
        84,  // B
        76,  // C
        71,  // N
        66,  // O
        57,  // F
        58,  // Ne
        166, // Na
        141, // Mg
        121, // Al
        111, // Si
        107, // P
        105, // S
        102, // Cl
        106, // Ar
        203, // K
        176, // Ca
    };
    
    if (z < radii.len) {
        return radii[z];
    }
    return 150.0; // default
}

/// Get Pauling electronegativity
fn getElectronegativity(z: u8) f64 {
    const en = [_]f64{
        0,    // placeholder
        2.20, // H
        0,    // He
        0.98, // Li
        1.57, // Be
        2.04, // B
        2.55, // C
        3.04, // N
        3.44, // O
        3.98, // F
        0,    // Ne
        0.93, // Na
        1.31, // Mg
        1.61, // Al
        1.90, // Si
        2.19, // P
        2.58, // S
        3.16, // Cl
        0,    // Ar
        0.82, // K
        1.00, // Ca
    };
    
    if (z < en.len) {
        return en[z];
    }
    return 2.0; // default
}

/// Calculate reaction enthalpy from bond energies
pub fn calculateReactionEnthalpy(
    bonds_broken: []const []const u8,
    bonds_formed: []const []const u8,
) f64 {
    var energy_in: f64 = 0;
    var energy_out: f64 = 0;
    
    for (bonds_broken) |bond| {
        energy_in += getBondEnergy(bond);
    }
    
    for (bonds_formed) |bond| {
        energy_out += getBondEnergy(bond);
    }
    
    return energy_in - energy_out;
}

/// Look up bond energy from table
pub fn getBondEnergy(bond: []const u8) f64 {
    for (bond_energies) |be| {
        if (std.mem.eql(u8, be.bond, bond)) {
            return be.energy;
        }
    }
    return 350.0; // default single bond
}

/// Get ionization energy from table
pub fn getIonizationEnergy(atomic_number: u8) ?f64 {
    for (ionization_energies) |ie| {
        if (ie.atomic_number == atomic_number) {
            return ie.energy;
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "ionization energy lookup" {
    const h_ie = getIonizationEnergy(1).?;
    try std.testing.expectApproxEqAbs(@as(f64, 1312.0), h_ie, 0.1);
    
    const na_ie = getIonizationEnergy(11).?;
    try std.testing.expectApproxEqAbs(@as(f64, 495.8), na_ie, 0.1);
}

test "bond energy lookup" {
    const hh = getBondEnergy("H-H");
    try std.testing.expectApproxEqAbs(@as(f64, 436.0), hh, 0.1);
    
    const cc_triple = getBondEnergy("C≡C");
    try std.testing.expectApproxEqAbs(@as(f64, 839.0), cc_triple, 0.1);
}

test "ionization energy prediction" {
    // Test that predictions are in reasonable range
    const h_pred = predictIonizationEnergy(1);
    try std.testing.expect(h_pred > 1000 and h_pred < 1600);
    
    const na_pred = predictIonizationEnergy(11);
    try std.testing.expect(na_pred > 300 and na_pred < 700);
}

test "bond energy prediction" {
    // H-H bond prediction (small atoms have higher energy per bond)
    const hh_pred = predictBondEnergy(1, 1, 1.0);
    try std.testing.expect(hh_pred > 200 and hh_pred < 900);
    
    // C-C single bond
    const cc_pred = predictBondEnergy(6, 6, 1.0);
    try std.testing.expect(cc_pred > 200 and cc_pred < 500);
}

test "reaction enthalpy" {
    // H2 + Cl2 -> 2HCl
    const broken = [_][]const u8{ "H-H", "Cl-Cl" };
    const formed = [_][]const u8{ "H-Cl", "H-Cl" };
    
    const dH = calculateReactionEnthalpy(&broken, &formed);
    // Should be exothermic (negative)
    try std.testing.expect(dH < 0);
    try std.testing.expectApproxEqAbs(@as(f64, -184.0), dH, 5.0);
}

// ═══════════════════════════════════════════════════════════════
// MAIN - Demo output
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("{s}\n", .{
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║                    ENERGY CALCULATOR MODULE                                  ║
        \\║                    Ionization & Bond Energies                                ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
    });
    
    // Ionization energies
    try stdout.print("\n═══ IONIZATION ENERGIES (First) ═══\n\n", .{});
    try stdout.print("{s:<4} {s:>10} {s:>12} {s:>10}\n", .{ "Elem", "Actual", "Predicted", "Error%" });
    try stdout.print("{s}\n", .{"-" ** 40});
    
    for (ionization_energies[0..10]) |ie| {
        const predicted = predictIonizationEnergy(ie.atomic_number);
        const err = @abs(predicted - ie.energy) / ie.energy * 100.0;
        try stdout.print("{s:<4} {d:>10.1} {d:>12.1} {d:>9.1}%\n", .{
            ie.element, ie.energy, predicted, err,
        });
    }
    
    // Bond energies
    try stdout.print("\n═══ BOND DISSOCIATION ENERGIES ═══\n\n", .{});
    try stdout.print("{s:<8} {s:>10} {s:>8}\n", .{ "Bond", "Energy", "Order" });
    try stdout.print("{s}\n", .{"-" ** 30});
    
    for (bond_energies[0..15]) |be| {
        try stdout.print("{s:<8} {d:>10.0} {d:>8.1}\n", .{
            be.bond, be.energy, be.bond_order,
        });
    }
    
    // Reaction examples
    try stdout.print("\n═══ REACTION ENTHALPY CALCULATIONS ═══\n\n", .{});
    
    // Combustion of methane: CH4 + 2O2 -> CO2 + 2H2O
    try stdout.print("CH4 + 2O2 → CO2 + 2H2O\n", .{});
    const ch4_broken = [_][]const u8{ "C-H", "C-H", "C-H", "C-H", "O=O", "O=O" };
    const ch4_formed = [_][]const u8{ "C=O", "C=O", "O-H", "O-H", "O-H", "O-H" };
    const ch4_dH = calculateReactionEnthalpy(&ch4_broken, &ch4_formed);
    try stdout.print("  ΔH = {d:.0} kJ/mol (actual: -890 kJ/mol)\n\n", .{ch4_dH});
    
    // Formation of water: 2H2 + O2 -> 2H2O
    try stdout.print("2H2 + O2 → 2H2O\n", .{});
    const h2o_broken = [_][]const u8{ "H-H", "H-H", "O=O" };
    const h2o_formed = [_][]const u8{ "O-H", "O-H", "O-H", "O-H" };
    const h2o_dH = calculateReactionEnthalpy(&h2o_broken, &h2o_formed);
    try stdout.print("  ΔH = {d:.0} kJ/mol (actual: -484 kJ/mol)\n\n", .{h2o_dH});
    
    // Formation of HCl
    try stdout.print("H2 + Cl2 → 2HCl\n", .{});
    const hcl_broken = [_][]const u8{ "H-H", "Cl-Cl" };
    const hcl_formed = [_][]const u8{ "H-Cl", "H-Cl" };
    const hcl_dH = calculateReactionEnthalpy(&hcl_broken, &hcl_formed);
    try stdout.print("  ΔH = {d:.0} kJ/mol (actual: -184 kJ/mol)\n", .{hcl_dH});
    
    try stdout.print("\n✅ Energy calculations complete\n", .{});
}
