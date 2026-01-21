// v6764_hgrn.zig - HGRN (Hierarchical Gated RNN)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const HGRNConfig = struct {
    hidden_dim: usize = 256,
    num_levels: usize = 3,
    expansion_ratio: f32 = 1.5,
};

// Lower-bounded gate for stability
pub fn lowerBoundGate(gate: f32, lower_bound: f32) f32 {
    return lower_bound + (1.0 - lower_bound) * gate;
}

// Hierarchical gate computation
pub fn hierarchicalGate(input: []const f32, level: usize, num_levels: usize) f32 {
    var sum: f64 = 0;
    for (input) |x| {
        sum += @as(f64, x);
    }
    const mean: f32 = @floatCast(sum / @as(f64, @floatFromInt(input.len)));

    // Different gate behavior per level
    const level_factor = @as(f32, @floatFromInt(level + 1)) / @as(f32, @floatFromInt(num_levels));
    const raw_gate = 1.0 / (1.0 + @exp(-mean * level_factor));

    return lowerBoundGate(raw_gate, 0.5);
}

// Multi-level recurrence
pub fn multiLevelRecurrence(
    input: []const f32,
    prev_states: []const f32,
    gates: []const f32,
    num_levels: usize,
    output: []f32,
) void {
    const dim_per_level = input.len / num_levels;

    for (0..num_levels) |level| {
        const start = level * dim_per_level;
        const end = @min(start + dim_per_level, input.len);
        const gate = if (level < gates.len) gates[level] else 0.9;

        for (start..end) |i| {
            if (i < output.len and i < prev_states.len) {
                output[i] = gate * prev_states[i] + (1.0 - gate) * input[i];
            }
        }
    }
}

// PHI-based level scaling
pub fn phiLevelScale(level: usize, num_levels: usize) f32 {
    const progress = @as(f64, @floatFromInt(level)) / @as(f64, @floatFromInt(num_levels));
    return @floatCast(math.pow(f64, PHI, progress) / PHI);
}

// Forget gate with exponential parameterization
pub fn exponentialForgetGate(input: f32, weight: f32) f32 {
    return @exp(-@exp(weight) * @abs(input));
}

// Tests
test "lower bound gate" {
    const g = lowerBoundGate(0.0, 0.5);
    try testing.expectEqual(@as(f32, 0.5), g);

    const g2 = lowerBoundGate(1.0, 0.5);
    try testing.expectEqual(@as(f32, 1.0), g2);
}

test "hierarchical gate" {
    const input = [_]f32{ 1.0, 2.0, 3.0 };
    const g0 = hierarchicalGate(&input, 0, 3);
    const g2 = hierarchicalGate(&input, 2, 3);
    try testing.expect(g0 >= 0.5);
    try testing.expect(g2 >= 0.5);
}

test "multi level recurrence" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const prev = [_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const gates = [_]f32{ 0.5, 0.7, 0.9 };
    var output: [6]f32 = undefined;
    multiLevelRecurrence(&input, &prev, &gates, 3, &output);
    try testing.expect(output[0] > 0);
}

test "phi level scale" {
    const s0 = phiLevelScale(0, 3);
    const s2 = phiLevelScale(2, 3);
    try testing.expect(s2 > s0);
}

test "exponential forget gate" {
    const g = exponentialForgetGate(0.5, 0.0);
    try testing.expect(g > 0);
    try testing.expect(g < 1);
}

test "config defaults" {
    const config = HGRNConfig{};
    try testing.expectEqual(@as(usize, 3), config.num_levels);
}
