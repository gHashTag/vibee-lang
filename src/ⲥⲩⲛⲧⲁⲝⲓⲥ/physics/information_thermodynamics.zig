const std = @import("std");
const math = std.math;

/// Information Thermodynamics Module
/// 
/// Core insight: Information is physical. Computation has thermodynamic costs.
/// 
/// LANDAUER'S PRINCIPLE (1961):
///   Erasing 1 bit of information requires minimum energy: E = kT ln(2)
///   
/// IMPLICATIONS:
///   1. Information ≡ Physics (not abstract)
///   2. Computation ≡ Physics (has energy cost)
///   3. Optimal algorithms reflect physical laws
///   4. Reversible computation can be thermodynamically free
///   5. Entropy of computation = entropy of physics

pub const PI: f64 = 3.14159265358979323846;

// ═══════════════════════════════════════════════════════════════
// FUNDAMENTAL CONSTANTS
// ═══════════════════════════════════════════════════════════════

/// Boltzmann constant (J/K)
pub const k_B: f64 = 1.380649e-23;

/// Room temperature (K)
pub const T_room: f64 = 300.0;

/// Planck constant (J·s)
pub const h: f64 = 6.62607015e-34;

/// Speed of light (m/s)
pub const c: f64 = 299792458.0;

/// Planck time (s) - minimum meaningful time interval
pub const t_planck: f64 = 5.391247e-44;

/// Planck energy (J)
pub const E_planck: f64 = 1.956e9;

// ═══════════════════════════════════════════════════════════════
// LANDAUER'S PRINCIPLE
// ═══════════════════════════════════════════════════════════════

/// Minimum energy to erase one bit at temperature T
/// E_min = kT ln(2)
pub fn landauerEnergy(temperature: f64) f64 {
    return k_B * temperature * @log(2.0);
}

/// Energy to erase n bits
pub fn erasureEnergy(n_bits: u64, temperature: f64) f64 {
    return @as(f64, @floatFromInt(n_bits)) * landauerEnergy(temperature);
}

/// At room temperature (300K):
/// E_bit = 1.38e-23 × 300 × ln(2) ≈ 2.87e-21 J ≈ 0.018 eV
pub const E_bit_room: f64 = k_B * T_room * @log(2.0);

/// Bits that can be erased with 1 Joule at room temperature
pub const bits_per_joule_room: f64 = 1.0 / E_bit_room;

// ═══════════════════════════════════════════════════════════════
// COMPUTATIONAL COMPLEXITY ↔ PHYSICS
// ═══════════════════════════════════════════════════════════════

pub const ComplexityClass = enum {
    O_1,        // Constant - minimal entropy change
    O_log_n,    // Logarithmic - reversible-like
    O_n,        // Linear - proportional to input entropy
    O_n_log_n,  // Linearithmic - optimal sorting bound
    O_n2,       // Quadratic - pairwise interactions
    O_2n,       // Exponential - combinatorial explosion
    
    pub fn physicalInterpretation(self: ComplexityClass) []const u8 {
        return switch (self) {
            .O_1 => "No information destruction - constant entropy",
            .O_log_n => "Tree-like structure - minimal branching entropy",
            .O_n => "Linear scan - entropy proportional to system size",
            .O_n_log_n => "Optimal comparison sort - information-theoretic limit",
            .O_n2 => "All-pairs interaction - like gravitational N-body",
            .O_2n => "Explores all states - like partition function",
        };
    }
    
    pub fn minEnergyAtRoomTemp(self: ComplexityClass, n: u64) f64 {
        const n_f = @as(f64, @floatFromInt(n));
        const ops = switch (self) {
            .O_1 => 1.0,
            .O_log_n => @log2(n_f),
            .O_n => n_f,
            .O_n_log_n => n_f * @log2(n_f),
            .O_n2 => n_f * n_f,
            .O_2n => math.pow(f64, 2.0, n_f),
        };
        // Each irreversible operation erases ~1 bit
        return ops * E_bit_room;
    }
};

// ═══════════════════════════════════════════════════════════════
// REVERSIBLE vs IRREVERSIBLE COMPUTATION
// ═══════════════════════════════════════════════════════════════

pub const ComputationType = enum {
    Irreversible,  // AND, OR, NAND - destroys information
    Reversible,    // NOT, CNOT, Toffoli - preserves information
    
    pub fn energyCost(self: ComputationType, temperature: f64) f64 {
        return switch (self) {
            .Irreversible => landauerEnergy(temperature),
            .Reversible => 0.0, // Theoretically free!
        };
    }
};

