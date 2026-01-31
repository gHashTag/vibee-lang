const std = @import("std");
const tvc_bigint = @import("tvc_bigint.zig");

pub const TRITS_PER_BYTE: usize = 5;
pub const MAX_PACKED_BYTES: usize = 52;
pub const MAX_TRITS: usize = MAX_PACKED_BYTES * TRITS_PER_BYTE;
pub const Trit = i8;

pub fn encodePack(trits: [5]i8) u8 {
    const t0: u16 = @intCast(@as(i16, trits[0]) + 1);
    const t1: u16 = @intCast(@as(i16, trits[1]) + 1);
    const t2: u16 = @intCast(@as(i16, trits[2]) + 1);
    const t3: u16 = @intCast(@as(i16, trits[3]) + 1);
    const t4: u16 = @intCast(@as(i16, trits[4]) + 1);
    const value = t0 * 1 + t1 * 3 + t2 * 9 + t3 * 27 + t4 * 81;
    return @intCast(value);
}

pub fn decodePack(pack_val: u8) [5]i8 {
    var value: u16 = pack_val;
    const d0 = value % 3;
    value /= 3;
    const d1 = value % 3;
    value /= 3;
    const d2 = value % 3;
    value /= 3;
    const d3 = value % 3;
    value /= 3;
    const d4 = value % 3;
    return .{
        @as(i8, @intCast(d0)) - 1,
        @as(i8, @intCast(d1)) - 1,
        @as(i8, @intCast(d2)) - 1,
        @as(i8, @intCast(d3)) - 1,
        @as(i8, @intCast(d4)) - 1,
    };
}

