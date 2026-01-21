//! CPU Training Loop
//! ==================
//!
//! Minimal training implementation with SGD.
//! φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const MiniLM = @import("model.zig").MiniLM;
const PHI = @import("tensor.zig").PHI;
const PHOENIX = @import("tensor.zig").PHOENIX;

/// Training configuration
pub const TrainingConfig = struct {
    learning_rate: f32 = 0.001,
    weight_decay: f32 = 0.01,
    max_steps: usize = 1000,
    log_interval: usize = 100,
    seed: u64 = 42,
};

/// SGD optimizer with weight decay
pub const SGD = struct {
    lr: f32,
    weight_decay: f32,

    const Self = @This();

    pub fn init(lr: f32, weight_decay: f32) Self {
        return Self{
            .lr = lr,
            .weight_decay = weight_decay,
        };
    }

    pub fn step(self: Self, param: *Tensor) void {
        if (param.grad) |grad| {
            for (param.data, grad) |*p, g| {
                // Weight decay
                p.* -= self.lr * self.weight_decay * p.*;
                // Gradient step
                p.* -= self.lr * g;
            }
        }
    }
};

/// Lion optimizer (memory efficient)
pub const Lion = struct {
    lr: f32,
    beta1: f32,
    beta2: f32,
    weight_decay: f32,
    momentum: std.AutoHashMap(*Tensor, []f32),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, lr: f32, weight_decay: f32) Self {
        return Self{
            .lr = lr,
            .beta1 = 0.9,
            .beta2 = 0.99,
            .weight_decay = weight_decay,
            .momentum = std.AutoHashMap(*Tensor, []f32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.momentum.valueIterator();
        while (it.next()) |m| {
            self.allocator.free(m.*);
        }
        self.momentum.deinit();
    }

    pub fn step(self: *Self, param: *Tensor) !void {
        if (param.grad) |grad| {
            // Get or create momentum
            const m = self.momentum.get(param) orelse blk: {
                const new_m = try self.allocator.alloc(f32, param.numel());
                @memset(new_m, 0);
                try self.momentum.put(param, new_m);
                break :blk new_m;
            };

            for (param.data, grad, m) |*p, g, *mom| {
                // Weight decay
                p.* *= (1.0 - self.lr * self.weight_decay);

                // Lion update: sign of interpolation
                const update = self.beta1 * mom.* + (1.0 - self.beta1) * g;
                p.* -= self.lr * std.math.sign(update);

                // Update momentum
                mom.* = self.beta2 * mom.* + (1.0 - self.beta2) * g;
            }
        }
    }
};

/// Simple training data generator
pub const DataGenerator = struct {
    vocab_size: usize,
    seq_length: usize,
    rng: std.rand.DefaultPrng,

    const Self = @This();

    pub fn init(vocab_size: usize, seq_length: usize, seed: u64) Self {
        return Self{
            .vocab_size = vocab_size,
            .seq_length = seq_length,
            .rng = std.rand.DefaultPrng.init(seed),
        };
    }

    pub fn nextBatch(self: *Self, input: []usize, target: []usize) void {
        const random = self.rng.random();
        for (0..self.seq_length) |i| {
            input[i] = random.intRangeAtMost(usize, 0, self.vocab_size - 1);
            // Target is next token (shifted by 1)
            target[i] = if (i + 1 < self.seq_length)
                input[i + 1]
            else
                random.intRangeAtMost(usize, 0, self.vocab_size - 1);
        }
    }
};

/// Training loop
pub fn train(
    allocator: std.mem.Allocator,
    model: *MiniLM,
    config: TrainingConfig,
) !void {
    std.debug.print("\n", .{});
    std.debug.print("═" ** 60 ++ "\n", .{});
    std.debug.print("           VIBEE ML CPU Training v3000\n", .{});
    std.debug.print("═" ** 60 ++ "\n", .{});
    std.debug.print("  Model: MiniLM ({d} params)\n", .{model.numParameters()});
    std.debug.print("  Learning Rate: {d:.6}\n", .{config.learning_rate});
    std.debug.print("  Weight Decay: {d:.4}\n", .{config.weight_decay});
    std.debug.print("  Max Steps: {d}\n", .{config.max_steps});
    std.debug.print("  Sacred: φ² + 1/φ² = {d:.1}\n", .{PHI * PHI + 1.0 / (PHI * PHI)});
    std.debug.print("═" ** 60 ++ "\n\n", .{});

    var optimizer = SGD.init(config.learning_rate, config.weight_decay);
    var data_gen = DataGenerator.init(model.vocab_size, 8, config.seed);

    const input = try allocator.alloc(usize, 8);
    defer allocator.free(input);
    const target = try allocator.alloc(usize, 8);
    defer allocator.free(target);

    var output = try Tensor.init(allocator, &[_]usize{ 8, model.vocab_size }, false);
    defer output.deinit();

    var total_loss: f32 = 0;
    var step: usize = 0;

    while (step < config.max_steps) : (step += 1) {
        // Generate batch
        data_gen.nextBatch(input, target);

        // Forward pass
        try model.forward(input, &output);

        // Compute loss
        const loss = output.crossEntropyLoss(target);
        total_loss += loss;

        // Backward pass (simplified - just update embedding)
        // In a full implementation, we'd compute gradients through the network
        computeEmbeddingGradients(model, input, target, &output);

        // Optimizer step
        optimizer.step(&model.embedding);

        // Zero gradients
        model.embedding.zeroGrad();

        // Logging
        if ((step + 1) % config.log_interval == 0) {
            const avg_loss = total_loss / @as(f32, @floatFromInt(config.log_interval));
            std.debug.print("Step {d:>5}/{d}: loss = {d:.4}\n", .{ step + 1, config.max_steps, avg_loss });
            total_loss = 0;
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("═" ** 60 ++ "\n", .{});
    std.debug.print("           Training Complete!\n", .{});
    std.debug.print("           PHOENIX = {d}\n", .{PHOENIX});
    std.debug.print("═" ** 60 ++ "\n", .{});
}

/// Simplified gradient computation for embedding
fn computeEmbeddingGradients(model: *MiniLM, input: []const usize, target: []const usize, output: *Tensor) void {
    if (model.embedding.grad) |grad| {
        const seq_len = input.len;

        for (0..seq_len) |i| {
            const token_id = input[i];
            const target_id = target[i];

            // Gradient of cross-entropy w.r.t. softmax output
            for (0..model.vocab_size) |j| {
                const prob = output.data[i * model.vocab_size + j];
                const target_prob: f32 = if (j == target_id) 1.0 else 0.0;
                const grad_output = prob - target_prob;

                // Propagate to embedding (simplified)
                for (0..model.hidden_size) |k| {
                    grad[token_id * model.hidden_size + k] += grad_output * 0.01;
                }
            }
        }
    }
}

// ============================================================================
// Main entry point for training
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create tiny model
    var model = try MiniLM.init(allocator, 100, 32, 1);
    defer model.deinit();

    // Train
    const config = TrainingConfig{
        .learning_rate = 0.01,
        .weight_decay = 0.001,
        .max_steps = 500,
        .log_interval = 50,
    };

    try train(allocator, &model, config);
}

// ============================================================================
// Tests
// ============================================================================

test "sgd step" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var param = try Tensor.init(allocator, &[_]usize{4}, true);
    defer param.deinit();
    param.fill(1.0);
    if (param.grad) |g| {
        @memset(g, 0.1);
    }

    var optimizer = SGD.init(0.1, 0.0);
    optimizer.step(&param);

    // param should decrease
    try std.testing.expect(param.data[0] < 1.0);
}

test "data generator" {
    var gen = DataGenerator.init(100, 8, 42);

    var input: [8]usize = undefined;
    var target: [8]usize = undefined;

    gen.nextBatch(&input, &target);

    // All values should be in range
    for (input) |v| {
        try std.testing.expect(v < 100);
    }
}
