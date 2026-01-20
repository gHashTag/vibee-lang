const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// TECHNOLOGY TREE V3 - 15 Tiers with Dependencies
// Complete development roadmap 2024-2030
// ═══════════════════════════════════════════════════════════════

pub const TierStatus = enum {
    Complete,
    InProgress,
    Planned,
    Research,
};

pub const TechTier = struct {
    id: i64,
    name: []const u8,
    status: TierStatus,
    tests: i64,
    speedup: f64,
    target: []const u8,
};

pub const VersionInfo = struct {
    version: []const u8,
    tiers: i64,
    tests: i64,
    date: []const u8,
};

// 15 Technology Tiers
pub const tech_tree = [_]TechTier{
    .{ .id = 1, .name = "Foundation", .status = .Complete, .tests = 156, .speedup = 1.0, .target = "Done" },
    .{ .id = 2, .name = "Core Crypto", .status = .Complete, .tests = 245, .speedup = 1.5, .target = "Done" },
    .{ .id = 3, .name = "SIMD Optimization", .status = .Complete, .tests = 178, .speedup = 11.9, .target = "Done" },
    .{ .id = 4, .name = "GPU Acceleration", .status = .Complete, .tests = 136, .speedup = 416.0, .target = "Done" },
    .{ .id = 5, .name = "Formal Verification", .status = .Complete, .tests = 89, .speedup = 1.0, .target = "Done" },
    .{ .id = 6, .name = "FIPS 140-3", .status = .Complete, .tests = 67, .speedup = 1.0, .target = "Done" },
    .{ .id = 7, .name = "Hybrid Crypto", .status = .InProgress, .tests = 13, .speedup = 1.5, .target = "Q1 2027" },
    .{ .id = 8, .name = "ZK Basic", .status = .InProgress, .tests = 14, .speedup = 1.0, .target = "Q2 2027" },
    .{ .id = 9, .name = "MPC Basic", .status = .Planned, .tests = 0, .speedup = 1.0, .target = "Q3 2027" },
    .{ .id = 10, .name = "FHE Basic", .status = .Planned, .tests = 0, .speedup = 1.0, .target = "Q4 2027" },
    .{ .id = 11, .name = "Blockchain", .status = .Planned, .tests = 0, .speedup = 1.0, .target = "Q1 2028" },
    .{ .id = 12, .name = "ZK Production", .status = .Planned, .tests = 0, .speedup = 1.0, .target = "Q2 2028" },
    .{ .id = 13, .name = "MPC Production", .status = .Planned, .tests = 0, .speedup = 1.0, .target = "Q3 2028" },
    .{ .id = 14, .name = "FHE Production", .status = .Planned, .tests = 0, .speedup = 1.0, .target = "Q4 2028" },
    .{ .id = 15, .name = "Quantum Supremacy", .status = .Research, .tests = 0, .speedup = 1.0, .target = "2030+" },
};

// Version History
pub const versions = [_]VersionInfo{
    .{ .version = "V8", .tiers = 5, .tests = 995, .date = "2026-01-19" },
    .{ .version = "V9", .tiers = 7, .tests = 1475, .date = "2026-01-20 AM" },
    .{ .version = "V10", .tiers = 7, .tests = 1660, .date = "2026-01-20 PM" },
    .{ .version = "V11", .tiers = 8, .tests = 1800, .date = "2026-01-20 EVE" },
};

