// ============================================================================
// MOLECULAR PROPERTY PREDICTOR
// Using unified theory patterns to predict molecular properties
// ============================================================================

const std = @import("std");
const math = std.math;
const unified = @import("unified_constants.zig");

// ============================================================================
// MOLECULAR ORBITAL THEORY
// ============================================================================

/// Bond order = (bonding electrons - antibonding electrons) / 2
pub fn bondOrder(bonding: u32, antibonding: u32) f64 {
    return @as(f64, @floatFromInt(bonding - antibonding)) / 2.0;
}

/// Predict if molecule is stable (bond order > 0)
pub fn isStable(bonding: u32, antibonding: u32) bool {
    return bonding > antibonding;
}

/// Predict if molecule is paramagnetic (unpaired electrons)
pub fn isParamagnetic(unpaired_electrons: u32) bool {
    return unpaired_electrons > 0;
}

// ============================================================================
// VSEPR GEOMETRY PREDICTION
// ============================================================================

pub const MolecularGeometry = enum {
    Linear,           // 2 electron domains
    TrigonalPlanar,   // 3 electron domains
    Tetrahedral,      // 4 electron domains
    TrigonalBipyramidal, // 5 electron domains
    Octahedral,       // 6 electron domains
    Bent,             // 2 bonding + lone pairs
    TrigonalPyramidal, // 3 bonding + 1 lone pair
    Seesaw,           // 4 bonding + 1 lone pair
    TShape,           // 3 bonding + 2 lone pairs
    SquarePlanar,     // 4 bonding + 2 lone pairs
    SquarePyramidal,  // 5 bonding + 1 lone pair
};

/// Predict molecular geometry from electron domains
pub fn predictGeometry(bonding_pairs: u32, lone_pairs: u32) MolecularGeometry {
    const total = bonding_pairs + lone_pairs;
    
    return switch (total) {
        2 => .Linear,
        3 => switch (lone_pairs) {
            0 => .TrigonalPlanar,
            1 => .Bent,
            else => .Linear,
        },
        4 => switch (lone_pairs) {
            0 => .Tetrahedral,
            1 => .TrigonalPyramidal,
            2 => .Bent,
            else => .Linear,
        },
        5 => switch (lone_pairs) {
            0 => .TrigonalBipyramidal,
            1 => .Seesaw,
            2 => .TShape,
            else => .Linear,
        },
        6 => switch (lone_pairs) {
            0 => .Octahedral,
            1 => .SquarePyramidal,
            2 => .SquarePlanar,
            else => .Linear,
        },
        else => .Linear,
    };
}

/// Get bond angle for geometry
pub fn bondAngle(geometry: MolecularGeometry) f64 {
    return switch (geometry) {
        .Linear => 180.0,
        .TrigonalPlanar => 120.0,
        .Tetrahedral => 109.5,
        .TrigonalBipyramidal => 90.0, // axial-equatorial
        .Octahedral => 90.0,
        .Bent => 104.5, // approximate for water
        .TrigonalPyramidal => 107.0, // approximate for ammonia
        .Seesaw => 90.0,
        .TShape => 90.0,
        .SquarePlanar => 90.0,
        .SquarePyramidal => 90.0,
    };
}

// ============================================================================
// HYBRIDIZATION
// ============================================================================

pub const Hybridization = enum {
    sp,
    sp2,
    sp3,
    sp3d,
    sp3d2,
};

/// Predict hybridization from electron domains
pub fn predictHybridization(electron_domains: u32) Hybridization {
    return switch (electron_domains) {
        2 => .sp,
        3 => .sp2,
        4 => .sp3,
        5 => .sp3d,
        6 => .sp3d2,
        else => .sp3,
    };
}

// ============================================================================
// BOND LENGTH PREDICTION
// ============================================================================

/// Covalent radii (pm) for common elements
pub fn covalentRadius(Z: u32) f64 {
    return switch (Z) {
        1 => 31.0,   // H
        6 => 76.0,   // C
        7 => 71.0,   // N
        8 => 66.0,   // O
        9 => 57.0,   // F
        15 => 107.0, // P
        16 => 105.0, // S
        17 => 102.0, // Cl
        35 => 120.0, // Br
        53 => 139.0, // I
        else => 100.0,
    };
}

