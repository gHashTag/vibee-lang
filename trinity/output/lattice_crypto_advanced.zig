const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// LATTICE CRYPTOGRAPHY ADVANCED
// NTRU, FrodoKEM, NewHope - Post-Quantum Security
// ═══════════════════════════════════════════════════════════════

pub const LatticeProblem = enum {
    LWE,
    RingLWE,
    ModuleLWE,
    NTRU,
    SIS,
};

pub const SecurityLevel = enum(u8) {
    Level1 = 1, // 128-bit classical, 64-bit quantum
    Level3 = 3, // 192-bit classical, 96-bit quantum
    Level5 = 5, // 256-bit classical, 128-bit quantum
};

pub const LatticeScheme = struct {
    name: []const u8,
    problem: LatticeProblem,
    pk_size: usize,
    sk_size: usize,
    ct_size: usize,
    keygen_ms: f64,
    encaps_ms: f64,
    decaps_ms: f64,
    security_level: SecurityLevel,
};

// Scheme Database
pub const schemes = [_]LatticeScheme{
    // FrodoKEM (Conservative LWE)
    .{ .name = "FrodoKEM-640", .problem = .LWE, .pk_size = 9616, .sk_size = 19888, .ct_size = 9720, .keygen_ms = 3.2, .encaps_ms = 3.8, .decaps_ms = 3.5, .security_level = .Level1 },
    .{ .name = "FrodoKEM-976", .problem = .LWE, .pk_size = 15632, .sk_size = 31296, .ct_size = 15744, .keygen_ms = 7.5, .encaps_ms = 8.2, .decaps_ms = 7.8, .security_level = .Level3 },
    .{ .name = "FrodoKEM-1344", .problem = .LWE, .pk_size = 21520, .sk_size = 43088, .ct_size = 21632, .keygen_ms = 14.0, .encaps_ms = 15.2, .decaps_ms = 14.5, .security_level = .Level5 },
    
    // NTRU (26+ years of cryptanalysis)
    .{ .name = "NTRU-HPS-2048-509", .problem = .NTRU, .pk_size = 699, .sk_size = 935, .ct_size = 699, .keygen_ms = 0.15, .encaps_ms = 0.08, .decaps_ms = 0.12, .security_level = .Level1 },
    .{ .name = "NTRU-HPS-2048-677", .problem = .NTRU, .pk_size = 930, .sk_size = 1234, .ct_size = 930, .keygen_ms = 0.20, .encaps_ms = 0.10, .decaps_ms = 0.15, .security_level = .Level3 },
    .{ .name = "NTRU-HPS-4096-821", .problem = .NTRU, .pk_size = 1230, .sk_size = 1590, .ct_size = 1230, .keygen_ms = 0.35, .encaps_ms = 0.15, .decaps_ms = 0.22, .security_level = .Level5 },
    
    // NewHope (Ring-LWE)
    .{ .name = "NewHope-512", .problem = .RingLWE, .pk_size = 928, .sk_size = 1888, .ct_size = 1120, .keygen_ms = 0.05, .encaps_ms = 0.07, .decaps_ms = 0.06, .security_level = .Level1 },
    .{ .name = "NewHope-1024", .problem = .RingLWE, .pk_size = 1824, .sk_size = 3680, .ct_size = 2208, .keygen_ms = 0.10, .encaps_ms = 0.14, .decaps_ms = 0.12, .security_level = .Level5 },
    
    // ML-KEM (Module-LWE, NIST Standard)
    .{ .name = "ML-KEM-512", .problem = .ModuleLWE, .pk_size = 800, .sk_size = 1632, .ct_size = 768, .keygen_ms = 0.025, .encaps_ms = 0.030, .decaps_ms = 0.028, .security_level = .Level1 },
    .{ .name = "ML-KEM-768", .problem = .ModuleLWE, .pk_size = 1184, .sk_size = 2400, .ct_size = 1088, .keygen_ms = 0.035, .encaps_ms = 0.042, .decaps_ms = 0.040, .security_level = .Level3 },
    .{ .name = "ML-KEM-1024", .problem = .ModuleLWE, .pk_size = 1568, .sk_size = 3168, .ct_size = 1568, .keygen_ms = 0.045, .encaps_ms = 0.052, .decaps_ms = 0.048, .security_level = .Level5 },
};

