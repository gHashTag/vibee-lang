const std = @import("std");
const math = std.math;

/// Computational Physics Module
/// 
/// THESIS: Optimal algorithms are not arbitrary human inventions.
/// They are DISCOVERIES of physical laws governing information.
///
/// Evidence:
/// 1. O(n log n) sorting = information-theoretic limit
/// 2. FFT = exploits symmetry (like physics exploits symmetry)
/// 3. Quantum algorithms = use actual quantum physics
/// 4. P vs NP may be a physical law about the universe

pub const PI: f64 = 3.14159265358979323846;
pub const k_B: f64 = 1.380649e-23;
pub const h: f64 = 6.62607015e-34;
pub const c: f64 = 299792458.0;

// ═══════════════════════════════════════════════════════════════
// FUNDAMENTAL COMPUTATIONAL LIMITS
// ═══════════════════════════════════════════════════════════════

/// The universe as a computer (Lloyd, 2002)
pub const UniverseComputer = struct {
    /// Age of universe in seconds
    pub const age: f64 = 4.35e17;
    
    /// Total mass-energy (observable universe)
    pub const total_energy: f64 = 4e69; // Joules
    
    /// Maximum operations performed since Big Bang
    /// Using Margolus-Levitin: ν_max = 2E/h
    pub fn maxOperations() f64 {
        return 2.0 * total_energy * age / h;
    }
    
    /// Result: ~10^122 operations
    /// This is why we can't brute-force 2^256 (only ~10^77)
    pub const max_ops_estimate: f64 = 1e122;
    
    /// Bekenstein bound for observable universe
    pub const max_bits: f64 = 1e122;
};

/// Why certain problems are hard: physical interpretation
pub const HardnessPhysics = struct {
    pub const Interpretation = struct {
        problem_class: []const u8,
        physical_reason: []const u8,
        example: []const u8,
    };
    
    pub const interpretations = [_]Interpretation{
        .{
            .problem_class = "NP-complete",
            .physical_reason = "Requires exploring exponential configuration space - like finding ground state of spin glass",
            .example = "SAT, TSP, Graph Coloring",
        },
        .{
            .problem_class = "PSPACE",
            .physical_reason = "Requires tracking exponential history - like full quantum state evolution",
            .example = "QBF, Game trees",
        },
        .{
            .problem_class = "BQP",
            .physical_reason = "Exploits quantum superposition and interference - actual physics",
            .example = "Factoring (Shor), Search (Grover)",
        },
        .{
            .problem_class = "Undecidable",
            .physical_reason = "Would require infinite information - violates Bekenstein bound",
            .example = "Halting problem, Kolmogorov complexity",
        },
    };
};

// ═══════════════════════════════════════════════════════════════
// ALGORITHM OPTIMALITY = PHYSICAL LAW
// ═══════════════════════════════════════════════════════════════

pub const OptimalityProof = struct {
    algorithm: []const u8,
    complexity: []const u8,
    why_optimal: []const u8,
    physical_principle: []const u8,
};

pub const optimal_algorithms = [_]OptimalityProof{
    .{
        .algorithm = "Comparison Sort",
        .complexity = "O(n log n)",
        .why_optimal = "log₂(n!) comparisons needed to distinguish n! permutations",
        .physical_principle = "Information theory: each comparison yields 1 bit",
    },
    .{
        .algorithm = "Binary Search",
        .complexity = "O(log n)",
        .why_optimal = "Each comparison halves search space",
        .physical_principle = "Entropy reduction: H → H/2 per step",
    },
    .{
        .algorithm = "Matrix Multiplication",
        .complexity = "O(n^ω), ω ≈ 2.37",
        .why_optimal = "Unknown if optimal; Strassen showed < O(n³)",
        .physical_principle = "Tensor rank and algebraic complexity",
    },
    .{
        .algorithm = "FFT",
        .complexity = "O(n log n)",
        .why_optimal = "Exploits roots of unity symmetry",
        .physical_principle = "Group theory: cyclic group structure",
    },
    .{
        .algorithm = "Dijkstra (Fibonacci heap)",
        .complexity = "O(E + V log V)",
        .why_optimal = "Each edge relaxed once, priority queue optimal",
        .physical_principle = "Principle of optimality (Bellman)",
    },
    .{
        .algorithm = "Union-Find",
        .complexity = "O(α(n)) per operation",
        .why_optimal = "α(n) is inverse Ackermann - almost constant",
        .physical_principle = "Tree compression reaches equilibrium",
    },
};

// ═══════════════════════════════════════════════════════════════
// P vs NP: A PHYSICAL QUESTION?
// ═══════════════════════════════════════════════════════════════

/// If P = NP, physics would be very different:
/// - Protein folding would be easy (biology changes)
/// - Cryptography impossible (society changes)
/// - Creativity automatable (philosophy changes)
/// 
/// The asymmetry P ≠ NP may reflect a deep physical truth:
/// - Second law of thermodynamics: entropy increases
/// - Time asymmetry: easy to scramble, hard to unscramble
/// - Verification vs creation asymmetry

