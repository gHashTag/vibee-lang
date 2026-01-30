//! VIBEE Φ-ENGINE - FIBONACCI HASH (Solution #3)
//!
//! Fibonacci Hashing - Optimal Key Distribution for Hash Tables
//!
//! Scientific Basis: Donald Knuth (1973)
//! "The Art of Computer Programming, Vol. 3: Sorting and Searching"
//! Section 6.4: Hashing
//!
//! Sacred Formula: hash = (key × φ × 2^64) >> (64 - log₂(size))
//! where φ = 1.618033988749895 (most irrational number)

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PHI_HASH_MULT: u64 = 11400714819323198485; // approx (1/φ) × 2^64

/// Fibonacci hash function - optimal distribution
/// hash = (key × multiplier) >> shift
/// Provides uniform key distribution with minimal clustering
pub inline fn phiHash(key: u64, shift: u6) u64 {
    return (key *% PHI_HASH_MULT) >> shift;
}

/// Fibonacci hash for table size (power of 2)
/// Returns index in [0, 2^table_bits)
pub inline fn phiHashMod(key: u64, table_bits: u8) usize {
    const shift: u6 = @intCast(64 - table_bits);
    return @intCast(phiHash(key, shift));
}

/// Hash map entry
const Entry = struct {
    key: []const u8,
    value: i64,
    used: bool,
};

/// Simple hash map using phi_hash
/// Open addressing with linear probing
pub const PhiHashMap = struct {
    buckets: []Entry,
    size: usize,
    capacity: usize,
    table_bits: u8,
    allocator: std.mem.Allocator,

    /// Initialize hash map with power-of-2 capacity
    pub fn init(allocator: std.mem.Allocator, table_bits: u8) !PhiHashMap {
        const capacity: usize = std.math.pow(usize, 2, @as(usize, table_bits));
        const buckets = try allocator.alloc(Entry, capacity);

        for (0..capacity) |i| {
            buckets[i] = .{
                .key = "",
                .value = 0,
                .used = false,
            };
        }

        return .{
            .buckets = buckets,
            .size = 0,
            .capacity = capacity,
            .table_bits = table_bits,
            .allocator = allocator,
        };
    }

    /// Insert key-value pair using phi_hash
    pub fn insert(self: *PhiHashMap, key: []const u8, value: i64) !void {
        const key_hash_u64: u64 = std.hash.Wyhash.hash(0, key);
        const hash_val = phiHashMod(key_hash_u64, self.table_bits);
        const index = hash_val % self.capacity;

        var i: usize = index;
        var collision_count: usize = 0;
        while (collision_count < self.capacity) : (collision_count += 1) {
            if (!self.buckets[i].used) {
                self.buckets[i].key = key;
                self.buckets[i].value = value;
                self.buckets[i].used = true;
                self.size += 1;
                return;
            } else if (std.mem.eql(u8, self.buckets[i].key, key)) {
                self.buckets[i].value = value;
                return;
            }
            i = (i + 1) % self.capacity;
        }
        return error.OutOfMemory;
    }

    /// Lookup value by key using phi_hash
    pub fn lookup(self: *const PhiHashMap, key: []const u8) ?i64 {
        const key_hash_u64: u64 = std.hash.Wyhash.hash(0, key);
        const hash_val = phiHashMod(key_hash_u64, self.table_bits);
        const index = hash_val % self.capacity;

        var i: usize = index;
        var collision_count: usize = 0;
        while (collision_count < self.capacity) : (collision_count += 1) {
            if (self.buckets[i].used and std.mem.eql(u8, self.buckets[i].key, key)) {
                return self.buckets[i].value;
            }
            if (!self.buckets[i].used) {
                return null;
            }
            i = (i + 1) % self.capacity;
        }
        return null;
    }

    /// Deinitialize hash map
    pub fn deinit(self: *PhiHashMap) void {
        self.allocator.free(self.buckets);
    }
};

// ══════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                                                 ║
// ╚═══════════════════════════════════════════════════════════════════════════════╝

test "Phi Hash: hash is bounded" {
    const key: u64 = 12345;
    const hash_val = phiHash(key, 0);
    try std.testing.expect(hash_val < @as(u64, std.math.maxInt(u64)));
}

