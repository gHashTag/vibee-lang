// v6755_zero_optimizer.zig - ZeRO Optimizer States
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const ZeROConfig = struct {
    stage: usize = 1,
    offload_optimizer: bool = false,
    offload_params: bool = false,
};

pub const ZeROStage = enum(usize) {
    stage1 = 1, // Partition optimizer states
    stage2 = 2, // + Partition gradients
    stage3 = 3, // + Partition parameters
};

pub fn memoryPerDevice(model_params: usize, world_size: usize, stage: ZeROStage, dtype_bytes: usize) usize {
    const params_mem = model_params * dtype_bytes;
    const grad_mem = model_params * dtype_bytes;
    const opt_mem = model_params * dtype_bytes * 2; // Adam: m and v

    return switch (stage) {
        .stage1 => params_mem + grad_mem + opt_mem / world_size,
        .stage2 => params_mem + (grad_mem + opt_mem) / world_size,
        .stage3 => (params_mem + grad_mem + opt_mem) / world_size,
    };
}

pub fn memoryReduction(world_size: usize, stage: ZeROStage) f32 {
    // Compared to no ZeRO (all replicated)
    const ws: f32 = @floatFromInt(world_size);
    return switch (stage) {
        .stage1 => 1.0 + 2.0 / ws, // Only optimizer sharded
        .stage2 => 1.0 + 3.0 / ws, // Optimizer + gradients
        .stage3 => 4.0 / ws, // Everything sharded
    };
}

pub fn communicationOverhead(stage: ZeROStage) f32 {
    // Relative to data parallel baseline
    return switch (stage) {
        .stage1 => 1.0, // Same as DP
        .stage2 => 1.0, // Same as DP
        .stage3 => 1.5, // 50% more for param gather
    };
}

pub fn partitionOptimizerState(state: []const f32, rank: usize, world_size: usize, output: []f32) void {
    const chunk = state.len / world_size;
    const start = rank * chunk;
    const end = @min(start + chunk, state.len);

    for (start..end) |i| {
        if (i - start < output.len) {
            output[i - start] = state[i];
        }
    }
}

pub fn gatherParameters(local_params: []const f32, world_size: usize, output: []f32) void {
    // Simulate all-gather (in real impl, would gather from all ranks)
    const chunk = output.len / world_size;
    for (0..chunk) |i| {
        if (i < local_params.len) {
            output[i] = local_params[i];
        }
    }
}

pub fn phiWorldSize(model_gb: f32, memory_per_device_gb: f32) usize {
    const min_devices = model_gb * 4.0 / memory_per_device_gb; // 4x for optimizer
    return @max(1, @as(usize, @intFromFloat(min_devices * @as(f32, @floatCast(PHI_INV)))));
}

// Tests
test "memory per device stage1" {
    const mem = memoryPerDevice(1000, 4, .stage1, 4);
    try testing.expect(mem < 1000 * 4 * 4); // Less than full replication
}

test "memory per device stage3" {
    const mem = memoryPerDevice(1000, 4, .stage3, 4);
    try testing.expect(mem < 1000 * 4 * 4); // Less than full replication
}

test "memory reduction" {
    const red1 = memoryReduction(4, .stage1);
    const red3 = memoryReduction(4, .stage3);
    try testing.expect(red3 < red1);
}

test "communication overhead" {
    const oh1 = communicationOverhead(.stage1);
    const oh3 = communicationOverhead(.stage3);
    try testing.expect(oh3 > oh1);
}

test "partition optimizer state" {
    const state = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var output: [4]f32 = undefined;
    partitionOptimizerState(&state, 1, 2, &output);
    try testing.expectEqual(@as(f32, 5), output[0]);
}

test "phi world size" {
    const ws = phiWorldSize(70.0, 80.0);
    try testing.expect(ws >= 2);
}
