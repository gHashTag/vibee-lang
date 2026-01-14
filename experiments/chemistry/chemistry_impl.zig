// Chemistry Implementation via Creation Pattern
// Source: Reactants → Transformer: Reaction → Result: Products

const std = @import("std");
const print = std.debug.print;
const math = std.math;

// ============================================================================
// CHEMICAL CONSTANTS
// ============================================================================

const R: f64 = 8.314; // Gas constant J/(mol·K)
const AVOGADRO: f64 = 6.022e23; // Avogadro's number
const FARADAY: f64 = 96485.0; // Faraday constant C/mol

// ============================================================================
// ELEMENT DATA (Periodic Table)
// ============================================================================

const Element = struct {
    symbol: []const u8,
    name: []const u8,
    atomic_number: u8,
    atomic_mass: f64,
    electronegativity: f64,
    group: u8,
    period: u8,
};

const ELEMENTS = [_]Element{
    .{ .symbol = "H", .name = "Hydrogen", .atomic_number = 1, .atomic_mass = 1.008, .electronegativity = 2.20, .group = 1, .period = 1 },
    .{ .symbol = "He", .name = "Helium", .atomic_number = 2, .atomic_mass = 4.003, .electronegativity = 0.0, .group = 18, .period = 1 },
    .{ .symbol = "Li", .name = "Lithium", .atomic_number = 3, .atomic_mass = 6.941, .electronegativity = 0.98, .group = 1, .period = 2 },
    .{ .symbol = "Be", .name = "Beryllium", .atomic_number = 4, .atomic_mass = 9.012, .electronegativity = 1.57, .group = 2, .period = 2 },
    .{ .symbol = "B", .name = "Boron", .atomic_number = 5, .atomic_mass = 10.81, .electronegativity = 2.04, .group = 13, .period = 2 },
    .{ .symbol = "C", .name = "Carbon", .atomic_number = 6, .atomic_mass = 12.01, .electronegativity = 2.55, .group = 14, .period = 2 },
    .{ .symbol = "N", .name = "Nitrogen", .atomic_number = 7, .atomic_mass = 14.01, .electronegativity = 3.04, .group = 15, .period = 2 },
    .{ .symbol = "O", .name = "Oxygen", .atomic_number = 8, .atomic_mass = 16.00, .electronegativity = 3.44, .group = 16, .period = 2 },
    .{ .symbol = "F", .name = "Fluorine", .atomic_number = 9, .atomic_mass = 19.00, .electronegativity = 3.98, .group = 17, .period = 2 },
    .{ .symbol = "Ne", .name = "Neon", .atomic_number = 10, .atomic_mass = 20.18, .electronegativity = 0.0, .group = 18, .period = 2 },
    .{ .symbol = "Na", .name = "Sodium", .atomic_number = 11, .atomic_mass = 22.99, .electronegativity = 0.93, .group = 1, .period = 3 },
    .{ .symbol = "Mg", .name = "Magnesium", .atomic_number = 12, .atomic_mass = 24.31, .electronegativity = 1.31, .group = 2, .period = 3 },
    .{ .symbol = "Al", .name = "Aluminum", .atomic_number = 13, .atomic_mass = 26.98, .electronegativity = 1.61, .group = 13, .period = 3 },
    .{ .symbol = "Si", .name = "Silicon", .atomic_number = 14, .atomic_mass = 28.09, .electronegativity = 1.90, .group = 14, .period = 3 },
    .{ .symbol = "P", .name = "Phosphorus", .atomic_number = 15, .atomic_mass = 30.97, .electronegativity = 2.19, .group = 15, .period = 3 },
    .{ .symbol = "S", .name = "Sulfur", .atomic_number = 16, .atomic_mass = 32.07, .electronegativity = 2.58, .group = 16, .period = 3 },
    .{ .symbol = "Cl", .name = "Chlorine", .atomic_number = 17, .atomic_mass = 35.45, .electronegativity = 3.16, .group = 17, .period = 3 },
    .{ .symbol = "Ar", .name = "Argon", .atomic_number = 18, .atomic_mass = 39.95, .electronegativity = 0.0, .group = 18, .period = 3 },
    .{ .symbol = "K", .name = "Potassium", .atomic_number = 19, .atomic_mass = 39.10, .electronegativity = 0.82, .group = 1, .period = 4 },
    .{ .symbol = "Ca", .name = "Calcium", .atomic_number = 20, .atomic_mass = 40.08, .electronegativity = 1.00, .group = 2, .period = 4 },
    .{ .symbol = "Fe", .name = "Iron", .atomic_number = 26, .atomic_mass = 55.85, .electronegativity = 1.83, .group = 8, .period = 4 },
    .{ .symbol = "Cu", .name = "Copper", .atomic_number = 29, .atomic_mass = 63.55, .electronegativity = 1.90, .group = 11, .period = 4 },
    .{ .symbol = "Zn", .name = "Zinc", .atomic_number = 30, .atomic_mass = 65.38, .electronegativity = 1.65, .group = 12, .period = 4 },
    .{ .symbol = "Ag", .name = "Silver", .atomic_number = 47, .atomic_mass = 107.87, .electronegativity = 1.93, .group = 11, .period = 5 },
    .{ .symbol = "Au", .name = "Gold", .atomic_number = 79, .atomic_mass = 196.97, .electronegativity = 2.54, .group = 11, .period = 6 },
};

