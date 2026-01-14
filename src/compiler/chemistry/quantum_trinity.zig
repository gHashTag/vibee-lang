const std = @import("std");
const math = std.math;

/// ╔═══════════════════════════════════════════════════════════════════════════╗
/// ║                    QUANTUM TRINITY                                        ║
/// ║                                                                           ║
/// ║  Why 3 is fundamental to quantum mechanics and chemistry                  ║
/// ║                                                                           ║
/// ║  "God made the integers, all else is the work of man" — Kronecker        ║
/// ║  "God made 3, all else follows" — Quantum Trinity                        ║
/// ╚═══════════════════════════════════════════════════════════════════════════╝

pub const PI: f64 = 3.14159265358979323846;
pub const HBAR: f64 = 1.054571817e-34; // Reduced Planck constant

// ═══════════════════════════════════════════════════════════════
// THE QUANTUM TRINITY: 3 EVERYWHERE
// ═══════════════════════════════════════════════════════════════

/// Level 1: QUARKS — The deepest level
pub const QuarkTrinity = struct {
    /// 3 colors in QCD (Quantum Chromodynamics)
    pub const Color = enum { Red, Green, Blue };
    
    /// 3 generations of quarks
    pub const Generation = enum {
        First,  // up, down
        Second, // charm, strange  
        Third,  // top, bottom
    };
    
    /// 3 quarks in a baryon (proton, neutron)
    pub const quarks_per_baryon: u8 = 3;
    
    /// Proton = uud (2 up + 1 down)
    pub const proton_quarks = [3][]const u8{ "up", "up", "down" };
    
    /// Neutron = udd (1 up + 2 down)
    pub const neutron_quarks = [3][]const u8{ "up", "down", "down" };
    
    /// Color confinement: only colorless (RGB) combinations exist
    /// This is why we see 3-quark baryons, not free quarks
    pub fn isColorless(colors: [3]Color) bool {
        var has_r = false;
        var has_g = false;
        var has_b = false;
        for (colors) |c| {
            switch (c) {
                .Red => has_r = true,
                .Green => has_g = true,
                .Blue => has_b = true,
            }
        }
        return has_r and has_g and has_b;
    }
};

/// Level 2: PARTICLES — Building blocks of atoms
pub const ParticleTrinity = struct {
    /// 3 particles in an atom
    pub const Particle = enum {
        Proton,   // positive charge, in nucleus
        Neutron,  // neutral, in nucleus
        Electron, // negative charge, in orbitals
    };
    
    /// 3 generations of leptons
    pub const Lepton = enum {
        Electron,    // e⁻, stable
        Muon,        // μ⁻, unstable
        Tau,         // τ⁻, unstable
    };
    
    /// 3 types of neutrinos
    pub const Neutrino = enum {
        ElectronNeutrino, // νₑ
        MuonNeutrino,     // νμ
        TauNeutrino,      // ντ
    };
    
    /// 3 fundamental forces in Standard Model (excluding gravity)
    pub const Force = enum {
        Electromagnetic, // photon
        WeakNuclear,     // W±, Z bosons
        StrongNuclear,   // gluons
    };
};

/// Level 3: QUANTUM NUMBERS — Electron states
pub const QuantumNumbers = struct {
    n: u8,  // principal: 1, 2, 3, ...
    l: u8,  // angular momentum: 0 to n-1
    m: i8,  // magnetic: -l to +l (2l+1 values)
    s: f64, // spin: +1/2 or -1/2
    
    /// Orbital names: s, p, d, f
    pub fn orbitalName(l: u8) []const u8 {
        return switch (l) {
            0 => "s",
            1 => "p",
            2 => "d",
            3 => "f",
            else => "?",
        };
    }
    
    /// Number of orbitals in subshell = 2l + 1
    /// For p orbitals (l=1): 3 orbitals (px, py, pz)
    pub fn orbitalsInSubshell(l: u8) u8 {
        return 2 * l + 1;
    }
    
    /// Maximum electrons in subshell = 2(2l + 1)
    pub fn maxElectronsInSubshell(l: u8) u8 {
        return 2 * orbitalsInSubshell(l);
    }
    
    /// p orbitals: 3 orbitals × 2 electrons = 6 electrons
    /// This is why period 2 has 8 elements (2 in s + 6 in p)
    pub const p_orbitals: u8 = 3;
    pub const p_electrons: u8 = 6;
    
    /// d orbitals: 5 orbitals (but 5 = 2×3 - 1, still related to 3)
    pub const d_orbitals: u8 = 5;
    
    /// f orbitals: 7 orbitals (7 = 2×3 + 1)
    pub const f_orbitals: u8 = 7;
};

