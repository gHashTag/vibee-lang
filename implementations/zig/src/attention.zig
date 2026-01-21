//! Flash Attention Implementation
//! ===============================
//!
//! Reference implementation of Flash Attention concepts.
//! For production, use optimized CUDA kernels.

const std = @import("std");
const core = @import("core.zig");

/// Flash Attention configuration
pub const FlashAttentionConfig = struct {
    num_heads: usize = 12,
    head_dim: usize = 64,
    dropout: f32 = 0.0,
    is_causal: bool = true,
    block_size: usize = 64,
};

/// Softmax with numerical stability
pub fn softmax(x: []f32, out: []f32) void {
    // Find max for numerical stability
    var max_val: f32 = x[0];
    for (x[1..]) |v| {
        if (v > max_val) max_val = v;
    }
    
    // Compute exp and sum
    var sum: f32 = 0.0;
    for (x, 0..) |v, i| {
        out[i] = @exp(v - max_val);
        sum += out[i];
    }
    
    // Normalize
    for (out) |*v| {
        v.* /= sum;
    }
}

/// Standard attention (O(N²) memory) - for reference
pub fn standardAttention(
    allocator: std.mem.Allocator,
    q: []const f32, // [seq_len, head_dim]
    k: []const f32,
    v: []const f32,
    seq_len: usize,
    head_dim: usize,
    is_causal: bool,
) ![]f32 {
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));
    
    // Allocate attention scores [seq_len, seq_len]
    var scores = try allocator.alloc(f32, seq_len * seq_len);
    defer allocator.free(scores);
    
    // Compute Q @ K^T
    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            var dot: f32 = 0.0;
            for (0..head_dim) |d| {
                dot += q[i * head_dim + d] * k[j * head_dim + d];
            }
            scores[i * seq_len + j] = dot * scale;
            
            // Apply causal mask
            if (is_causal and j > i) {
                scores[i * seq_len + j] = -std.math.inf(f32);
            }
        }
    }
    
    // Softmax per row
    var probs = try allocator.alloc(f32, seq_len * seq_len);
    defer allocator.free(probs);
    
    for (0..seq_len) |i| {
        const row_start = i * seq_len;
        softmax(scores[row_start..row_start + seq_len], probs[row_start..row_start + seq_len]);
    }
    
    // Compute attention @ V
    var output = try allocator.alloc(f32, seq_len * head_dim);
    @memset(output, 0.0);
    
    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            const prob = probs[i * seq_len + j];
            for (0..head_dim) |d| {
                output[i * head_dim + d] += prob * v[j * head_dim + d];
            }
        }
    }
    
    return output;
}

/// Flash Attention (O(N) memory) - simplified reference
/// Real Flash Attention uses tiling and fused kernels
pub fn flashAttention(
    allocator: std.mem.Allocator,
    q: []const f32,
    k: []const f32,
    v: []const f32,
    seq_len: usize,
    head_dim: usize,
    config: FlashAttentionConfig,
) ![]f32 {
    const block_size = config.block_size;
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));
    
    // Output and running statistics
    var output = try allocator.alloc(f32, seq_len * head_dim);
    @memset(output, 0.0);
    
    var row_max = try allocator.alloc(f32, seq_len);
    defer allocator.free(row_max);
    @memset(row_max, -std.math.inf(f32));
    
    var row_sum = try allocator.alloc(f32, seq_len);
    defer allocator.free(row_sum);
    @memset(row_sum, 0.0);
    
    // Process in blocks (simplified - real impl uses SRAM tiling)
    var j: usize = 0;
    while (j < seq_len) : (j += block_size) {
        const j_end = @min(j + block_size, seq_len);
        
        for (0..seq_len) |i| {
            // Skip if causal and block is fully masked
            if (config.is_causal and j > i) continue;
            
            // Compute attention scores for this block
            for (j..j_end) |jj| {
                if (config.is_causal and jj > i) continue;
                
                var dot: f32 = 0.0;
                for (0..head_dim) |d| {
                    dot += q[i * head_dim + d] * k[jj * head_dim + d];
                }
                dot *= scale;
                
                // Online softmax update
                const old_max = row_max[i];
                row_max[i] = @max(row_max[i], dot);
                
                const exp_diff = @exp(old_max - row_max[i]);
                row_sum[i] = row_sum[i] * exp_diff + @exp(dot - row_max[i]);
                
                // Update output with correction
                const weight = @exp(dot - row_max[i]);
                for (0..head_dim) |d| {
                    output[i * head_dim + d] = output[i * head_dim + d] * exp_diff + weight * v[jj * head_dim + d];
                }
            }
        }
    }
    
    // Normalize by sum
    for (0..seq_len) |i| {
        for (0..head_dim) |d| {
            output[i * head_dim + d] /= row_sum[i];
        }
    }
    
    return output;
}

// ============================================================================
// Tests
// ============================================================================

test "softmax" {
    var input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [3]f32 = undefined;
    
    softmax(&input, &output);
    
    // Sum should be 1
    var sum: f32 = 0.0;
    for (output) |v| sum += v;
    try std.testing.expect(@abs(sum - 1.0) < 1e-5);
    
    // Largest input should have largest probability
    try std.testing.expect(output[2] > output[1]);
    try std.testing.expect(output[1] > output[0]);
}

test "standard attention" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const seq_len: usize = 4;
    const head_dim: usize = 8;
    
    // Create simple test data
    var q: [seq_len * head_dim]f32 = undefined;
    var k: [seq_len * head_dim]f32 = undefined;
    var v: [seq_len * head_dim]f32 = undefined;
    
    for (0..seq_len * head_dim) |i| {
        q[i] = @as(f32, @floatFromInt(i % head_dim)) * 0.1;
        k[i] = @as(f32, @floatFromInt(i % head_dim)) * 0.1;
        v[i] = @as(f32, @floatFromInt(i % head_dim)) * 0.1;
    }
    
    const output = try standardAttention(allocator, &q, &k, &v, seq_len, head_dim, true);
    defer allocator.free(output);
    
    try std.testing.expectEqual(seq_len * head_dim, output.len);
}