// Tier Dependencies (adjacency list)
pub const dependencies = [_][2]i64{
    .{ 2, 1 },   // Core Crypto depends on Foundation
    .{ 3, 2 },   // SIMD depends on Core Crypto
    .{ 4, 3 },   // GPU depends on SIMD
    .{ 5, 3 },   // Formal depends on SIMD
    .{ 6, 5 },   // FIPS depends on Formal
    .{ 7, 4 },   // Hybrid depends on GPU
    .{ 7, 5 },   // Hybrid depends on Formal
    .{ 7, 6 },   // Hybrid depends on FIPS
    .{ 8, 7 },   // ZK Basic depends on Hybrid
    .{ 9, 7 },   // MPC Basic depends on Hybrid
    .{ 10, 7 },  // FHE Basic depends on Hybrid
    .{ 11, 8 },  // Blockchain depends on ZK
    .{ 11, 9 },  // Blockchain depends on MPC
    .{ 11, 10 }, // Blockchain depends on FHE
    .{ 12, 8 },  // ZK Prod depends on ZK Basic
    .{ 12, 11 }, // ZK Prod depends on Blockchain
    .{ 13, 9 },  // MPC Prod depends on MPC Basic
    .{ 13, 11 }, // MPC Prod depends on Blockchain
    .{ 14, 10 }, // FHE Prod depends on FHE Basic
    .{ 14, 11 }, // FHE Prod depends on Blockchain
    .{ 15, 12 }, // Quantum depends on ZK Prod
    .{ 15, 13 }, // Quantum depends on MPC Prod
    .{ 15, 14 }, // Quantum depends on FHE Prod
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

pub fn getInProgressTiers() i64 {
    var count: i64 = 0;
    for (tech_tree) |t| {
        if (t.status == .InProgress) count += 1;
    }
    return count;
}

pub fn getPlannedTiers() i64 {
    var count: i64 = 0;
    for (tech_tree) |t| {
        if (t.status == .Planned) count += 1;
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

pub fn getCompletionPercent() f64 {
    const complete = getCompleteTiers();
    return @as(f64, @floatFromInt(complete)) / @as(f64, @floatFromInt(tech_tree.len)) * 100.0;
}

pub fn getMaxSpeedup() f64 {
    var max: f64 = 0.0;
    for (tech_tree) |t| {
        if (t.speedup > max) max = t.speedup;
    }
    return max;
}

pub fn getVersionImprovement(v1: usize, v2: usize) f64 {
    const t1 = versions[v1].tests;
    const t2 = versions[v2].tests;
    return @as(f64, @floatFromInt(t2 - t1)) / @as(f64, @floatFromInt(t1)) * 100.0;
}

pub fn getNextTier() []const u8 {
    for (tech_tree) |t| {
        if (t.status == .InProgress) return t.name;
    }
    for (tech_tree) |t| {
        if (t.status == .Planned) return t.name;
    }
    return "All complete";
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "15 tiers defined" {
    try std.testing.expectEqual(@as(usize, 15), tech_tree.len);
}

test "6 tiers complete" {
    const complete = getCompleteTiers();
    try std.testing.expectEqual(@as(i64, 6), complete);
}

test "2 tiers in progress" {
    const in_progress = getInProgressTiers();
    try std.testing.expectEqual(@as(i64, 2), in_progress);
}

test "6 tiers planned" {
    const planned = getPlannedTiers();
    try std.testing.expectEqual(@as(i64, 6), planned);
}

test "Completion 40%" {
    const pct = getCompletionPercent();
    try std.testing.expectApproxEqAbs(@as(f64, 40.0), pct, 0.1);
}

test "Total tests > 800" {
    const total = getTotalTests();
    try std.testing.expect(total > 800);
}

test "Max speedup 416x" {
    const max = getMaxSpeedup();
    try std.testing.expectApproxEqAbs(@as(f64, 416.0), max, 0.1);
}

test "4 versions tracked" {
    try std.testing.expectEqual(@as(usize, 4), versions.len);
}

test "V8 to V9 improvement > 40%" {
    const improvement = getVersionImprovement(0, 1);
    try std.testing.expect(improvement > 40.0);
}

test "V10 to V11 improvement > 5%" {
    const improvement = getVersionImprovement(2, 3);
    try std.testing.expect(improvement > 5.0);
}

test "23 dependencies defined" {
    try std.testing.expectEqual(@as(usize, 23), dependencies.len);
}

test "Next tier is Hybrid Crypto" {
    const next = getNextTier();
    try std.testing.expect(std.mem.eql(u8, next, "Hybrid Crypto"));
}

test "Tier 1 is Foundation" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[0].name, "Foundation"));
}

test "Tier 15 is Quantum Supremacy" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[14].name, "Quantum Supremacy"));
}

test "V11 has 1800 tests" {
    try std.testing.expectEqual(@as(i64, 1800), versions[3].tests);
}