// ═══════════════════════════════════════════════════════════════
// SPIN STATES AND CHEMICAL BONDING
// ═══════════════════════════════════════════════════════════════

/// Spin multiplicity: 2S + 1
pub const SpinState = enum {
    Singlet,  // S=0, multiplicity=1 (paired electrons)
    Doublet,  // S=1/2, multiplicity=2 (one unpaired)
    Triplet,  // S=1, multiplicity=3 (two unpaired, parallel)
    
    pub fn fromUnpairedElectrons(n: u8) SpinState {
        return switch (n) {
            0 => .Singlet,
            1 => .Doublet,
            2 => .Triplet,
            else => .Triplet, // higher multiplicities exist but rare
        };
    }
    
    pub fn multiplicity(self: SpinState) u8 {
        return switch (self) {
            .Singlet => 1,
            .Doublet => 2,
            .Triplet => 3,
        };
    }
};

/// Bond types based on electron pairing
pub const BondSpin = struct {
    /// Covalent bond: singlet state (electrons paired, opposite spins)
    pub fn isCovalent(spin: SpinState) bool {
        return spin == .Singlet;
    }
    
    /// Radical: doublet state (one unpaired electron)
    pub fn isRadical(spin: SpinState) bool {
        return spin == .Doublet;
    }
    
    /// Biradical/Triplet: two unpaired electrons (e.g., O₂ ground state)
    pub fn isTriplet(spin: SpinState) bool {
        return spin == .Triplet;
    }
    
    /// O₂ is triplet in ground state — this is why it's paramagnetic!
    pub const oxygen_ground_state: SpinState = .Triplet;
};

// ═══════════════════════════════════════════════════════════════
// 3D SPACE AND ORBITALS
// ═══════════════════════════════════════════════════════════════

/// Why 3 spatial dimensions?
pub const SpatialTrinity = struct {
    pub const dimensions: u8 = 3;
    
    /// p orbitals align with 3 axes
    pub const p_orbital_axes = [3][]const u8{ "px", "py", "pz" };
    
    /// Spherical harmonics Y_l^m
    /// For l=1 (p orbitals): m = -1, 0, +1 → 3 orbitals
    pub fn sphericalHarmonics(l: u8) u8 {
        return 2 * l + 1;
    }
    
    /// Stable orbits only exist in 3D
    /// In 2D: orbits are unstable (no closed orbits)
    /// In 4D+: orbits are unstable (inverse cube law)
    /// 3D is special: inverse square law → stable ellipses
    pub fn isStableDimension(d: u8) bool {
        return d == 3;
    }
};

// ═══════════════════════════════════════════════════════════════
// SYMMETRY AND GROUP THEORY
// ═══════════════════════════════════════════════════════════════

/// SU(3) — The symmetry group of strong force
pub const SU3 = struct {
    /// 3×3 - 1 = 8 generators (Gell-Mann matrices)
    pub const generators: u8 = 8;
    
    /// 8 gluons mediate strong force
    pub const gluons: u8 = 8;
    
    /// Eightfold Way: hadrons organized by SU(3) flavor symmetry
    pub const eightfold_way: u8 = 8;
    
    /// 3 is the fundamental representation dimension
    pub const fundamental_dim: u8 = 3;
};

/// Point groups in molecular symmetry
pub const MolecularSymmetry = struct {
    /// C3 rotation: 120° = 360°/3
    pub const c3_angle: f64 = 120.0;
    
    /// D3h: trigonal planar (e.g., BF₃)
    /// Has C3 axis + 3 C2 axes + σh plane
    pub const d3h_c2_axes: u8 = 3;
    
    /// Td: tetrahedral (e.g., CH₄)
    /// Has 4 C3 axes (through vertices)
    pub const td_c3_axes: u8 = 4;
    
    /// Oh: octahedral (e.g., SF₆)
    /// Has 3 C4 axes, 4 C3 axes, 6 C2 axes
    pub const oh_c4_axes: u8 = 3;
};

// ═══════════════════════════════════════════════════════════════
// QUANTUM CHEMISTRY CALCULATIONS
// ═══════════════════════════════════════════════════════════════

/// Hydrogen atom energy levels
pub fn hydrogenEnergy(n: u8) f64 {
    // E_n = -13.6 eV / n²
    const n_f = @as(f64, @floatFromInt(n));
    return -13.6 / (n_f * n_f);
}

/// Orbital angular momentum
pub fn angularMomentum(l: u8) f64 {
    // L = √(l(l+1)) ℏ
    const l_f = @as(f64, @floatFromInt(l));
    return @sqrt(l_f * (l_f + 1.0)) * HBAR;
}

