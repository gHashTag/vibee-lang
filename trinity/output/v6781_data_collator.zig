// v6781_data_collator.zig - Data Collator (Dynamic Padding)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const PaddingStrategy = enum {
    max_length,
    longest,
    do_not_pad,
};

pub const CollatorConfig = struct {
    padding: PaddingStrategy = .longest,
    max_length: usize = 512,
    pad_token_id: u32 = 0,
    truncation: bool = true,
};

// Find max length in batch
pub fn findMaxLength(lengths: []const usize) usize {
    var max_len: usize = 0;
    for (lengths) |l| {
        max_len = @max(max_len, l);
    }
    return max_len;
}

// Pad sequence to target length
pub fn padSequence(
    input: []const u32,
    length: usize,
    target_length: usize,
    pad_token: u32,
    output: []u32,
) void {
    // Copy original
    for (0..length) |i| {
        if (i < output.len and i < input.len) {
            output[i] = input[i];
        }
    }
    // Pad
    for (length..target_length) |i| {
        if (i < output.len) {
            output[i] = pad_token;
        }
    }
}

// Create attention mask
pub fn createAttentionMask(length: usize, target_length: usize, mask: []u8) void {
    for (0..length) |i| {
        if (i < mask.len) {
            mask[i] = 1;
        }
    }
    for (length..target_length) |i| {
        if (i < mask.len) {
            mask[i] = 0;
        }
    }
}

// Truncate if needed
pub fn truncateSequence(length: usize, max_length: usize) usize {
    return @min(length, max_length);
}

// PHI-based dynamic max length
pub fn phiDynamicMaxLength(batch_max: usize, global_max: usize) usize {
    // Round up to nearest PHI multiple for efficiency
    const phi_unit = @as(usize, @intFromFloat(@as(f64, @floatFromInt(global_max)) * PHI_INV / 8.0)) * 8;
    const rounded = ((batch_max + phi_unit - 1) / phi_unit) * phi_unit;
    return @min(rounded, global_max);
}

// Compute padding efficiency
pub fn paddingEfficiency(actual_tokens: usize, padded_tokens: usize) f32 {
    if (padded_tokens == 0) return 1.0;
    return @as(f32, @floatFromInt(actual_tokens)) / @as(f32, @floatFromInt(padded_tokens));
}

// Collate batch
pub fn collateBatch(
    lengths: []const usize,
    config: CollatorConfig,
) struct { target_length: usize, efficiency: f32 } {
    const batch_max = findMaxLength(lengths);
    const target = switch (config.padding) {
        .max_length => config.max_length,
        .longest => @min(batch_max, config.max_length),
        .do_not_pad => batch_max,
    };

    var total_actual: usize = 0;
    for (lengths) |l| {
        total_actual += @min(l, target);
    }
    const total_padded = target * lengths.len;

    return .{
        .target_length = target,
        .efficiency = paddingEfficiency(total_actual, total_padded),
    };
}

// Tests
test "find max length" {
    const lengths = [_]usize{ 10, 25, 15, 30 };
    try testing.expectEqual(@as(usize, 30), findMaxLength(&lengths));
}

test "pad sequence" {
    const input = [_]u32{ 1, 2, 3 };
    var output: [5]u32 = undefined;
    padSequence(&input, 3, 5, 0, &output);
    try testing.expectEqual(@as(u32, 1), output[0]);
    try testing.expectEqual(@as(u32, 0), output[4]);
}

test "create attention mask" {
    var mask: [5]u8 = undefined;
    createAttentionMask(3, 5, &mask);
    try testing.expectEqual(@as(u8, 1), mask[0]);
    try testing.expectEqual(@as(u8, 0), mask[4]);
}

test "truncate sequence" {
    try testing.expectEqual(@as(usize, 100), truncateSequence(150, 100));
    try testing.expectEqual(@as(usize, 50), truncateSequence(50, 100));
}

test "phi dynamic max length" {
    const len = phiDynamicMaxLength(100, 512);
    try testing.expect(len >= 100);
    try testing.expect(len <= 512);
}

test "padding efficiency" {
    const eff = paddingEfficiency(80, 100);
    try testing.expectEqual(@as(f32, 0.8), eff);
}
