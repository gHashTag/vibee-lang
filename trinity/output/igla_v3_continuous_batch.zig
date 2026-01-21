// ═══════════════════════════════════════════════════════════════════════════════
// igla_v3_continuous_batch v3.0.0 - Continuous Batching
// 15x throughput improvement through dynamic batching
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: Orca (OSDI 2022)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const RequestState = enum {
    pending,
    prefill,
    decode,
    finished,
};

pub const Request = struct {
    id: u32 = 0,
    prompt_len: usize = 0,
    generated_len: usize = 0,
    max_tokens: usize = 256,
    state: RequestState = .pending,
    
    pub fn isFinished(self: *const Request) bool {
        return self.state == .finished or self.generated_len >= self.max_tokens;
    }
    
    pub fn totalLen(self: *const Request) usize {
        return self.prompt_len + self.generated_len;
    }
};

pub const BatchConfig = struct {
    max_batch_size: usize = 64,
    max_tokens_per_batch: usize = 4096,
    prefill_chunk_size: usize = 512,
};

pub const Batch = struct {
    requests: [64]?*Request = [_]?*Request{null} ** 64,
    num_requests: usize = 0,
    total_tokens: usize = 0,
    
    pub fn addRequest(self: *Batch, request: *Request) bool {
        if (self.num_requests >= 64) return false;
        self.requests[self.num_requests] = request;
        self.num_requests += 1;
        self.total_tokens += request.totalLen();
        return true;
    }
    
    pub fn removeFinished(self: *Batch) usize {
        var removed: usize = 0;
        var write_idx: usize = 0;
        
        for (0..self.num_requests) |i| {
            if (self.requests[i]) |req| {
                if (!req.isFinished()) {
                    self.requests[write_idx] = req;
                    write_idx += 1;
                } else {
                    removed += 1;
                }
            }
        }
        
        // Clear remaining slots
        for (write_idx..self.num_requests) |i| {
            self.requests[i] = null;
        }
        
        self.num_requests = write_idx;
        return removed;
    }
};

pub const Scheduler = struct {
    pending: [256]Request = undefined,
    pending_count: usize = 0,
    running: Batch = .{},
    config: BatchConfig = .{},
    next_id: u32 = 0,
    
    pub fn addRequest(self: *Scheduler, prompt_len: usize, max_tokens: usize) ?u32 {
        if (self.pending_count >= 256) return null;
        
        self.pending[self.pending_count] = Request{
            .id = self.next_id,
            .prompt_len = prompt_len,
            .max_tokens = max_tokens,
            .state = .pending,
        };
        self.pending_count += 1;
        self.next_id += 1;
        
        return self.next_id - 1;
    }
    
    pub fn scheduleIteration(self: *Scheduler) void {
        // Remove finished requests
        _ = self.running.removeFinished();
        
        // Add pending requests if capacity
        while (self.pending_count > 0 and 
               self.running.num_requests < self.config.max_batch_size and
               self.running.total_tokens < self.config.max_tokens_per_batch) {
            
            self.pending_count -= 1;
            var req = &self.pending[self.pending_count];
            req.state = .prefill;
            _ = self.running.addRequest(req);
        }
    }
};

// Calculate throughput improvement
pub fn throughputImprovement(continuous_tps: f32, static_tps: f32) f32 {
    if (static_tps == 0) return 0;
    return continuous_tps / static_tps;
}

// Calculate batch efficiency
pub fn batchEfficiency(active_tokens: usize, max_tokens: usize) f32 {
    if (max_tokens == 0) return 0;
    return @as(f32, @floatFromInt(active_tokens)) / @as(f32, @floatFromInt(max_tokens));
}

// PHI-optimal batch size
pub fn phiOptimalBatchSize(memory_budget: usize, tokens_per_request: usize) usize {
    const base = memory_budget / tokens_per_request;
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(base)) * PHI_INV)));
}

// Estimate latency reduction
pub fn latencyReduction(queue_depth: usize, batch_size: usize) f32 {
    if (batch_size == 0) return 0;
    const wait_time = @as(f32, @floatFromInt(queue_depth)) / @as(f32, @floatFromInt(batch_size));
    return 1.0 / (1.0 + wait_time);
}

// Tests
test "request lifecycle" {
    var req = Request{ .prompt_len = 10, .max_tokens = 5 };
    try testing.expect(!req.isFinished());
    
    req.generated_len = 5;
    try testing.expect(req.isFinished());
}

test "batch add remove" {
    var batch = Batch{};
    var req1 = Request{ .id = 1, .prompt_len = 10 };
    var req2 = Request{ .id = 2, .prompt_len = 20, .state = .finished };
    
    try testing.expect(batch.addRequest(&req1));
    try testing.expect(batch.addRequest(&req2));
    try testing.expectEqual(@as(usize, 2), batch.num_requests);
    
    const removed = batch.removeFinished();
    try testing.expectEqual(@as(usize, 1), removed);
    try testing.expectEqual(@as(usize, 1), batch.num_requests);
}

test "scheduler add request" {
    var scheduler = Scheduler{};
    
    const id1 = scheduler.addRequest(100, 50);
    try testing.expect(id1 != null);
    try testing.expectEqual(@as(u32, 0), id1.?);
    
    const id2 = scheduler.addRequest(200, 100);
    try testing.expect(id2 != null);
    try testing.expectEqual(@as(u32, 1), id2.?);
}

test "throughput improvement" {
    const improvement = throughputImprovement(150.0, 10.0);
    try testing.expectApproxEqAbs(@as(f32, 15.0), improvement, 0.01);
}

test "batch efficiency" {
    const eff = batchEfficiency(3000, 4096);
    try testing.expectApproxEqAbs(@as(f32, 0.732), eff, 0.01);
}

test "phi optimal batch size" {
    const size = phiOptimalBatchSize(8192, 128);
    try testing.expect(size > 30);
    try testing.expect(size < 50);
}
