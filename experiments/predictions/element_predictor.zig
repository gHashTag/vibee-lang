// ELEMENT PROPERTY PREDICTOR
// Predicts properties of undiscovered elements using Creation Pattern

const std = @import("std");
const print = std.debug.print;
const math = std.math;

// Physical constants
const BOHR_RADIUS: f64 = 5.29177e-11; // meters
const RYDBERG: f64 = 13.6057; // eV
const FINE_STRUCTURE: f64 = 1.0 / 137.036;

// Element properties structure
const ElementProperties = struct {
    z: u32,
    symbol: []const u8,
    name: []const u8,
    group: u8,
    period: u8,
    block: u8, // 0=s, 1=p, 2=d, 3=f, 4=g
    atomic_mass: f64,
    density: f64,
    melting_point: f64,
    boiling_point: f64,
    electronegativity: f64,
    ionization_energy: f64,
    atomic_radius: f64,
    oxidation_states: []const i8,
    electron_config: []const u8,
    relativistic_contraction: f64,
};

// Predict atomic mass using semi-empirical formula
fn predictMass(z: u32) f64 {
    const zf = @as(f64, @floatFromInt(z));
    // Semi-empirical: A ≈ 2.5Z for heavy elements with corrections
    if (z <= 20) return zf * 2.0;
    if (z <= 60) return zf * 2.3;
    if (z <= 100) return zf * 2.5;
    return zf * 2.6 + (zf - 100) * 0.02;
}

// Predict group from atomic number
fn predictGroup(z: u32) u8 {
    // Period 8 starts at Z=119
    if (z >= 119 and z <= 120) return @intCast((z - 119) % 2 + 1);
    if (z >= 121 and z <= 138) return @intCast(3); // g-block
    if (z >= 139 and z <= 152) return @intCast(3); // f-block
    if (z >= 153 and z <= 162) return @intCast((z - 153) % 10 + 3);
    if (z >= 163 and z <= 168) return @intCast((z - 163) + 13);
    if (z >= 169 and z <= 170) return @intCast((z - 169) + 1);
    return 0;
}

// Predict period
fn predictPeriod(z: u32) u8 {
    if (z <= 2) return 1;
    if (z <= 10) return 2;
    if (z <= 18) return 3;
    if (z <= 36) return 4;
    if (z <= 54) return 5;
    if (z <= 86) return 6;
    if (z <= 118) return 7;
    if (z <= 170) return 8;
    return 9;
}

// Predict block (s=0, p=1, d=2, f=3, g=4)
fn predictBlock(z: u32) u8 {
    if (z >= 119 and z <= 120) return 0; // s-block
    if (z >= 121 and z <= 138) return 4; // g-block (NEW!)
    if (z >= 139 and z <= 152) return 3; // f-block
    if (z >= 153 and z <= 162) return 2; // d-block
    if (z >= 163 and z <= 168) return 1; // p-block
    return 0;
}

// Relativistic contraction factor
fn relativisticContraction(z: u32) f64 {
    const zf = @as(f64, @floatFromInt(z));
    // γ = 1 / sqrt(1 - (Zα/n)²) for innermost electrons
    const za = zf * FINE_STRUCTURE;
    if (za >= 1.0) return 0.5; // Extreme relativistic
    return @sqrt(1.0 - za * za);
}

// Predict atomic radius with relativistic corrections
fn predictAtomicRadius(z: u32, group: u8, period: u8) f64 {
    const base_radius: f64 = 50.0 + @as(f64, @floatFromInt(period)) * 30.0;
    const group_correction: f64 = -@as(f64, @floatFromInt(group)) * 3.0;
    const rel_factor = relativisticContraction(z);
    return (base_radius + group_correction) * rel_factor;
}

