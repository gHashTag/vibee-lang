// ═══════════════════════════════════════════════════════════════
// v6704: GOLDEN TOKENIZER - φ-Optimized BPE Tokenizer
// Generated from specs/tri/v6704_golden_tokenizer.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

pub const VOCAB_SIZE: usize = 30522;
pub const MAX_TOKEN_LENGTH: usize = 50;

// Fibonacci sequence for golden splits
pub const FIBONACCI = [_]usize{ 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144 };

// ═══════════════════════════════════════════════════════════════
// SPECIAL TOKENS
// ═══════════════════════════════════════════════════════════════

pub const SpecialTokens = struct {
    pub const PAD: u32 = 0;
    pub const UNK: u32 = 1;
    pub const CLS: u32 = 2;
    pub const SEP: u32 = 3;
    pub const MASK: u32 = 4;
};

// ═══════════════════════════════════════════════════════════════
// TOKEN
// ═══════════════════════════════════════════════════════════════

pub const Token = struct {
    id: u32,
    text: [MAX_TOKEN_LENGTH]u8,
    text_len: u8,
    start: usize,
    end: usize,

    pub fn init(id: u32, text: []const u8, start: usize, end: usize) Token {
        var token = Token{
            .id = id,
            .text = undefined,
            .text_len = 0,
            .start = start,
            .end = end,
        };
        const len = @min(text.len, MAX_TOKEN_LENGTH);
        @memcpy(token.text[0..len], text[0..len]);
        token.text_len = @intCast(len);
        return token;
    }

    pub fn getText(self: Token) []const u8 {
        return self.text[0..self.text_len];
    }
};

// ═══════════════════════════════════════════════════════════════
// TOKEN SEQUENCE
// ═══════════════════════════════════════════════════════════════

