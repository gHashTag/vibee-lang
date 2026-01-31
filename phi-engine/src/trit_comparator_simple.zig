const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

const TritArray = struct {
    hash: i64,
    length: usize,
};

const ComparisonResult = struct {
    similarity: i8,
    hamming_distance: usize,
};

pub fn compareStreams(a: TritArray, b: TritArray, config: void) ComparisonResult {
    _ = config;
    const hash_diff = @abs(a.hash - b.hash);
    const length_diff = @abs(@as(i64, a.length) - @as(i64, b.length));
    
    const similarity: i8 = if (hash_diff == 0 and length_diff == 0) 1 else -1;
    const hamming_distance: usize = @as(usize, (hash_diff + length_diff) / 10);
    
    return ComparisonResult{
        .similarity = similarity,
        .hamming_distance = hamming_distance,
    };
}

test "testCompareStreamsIdentical" {
    const text = "fibonacci";
    const hash: i64 = 123456;
    
    const stream1 = TritArray{ .hash = hash, .length = text.len };
    const stream2 = TritArray{ .hash = hash, .length = text.len };
    
    const result = compareStreams(stream1, stream2, {});
    
    try std.testing.expectEqual(@as(i8, 1), result.similarity);
    try std.testing.expectEqual(@as(usize, 0), result.hamming_distance);
}

test "testGoldenIdentity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
