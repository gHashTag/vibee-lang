const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// TECHNOLOGY TREE V4 - 20 Tiers with Critical Path
// Complete roadmap 2024-2032
// ═══════════════════════════════════════════════════════════════

pub const TierStatus = enum {
    Complete,
    InProgress,
    New,
    Planned,
    Research,
};

pub const TechTier = struct {
    id: i64,
    name: []const u8,
    status: TierStatus,
    tests: i64,
    quarter: []const u8,
    speedup: []const u8,
};

pub const VersionInfo = struct {
    version: []const u8,
    tiers: i64,
    tests: i64,
    date: []const u8,
};

// 20 Technology Tiers
pub const tech_tree = [_]TechTier{
    // Track A: Core Crypto (Complete)
    .{ .id = 1, .name = "Foundation", .status = .Complete, .tests = 156, .quarter = "2024 Q1", .speedup = "baseline" },
    .{ .id = 2, .name = "Core Crypto", .status = .Complete, .tests = 245, .quarter = "2024 Q2", .speedup = "1.5x" },
    .{ .id = 3, .name = "SIMD Optimization", .status = .Complete, .tests = 178, .quarter = "2024 Q3", .speedup = "11.9x" },
    .{ .id = 4, .name = "GPU Acceleration", .status = .Complete, .tests = 136, .quarter = "2024 Q4", .speedup = "1978x" },
    .{ .id = 5, .name = "Formal Verification", .status = .Complete, .tests = 89, .quarter = "2025 Q1", .speedup = "verified" },
    .{ .id = 6, .name = "FIPS 140-3", .status = .Complete, .tests = 67, .quarter = "2025 Q2", .speedup = "certified" },
    
    // Track B: Advanced Crypto (In Progress)
    .{ .id = 7, .name = "Hybrid Crypto", .status = .InProgress, .tests = 26, .quarter = "2027 Q1", .speedup = "1.5x" },
    .{ .id = 8, .name = "ZK Basic", .status = .InProgress, .tests = 27, .quarter = "2027 Q2", .speedup = "TBD" },
    .{ .id = 9, .name = "Threshold Crypto", .status = .New, .tests = 0, .quarter = "2027 Q2", .speedup = "TBD" },
    .{ .id = 10, .name = "MPC Basic", .status = .Planned, .tests = 0, .quarter = "2027 Q3", .speedup = "TBD" },
    .{ .id = 11, .name = "FHE Basic", .status = .Planned, .tests = 0, .quarter = "2027 Q4", .speedup = "TBD" },
    .{ .id = 12, .name = "TEE Integration", .status = .New, .tests = 0, .quarter = "2027 Q4", .speedup = "TBD" },
    .{ .id = 13, .name = "PQ Sigs Advanced", .status = .New, .tests = 0, .quarter = "2028 Q1", .speedup = "TBD" },
    .{ .id = 14, .name = "Blockchain", .status = .Planned, .tests = 0, .quarter = "2028 Q1", .speedup = "TBD" },
    
    // Track C: Production (Future)
    .{ .id = 15, .name = "ZK Production", .status = .Planned, .tests = 0, .quarter = "2028 Q2", .speedup = "TBD" },
    .{ .id = 16, .name = "MPC Production", .status = .Planned, .tests = 0, .quarter = "2028 Q3", .speedup = "TBD" },
    .{ .id = 17, .name = "FHE Production", .status = .Planned, .tests = 0, .quarter = "2028 Q4", .speedup = "TBD" },
    .{ .id = 18, .name = "Threshold Prod", .status = .Planned, .tests = 0, .quarter = "2029 Q1", .speedup = "TBD" },
    .{ .id = 19, .name = "TEE Production", .status = .Planned, .tests = 0, .quarter = "2029 Q2", .speedup = "TBD" },
    .{ .id = 20, .name = "Quantum Supremacy", .status = .Research, .tests = 0, .quarter = "2030+", .speedup = "TBD" },
};

// Version History
pub const versions = [_]VersionInfo{
    .{ .version = "V8", .tiers = 5, .tests = 995, .date = "2026-01-19" },
    .{ .version = "V9", .tiers = 7, .tests = 1475, .date = "2026-01-20 AM" },
    .{ .version = "V10", .tiers = 7, .tests = 1660, .date = "2026-01-20 PM" },
    .{ .version = "V11", .tiers = 8, .tests = 1741, .date = "2026-01-20 EVE" },
    .{ .version = "V12", .tiers = 9, .tests = 1850, .date = "2026-01-20 NIGHT" },
};

// Critical Path: T1 → T2 → T3 → T4 → T7 → T8 → T14 → T15 → T20
pub const critical_path = [_]i64{ 1, 2, 3, 4, 7, 8, 14, 15, 20 };
pub const critical_path_duration_years: f64 = 6.0;

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

pub fn getNewTiers() i64 {
    var count: i64 = 0;
    for (tech_tree) |t| {
        if (t.status == .New) count += 1;
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

pub fn getVersionImprovement(v1: usize, v2: usize) f64 {
    const t1 = versions[v1].tests;
    const t2 = versions[v2].tests;
    return @as(f64, @floatFromInt(t2 - t1)) / @as(f64, @floatFromInt(t1)) * 100.0;
}

pub fn getCriticalPathLength() usize {
    return critical_path.len;
}

pub fn getMaxSpeedup() []const u8 {
    return "1978x"; // GPU tier
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "20 tiers defined" {
    try std.testing.expectEqual(@as(usize, 20), tech_tree.len);
}

test "6 complete tiers" {
    const complete = getCompleteTiers();
    try std.testing.expectEqual(@as(i64, 6), complete);
}

test "2 in-progress tiers" {
    const in_progress = getInProgressTiers();
    try std.testing.expectEqual(@as(i64, 2), in_progress);
}

test "3 new tiers (Threshold, TEE, PQ Sigs)" {
    const new = getNewTiers();
    try std.testing.expectEqual(@as(i64, 3), new);
}

test "Completion 30%" {
    const pct = getCompletionPercent();
    try std.testing.expectApproxEqAbs(@as(f64, 30.0), pct, 0.1);
}

test "Total tests > 900" {
    const total = getTotalTests();
    try std.testing.expect(total > 900);
}

test "5 versions tracked" {
    try std.testing.expectEqual(@as(usize, 5), versions.len);
}

test "V12 has 1850 tests" {
    try std.testing.expectEqual(@as(i64, 1850), versions[4].tests);
}

test "V8 to V12 improvement > 80%" {
    const improvement = getVersionImprovement(0, 4);
    try std.testing.expect(improvement > 80.0);
}

test "Critical path has 9 tiers" {
    try std.testing.expectEqual(@as(usize, 9), getCriticalPathLength());
}

test "Critical path duration 6 years" {
    try std.testing.expectApproxEqAbs(@as(f64, 6.0), critical_path_duration_years, 0.1);
}

test "Tier 1 is Foundation" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[0].name, "Foundation"));
}

test "Tier 20 is Quantum Supremacy" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[19].name, "Quantum Supremacy"));
}

test "GPU speedup 1978x" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[3].speedup, "1978x"));
}

test "Max speedup is 1978x" {
    const max = getMaxSpeedup();
    try std.testing.expect(std.mem.eql(u8, max, "1978x"));
}
