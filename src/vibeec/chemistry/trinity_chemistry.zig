const std = @import("std");
const math = std.math;

/// ╔═══════════════════════════════════════════════════════════════════════════╗
/// ║                    TRINITY CHEMISTRY                                      ║
/// ║                                                                           ║
/// ║  Trinity Sort principles applied to chemistry:                            ║
/// ║                                                                           ║
/// ║  1. 3-WAY PARTITION → Anion / Neutral / Cation                           ║
/// ║  2. GOLDEN RATIO φ  → Optimal bond angles, DNA spirals                   ║
/// ║  3. THRESHOLD 27    → Crystal systems, element clustering                ║
/// ║                                                                           ║
/// ║  "The same mathematics governs sorting and molecular organization"        ║
/// ╚═══════════════════════════════════════════════════════════════════════════╝

pub const PI: f64 = 3.14159265358979323846;
pub const PHI: f64 = 1.61803398874989484820; // Golden ratio
pub const PHI_ANGLE: f64 = 137.5077640500378; // Golden angle in degrees

// ═══════════════════════════════════════════════════════════════
// TRINITY CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const TRINITY: u8 = 3;
pub const TRINITY_SQUARED: u8 = 9;
pub const TRINITY_CUBED: u8 = 27;

/// Why these numbers appear everywhere:
pub const TrinityManifestations = struct {
    pub const spatial_dimensions: u8 = 3;
    pub const quark_colors: u8 = 3;
    pub const particle_generations: u8 = 3;
    pub const quarks_in_proton: u8 = 3;
    pub const states_of_matter: u8 = 3; // solid, liquid, gas
    pub const subatomic_particles: u8 = 3; // p, n, e
    
    // 3² = 9
    pub const planets_classical: u8 = 9;
    pub const muses: u8 = 9;
    
    // 3³ = 27
    pub const cubic_crystal_systems: u8 = 27; // 3×3×3 unit cells
    pub const optimal_sort_threshold: u8 = 27;
    pub const moon_days: u8 = 27; // sidereal month ≈ 27.3 days
};

// ═══════════════════════════════════════════════════════════════
// 3-WAY PARTITION FOR CHEMISTRY
// ═══════════════════════════════════════════════════════════════

pub const ChargeClass = enum {
    Anion,    // negative charge (< 0)
    Neutral,  // zero charge (= 0)
    Cation,   // positive charge (> 0)
    
    pub fn fromCharge(charge: i8) ChargeClass {
        if (charge < 0) return .Anion;
        if (charge > 0) return .Cation;
        return .Neutral;
    }
};

pub const ElectronegativityClass = enum {
    Electropositive, // metals, electron donors
    Intermediate,    // metalloids
    Electronegative, // non-metals, electron acceptors
    
    pub fn fromEN(en: f64) ElectronegativityClass {
        if (en < 1.8) return .Electropositive;
        if (en > 2.5) return .Electronegative;
        return .Intermediate;
    }
};

pub const ReactivityClass = enum {
    Inert,     // noble gases, stable molecules
    Moderate,  // most compounds
    Reactive,  // radicals, unstable species
    
    pub fn fromReactivity(r: f64) ReactivityClass {
        if (r < 0.5) return .Inert;
        if (r > 2.0) return .Reactive;
        return .Moderate;
    }
};

/// 3-way partition of molecules by any property
pub fn trinityPartition(
    comptime T: type,
    items: []T,
    comptime classifier: fn (T) i8, // returns -1, 0, or +1
) struct { low: usize, high: usize } {
    if (items.len == 0) return .{ .low = 0, .high = 0 };
    
    var low: usize = 0;
    var mid: usize = 0;
    var high: usize = items.len - 1;
    
    while (mid <= high) {
        const class = classifier(items[mid]);
        if (class < 0) {
            std.mem.swap(T, &items[low], &items[mid]);
            low += 1;
            mid += 1;
        } else if (class > 0) {
            std.mem.swap(T, &items[mid], &items[high]);
            if (high == 0) break;
            high -= 1;
        } else {
            mid += 1;
        }
    }
    
    return .{ .low = low, .high = high + 1 };
}

// ═══════════════════════════════════════════════════════════════
// GOLDEN RATIO IN CHEMISTRY
// ═══════════════════════════════════════════════════════════════

/// Golden angle: 360° / φ² ≈ 137.5°
/// Appears in: phyllotaxis, DNA helix, protein folding
pub fn goldenAngle() f64 {
    return 360.0 / (PHI * PHI);
}

