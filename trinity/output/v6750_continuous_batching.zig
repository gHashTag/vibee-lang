// v6750_continuous_batching.zig - Continuous Batching for Inference
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

pub const BatchConfig = struct {
    max_batch_size: usize = 32,
    max_waiting_time: f32 = 0.1,
};

pub const RequestState = enum {
    waiting,
    prefill,
    decode,
    completed,
};

pub const Request = struct {
    id: usize,
    state: RequestState,
    tokens_generated: usize,
    max_tokens: usize,
};

pub fn phiBatchSize(memory_gb: f32) usize {
    // PHI-scaled batch size based on memory
    const base = memory_gb * 8.0; // 8 requests per GB
    return @intFromFloat(base * @as(f32, @floatCast(PHI)));
}

pub fn canAddRequest(current_batch: usize, max_batch: usize) bool {
    return current_batch < max_batch;
}

pub fn iterationStep(requests: []Request) struct { completed: usize, continuing: usize } {
    var completed: usize = 0;
    var continuing: usize = 0;

    for (requests) |*req| {
        if (req.state == .decode) {
            req.tokens_generated += 1;
            if (req.tokens_generated >= req.max_tokens) {
                req.state = .completed;
                completed += 1;
            } else {
                continuing += 1;
            }
        } else if (req.state == .prefill) {
            req.state = .decode;
            continuing += 1;
        } else if (req.state == .waiting) {
            req.state = .prefill;
            continuing += 1;
        }
    }

    return .{ .completed = completed, .continuing = continuing };
}

pub fn throughputImprovement(_: usize, avg_seq_len: usize, max_seq_len: usize) f32 {
    // Static batching wastes compute on padding
    const static_efficiency = @as(f32, @floatFromInt(avg_seq_len)) / @as(f32, @floatFromInt(max_seq_len));
    // Continuous batching is ~100% efficient
    return 1.0 / static_efficiency;
}

pub fn optimalBatchSize(memory_budget: usize, kv_cache_per_token: usize, max_seq_len: usize) usize {
    return memory_budget / (kv_cache_per_token * max_seq_len);
}

// Tests
test "phi batch size" {
    const batch = phiBatchSize(4.0);
    try testing.expect(batch > 50);
}

test "can add request" {
    try testing.expect(canAddRequest(10, 32));
    try testing.expect(!canAddRequest(32, 32));
}

test "iteration step" {
    var requests = [_]Request{
        .{ .id = 0, .state = .decode, .tokens_generated = 9, .max_tokens = 10 },
        .{ .id = 1, .state = .decode, .tokens_generated = 5, .max_tokens = 10 },
    };
    const result = iterationStep(&requests);
    try testing.expectEqual(@as(usize, 1), result.completed);
    try testing.expectEqual(@as(usize, 1), result.continuing);
}

test "throughput improvement" {
    const improvement = throughputImprovement(32, 256, 512);
    try testing.expectEqual(@as(f32, 2.0), improvement);
}

test "optimal batch size" {
    const batch = optimalBatchSize(1024 * 1024, 1024, 512);
    try testing.expectEqual(@as(usize, 2), batch);
}

test "config defaults" {
    const config = BatchConfig{};
    try testing.expectEqual(@as(usize, 32), config.max_batch_size);
}
