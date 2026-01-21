// v6740_speculative_decoding.zig - Speculative Decoding for QuantumMiniLM
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;

pub const SpeculativeConfig = struct {
    draft_length: usize = 5,
    acceptance_threshold: f32 = 0.7,
    max_candidates: usize = 8,
};

pub fn phiSpeculationLength(base: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(base)) * PHI);
}

pub fn draftTokens(input: []const f32, config: SpeculativeConfig, output: []f32) usize {
    const draft_len = @min(config.draft_length, output.len);
    for (0..draft_len) |i| {
        const idx = i % input.len;
        output[i] = input[idx] * @as(f32, @floatCast(PHI_INV));
    }
    return draft_len;
}

pub fn verifyTokens(draft: []const f32, target: []const f32, threshold: f32) usize {
    var accepted: usize = 0;
    const len = @min(draft.len, target.len);
    for (0..len) |i| {
        const diff = @abs(draft[i] - target[i]);
        if (diff < threshold) {
            accepted += 1;
        } else break;
    }
    return accepted;
}

pub fn computeSpeedup(acceptance_rate: f32, speculation_length: usize) f32 {
    const k: f32 = @floatFromInt(speculation_length);
    const alpha = acceptance_rate;
    if (alpha >= 1.0) return k;
    return 1.0 / (1.0 - alpha + alpha / k);
}

pub fn acceptanceThresholdPhi() f32 {
    return @floatCast(PHI_INV);
}

// Tests
test "phi speculation length" {
    try testing.expectEqual(@as(usize, 8), phiSpeculationLength(5));
    try testing.expectEqual(@as(usize, 16), phiSpeculationLength(10));
}

test "draft tokens" {
    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [5]f32 = undefined;
    const config = SpeculativeConfig{};
    const len = draftTokens(&input, config, &output);
    try testing.expectEqual(@as(usize, 5), len);
}

test "verify tokens" {
    const draft = [_]f32{ 1.0, 2.0, 3.0 };
    const target = [_]f32{ 1.1, 2.1, 5.0 };
    const accepted = verifyTokens(&draft, &target, 0.5);
    try testing.expectEqual(@as(usize, 2), accepted);
}

test "speedup calculation" {
    const speedup = computeSpeedup(0.8, 5);
    try testing.expect(speedup > 2.0);
}

test "phi threshold" {
    const threshold = acceptanceThresholdPhi();
    try testing.expect(@abs(threshold - 0.618) < 0.01);
}

test "config defaults" {
    const config = SpeculativeConfig{};
    try testing.expectEqual(@as(usize, 5), config.draft_length);
}
