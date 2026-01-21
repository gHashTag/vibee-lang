//! Core types and sacred constants for VIBEE ML.

const std = @import("std");
const math = std.math;

// ============================================================================
// Sacred Constants
// ============================================================================

/// Golden ratio φ = (1 + √5) / 2
pub const PHI: f64 = 1.618033988749895;

/// φ² = φ + 1
pub const PHI_SQUARED: f64 = PHI * PHI;

/// Golden identity: φ² + 1/φ² = 3
pub const GOLDEN_IDENTITY: f64 = PHI_SQUARED + 1.0 / PHI_SQUARED;

/// Phoenix constant
pub const PHOENIX: i64 = 999;

// ============================================================================
// Tensor Types
// ============================================================================

/// Supported data types
pub const DType = enum {
    f32,
    f16,
    bf16,
    i8,
    i4,
    
    pub fn sizeBytes(self: DType) usize {
        return switch (self) {
            .f32 => 4,
            .f16, .bf16 => 2,
            .i8 => 1,
            .i4 => 1, // Packed, but minimum addressable
        };
    }
};

/// Tensor shape
pub const Shape = struct {
    dims: [4]usize = .{ 0, 0, 0, 0 },
    ndim: usize = 0,
    
    pub fn init(dims: []const usize) Shape {
        var shape = Shape{};
        shape.ndim = @min(dims.len, 4);
        for (0..shape.ndim) |i| {
            shape.dims[i] = dims[i];
        }
        return shape;
    }
    
    pub fn numel(self: Shape) usize {
        var n: usize = 1;
        for (0..self.ndim) |i| {
            n *= self.dims[i];
        }
        return n;
    }
};

/// Simple tensor structure
pub fn Tensor(comptime T: type) type {
    return struct {
        data: []T,
        shape: Shape,
        
        const Self = @This();
        
        pub fn init(allocator: std.mem.Allocator, shape: Shape) !Self {
            const data = try allocator.alloc(T, shape.numel());
            return Self{ .data = data, .shape = shape };
        }
        
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }
        
        pub fn fill(self: *Self, value: T) void {
            @memset(self.data, value);
        }
        
        pub fn get(self: Self, indices: []const usize) T {
            var idx: usize = 0;
            var stride: usize = 1;
            var i = self.shape.ndim;
            while (i > 0) {
                i -= 1;
                idx += indices[i] * stride;
                stride *= self.shape.dims[i];
            }
            return self.data[idx];
        }
    };
}

// ============================================================================
// Configuration Types
// ============================================================================

/// Training configuration
pub const TrainingConfig = struct {
    batch_size: usize = 32,
    learning_rate: f32 = 1e-4,
    weight_decay: f32 = 0.01,
    max_grad_norm: f32 = 1.0,
    mixed_precision: bool = true,
    gradient_checkpointing: bool = true,
};

/// Inference configuration
pub const InferenceConfig = struct {
    max_batch_size: usize = 32,
    max_sequence_length: usize = 4096,
    temperature: f32 = 0.7,
    top_p: f32 = 0.9,
    use_cache: bool = true,
};

// ============================================================================
// Tests
// ============================================================================

test "sacred constants" {
    // Verify golden identity: φ² + 1/φ² = 3
    try std.testing.expect(@abs(GOLDEN_IDENTITY - 3.0) < 1e-10);
    
    // Verify φ² = φ + 1
    try std.testing.expect(@abs(PHI_SQUARED - PHI - 1.0) < 1e-10);
}

test "tensor basics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const shape = Shape.init(&[_]usize{ 2, 3 });
    try std.testing.expectEqual(@as(usize, 6), shape.numel());
    
    var tensor = try Tensor(f32).init(allocator, shape);
    defer tensor.deinit(allocator);
    
    tensor.fill(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), tensor.data[0]);
}
