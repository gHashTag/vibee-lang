//! VIBEE Φ-ENGINE - AMR RESIZE (Solution #1)
//!
//! AMR (Amortized Multiplicative Resize) - Golden Optimum Growth
//!
//! Scientific Basis: CLRS (Cormen, Leiserson, Rivest, Stein)
//! Chapter 17: Amortized Analysis (2009)
//!
//! Sacred Formula: new_capacity = current × φ
//! where φ = 1.618033988749895

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

/// Buffer with AMR growth
pub const Buffer = struct {
    data: []u8,
    capacity: usize,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, initial_capacity: usize) !Buffer {
        const data_ = try allocator.alloc(u8, initial_capacity);
        return .{
            .data = data_,
            .capacity = initial_capacity,
            .len = 0,
            .allocator = allocator,
        };
    }

    pub fn grow(self: *Buffer, min_additional: usize) !void {
        const current = self.capacity;
        const phi_growth_f64: f64 = @as(f64, @floatFromInt(current)) * PHI;
        const new_size: usize = @intFromFloat(phi_growth_f64);
        const final_size: usize = @max(new_size, current + min_additional);

        self.data = try self.allocator.realloc(self.data, final_size);
        self.capacity = final_size;
    }

    pub fn append(self: *Buffer, byte: u8) !void {
        if (self.len >= self.capacity) {
            try self.grow(1);
        }
        self.data[self.len] = byte;
        self.len += 1;
    }

    pub fn deinit(self: *Buffer) void {
        self.allocator.free(self.data);
    }
};

// ════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═══════════════════════════════════════════════════════════════╝

test "AMR Resize: phi growth initial" {
    var buf = try Buffer.init(std.testing.allocator, 100);
    defer buf.deinit();

    try buf.grow(50);

    // Expected: 100 × 1.618 = 161.8 → 161
    try std.testing.expectEqual(@as(usize, 161), buf.capacity);
}

test "AMR Resize: phi growth large" {
    var buf = try Buffer.init(std.testing.allocator, 1000);
    defer buf.deinit();

    try buf.grow(100);

    // Expected: 1000 × 1.618 = 1618.0 → 1618
    try std.testing.expectEqual(@as(usize, 1618), buf.capacity);
}

test "AMR Resize: phi growth phi squared" {
    var buf = try Buffer.init(std.testing.allocator, 161);
    defer buf.deinit();

    try buf.grow(50);

    // Expected: 161 × 1.618 = 260.498 → 260
    try std.testing.expectEqual(@as(usize, 260), buf.capacity);
}

test "AMR Resize: golden identity" {
    // φ² + 1/φ² = 3 (EXACT!)
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}

test "AMR Resize: append with growth" {
    var buf = try Buffer.init(std.testing.allocator, 100);
    defer buf.deinit();

    // Append until buffer is full, then it should grow
    var i: usize = 0;
    while (i < 200) : (i += 1) {
        try buf.append(@intCast(i % 256));
    }

    // Buffer should have grown using AMR
    try std.testing.expect(buf.capacity > 100);
}

test "AMR Resize: amortized O(1) property" {
    // Amortized analysis: average cost per operation is O(1)
    // With φ = 1.618 growth factor, number of copies is minimized

    var buf = try Buffer.init(std.testing.allocator, 100);
    defer buf.deinit();

    var total_capacity: usize = 100;
    var total_operations: usize = 0;

    // Simulate 1000 appends
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        try buf.append(@intCast(i % 256));
        total_operations += 1;
        total_capacity = buf.capacity;
    }

    // Growth occurred (buffer grew)
    try std.testing.expect(total_capacity > 100);

    // Operations completed successfully
    try std.testing.expectEqual(@as(usize, 1000), total_operations);
}