/// Fibonacci angles in molecular geometry
pub const FibonacciAngles = struct {
    /// DNA helix: 36° per base pair (360°/10 ≈ golden subdivision)
    pub const dna_twist: f64 = 36.0;
    
    /// Alpha helix: 100° per residue (close to 360°/φ²)
    pub const alpha_helix: f64 = 100.0;
    
    /// Icosahedral symmetry (viruses): 72° = 360°/5
    pub const icosahedral: f64 = 72.0;
    
    /// Check if angle is "golden" (related to φ)
    pub fn isGoldenAngle(angle: f64) bool {
        const golden = goldenAngle();
        const tolerance = 5.0;
        
        // Check direct match
        if (@abs(angle - golden) < tolerance) return true;
        
        // Check 360 - golden
        if (@abs(angle - (360.0 - golden)) < tolerance) return true;
        
        // Check subdivisions
        if (@abs(angle - golden / 2.0) < tolerance) return true;
        if (@abs(angle - golden / 3.0) < tolerance) return true;
        
        return false;
    }
};

/// Predict optimal bond angle using golden ratio
pub fn predictOptimalAngle(coordination_number: u8) f64 {
    return switch (coordination_number) {
        2 => 180.0,                          // Linear
        3 => 120.0,                          // Trigonal planar
        4 => 109.47,                         // Tetrahedral (arccos(-1/3))
        5 => 90.0,                           // Trigonal bipyramidal (equatorial)
        6 => 90.0,                           // Octahedral
        else => 360.0 / @as(f64, @floatFromInt(coordination_number)),
    };
}

/// Golden ratio in bond lengths
/// Longer bond / shorter bond often ≈ φ in conjugated systems
pub fn goldenBondRatio(short_bond: f64, long_bond: f64) f64 {
    return long_bond / short_bond;
}

pub fn isGoldenRatio(ratio: f64) bool {
    return @abs(ratio - PHI) < 0.1 or @abs(ratio - 1.0 / PHI) < 0.1;
}

// ═══════════════════════════════════════════════════════════════
// THRESHOLD 27 = 3³ IN CHEMISTRY
// ═══════════════════════════════════════════════════════════════

/// Element clustering by atomic number
/// First 27 elements form the "core" of chemistry
pub const ElementCluster = enum {
    Light,      // Z = 1-9 (H to F) - main organic elements
    Medium,     // Z = 10-18 (Ne to Ar) - second period + noble
    Transition, // Z = 19-27 (K to Co) - first transition metals
    Heavy,      // Z > 27 - heavier elements
    
    pub fn fromAtomicNumber(z: u8) ElementCluster {
        if (z <= 9) return .Light;
        if (z <= 18) return .Medium;
        if (z <= 27) return .Transition;
        return .Heavy;
    }
};

/// Why 27 is special in chemistry:
pub const Threshold27 = struct {
    /// First 27 elements contain all essential biological elements
    pub const biological_elements: [11]u8 = .{ 1, 6, 7, 8, 11, 12, 15, 16, 17, 19, 20 };
    // H, C, N, O, Na, Mg, P, S, Cl, K, Ca - all Z ≤ 27 except Fe(26), Co(27)
    
    /// 27 = 3³ cubic arrangements
    pub const cubic_unit_cells: u8 = 27;
    
    /// Cobalt (Z=27) is the heaviest essential trace element
    pub const cobalt_z: u8 = 27;
    
    /// Optimal cluster size for molecular dynamics
    pub const optimal_cluster: u8 = 27;
};

// ═══════════════════════════════════════════════════════════════
// TRINITY SORT FOR MOLECULAR SCREENING
// ═══════════════════════════════════════════════════════════════

pub const MoleculeData = struct {
    name: []const u8,
    molecular_weight: f64,
    logP: f64,           // lipophilicity
    charge: i8,
    reactivity: f64,
    
    pub fn chargeClass(self: MoleculeData) ChargeClass {
        return ChargeClass.fromCharge(self.charge);
    }
    
    pub fn lipophilicityClass(self: MoleculeData) i8 {
        if (self.logP < -1.0) return -1; // hydrophilic
        if (self.logP > 2.0) return 1;   // lipophilic
        return 0;                         // amphiphilic
    }
    
    pub fn sizeClass(self: MoleculeData) i8 {
        if (self.molecular_weight < 150) return -1; // small
        if (self.molecular_weight > 500) return 1;  // large
        return 0;                                    // medium (drug-like)
    }
};

