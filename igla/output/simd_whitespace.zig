// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲒⲘⲆ ⲰⲎⲒⲦⲈⲤⲠⲀⲔⲈ ⲆⲈⲦⲈⲔⲦⲒⲞⲚ - GENERATED FROM ⲥⲓⲙⲇ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ.tri
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// PAS Pattern: D&C (Divide-and-Conquer)
// Expected speedup: 4-8x for whitespace skipping
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲔⲞⲚⲤⲦⲀⲚⲦⲤ
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// Whitespace characters
pub const SPACE: u8 = 0x20;
pub const TAB: u8 = 0x09;
pub const NEWLINE: u8 = 0x0A;
pub const CR: u8 = 0x0D;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD WHITESPACE DETECTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimdWhitespace = struct {
    
    /// Check if character is whitespace
    pub inline fn isWhitespace(c: u8) bool {
        return c == SPACE or c == TAB or c == NEWLINE or c == CR;
    }
    
    /// Process 8 bytes at a time using u64 operations
    pub fn skipWhitespace8(input: []const u8) usize {
        var pos: usize = 0;
        
        // Process 8 bytes at a time
        while (pos + 8 <= input.len) {
            const chunk: u64 = @as(*align(1) const u64, @ptrCast(input.ptr + pos)).*;
            
            // Check each byte for non-whitespace
            var mask: u64 = 0;
            inline for (0..8) |i| {
                const byte: u8 = @truncate(chunk >> @intCast(i * 8));
                if (!isWhitespace(byte)) {
                    mask |= @as(u64, 1) << @intCast(i * 8);
                }
            }
            
            if (mask != 0) {
                // Found non-whitespace
                return pos + @ctz(mask) / 8;
            }
            
            pos += 8;
        }
        
        // Scalar fallback for remainder
        return pos + skipWhitespaceScalar(input[pos..]);
    }
    
    /// Scalar fallback for small inputs or remainder
    pub fn skipWhitespaceScalar(input: []const u8) usize {
        var pos: usize = 0;
        while (pos < input.len) {
            if (!isWhitespace(input[pos])) {
                return pos;
            }
            pos += 1;
        }
        return pos;
    }
    
    /// Optimized version using lookup table
    pub fn skipWhitespaceLUT(input: []const u8) usize {
        // Lookup table: 1 = whitespace, 0 = not whitespace
        const lut = comptime blk: {
            var table: [256]u1 = [_]u1{0} ** 256;
            table[SPACE] = 1;
            table[TAB] = 1;
            table[NEWLINE] = 1;
            table[CR] = 1;
            break :blk table;
        };
        
        var pos: usize = 0;
        
        // Unroll 4x for better performance
        while (pos + 4 <= input.len) {
            if (lut[input[pos]] == 0) return pos;
            if (lut[input[pos + 1]] == 0) return pos + 1;
            if (lut[input[pos + 2]] == 0) return pos + 2;
            if (lut[input[pos + 3]] == 0) return pos + 3;
            pos += 4;
        }
        
        while (pos < input.len) {
            if (lut[input[pos]] == 0) return pos;
            pos += 1;
        }
        
        return pos;
    }
    
    /// Auto-select best implementation
    pub fn skipWhitespace(input: []const u8) usize {
        if (input.len >= 8) {
            return skipWhitespace8(input);
        } else {
            return skipWhitespaceScalar(input);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STRUCTURAL INDEXER (like simdjson)
// ═══════════════════════════════════════════════════════════════════════════════

pub const StructuralIndexer = struct {
    structural_mask: u64,
    whitespace_mask: u64,
    
    /// Check if character is structural
    pub inline fn isStructural(c: u8) bool {
        return c == '{' or c == '}' or c == '[' or c == ']' or c == ':' or c == ',';
    }
    
    /// Classify up to 64 bytes into structural and whitespace masks
    pub fn classify64Bytes(input: []const u8) StructuralIndexer {
        var structural: u64 = 0;
        var whitespace: u64 = 0;
        
        const len = @min(input.len, 64);
        
        for (0..len) |i| {
            const c = input[i];
            const bit: u64 = @as(u64, 1) << @intCast(i);
            
            if (isStructural(c)) {
                structural |= bit;
            }
            if (SimdWhitespace.isWhitespace(c)) {
                whitespace |= bit;
            }
        }
        
        return .{
            .structural_mask = structural,
            .whitespace_mask = whitespace,
        };
    }
    
    /// Get next structural character position
    pub fn nextStructural(self: *const StructuralIndexer, from: usize) ?usize {
        if (from >= 64) return null;
        const shifted = self.structural_mask >> @intCast(from);
        if (shifted == 0) return null;
        return from + @ctz(shifted);
    }
    
    /// Count structural characters
    pub fn countStructural(self: *const StructuralIndexer) usize {
        return @popCount(self.structural_mask);
    }
    
    /// Count whitespace characters
    pub fn countWhitespace(self: *const StructuralIndexer) usize {
        return @popCount(self.whitespace_mask);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ⲦⲈⲤⲦⲤ
// ═══════════════════════════════════════════════════════════════════════════════

test "ⲥⲕⲓⲡ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ_ⲥⲡⲁⲕⲉⲥ" {
    const input = "    hello";
    const result = SimdWhitespace.skipWhitespace(input);
    try std.testing.expectEqual(@as(usize, 4), result);
}

test "ⲥⲕⲓⲡ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ_ⲙⲓⲝⲉⲇ" {
    const input = " \t\n\rhello";
    const result = SimdWhitespace.skipWhitespace(input);
    try std.testing.expectEqual(@as(usize, 4), result);
}

test "ⲥⲕⲓⲡ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ_ⲛⲟⲛⲉ" {
    const input = "hello";
    const result = SimdWhitespace.skipWhitespace(input);
    try std.testing.expectEqual(@as(usize, 0), result);
}

test "ⲥⲕⲓⲡ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ_ⲁⲗⲗ" {
    const input = "                "; // 16 spaces
    const result = SimdWhitespace.skipWhitespace(input);
    try std.testing.expectEqual(@as(usize, 16), result);
}

test "ⲥⲕⲓⲡ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ_ⲗⲁⲣⲅⲉ" {
    // 100 spaces + 'x'
    var input: [101]u8 = undefined;
    @memset(&input, ' ');
    input[100] = 'x';
    
    const result = SimdWhitespace.skipWhitespace(&input);
    try std.testing.expectEqual(@as(usize, 100), result);
}

test "ⲥⲕⲓⲡ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ_ⲗⲩⲧ" {
    const input = "    hello";
    const result = SimdWhitespace.skipWhitespaceLUT(input);
    try std.testing.expectEqual(@as(usize, 4), result);
}

test "ⲕⲗⲁⲥⲥⲓⲫⲩ_ⲥⲧⲣⲩⲕⲧⲩⲣⲁⲗ" {
    const input = "{\"key\": 42}";
    // {  "  k  e  y  "  :     4  2  }
    // 0  1  2  3  4  5  6  7  8  9  10
    const indexer = StructuralIndexer.classify64Bytes(input);
    
    // Should have structural chars at positions 0 ({), 6 (:), 10 (})
    try std.testing.expect(indexer.structural_mask & 1 != 0); // { at 0
    try std.testing.expect(indexer.structural_mask & (1 << 6) != 0); // : at 6
    try std.testing.expect(indexer.structural_mask & (1 << 10) != 0); // } at 10
}

test "ⲕⲟⲩⲛⲧ_ⲥⲧⲣⲩⲕⲧⲩⲣⲁⲗ" {
    const input = "{\"a\":1,\"b\":2}";
    const indexer = StructuralIndexer.classify64Bytes(input);
    
    // { : , : } = 5 structural chars
    try std.testing.expectEqual(@as(usize, 5), indexer.countStructural());
}

test "ⲛⲉⲝⲧ_ⲥⲧⲣⲩⲕⲧⲩⲣⲁⲗ" {
    var input: [64]u8 = undefined;
    @memset(&input, 'a');
    input[5] = '{';
    input[10] = ':';
    input[15] = '}';
    
    const indexer = StructuralIndexer.classify64Bytes(&input);
    
    try std.testing.expectEqual(@as(?usize, 5), indexer.nextStructural(0));
    try std.testing.expectEqual(@as(?usize, 10), indexer.nextStructural(6));
    try std.testing.expectEqual(@as(?usize, 15), indexer.nextStructural(11));
    try std.testing.expectEqual(@as(?usize, null), indexer.nextStructural(16));
}

test "ⲓⲥ_ⲱⲏⲓⲧⲉⲥⲡⲁⲕⲉ" {
    try std.testing.expect(SimdWhitespace.isWhitespace(' '));
    try std.testing.expect(SimdWhitespace.isWhitespace('\t'));
    try std.testing.expect(SimdWhitespace.isWhitespace('\n'));
    try std.testing.expect(SimdWhitespace.isWhitespace('\r'));
    try std.testing.expect(!SimdWhitespace.isWhitespace('a'));
    try std.testing.expect(!SimdWhitespace.isWhitespace('0'));
}

test "ⲓⲥ_ⲥⲧⲣⲩⲕⲧⲩⲣⲁⲗ" {
    try std.testing.expect(StructuralIndexer.isStructural('{'));
    try std.testing.expect(StructuralIndexer.isStructural('}'));
    try std.testing.expect(StructuralIndexer.isStructural('['));
    try std.testing.expect(StructuralIndexer.isStructural(']'));
    try std.testing.expect(StructuralIndexer.isStructural(':'));
    try std.testing.expect(StructuralIndexer.isStructural(','));
    try std.testing.expect(!StructuralIndexer.isStructural('a'));
}
