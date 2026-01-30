// ═══════════════════════════════════════════════════════════════════════════════
// LEVEL 5: ADVANCED - Quantum Algorithms
// ═══════════════════════════════════════════════════════════════════════════════
//
// Quantum computing fundamentals and algorithms
// Time: 6+ months (research level)
//
// Algorithms: Grover's Search, Shor's Factoring, VQE
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// COMPLEX NUMBERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Complex = struct {
    real: f64,
    imag: f64,

    pub fn init(real: f64, imag: f64) Complex {
        return Complex{ .real = real, .imag = imag };
    }

    pub fn zero() Complex {
        return Complex{ .real = 0, .imag = 0 };
    }

    pub fn one() Complex {
        return Complex{ .real = 1, .imag = 0 };
    }

    pub fn add(self: Complex, other: Complex) Complex {
        return Complex{
            .real = self.real + other.real,
            .imag = self.imag + other.imag,
        };
    }

    pub fn mul(self: Complex, other: Complex) Complex {
        return Complex{
            .real = self.real * other.real - self.imag * other.imag,
            .imag = self.real * other.imag + self.imag * other.real,
        };
    }

    pub fn scale(self: Complex, s: f64) Complex {
        return Complex{
            .real = self.real * s,
            .imag = self.imag * s,
        };
    }

    pub fn conjugate(self: Complex) Complex {
        return Complex{
            .real = self.real,
            .imag = -self.imag,
        };
    }

    pub fn magnitude(self: Complex) f64 {
        return @sqrt(self.real * self.real + self.imag * self.imag);
    }

    pub fn magnitudeSquared(self: Complex) f64 {
        return self.real * self.real + self.imag * self.imag;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUBIT
// ═══════════════════════════════════════════════════════════════════════════════

/// Qubit state: α|0⟩ + β|1⟩
pub const Qubit = struct {
    alpha: Complex, // |0⟩ amplitude
    beta: Complex, // |1⟩ amplitude

    /// Create |0⟩ state
    pub fn zero() Qubit {
        return Qubit{
            .alpha = Complex.one(),
            .beta = Complex.zero(),
        };
    }

    /// Create |1⟩ state
    pub fn one() Qubit {
        return Qubit{
            .alpha = Complex.zero(),
            .beta = Complex.one(),
        };
    }

    /// Create |+⟩ = (|0⟩ + |1⟩) / √2
    pub fn plus() Qubit {
        const inv_sqrt2 = 1.0 / @sqrt(2.0);
        return Qubit{
            .alpha = Complex.init(inv_sqrt2, 0),
            .beta = Complex.init(inv_sqrt2, 0),
        };
    }

    /// Create |-⟩ = (|0⟩ - |1⟩) / √2
    pub fn minus() Qubit {
        const inv_sqrt2 = 1.0 / @sqrt(2.0);
        return Qubit{
            .alpha = Complex.init(inv_sqrt2, 0),
            .beta = Complex.init(-inv_sqrt2, 0),
        };
    }

    /// Check if state is normalized (|α|² + |β|² = 1)
    pub fn isNormalized(self: Qubit) bool {
        const norm = self.alpha.magnitudeSquared() + self.beta.magnitudeSquared();
        return @abs(norm - 1.0) < 0.0001;
    }

    /// Probability of measuring |0⟩
    pub fn prob0(self: Qubit) f64 {
        return self.alpha.magnitudeSquared();
    }

    /// Probability of measuring |1⟩
    pub fn prob1(self: Qubit) f64 {
        return self.beta.magnitudeSquared();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM GATES
// ═══════════════════════════════════════════════════════════════════════════════

pub const QuantumGate = enum {
    hadamard,
    pauli_x,
    pauli_y,
    pauli_z,
    phase,
    t_gate,

    pub fn name(self: QuantumGate) []const u8 {
        return switch (self) {
            .hadamard => "H",
            .pauli_x => "X",
            .pauli_y => "Y",
            .pauli_z => "Z",
            .phase => "S",
            .t_gate => "T",
        };
    }
};

/// Apply Hadamard gate: H|0⟩ = |+⟩, H|1⟩ = |-⟩
pub fn applyHadamard(q: Qubit) Qubit {
    const inv_sqrt2 = 1.0 / @sqrt(2.0);

    return Qubit{
        .alpha = q.alpha.add(q.beta).scale(inv_sqrt2),
        .beta = q.alpha.add(q.beta.scale(-1)).scale(inv_sqrt2),
    };
}

/// Apply Pauli-X gate (NOT): X|0⟩ = |1⟩, X|1⟩ = |0⟩
pub fn applyPauliX(q: Qubit) Qubit {
    return Qubit{
        .alpha = q.beta,
        .beta = q.alpha,
    };
}

/// Apply Pauli-Z gate: Z|0⟩ = |0⟩, Z|1⟩ = -|1⟩
pub fn applyPauliZ(q: Qubit) Qubit {
    return Qubit{
        .alpha = q.alpha,
        .beta = q.beta.scale(-1),
    };
}

/// Apply Phase gate (S): S|0⟩ = |0⟩, S|1⟩ = i|1⟩
pub fn applyPhase(q: Qubit) Qubit {
    return Qubit{
        .alpha = q.alpha,
        .beta = Complex.init(-q.beta.imag, q.beta.real), // multiply by i
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// GROVER'S ALGORITHM
// ═══════════════════════════════════════════════════════════════════════════════

/// Grover's search algorithm simulation
/// Finds marked item in O(√N) queries
pub const GroverSearch = struct {
    n_qubits: u32,
    n_items: u32,
    marked_item: u32,
    optimal_iterations: u32,

    pub fn init(n_qubits: u32, marked_item: u32) GroverSearch {
        const n_items = @as(u32, 1) << @intCast(n_qubits);
        const optimal = @as(u32, @intFromFloat(@round(
            std.math.pi / 4.0 * @sqrt(@as(f64, @floatFromInt(n_items))),
        )));

        return GroverSearch{
            .n_qubits = n_qubits,
            .n_items = n_items,
            .marked_item = marked_item,
            .optimal_iterations = @max(1, optimal),
        };
    }

    /// Simulate Grover's algorithm
    pub fn search(self: GroverSearch) GroverResult {
        // Initial amplitude for each state
        var amplitude = 1.0 / @sqrt(@as(f64, @floatFromInt(self.n_items)));
        var marked_amplitude = amplitude;

        // Grover iterations
        var i: u32 = 0;
        while (i < self.optimal_iterations) : (i += 1) {
            // Oracle: flip sign of marked state
            marked_amplitude = -marked_amplitude;

            // Diffusion: invert about mean
            const mean = (@as(f64, @floatFromInt(self.n_items - 1)) * amplitude + marked_amplitude) /
                @as(f64, @floatFromInt(self.n_items));

            amplitude = 2 * mean - amplitude;
            marked_amplitude = 2 * mean - marked_amplitude;
        }

        const success_prob = marked_amplitude * marked_amplitude;

        return GroverResult{
            .found_item = self.marked_item,
            .probability = success_prob,
            .iterations = self.optimal_iterations,
            .classical_queries = self.n_items / 2, // Expected for classical
            .quantum_queries = self.optimal_iterations,
        };
    }
};

pub const GroverResult = struct {
    found_item: u32,
    probability: f64,
    iterations: u32,
    classical_queries: u32,
    quantum_queries: u32,

    pub fn speedup(self: GroverResult) f64 {
        return @as(f64, @floatFromInt(self.classical_queries)) /
            @as(f64, @floatFromInt(@max(1, self.quantum_queries)));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM FOURIER TRANSFORM
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantum Fourier Transform (simplified)
pub fn qft(amplitudes: []Complex) void {
    const n = amplitudes.len;
    const n_f = @as(f64, @floatFromInt(n));

    // Temporary storage
    var temp: [256]Complex = undefined;
    for (0..n) |k| {
        temp[k] = Complex.zero();
        for (0..n) |j| {
            const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(j * k)) / n_f;
            const phase = Complex.init(@cos(angle), @sin(angle));
            temp[k] = temp[k].add(amplitudes[j].mul(phase));
        }
        temp[k] = temp[k].scale(1.0 / @sqrt(n_f));
    }

    // Copy back
    for (0..n) |i| {
        amplitudes[i] = temp[i];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM SPEC
// ═══════════════════════════════════════════════════════════════════════════════

pub const QuantumAlgorithm = enum {
    grover,
    shor,
    vqe,
    qaoa,
    qft,

    pub fn classicalComplexity(self: QuantumAlgorithm) []const u8 {
        return switch (self) {
            .grover => "O(N)",
            .shor => "O(exp(n^(1/3)))",
            .vqe => "O(exp(n))",
            .qaoa => "O(exp(n))",
            .qft => "O(n * 2^n)",
        };
    }

    pub fn quantumComplexity(self: QuantumAlgorithm) []const u8 {
        return switch (self) {
            .grover => "O(√N)",
            .shor => "O(n³)",
            .vqe => "O(poly(n))",
            .qaoa => "O(poly(n))",
            .qft => "O(n²)",
        };
    }

    pub fn speedup(self: QuantumAlgorithm) []const u8 {
        return switch (self) {
            .grover => "Quadratic",
            .shor => "Exponential",
            .vqe => "Exponential (for specific problems)",
            .qaoa => "Polynomial to Exponential",
            .qft => "Exponential",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Complex arithmetic" {
    const a = Complex.init(3, 4);
    const b = Complex.init(1, 2);

    const sum = a.add(b);
    try testing.expectApproxEqAbs(@as(f64, 4), sum.real, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 6), sum.imag, 0.0001);

    const prod = a.mul(b);
    try testing.expectApproxEqAbs(@as(f64, -5), prod.real, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 10), prod.imag, 0.0001);
}

test "Complex magnitude" {
    const c = Complex.init(3, 4);
    try testing.expectApproxEqAbs(@as(f64, 5), c.magnitude(), 0.0001);
}

test "Qubit zero state" {
    const q = Qubit.zero();
    try testing.expect(q.isNormalized());
    try testing.expectApproxEqAbs(@as(f64, 1), q.prob0(), 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0), q.prob1(), 0.0001);
}

test "Qubit one state" {
    const q = Qubit.one();
    try testing.expect(q.isNormalized());
    try testing.expectApproxEqAbs(@as(f64, 0), q.prob0(), 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 1), q.prob1(), 0.0001);
}

test "Qubit plus state" {
    const q = Qubit.plus();
    try testing.expect(q.isNormalized());
    try testing.expectApproxEqAbs(@as(f64, 0.5), q.prob0(), 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.5), q.prob1(), 0.0001);
}

test "Hadamard gate" {
    const q0 = Qubit.zero();
    const q_plus = applyHadamard(q0);

    try testing.expect(q_plus.isNormalized());
    try testing.expectApproxEqAbs(@as(f64, 0.5), q_plus.prob0(), 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.5), q_plus.prob1(), 0.0001);
}

test "Pauli-X gate" {
    const q0 = Qubit.zero();
    const q1 = applyPauliX(q0);

    try testing.expectApproxEqAbs(@as(f64, 0), q1.prob0(), 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 1), q1.prob1(), 0.0001);
}

test "Grover's algorithm" {
    const grover = GroverSearch.init(3, 5); // 8 items, find item 5
    const result = grover.search();

    try testing.expectEqual(@as(u32, 5), result.found_item);
    try testing.expect(result.probability > 0.9); // High success probability
    try testing.expect(result.speedup() > 1.0); // Quantum advantage
}

test "QuantumAlgorithm complexities" {
    try testing.expectEqualStrings("O(N)", QuantumAlgorithm.grover.classicalComplexity());
    try testing.expectEqualStrings("O(√N)", QuantumAlgorithm.grover.quantumComplexity());
    try testing.expectEqualStrings("Quadratic", QuantumAlgorithm.grover.speedup());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const result = phi_sq + phi_inv_sq;
    try testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