pub const PvsNP = struct {
    pub const physical_arguments_for_p_neq_np = [_][]const u8{
        "Thermodynamic asymmetry: mixing is easy, unmixing is hard",
        "Time's arrow: forward evolution easy, backward hard",
        "Quantum mechanics: measurement collapses superposition irreversibly",
        "No free lunch: finding needles in haystacks requires searching",
        "Spin glass ground states are physically hard to find",
    };
    
    pub const implications_if_p_eq_np = [_][]const u8{
        "All NP problems solvable in polynomial time",
        "Cryptography based on hardness assumptions breaks",
        "Mathematical proofs could be found automatically",
        "Protein structure prediction becomes tractable",
        "Optimization problems become easy",
    };
};

// ═══════════════════════════════════════════════════════════════
// QUANTUM SPEEDUP: PHYSICS ENABLING ALGORITHMS
// ═══════════════════════════════════════════════════════════════

pub const QuantumSpeedup = struct {
    algorithm: []const u8,
    classical: []const u8,
    quantum: []const u8,
    speedup: []const u8,
    physics_used: []const u8,
};

pub const quantum_algorithms = [_]QuantumSpeedup{
    .{
        .algorithm = "Grover Search",
        .classical = "O(N)",
        .quantum = "O(√N)",
        .speedup = "Quadratic",
        .physics_used = "Amplitude amplification via interference",
    },
    .{
        .algorithm = "Shor Factoring",
        .classical = "O(exp(n^(1/3)))",
        .quantum = "O(n³)",
        .speedup = "Exponential",
        .physics_used = "Quantum Fourier transform, period finding",
    },
    .{
        .algorithm = "Quantum Simulation",
        .classical = "O(exp(n))",
        .quantum = "O(poly(n))",
        .speedup = "Exponential",
        .physics_used = "Direct quantum evolution",
    },
    .{
        .algorithm = "HHL (Linear systems)",
        .classical = "O(N)",
        .quantum = "O(log N)",
        .speedup = "Exponential",
        .physics_used = "Quantum phase estimation",
    },
};

// ═══════════════════════════════════════════════════════════════
// ENERGY-TIME-SPACE TRADEOFFS
// ═══════════════════════════════════════════════════════════════

/// Fundamental tradeoff: you can trade space for time, but not escape physics
pub const ComputationalResources = struct {
    /// Time-space tradeoff
    /// Many algorithms can trade memory for speed
    /// Example: Rainbow tables vs brute force
    pub fn timeSpaceProduct(time_complexity: f64, space_complexity: f64) f64 {
        return time_complexity * space_complexity;
    }
    
    /// Energy-time tradeoff (Margolus-Levitin)
    /// More energy → faster computation
    /// E × t ≥ h/4 (quantum limit)
    pub fn minTimeForEnergy(energy_j: f64) f64 {
        return h / (4.0 * energy_j);
    }
    
    /// Energy-space tradeoff (Landauer)
    /// More bits → more energy to erase
    pub fn minEnergyForBits(n_bits: u64, temperature: f64) f64 {
        return @as(f64, @floatFromInt(n_bits)) * k_B * temperature * @log(2.0);
    }
    
    /// The fundamental constraint: can't escape all three
    /// Fast + Small + Cool = Impossible
    pub fn isPhysicallyPossible(
        time_s: f64,
        space_bits: u64,
        energy_j: f64,
        temperature: f64,
    ) bool {
        const min_time = minTimeForEnergy(energy_j);
        const min_energy = minEnergyForBits(space_bits, temperature);
        return time_s >= min_time and energy_j >= min_energy;
    }
};

// ═══════════════════════════════════════════════════════════════
// SYMMETRY IN ALGORITHMS = SYMMETRY IN PHYSICS
// ═══════════════════════════════════════════════════════════════

pub const SymmetryExploitation = struct {
    symmetry_type: []const u8,
    algorithm_example: []const u8,
    physics_analog: []const u8,
    speedup_factor: []const u8,
};

