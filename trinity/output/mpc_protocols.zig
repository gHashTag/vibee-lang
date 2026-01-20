const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// MULTI-PARTY COMPUTATION PROTOCOLS
// SPDZ, ABY, Garbled Circuits - Tier 9
// ═══════════════════════════════════════════════════════════════

pub const SecurityModel = enum {
    SemiHonest,
    Malicious,
    Covert,
};

pub const SharingType = enum {
    Arithmetic,
    Boolean,
    Yao,
};

pub const MPCProtocol = struct {
    name: []const u8,
    paper: []const u8,
    year: i64,
    security: SecurityModel,
    parties: i64,
    threshold: i64,
    mult_per_sec: i64,
};

pub const BeaverTriple = struct {
    a: i64,
    b: i64,
    c: i64, // c = a * b mod p
    
    pub fn verify(self: *const BeaverTriple, modulus: i64) bool {
        return @mod(self.a * self.b, modulus) == @mod(self.c, modulus);
    }
};

pub const SecretShare = struct {
    party_id: i64,
    share: i64,
    modulus: i64,
};

// Protocol Database
pub const protocols = [_]MPCProtocol{
    .{ .name = "SPDZ", .paper = "CRYPTO 2012", .year = 2012, .security = .Malicious, .parties = 0, .threshold = 0, .mult_per_sec = 1000000 },
    .{ .name = "ABY", .paper = "NDSS 2015", .year = 2015, .security = .SemiHonest, .parties = 2, .threshold = 1, .mult_per_sec = 10000000 },
    .{ .name = "Yao GC", .paper = "FOCS 1986", .year = 1986, .security = .SemiHonest, .parties = 2, .threshold = 1, .mult_per_sec = 5000000 },
    .{ .name = "BGW", .paper = "STOC 1988", .year = 1988, .security = .SemiHonest, .parties = 0, .threshold = 0, .mult_per_sec = 100000 },
    .{ .name = "GMW", .paper = "STOC 1987", .year = 1987, .security = .SemiHonest, .parties = 0, .threshold = 0, .mult_per_sec = 500000 },
    .{ .name = "MP-SPDZ", .paper = "CCS 2020", .year = 2020, .security = .Malicious, .parties = 0, .threshold = 0, .mult_per_sec = 2000000 },
};

// Applications
pub const Application = struct {
    name: []const u8,
    description: []const u8,
    protocols: []const []const u8,
};

pub const applications = [_]Application{
    .{ .name = "PSI", .description = "Private Set Intersection", .protocols = &[_][]const u8{ "OPRF", "Circuit", "OT" } },
    .{ .name = "Threshold Sig", .description = "t-of-n Signatures", .protocols = &[_][]const u8{ "GG18", "GG20", "FROST" } },
    .{ .name = "Private ML", .description = "ML on Private Data", .protocols = &[_][]const u8{ "SecureML", "ABY3", "FALCON" } },
};

pub fn generateBeaverTriple(seed: u64, modulus: i64) BeaverTriple {
    // Deterministic generation for testing
    const a = @as(i64, @intCast(seed % @as(u64, @intCast(modulus))));
    const b = @as(i64, @intCast((seed >> 16) % @as(u64, @intCast(modulus))));
    const c = @mod(a * b, modulus);
    return BeaverTriple{ .a = a, .b = b, .c = c };
}

pub fn additiveShare(secret: i64, n: usize, modulus: i64, seed: u64) [8]SecretShare {
    var shares: [8]SecretShare = undefined;
    var sum: i64 = 0;
    
    // Generate n-1 random shares
    var i: usize = 0;
    while (i < n - 1) : (i += 1) {
        const r = @as(i64, @intCast((seed + i) % @as(u64, @intCast(modulus))));
        shares[i] = SecretShare{ .party_id = @as(i64, @intCast(i)), .share = r, .modulus = modulus };
        sum = @mod(sum + r, modulus);
    }
    
    // Last share makes sum equal to secret
    shares[n - 1] = SecretShare{ 
        .party_id = @as(i64, @intCast(n - 1)), 
        .share = @mod(secret - sum + modulus, modulus), 
        .modulus = modulus 
    };
    
    return shares;
}

pub fn reconstruct(shares: []const SecretShare, n: usize) i64 {
    var sum: i64 = 0;
    for (0..n) |i| {
        sum = @mod(sum + shares[i].share, shares[i].modulus);
    }
    return sum;
}

pub fn getFastestProtocol() MPCProtocol {
    var max_speed: i64 = 0;
    var fastest: MPCProtocol = protocols[0];
    for (protocols) |p| {
        if (p.mult_per_sec > max_speed) {
            max_speed = p.mult_per_sec;
            fastest = p;
        }
    }
    return fastest;
}

pub fn getMaliciousProtocols() i64 {
    var count: i64 = 0;
    for (protocols) |p| {
        if (p.security == .Malicious) count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "6 MPC protocols defined" {
    try std.testing.expectEqual(@as(usize, 6), protocols.len);
}

test "SPDZ is malicious secure" {
    try std.testing.expectEqual(SecurityModel.Malicious, protocols[0].security);
}

test "ABY is 2-party" {
    try std.testing.expectEqual(@as(i64, 2), protocols[1].parties);
}

test "Yao GC from 1986" {
    try std.testing.expectEqual(@as(i64, 1986), protocols[2].year);
}

test "ABY is fastest (10M mult/sec)" {
    const fastest = getFastestProtocol();
    try std.testing.expect(std.mem.eql(u8, fastest.name, "ABY"));
}

test "2 malicious protocols" {
    const count = getMaliciousProtocols();
    try std.testing.expectEqual(@as(i64, 2), count);
}

test "Beaver triple verification" {
    const triple = generateBeaverTriple(12345, 997);
    try std.testing.expect(triple.verify(997));
}

test "Additive secret sharing" {
    const secret: i64 = 42;
    const modulus: i64 = 997;
    const shares = additiveShare(secret, 3, modulus, 12345);
    const reconstructed = reconstruct(&shares, 3);
    try std.testing.expectEqual(secret, reconstructed);
}

test "3 MPC applications" {
    try std.testing.expectEqual(@as(usize, 3), applications.len);
}

test "PSI application exists" {
    try std.testing.expect(std.mem.eql(u8, applications[0].name, "PSI"));
}

test "MP-SPDZ from 2020" {
    try std.testing.expectEqual(@as(i64, 2020), protocols[5].year);
}

test "SPDZ 1M mult/sec" {
    try std.testing.expectEqual(@as(i64, 1000000), protocols[0].mult_per_sec);
}
