const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// TECHNOLOGY TREE V5 - 25 Tiers with Parallel Tracks
// ═══════════════════════════════════════════════════════════════

pub const TierStatus = enum {
    Complete,
    InProgress,
    New,
    Planned,
    Research,
};

pub const Track = enum {
    Foundation,
    Privacy,
    Distributed,
    ML,
    Future,
};

pub const TechTier = struct {
    id: i64,
    name: []const u8,
    status: TierStatus,
    tests: i64,
    track: Track,
};

pub const VersionInfo = struct {
    version: []const u8,
    tiers: i64,
    tests: i64,
};

// 25 Technology Tiers
pub const tech_tree = [_]TechTier{
    // Track A: Foundation (6 tiers, Complete)
    .{ .id = 1, .name = "Foundation", .status = .Complete, .tests = 156, .track = .Foundation },
    .{ .id = 2, .name = "Core Crypto", .status = .Complete, .tests = 245, .track = .Foundation },
    .{ .id = 3, .name = "SIMD", .status = .Complete, .tests = 178, .track = .Foundation },
    .{ .id = 4, .name = "GPU", .status = .Complete, .tests = 136, .track = .Foundation },
    .{ .id = 5, .name = "Formal Verification", .status = .Complete, .tests = 89, .track = .Foundation },
    .{ .id = 6, .name = "FIPS 140-3", .status = .Complete, .tests = 67, .track = .Foundation },
    
    // Track B: Privacy (5 tiers, In Progress)
    .{ .id = 7, .name = "Hybrid Crypto", .status = .InProgress, .tests = 26, .track = .Privacy },
    .{ .id = 8, .name = "ZK Basic", .status = .InProgress, .tests = 27, .track = .Privacy },
    .{ .id = 9, .name = "FHE Basic", .status = .InProgress, .tests = 13, .track = .Privacy },
    .{ .id = 10, .name = "MPC Basic", .status = .InProgress, .tests = 12, .track = .Privacy },
    .{ .id = 11, .name = "TEE", .status = .InProgress, .tests = 12, .track = .Privacy },
    
    // Track C: Distributed (4 tiers, New)
    .{ .id = 12, .name = "Threshold", .status = .New, .tests = 12, .track = .Distributed },
    .{ .id = 13, .name = "Secure Aggregation", .status = .New, .tests = 0, .track = .Distributed },
    .{ .id = 14, .name = "Blockchain", .status = .New, .tests = 0, .track = .Distributed },
    .{ .id = 15, .name = "Consensus", .status = .New, .tests = 0, .track = .Distributed },
    
    // Track D: ML (4 tiers, Planned)
    .{ .id = 16, .name = "Private ML", .status = .Planned, .tests = 0, .track = .ML },
    .{ .id = 17, .name = "Federated Learning", .status = .Planned, .tests = 0, .track = .ML },
    .{ .id = 18, .name = "Verifiable Computation", .status = .Planned, .tests = 0, .track = .ML },
    .{ .id = 19, .name = "Model Protection", .status = .Planned, .tests = 0, .track = .ML },
    
    // Track E: Future (6 tiers, Research)
    .{ .id = 20, .name = "ZK Production", .status = .Research, .tests = 0, .track = .Future },
    .{ .id = 21, .name = "FHE Production", .status = .Research, .tests = 0, .track = .Future },
    .{ .id = 22, .name = "MPC Production", .status = .Research, .tests = 0, .track = .Future },
    .{ .id = 23, .name = "Quantum-Safe Migration", .status = .Research, .tests = 0, .track = .Future },
    .{ .id = 24, .name = "Post-Quantum TLS", .status = .Research, .tests = 0, .track = .Future },
    .{ .id = 25, .name = "Quantum Supremacy", .status = .Research, .tests = 0, .track = .Future },
};

// Version History
pub const versions = [_]VersionInfo{
    .{ .version = "V8", .tiers = 5, .tests = 995 },
    .{ .version = "V9", .tiers = 7, .tests = 1475 },
    .{ .version = "V10", .tiers = 7, .tests = 1660 },
    .{ .version = "V11", .tiers = 8, .tests = 1741 },
    .{ .version = "V12", .tiers = 9, .tests = 2967 },
    .{ .version = "V13", .tiers = 11, .tests = 3100 },
};

pub fn getTotalTiers() i64 {
    return tech_tree.len;
}

pub fn getCompleteTiers() i64 {
    var count: i64 = 0;
    for (tech_tree) |t| {
        if (t.status == .Complete) count += 1;
    }
    return count;
}

pub fn getTiersByTrack(track: Track) i64 {
    var count: i64 = 0;
    for (tech_tree) |t| {
        if (t.track == track) count += 1;
    }
    return count;
}

pub fn getTotalTests() i64 {
    var total: i64 = 0;
    for (tech_tree) |t| {
        total += t.tests;
    }
    return total;
}

pub fn getTrackCompletion(track: Track) f64 {
    var complete: i64 = 0;
    var total: i64 = 0;
    for (tech_tree) |t| {
        if (t.track == track) {
            total += 1;
            if (t.status == .Complete) complete += 1;
        }
    }
    return if (total > 0) @as(f64, @floatFromInt(complete)) / @as(f64, @floatFromInt(total)) * 100.0 else 0.0;
}

pub fn getVersionImprovement(v1: usize, v2: usize) f64 {
    const t1 = versions[v1].tests;
    const t2 = versions[v2].tests;
    return @as(f64, @floatFromInt(t2 - t1)) / @as(f64, @floatFromInt(t1)) * 100.0;
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "25 tiers defined" {
    try std.testing.expectEqual(@as(usize, 25), tech_tree.len);
}

test "6 complete tiers" {
    const complete = getCompleteTiers();
    try std.testing.expectEqual(@as(i64, 6), complete);
}

test "6 tiers in Foundation track" {
    const count = getTiersByTrack(.Foundation);
    try std.testing.expectEqual(@as(i64, 6), count);
}

test "5 tiers in Privacy track" {
    const count = getTiersByTrack(.Privacy);
    try std.testing.expectEqual(@as(i64, 5), count);
}

test "4 tiers in Distributed track" {
    const count = getTiersByTrack(.Distributed);
    try std.testing.expectEqual(@as(i64, 4), count);
}

test "4 tiers in ML track" {
    const count = getTiersByTrack(.ML);
    try std.testing.expectEqual(@as(i64, 4), count);
}

test "6 tiers in Future track" {
    const count = getTiersByTrack(.Future);
    try std.testing.expectEqual(@as(i64, 6), count);
}

test "Foundation track 100% complete" {
    const completion = getTrackCompletion(.Foundation);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), completion, 0.1);
}

test "Total tests > 900" {
    const total = getTotalTests();
    try std.testing.expect(total > 900);
}

test "6 versions tracked" {
    try std.testing.expectEqual(@as(usize, 6), versions.len);
}

test "V13 has 3100 tests" {
    try std.testing.expectEqual(@as(i64, 3100), versions[5].tests);
}

test "V8 to V13 improvement > 200%" {
    const improvement = getVersionImprovement(0, 5);
    try std.testing.expect(improvement > 200.0);
}

test "Tier 1 is Foundation" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[0].name, "Foundation"));
}

test "Tier 25 is Quantum Supremacy" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[24].name, "Quantum Supremacy"));
}
