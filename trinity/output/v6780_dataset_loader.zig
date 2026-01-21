// v6780_dataset_loader.zig - Dataset Loader (GLUE, SQuAD)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const DatasetType = enum {
    glue_sst2,
    glue_mrpc,
    glue_cola,
    squad_v1,
    squad_v2,
    custom,
};

pub const DatasetConfig = struct {
    dataset_type: DatasetType = .glue_sst2,
    max_length: usize = 128,
    batch_size: usize = 32,
    shuffle: bool = true,
};

pub const Sample = struct {
    input_ids: [128]u32 = [_]u32{0} ** 128,
    attention_mask: [128]u8 = [_]u8{0} ** 128,
    label: i32 = 0,
    length: usize = 0,
};

// Create sample from tokens
pub fn createSample(tokens: []const u32, label: i32) Sample {
    var sample = Sample{};
    const n = @min(tokens.len, 128);

    for (0..n) |i| {
        sample.input_ids[i] = tokens[i];
        sample.attention_mask[i] = 1;
    }
    sample.label = label;
    sample.length = n;

    return sample;
}

// Shuffle indices using Fisher-Yates
pub fn shuffleIndices(indices: []usize, seed: u64) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    var i = indices.len;
    while (i > 1) {
        i -= 1;
        const j = random.intRangeAtMost(usize, 0, i);
        const tmp = indices[i];
        indices[i] = indices[j];
        indices[j] = tmp;
    }
}

// Get batch indices
pub fn getBatchIndices(
    epoch_indices: []const usize,
    batch_idx: usize,
    batch_size: usize,
    output: []usize,
) usize {
    const start = batch_idx * batch_size;
    const end = @min(start + batch_size, epoch_indices.len);
    const actual_size = end - start;

    for (0..actual_size) |i| {
        if (i < output.len) {
            output[i] = epoch_indices[start + i];
        }
    }

    return actual_size;
}

// PHI-based batch size
pub fn phiBatchSize(memory_gb: f32, seq_len: usize) usize {
    const base = memory_gb * 1000.0 / @as(f32, @floatFromInt(seq_len));
    return @intFromFloat(base * @as(f32, @floatCast(PHI_INV)));
}

// Number of batches per epoch
pub fn numBatches(dataset_size: usize, batch_size: usize) usize {
    return (dataset_size + batch_size - 1) / batch_size;
}

// Estimate dataset size for GLUE tasks
pub fn glueDatasetSize(task: DatasetType) usize {
    return switch (task) {
        .glue_sst2 => 67349,
        .glue_mrpc => 3668,
        .glue_cola => 8551,
        .squad_v1 => 87599,
        .squad_v2 => 130319,
        .custom => 0,
    };
}

// Tests
test "create sample" {
    const tokens = [_]u32{ 101, 2023, 2003, 102 };
    const sample = createSample(&tokens, 1);
    try testing.expectEqual(@as(u32, 101), sample.input_ids[0]);
    try testing.expectEqual(@as(i32, 1), sample.label);
    try testing.expectEqual(@as(usize, 4), sample.length);
}

test "shuffle indices" {
    var indices = [_]usize{ 0, 1, 2, 3, 4 };
    shuffleIndices(&indices, 42);
    // Should be different from original (with high probability)
    var same_count: usize = 0;
    for (0..5) |i| {
        if (indices[i] == i) same_count += 1;
    }
    try testing.expect(same_count < 5);
}

test "get batch indices" {
    const epoch = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7 };
    var batch: [4]usize = undefined;
    const size = getBatchIndices(&epoch, 1, 3, &batch);
    try testing.expectEqual(@as(usize, 3), size);
    try testing.expectEqual(@as(usize, 3), batch[0]);
}

test "phi batch size" {
    const bs = phiBatchSize(8.0, 128);
    try testing.expect(bs > 30);
}

test "num batches" {
    try testing.expectEqual(@as(usize, 4), numBatches(100, 32));
}

test "glue dataset size" {
    const size = glueDatasetSize(.glue_sst2);
    try testing.expect(size > 60000);
}