/// Predict bond length (pm)
pub fn predictBondLength(Z1: u32, Z2: u32, bond_order_val: f64) f64 {
    const r1 = covalentRadius(Z1);
    const r2 = covalentRadius(Z2);
    
    // Schomaker-Stevenson correction for electronegativity
    const chi1 = unified.electronegativityPauling(Z1);
    const chi2 = unified.electronegativityPauling(Z2);
    const correction = 9.0 * @abs(chi1 - chi2);
    
    // Bond order correction (shorter for multiple bonds)
    const bo_factor = 1.0 - 0.1 * (bond_order_val - 1.0);
    
    return (r1 + r2 - correction) * bo_factor;
}

// ============================================================================
// DIPOLE MOMENT PREDICTION
// ============================================================================

/// Estimate dipole moment (Debye) from electronegativity difference and bond length
pub fn predictDipoleMoment(Z1: u32, Z2: u32, bond_length_pm: f64) f64 {
    const chi1 = unified.electronegativityPauling(Z1);
    const chi2 = unified.electronegativityPauling(Z2);
    const delta_chi = @abs(chi1 - chi2);
    
    // Simplified model: μ ≈ δ × d × 4.8 (Debye)
    // where δ is partial charge and d is distance in Angstroms
    const d_angstrom = bond_length_pm / 100.0;
    const partial_charge = delta_chi / 4.0; // rough approximation
    
    return partial_charge * d_angstrom * 4.8;
}

// ============================================================================
// MOLECULAR PROPERTIES FROM UNIFIED THEORY
// ============================================================================

/// Apply n × 3^k × π^m pattern to molecular properties
pub const MolecularPattern = struct {
    property: []const u8,
    n: f64,
    k: i32,
    m: i32,
    
    pub fn calculate(self: MolecularPattern) f64 {
        return self.n * math.pow(f64, 3.0, @floatFromInt(self.k)) * math.pow(f64, unified.PI, @floatFromInt(self.m));
    }
};

/// Known molecular patterns
pub const MOLECULAR_PATTERNS = [_]MolecularPattern{
    // Water molecule angle: 104.5° ≈ π/3 × 100 = 104.7°
    .{ .property = "H2O bond angle", .n = 100.0 / 3.0, .k = 0, .m = 1 },
    
    // Methane bond angle: 109.5° ≈ 35π = 109.96°
    .{ .property = "CH4 bond angle", .n = 35.0, .k = 0, .m = 1 },
    
    // Benzene C-C bond length: 139 pm ≈ 44π = 138.2 pm
    .{ .property = "Benzene C-C (pm)", .n = 44.0, .k = 0, .m = 1 },
};

// ============================================================================
// COMMON MOLECULES
// ============================================================================

pub const Molecule = struct {
    formula: []const u8,
    name: []const u8,
    geometry: MolecularGeometry,
    bond_angle: f64,
    dipole_moment: f64, // Debye
    bond_length: f64,   // pm (primary bond)
};

pub const COMMON_MOLECULES = [_]Molecule{
    .{ .formula = "H2O", .name = "Water", .geometry = .Bent, .bond_angle = 104.5, .dipole_moment = 1.85, .bond_length = 96 },
    .{ .formula = "NH3", .name = "Ammonia", .geometry = .TrigonalPyramidal, .bond_angle = 107.0, .dipole_moment = 1.47, .bond_length = 101 },
    .{ .formula = "CH4", .name = "Methane", .geometry = .Tetrahedral, .bond_angle = 109.5, .dipole_moment = 0.0, .bond_length = 109 },
    .{ .formula = "CO2", .name = "Carbon dioxide", .geometry = .Linear, .bond_angle = 180.0, .dipole_moment = 0.0, .bond_length = 116 },
    .{ .formula = "HCl", .name = "Hydrogen chloride", .geometry = .Linear, .bond_angle = 180.0, .dipole_moment = 1.08, .bond_length = 127 },
    .{ .formula = "H2S", .name = "Hydrogen sulfide", .geometry = .Bent, .bond_angle = 92.1, .dipole_moment = 0.97, .bond_length = 134 },
    .{ .formula = "PH3", .name = "Phosphine", .geometry = .TrigonalPyramidal, .bond_angle = 93.5, .dipole_moment = 0.58, .bond_length = 142 },
    .{ .formula = "SF6", .name = "Sulfur hexafluoride", .geometry = .Octahedral, .bond_angle = 90.0, .dipole_moment = 0.0, .bond_length = 156 },
};

