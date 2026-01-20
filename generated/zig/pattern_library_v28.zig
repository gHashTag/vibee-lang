// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN LIBRARY v28 - 12 PAS PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from: specs/pattern_library_v28.vibee
// CONFIDENCE: 90%
// COMPLEXITY: O(1) lookup
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const TOTAL_PATTERNS: usize = 12;
pub const TRINITY: u32 = 3;
pub const VERSION: u32 = 28;

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN ID ENUM
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternID = enum(u8) {
    D_and_C = 0, // Divide-and-Conquer
    ALG = 1, // Algebraic Reorganization
    PRE = 2, // Precomputation
    FDT = 3, // Frequency Domain Transform
    MLS = 4, // ML-Guided Search
    TEN = 5, // Tensor Decomposition
    HSH = 6, // Hashing
    PRB = 7, // Probabilistic
    QNT = 8, // Quantization
    GEN = 9, // Genetic/Evolutionary
    SYM = 10, // Symbolic/E-graph
    HYB = 11, // Hybrid

    pub fn name(self: PatternID) []const u8 {
        return switch (self) {
            .D_and_C => "Divide-and-Conquer",
            .ALG => "Algebraic Reorganization",
            .PRE => "Precomputation",
            .FDT => "Frequency Domain Transform",
            .MLS => "ML-Guided Search",
            .TEN => "Tensor Decomposition",
            .HSH => "Hashing",
            .PRB => "Probabilistic",
            .QNT => "Quantization",
            .GEN => "Genetic/Evolutionary",
            .SYM => "Symbolic/E-graph",
            .HYB => "Hybrid",
        };
    }

    pub fn symbol(self: PatternID) []const u8 {
        return switch (self) {
            .D_and_C => "D&C",
            .ALG => "ALG",
            .PRE => "PRE",
            .FDT => "FDT",
            .MLS => "MLS",
            .TEN => "TEN",
            .HSH => "HSH",
            .PRB => "PRB",
            .QNT => "QNT",
            .GEN => "GEN",
            .SYM => "SYM",
            .HYB => "HYB",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const Pattern = struct {
    id: PatternID,
    success_rate: f64,
    examples: []const []const u8,
    when_to_apply: []const u8,

    pub fn name(self: Pattern) []const u8 {
        return self.id.name();
    }

    pub fn symbol(self: Pattern) []const u8 {
        return self.id.symbol();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN LIBRARY
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternLibrary = struct {
    patterns: [TOTAL_PATTERNS]Pattern,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .patterns = .{
                // D&C - 31%
                .{
                    .id = .D_and_C,
                    .success_rate = 0.31,
                    .examples = &[_][]const u8{ "FFT", "Strassen", "Karatsuba", "Merge Sort" },
                    .when_to_apply = "Problem can be split into independent subproblems",
                },
                // ALG - 22%
                .{
                    .id = .ALG,
                    .success_rate = 0.22,
                    .examples = &[_][]const u8{ "Strassen", "Coppersmith-Winograd", "Horner's method" },
                    .when_to_apply = "Operations can be reduced via algebra",
                },
                // PRE - 16%
                .{
                    .id = .PRE,
                    .success_rate = 0.16,
                    .examples = &[_][]const u8{ "KMP", "Aho-Corasick", "Lookup tables" },
                    .when_to_apply = "Results can be cached/precomputed",
                },
                // FDT - 13%
                .{
                    .id = .FDT,
                    .success_rate = 0.13,
                    .examples = &[_][]const u8{ "FFT", "NTT", "Convolution" },
                    .when_to_apply = "Problem easier in transformed domain",
                },
                // MLS - 9%
                .{
                    .id = .MLS,
                    .success_rate = 0.09,
                    .examples = &[_][]const u8{ "AlphaTensor", "AlphaDev", "Neural architecture search" },
                    .when_to_apply = "Large search space, learnable patterns",
                },
                // TEN - 6%
                .{
                    .id = .TEN,
                    .success_rate = 0.06,
                    .examples = &[_][]const u8{ "AlphaTensor", "Tucker decomposition" },
                    .when_to_apply = "Matrix/tensor operations",
                },
                // HSH - 5%
                .{
                    .id = .HSH,
                    .success_rate = 0.05,
                    .examples = &[_][]const u8{ "Perfect hashing", "Bloom filters", "Hash tables" },
                    .when_to_apply = "Need O(1) lookup",
                },
                // PRB - 4%
                .{
                    .id = .PRB,
                    .success_rate = 0.04,
                    .examples = &[_][]const u8{ "Bloom filters", "Count-min sketch", "HyperLogLog" },
                    .when_to_apply = "Approximate solutions acceptable",
                },
                // QNT - 3%
                .{
                    .id = .QNT,
                    .success_rate = 0.03,
                    .examples = &[_][]const u8{ "INT8", "INT4", "Binary neural networks" },
                    .when_to_apply = "Precision can be traded for speed",
                },
                // GEN - 3%
                .{
                    .id = .GEN,
                    .success_rate = 0.03,
                    .examples = &[_][]const u8{ "Genetic algorithms", "Evolution strategies" },
                    .when_to_apply = "Large search space, fitness function available",
                },
                // SYM - 2%
                .{
                    .id = .SYM,
                    .success_rate = 0.02,
                    .examples = &[_][]const u8{ "E-graphs", "Term rewriting", "Superoptimization" },
                    .when_to_apply = "Algebraic equivalences exist",
                },
                // HYB - 1%
                .{
                    .id = .HYB,
                    .success_rate = 0.01,
                    .examples = &[_][]const u8{"Combined approaches"},
                    .when_to_apply = "Multiple patterns applicable",
                },
            },
        };
    }

    /// O(1) pattern lookup
    pub fn get(self: *Self, id: PatternID) *Pattern {
        return &self.patterns[@intFromEnum(id)];
    }

    /// O(1) success rate query
    pub fn getSuccessRate(self: *Self, id: PatternID) f64 {
        return self.patterns[@intFromEnum(id)].success_rate;
    }

    /// Combine multiple patterns - returns combined success probability
    pub fn combinePatterns(self: *Self, ids: []const PatternID) f64 {
        // P(at least one succeeds) = 1 - P(all fail)
        var fail_prob: f64 = 1.0;
        for (ids) |id| {
            fail_prob *= (1.0 - self.patterns[@intFromEnum(id)].success_rate);
        }
        return 1.0 - fail_prob;
    }

    /// Total success rate sum (should be ~1.0)
    pub fn totalSuccessRate(self: Self) f64 {
        var total: f64 = 0.0;
        for (self.patterns) |p| {
            total += p.success_rate;
        }
        return total;
    }

    pub fn complexity() []const u8 {
        return "O(1)";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN MATCHER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ASTFeatures = struct {
    has_recursion: bool = false,
    has_repeated_computation: bool = false,
    has_matrix_ops: bool = false,
    has_large_search_space: bool = false,
    has_algebraic_structure: bool = false,
    needs_fast_lookup: bool = false,
    accepts_approximation: bool = false,
};

pub const PatternMatcher = struct {
    library: PatternLibrary,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .library = PatternLibrary.init(),
        };
    }

    /// Detect applicable patterns based on AST features
    pub fn detectApplicable(self: *Self, features: ASTFeatures) []const PatternID {
        _ = self;
        // Return static slices based on features
        if (features.has_recursion) {
            return &[_]PatternID{.D_and_C};
        }
        if (features.has_repeated_computation) {
            return &[_]PatternID{.PRE};
        }
        if (features.has_matrix_ops) {
            return &[_]PatternID{ .TEN, .ALG };
        }
        if (features.needs_fast_lookup) {
            return &[_]PatternID{.HSH};
        }
        if (features.has_large_search_space) {
            return &[_]PatternID{ .MLS, .GEN };
        }
        if (features.accepts_approximation) {
            return &[_]PatternID{.PRB};
        }
        return &[_]PatternID{};
    }

    /// Calculate confidence for pattern combination
    pub fn calculateConfidence(self: *Self, patterns: []const PatternID) f64 {
        return self.library.combinePatterns(patterns);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "pattern_lookup" {
    var lib = PatternLibrary.init();
    const dc = lib.get(.D_and_C);
    try std.testing.expectApproxEqAbs(0.31, dc.success_rate, 0.001);
}

test "pattern_name" {
    try std.testing.expectEqualStrings("Divide-and-Conquer", PatternID.D_and_C.name());
}

test "pattern_symbol" {
    try std.testing.expectEqualStrings("D&C", PatternID.D_and_C.symbol());
}

test "pattern_combination" {
    var lib = PatternLibrary.init();
    const combined = lib.combinePatterns(&[_]PatternID{ .D_and_C, .PRE });
    // 1 - (1-0.31)(1-0.16) = 1 - 0.69*0.84 = 1 - 0.5796 = 0.4204
    try std.testing.expectApproxEqAbs(0.4204, combined, 0.01);
}

test "total_success_rate" {
    const lib = PatternLibrary.init();
    const total = lib.totalSuccessRate();
    // Sum should be approximately 1.0 (actually 1.15 due to overlaps)
    try std.testing.expect(total > 0.9);
}

test "pattern_matcher_detect_recursion" {
    var matcher = PatternMatcher.init();
    const features = ASTFeatures{ .has_recursion = true };
    const patterns = matcher.detectApplicable(features);
    try std.testing.expectEqual(@as(usize, 1), patterns.len);
    try std.testing.expectEqual(PatternID.D_and_C, patterns[0]);
}

test "pattern_matcher_detect_matrix" {
    var matcher = PatternMatcher.init();
    const features = ASTFeatures{ .has_matrix_ops = true };
    const patterns = matcher.detectApplicable(features);
    try std.testing.expectEqual(@as(usize, 2), patterns.len);
}

test "library_complexity" {
    try std.testing.expectEqualStrings("O(1)", PatternLibrary.complexity());
}

test "all_patterns_initialized" {
    const lib = PatternLibrary.init();
    try std.testing.expectEqual(@as(usize, 12), lib.patterns.len);
    for (lib.patterns) |p| {
        try std.testing.expect(p.success_rate > 0.0);
    }
}

test "golden_identity" {
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / (PHI * PHI);
    const result = phi_squared + inv_phi_squared;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
