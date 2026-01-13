const std = @import("std");
const math = std.math;

// ============================================================================
// ADVANCED SUPERHEAVY ELEMENT PREDICTOR
// Based on: Bethe-Weizsäcker formula, Nuclear Shell Model, Dirac Equation
// ============================================================================

// Physical constants
const ALPHA: f64 = 1.0 / 137.035999084; // Fine structure constant
const M_PROTON: f64 = 938.272088; // MeV/c²
const M_NEUTRON: f64 = 939.565420; // MeV/c²
const M_ELECTRON: f64 = 0.51099895; // MeV/c²
const HBAR_C: f64 = 197.3269804; // MeV·fm
const R0: f64 = 1.25; // fm, nuclear radius parameter
const A_BOHR: f64 = 52917.72109; // pm, Bohr radius

// Bethe-Weizsäcker mass formula coefficients (MeV)
const A_V: f64 = 15.75; // Volume term
const A_S: f64 = 17.80; // Surface term
const A_C: f64 = 0.711; // Coulomb term
const A_A: f64 = 23.70; // Asymmetry term
const A_P: f64 = 11.18; // Pairing term

// Magic numbers for shell closures
const PROTON_MAGIC = [_]u16{ 2, 8, 20, 28, 50, 82, 114, 120, 126 };
const NEUTRON_MAGIC = [_]u16{ 2, 8, 20, 28, 50, 82, 126, 184 };

/// Bethe-Weizsäcker semi-empirical mass formula
/// Returns binding energy in MeV
pub fn bindingEnergy(z: u16, n: u16) f64 {
    const a: f64 = @floatFromInt(z + n); // Mass number
    const zf: f64 = @floatFromInt(z);
    const nf: f64 = @floatFromInt(n);

    if (a < 1) return 0;

    // Volume term (proportional to A)
    const e_volume = A_V * a;

    // Surface term (proportional to A^(2/3))
    const e_surface = -A_S * math.pow(f64, a, 2.0 / 3.0);

    // Coulomb term (proton repulsion)
    const e_coulomb = -A_C * zf * (zf - 1.0) / math.pow(f64, a, 1.0 / 3.0);

    // Asymmetry term (neutron-proton imbalance)
    const e_asymmetry = -A_A * math.pow(f64, nf - zf, 2.0) / a;

    // Pairing term
    var e_pairing: f64 = 0;
    const z_even = z % 2 == 0;
    const n_even = n % 2 == 0;
    if (z_even and n_even) {
        e_pairing = A_P / math.sqrt(a); // Even-even: more stable
    } else if (!z_even and !n_even) {
        e_pairing = -A_P / math.sqrt(a); // Odd-odd: less stable
    }

    // Shell correction (magic numbers)
    var e_shell: f64 = 0;
    for (PROTON_MAGIC) |magic| {
        if (z == magic) e_shell += 2.0; // MeV bonus for closed shell
    }
    for (NEUTRON_MAGIC) |magic| {
        if (n == magic) e_shell += 2.5; // MeV bonus for closed shell
    }

    return e_volume + e_surface + e_coulomb + e_asymmetry + e_pairing + e_shell;
}

/// Calculate atomic mass in atomic mass units (u)
pub fn atomicMass(z: u16, n: u16) f64 {
    const zf: f64 = @floatFromInt(z);
    const nf: f64 = @floatFromInt(n);

    // Mass = Z*m_p + N*m_n - B.E./c²
    const be = bindingEnergy(z, n);
    const mass_mev = zf * M_PROTON + nf * M_NEUTRON - be;

    // Convert MeV/c² to atomic mass units (1 u = 931.494 MeV/c²)
    return mass_mev / 931.494;
}

/// Relativistic contraction factor (Dirac equation)
/// Returns gamma factor for 1s electron
pub fn relativisticGamma(z: u16) f64 {
    const zf: f64 = @floatFromInt(z);
    const v_over_c = zf * ALPHA;

    if (v_over_c >= 0.999) {
        // Near Feynmanium limit, use approximation
        return 0.05;
    }

    // Lorentz factor: γ = 1/√(1 - v²/c²)
    // For bound electron: effective γ from Dirac equation
    const gamma_sq = 1.0 - v_over_c * v_over_c;
    if (gamma_sq <= 0) return 0.05;

    return math.sqrt(gamma_sq);
}

/// Relativistic contraction percentage
pub fn relativisticContraction(z: u16) f64 {
    return (1.0 - relativisticGamma(z)) * 100.0;
}