// ============================================================================
// REACTION PREDICTION
// ============================================================================

/// Predict reaction enthalpy from bond energies (kJ/mol)
/// ΔH = Σ(bonds broken) - Σ(bonds formed)
pub fn predictReactionEnthalpy(bonds_broken: []const f64, bonds_formed: []const f64) f64 {
    var broken_sum: f64 = 0;
    for (bonds_broken) |e| {
        broken_sum += e;
    }
    
    var formed_sum: f64 = 0;
    for (bonds_formed) |e| {
        formed_sum += e;
    }
    
    return broken_sum - formed_sum;
}

/// Common bond energies (kJ/mol)
pub fn bondEnergyTable(bond: []const u8) f64 {
    const bonds = std.StaticStringMap(f64).initComptime(.{
        .{ "H-H", 436.0 },
        .{ "C-H", 413.0 },
        .{ "C-C", 347.0 },
        .{ "C=C", 614.0 },
        .{ "C≡C", 839.0 },
        .{ "C-O", 358.0 },
        .{ "C=O", 799.0 },
        .{ "O-H", 463.0 },
        .{ "O=O", 498.0 },
        .{ "N-H", 391.0 },
        .{ "N≡N", 945.0 },
        .{ "H-Cl", 431.0 },
        .{ "H-Br", 366.0 },
        .{ "H-I", 298.0 },
        .{ "Cl-Cl", 242.0 },
        .{ "Br-Br", 193.0 },
        .{ "I-I", 151.0 },
    });
    
    return bonds.get(bond) orelse 0.0;
}

