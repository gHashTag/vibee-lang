// v6753_pipeline_parallelism.zig - Pipeline Parallelism
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const PPConfig = struct {
    num_stages: usize = 4,
    micro_batches: usize = 8,
};

pub fn layersPerStage(total_layers: usize, num_stages: usize) usize {
    return (total_layers + num_stages - 1) / num_stages;
}

pub fn stageForLayer(layer_idx: usize, layers_per_stage: usize) usize {
    return layer_idx / layers_per_stage;
}

pub fn bubbleOverhead(num_stages: usize, micro_batches: usize) f32 {
    // Bubble = (p-1) / m where p = stages, m = micro_batches
    const p: f32 = @floatFromInt(num_stages);
    const m: f32 = @floatFromInt(micro_batches);
    return (p - 1.0) / m;
}

pub fn efficiency(num_stages: usize, micro_batches: usize) f32 {
    return 1.0 - bubbleOverhead(num_stages, micro_batches);
}

pub fn phiMicroBatches(num_stages: usize) usize {
    // PHI-scaled micro batches for optimal efficiency
    return @intFromFloat(@as(f64, @floatFromInt(num_stages)) * PHI * PHI);
}

pub fn schedule1F1B(stage: usize, micro_batch: usize, num_stages: usize, num_micro: usize) struct { is_forward: bool, active: bool } {
    // 1F1B schedule: forward then backward interleaved
    const warmup = num_stages - stage - 1;
    const total_steps = num_micro + num_stages - 1;

    if (micro_batch < warmup) {
        return .{ .is_forward = true, .active = micro_batch <= stage };
    } else if (micro_batch < total_steps - warmup) {
        return .{ .is_forward = (micro_batch - warmup) % 2 == 0, .active = true };
    } else {
        return .{ .is_forward = false, .active = micro_batch < total_steps };
    }
}

pub fn memoryPerStage(total_memory: usize, num_stages: usize) usize {
    return total_memory / num_stages;
}

// Tests
test "layers per stage" {
    try testing.expectEqual(@as(usize, 3), layersPerStage(12, 4));
    try testing.expectEqual(@as(usize, 4), layersPerStage(12, 3));
}

test "stage for layer" {
    try testing.expectEqual(@as(usize, 0), stageForLayer(2, 3));
    try testing.expectEqual(@as(usize, 1), stageForLayer(4, 3));
}

test "bubble overhead" {
    const overhead = bubbleOverhead(4, 8);
    try testing.expect(@abs(overhead - 0.375) < 0.01);
}

test "efficiency" {
    const eff = efficiency(4, 16);
    try testing.expect(eff > 0.8);
}

test "phi micro batches" {
    const mb = phiMicroBatches(4);
    try testing.expect(mb >= 10);
}

test "memory per stage" {
    const mem = memoryPerStage(1024, 4);
    try testing.expectEqual(@as(usize, 256), mem);
}