/// Predict atomic radius using relativistic correction
pub fn predictRadius(z: u16, period: u8, group: u8) f64 {
    // Base radius from periodic trends (pm)
    const period_f: f64 = @floatFromInt(period);
    const group_f: f64 = @floatFromInt(group);

    // Empirical formula based on known elements
    var base_radius: f64 = 0;

    if (group <= 2) {
        // s-block: larger radii
        base_radius = 80.0 + period_f * 35.0 - group_f * 10.0;
    } else if (group >= 13) {
        // p-block
        base_radius = 60.0 + period_f * 25.0 - (group_f - 12.0) * 8.0;
    } else {
        // d-block and f-block
        base_radius = 70.0 + period_f * 20.0;
    }

    // Apply relativistic contraction
    const gamma = relativisticGamma(z);
    return base_radius * gamma;
}

/// Predict ionization energy using relativistic correction
pub fn predictIonizationEnergy(z: u16, group: u8) f64 {
    const group_f: f64 = @floatFromInt(group);

    // Base IE from group trends (eV)
    var base_ie: f64 = 0;

    if (group == 1) {
        base_ie = 4.0; // Alkali metals
    } else if (group == 2) {
        base_ie = 5.5; // Alkaline earth
    } else if (group >= 13 and group <= 18) {
        base_ie = 5.0 + (group_f - 12.0) * 1.5; // p-block trend
    } else {
        base_ie = 6.0 + group_f * 0.3; // d-block
    }

    // Relativistic correction increases IE for heavy elements
    const gamma = relativisticGamma(z);
    if (gamma < 0.1) return base_ie * 3.0;
    return base_ie / gamma;
}

/// Predict electronegativity (Pauling scale)
pub fn predictElectronegativity(z: u16, group: u8) f64 {
    const group_f: f64 = @floatFromInt(group);

    // Base EN from group
    var base_en: f64 = 0;

    if (group == 1) {
        base_en = 0.8;
    } else if (group == 2) {
        base_en = 1.0;
    } else if (group >= 13) {
        base_en = 1.5 + (group_f - 12.0) * 0.3;
    } else {
        base_en = 1.3 + group_f * 0.1;
    }

    // Slight increase for heavy elements due to relativistic effects
    const zf: f64 = @floatFromInt(z);
    return base_en + (zf - 100.0) * 0.002;
}

/// Estimate half-life based on stability factors
pub fn estimateHalfLife(z: u16, n: u16) []const u8 {
    var stability_score: f64 = 0;

    // Check for magic numbers
    for (PROTON_MAGIC) |magic| {
        if (z == magic) stability_score += 3.0;
    }
    for (NEUTRON_MAGIC) |magic| {
        if (n == magic) stability_score += 4.0;
    }

    // Even-even bonus
    if (z % 2 == 0 and n % 2 == 0) {
        stability_score += 1.0;
    }

    // Optimal N/Z ratio
    const zf: f64 = @floatFromInt(z);
    const nf: f64 = @floatFromInt(n);
    const ratio = nf / zf;
    if (ratio > 1.4 and ratio < 1.6) {
        stability_score += 1.0;
    }

    // Convert score to half-life estimate
    if (stability_score >= 7.0) return "hours-days";
    if (stability_score >= 5.0) return "minutes";
    if (stability_score >= 3.0) return "seconds";
    if (stability_score >= 1.0) return "milliseconds";
    return "microseconds";
}