pub fn getSchemeByName(name: []const u8) ?LatticeScheme {
    for (schemes) |s| {
        if (std.mem.eql(u8, s.name, name)) return s;
    }
    return null;
}

pub fn getSchemesByProblem(problem: LatticeProblem) []const LatticeScheme {
    // Return count for testing
    _ = problem;
    return &schemes; // Returns all schemes, filter externally
}

pub fn getSmallestKeyScheme() LatticeScheme {
    var min_size: usize = std.math.maxInt(usize);
    var min_scheme: LatticeScheme = schemes[0];
    for (schemes) |s| {
        if (s.pk_size < min_size) {
            min_size = s.pk_size;
            min_scheme = s;
        }
    }
    return min_scheme;
}

pub fn getFastestScheme() LatticeScheme {
    var min_time: f64 = std.math.floatMax(f64);
    var fastest: LatticeScheme = schemes[0];
    for (schemes) |s| {
        const total = s.keygen_ms + s.encaps_ms + s.decaps_ms;
        if (total < min_time) {
            min_time = total;
            fastest = s;
        }
    }
    return fastest;
}

pub fn getAverageKeySize() f64 {
    var total: f64 = 0.0;
    for (schemes) |s| {
        total += @as(f64, @floatFromInt(s.pk_size));
    }
    return total / @as(f64, @floatFromInt(schemes.len));
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "11 lattice schemes defined" {
    try std.testing.expectEqual(@as(usize, 11), schemes.len);
}

test "FrodoKEM-640 exists" {
    const frodo = getSchemeByName("FrodoKEM-640");
    try std.testing.expect(frodo != null);
    try std.testing.expectEqual(@as(usize, 9616), frodo.?.pk_size);
}

test "NTRU has smallest keys" {
    const smallest = getSmallestKeyScheme();
    try std.testing.expect(std.mem.eql(u8, smallest.name, "NTRU-HPS-2048-509"));
}

test "ML-KEM-512 is fastest" {
    const fastest = getFastestScheme();
    try std.testing.expect(std.mem.eql(u8, fastest.name, "ML-KEM-512"));
}

test "FrodoKEM uses plain LWE" {
    const frodo = getSchemeByName("FrodoKEM-640");
    try std.testing.expect(frodo != null);
    try std.testing.expectEqual(LatticeProblem.LWE, frodo.?.problem);
}

test "ML-KEM uses Module-LWE" {
    const mlkem = getSchemeByName("ML-KEM-1024");
    try std.testing.expect(mlkem != null);
    try std.testing.expectEqual(LatticeProblem.ModuleLWE, mlkem.?.problem);
}

test "NewHope uses Ring-LWE" {
    const nh = getSchemeByName("NewHope-512");
    try std.testing.expect(nh != null);
    try std.testing.expectEqual(LatticeProblem.RingLWE, nh.?.problem);
}

test "Average key size > 3000" {
    const avg = getAverageKeySize();
    try std.testing.expect(avg > 3000.0);
}

test "FrodoKEM-1344 is Level 5" {
    const frodo = getSchemeByName("FrodoKEM-1344");
    try std.testing.expect(frodo != null);
    try std.testing.expectEqual(SecurityLevel.Level5, frodo.?.security_level);
}

test "NTRU keygen < 1ms" {
    const ntru = getSchemeByName("NTRU-HPS-2048-509");
    try std.testing.expect(ntru != null);
    try std.testing.expect(ntru.?.keygen_ms < 1.0);
}

test "FrodoKEM keygen > 3ms" {
    const frodo = getSchemeByName("FrodoKEM-640");
    try std.testing.expect(frodo != null);
    try std.testing.expect(frodo.?.keygen_ms > 3.0);
}

test "ML-KEM-1024 pk_size 1568" {
    const mlkem = getSchemeByName("ML-KEM-1024");
    try std.testing.expect(mlkem != null);
    try std.testing.expectEqual(@as(usize, 1568), mlkem.?.pk_size);
}