fn getElement(symbol: []const u8) ?Element {
    for (ELEMENTS) |e| {
        if (std.mem.eql(u8, e.symbol, symbol)) return e;
    }
    return null;
}

// ============================================================================
// CREATION PATTERN: CHEMICAL REACTIONS
// ============================================================================

// Reaction types (for documentation)
// synthesis, decomposition, single_replacement, double_replacement,
// combustion, acid_base, redox

// ============================================================================
// REACTION 1: WATER SYNTHESIS (Combustion of Hydrogen)
// Source: H₂ + O₂ → Transformer: Combustion → Result: H₂O
// ============================================================================

fn water_synthesis(h2_moles: f64, o2_moles: f64) struct {
    h2o_moles: f64,
    h2_remaining: f64,
    o2_remaining: f64,
    energy_released_kj: f64,
} {
    // 2H₂ + O₂ → 2H₂O, ΔH = -572 kJ
    const stoich_ratio = 2.0; // 2 mol H₂ per 1 mol O₂
    
    // Limiting reagent calculation
    const h2_needed = o2_moles * stoich_ratio;
    _ = h2_moles / stoich_ratio; // o2_needed (for reference)
    
    var h2o_produced: f64 = 0;
    var h2_left: f64 = 0;
    var o2_left: f64 = 0;
    
    if (h2_moles <= h2_needed) {
        // H₂ is limiting
        h2o_produced = h2_moles; // 2 mol H₂ → 2 mol H₂O
        h2_left = 0;
        o2_left = o2_moles - (h2_moles / stoich_ratio);
    } else {
        // O₂ is limiting
        h2o_produced = o2_moles * stoich_ratio;
        h2_left = h2_moles - h2_needed;
        o2_left = 0;
    }
    
    // Energy: -286 kJ per mol H₂O formed
    const energy = h2o_produced * 286.0;
    
    return .{
        .h2o_moles = h2o_produced,
        .h2_remaining = h2_left,
        .o2_remaining = o2_left,
        .energy_released_kj = energy,
    };
}

// ============================================================================
// REACTION 2: PHOTOSYNTHESIS
// Source: CO₂ + H₂O + Light → Transformer: Chloroplast → Result: C₆H₁₂O₆ + O₂
// ============================================================================

fn photosynthesis(co2_moles: f64, h2o_moles: f64) struct {
    glucose_moles: f64,
    o2_moles: f64,
    energy_stored_kj: f64,
    co2_remaining: f64,
    h2o_remaining: f64,
} {
    // 6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂, ΔG = +2870 kJ
    const co2_per_glucose = 6.0;
    const h2o_per_glucose = 6.0;
    
    // Limiting reagent
    const glucose_from_co2 = co2_moles / co2_per_glucose;
    const glucose_from_h2o = h2o_moles / h2o_per_glucose;
    const glucose_produced = @min(glucose_from_co2, glucose_from_h2o);
    
    const co2_used = glucose_produced * co2_per_glucose;
    const h2o_used = glucose_produced * h2o_per_glucose;
    const o2_produced = glucose_produced * 6.0;
    
    // Energy stored: 2870 kJ per mol glucose
    const energy = glucose_produced * 2870.0;
    
    return .{
        .glucose_moles = glucose_produced,
        .o2_moles = o2_produced,
        .energy_stored_kj = energy,
        .co2_remaining = co2_moles - co2_used,
        .h2o_remaining = h2o_moles - h2o_used,
    };
}

// ============================================================================
// REACTION 3: ACID-BASE NEUTRALIZATION
// Source: HCl + NaOH → Transformer: Neutralization → Result: NaCl + H₂O
// ============================================================================