pub const symmetries = [_]SymmetryExploitation{
    .{
        .symmetry_type = "Cyclic (roots of unity)",
        .algorithm_example = "FFT",
        .physics_analog = "Fourier analysis of waves",
        .speedup_factor = "O(n²) → O(n log n)",
    },
    .{
        .symmetry_type = "Divide and conquer",
        .algorithm_example = "Merge sort, Karatsuba",
        .physics_analog = "Scale invariance, fractals",
        .speedup_factor = "Reduces exponent",
    },
    .{
        .symmetry_type = "Commutativity",
        .algorithm_example = "Parallel reduction",
        .physics_analog = "Abelian group operations",
        .speedup_factor = "O(n) → O(log n) parallel",
    },
    .{
        .symmetry_type = "Sparsity",
        .algorithm_example = "Sparse matrix algorithms",
        .physics_analog = "Locality in physics",
        .speedup_factor = "O(n²) → O(n) or O(n log n)",
    },
    .{
        .symmetry_type = "Monotonicity",
        .algorithm_example = "Binary search, DP",
        .physics_analog = "Convexity, energy minimization",
        .speedup_factor = "O(n) → O(log n)",
    },
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "universe computation limit" {
    const max_ops = UniverseComputer.maxOperations();
    // Should be around 10^122
    try std.testing.expect(max_ops > 1e120 and max_ops < 1e125);
}

test "physical possibility check" {
    // Reasonable computation: 1 second, 1 MB, 1 Joule, room temp
    const possible = ComputationalResources.isPhysicallyPossible(
        1.0,           // 1 second
        8_000_000,     // 1 MB
        1.0,           // 1 Joule
        300.0,         // room temperature
    );
    try std.testing.expect(possible);
    
    // Check minimum time constraint
    const min_time = ComputationalResources.minTimeForEnergy(1e-12);
    // With 1 picojoule, min time is ~1.66e-22 s
    // 1 attosecond (1e-18) > 1.66e-22, so time constraint is satisfied
    // But let's verify the function works
    try std.testing.expect(min_time > 1e-23 and min_time < 1e-21);
}

test "min time for energy" {
    // With 1 Joule, minimum time is h/4 ≈ 1.66e-34 seconds
    const min_t = ComputationalResources.minTimeForEnergy(1.0);
    try std.testing.expect(min_t > 1e-35 and min_t < 1e-33);
}

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("{s}\n", .{
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║              COMPUTATIONAL PHYSICS                                           ║
        \\║              Why Optimal Algorithms = Physical Laws                          ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
    });
    
    // Universe as computer
    try stdout.print("\n═══ THE UNIVERSE AS A COMPUTER ═══\n\n", .{});
    try stdout.print("Age of universe: {e:.2} seconds\n", .{UniverseComputer.age});
    try stdout.print("Total energy: {e:.2} Joules\n", .{UniverseComputer.total_energy});
    try stdout.print("Maximum operations since Big Bang: ~10^122\n", .{});
    try stdout.print("\nThis is why brute-forcing 2^256 is impossible:\n", .{});
    try stdout.print("  2^256 ≈ 10^77 << 10^122 (universe limit)\n", .{});
    try stdout.print("  But 10^77 operations would take all matter in universe!\n", .{});
    
    // Optimal algorithms
    try stdout.print("\n═══ OPTIMAL ALGORITHMS = PHYSICAL LAWS ═══\n\n", .{});
    for (optimal_algorithms) |alg| {
        try stdout.print("{s} [{s}]\n", .{ alg.algorithm, alg.complexity });
        try stdout.print("  Why optimal: {s}\n", .{alg.why_optimal});
        try stdout.print("  Physics: {s}\n\n", .{alg.physical_principle});
    }
    
    // P vs NP
    try stdout.print("═══ P vs NP: A PHYSICAL QUESTION? ═══\n\n", .{});
    try stdout.print("Physical arguments for P ≠ NP:\n", .{});
    for (PvsNP.physical_arguments_for_p_neq_np) |arg| {
        try stdout.print("  • {s}\n", .{arg});
    }
    
    // Quantum speedups
    try stdout.print("\n═══ QUANTUM ALGORITHMS: PHYSICS → SPEEDUP ═══\n\n", .{});
    try stdout.print("{s:<20} {s:<15} {s:<12} {s}\n", .{ "Algorithm", "Classical", "Quantum", "Physics Used" });
    try stdout.print("{s}\n", .{"-" ** 75});
    for (quantum_algorithms) |q| {
        try stdout.print("{s:<20} {s:<15} {s:<12} {s}\n", .{
            q.algorithm, q.classical, q.quantum, q.physics_used,
        });
    }
    
    // Symmetry exploitation
    try stdout.print("\n═══ SYMMETRY: KEY TO FAST ALGORITHMS ═══\n\n", .{});
    for (symmetries) |sym| {
        try stdout.print("{s}\n", .{sym.symmetry_type});
        try stdout.print("  Algorithm: {s}\n", .{sym.algorithm_example});
        try stdout.print("  Physics: {s}\n", .{sym.physics_analog});
        try stdout.print("  Speedup: {s}\n\n", .{sym.speedup_factor});
    }
    
    // Hardness interpretations
    try stdout.print("═══ WHY PROBLEMS ARE HARD: PHYSICS ═══\n\n", .{});
    for (HardnessPhysics.interpretations) |interp| {
        try stdout.print("{s}\n", .{interp.problem_class});
        try stdout.print("  Physical reason: {s}\n", .{interp.physical_reason});
        try stdout.print("  Examples: {s}\n\n", .{interp.example});
    }
    
    try stdout.print("═══ CONCLUSION ═══\n\n", .{});
    try stdout.print("Algorithms are not arbitrary human constructs.\n", .{});
    try stdout.print("They are DISCOVERIES of how information behaves physically.\n", .{});
    try stdout.print("The best algorithms exploit the deepest symmetries of nature.\n", .{});
    try stdout.print("\n✅ Computation is physics. Physics is computation.\n", .{});
}