pub const PackedBigInt = struct {
    data: [MAX_PACKED_BYTES]u8,
    trit_len: usize,

    const Self = @This();

    pub fn zero() Self {
        return Self{
            .data = [_]u8{encodePack(.{ 0, 0, 0, 0, 0 })} ** MAX_PACKED_BYTES,
            .trit_len = 1,
        };
    }

    pub fn packedLen(self: *const Self) usize {
        return (self.trit_len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
    }

    pub fn getTrit(self: *const Self, pos: usize) Trit {
        if (pos >= self.trit_len) return 0;
        const byte_idx = pos / TRITS_PER_BYTE;
        const trit_idx = pos % TRITS_PER_BYTE;
        const trits = decodePack(self.data[byte_idx]);
        return trits[trit_idx];
    }

    pub fn setTrit(self: *Self, pos: usize, value: Trit) void {
        if (pos >= MAX_TRITS) return;
        const byte_idx = pos / TRITS_PER_BYTE;
        const trit_idx = pos % TRITS_PER_BYTE;
        var trits = decodePack(self.data[byte_idx]);
        trits[trit_idx] = value;
        self.data[byte_idx] = encodePack(trits);
        if (pos >= self.trit_len and value != 0) {
            self.trit_len = pos + 1;
        }
    }

    pub fn fromI64(value: i64) Self {
        var result = Self.zero();
        if (value == 0) return result;
        var v = value;
        var pos: usize = 0;
        while (v != 0 and pos < MAX_TRITS) {
            var rem = @mod(v, @as(i64, 3));
            if (rem == 2) rem = -1;
            result.setTrit(pos, @intCast(rem));
            v = @divFloor(v - rem, 3);
            pos += 1;
        }
        result.trit_len = if (pos == 0) 1 else pos;
        result.normalize();
        return result;
    }

    pub fn toI64(self: *const Self) i64 {
        var result: i64 = 0;
        var power: i64 = 1;
        for (0..self.trit_len) |i| {
            result += @as(i64, self.getTrit(i)) * power;
            power *= 3;
        }
        return result;
    }

    fn normalize(self: *Self) void {
        while (self.trit_len > 1 and self.getTrit(self.trit_len - 1) == 0) {
            self.trit_len -= 1;
        }
    }

    pub fn isZero(self: *const Self) bool {
        return self.trit_len == 1 and self.getTrit(0) == 0;
    }

    pub fn isNegative(self: *const Self) bool {
        return self.getTrit(self.trit_len - 1) < 0;
    }

    pub fn negate(self: *const Self) Self {
        var result = Self.zero();
        result.trit_len = self.trit_len;
        for (0..self.packedLen()) |i| {
            const trits = decodePack(self.data[i]);
            const negated = [5]i8{ -trits[0], -trits[1], -trits[2], -trits[3], -trits[4] };
            result.data[i] = encodePack(negated);
        }
        return result;
    }

    pub fn add(a: *const Self, b: *const Self) Self {
        var result = Self.zero();
        var carry: Trit = 0;
        const max_len = @max(a.trit_len, b.trit_len);
        for (0..max_len + 1) |i| {
            if (i >= MAX_TRITS) break;
            var sum: i16 = @as(i16, a.getTrit(i)) + @as(i16, b.getTrit(i)) + carry;
            carry = 0;
            while (sum > 1) {
                sum -= 3;
                carry += 1;
            }
            while (sum < -1) {
                sum += 3;
                carry -= 1;
            }
            result.setTrit(i, @intCast(sum));
        }
        result.trit_len = max_len + 1;
        result.normalize();
        return result;
    }

    pub fn sub(a: *const Self, b: *const Self) Self {
        const neg_b = b.negate();
        return a.add(&neg_b);
    }

    pub fn mul(a: *const Self, b: *const Self) Self {
        var result = Self.zero();
        for (0..a.trit_len) |i| {
            const a_trit = a.getTrit(i);
            if (a_trit == 0) continue;
            var partial = Self.zero();
            var carry: Trit = 0;
            for (0..b.trit_len) |j| {
                if (i + j >= MAX_TRITS) break;
                var prod: i16 = @as(i16, a_trit) * @as(i16, b.getTrit(j)) + carry;
                carry = 0;
                while (prod > 1) {
                    prod -= 3;
                    carry += 1;
                }
                while (prod < -1) {
                    prod += 3;
                    carry -= 1;
                }
                partial.setTrit(i + j, @intCast(prod));
            }
            if (carry != 0 and i + b.trit_len < MAX_TRITS) {
                partial.setTrit(i + b.trit_len, carry);
            }
            partial.trit_len = @min(i + b.trit_len + 1, MAX_TRITS);
            result = result.add(&partial);
        }
        result.normalize();
        return result;
    }

    pub fn fromBigInt(big: *const tvc_bigint.TVCBigInt) Self {
        var result = Self.zero();
        for (0..big.len) |i| {
            result.setTrit(i, big.trits[i]);
        }
        result.trit_len = big.len;
        return result;
    }

    pub fn toBigInt(self: *const Self) tvc_bigint.TVCBigInt {
        var result = tvc_bigint.TVCBigInt.zero();
        for (0..self.trit_len) |i| {
            result.trits[i] = self.getTrit(i);
        }
        result.len = self.trit_len;
        return result;
    }

    pub fn memoryUsage(self: *const Self) usize {
        return self.packedLen();
    }
};

test "encode/decode pack" {
    const trits = [5]i8{ -1, 0, 1, -1, 1 };
    const encoded = encodePack(trits);
    const decoded = decodePack(encoded);
    try std.testing.expectEqual(trits[0], decoded[0]);
    try std.testing.expectEqual(trits[1], decoded[1]);
    try std.testing.expectEqual(trits[2], decoded[2]);
    try std.testing.expectEqual(trits[3], decoded[3]);
    try std.testing.expectEqual(trits[4], decoded[4]);
}

test "PackedBigInt fromI64 and toI64" {
    const cases = [_]i64{ 0, 1, -1, 10, -10, 100, -100, 12345, -12345 };
    for (cases) |val| {
        const pbi = PackedBigInt.fromI64(val);
        const back = pbi.toI64();
        try std.testing.expectEqual(val, back);
    }
}

test "PackedBigInt addition" {
    const a = PackedBigInt.fromI64(123);
    const b = PackedBigInt.fromI64(456);
    const sum = a.add(&b);
    try std.testing.expectEqual(@as(i64, 579), sum.toI64());
}

test "PackedBigInt multiplication" {
    const a = PackedBigInt.fromI64(12);
    const b = PackedBigInt.fromI64(34);
    const prod = a.mul(&b);
    try std.testing.expectEqual(@as(i64, 408), prod.toI64());
}

test "PackedBigInt conversion" {
    const val: i64 = 12345;
    const big = tvc_bigint.TVCBigInt.fromI64(val);
    const pbi = PackedBigInt.fromBigInt(&big);
    const back = pbi.toBigInt();
    try std.testing.expectEqual(val, back.toI64());
    try std.testing.expectEqual(val, pbi.toI64());
}

pub fn runBenchmarks() void {
    const iterations: u64 = 100000;
    std.debug.print("\nPacked vs Unpacked BigInt Benchmarks\n", .{});
    std.debug.print("=====================================\n\n", .{});

    const val_a: i64 = 123456789;
    const val_b: i64 = 987654321;

    const unpacked_a = tvc_bigint.TVCBigInt.fromI64(val_a);
    const unpacked_b = tvc_bigint.TVCBigInt.fromI64(val_b);
    const packed_a = PackedBigInt.fromI64(val_a);
    const packed_b = PackedBigInt.fromI64(val_b);

    std.debug.print("Number sizes:\n", .{});
    std.debug.print("  Unpacked: {} trits, {} bytes\n", .{ unpacked_a.len, unpacked_a.len });
    std.debug.print("  Packed:   {} trits, {} bytes\n", .{ packed_a.trit_len, packed_a.memoryUsage() });
    std.debug.print("  Memory savings: {d:.1}x\n\n", .{@as(f64, @floatFromInt(unpacked_a.len)) / @as(f64, @floatFromInt(packed_a.memoryUsage()))});

    std.debug.print("Addition x {} iterations:\n", .{iterations});

    const unpacked_start = std.time.nanoTimestamp();
    var unpacked_result = tvc_bigint.TVCBigInt.zero();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        unpacked_result = unpacked_a.addScalar(&unpacked_b);
    }
    const unpacked_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(unpacked_result);
    const unpacked_ns = @as(u64, @intCast(unpacked_end - unpacked_start));

    const packed_start = std.time.nanoTimestamp();
    var packed_result = PackedBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        packed_result = packed_a.add(&packed_b);
    }
    const packed_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(packed_result);
    const packed_ns = @as(u64, @intCast(packed_end - packed_start));

    const speedup: f64 = @as(f64, @floatFromInt(unpacked_ns)) / @as(f64, @floatFromInt(packed_ns));

    std.debug.print("  Unpacked: {} ns ({} ns/op)\n", .{ unpacked_ns, unpacked_ns / iterations });
    std.debug.print("  Packed:   {} ns ({} ns/op)\n", .{ packed_ns, packed_ns / iterations });
    std.debug.print("  Speedup:  {d:.2}x\n", .{speedup});
    std.debug.print("  Results match: {}\n", .{unpacked_result.toI64() == packed_result.toI64()});
}

pub fn main() !void {
    runBenchmarks();
}
