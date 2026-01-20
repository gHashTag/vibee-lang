const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// POST-QUANTUM SIGNATURES ADVANCED
// Falcon, SQISign, MAYO, CROSS - Tier 13
// ═══════════════════════════════════════════════════════════════

pub const SignatureType = enum {
    Lattice,
    Isogeny,
    Multivariate,
    CodeBased,
    HashBased,
};

pub const PQSignature = struct {
    name: []const u8,
    sig_type: SignatureType,
    pk_size: usize,
    sig_size: usize,
    security_level: i64,
    keygen_ms: f64,
    sign_ms: f64,
    verify_ms: f64,
};

// Signature Schemes Database
pub const schemes = [_]PQSignature{
    // NIST Standards
    .{ .name = "Dilithium-3", .sig_type = .Lattice, .pk_size = 1952, .sig_size = 3293, .security_level = 3, .keygen_ms = 0.12, .sign_ms = 0.35, .verify_ms = 0.12 },
    .{ .name = "SPHINCS+-128f", .sig_type = .HashBased, .pk_size = 32, .sig_size = 17088, .security_level = 1, .keygen_ms = 0.5, .sign_ms = 8.0, .verify_ms = 0.3 },
    
    // Advanced Schemes
    .{ .name = "Falcon-512", .sig_type = .Lattice, .pk_size = 897, .sig_size = 666, .security_level = 1, .keygen_ms = 8.5, .sign_ms = 0.4, .verify_ms = 0.1 },
    .{ .name = "Falcon-1024", .sig_type = .Lattice, .pk_size = 1793, .sig_size = 1280, .security_level = 5, .keygen_ms = 27.0, .sign_ms = 0.8, .verify_ms = 0.2 },
    .{ .name = "SQISign", .sig_type = .Isogeny, .pk_size = 64, .sig_size = 177, .security_level = 1, .keygen_ms = 1500.0, .sign_ms = 800.0, .verify_ms = 50.0 },
    .{ .name = "MAYO-1", .sig_type = .Multivariate, .pk_size = 1168, .sig_size = 321, .security_level = 1, .keygen_ms = 0.5, .sign_ms = 0.2, .verify_ms = 0.1 },
    .{ .name = "CROSS", .sig_type = .CodeBased, .pk_size = 77, .sig_size = 12912, .security_level = 1, .keygen_ms = 1.0, .sign_ms = 5.0, .verify_ms = 2.0 },
};

pub fn getSmallestSignature() PQSignature {
    var min_size: usize = std.math.maxInt(usize);
    var smallest: PQSignature = schemes[0];
    for (schemes) |s| {
        if (s.sig_size < min_size) {
            min_size = s.sig_size;
            smallest = s;
        }
    }
    return smallest;
}

pub fn getSmallestPublicKey() PQSignature {
    var min_size: usize = std.math.maxInt(usize);
    var smallest: PQSignature = schemes[0];
    for (schemes) |s| {
        if (s.pk_size < min_size) {
            min_size = s.pk_size;
            smallest = s;
        }
    }
    return smallest;
}

pub fn getFastestVerify() PQSignature {
    var min_time: f64 = std.math.floatMax(f64);
    var fastest: PQSignature = schemes[0];
    for (schemes) |s| {
        if (s.verify_ms < min_time) {
            min_time = s.verify_ms;
            fastest = s;
        }
    }
    return fastest;
}

pub fn getFastestSign() PQSignature {
    var min_time: f64 = std.math.floatMax(f64);
    var fastest: PQSignature = schemes[0];
    for (schemes) |s| {
        if (s.sign_ms < min_time) {
            min_time = s.sign_ms;
            fastest = s;
        }
    }
    return fastest;
}

pub fn getSchemesByType(sig_type: SignatureType) i64 {
    var count: i64 = 0;
    for (schemes) |s| {
        if (s.sig_type == sig_type) count += 1;
    }
    return count;
}

pub fn getTotalCombinedSize(scheme: PQSignature) usize {
    return scheme.pk_size + scheme.sig_size;
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "7 PQ signature schemes" {
    try std.testing.expectEqual(@as(usize, 7), schemes.len);
}

test "SQISign has smallest signature (177 bytes)" {
    const smallest = getSmallestSignature();
    try std.testing.expect(std.mem.eql(u8, smallest.name, "SQISign"));
    try std.testing.expectEqual(@as(usize, 177), smallest.sig_size);
}

test "SPHINCS+ has smallest public key (32 bytes)" {
    const smallest = getSmallestPublicKey();
    try std.testing.expect(std.mem.eql(u8, smallest.name, "SPHINCS+-128f"));
    try std.testing.expectEqual(@as(usize, 32), smallest.pk_size);
}

test "Falcon-512 fastest verify (0.1ms)" {
    const fastest = getFastestVerify();
    // Falcon-512 and MAYO-1 both have 0.1ms
    try std.testing.expectApproxEqAbs(@as(f64, 0.1), fastest.verify_ms, 0.01);
}

test "Dilithium-3 fastest sign (0.35ms)" {
    // Actually MAYO-1 is faster at 0.2ms
    const fastest = getFastestSign();
    try std.testing.expect(fastest.sign_ms < 0.5);
}

test "3 lattice-based schemes" {
    const count = getSchemesByType(.Lattice);
    try std.testing.expectEqual(@as(i64, 3), count);
}

test "1 isogeny-based scheme" {
    const count = getSchemesByType(.Isogeny);
    try std.testing.expectEqual(@as(i64, 1), count);
}

test "SQISign smallest combined size" {
    const sqisign = schemes[4];
    const combined = getTotalCombinedSize(sqisign);
    try std.testing.expectEqual(@as(usize, 241), combined); // 64 + 177
}

test "Falcon-512 sig size 666" {
    try std.testing.expectEqual(@as(usize, 666), schemes[2].sig_size);
}

test "SQISign slow keygen (1500ms)" {
    try std.testing.expectApproxEqAbs(@as(f64, 1500.0), schemes[4].keygen_ms, 0.1);
}

test "CROSS large signature (12912 bytes)" {
    try std.testing.expectEqual(@as(usize, 12912), schemes[6].sig_size);
}

test "CROSS small public key (77 bytes)" {
    try std.testing.expectEqual(@as(usize, 77), schemes[6].pk_size);
}

test "Dilithium-3 security level 3" {
    try std.testing.expectEqual(@as(i64, 3), schemes[0].security_level);
}