/// Magnetic quantum number range
pub fn magneticRange(l: u8) struct { min: i8, max: i8 } {
    const l_i: i8 = @intCast(l);
    return .{ .min = -l_i, .max = l_i };
}

/// Selection rules for transitions
pub const SelectionRules = struct {
    /// Δl = ±1 (angular momentum must change by 1)
    pub fn isAllowedTransition(l1: u8, l2: u8) bool {
        const diff = if (l1 > l2) l1 - l2 else l2 - l1;
        return diff == 1;
    }
    
    /// Δm = 0, ±1
    pub fn isAllowedMagnetic(m1: i8, m2: i8) bool {
        const diff = if (m1 > m2) m1 - m2 else m2 - m1;
        return diff <= 1;
    }
};

// ═══════════════════════════════════════════════════════════════
// THE DEEP CONNECTION
// ═══════════════════════════════════════════════════════════════

pub const DeepConnection = struct {
    level: []const u8,
    manifestation: []const u8,
    why_three: []const u8,
};

pub const connections = [_]DeepConnection{
    .{
        .level = "Quarks",
        .manifestation = "3 colors (RGB)",
        .why_three = "SU(3) gauge symmetry of strong force",
    },
    .{
        .level = "Quarks",
        .manifestation = "3 generations",
        .why_three = "Unknown — one of deepest mysteries",
    },
    .{
        .level = "Baryons",
        .manifestation = "3 quarks per baryon",
        .why_three = "Color confinement requires colorless states",
    },
    .{
        .level = "Atoms",
        .manifestation = "3 particle types",
        .why_three = "Charge conservation: +, 0, -",
    },
    .{
        .level = "Orbitals",
        .manifestation = "3 p orbitals",
        .why_three = "3 spatial dimensions (x, y, z)",
    },
    .{
        .level = "Spin",
        .manifestation = "Singlet/Doublet/Triplet",
        .why_three = "Spin-1/2 particles: 2S+1 states",
    },
    .{
        .level = "Space",
        .manifestation = "3 dimensions",
        .why_three = "Only dimension with stable orbits",
    },
    .{
        .level = "Forces",
        .manifestation = "3 gauge forces",
        .why_three = "Standard Model structure",
    },
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "color confinement" {
    const colorless = QuarkTrinity.isColorless(.{ .Red, .Green, .Blue });
    try std.testing.expect(colorless);
    
    const not_colorless = QuarkTrinity.isColorless(.{ .Red, .Red, .Blue });
    try std.testing.expect(!not_colorless);
}

test "p orbitals count" {
    const p_orbitals = QuantumNumbers.orbitalsInSubshell(1);
    try std.testing.expectEqual(@as(u8, 3), p_orbitals);
}

test "hydrogen energy" {
    const e1 = hydrogenEnergy(1);
    try std.testing.expect(e1 < -13.5 and e1 > -13.7);
    
    const e2 = hydrogenEnergy(2);
    try std.testing.expect(e2 > e1); // less negative = higher energy
}

test "spin multiplicity" {
    try std.testing.expectEqual(@as(u8, 1), SpinState.Singlet.multiplicity());
    try std.testing.expectEqual(@as(u8, 3), SpinState.Triplet.multiplicity());
}

test "selection rules" {
    try std.testing.expect(SelectionRules.isAllowedTransition(0, 1)); // s → p
    try std.testing.expect(SelectionRules.isAllowedTransition(1, 2)); // p → d
    try std.testing.expect(!SelectionRules.isAllowedTransition(0, 2)); // s → d forbidden
}

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("{s}\n", .{
        \\╔═══════════════════════════════════════════════════════════════════════════╗
        \\║                    QUANTUM TRINITY                                        ║
        \\║                                                                           ║
        \\║  Why 3 is fundamental to reality                                         ║
        \\╚═══════════════════════════════════════════════════════════════════════════╝
    });
    
    // Quarks
    try stdout.print("\n═══ LEVEL 1: QUARKS ═══\n\n", .{});
    try stdout.print("3 colors:      Red, Green, Blue (QCD)\n", .{});
    try stdout.print("3 generations: (u,d), (c,s), (t,b)\n", .{});
    try stdout.print("3 quarks:      per baryon (proton = uud)\n\n", .{});
    try stdout.print("WHY: SU(3) gauge symmetry requires 3 colors\n", .{});
    try stdout.print("     Color confinement → only RGB combinations exist\n", .{});
    
    // Particles
    try stdout.print("\n═══ LEVEL 2: PARTICLES ═══\n\n", .{});
    try stdout.print("3 particles:   proton, neutron, electron\n", .{});
    try stdout.print("3 leptons:     e⁻, μ⁻, τ⁻\n", .{});
    try stdout.print("3 neutrinos:   νₑ, νμ, ντ\n", .{});
    try stdout.print("3 forces:      EM, Weak, Strong\n\n", .{});
    try stdout.print("WHY: Charge conservation requires +, 0, -\n", .{});
    
    // Quantum numbers
    try stdout.print("\n═══ LEVEL 3: QUANTUM NUMBERS ═══\n\n", .{});
    try stdout.print("p orbitals:    3 (px, py, pz)\n", .{});
    try stdout.print("d orbitals:    5 = 2×3 - 1\n", .{});
    try stdout.print("f orbitals:    7 = 2×3 + 1\n\n", .{});
    try stdout.print("Formula: 2l + 1 orbitals per subshell\n", .{});
    try stdout.print("For l=1 (p): 2(1) + 1 = 3 orbitals\n", .{});
    
    // Spin states
    try stdout.print("\n═══ LEVEL 4: SPIN STATES ═══\n\n", .{});
    try stdout.print("Singlet (S=0):  Paired electrons, diamagnetic\n", .{});
    try stdout.print("Doublet (S=½):  One unpaired, radical\n", .{});
    try stdout.print("Triplet (S=1):  Two unpaired parallel, paramagnetic\n\n", .{});
    try stdout.print("O₂ ground state: TRIPLET (paramagnetic!)\n", .{});
    try stdout.print("This is why liquid O₂ is attracted to magnets.\n", .{});
    
    // 3D space
    try stdout.print("\n═══ LEVEL 5: SPACE ═══\n\n", .{});
    try stdout.print("3 dimensions: x, y, z\n\n", .{});
    try stdout.print("WHY 3 is special:\n", .{});
    try stdout.print("  • 2D: No stable orbits (no closed paths)\n", .{});
    try stdout.print("  • 3D: Stable orbits (inverse square law)\n", .{});
    try stdout.print("  • 4D+: Unstable orbits (inverse cube+)\n\n", .{});
    try stdout.print("Only in 3D can atoms exist!\n", .{});
    
    // Symmetry
    try stdout.print("\n═══ LEVEL 6: SYMMETRY ═══\n\n", .{});
    try stdout.print("SU(3): 3×3 - 1 = 8 generators (gluons)\n", .{});
    try stdout.print("C3 rotation: 120° = 360°/3\n", .{});
    try stdout.print("Trigonal molecules: 3-fold symmetry\n", .{});
    
    // Deep connections
    try stdout.print("\n═══ THE DEEP CONNECTION ═══\n\n", .{});
    try stdout.print("{s:<12} {s:<25} {s}\n", .{ "Level", "Manifestation", "Why 3?" });
    try stdout.print("{s}\n", .{"-" ** 70});
    for (connections) |c| {
        try stdout.print("{s:<12} {s:<25} {s}\n", .{ c.level, c.manifestation, c.why_three });
    }
    
    // Hydrogen spectrum
    try stdout.print("\n═══ HYDROGEN ENERGY LEVELS ═══\n\n", .{});
    try stdout.print("n    Energy (eV)    Orbital\n", .{});
    try stdout.print("{s}\n", .{"-" ** 30});
    for (1..5) |n| {
        const e = hydrogenEnergy(@intCast(n));
        try stdout.print("{d}    {d:>10.2}    {s}\n", .{ n, e, if (n == 1) "1s" else if (n == 2) "2s,2p" else if (n == 3) "3s,3p,3d" else "..." });
    }
    
    // Conclusion
    try stdout.print("\n═══ CONCLUSION ═══\n\n", .{});
    try stdout.print("The number 3 appears at EVERY level of reality:\n\n", .{});
    try stdout.print("  Quarks    → 3 colors, 3 generations, 3 per baryon\n", .{});
    try stdout.print("  Particles → 3 types (p, n, e)\n", .{});
    try stdout.print("  Orbitals  → 3 p orbitals (from 3D space)\n", .{});
    try stdout.print("  Spin      → 3 multiplicities (singlet/doublet/triplet)\n", .{});
    try stdout.print("  Space     → 3 dimensions (only stable option)\n", .{});
    try stdout.print("  Forces    → 3 gauge interactions\n\n", .{});
    try stdout.print("This is not coincidence. This is structure.\n", .{});
    
    try stdout.print("\n✅ 3 is woven into the fabric of quantum reality.\n", .{});
}