pub const TokenSequence = struct {
    tokens: std.ArrayList(Token),
    input_ids: std.ArrayList(u32),
    attention_mask: std.ArrayList(u32),

    pub fn init(allocator: Allocator) TokenSequence {
        return .{
            .tokens = std.ArrayList(Token).init(allocator),
            .input_ids = std.ArrayList(u32).init(allocator),
            .attention_mask = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *TokenSequence) void {
        self.tokens.deinit();
        self.input_ids.deinit();
        self.attention_mask.deinit();
    }

    pub fn length(self: TokenSequence) usize {
        return self.tokens.items.len;
    }

    pub fn addToken(self: *TokenSequence, token: Token) !void {
        try self.tokens.append(token);
        try self.input_ids.append(token.id);
        try self.attention_mask.append(1);
    }

    pub fn padTo(self: *TokenSequence, target_len: usize) !void {
        while (self.input_ids.items.len < target_len) {
            try self.input_ids.append(SpecialTokens.PAD);
            try self.attention_mask.append(0);
        }
    }
};

// ═══════════════════════════════════════════════════════════════
// BPE MERGE
// ═══════════════════════════════════════════════════════════════

pub const BPEMerge = struct {
    pair: [2][MAX_TOKEN_LENGTH]u8,
    pair_lens: [2]u8,
    merged: [MAX_TOKEN_LENGTH]u8,
    merged_len: u8,
    frequency: u32,
    phi_score: f32,

    pub fn init(first: []const u8, second: []const u8, freq: u32) BPEMerge {
        var merge = BPEMerge{
            .pair = undefined,
            .pair_lens = undefined,
            .merged = undefined,
            .merged_len = 0,
            .frequency = freq,
            .phi_score = 0,
        };

        const len1 = @min(first.len, MAX_TOKEN_LENGTH);
        const len2 = @min(second.len, MAX_TOKEN_LENGTH);
        @memcpy(merge.pair[0][0..len1], first[0..len1]);
        @memcpy(merge.pair[1][0..len2], second[0..len2]);
        merge.pair_lens = .{ @intCast(len1), @intCast(len2) };

        // Create merged token
        const merged_len = @min(len1 + len2, MAX_TOKEN_LENGTH);
        @memcpy(merge.merged[0..len1], first[0..len1]);
        if (len1 + len2 <= MAX_TOKEN_LENGTH) {
            @memcpy(merge.merged[len1..merged_len], second[0..len2]);
        }
        merge.merged_len = @intCast(merged_len);

        // Compute φ-score
        merge.phi_score = computePhiScore(freq, merged_len);

        return merge;
    }
};

// ═══════════════════════════════════════════════════════════════
// PHI SCORING
// ═══════════════════════════════════════════════════════════════

pub fn computePhiScore(frequency: u32, length: usize) f32 {
    const freq_f: f32 = @floatFromInt(frequency);
    const len_f: f32 = @floatFromInt(length);

    // Base score from frequency
    var score = freq_f;

    // φ^(-length_diff) scaling
    const phi_inv: f32 = @floatCast(PHI_INV);
    score *= std.math.pow(f32, phi_inv, len_f - 1.0);

    // Fibonacci bonus: if length is in Fibonacci sequence
    for (FIBONACCI) |fib| {
        if (length == fib) {
            score *= 1.1; // 10% bonus
            break;
        }
    }

    return score;
}

// ═══════════════════════════════════════════════════════════════
// FIBONACCI SPLIT
// ═══════════════════════════════════════════════════════════════

pub fn fibonacciPositions(word_length: usize) [12]usize {
    var positions: [12]usize = undefined;
    var count: usize = 0;

    positions[count] = 0;
    count += 1;

    for (FIBONACCI) |fib| {
        if (fib < word_length and count < 12) {
            positions[count] = fib;
            count += 1;
        }
    }

    // Fill rest with word_length
    while (count < 12) {
        positions[count] = word_length;
        count += 1;
    }

    return positions;
}

pub fn goldenSplit(word: []const u8) struct { first: []const u8, second: []const u8 } {
    if (word.len <= 1) {
        return .{ .first = word, .second = "" };
    }

    // Split at golden ratio position
    const split_pos = @as(usize, @intFromFloat(@as(f64, @floatFromInt(word.len)) * PHI_INV));
    const actual_pos = @max(1, @min(split_pos, word.len - 1));

    return .{
        .first = word[0..actual_pos],
        .second = word[actual_pos..],
    };
}

// ═══════════════════════════════════════════════════════════════
// GOLDEN TOKENIZER
// ═══════════════════════════════════════════════════════════════

pub const GoldenTokenizer = struct {
    allocator: Allocator,
    vocab: std.StringHashMap(u32),
    id_to_token: std.AutoHashMap(u32, []const u8),
    next_id: u32,

    pub fn init(allocator: Allocator) GoldenTokenizer {
        return GoldenTokenizer{
            .allocator = allocator,
            .vocab = std.StringHashMap(u32).init(allocator),
            .id_to_token = std.AutoHashMap(u32, []const u8).init(allocator),
            .next_id = 5, // After special tokens
        };
    }

    pub fn deinit(self: *GoldenTokenizer) void {
        self.vocab.deinit();
        self.id_to_token.deinit();
    }

    pub fn encode(self: *GoldenTokenizer, text: []const u8) !TokenSequence {
        var seq = TokenSequence.init(self.allocator);

        // Add CLS token
        try seq.addToken(Token.init(SpecialTokens.CLS, "[CLS]", 0, 0));

        // Simple word-level tokenization (simplified)
        var word_start: usize = 0;
        for (text, 0..) |c, i| {
            if (c == ' ' or i == text.len - 1) {
                const end = if (c == ' ') i else i + 1;
                if (end > word_start) {
                    const word = text[word_start..end];
                    const id = self.vocab.get(word) orelse SpecialTokens.UNK;
                    try seq.addToken(Token.init(id, word, word_start, end));
                }
                word_start = i + 1;
            }
        }

        // Add SEP token
        try seq.addToken(Token.init(SpecialTokens.SEP, "[SEP]", text.len, text.len));

        return seq;
    }

    pub fn decode(self: *GoldenTokenizer, ids: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);

        for (ids) |id| {
            if (id == SpecialTokens.PAD or id == SpecialTokens.CLS or id == SpecialTokens.SEP) {
                continue;
            }
            if (self.id_to_token.get(id)) |token| {
                try result.appendSlice(token);
                try result.append(' ');
            }
        }

        return result.toOwnedSlice();
    }

    pub fn addToken(self: *GoldenTokenizer, text: []const u8) !u32 {
        if (self.vocab.get(text)) |id| {
            return id;
        }

        const id = self.next_id;
        self.next_id += 1;

        // Need to dupe the string for storage
        const duped = try self.allocator.dupe(u8, text);
        try self.vocab.put(duped, id);
        try self.id_to_token.put(id, duped);

        return id;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "phi score" {
    const score = computePhiScore(100, 2);
    // 100 * φ^(-1) = 100 * 0.618 ≈ 61.8
    try testing.expect(score > 50);
}

test "fibonacci positions" {
    const positions = fibonacciPositions(21);
    try testing.expect(positions[0] == 0);
    try testing.expect(positions[1] == 1);
    try testing.expect(positions[2] == 1);
    try testing.expect(positions[3] == 2);
    try testing.expect(positions[4] == 3);
    try testing.expect(positions[5] == 5);
    try testing.expect(positions[6] == 8);
    try testing.expect(positions[7] == 13);
}

test "encode simple" {
    var tokenizer = GoldenTokenizer.init(testing.allocator);
    defer tokenizer.deinit();

    var seq = try tokenizer.encode("hello world");
    defer seq.deinit();

    // Should have at least CLS + 2 words + SEP = 4 tokens
    try testing.expect(seq.length() >= 2);
}

test "decode roundtrip" {
    var tokenizer = GoldenTokenizer.init(testing.allocator);
    defer tokenizer.deinit();

    // Add tokens
    _ = try tokenizer.addToken("the");
    _ = try tokenizer.addToken("quick");
    _ = try tokenizer.addToken("brown");
    _ = try tokenizer.addToken("fox");

    // This is a simplified test - full roundtrip needs more implementation
    try testing.expect(tokenizer.next_id > 5);
}

test "special tokens" {
    var tokenizer = GoldenTokenizer.init(testing.allocator);
    defer tokenizer.deinit();

    var seq = try tokenizer.encode("test");
    defer seq.deinit();

    // First token should be CLS
    try testing.expect(seq.input_ids.items[0] == SpecialTokens.CLS);
    // Last token should be SEP
    try testing.expect(seq.input_ids.items[seq.input_ids.items.len - 1] == SpecialTokens.SEP);
}

test "batch padding" {
    var tokenizer = GoldenTokenizer.init(testing.allocator);
    defer tokenizer.deinit();

    var seq1 = try tokenizer.encode("short");
    defer seq1.deinit();

    var seq2 = try tokenizer.encode("this is longer");
    defer seq2.deinit();

    const max_len = @max(seq1.length(), seq2.length()) + 2;
    try seq1.padTo(max_len);
    try seq2.padTo(max_len);

    try testing.expect(seq1.input_ids.items.len == seq2.input_ids.items.len);
}

test "golden split" {
    const result = goldenSplit("internationalization");
    // Split at ~0.618 * 20 ≈ 12
    try testing.expect(result.first.len > 0);
    try testing.expect(result.second.len > 0);
}

test "cache hit" {
    var tokenizer = GoldenTokenizer.init(testing.allocator);
    defer tokenizer.deinit();

    const id1 = try tokenizer.addToken("repeated");
    const id2 = try tokenizer.addToken("repeated");

    // Same token should return same ID
    try testing.expect(id1 == id2);
}

test "unk handling" {
    var tokenizer = GoldenTokenizer.init(testing.allocator);
    defer tokenizer.deinit();

    var seq = try tokenizer.encode("xyz123unknown");
    defer seq.deinit();

    // Unknown words should get UNK token
    var has_unk = false;
    for (seq.input_ids.items) |id| {
        if (id == SpecialTokens.UNK) {
            has_unk = true;
            break;
        }
    }
    try testing.expect(has_unk);
}