fn acid_base_neutralization(hcl_moles: f64, naoh_moles: f64) struct {
    nacl_moles: f64,
    h2o_moles: f64,
    excess_acid: f64,
    excess_base: f64,
    final_ph: f64,
} {
    // HCl + NaOH → NaCl + H₂O (1:1 ratio)
    const salt_produced = @min(hcl_moles, naoh_moles);
    const water_produced = salt_produced;
    
    var excess_acid: f64 = 0;
    var excess_base: f64 = 0;
    var ph: f64 = 7.0;
    
    if (hcl_moles > naoh_moles) {
        excess_acid = hcl_moles - naoh_moles;
        // pH = -log[H⁺], assuming 1L solution
        ph = -@log10(excess_acid);
    } else if (naoh_moles > hcl_moles) {
        excess_base = naoh_moles - hcl_moles;
        // pOH = -log[OH⁻], pH = 14 - pOH
        const poh = -@log10(excess_base);
        ph = 14.0 - poh;
    }
    
    return .{
        .nacl_moles = salt_produced,
        .h2o_moles = water_produced,
        .excess_acid = excess_acid,
        .excess_base = excess_base,
        .final_ph = ph,
    };
}

// ============================================================================
// THERMODYNAMICS: GIBBS FREE ENERGY
// ============================================================================

fn calculate_delta_g(delta_h: f64, delta_s: f64, temperature_k: f64) f64 {
    // ΔG = ΔH - TΔS
    return delta_h - (temperature_k * delta_s / 1000.0); // Convert J to kJ
}

fn is_spontaneous(delta_g: f64) bool {
    return delta_g < 0;
}

fn calculate_equilibrium_constant(delta_g: f64, temperature_k: f64) f64 {
    // ΔG = -RT ln(K)
    // K = exp(-ΔG / RT)
    const exponent = -delta_g * 1000.0 / (R * temperature_k);
    return @exp(exponent);
}

// ============================================================================
// KINETICS: REACTION RATES
// ============================================================================

fn first_order_rate(k: f64, concentration: f64) f64 {
    // Rate = k[A]
    return k * concentration;
}

fn first_order_half_life(k: f64) f64 {
    // t½ = ln(2) / k
    return @log(2.0) / k;
}

fn second_order_rate(k: f64, concentration: f64) f64 {
    // Rate = k[A]²
    return k * concentration * concentration;
}

fn second_order_half_life(k: f64, initial_concentration: f64) f64 {
    // t½ = 1 / (k[A]₀)
    return 1.0 / (k * initial_concentration);
}

// Arrhenius equation: k = A × exp(-Ea / RT)
// Used for temperature dependence of rate constants

// ============================================================================
// PERIODIC TRENDS
// ============================================================================

// Periodic trend analysis functions (used in main)

// ============================================================================
// TESTS
// ============================================================================

test "water_synthesis: stoichiometric" {
    const result = water_synthesis(2.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result.h2o_moles, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 572.0), result.energy_released_kj, 1.0);
}

test "water_synthesis: excess_hydrogen" {
    const result = water_synthesis(4.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result.h2o_moles, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result.h2_remaining, 0.01);
}

test "water_synthesis: excess_oxygen" {
    const result = water_synthesis(2.0, 2.0);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result.h2o_moles, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.o2_remaining, 0.01);
}

test "photosynthesis: balanced" {
    const result = photosynthesis(6.0, 6.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.glucose_moles, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 6.0), result.o2_moles, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 2870.0), result.energy_stored_kj, 10.0);
}

test "acid_base: stoichiometric" {
    const result = acid_base_neutralization(1.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.nacl_moles, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 7.0), result.final_ph, 0.01);
}

test "acid_base: excess_acid" {
    const result = acid_base_neutralization(2.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.nacl_moles, 0.01);
    try std.testing.expect(result.final_ph < 7.0);
}

test "gibbs_free_energy: spontaneous" {
    // Exothermic reaction with positive entropy change
    const delta_g = calculate_delta_g(-100.0, 50.0, 298.0);
    try std.testing.expect(delta_g < 0);
    try std.testing.expect(is_spontaneous(delta_g));
}

test "equilibrium_constant" {
    // ΔG = -10 kJ/mol at 298 K
    const k = calculate_equilibrium_constant(-10.0, 298.0);
    try std.testing.expect(k > 1.0); // Favors products
}

test "first_order_kinetics" {
    const k = 0.1;
    const rate = first_order_rate(k, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1), rate, 0.001);
    
    const half_life = first_order_half_life(k);
    try std.testing.expectApproxEqAbs(@as(f64, 6.93), half_life, 0.01);
}

test "second_order_kinetics" {
    const k = 0.1;
    const rate = second_order_rate(k, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1), rate, 0.001);
    
    const half_life = second_order_half_life(k, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), half_life, 0.01);
}

test "periodic_trend: electronegativity" {
    // Period 2: Li, Be, B, C, N, O, F - should increase
    const li = getElement("Li").?;
    const f = getElement("F").?;
    try std.testing.expect(f.electronegativity > li.electronegativity);
    
    // F has highest electronegativity
    try std.testing.expectApproxEqAbs(@as(f64, 3.98), f.electronegativity, 0.01);
}

// ============================================================================
// MAIN: DEMONSTRATION
// ============================================================================

