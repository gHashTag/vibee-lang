//! Minimal Transformer Model for CPU Training
//! ============================================
//!
//! A tiny transformer that can train on CPU.
//! φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const PHI = @import("tensor.zig").PHI;

/// Linear layer
pub const Linear = struct {
    weight: Tensor,
    bias: Tensor,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, in_features: usize, out_features: usize) !Self {
        var weight = try Tensor.init(allocator, &[_]usize{ in_features, out_features }, true);
        weight.fillRandom(42);

        var bias = try Tensor.init(allocator, &[_]usize{out_features}, true);
        bias.fill(0);

        return Self{
            .weight = weight,
            .bias = bias,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.weight.deinit();
        self.bias.deinit();
    }

    pub fn forward(self: Self, input: Tensor, output: *Tensor) void {
        // output = input @ weight + bias
        input.matmul(self.weight, output);

        // Add bias
        const out_features = self.bias.numel();
        const batch_size = output.numel() / out_features;

        for (0..batch_size) |b| {
            for (0..out_features) |i| {
                output.data[b * out_features + i] += self.bias.data[i];
            }
        }
    }

    pub fn parameters(self: *Self) [2]*Tensor {
        return [2]*Tensor{ &self.weight, &self.bias };
    }
};

/// Simple attention (single head)
pub const Attention = struct {
    query: Linear,
    key: Linear,
    value: Linear,
    output: Linear,
    head_dim: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, hidden_size: usize, head_dim: usize) !Self {
        return Self{
            .query = try Linear.init(allocator, hidden_size, head_dim),
            .key = try Linear.init(allocator, hidden_size, head_dim),
            .value = try Linear.init(allocator, hidden_size, head_dim),
            .output = try Linear.init(allocator, head_dim, hidden_size),
            .head_dim = head_dim,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.query.deinit();
        self.key.deinit();
        self.value.deinit();
        self.output.deinit();
    }
};

/// Minimal Transformer Block
pub const TransformerBlock = struct {
    attention: Attention,
    ff1: Linear,
    ff2: Linear,
    hidden_size: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, hidden_size: usize) !Self {
        const head_dim = hidden_size;
        const ff_size = hidden_size * 4;

        return Self{
            .attention = try Attention.init(allocator, hidden_size, head_dim),
            .ff1 = try Linear.init(allocator, hidden_size, ff_size),
            .ff2 = try Linear.init(allocator, ff_size, hidden_size),
            .hidden_size = hidden_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.attention.deinit();
        self.ff1.deinit();
        self.ff2.deinit();
    }
};

/// Minimal Language Model
pub const MiniLM = struct {
    embedding: Tensor,
    blocks: []TransformerBlock,
    output: Linear,
    vocab_size: usize,
    hidden_size: usize,
    num_layers: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        vocab_size: usize,
        hidden_size: usize,
        num_layers: usize,
    ) !Self {
        // Embedding table
        var embedding = try Tensor.init(allocator, &[_]usize{ vocab_size, hidden_size }, true);
        embedding.fillRandom(42);

        // Transformer blocks
        const blocks = try allocator.alloc(TransformerBlock, num_layers);
        for (blocks) |*block| {
            block.* = try TransformerBlock.init(allocator, hidden_size);
        }

        // Output projection
        const output = try Linear.init(allocator, hidden_size, vocab_size);

        return Self{
            .embedding = embedding,
            .blocks = blocks,
            .output = output,
            .vocab_size = vocab_size,
            .hidden_size = hidden_size,
            .num_layers = num_layers,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.embedding.deinit();
        for (self.blocks) |*block| {
            block.deinit();
        }
        self.allocator.free(self.blocks);
        self.output.deinit();
    }

    /// Forward pass (simplified - just embedding + output)
    pub fn forward(self: Self, input_ids: []const usize, output: *Tensor) !void {
        const seq_len = input_ids.len;

        // Lookup embeddings
        var hidden = try Tensor.init(self.allocator, &[_]usize{ seq_len, self.hidden_size }, false);
        defer hidden.deinit();

        for (input_ids, 0..) |token_id, i| {
            for (0..self.hidden_size) |j| {
                hidden.data[i * self.hidden_size + j] = self.embedding.data[token_id * self.hidden_size + j];
            }
        }

        // Apply GELU activation (simplified)
        var activated = try Tensor.init(self.allocator, &[_]usize{ seq_len, self.hidden_size }, false);
        defer activated.deinit();
        hidden.gelu(&activated);

        // Output projection
        self.output.forward(activated, output);

        // Softmax
        output.softmax(output);
    }

    /// Count total parameters
    pub fn numParameters(self: Self) usize {
        var total: usize = self.embedding.numel();
        total += self.output.weight.numel() + self.output.bias.numel();

        for (self.blocks) |block| {
            // Attention
            total += block.attention.query.weight.numel() + block.attention.query.bias.numel();
            total += block.attention.key.weight.numel() + block.attention.key.bias.numel();
            total += block.attention.value.weight.numel() + block.attention.value.bias.numel();
            total += block.attention.output.weight.numel() + block.attention.output.bias.numel();
            // FFN
            total += block.ff1.weight.numel() + block.ff1.bias.numel();
            total += block.ff2.weight.numel() + block.ff2.bias.numel();
        }

        return total;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "linear layer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var linear = try Linear.init(allocator, 4, 2);
    defer linear.deinit();

    var input = try Tensor.init(allocator, &[_]usize{ 1, 4 }, false);
    defer input.deinit();
    input.fill(1.0);

    var output = try Tensor.init(allocator, &[_]usize{ 1, 2 }, false);
    defer output.deinit();

    linear.forward(input, &output);

    // Output should be non-zero
    try std.testing.expect(output.data[0] != 0 or output.data[1] != 0);
}

test "mini lm" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Tiny model: vocab=100, hidden=32, layers=1
    var model = try MiniLM.init(allocator, 100, 32, 1);
    defer model.deinit();

    const num_params = model.numParameters();
    std.debug.print("\nMiniLM parameters: {d}\n", .{num_params});

    // Forward pass
    const input_ids = [_]usize{ 1, 2, 3 };
    var output = try Tensor.init(allocator, &[_]usize{ 3, 100 }, false);
    defer output.deinit();

    try model.forward(&input_ids, &output);

    // Check softmax output sums to ~1 per position
    var sum: f32 = 0;
    for (0..100) |i| {
        sum += output.data[i];
    }
    try std.testing.expect(@abs(sum - 1.0) < 1e-4);
}
