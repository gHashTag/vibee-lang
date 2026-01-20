const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// TECHNOLOGY TREE V6 - 30 Tiers with Milestones
// ═══════════════════════════════════════════════════════════════

pub const TierStatus = enum { Complete, InProgress, New, Planned, Research };

pub const TechTier = struct {
    id: i64,
    name: []const u8,
    status: TierStatus,
    tests: i64,
    milestone: i64,
};

pub const Milestone = struct {
    id: i64,
    name: []const u8,
    status: []const u8,
    target: []const u8,
    tiers_start: i64,
    tiers_end: i64,
};

pub const VersionInfo = struct {
    version: []const u8,
    tests: i64,
};

// 30 Technology Tiers
pub const tech_tree = [_]TechTier{
    // Milestone 1: Foundation (Complete)
    .{ .id = 1, .name = "Foundation", .status = .Complete, .tests = 156, .milestone = 1 },
    .{ .id = 2, .name = "Core Crypto", .status = .Complete, .tests = 245, .milestone = 1 },
    .{ .id = 3, .name = "SIMD", .status = .Complete, .tests = 178, .milestone = 1 },
    .{ .id = 4, .name = "GPU", .status = .Complete, .tests = 136, .milestone = 1 },
    .{ .id = 5, .name = "Formal Verification", .status = .Complete, .tests = 89, .milestone = 1 },
    .{ .id = 6, .name = "FIPS 140-3", .status = .Complete, .tests = 67, .milestone = 1 },
    // Milestone 2: Privacy Primitives (In Progress)
    .{ .id = 7, .name = "Hybrid Crypto", .status = .InProgress, .tests = 26, .milestone = 2 },
    .{ .id = 8, .name = "ZK Basic", .status = .InProgress, .tests = 27, .milestone = 2 },
    .{ .id = 9, .name = "FHE Basic", .status = .InProgress, .tests = 13, .milestone = 2 },
    .{ .id = 10, .name = "MPC Basic", .status = .InProgress, .tests = 12, .milestone = 2 },
    .{ .id = 11, .name = "TEE", .status = .InProgress, .tests = 12, .milestone = 2 },
    .{ .id = 12, .name = "Threshold", .status = .InProgress, .tests = 12, .milestone = 2 },
    // Milestone 3: Distributed (New/Planned)
    .{ .id = 13, .name = "Differential Privacy", .status = .New, .tests = 0, .milestone = 3 },
    .{ .id = 14, .name = "Oblivious RAM", .status = .New, .tests = 0, .milestone = 3 },
    .{ .id = 15, .name = "Searchable Encryption", .status = .New, .tests = 0, .milestone = 3 },
    .{ .id = 16, .name = "Secure Aggregation", .status = .Planned, .tests = 0, .milestone = 3 },
    .{ .id = 17, .name = "Blockchain", .status = .Planned, .tests = 0, .milestone = 3 },
    .{ .id = 18, .name = "Consensus", .status = .Planned, .tests = 0, .milestone = 3 },
    // Milestone 4: ML Privacy (Planned)
    .{ .id = 19, .name = "Private ML Inference", .status = .Planned, .tests = 0, .milestone = 4 },
    .{ .id = 20, .name = "Federated Learning", .status = .Planned, .tests = 0, .milestone = 4 },
    .{ .id = 21, .name = "Verifiable Computation", .status = .Planned, .tests = 0, .milestone = 4 },
    .{ .id = 22, .name = "Model Protection", .status = .Planned, .tests = 0, .milestone = 4 },
    .{ .id = 23, .name = "Synthetic Data", .status = .Planned, .tests = 0, .milestone = 4 },
    .{ .id = 24, .name = "Privacy Budgets", .status = .Planned, .tests = 0, .milestone = 4 },
    // Milestone 5: Production (Research)
    .{ .id = 25, .name = "ZK Production", .status = .Research, .tests = 0, .milestone = 5 },
    .{ .id = 26, .name = "FHE Production", .status = .Research, .tests = 0, .milestone = 5 },
    .{ .id = 27, .name = "MPC Production", .status = .Research, .tests = 0, .milestone = 5 },
    .{ .id = 28, .name = "Quantum-Safe", .status = .Research, .tests = 0, .milestone = 5 },
    .{ .id = 29, .name = "Post-Quantum TLS", .status = .Research, .tests = 0, .milestone = 5 },
    .{ .id = 30, .name = "Quantum Supremacy", .status = .Research, .tests = 0, .milestone = 5 },
};