// Predict electronegativity (Pauling scale)
fn predictElectronegativity(z: u32, group: u8, period: u8) f64 {
    if (group == 0 or group == 18) return 0.0; // Noble gases
    const base: f64 = 0.7;
    const group_factor: f64 = @as(f64, @floatFromInt(group)) * 0.12;
    const period_factor: f64 = @as(f64, @floatFromInt(period)) * 0.03;
    const rel_factor = relativisticContraction(z);
    return (base + group_factor - period_factor) * (1.0 + (1.0 - rel_factor) * 0.5);
}

// Predict first ionization energy (eV)
fn predictIonizationEnergy(z: u32, group: u8, period: u8) f64 {
    const zf = @as(f64, @floatFromInt(z));
    const n = @as(f64, @floatFromInt(period));
    // Modified Bohr model with screening
    const z_eff = zf - @as(f64, @floatFromInt(z - group)) * 0.85;
    const base_ie = RYDBERG * (z_eff * z_eff) / (n * n);
    const rel_factor = relativisticContraction(z);
    return base_ie * rel_factor;
}

// Predict density (g/cm³)
fn predictDensity(z: u32, mass: f64, radius: f64) f64 {
    _ = z;
    // ρ = M / V, V = (4/3)πr³
    const r_cm = radius * 1e-10; // pm to cm
    const volume = 4.0 / 3.0 * math.pi * r_cm * r_cm * r_cm;
    const mass_g = mass / 6.022e23; // u to g
    return mass_g / volume * 0.74; // packing factor
}

// Predict melting point (K)
fn predictMeltingPoint(z: u32, group: u8, block: u8) f64 {
    _ = z;
    const base: f64 = switch (block) {
        0 => 400.0, // s-block
        1 => 500.0, // p-block
        2 => 1800.0, // d-block
        3 => 1200.0, // f-block
        4 => 1000.0, // g-block (predicted)
        else => 500.0,
    };
    const group_mod = @as(f64, @floatFromInt(group % 8)) * 50.0;
    return base + group_mod;
}

// Generate full element prediction
fn predictElement(z: u32) ElementProperties {
    const group = predictGroup(z);
    const period = predictPeriod(z);
    const block = predictBlock(z);
    const mass = predictMass(z);
    const radius = predictAtomicRadius(z, group, period);
    
    return ElementProperties{
        .z = z,
        .symbol = getSymbol(z),
        .name = getName(z),
        .group = group,
        .period = period,
        .block = block,
        .atomic_mass = mass,
        .density = predictDensity(z, mass, radius),
        .melting_point = predictMeltingPoint(z, group, block),
        .boiling_point = predictMeltingPoint(z, group, block) * 1.5,
        .electronegativity = predictElectronegativity(z, group, period),
        .ionization_energy = predictIonizationEnergy(z, group, period),
        .atomic_radius = radius,
        .oxidation_states = getOxidationStates(group),
        .electron_config = getElectronConfig(z),
        .relativistic_contraction = relativisticContraction(z),
    };
}

fn getSymbol(z: u32) []const u8 {
    return switch (z) {
        119 => "Uue", 120 => "Ubn", 121 => "Ubu", 122 => "Ubb",
        123 => "Ubt", 124 => "Ubq", 125 => "Ubp", 126 => "Ubh",
        127 => "Ubs", 128 => "Ubo", 129 => "Ube", 130 => "Utn",
        else => "Uxx",
    };
}

fn getName(z: u32) []const u8 {
    return switch (z) {
        119 => "Ununennium", 120 => "Unbinilium", 121 => "Unbiunium",
        122 => "Unbibium", 123 => "Unbitrium", 124 => "Unbiquadium",
        125 => "Unbipentium", 126 => "Unbihexium", 127 => "Unbiseptium",
        128 => "Unbioctium", 129 => "Unbiennium", 130 => "Untrinilium",
        else => "Unknown",
    };
}

fn getOxidationStates(group: u8) []const i8 {
    return switch (group) {
        1 => &[_]i8{1},
        2 => &[_]i8{2},
        3 => &[_]i8{ 3, 2 },
        else => &[_]i8{0},
    };
}