/// Reversible gates preserve information (bijective)
pub const ReversibleGate = enum {
    NOT,      // 1 input, 1 output - trivially reversible
    CNOT,     // 2 inputs, 2 outputs - controlled NOT
    Toffoli,  // 3 inputs, 3 outputs - universal reversible
    Fredkin,  // 3 inputs, 3 outputs - controlled swap
    
    pub fn isUniversal(self: ReversibleGate) bool {
        return self == .Toffoli or self == .Fredkin;
    }
};

/// Irreversible gates destroy information
pub const IrreversibleGate = enum {
    AND,   // 2 inputs → 1 output (loses 1 bit)
    OR,    // 2 inputs → 1 output (loses 1 bit)
    NAND,  // 2 inputs → 1 output (loses 1 bit)
    XOR,   // 2 inputs → 1 output (loses 1 bit, but reversible with ancilla)
    
    pub fn bitsErased(self: IrreversibleGate) u8 {
        _ = self;
        return 1; // All 2→1 gates erase 1 bit
    }
};

// ═══════════════════════════════════════════════════════════════
// ALGORITHM ENTROPY
// ═══════════════════════════════════════════════════════════════

/// Shannon entropy of a probability distribution
pub fn shannonEntropy(probabilities: []const f64) f64 {
    var entropy: f64 = 0.0;
    for (probabilities) |p| {
        if (p > 0) {
            entropy -= p * @log2(p);
        }
    }
    return entropy;
}

/// Information content of a message (bits)
pub fn informationContent(probability: f64) f64 {
    if (probability <= 0) return 0;
    return -@log2(probability);
}

/// Minimum bits needed to represent n distinct states
pub fn minBitsForStates(n: u64) u64 {
    if (n <= 1) return 0;
    return @as(u64, @intFromFloat(@ceil(@log2(@as(f64, @floatFromInt(n))))));
}

/// Kolmogorov complexity lower bound: random data is incompressible
pub fn isLikelyRandom(data_bits: u64, compressed_bits: u64) bool {
    // If compression ratio < 1.1, data is likely random
    const ratio = @as(f64, @floatFromInt(data_bits)) / @as(f64, @floatFromInt(compressed_bits));
    return ratio < 1.1;
}

// ═══════════════════════════════════════════════════════════════
// PHYSICAL LIMITS OF COMPUTATION
// ═══════════════════════════════════════════════════════════════

pub const PhysicalLimits = struct {
    /// Bremermann's limit: max bits processed per second per gram
    /// ~1.36 × 10^50 bits/s/kg
    pub const bremermann_limit: f64 = 1.36e50;
    
    /// Bekenstein bound: max information in a region
    /// I ≤ 2πRE/(ℏc ln 2) bits
    pub fn bekensteinBound(radius_m: f64, energy_j: f64) f64 {
        const hbar = h / (2.0 * PI);
        return 2.0 * PI * radius_m * energy_j / (hbar * c * @log(2.0));
    }
    
    /// Margolus-Levitin theorem: max operations per second
    /// ν ≤ 2E/h operations/second
    pub fn margolusLevitinLimit(energy_j: f64) f64 {
        return 2.0 * energy_j / h;
    }
    
    /// Lloyd's ultimate laptop: 1kg, 1 liter
    /// ~10^51 ops/s, ~10^31 bits
    pub const lloyd_ops_per_sec: f64 = 5.4e50;
    pub const lloyd_memory_bits: f64 = 2.13e31;
};

// ═══════════════════════════════════════════════════════════════
// SORTING: INFORMATION-THEORETIC BOUND
// ═══════════════════════════════════════════════════════════════

/// Why is O(n log n) optimal for comparison sorting?
/// 
/// n! possible permutations → log₂(n!) bits of information
/// Each comparison reveals 1 bit → need log₂(n!) comparisons
/// Stirling: log₂(n!) ≈ n log₂(n) - n/ln(2)
/// 
/// This is a PHYSICAL law, not just mathematics!
pub fn sortingLowerBound(n: u64) f64 {
    if (n <= 1) return 0;
    const n_f = @as(f64, @floatFromInt(n));
    // log₂(n!) using Stirling approximation
    return n_f * @log2(n_f) - n_f / @log(2.0) + 0.5 * @log2(2.0 * PI * n_f);
}

/// Minimum energy for sorting n items at temperature T
pub fn sortingMinEnergy(n: u64, temperature: f64) f64 {
    const comparisons = sortingLowerBound(n);
    // Each comparison that discards a possibility erases information
    return comparisons * landauerEnergy(temperature);
}

// ═══════════════════════════════════════════════════════════════
// MAXWELL'S DEMON AND INFORMATION
// ═══════════════════════════════════════════════════════════════

/// Maxwell's Demon paradox resolution:
/// The demon must MEASURE particles (gain information)
/// To reset memory, must ERASE information
/// Erasure costs kT ln(2) per bit → no free lunch!