/// Drug-likeness filter using Trinity partition
/// Lipinski's Rule of 5 simplified to Rule of 3
pub const DrugLikeness = struct {
    pub const MW_LOW: f64 = 150;
    pub const MW_HIGH: f64 = 500;
    pub const LOGP_LOW: f64 = -1.0;
    pub const LOGP_HIGH: f64 = 5.0;
    
    pub fn classify(mol: MoleculeData) enum { TooSmall, DrugLike, TooLarge } {
        if (mol.molecular_weight < MW_LOW) return .TooSmall;
        if (mol.molecular_weight > MW_HIGH) return .TooLarge;
        if (mol.logP < LOGP_LOW or mol.logP > LOGP_HIGH) return .TooLarge;
        return .DrugLike;
    }
};

// ═══════════════════════════════════════════════════════════════
// TRINITY REACTION CLASSIFICATION
// ═══════════════════════════════════════════════════════════════

pub const ReactionType = enum {
    Synthesis,      // A + B → AB (combination)
    Decomposition,  // AB → A + B (analysis)
    Exchange,       // AB + CD → AD + CB (metathesis)
    
    /// All reactions are one of these three types
    /// This is the chemical trinity
    pub fn classify(reactants: u8, products: u8) ReactionType {
        if (products < reactants) return .Synthesis;
        if (products > reactants) return .Decomposition;
        return .Exchange;
    }
};