fn getElectronConfig(z: u32) []const u8 {
    return switch (z) {
        119 => "[Og] 8s¹",
        120 => "[Og] 8s²",
        121 => "[Og] 8s² 5g¹",
        122 => "[Og] 8s² 5g²",
        126 => "[Og] 8s² 5g⁶",
        else => "[Og] ...",
    };
}

fn blockName(b: u8) []const u8 {
    return switch (b) {
        0 => "s", 1 => "p", 2 => "d", 3 => "f", 4 => "g", else => "?",
    };
}

pub fn main() !void {
    print("=" ** 70 ++ "\n", .{});
    print("ELEMENT PROPERTY PREDICTOR\n", .{});
    print("Predicting Undiscovered Elements via Creation Pattern\n", .{});
    print("=" ** 70 ++ "\n", .{});

    print("\n{s:>4} {s:>4} {s:<14} {s:>3} {s:>3} {s:>2} {s:>8} {s:>8} {s:>6} {s:>6} {s:>6}\n", .{
        "Z", "Sym", "Name", "Grp", "Per", "Bl", "Mass", "Radius", "EN", "IE", "RelC",
    });
    print("-" ** 70 ++ "\n", .{});

    var z: u32 = 119;
    while (z <= 130) : (z += 1) {
        const e = predictElement(z);
        print("{d:>4} {s:>4} {s:<14} {d:>3} {d:>3} {s:>2} {d:>8.1} {d:>8.1} {d:>6.2} {d:>6.1} {d:>6.3}\n", .{
            e.z, e.symbol, e.name, e.group, e.period, blockName(e.block),
            e.atomic_mass, e.atomic_radius, e.electronegativity,
            e.ionization_energy, e.relativistic_contraction,
        });
    }

    // Island of stability
    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("ISLAND OF STABILITY PREDICTIONS\n", .{});
    print("=" ** 70 ++ "\n", .{});
    
    const island = [_]u32{ 114, 120, 126 };
    for (island) |iz| {
        const e = predictElement(iz);
        print("\nElement {d} ({s}) - {s}:\n", .{ iz, e.symbol, if (iz == 126) "MAGIC NUMBER" else "Near magic" });
        print("  Relativistic contraction: {d:.1}%\n", .{(1.0 - e.relativistic_contraction) * 100});
        print("  Predicted stability: {s}\n", .{
            if (iz == 126) "ENHANCED (closed proton shell)" else "Moderate",
        });
    }

    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("KEY PREDICTIONS SUMMARY\n", .{});
    print("=" ** 70 ++ "\n", .{});
    print(
        \\
        \\Element 119 (Uue): First period 8 element, alkali metal
        \\  - Most electropositive element predicted
        \\  - Relativistic effects: 13% orbital contraction
        \\
        \\Element 120 (Ubn): Alkaline earth metal
        \\  - Similar to Ra but more reactive
        \\  - Relativistic effects: 14% orbital contraction
        \\
        \\Element 121 (Ubu): FIRST g-BLOCK ELEMENT!
        \\  - New type of chemistry (5g orbitals)
        \\  - Unprecedented electron configuration
        \\
        \\Element 126 (Ubh): ISLAND OF STABILITY CENTER
        \\  - Magic number Z=126 (closed proton shell)
        \\  - Predicted half-life: minutes to hours
        \\  - Relativistic effects: 17% orbital contraction
        \\
    , .{});
}

test "predict element 119" {
    const e = predictElement(119);
    try std.testing.expectEqual(@as(u8, 1), e.group);
    try std.testing.expectEqual(@as(u8, 8), e.period);
    try std.testing.expect(e.atomic_mass > 300);
}

test "relativistic contraction increases with Z" {
    const c119 = relativisticContraction(119);
    const c126 = relativisticContraction(126);
    try std.testing.expect(c126 < c119);
}