pub const MaxwellDemon = struct {
    memory_bits: u64,
    temperature: f64,
    
    pub fn init(memory_bits: u64, temperature: f64) MaxwellDemon {
        return .{ .memory_bits = memory_bits, .temperature = temperature };
    }
    
    /// Energy gained by sorting one particle
    pub fn energyGainedPerSort(self: MaxwellDemon) f64 {
        return k_B * self.temperature * @log(2.0);
    }
    
    /// Energy cost to erase memory after sorting
    pub fn memoryClearCost(self: MaxwellDemon) f64 {
        return erasureEnergy(self.memory_bits, self.temperature);
    }
    
    /// Net energy: always ≤ 0 (second law preserved)
    pub fn netEnergy(self: MaxwellDemon, particles_sorted: u64) f64 {
        const gained = @as(f64, @floatFromInt(particles_sorted)) * self.energyGainedPerSort();
        const cost = self.memoryClearCost();
        return gained - cost;
    }
};

// ═══════════════════════════════════════════════════════════════
// UNIFIED PATTERN: ALGORITHMS = PHYSICS
// ═══════════════════════════════════════════════════════════════

pub const AlgorithmPhysicsMapping = struct {
    algorithm: []const u8,
    physical_analog: []const u8,
    shared_principle: []const u8,
};

pub const mappings = [_]AlgorithmPhysicsMapping{
    .{
        .algorithm = "Binary Search",
        .physical_analog = "Bisection in phase space",
        .shared_principle = "Entropy halving per step",
    },
    .{
        .algorithm = "Merge Sort",
        .physical_analog = "Reversible mixing",
        .shared_principle = "Information-theoretic optimality",
    },
    .{
        .algorithm = "Hash Table",
        .physical_analog = "Ergodic distribution",
        .shared_principle = "Uniform entropy maximization",
    },
    .{
        .algorithm = "Dynamic Programming",
        .physical_analog = "Principle of least action",
        .shared_principle = "Optimal substructure",
    },
    .{
        .algorithm = "Gradient Descent",
        .physical_analog = "Thermodynamic relaxation",
        .shared_principle = "Energy minimization",
    },
    .{
        .algorithm = "Simulated Annealing",
        .physical_analog = "Actual annealing",
        .shared_principle = "Boltzmann distribution sampling",
    },
    .{
        .algorithm = "Quantum Computing",
        .physical_analog = "Quantum mechanics",
        .shared_principle = "Superposition and interference",
    },
    .{
        .algorithm = "Neural Networks",
        .physical_analog = "Spin glasses / Hopfield",
        .shared_principle = "Energy landscape optimization",
    },
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "landauer energy at room temperature" {
    const E = landauerEnergy(T_room);
    // Should be approximately 2.87e-21 J
    try std.testing.expect(E > 2.8e-21 and E < 3.0e-21);
}

test "bits per joule" {
    // At room temperature, ~3.5e20 bits can be erased per joule
    try std.testing.expect(bits_per_joule_room > 3e20 and bits_per_joule_room < 4e20);
}

test "shannon entropy" {
    // Fair coin: entropy = 1 bit
    const fair_coin = [_]f64{ 0.5, 0.5 };
    const entropy = shannonEntropy(&fair_coin);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), entropy, 0.001);
    
    // Certain outcome: entropy = 0
    const certain = [_]f64{ 1.0, 0.0 };
    const zero_entropy = shannonEntropy(&certain);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), zero_entropy, 0.001);
}

test "sorting lower bound" {
    // For n=8: log₂(8!) = log₂(40320) ≈ 15.3
    const bound = sortingLowerBound(8);
    try std.testing.expect(bound > 15 and bound < 16);
}

test "maxwell demon net energy" {
    const demon = MaxwellDemon.init(100, T_room);
    // Sorting 100 particles with 100 bits memory → net ≈ 0
    const net = demon.netEnergy(100);
    try std.testing.expect(net <= 0.0001); // Second law preserved
}

test "complexity energy scaling" {
    const n: u64 = 1000;
    const e_linear = ComplexityClass.O_n.minEnergyAtRoomTemp(n);
    const e_quadratic = ComplexityClass.O_n2.minEnergyAtRoomTemp(n);
    
    // Quadratic should be ~1000x more than linear
    const ratio = e_quadratic / e_linear;
    try std.testing.expect(ratio > 900 and ratio < 1100);
}