/// Predict most stable isotope for given Z
pub fn mostStableIsotope(z: u16) u16 {
    // Optimal N/Z ratio increases with Z
    const zf: f64 = @floatFromInt(z);

    // Empirical formula: N ≈ Z + 0.015*Z² for heavy elements
    const n_optimal = zf + 0.015 * zf * zf;

    // Round to nearest even number (even-even more stable)
    var n: u16 = @intFromFloat(n_optimal);
    if (n % 2 != 0) n += 1;

    // Check if near magic number
    for (NEUTRON_MAGIC) |magic| {
        const diff = if (n > magic) n - magic else magic - n;
        if (diff <= 4) {
            n = magic;
            break;
        }
    }

    return n;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║     ADVANCED SUPERHEAVY ELEMENT PREDICTOR                                   ║\n", .{});
    try stdout.print("║     Bethe-Weizsäcker + Shell Model + Dirac Equation                         ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Validate against known elements
    try stdout.print("=== VALIDATION AGAINST KNOWN ELEMENTS ===\n\n", .{});

    const known = [_]struct { z: u16, n: u16, name: []const u8, actual_mass: f64 }{
        .{ .z = 82, .n = 126, .name = "Pb-208", .actual_mass = 207.977 },
        .{ .z = 92, .n = 146, .name = "U-238", .actual_mass = 238.051 },
        .{ .z = 114, .n = 175, .name = "Fl-289", .actual_mass = 289.0 },
        .{ .z = 118, .n = 176, .name = "Og-294", .actual_mass = 294.0 },
    };

    for (known) |k| {
        const pred_mass = atomicMass(k.z, k.n);
        const error_pct = @abs(pred_mass - k.actual_mass) / k.actual_mass * 100.0;
        const be = bindingEnergy(k.z, k.n);
        const be_per_nucleon = be / @as(f64, @floatFromInt(k.z + k.n));

        try stdout.print("{s}:\n", .{k.name});
        try stdout.print("  Predicted mass: {d:.3} u, Actual: {d:.3} u, Error: {d:.2}%\n", .{ pred_mass, k.actual_mass, error_pct });
        try stdout.print("  Binding energy: {d:.1} MeV, B.E./A: {d:.2} MeV\n\n", .{ be, be_per_nucleon });
    }

    // Predict superheavy elements
    try stdout.print("=== SUPERHEAVY ELEMENT PREDICTIONS ===\n\n", .{});

    const predictions = [_]struct { z: u16, sym: []const u8, period: u8, group: u8 }{
        .{ .z = 119, .sym = "Uue", .period = 8, .group = 1 },
        .{ .z = 120, .sym = "Ubn", .period = 8, .group = 2 },
        .{ .z = 121, .sym = "Ubu", .period = 8, .group = 3 },
        .{ .z = 126, .sym = "Ubh", .period = 8, .group = 8 },
        .{ .z = 137, .sym = "Uts", .period = 8, .group = 19 },
        .{ .z = 164, .sym = "Uhq", .period = 8, .group = 14 },
    };

    for (predictions) |p| {
        const n = mostStableIsotope(p.z);
        const mass = atomicMass(p.z, n);
        const be = bindingEnergy(p.z, n);
        const radius = predictRadius(p.z, p.period, p.group);
        const ie = predictIonizationEnergy(p.z, p.group);
        const en = predictElectronegativity(p.z, p.group);
        const rel_c = relativisticContraction(p.z);
        const halflife = estimateHalfLife(p.z, n);

        try stdout.print("Z={d} {s} (most stable: A={d}):\n", .{ p.z, p.sym, p.z + n });
        try stdout.print("  Mass: {d:.1} u, B.E.: {d:.0} MeV\n", .{ mass, be });
        try stdout.print("  Radius: {d:.0} pm, IE: {d:.1} eV, EN: {d:.2}\n", .{ radius, ie, en });
        try stdout.print("  Relativistic contraction: {d:.1}%\n", .{rel_c});
        try stdout.print("  Estimated half-life: {s}\n\n", .{halflife});
    }

    // Island of stability analysis
    try stdout.print("=== ISLAND OF STABILITY ANALYSIS ===\n\n", .{});

    const island_candidates = [_]struct { z: u16, n: u16 }{
        .{ .z = 114, .n = 184 },
        .{ .z = 120, .n = 184 },
        .{ .z = 126, .n = 184 },
        .{ .z = 126, .n = 178 },
    };

    for (island_candidates) |c| {
        const be = bindingEnergy(c.z, c.n);
        const be_per_a = be / @as(f64, @floatFromInt(c.z + c.n));
        const halflife = estimateHalfLife(c.z, c.n);

        try stdout.print("Z={d}, N={d} (A={d}):\n", .{ c.z, c.n, c.z + c.n });
        try stdout.print("  B.E./A: {d:.3} MeV, Half-life: {s}\n\n", .{ be_per_a, halflife });
    }

    try stdout.print("✅ Advanced prediction complete\n", .{});
}

// Tests
test "binding energy positive for stable nuclei" {
    const be = bindingEnergy(82, 126); // Pb-208
    try std.testing.expect(be > 0);
}

test "mass prediction within 1% for Pb-208" {
    const pred = atomicMass(82, 126);
    const actual: f64 = 207.977;
    const error_pct = @abs(pred - actual) / actual * 100.0;
    try std.testing.expect(error_pct < 1.0);
}

test "relativistic contraction increases with Z" {
    const c79 = relativisticContraction(79);
    const c126 = relativisticContraction(126);
    try std.testing.expect(c126 > c79);
}

test "magic number Z=126 has enhanced stability" {
    const be_126 = bindingEnergy(126, 184);
    const be_125 = bindingEnergy(125, 184);
    // Z=126 should have higher binding energy due to shell closure
    try std.testing.expect(be_126 > be_125);
}

test "doubly magic nucleus most stable" {
    const halflife_126_184 = estimateHalfLife(126, 184);
    try std.testing.expect(std.mem.eql(u8, halflife_126_184, "hours-days"));
}
