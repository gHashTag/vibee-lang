// TVC HybridBigInt - Optimal Memory/Speed Trade-off
// Uses packed storage, unpacked computation with SIMD acceleration
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const tvc_bigint = @import("tvc_bigint.zig");
const tvc_packed = @import("tvc_packed.zig");

pub const MAX_TRITS = 256;
pub const TRITS_PER_BYTE = 5;
pub const MAX_PACKED_BYTES = (MAX_TRITS + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
pub const Trit = i8;

// SIMD types for 32-trit parallel operations
pub const Vec32i8 = @Vector(32, i8);
pub const Vec32i16 = @Vector(32, i16);
pub const SIMD_WIDTH = 32;
pub const SIMD_CHUNKS = MAX_TRITS / SIMD_WIDTH; // 256 / 32 = 8

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD add 32 trits in parallel with carry propagation
pub fn simdAddTrits(a: Vec32i8, b: Vec32i8) struct { sum: Vec32i8, carry: Vec32i8 } {
    const a_wide: Vec32i16 = a;
    const b_wide: Vec32i16 = b;
    const sum_wide = a_wide + b_wide;

    const ones: Vec32i16 = @splat(1);
    const neg_ones: Vec32i16 = @splat(-1);
    const threes: Vec32i16 = @splat(3);

    const high_mask = sum_wide > ones;
    const low_mask = sum_wide < neg_ones;

    var normalized = sum_wide;
    normalized = @select(i16, high_mask, sum_wide - threes, normalized);
    normalized = @select(i16, low_mask, sum_wide + threes, normalized);

    var carry: Vec32i16 = @splat(0);
    carry = @select(i16, high_mask, ones, carry);
    carry = @select(i16, low_mask, neg_ones, carry);

    var sum_result: Vec32i8 = undefined;
    var carry_result: Vec32i8 = undefined;

    inline for (0..32) |i| {
        sum_result[i] = @intCast(normalized[i]);
        carry_result[i] = @intCast(carry[i]);
    }

    return .{ .sum = sum_result, .carry = carry_result };
}

/// SIMD negate 32 trits
pub fn simdNegate(v: Vec32i8) Vec32i8 {
    const zero: Vec32i8 = @splat(0);
    return zero - v;
}

/// SIMD dot product of 32 trits (returns scalar)
pub fn simdDotProduct(a: Vec32i8, b: Vec32i8) i32 {
    const a_wide: Vec32i16 = a;
    const b_wide: Vec32i16 = b;
    const prod = a_wide * b_wide;
    return @reduce(.Add, prod);
}

/// SIMD check if all zeros
pub fn simdIsZero(v: Vec32i8) bool {
    const zero: Vec32i8 = @splat(0);
    return @reduce(.Or, v != zero) == false;
}

/// Storage mode for HybridBigInt
pub const StorageMode = enum {
    /// Packed: 5 trits per byte, memory efficient
    packed_mode,
    /// Unpacked: 1 trit per byte, compute efficient
    unpacked_mode,
};

/// HybridBigInt: Best of both worlds
/// - Stores in packed format (4.5x memory savings)
/// - Unpacks lazily for computation
/// - Re-packs after computation if needed
pub const HybridBigInt = struct {
    /// Packed storage (always valid)
    packed_data: [MAX_PACKED_BYTES]u8,
    /// Unpacked cache (valid only when mode == unpacked_mode)
    unpacked_cache: [MAX_TRITS]Trit,
    /// Current storage mode
    mode: StorageMode,
    /// Number of significant trits
    trit_len: usize,
    /// Dirty flag: unpacked cache modified, needs re-pack
    dirty: bool,

    const Self = @This();

    /// Create zero value
    pub fn zero() Self {
        const zero_pack = tvc_packed.encodePack(.{ 0, 0, 0, 0, 0 });
        return Self{
            .packed_data = [_]u8{zero_pack} ** MAX_PACKED_BYTES,
            .unpacked_cache = [_]Trit{0} ** MAX_TRITS,
            .mode = .packed_mode,
            .trit_len = 1,
            .dirty = false,
        };
    }

    /// Create from i64
    pub fn fromI64(value: i64) Self {
        var result = Self.zero();
        if (value == 0) return result;

        var v = value;
        var pos: usize = 0;

        while (v != 0 and pos < MAX_TRITS) {
            var rem = @mod(v, @as(i64, 3));
            if (rem == 2) rem = -1;
            result.unpacked_cache[pos] = @intCast(rem);
            v = @divFloor(v - rem, 3);
            pos += 1;
        }

        result.trit_len = if (pos == 0) 1 else pos;
        result.mode = .unpacked_mode;
        result.dirty = true;
        return result;
    }

    /// Convert to i64
    pub fn toI64(self: *Self) i64 {
        self.ensureUnpacked();
        var result: i64 = 0;
        var power: i64 = 1;
        for (0..self.trit_len) |i| {
            result += @as(i64, self.unpacked_cache[i]) * power;
            power *= 3;
        }
        return result;
    }

    /// Get trit at position (auto-unpacks if needed)
    pub fn getTrit(self: *Self, pos: usize) Trit {
        if (pos >= self.trit_len) return 0;
        self.ensureUnpacked();
        return self.unpacked_cache[pos];
    }

    /// Set trit at position (marks dirty)
    pub fn setTrit(self: *Self, pos: usize, value: Trit) void {
        if (pos >= MAX_TRITS) return;
        self.ensureUnpacked();
        self.unpacked_cache[pos] = value;
        self.dirty = true;
        if (pos >= self.trit_len and value != 0) {
            self.trit_len = pos + 1;
        }
    }

    /// Ensure unpacked cache is valid
    pub fn ensureUnpacked(self: *Self) void {
        if (self.mode == .unpacked_mode) return;

        // Unpack from packed_data to unpacked_cache
        const num_packs = (self.trit_len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
        for (0..num_packs) |pack_idx| {
            const trits = tvc_packed.decodePack(self.packed_data[pack_idx]);
            const base = pack_idx * TRITS_PER_BYTE;
            for (0..TRITS_PER_BYTE) |j| {
                if (base + j < MAX_TRITS) {
                    self.unpacked_cache[base + j] = trits[j];
                }
            }
        }
        self.mode = .unpacked_mode;
    }

    /// Pack the unpacked cache back to packed storage
    pub fn pack(self: *Self) void {
        if (!self.dirty and self.mode == .packed_mode) return;

        const num_packs = (self.trit_len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
        for (0..num_packs) |pack_idx| {
            const base = pack_idx * TRITS_PER_BYTE;
            var trits: [5]Trit = .{ 0, 0, 0, 0, 0 };
            for (0..TRITS_PER_BYTE) |j| {
                if (base + j < self.trit_len) {
                    trits[j] = self.unpacked_cache[base + j];
                }
            }
            self.packed_data[pack_idx] = tvc_packed.encodePack(trits);
        }
        self.mode = .packed_mode;
        self.dirty = false;
    }

    /// Memory usage in bytes (packed)
    pub fn memoryUsage(self: *const Self) usize {
        return (self.trit_len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
    }

    /// Normalize: remove leading zeros
    fn normalize(self: *Self) void {
        self.ensureUnpacked();
        while (self.trit_len > 1 and self.unpacked_cache[self.trit_len - 1] == 0) {
            self.trit_len -= 1;
        }
        self.dirty = true;
    }

    /// Check if zero
    pub fn isZero(self: *Self) bool {
        self.ensureUnpacked();
        return self.trit_len == 1 and self.unpacked_cache[0] == 0;
    }

    /// Check if negative
    pub fn isNegative(self: *Self) bool {
        self.ensureUnpacked();
        return self.unpacked_cache[self.trit_len - 1] < 0;
    }

    /// Negate
    pub fn negate(self: *const Self) Self {
        var result = Self.zero();
        result.trit_len = self.trit_len;
        result.mode = .unpacked_mode;
        result.dirty = true;

        // Copy and negate from self (may need to unpack)
        var self_mut = self.*;
        self_mut.ensureUnpacked();

        for (0..self.trit_len) |i| {
            result.unpacked_cache[i] = -self_mut.unpacked_cache[i];
        }
        return result;
    }

    /// Add two HybridBigInts (uses unpacked for speed)
    pub fn add(a: *Self, b: *Self) Self {
        a.ensureUnpacked();
        b.ensureUnpacked();

        var result = Self.zero();
        result.mode = .unpacked_mode;
        result.dirty = true;

        var carry: Trit = 0;
        const max_len = @max(a.trit_len, b.trit_len);

        for (0..max_len + 1) |i| {
            if (i >= MAX_TRITS) break;

            const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;

            var sum: i16 = a_trit + b_trit + carry;
            carry = 0;

            while (sum > 1) {
                sum -= 3;
                carry += 1;
            }
            while (sum < -1) {
                sum += 3;
                carry -= 1;
            }

            result.unpacked_cache[i] = @intCast(sum);
        }

        result.trit_len = @min(max_len + 1, MAX_TRITS);
        result.normalize();
        return result;
    }

    /// SIMD-accelerated add (32 trits at a time)
    /// Uses SIMD for parallel addition, then sequential carry propagation
    pub fn addSimd(a: *Self, b: *Self) Self {
        a.ensureUnpacked();
        b.ensureUnpacked();

        var result = Self.zero();
        result.mode = .unpacked_mode;
        result.dirty = true;

        const max_len = @max(a.trit_len, b.trit_len);
        const num_chunks = (max_len + SIMD_WIDTH - 1) / SIMD_WIDTH;

        // Phase 1: SIMD parallel addition (no carry propagation yet)
        var carries: [SIMD_CHUNKS + 1][SIMD_WIDTH]Trit = undefined;

        for (0..num_chunks) |chunk| {
            const base = chunk * SIMD_WIDTH;

            var a_vec: Vec32i8 = undefined;
            var b_vec: Vec32i8 = undefined;

            inline for (0..SIMD_WIDTH) |i| {
                const idx = base + i;
                a_vec[i] = if (idx < a.trit_len) a.unpacked_cache[idx] else 0;
                b_vec[i] = if (idx < b.trit_len) b.unpacked_cache[idx] else 0;
            }

            const simd_result = simdAddTrits(a_vec, b_vec);

            inline for (0..SIMD_WIDTH) |i| {
                const idx = base + i;
                if (idx < MAX_TRITS) {
                    result.unpacked_cache[idx] = simd_result.sum[i];
                }
                carries[chunk][i] = simd_result.carry[i];
            }
        }

        // Phase 2: Sequential carry propagation (necessary for correctness)
        var carry: Trit = 0;
        for (0..max_len + 1) |i| {
            if (i >= MAX_TRITS) break;

            const chunk = i / SIMD_WIDTH;
            const offset = i % SIMD_WIDTH;

            var val: i16 = result.unpacked_cache[i];

            // Add carry from SIMD (shifted by 1 position)
            if (i > 0) {
                const prev_chunk = (i - 1) / SIMD_WIDTH;
                const prev_offset = (i - 1) % SIMD_WIDTH;
                if (prev_chunk < num_chunks) {
                    val += carries[prev_chunk][prev_offset];
                }
            }

            val += carry;
            carry = 0;

            while (val > 1) {
                val -= 3;
                carry += 1;
            }
            while (val < -1) {
                val += 3;
                carry -= 1;
            }

            result.unpacked_cache[i] = @intCast(val);
            _ = chunk;
            _ = offset;
        }

        result.trit_len = @min(max_len + 1, MAX_TRITS);
        result.normalize();
        return result;
    }

    /// Subtract
    pub fn sub(a: *Self, b: *Self) Self {
        var neg_b = b.negate();
        return a.add(&neg_b);
    }

    /// Multiply two HybridBigInts
    pub fn mul(a: *Self, b: *Self) Self {
        a.ensureUnpacked();
        b.ensureUnpacked();

        var result = Self.zero();
        result.mode = .unpacked_mode;
        result.dirty = true;

        for (0..a.trit_len) |i| {
            const a_trit = a.unpacked_cache[i];
            if (a_trit == 0) continue;

            var carry: Trit = 0;
            for (0..b.trit_len) |j| {
                if (i + j >= MAX_TRITS) break;

                var prod: i16 = @as(i16, a_trit) * @as(i16, b.unpacked_cache[j]);
                prod += result.unpacked_cache[i + j];
                prod += carry;
                carry = 0;

                while (prod > 1) {
                    prod -= 3;
                    carry += 1;
                }
                while (prod < -1) {
                    prod += 3;
                    carry -= 1;
                }

                result.unpacked_cache[i + j] = @intCast(prod);
            }

            if (carry != 0 and i + b.trit_len < MAX_TRITS) {
                result.unpacked_cache[i + b.trit_len] += carry;
            }
        }

        result.trit_len = @min(a.trit_len + b.trit_len, MAX_TRITS);
        result.normalize();
        return result;
    }

    /// SIMD dot product (for VSA similarity)
    pub fn dotProduct(a: *Self, b: *Self) i32 {
        a.ensureUnpacked();
        b.ensureUnpacked();

        var total: i32 = 0;
        const min_len = @min(a.trit_len, b.trit_len);
        const num_chunks = min_len / SIMD_WIDTH;

        // SIMD chunks
        for (0..num_chunks) |chunk| {
            const base = chunk * SIMD_WIDTH;

            var a_vec: Vec32i8 = undefined;
            var b_vec: Vec32i8 = undefined;

            inline for (0..SIMD_WIDTH) |i| {
                a_vec[i] = a.unpacked_cache[base + i];
                b_vec[i] = b.unpacked_cache[base + i];
            }

            total += simdDotProduct(a_vec, b_vec);
        }

        // Remainder (scalar)
        const remainder_start = num_chunks * SIMD_WIDTH;
        for (remainder_start..min_len) |i| {
            total += @as(i32, a.unpacked_cache[i]) * @as(i32, b.unpacked_cache[i]);
        }

        return total;
    }

    /// Convert from TVCBigInt
    pub fn fromBigInt(big: *const tvc_bigint.TVCBigInt) Self {
        var result = Self.zero();
        result.mode = .unpacked_mode;
        result.dirty = true;
        for (0..big.len) |i| {
            result.unpacked_cache[i] = big.trits[i];
        }
        result.trit_len = big.len;
        return result;
    }

    /// Convert to TVCBigInt
    pub fn toBigInt(self: *Self) tvc_bigint.TVCBigInt {
        self.ensureUnpacked();
        var result = tvc_bigint.TVCBigInt.zero();
        for (0..self.trit_len) |i| {
            result.trits[i] = self.unpacked_cache[i];
        }
        result.len = self.trit_len;
        return result;
    }

    /// Convert from PackedBigInt
    pub fn fromPacked(pbi: *const tvc_packed.PackedBigInt) Self {
        var result = Self.zero();
        // Copy packed data directly
        for (0..tvc_packed.MAX_PACKED_BYTES) |i| {
            if (i < MAX_PACKED_BYTES) {
                result.packed_data[i] = pbi.data[i];
            }
        }
        result.trit_len = pbi.trit_len;
        result.mode = .packed_mode;
        result.dirty = false;
        return result;
    }

    /// Convert to PackedBigInt
    pub fn toPacked(self: *Self) tvc_packed.PackedBigInt {
        self.pack(); // Ensure packed
        var result = tvc_packed.PackedBigInt.zero();
        for (0..MAX_PACKED_BYTES) |i| {
            if (i < tvc_packed.MAX_PACKED_BYTES) {
                result.data[i] = self.packed_data[i];
            }
        }
        result.trit_len = self.trit_len;
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HybridBigInt fromI64 and toI64" {
    const cases = [_]i64{ 0, 1, -1, 10, -10, 100, -100, 12345, -12345 };
    for (cases) |val| {
        var hybrid = HybridBigInt.fromI64(val);
        const back = hybrid.toI64();
        try std.testing.expectEqual(val, back);
    }
}

test "HybridBigInt addition" {
    var a = HybridBigInt.fromI64(123);
    var b = HybridBigInt.fromI64(456);
    var sum = a.add(&b);
    try std.testing.expectEqual(@as(i64, 579), sum.toI64());
}

test "HybridBigInt multiplication" {
    var a = HybridBigInt.fromI64(12);
    var b = HybridBigInt.fromI64(34);
    var prod = a.mul(&b);
    try std.testing.expectEqual(@as(i64, 408), prod.toI64());
}

test "HybridBigInt pack/unpack roundtrip" {
    var hybrid = HybridBigInt.fromI64(12345);
    const val1 = hybrid.toI64();

    // Force pack
    hybrid.pack();
    try std.testing.expectEqual(StorageMode.packed_mode, hybrid.mode);

    // Force unpack via getTrit
    _ = hybrid.getTrit(0);
    try std.testing.expectEqual(StorageMode.unpacked_mode, hybrid.mode);

    const val2 = hybrid.toI64();
    try std.testing.expectEqual(val1, val2);
}

test "HybridBigInt memory efficiency" {
    var hybrid = HybridBigInt.fromI64(123456789);
    hybrid.pack();
    const mem = hybrid.memoryUsage();
    // 18 trits / 5 = 4 bytes (vs 18 bytes unpacked)
    try std.testing.expect(mem <= 4);
}

test "HybridBigInt conversion from BigInt" {
    const val: i64 = 12345;
    const big = tvc_bigint.TVCBigInt.fromI64(val);
    var hybrid = HybridBigInt.fromBigInt(&big);
    try std.testing.expectEqual(val, hybrid.toI64());
}

test "HybridBigInt conversion to BigInt" {
    var hybrid = HybridBigInt.fromI64(12345);
    const big = hybrid.toBigInt();
    try std.testing.expectEqual(@as(i64, 12345), big.toI64());
}

test "SIMD addSimd correctness" {
    const cases = [_][2]i64{
        .{ 123, 456 },
        .{ -100, 200 },
        .{ 12345, 67890 },
        .{ -99999, 99999 },
        .{ 123456789, 987654321 },
    };

    for (cases) |pair| {
        var a = HybridBigInt.fromI64(pair[0]);
        var b = HybridBigInt.fromI64(pair[1]);

        var sum_scalar = a.add(&b);
        var sum_simd = a.addSimd(&b);

        try std.testing.expectEqual(sum_scalar.toI64(), sum_simd.toI64());
    }
}

test "SIMD dotProduct" {
    var a = HybridBigInt.fromI64(12345);
    var b = HybridBigInt.fromI64(12345);

    const dot = a.dotProduct(&b);
    // dot product of identical vectors = sum of squares of trits
    // For balanced ternary, each trit is -1, 0, or 1, so trit^2 = 0 or 1
    try std.testing.expect(dot > 0);
}

test "SIMD functions" {
    // Test simdAddTrits
    const a_vec: Vec32i8 = @splat(1);
    const b_vec: Vec32i8 = @splat(1);

    const result = simdAddTrits(a_vec, b_vec);
    // 1 + 1 = 2, which normalizes to -1 with carry +1
    try std.testing.expectEqual(@as(i8, -1), result.sum[0]);
    try std.testing.expectEqual(@as(i8, 1), result.carry[0]);

    // Test simdNegate
    const neg = simdNegate(a_vec);
    try std.testing.expectEqual(@as(i8, -1), neg[0]);

    // Test simdIsZero
    const zero_vec: Vec32i8 = @splat(0);
    try std.testing.expect(simdIsZero(zero_vec));
    try std.testing.expect(!simdIsZero(a_vec));
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmarks() void {
    const iterations: u64 = 100000;
    std.debug.print("\nHybrid vs Packed vs Unpacked BigInt Benchmarks\n", .{});
    std.debug.print("==============================================\n\n", .{});

    const val_a: i64 = 123456789;
    const val_b: i64 = 987654321;

    // Create all three types
    const unpacked_a = tvc_bigint.TVCBigInt.fromI64(val_a);
    const unpacked_b = tvc_bigint.TVCBigInt.fromI64(val_b);
    const packed_a = tvc_packed.PackedBigInt.fromI64(val_a);
    const packed_b = tvc_packed.PackedBigInt.fromI64(val_b);
    var hybrid_a = HybridBigInt.fromI64(val_a);
    var hybrid_b = HybridBigInt.fromI64(val_b);

    std.debug.print("Memory comparison:\n", .{});
    std.debug.print("  Unpacked: {} bytes\n", .{unpacked_a.len});
    std.debug.print("  Packed:   {} bytes\n", .{packed_a.memoryUsage()});
    hybrid_a.pack();
    std.debug.print("  Hybrid:   {} bytes (packed)\n\n", .{hybrid_a.memoryUsage()});

    std.debug.print("Addition x {} iterations:\n", .{iterations});

    // Unpacked benchmark
    const unpacked_start = std.time.nanoTimestamp();
    var unpacked_result = tvc_bigint.TVCBigInt.zero();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        unpacked_result = unpacked_a.addScalar(&unpacked_b);
    }
    const unpacked_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(unpacked_result);
    const unpacked_ns = @as(u64, @intCast(unpacked_end - unpacked_start));

    // Packed benchmark
    const packed_start = std.time.nanoTimestamp();
    var packed_result = tvc_packed.PackedBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        packed_result = packed_a.add(&packed_b);
    }
    const packed_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(packed_result);
    const packed_ns = @as(u64, @intCast(packed_end - packed_start));

    // Hybrid benchmark
    hybrid_a = HybridBigInt.fromI64(val_a);
    hybrid_b = HybridBigInt.fromI64(val_b);
    const hybrid_start = std.time.nanoTimestamp();
    var hybrid_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        hybrid_result = hybrid_a.add(&hybrid_b);
    }
    const hybrid_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(hybrid_result);
    const hybrid_ns = @as(u64, @intCast(hybrid_end - hybrid_start));

    std.debug.print("  Unpacked: {} ns ({} ns/op)\n", .{ unpacked_ns, unpacked_ns / iterations });
    std.debug.print("  Packed:   {} ns ({} ns/op)\n", .{ packed_ns, packed_ns / iterations });
    std.debug.print("  Hybrid:   {} ns ({} ns/op)\n\n", .{ hybrid_ns, hybrid_ns / iterations });

    const hybrid_vs_packed: f64 = @as(f64, @floatFromInt(packed_ns)) / @as(f64, @floatFromInt(hybrid_ns));
    const hybrid_vs_unpacked: f64 = @as(f64, @floatFromInt(unpacked_ns)) / @as(f64, @floatFromInt(hybrid_ns));

    std.debug.print("Hybrid speedup:\n", .{});
    std.debug.print("  vs Packed:   {d:.2}x\n", .{hybrid_vs_packed});
    std.debug.print("  vs Unpacked: {d:.2}x\n", .{hybrid_vs_unpacked});

    // SIMD benchmark
    std.debug.print("\nSIMD Addition x {} iterations:\n", .{iterations});

    hybrid_a = HybridBigInt.fromI64(val_a);
    hybrid_b = HybridBigInt.fromI64(val_b);
    const simd_start = std.time.nanoTimestamp();
    var simd_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        simd_result = hybrid_a.addSimd(&hybrid_b);
    }
    const simd_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(simd_result);
    const simd_ns = @as(u64, @intCast(simd_end - simd_start));

    std.debug.print("  Hybrid SIMD: {} ns ({} ns/op)\n", .{ simd_ns, simd_ns / iterations });

    const simd_vs_scalar: f64 = @as(f64, @floatFromInt(hybrid_ns)) / @as(f64, @floatFromInt(simd_ns));
    std.debug.print("  SIMD speedup vs scalar: {d:.2}x\n", .{simd_vs_scalar});

    // Dot product benchmark
    std.debug.print("\nDot Product x {} iterations:\n", .{iterations});

    hybrid_a = HybridBigInt.fromI64(val_a);
    hybrid_b = HybridBigInt.fromI64(val_b);
    const dot_start = std.time.nanoTimestamp();
    var dot_result: i32 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        dot_result = hybrid_a.dotProduct(&hybrid_b);
    }
    const dot_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(dot_result);
    const dot_ns = @as(u64, @intCast(dot_end - dot_start));

    std.debug.print("  Dot product: {} ns ({} ns/op)\n", .{ dot_ns, dot_ns / iterations });

    std.debug.print("\nResults match:\n", .{});
    std.debug.print("  Unpacked == Packed: {}\n", .{unpacked_result.toI64() == packed_result.toI64()});
    std.debug.print("  Unpacked == Hybrid: {}\n", .{unpacked_result.toI64() == hybrid_result.toI64()});
    std.debug.print("  Hybrid == SIMD:     {}\n", .{hybrid_result.toI64() == simd_result.toI64()});
}

pub fn main() !void {
    runBenchmarks();
}