// 5 Milestones
pub const milestones = [_]Milestone{
    .{ .id = 1, .name = "Foundation", .status = "ACHIEVED", .target = "2025 Q2", .tiers_start = 1, .tiers_end = 6 },
    .{ .id = 2, .name = "Privacy Primitives", .status = "IN_PROGRESS", .target = "2027 Q4", .tiers_start = 7, .tiers_end = 12 },
    .{ .id = 3, .name = "Distributed", .status = "PLANNED", .target = "2028 Q4", .tiers_start = 13, .tiers_end = 18 },
    .{ .id = 4, .name = "ML Privacy", .status = "PLANNED", .target = "2029 Q4", .tiers_start = 19, .tiers_end = 24 },
    .{ .id = 5, .name = "Production", .status = "RESEARCH", .target = "2032+", .tiers_start = 25, .tiers_end = 30 },
};

// Version History
pub const versions = [_]VersionInfo{
    .{ .version = "V8", .tests = 995 },
    .{ .version = "V9", .tests = 1475 },
    .{ .version = "V10", .tests = 1660 },
    .{ .version = "V11", .tests = 1741 },
    .{ .version = "V12", .tests = 2967 },
    .{ .version = "V13", .tests = 3119 },
    .{ .version = "V14", .tests = 3250 },
};

pub fn getTotalTiers() i64 { return tech_tree.len; }

pub fn getCompleteTiers() i64 {
    var count: i64 = 0;
    for (tech_tree) |t| { if (t.status == .Complete) count += 1; }
    return count;
}

pub fn getMilestoneProgress(milestone_id: i64) f64 {
    var complete: i64 = 0;
    var total: i64 = 0;
    for (tech_tree) |t| {
        if (t.milestone == milestone_id) {
            total += 1;
            if (t.status == .Complete) complete += 1;
        }
    }
    return if (total > 0) @as(f64, @floatFromInt(complete)) / @as(f64, @floatFromInt(total)) * 100.0 else 0.0;
}

pub fn getTotalTests() i64 {
    var total: i64 = 0;
    for (tech_tree) |t| { total += t.tests; }
    return total;
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "30 tiers defined" {
    try std.testing.expectEqual(@as(usize, 30), tech_tree.len);
}

test "6 complete tiers" {
    try std.testing.expectEqual(@as(i64, 6), getCompleteTiers());
}

test "5 milestones" {
    try std.testing.expectEqual(@as(usize, 5), milestones.len);
}

test "Milestone 1 is 100% complete" {
    const progress = getMilestoneProgress(1);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), progress, 0.1);
}

test "Milestone 2 is 0% complete" {
    const progress = getMilestoneProgress(2);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), progress, 0.1);
}

test "7 versions tracked" {
    try std.testing.expectEqual(@as(usize, 7), versions.len);
}

test "V14 has 3250 tests" {
    try std.testing.expectEqual(@as(i64, 3250), versions[6].tests);
}

test "Total tests > 900" {
    try std.testing.expect(getTotalTests() > 900);
}

test "Tier 1 is Foundation" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[0].name, "Foundation"));
}

test "Tier 30 is Quantum Supremacy" {
    try std.testing.expect(std.mem.eql(u8, tech_tree[29].name, "Quantum Supremacy"));
}

test "Milestone 1 achieved" {
    try std.testing.expect(std.mem.eql(u8, milestones[0].status, "ACHIEVED"));
}
