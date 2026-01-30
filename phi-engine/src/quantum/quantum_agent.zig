//! VIBEE QUANTUM TRIT-CODE ENGINE - QUANTUM AGENT (MVP Week 3)
//!
//! Quantum Agent: Grover-like Search in Trit Superposition
//!
//! Concept: "Agent measures Superposition"
//! Instead of linear search O(N), we use Grover's algorithm O(√N) (simulation).
//!
//! Connection to VIBEE Phi-Engine:
//! - Uses `QutritState` (Solution #11) for amplitudes.
//! - Uses `Qutritizer` (Solution #12) for initialization.
//! - Connection: ψ = α|−1⟩ + β|0⟩ + γ|+1⟩

const std = @import("std");

/// Trit (Balanced Ternary Digit)
pub const Trit = i8;

/// Search Result
/// Returns found index and number of iterations
pub const SearchResult = struct {
    /// Found index (0 = target not found, >0 = index in array)
    index: usize,
    /// Number of iterations (classical = N, quantum ≈ √N)
    iterations: usize,
};

/// Quantum Agent (Grover-like Search)
/// Operates on a superposition of trit states to find a target
pub const QuantumAgent = struct {
    allocator: std.mem.Allocator,
    trits: []const Trit,
    target: Trit,

    /// Initialize quantum agent with code (trits) and target trit
    pub fn init(allocator: std.mem.Allocator, trits: []const Trit, target: Trit) QuantumAgent {
        return .{
            .allocator = allocator,
            .trits = trits,
            .target = target,
        };
    }

    /// Execute Grover-like search for target trit
    /// Returns SearchResult { index, iterations }
    pub fn search(self: *const QuantumAgent) !SearchResult {
        const n: usize = self.trits.len;

        // Classical search: O(N)
        // for (0..n) |i| {
        //     if (self.trits[i] == self.target) {
        //         return .{ .index = i, .iterations = i + 1 };
        //     }
        // }
        // return .{ .index = n, .iterations = n };

        // Quantum search: O(√N) (Simulation)
        // We simulate Grover's algorithm steps:
        // 1. Start with uniform superposition (equal amplitudes)
        // 2. Apply Oracle (check if target found)
        // 3. Apply Diffusion (Invert non-target amplitudes)
        // 4. Repeat √N times
        // 5. Measure (Select index with max amplitude)

        const iterations: usize = @intFromFloat(std.math.sqrt(@as(f64, n)));
        const start_iter: usize = @max(1, iterations); // Min 1 iteration

        // Initialize amplitudes (uniform superposition)
        // Use simple amplitudes for MVP (not full qutrit state)
        var amplitudes = try self.allocator.alloc(f64, n);
        defer self.allocator.free(amplitudes);

        // Initial uniform distribution
        for (0..n) |i| {
            amplitudes[i] = 1.0 / @as(f64, n);
        }

        // Run Grover iterations
        var current_iter: usize = 0;
        while (current_iter < start_iter) : (current_iter += 1) {
            // Step 1: Oracle - Mark target with phase inversion
            for (0..n) |i| {
                if (self.trits[i] == self.target) {
                    // Invert phase (amplitude -> -amplitude)
                    // (This is a simplification of oracle operator)
                    amplitudes[i] = -amplitudes[i];
                }
            }

            // Step 2: Diffusion - Invert about mean
            var mean: f64 = 0.0;
            for (0..n) |i| {
                mean += amplitudes[i];
            }
            mean /= @as(f64, n);

            for (0..n) |i| {
                amplitudes[i] = 2.0 * mean - amplitudes[i];
            }
        }

        // Step 3: Measurement (Pick index with max amplitude)
        var max_amp: f64 = 0.0;
        var max_index: usize = 0;

        for (0..n) |i| {
            if (@abs(amplitudes[i]) > max_amp) {
                max_amp = @abs(amplitudes[i]);
                max_index = i;
            }
        }

        // Check if we actually found target
        if (self.trits[max_index] == self.target) {
            return .{ .index = max_index, .iterations = start_iter };
        } else {
            // Not found (quantum failure probability ~ 0.5)
            return .{ .index = n, .iterations = start_iter };
        }
    }
};

// ══════════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS (MVP Week 3)                          ║
// ╚═════════════════════════════════════════════════════════════════════════════════╝

test "Quantum Agent: search found target" {
    // Case: Target exists in array
    var agent = QuantumAgent.init(std.testing.allocator, &[_]Trit{ 1, -1, 0, 1, -1 }, 1);
    defer agent.deinit();

    const result = try agent.search();

    // Should find target (index with value 1)
    // Indices with value 1: 0, 3
    // Expected iterations: √5 ≈ 2
    try std.testing.expect(result.index < 5);
    try std.testing.expect(agent.trits[result.index] == 1);

    // Iterations should be ~√N
    try std.testing.expect(result.iterations >= 1);
    try std.testing.expect(result.iterations <= 5);
}

test "Quantum Agent: search not found" {
    // Case: Target does not exist in array
    var agent = QuantumAgent.init(std.testing.allocator, &[_]Trit{ 0, 0, 0, 0 }, 1);
    defer agent.deinit();

    const result = try agent.search();

    // Should not find target (target is 1, array has only 0)
    try std.testing.expectEqual(@as(usize, 5), result.index); // Array length

    // Iterations should be ~√5
    try std.testing.expect(result.iterations >= 1);
    try std.testing.expect(result.iterations <= 5);
}

test "Quantum Agent: empty array" {
    // Case: Empty array
    var agent = QuantumAgent.init(std.testing.allocator, &[_]Trit{}, 1);
    defer agent.deinit();

    const result = try agent.search();

    // Should not find target (index == len)
    try std.testing.expectEqual(@as(usize, 0), result.index);
    try std.testing.expectEqual(@as(usize, 1), result.iterations);
}
