const std = @import("std");

pub const GOLDEN_IDENTITY: f64 = 3.0;

const TritArray = struct {
    hash: i64,
};

pub fn compareTritArrays(a: TritArray, b: TritArray) bool {
    return a.hash == b.hash;
}

pub fn stringToTritHash(text: []const u8) i64 {
    var hash: i64 = 0;
    for (text) |char| {
        hash = @mod(hash * 31 + @as(i64, char), 1000000007);
    }
    return hash;
}

test "testStringToTritHash" {
    const text1 = "fibonacci";
    const text2 = "fibonacci";
    
    const hash1 = stringToTritHash(text1);
    const hash2 = stringToTritHash(text2);
    
    try std.testing.expectEqual(hash1, hash2);
}

test "testCompareTritArrays" {
    const text1 = "fibonacci";
    const text2 = "fibonacci";
    
    const trit1 = TritArray{ .hash = stringToTritHash(text1) };
    const trit2 = TritArray{ .hash = stringToTritHash(text2) };
    
    try std.testing.expect(compareTritArrays(trit1, trit2));
}
