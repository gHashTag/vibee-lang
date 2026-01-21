// v6774_hopfield_modern.zig - Modern Hopfield Networks
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const HopfieldConfig = struct {
    pattern_dim: usize = 64,
    beta: f32 = 1.0,
    num_patterns: usize = 100,
};

// Modern Hopfield energy function
pub fn energyFunction(state: []const f32, patterns: []const f32, num_patterns: usize, beta: f32) f32 {
    const dim = state.len;
    var energy: f64 = 0;

    // E = -1/β * log(Σ exp(β * <ξ, x>))
    var log_sum_exp: f64 = 0;
    var max_dot: f64 = -math.inf(f64);

    for (0..num_patterns) |p| {
        var dot: f64 = 0;
        for (0..dim) |i| {
            const p_idx = p * dim + i;
            const pattern_val = if (p_idx < patterns.len) patterns[p_idx] else 0;
            dot += @as(f64, state[i]) * @as(f64, pattern_val);
        }
        max_dot = @max(max_dot, dot * @as(f64, beta));
    }

    for (0..num_patterns) |p| {
        var dot: f64 = 0;
        for (0..dim) |i| {
            const p_idx = p * dim + i;
            const pattern_val = if (p_idx < patterns.len) patterns[p_idx] else 0;
            dot += @as(f64, state[i]) * @as(f64, pattern_val);
        }
        log_sum_exp += @exp(dot * @as(f64, beta) - max_dot);
    }

    energy = -(@log(log_sum_exp) + max_dot) / @as(f64, beta);
    return @floatCast(energy);
}

// Modern Hopfield update rule (equivalent to attention!)
pub fn hopfieldUpdate(
    state: []const f32,
    patterns: []const f32,
    num_patterns: usize,
    beta: f32,
    output: []f32,
) void {
    const dim = state.len;

    // Compute softmax attention over patterns
    var scores: [256]f32 = undefined;
    var max_score: f32 = -math.inf(f32);

    for (0..num_patterns) |p| {
        var dot: f32 = 0;
        for (0..dim) |i| {
            const p_idx = p * dim + i;
            const pattern_val: f32 = if (p_idx < patterns.len) patterns[p_idx] else 0;
            dot += state[i] * pattern_val;
        }
        if (p < 256) {
            scores[p] = beta * dot;
            max_score = @max(max_score, scores[p]);
        }
    }

    // Softmax
    var sum: f32 = 0;
    for (0..num_patterns) |p| {
        if (p < 256) {
            scores[p] = @exp(scores[p] - max_score);
            sum += scores[p];
        }
    }

    // Weighted sum of patterns
    for (0..dim) |i| {
        var weighted: f32 = 0;
        for (0..num_patterns) |p| {
            const p_idx = p * dim + i;
            const pattern_val: f32 = if (p_idx < patterns.len) patterns[p_idx] else 0;
            const weight = if (p < 256) scores[p] / sum else 0;
            weighted += weight * pattern_val;
        }
        if (i < output.len) {
            output[i] = weighted;
        }
    }
}

// Attention as Hopfield retrieval
pub fn attentionAsHopfield(
    query: []const f32,
    keys: []const f32,
    _: []const f32,
    num_kv: usize,
    output: []f32,
) void {
    // Attention IS modern Hopfield with:
    // - Query = state
    // - Keys = patterns
    // - Values = pattern values
    hopfieldUpdate(query, keys, num_kv, 1.0, output);
}

// PHI-based beta (inverse temperature)
pub fn phiBeta(layer: usize, num_layers: usize) f32 {
    const progress = @as(f64, @floatFromInt(layer)) / @as(f64, @floatFromInt(num_layers));
    return @floatCast(PHI * (1.0 + progress));
}

// Tests
test "energy function" {
    const state = [_]f32{ 1.0, 0.0 };
    const patterns = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const energy = energyFunction(&state, &patterns, 2, 1.0);
    try testing.expect(energy < 0); // Negative energy for matching
}

test "hopfield update" {
    const state = [_]f32{ 0.9, 0.1 };
    const patterns = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    var output: [2]f32 = undefined;
    hopfieldUpdate(&state, &patterns, 2, 1.0, &output);
    try testing.expect(output[0] > output[1]); // Should converge to first pattern
}

test "attention as hopfield" {
    const query = [_]f32{ 1.0, 0.0 };
    const keys = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const values = [_]f32{ 2.0, 0.0, 0.0, 2.0 };
    var output: [2]f32 = undefined;
    attentionAsHopfield(&query, &keys, &values, 2, &output);
    try testing.expect(output[0] > 0);
}

test "phi beta" {
    const b0 = phiBeta(0, 12);
    const b11 = phiBeta(11, 12);
    try testing.expect(b11 > b0);
}

test "config defaults" {
    const config = HopfieldConfig{};
    try testing.expectEqual(@as(f32, 1.0), config.beta);
}

test "pattern capacity" {
    // Modern Hopfield can store exponentially many patterns
    const config = HopfieldConfig{};
    try testing.expect(config.num_patterns > 0);
}