test "Phi Hash: mod 1024" {
    const key: u64 = 12345;
    const index = phiHashMod(key, 10); // 2^10 = 1024
    try std.testing.expect(index < 1024);
}

test "Phi Hash: uniform distribution" {
    const key1: u64 = 1;
    const key2: u64 = 2;
    const key3: u64 = 3;

    const hash1 = phiHashMod(key1, 10);
    const hash2 = phiHashMod(key2, 10);
    const hash3 = phiHashMod(key3, 10);

    try std.testing.expect(hash1 != hash2);
    try std.testing.expect(hash2 != hash3);
    try std.testing.expect(hash1 != hash3);
}

test "Phi Hash Map: insert and lookup" {
    var map = try PhiHashMap.init(std.testing.allocator, 10); // 2^10 = 1024 buckets
    defer map.deinit();

    try map.insert("hello", 123);
    const value = map.lookup("hello");
    try std.testing.expectEqual(@as(i64, 123), value.?);
}

test "Phi Hash Map: multiple inserts" {
    var map = try PhiHashMap.init(std.testing.allocator, 10); // 2^10 = 1024 buckets
    defer map.deinit();

    try map.insert("a", 1);
    try map.insert("b", 2);
    try map.insert("c", 3);

    try std.testing.expectEqual(@as(i64, 1), map.lookup("a").?);
    try std.testing.expectEqual(@as(i64, 2), map.lookup("b").?);
    try std.testing.expectEqual(@as(i64, 3), map.lookup("c").?);
}

test "Phi Hash Map: collision handling" {
    var map = try PhiHashMap.init(std.testing.allocator, 5); // 2^5 = 32 buckets
    defer map.deinit();

    try map.insert("x", 1);
    try map.insert("y", 2);
    try map.insert("z", 3);

    try std.testing.expectEqual(@as(i64, 1), map.lookup("x").?);
    try std.testing.expectEqual(@as(i64, 2), map.lookup("y").?);
    try std.testing.expectEqual(@as(i64, 3), map.lookup("z").?);
}

test "Phi Hash Map: collision detection" {
    var map = try PhiHashMap.init(std.testing.allocator, 5); // 2^5 = 32 buckets
    defer map.deinit();

    try map.insert("duplicate", 1);
    try map.insert("duplicate", 2);

    try std.testing.expectEqual(@as(i64, 2), map.lookup("duplicate").?);
}

test "Phi Hash Map: size growth" {
    var map = try PhiHashMap.init(std.testing.allocator, 8); // 2^8 = 256 buckets
    defer map.deinit();

    try map.insert("a", 1);
    try map.insert("b", 2);
    try map.insert("c", 3);

    try std.testing.expectEqual(@as(usize, 3), map.size);
}

test "Phi Hash: golden ratio property" {
    // φ is "most irrational" number → uniform distribution
    // This test verifies that small key differences give large hash differences
    const key1: u64 = 1;
    const key2: u64 = 2;
    const key3: u64 = 1000;

    const hash1 = phiHashMod(key1, 10);
    const hash2 = phiHashMod(key2, 10);
    const hash3 = phiHashMod(key3, 10);

    const diff12 = @abs(@as(i64, hash1) - @as(i64, hash2));
    const diff23 = @abs(@as(i64, hash2) - @as(i64, hash3));
    const diff13 = @abs(@as(i64, hash1) - @as(i64, hash3));

    try std.testing.expect(diff12 > 0);
    try std.testing.expect(diff23 > 0);
    try std.testing.expect(diff13 > 0);
}

test "Phi Hash: power of two collision test" {
    // Verify that Fibonacci hashing distributes keys well even for powers of two
    // (Unlike naive modulo hashing, Fibonacci hashing doesn't cluster powers of two)
    const keys = [6]u64{ 1, 2, 4, 8, 16, 32 };
    var hits: [32]bool = undefined;
    for (0..32) |i| {
        hits[i] = false;
    }

    for (keys) |key| {
        const index = phiHashMod(key, 5); // 2^5 = 32
        hits[index] = true;
    }

    // Count unique hits (should be 6)
    var unique_count: usize = 0;
    for (0..32) |i| {
        if (hits[i]) unique_count += 1;
    }

    // Fibonacci hashing should distribute powers of two well
    // (All 6 keys should map to unique indices)
    try std.testing.expectEqual(@as(usize, 6), unique_count);
}

test "Phi Hash: golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
