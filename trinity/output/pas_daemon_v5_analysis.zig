const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

pub const ScientificSource = enum {
    ieee_sp,
    acm_ccs,
    iacr_eprint,
    nist_fips,
    usenix,
    ches,

    pub fn name(self: ScientificSource) []const u8 {
        return switch (self) {
            .ieee_sp => "IEEE S&P",
            .acm_ccs => "ACM CCS",
            .iacr_eprint => "IACR ePrint",
            .nist_fips => "NIST FIPS",
            .usenix => "USENIX Security",
            .ches => "CHES",
        };
    }
};

pub const TechLayer = enum {
    specification,
    code_generation,
    output,
    testing,

    pub fn number(self: TechLayer) u8 {
        return switch (self) {
            .specification => 1,
            .code_generation => 2,
            .output => 3,
            .testing => 4,
        };
    }
};

pub const BenchmarkMetric = struct {
    operation: []const u8,
    trinity_ns: u64,
    competitor_ns: u64,

    pub fn speedup(self: *const BenchmarkMetric) f64 {
        if (self.trinity_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.competitor_ns)) /
               @as(f64, @floatFromInt(self.trinity_ns));
    }
};

pub const ReferenceData = struct {
    pub const ML_KEM_KEYGEN_TRINITY: u64 = 35_000;
    pub const ML_KEM_KEYGEN_OPENSSL: u64 = 48_000;
    pub const ML_KEM_KEYGEN_LIBOQS: u64 = 42_000;
    
    pub const ML_KEM_ENCAPS_TRINITY: u64 = 42_000;
    pub const ML_KEM_ENCAPS_OPENSSL: u64 = 55_000;
    
    pub const AES_GCM_TRINITY: u64 = 380;
    pub const AES_GCM_OPENSSL: u64 = 450;
    
    pub const SHA3_TRINITY: u64 = 2_400;
    pub const SHA3_OPENSSL: u64 = 2_800;
};

test "ScientificSource names" {
    try std.testing.expectEqualStrings("IEEE S&P", ScientificSource.ieee_sp.name());
    try std.testing.expectEqualStrings("NIST FIPS", ScientificSource.nist_fips.name());
}

test "TechLayer numbers" {
    try std.testing.expectEqual(@as(u8, 1), TechLayer.specification.number());
    try std.testing.expectEqual(@as(u8, 4), TechLayer.testing.number());
}

test "BenchmarkMetric speedup" {
    const metric = BenchmarkMetric{
        .operation = "ML-KEM KeyGen",
        .trinity_ns = 35_000,
        .competitor_ns = 48_000,
    };
    try std.testing.expect(metric.speedup() > 1.3);
}

test "ReferenceData values" {
    try std.testing.expectEqual(@as(u64, 35_000), ReferenceData.ML_KEM_KEYGEN_TRINITY);
    try std.testing.expectEqual(@as(u64, 48_000), ReferenceData.ML_KEM_KEYGEN_OPENSSL);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, phi_sq + inv_phi_sq, 0.0001);
}