// ═══════════════════════════════════════════════════════════════
// MAIN - Demo output
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("{s}\n", .{
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║              INFORMATION THERMODYNAMICS                                      ║
        \\║              Algorithms = Physics                                            ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
    });
    
    // Landauer's Principle
    try stdout.print("\n═══ LANDAUER'S PRINCIPLE ═══\n\n", .{});
    try stdout.print("Minimum energy to erase 1 bit: E = kT ln(2)\n\n", .{});
    try stdout.print("At T = {d:.0} K (room temperature):\n", .{T_room});
    try stdout.print("  E_bit = {e:.3} J\n", .{E_bit_room});
    try stdout.print("  E_bit = {d:.4} eV\n", .{E_bit_room / 1.602e-19});
    try stdout.print("  Bits per Joule: {e:.2}\n", .{bits_per_joule_room});
    
    // Energy to erase different amounts
    try stdout.print("\n═══ ERASURE ENERGY EXAMPLES ═══\n\n", .{});
    const examples = [_]u64{ 1, 8, 64, 1024, 1_000_000, 1_000_000_000 };
    for (examples) |bits| {
        const energy = erasureEnergy(bits, T_room);
        try stdout.print("  {d:>12} bits: {e:.2} J\n", .{ bits, energy });
    }
    
    // Complexity classes
    try stdout.print("\n═══ COMPLEXITY ↔ PHYSICS ═══\n\n", .{});
    const n: u64 = 1000;
    try stdout.print("For n = {d} elements:\n\n", .{n});
    
    inline for (std.meta.fields(ComplexityClass)) |field| {
        const class = @field(ComplexityClass, field.name);
        const energy = class.minEnergyAtRoomTemp(n);
        try stdout.print("{s:<12}: {e:.2} J minimum\n", .{ field.name, energy });
        try stdout.print("             {s}\n\n", .{class.physicalInterpretation()});
    }
    
    // Sorting bound
    try stdout.print("═══ SORTING: PHYSICAL LAW ═══\n\n", .{});
    try stdout.print("Why O(n log n) is optimal:\n", .{});
    try stdout.print("  n! permutations → log₂(n!) bits of uncertainty\n", .{});
    try stdout.print("  Each comparison reveals 1 bit\n", .{});
    try stdout.print("  Therefore: minimum comparisons = log₂(n!)\n\n", .{});
    
    const sort_sizes = [_]u64{ 10, 100, 1000, 10000 };
    try stdout.print("{s:>8} {s:>15} {s:>15}\n", .{ "n", "Min comparisons", "Min energy (J)" });
    try stdout.print("{s}\n", .{"-" ** 42});
    for (sort_sizes) |sz| {
        const bound = sortingLowerBound(sz);
        const energy = sortingMinEnergy(sz, T_room);
        try stdout.print("{d:>8} {d:>15.1} {e:>15.2}\n", .{ sz, bound, energy });
    }
    
    // Maxwell's Demon
    try stdout.print("\n═══ MAXWELL'S DEMON RESOLVED ═══\n\n", .{});
    try stdout.print("The demon must:\n", .{});
    try stdout.print("  1. MEASURE particles (gain information)\n", .{});
    try stdout.print("  2. STORE measurements (use memory)\n", .{});
    try stdout.print("  3. ERASE memory to continue (pay Landauer cost)\n\n", .{});
    
    const demon = MaxwellDemon.init(1000, T_room);
    try stdout.print("Demon with 1000-bit memory at 300K:\n", .{});
    try stdout.print("  Energy gained per sort: {e:.3} J\n", .{demon.energyGainedPerSort()});
    try stdout.print("  Memory clear cost: {e:.3} J\n", .{demon.memoryClearCost()});
    try stdout.print("  Net after 1000 sorts: {e:.3} J ≤ 0 ✓\n", .{demon.netEnergy(1000)});
    
    // Algorithm-Physics mappings
    try stdout.print("\n═══ ALGORITHM ↔ PHYSICS MAPPINGS ═══\n\n", .{});
    for (mappings) |m| {
        try stdout.print("{s}\n", .{m.algorithm});
        try stdout.print("  ↔ {s}\n", .{m.physical_analog});
        try stdout.print("  Principle: {s}\n\n", .{m.shared_principle});
    }
    
    // Physical limits
    try stdout.print("═══ ULTIMATE PHYSICAL LIMITS ═══\n\n", .{});
    try stdout.print("Bremermann limit: {e:.2} bits/s/kg\n", .{PhysicalLimits.bremermann_limit});
    try stdout.print("Lloyd's ultimate laptop (1kg, 1L):\n", .{});
    try stdout.print("  Operations: {e:.2} ops/s\n", .{PhysicalLimits.lloyd_ops_per_sec});
    try stdout.print("  Memory: {e:.2} bits\n", .{PhysicalLimits.lloyd_memory_bits});
    
    const earth_mass: f64 = 5.97e24; // kg
    const earth_radius: f64 = 6.37e6; // m
    const earth_energy: f64 = earth_mass * c * c;
    const earth_bits = PhysicalLimits.bekensteinBound(earth_radius, earth_energy);
    try stdout.print("\nBekenstein bound for Earth: {e:.2} bits\n", .{earth_bits});
    
    try stdout.print("\n✅ Information IS physical. Computation IS physics.\n", .{});
}
