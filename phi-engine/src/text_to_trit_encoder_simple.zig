const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

const Trit = struct {
    value: i8,

    pub fn toString(self: Trit) u8 {
        return switch (self.value) {
            1 => 'P',
            0 => '0',
            -1 => 'N',
            else => '?',
        };
    }
};

const TritArray = struct {
    hash: i64,
    length: usize,
};

pub fn textToTrits(text: []const u8) TritArray {
    const hash = stringToTritHash(text);
    return TritArray{
        .hash = hash,
        .length = text.len,
    };
}

fn stringToTritHash(text: []const u8) i64 {
    var hash: i64 = 0;
    for (text) |char| {
        hash = @mod(hash * 31 + @as(i64, char), 1000000007);
    }
    return hash;
}

test "testTextToTrits" {
    const text = "fibonacci";
    const trits = textToTrits(text);

    try std.testing.expect(trits.length == text.len);
}

test "testGoldenIdentity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