// ============================================================================
// MAIN
// ============================================================================

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    MOLECULAR PROPERTY PREDICTOR                             ║\n", .{});
    try stdout.print("║                    Using Unified Theory Patterns                            ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Show molecular patterns
    try stdout.print("═══ MOLECULAR PATTERNS (n × 3^k × π^m) ═══\n\n", .{});
    
    for (MOLECULAR_PATTERNS) |p| {
        try stdout.print("{s}:\n", .{p.property});
        try stdout.print("  Pattern: {d} × 3^{d} × π^{d}\n", .{p.n, p.k, p.m});
        try stdout.print("  Predicted: {d:.2}\n\n", .{p.calculate()});
    }

    // Show common molecules
    try stdout.print("═══ COMMON MOLECULES ═══\n\n", .{});
    
    for (COMMON_MOLECULES) |mol| {
        try stdout.print("{s} ({s}):\n", .{mol.formula, mol.name});
        try stdout.print("  Geometry: {s}\n", .{@tagName(mol.geometry)});
        try stdout.print("  Bond angle: {d:.1}°\n", .{mol.bond_angle});
        try stdout.print("  Dipole moment: {d:.2} D\n", .{mol.dipole_moment});
        try stdout.print("  Bond length: {d} pm\n\n", .{mol.bond_length});
    }

    // VSEPR predictions
    try stdout.print("═══ VSEPR GEOMETRY PREDICTIONS ═══\n\n", .{});
    
    const test_cases = [_]struct { bp: u32, lp: u32, example: []const u8 }{
        .{ .bp = 2, .lp = 0, .example = "CO2" },
        .{ .bp = 3, .lp = 0, .example = "BF3" },
        .{ .bp = 4, .lp = 0, .example = "CH4" },
        .{ .bp = 2, .lp = 2, .example = "H2O" },
        .{ .bp = 3, .lp = 1, .example = "NH3" },
        .{ .bp = 6, .lp = 0, .example = "SF6" },
    };
    
    for (test_cases) |tc| {
        const geom = predictGeometry(tc.bp, tc.lp);
        const angle = bondAngle(geom);
        const hybrid = predictHybridization(tc.bp + tc.lp);
        
        try stdout.print("{s} ({d} bonding, {d} lone pairs):\n", .{tc.example, tc.bp, tc.lp});
        try stdout.print("  Geometry: {s}\n", .{@tagName(geom)});
        try stdout.print("  Bond angle: {d:.1}°\n", .{angle});
        try stdout.print("  Hybridization: {s}\n\n", .{@tagName(hybrid)});
    }

    // Bond length predictions
    try stdout.print("═══ BOND LENGTH PREDICTIONS ═══\n\n", .{});
    
    const bond_tests = [_]struct { Z1: u32, Z2: u32, name: []const u8, actual: f64 }{
        .{ .Z1 = 1, .Z2 = 1, .name = "H-H", .actual = 74 },
        .{ .Z1 = 6, .Z2 = 6, .name = "C-C", .actual = 154 },
        .{ .Z1 = 6, .Z2 = 8, .name = "C-O", .actual = 143 },
        .{ .Z1 = 1, .Z2 = 17, .name = "H-Cl", .actual = 127 },
    };
    
    for (bond_tests) |bt| {
        const predicted = predictBondLength(bt.Z1, bt.Z2, 1.0);
        const err_pct = @abs(predicted - bt.actual) / bt.actual * 100.0;
        
        try stdout.print("{s}:\n", .{bt.name});
        try stdout.print("  Predicted: {d:.1} pm\n", .{predicted});
        try stdout.print("  Actual: {d:.1} pm\n", .{bt.actual});
        try stdout.print("  Error: {d:.1}%\n\n", .{err_pct});
    }

    // Reaction enthalpy example
    try stdout.print("═══ REACTION ENTHALPY EXAMPLE ═══\n\n", .{});
    try stdout.print("H2 + Cl2 → 2HCl\n", .{});
    
    const broken = [_]f64{ bondEnergyTable("H-H"), bondEnergyTable("Cl-Cl") };
    const formed = [_]f64{ bondEnergyTable("H-Cl"), bondEnergyTable("H-Cl") };
    const delta_H = predictReactionEnthalpy(&broken, &formed);
    
    try stdout.print("  Bonds broken: H-H ({d} kJ) + Cl-Cl ({d} kJ)\n", .{broken[0], broken[1]});
    try stdout.print("  Bonds formed: 2 × H-Cl ({d} kJ each)\n", .{formed[0]});
    try stdout.print("  ΔH = {d:.0} kJ/mol\n", .{delta_H});
    try stdout.print("  (Actual: -184 kJ/mol)\n", .{});

    try stdout.print("\n✅ Molecular predictions complete\n", .{});
}

// ============================================================================
// TESTS
// ============================================================================

test "bond order" {
    // O2: 8 bonding, 4 antibonding → bond order 2
    try std.testing.expectEqual(@as(f64, 2.0), bondOrder(8, 4));
    
    // N2: 8 bonding, 2 antibonding → bond order 3
    try std.testing.expectEqual(@as(f64, 3.0), bondOrder(8, 2));
}

test "geometry prediction" {
    try std.testing.expectEqual(MolecularGeometry.Linear, predictGeometry(2, 0));
    try std.testing.expectEqual(MolecularGeometry.Tetrahedral, predictGeometry(4, 0));
    try std.testing.expectEqual(MolecularGeometry.Bent, predictGeometry(2, 2));
    try std.testing.expectEqual(MolecularGeometry.TrigonalPyramidal, predictGeometry(3, 1));
}

test "hybridization prediction" {
    try std.testing.expectEqual(Hybridization.sp, predictHybridization(2));
    try std.testing.expectEqual(Hybridization.sp2, predictHybridization(3));
    try std.testing.expectEqual(Hybridization.sp3, predictHybridization(4));
}

test "bond energy table" {
    try std.testing.expectEqual(@as(f64, 436.0), bondEnergyTable("H-H"));
    try std.testing.expectEqual(@as(f64, 498.0), bondEnergyTable("O=O"));
}

test "reaction enthalpy" {
    // H2 + Cl2 → 2HCl
    const broken = [_]f64{ 436.0, 242.0 }; // H-H + Cl-Cl
    const formed = [_]f64{ 431.0, 431.0 }; // 2 × H-Cl
    const delta_H = predictReactionEnthalpy(&broken, &formed);
    
    // Should be exothermic (negative)
    try std.testing.expect(delta_H < 0);
}
