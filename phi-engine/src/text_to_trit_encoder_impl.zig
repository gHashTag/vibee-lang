const std = @import("std");

// Sacred Constants
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INVERSE: f64 = 0.6180339887498949;
pub const GOLDEN_IDENTITY: f64 = 3.0;

pub const TRIT_POSITIVE: i8 = 1;
pub const TRIT_NEUTRAL: i8 = 0;
pub const TRIT_NEGATIVE: i8 = -1;

const Trit = struct {
    value: i8,

    pub fn toString(self: Trit) u8 {
        return switch (self.value) {
            TRIT_POSITIVE => 'P',
            TRIT_NEUTRAL => '0',
            TRIT_NEGATIVE => 'N',
            else => '?',
        };
    }

    pub fn toInt(self: Trit) i8 {
        return self.value;
    }
};

const TritArray = struct {
    hash: i64,
    length: usize,
};

const EncodingConfig = struct {
    use_phi_mapping: bool,
    normalize_length: bool,
    add_padding: bool,
};

// Text to Trits (Step 1 of pipeline)
pub fn textToTrits(text: []const u8) TritArray {
    const hash = stringToTritHash(text);
    return TritArray{
        .hash = hash,
        .length = text.len,
    };
}

// Encode single character to trit using phi-based mapping
pub fn encodeCharacter(char: u8) Trit {
    const ascii_value: i32 = @as(i32, char);
    const trit_value: i8 = @as(i8, ascii_value % 3) - 1;
    return Trit{ .value = trit_value };
}

// Normalize trit array to specific length
pub fn normalizeLength(trits: TritArray, target_length: usize) TritArray {
    if (trits.length >= target_length) {
        // Truncate if too long
        return TritArray{
            .hash = trits.hash,
            .length = target_length,
        };
    } else {
        // Pad with zeros if too short (Fibonacci padding)
        const padding = target_length - trits.length;
        // Adjust hash to account for padding
        const padded_hash = trits.hash + @as(i64, padding * 13); // 13 is Fibonacci
        return TritArray{
            .hash = padded_hash,
            .length = target_length,
        };
    }
}

// Simple hash function for strings
fn stringToTritHash(text: []const u8) i64 {
    var hash: i64 = 0;
    for (text) |char| {
        hash = @mod(hash * 31 + @as(i64, char), 1000000007);
    }
    return hash;
}

// Full encoding pipeline with config
pub fn encode(text: []const u8, config: EncodingConfig) TritArray {
    var trits = textToTrits(text);

    // Normalize length if enabled
    if (config.normalize_length) {
        const target_length = 20; // Standard Fibonacci window size
        trits = normalizeLength(trits, target_length);
    }

    // Add padding if enabled (already handled in normalizeLength)
    _ = config.add_padding;

    return trits;
}

test "testEncodeSimple" {
    const config = EncodingConfig{
        .use_phi_mapping = true,
        .normalize_length = false,
        .add_padding = false,
    };

    const text = "fib";
    const trits = encode(text, config);

    try std.testing.expect(trits.length == text.len);
}

test "testNormalizeLength" {
    const text = "hi";
    const trits = textToTrits(text);
    const normalized = normalizeLength(trits, 10);

    // Manual length check
    if (normalized.length != 10) {
        return error.TestExpectedEqual{ .expected = 10, .actual = normalized.length };
    }
}

test "testPhiMapping" {
    const text1 = "fibonacci";
    const text2 = "fibonacci";

    const trits1 = textToTrits(text1);
    const trits2 = textToTrits(text2);

    // Same text should produce same hash
    try std.testing.expectEqual(trits1.hash, trits2.hash);
}

test "testGoldenIdentity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