/// Reaction energy classification
pub const ReactionEnergy = enum {
    Exothermic,   // ΔH < 0, releases energy
    Thermoneutral, // ΔH ≈ 0
    Endothermic,  // ΔH > 0, absorbs energy
    
    pub fn fromEnthalpy(dH: f64) ReactionEnergy {
        if (dH < -10.0) return .Exothermic;
        if (dH > 10.0) return .Endothermic;
        return .Thermoneutral;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "golden angle" {
    const angle = goldenAngle();
    try std.testing.expect(angle > 137.0 and angle < 138.0);
}

test "trinity partition" {
    var data = [_]i32{ -5, 3, 0, -2, 0, 7, -1, 0, 4 };
    
    const result = trinityPartition(i32, &data, struct {
        fn classify(x: i32) i8 {
            if (x < 0) return -1;
            if (x > 0) return 1;
            return 0;
        }
    }.classify);
    
    // Check negatives are first
    for (data[0..result.low]) |x| {
        try std.testing.expect(x < 0);
    }
    // Check zeros are in middle
    for (data[result.low..result.high]) |x| {
        try std.testing.expect(x == 0);
    }
    // Check positives are last
    for (data[result.high..]) |x| {
        try std.testing.expect(x > 0);
    }
}

test "element clustering" {
    try std.testing.expect(ElementCluster.fromAtomicNumber(6) == .Light);
    try std.testing.expect(ElementCluster.fromAtomicNumber(17) == .Medium);
    try std.testing.expect(ElementCluster.fromAtomicNumber(26) == .Transition);
    try std.testing.expect(ElementCluster.fromAtomicNumber(79) == .Heavy);
}

test "reaction classification" {
    try std.testing.expect(ReactionType.classify(2, 1) == .Synthesis);
    try std.testing.expect(ReactionType.classify(1, 2) == .Decomposition);
    try std.testing.expect(ReactionType.classify(2, 2) == .Exchange);
}

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("{s}\n", .{
        \\╔═══════════════════════════════════════════════════════════════════════════╗
        \\║                    TRINITY CHEMISTRY                                      ║
        \\║                                                                           ║
        \\║  Trinity Sort → Chemical Organization                                     ║
        \\╚═══════════════════════════════════════════════════════════════════════════╝
    });
    
    // 3-way partition
    try stdout.print("\n═══ 3-WAY PARTITION IN CHEMISTRY ═══\n\n", .{});
    try stdout.print("Algorithm              Chemistry\n", .{});
    try stdout.print("─────────────────────────────────────────────\n", .{});
    try stdout.print("[< pivot]              Anions (negative)\n", .{});
    try stdout.print("[= pivot]              Neutral molecules\n", .{});
    try stdout.print("[> pivot]              Cations (positive)\n", .{});
    try stdout.print("\nAlso applies to:\n", .{});
    try stdout.print("  • Electronegativity: donors / metalloids / acceptors\n", .{});
    try stdout.print("  • Reactivity: inert / moderate / reactive\n", .{});
    try stdout.print("  • Size: small / drug-like / large\n", .{});
    
    // Golden ratio
    try stdout.print("\n═══ GOLDEN RATIO φ = {d:.6} ═══\n\n", .{PHI});
    try stdout.print("Golden angle: {d:.2}°\n\n", .{goldenAngle()});
    try stdout.print("Appearances in chemistry:\n", .{});
    try stdout.print("  • DNA helix twist: {d:.1}° per base pair\n", .{FibonacciAngles.dna_twist});
    try stdout.print("  • Alpha helix: {d:.1}° per residue\n", .{FibonacciAngles.alpha_helix});
    try stdout.print("  • Icosahedral viruses: {d:.1}° symmetry\n", .{FibonacciAngles.icosahedral});
    try stdout.print("  • Phyllotaxis: {d:.2}° leaf arrangement\n", .{PHI_ANGLE});
    
    // Threshold 27
    try stdout.print("\n═══ THRESHOLD 27 = 3³ ═══\n\n", .{});
    try stdout.print("Why 27 is special:\n", .{});
    try stdout.print("  • 3³ = 27 cubic unit cells in crystal\n", .{});
    try stdout.print("  • First 27 elements contain ALL biological essentials\n", .{});
    try stdout.print("  • Cobalt (Z=27) is heaviest essential trace element\n", .{});
    try stdout.print("  • Optimal cluster size for molecular dynamics\n", .{});
    try stdout.print("  • Optimal threshold for insertion sort\n", .{});
    
    // Element clusters
    try stdout.print("\n═══ ELEMENT CLUSTERING BY 27 ═══\n\n", .{});
    try stdout.print("Cluster       Z range    Examples\n", .{});
    try stdout.print("─────────────────────────────────────────────\n", .{});
    try stdout.print("Light         1-9        H, C, N, O, F (organic)\n", .{});
    try stdout.print("Medium        10-18      Ne, Na, Mg, Si, Cl, Ar\n", .{});
    try stdout.print("Transition    19-27      K, Ca, Fe, Co (bio-metals)\n", .{});
    try stdout.print("Heavy         >27        Cu, Zn, Br, I, Au, Pb\n", .{});
    
    // Reaction trinity
    try stdout.print("\n═══ REACTION TRINITY ═══\n\n", .{});
    try stdout.print("ALL chemical reactions are ONE of THREE types:\n\n", .{});
    try stdout.print("1. SYNTHESIS:      A + B → AB\n", .{});
    try stdout.print("   (combination, building up)\n\n", .{});
    try stdout.print("2. DECOMPOSITION:  AB → A + B\n", .{});
    try stdout.print("   (analysis, breaking down)\n\n", .{});
    try stdout.print("3. EXCHANGE:       AB + CD → AD + CB\n", .{});
    try stdout.print("   (metathesis, rearrangement)\n", .{});
    
    // Drug screening example
    try stdout.print("\n═══ DRUG SCREENING WITH TRINITY SORT ═══\n\n", .{});
    try stdout.print("3-way partition by molecular weight:\n", .{});
    try stdout.print("  [< 150 Da]  → Too small, poor pharmacokinetics\n", .{});
    try stdout.print("  [150-500]   → Drug-like (Lipinski compliant)\n", .{});
    try stdout.print("  [> 500 Da]  → Too large, poor absorption\n\n", .{});
    try stdout.print("Complexity: O(n log k) where k = 3 classes\n", .{});
    try stdout.print("           = O(n log 3) = O(n × 1.58) ≈ O(n)\n", .{});
    
    // Summary
    try stdout.print("\n═══ UNIFIED PRINCIPLE ═══\n\n", .{});
    try stdout.print("Trinity Sort is optimal because:\n", .{});
    try stdout.print("  • 3 is the minimal stable partition\n", .{});
    try stdout.print("  • φ gives balanced subdivisions\n", .{});
    try stdout.print("  • 27 = 3³ is the natural threshold\n\n", .{});
    try stdout.print("Chemistry follows the same rules because:\n", .{});
    try stdout.print("  • 3 particle types (p, n, e)\n", .{});
    try stdout.print("  • 3 charge states (-, 0, +)\n", .{});
    try stdout.print("  • 3 reaction types\n", .{});
    try stdout.print("  • φ in molecular geometry\n", .{});
    try stdout.print("  • 27 core elements\n", .{});
    
    try stdout.print("\n✅ Sorting algorithms and chemistry share the same mathematics.\n", .{});
}