pub fn main() !void {
    print("=" ** 70 ++ "\n", .{});
    print("CHEMISTRY via CREATION PATTERN\n", .{});
    print("Source → Transformer → Result\n", .{});
    print("=" ** 70 ++ "\n", .{});

    // Reaction 1: Water Synthesis
    print("\n🔬 REACTION 1: Water Synthesis\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("Source: 2H₂ + O₂\n", .{});
    print("Transformer: Combustion (spark)\n", .{});
    print("Result: 2H₂O + Energy\n\n", .{});
    
    const water = water_synthesis(2.0, 1.0);
    print("Input: 2 mol H₂ + 1 mol O₂\n", .{});
    print("Output: {d:.2} mol H₂O\n", .{water.h2o_moles});
    print("Energy released: {d:.1} kJ\n", .{water.energy_released_kj});

    // Reaction 2: Photosynthesis
    print("\n🔬 REACTION 2: Photosynthesis\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("Source: 6CO₂ + 6H₂O + Light\n", .{});
    print("Transformer: Chloroplast enzymes\n", .{});
    print("Result: C₆H₁₂O₆ + 6O₂\n\n", .{});
    
    const photo = photosynthesis(6.0, 6.0);
    print("Input: 6 mol CO₂ + 6 mol H₂O\n", .{});
    print("Output: {d:.2} mol Glucose + {d:.2} mol O₂\n", .{ photo.glucose_moles, photo.o2_moles });
    print("Energy stored: {d:.1} kJ\n", .{photo.energy_stored_kj});

    // Reaction 3: Acid-Base
    print("\n🔬 REACTION 3: Acid-Base Neutralization\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("Source: HCl + NaOH\n", .{});
    print("Transformer: Proton transfer\n", .{});
    print("Result: NaCl + H₂O\n\n", .{});
    
    const neutral = acid_base_neutralization(1.0, 1.0);
    print("Input: 1 mol HCl + 1 mol NaOH\n", .{});
    print("Output: {d:.2} mol NaCl + {d:.2} mol H₂O\n", .{ neutral.nacl_moles, neutral.h2o_moles });
    print("Final pH: {d:.1}\n", .{neutral.final_ph});

    // Thermodynamics
    print("\n🔬 THERMODYNAMICS\n", .{});
    print("-" ** 50 ++ "\n", .{});
    
    const delta_g = calculate_delta_g(-100.0, 50.0, 298.0);
    const k_eq = calculate_equilibrium_constant(delta_g, 298.0);
    print("ΔH = -100 kJ/mol, ΔS = 50 J/(mol·K), T = 298 K\n", .{});
    print("ΔG = {d:.2} kJ/mol\n", .{delta_g});
    print("Spontaneous: {s}\n", .{if (is_spontaneous(delta_g)) "YES ✅" else "NO ❌"});
    print("Equilibrium constant K = {d:.2}\n", .{k_eq});

    // Periodic Trends
    print("\n🔬 PERIODIC TRENDS\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("Electronegativity across Period 2:\n", .{});
    
    const period2 = [_][]const u8{ "Li", "Be", "B", "C", "N", "O", "F" };
    for (period2) |sym| {
        if (getElement(sym)) |e| {
            print("  {s}: {d:.2}\n", .{ e.symbol, e.electronegativity });
        }
    }
    print("Trend: INCREASING → (Creation Pattern: Atomic Structure → Electron Pull → Electronegativity)\n", .{});

    // Summary
    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("🔬 CREATION PATTERN IN CHEMISTRY - SUMMARY\n", .{});
    print("=" ** 70 ++ "\n", .{});
    print(
        \\
        \\All chemical reactions follow: Source → Transformer → Result
        \\
        \\| Reaction Type    | Source           | Transformer      | Result           |
        \\|------------------|------------------|------------------|------------------|
        \\| Synthesis        | A + B            | Bond formation   | AB               |
        \\| Decomposition    | AB               | Bond breaking    | A + B            |
        \\| Combustion       | Fuel + O₂        | Oxidation        | CO₂ + H₂O        |
        \\| Acid-Base        | H⁺ + OH⁻         | Proton transfer  | H₂O              |
        \\| Redox            | Oxidizer+Reducer | e⁻ transfer      | Products         |
        \\| Photosynthesis   | CO₂ + H₂O + hν   | Enzymes          | Glucose + O₂     |
        \\
        \\The Creation Pattern reveals:
        \\1. CONSERVATION: Mass and energy are conserved (Source ≈ Result)
        \\2. TRANSFORMATION: Bonds break and form (Transformer)
        \\3. EQUILIBRIUM: Reactions reach balance (ΔG = 0)
        \\4. KINETICS: Rate depends on activation energy
        \\
    , .{});
}
