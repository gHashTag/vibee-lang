//! Tensor Implementation for CPU Training
//! ========================================
//!
//! Minimal tensor library with automatic differentiation support.
//! φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;

/// Sacred Constants
pub const PHI: f32 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f32 = 3.0;
pub const PHOENIX: i32 = 999;

/// Tensor with gradient support
pub const Tensor = struct {
    data: []f32,
    grad: ?[]f32,
    shape: []const usize,
    requires_grad: bool,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, shape: []const usize, requires_grad: bool) !Self {
        var size: usize = 1;
        for (shape) |dim| {
            size *= dim;
        }

        const data = try allocator.alloc(f32, size);
        @memset(data, 0);

        const grad = if (requires_grad) try allocator.alloc(f32, size) else null;
        if (grad) |g| {
            @memset(g, 0);
        }

        const shape_copy = try allocator.dupe(usize, shape);

        return Self{
            .data = data,
            .grad = grad,
            .shape = shape_copy,
            .requires_grad = requires_grad,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
        if (self.grad) |g| {
            self.allocator.free(g);
        }
        self.allocator.free(@constCast(self.shape));
    }

    pub fn numel(self: Self) usize {
        var size: usize = 1;
        for (self.shape) |dim| {
            size *= dim;
        }
        return size;
    }

    pub fn fill(self: *Self, value: f32) void {
        @memset(self.data, value);
    }

    pub fn fillRandom(self: *Self, seed: u64) void {
        var rng = std.rand.DefaultPrng.init(seed);
        const random = rng.random();
        for (self.data) |*v| {
            // Xavier initialization scaled by φ
            v.* = (random.float(f32) - 0.5) * 2.0 / @sqrt(@as(f32, @floatFromInt(self.numel()))) * PHI;
        }
    }

    pub fn zeroGrad(self: *Self) void {
        if (self.grad) |g| {
            @memset(g, 0);
        }
    }

    /// Element-wise addition
    pub fn add(self: Self, other: Self, out: *Self) void {
        for (self.data, other.data, out.data) |a, b, *o| {
            o.* = a + b;
        }
    }

    /// Element-wise multiplication
    pub fn mul(self: Self, other: Self, out: *Self) void {
        for (self.data, other.data, out.data) |a, b, *o| {
            o.* = a * b;
        }
    }

    /// Matrix multiplication (2D only)
    pub fn matmul(self: Self, other: Self, out: *Self) void {
        const m = self.shape[0];
        const k = self.shape[1];
        const n = other.shape[1];

        @memset(out.data, 0);

        for (0..m) |i| {
            for (0..n) |j| {
                var dot_sum: f32 = 0;
                for (0..k) |kk| {
                    dot_sum += self.data[i * k + kk] * other.data[kk * n + j];
                }
                out.data[i * n + j] = dot_sum;
            }
        }
    }

    /// ReLU activation
    pub fn relu(self: Self, out: *Self) void {
        for (self.data, out.data) |x, *o| {
            o.* = @max(0, x);
        }
    }

    /// GELU activation (approximation)
    pub fn gelu(self: Self, out: *Self) void {
        for (self.data, out.data) |x, *o| {
            // GELU(x) ≈ 0.5 * x * (1 + tanh(sqrt(2/π) * (x + 0.044715 * x³)))
            const sqrt_2_pi: f32 = 0.7978845608;
            const coeff: f32 = 0.044715;
            const inner = sqrt_2_pi * (x + coeff * x * x * x);
            o.* = 0.5 * x * (1.0 + math.tanh(inner));
        }
    }

    /// Softmax (last dimension)
    pub fn softmax(self: Self, out: *Self) void {
        const last_dim = self.shape[self.shape.len - 1];
        const batch_size = self.numel() / last_dim;

        for (0..batch_size) |b| {
            const start = b * last_dim;
            const end = start + last_dim;
            const slice = self.data[start..end];
            const out_slice = out.data[start..end];

            // Find max for numerical stability
            var max_val: f32 = slice[0];
            for (slice[1..]) |v| {
                max_val = @max(max_val, v);
            }

            // Compute exp and sum
            var exp_sum: f32 = 0;
            for (slice, out_slice) |v, *o| {
                o.* = @exp(v - max_val);
                exp_sum += o.*;
            }

            // Normalize
            for (out_slice) |*o| {
                o.* /= exp_sum;
            }
        }
    }

    /// Cross-entropy loss
    pub fn crossEntropyLoss(self: Self, targets: []const usize) f32 {
        const batch_size = self.shape[0];
        const num_classes = self.shape[1];
        var ce_loss: f32 = 0;

        for (0..batch_size) |b| {
            const target = targets[b];
            const prob = self.data[b * num_classes + target];
            ce_loss -= @log(@max(prob, 1e-10));
        }

        return ce_loss / @as(f32, @floatFromInt(batch_size));
    }

    /// Sum all elements
    pub fn sum(self: Self) f32 {
        var total: f32 = 0;
        for (self.data) |v| {
            total += v;
        }
        return total;
    }

    /// Mean of all elements
    pub fn mean(self: Self) f32 {
        return self.sum() / @as(f32, @floatFromInt(self.numel()));
    }
};

// ============================================================================
// Tests
// ============================================================================

test "tensor basics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var t = try Tensor.init(allocator, &[_]usize{ 2, 3 }, true);
    defer t.deinit();

    try std.testing.expectEqual(@as(usize, 6), t.numel());

    t.fill(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), t.data[0]);
    try std.testing.expectEqual(@as(f32, 6.0), t.sum());
}

test "matmul" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var a = try Tensor.init(allocator, &[_]usize{ 2, 3 }, false);
    defer a.deinit();
    var b = try Tensor.init(allocator, &[_]usize{ 3, 2 }, false);
    defer b.deinit();
    var c = try Tensor.init(allocator, &[_]usize{ 2, 2 }, false);
    defer c.deinit();

    // Identity-like matrices
    a.fill(1.0);
    b.fill(1.0);

    a.matmul(b, &c);

    // Each element should be 3 (sum of 3 ones)
    try std.testing.expectEqual(@as(f32, 3.0), c.data[0]);
}

test "softmax" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var t = try Tensor.init(allocator, &[_]usize{ 1, 3 }, false);
    defer t.deinit();
    var out = try Tensor.init(allocator, &[_]usize{ 1, 3 }, false);
    defer out.deinit();

    t.data[0] = 1.0;
    t.data[1] = 2.0;
    t.data[2] = 3.0;

    t.softmax(&out);

    // Sum should be 1
    const sum = out.sum();
    try std.testing.expect(@abs(sum - 1.0) < 1e-5);
}
