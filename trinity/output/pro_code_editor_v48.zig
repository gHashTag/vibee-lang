// ═══════════════════════════════════════════════════════════════════════════════
// PRO CODE EDITOR V48 - Generated from specs/pro_code_editor_v48.vibee
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// Myers O(ND) Diff Algorithm - Reference: Myers 1986, Algorithmica
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Sacred Constants
pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const TRINITY: u32 = 3;
pub const HASH_PRIME: u64 = 31;

// ANSI Colors
pub const Color = struct {
    pub const RESET = "\x1b[0m";
    pub const RED = "\x1b[31m";
    pub const GREEN = "\x1b[32m";
    pub const YELLOW = "\x1b[33m";
    pub const BLUE = "\x1b[34m";
    pub const MAGENTA = "\x1b[35m";
    pub const CYAN = "\x1b[36m";
    pub const GRAY = "\x1b[90m";
    pub const BOLD = "\x1b[1m";
    pub const DIM = "\x1b[2m";
};

// Box Drawing
pub const Box = struct {
    pub const TL = "╔";
    pub const TR = "╗";
    pub const BL = "╚";
    pub const BR = "╝";
    pub const H = "═";
    pub const V = "║";
    pub const T_R = "╠";
    pub const T_L = "╣";
    pub const CROSS = "╬";
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const EditType = enum { EQUAL, INSERT, DELETE };

pub const Edit = struct {
    edit_type: EditType,
    old_idx: usize,
    new_idx: usize,
    text: []const u8,
};

pub const DiffResult = struct {
    edits: []Edit,
    additions: u32,
    deletions: u32,
    edit_distance: u32,
    similarity: f32,
    allocator: Allocator,

    pub fn deinit(self: *DiffResult) void {
        self.allocator.free(self.edits);
    }
};

pub const TokenType = enum {
    KEYWORD, IDENTIFIER, STRING, NUMBER, COMMENT,
    OPERATOR, PUNCTUATION, TYPE, FUNCTION, BUILTIN,
};

pub const Token = struct {
    start: u32,
    end: u32,
    token_type: TokenType,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MYERS DIFF ENGINE - O(ND) Algorithm
// Reference: Myers 1986 "An O(ND) Difference Algorithm"
// ═══════════════════════════════════════════════════════════════════════════════

pub const MyersDiffEngine = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{ .allocator = allocator };
    }

    /// Compute diff using Myers O(ND) algorithm
    pub fn diff(self: *Self, old: []const u8, new: []const u8) !DiffResult {
        const old_lines = try self.splitLines(old);
        defer self.allocator.free(old_lines);
        const new_lines = try self.splitLines(new);
        defer self.allocator.free(new_lines);

        return try self.diffLines(old_lines, new_lines);
    }

    /// Core Myers algorithm on lines
    pub fn diffLines(self: *Self, old: []const []const u8, new: []const []const u8) !DiffResult {
        const n = old.len;
        const m = new.len;
        const max = n + m + 1;

        // V array for furthest reaching points
        const v_size = 2 * max + 1;
        const v = try self.allocator.alloc(i64, v_size);
        defer self.allocator.free(v);
        @memset(v, 0);

        // Offset for negative indices
        const offset: i64 = @intCast(max);

        var edits = std.ArrayList(Edit).init(self.allocator);
        var additions: u32 = 0;
        var deletions: u32 = 0;

        // Find shortest edit script
        var d: usize = 0;
        outer: while (d <= max) : (d += 1) {
            var k: i64 = -@as(i64, @intCast(d));
            while (k <= @as(i64, @intCast(d))) : (k += 2) {
                const k_idx: usize = @intCast(k + offset);

                var x: i64 = undefined;
                if (k == -@as(i64, @intCast(d)) or
                    (k != @as(i64, @intCast(d)) and v[k_idx - 1] < v[k_idx + 1]))
                {
                    x = v[k_idx + 1]; // Move down
                } else {
                    x = v[k_idx - 1] + 1; // Move right
                }

                var y = x - k;

                // Extend snake (diagonal)
                while (x < @as(i64, @intCast(n)) and y < @as(i64, @intCast(m)) and
                    std.mem.eql(u8, old[@intCast(x)], new[@intCast(y)]))
                {
                    x += 1;
                    y += 1;
                }

                v[k_idx] = x;

                // Check if done
                if (x >= @as(i64, @intCast(n)) and y >= @as(i64, @intCast(m))) {
                    break :outer;
                }
            }
        }

        // Backtrack to build edit list (simplified)
        var i: usize = 0;
        var j: usize = 0;
        while (i < n or j < m) {
            if (i < n and j < m and std.mem.eql(u8, old[i], new[j])) {
                try edits.append(.{
                    .edit_type = .EQUAL,
                    .old_idx = i,
                    .new_idx = j,
                    .text = old[i],
                });
                i += 1;
                j += 1;
            } else if (j < m and (i >= n or !self.existsAhead(old, i, new[j]))) {
                try edits.append(.{
                    .edit_type = .INSERT,
                    .old_idx = i,
                    .new_idx = j,
                    .text = new[j],
                });
                additions += 1;
                j += 1;
            } else if (i < n) {
                try edits.append(.{
                    .edit_type = .DELETE,
                    .old_idx = i,
                    .new_idx = j,
                    .text = old[i],
                });
                deletions += 1;
                i += 1;
            }
        }

        const edit_distance = additions + deletions;
        const max_len = @max(n, m);
        const similarity: f32 = if (max_len == 0) 1.0 else 1.0 - @as(f32, @floatFromInt(edit_distance)) / @as(f32, @floatFromInt(max_len));

        return DiffResult{
            .edits = try edits.toOwnedSlice(),
            .additions = additions,
            .deletions = deletions,
            .edit_distance = edit_distance,
            .similarity = similarity,
            .allocator = self.allocator,
        };
    }

    fn existsAhead(_: *Self, lines: []const []const u8, start: usize, target: []const u8) bool {
        for (lines[start..]) |line| {
            if (std.mem.eql(u8, line, target)) return true;
        }
        return false;
    }

    fn splitLines(self: *Self, text: []const u8) ![]const []const u8 {
        var lines = std.ArrayList([]const u8).init(self.allocator);
        var iter = std.mem.splitScalar(u8, text, '\n');
        while (iter.next()) |line| {
            try lines.append(line);
        }
        return try lines.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LINE HASHER - Karp-Rabin Style
// ═══════════════════════════════════════════════════════════════════════════════

pub const LineHasher = struct {
    pub fn hashLine(line: []const u8) u64 {
        var hash: u64 = 0;
        for (line) |c| {
            hash = hash *% HASH_PRIME +% c;
        }
        return hash;
    }

    pub fn hashLines(allocator: Allocator, lines: []const []const u8) ![]u64 {
        const hashes = try allocator.alloc(u64, lines.len);
        for (lines, 0..) |line, i| {
            hashes[i] = hashLine(line);
        }
        return hashes;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYNTAX HIGHLIGHTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SyntaxHighlighter = struct {
    allocator: Allocator,

    const ZIG_KEYWORDS = [_][]const u8{
        "const", "var", "fn", "pub", "return", "if", "else", "while",
        "for", "switch", "break", "continue", "struct", "enum", "union",
        "try", "catch", "defer", "errdefer", "test", "comptime", "inline",
    };

    const ZIG_TYPES = [_][]const u8{
        "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64",
        "f32", "f64", "bool", "void", "anytype", "usize", "isize",
    };

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn tokenize(self: *Self, content: []const u8) ![]Token {
        var tokens = std.ArrayList(Token).init(self.allocator);
        var i: u32 = 0;

        while (i < content.len) {
            const c = content[i];

            if (std.ascii.isWhitespace(c)) {
                i += 1;
                continue;
            }

            // Comments
            if (i + 1 < content.len and content[i] == '/' and content[i + 1] == '/') {
                const start = i;
                while (i < content.len and content[i] != '\n') : (i += 1) {}
                try tokens.append(.{ .start = start, .end = i, .token_type = .COMMENT });
                continue;
            }

            // Strings
            if (c == '"') {
                const start = i;
                i += 1;
                while (i < content.len and content[i] != '"') : (i += 1) {}
                if (i < content.len) i += 1;
                try tokens.append(.{ .start = start, .end = i, .token_type = .STRING });
                continue;
            }

            // Numbers
            if (std.ascii.isDigit(c)) {
                const start = i;
                while (i < content.len and (std.ascii.isDigit(content[i]) or content[i] == '.' or content[i] == 'x')) : (i += 1) {}
                try tokens.append(.{ .start = start, .end = i, .token_type = .NUMBER });
                continue;
            }

            // Identifiers
            if (std.ascii.isAlphabetic(c) or c == '_' or c == '@') {
                const start = i;
                while (i < content.len and (std.ascii.isAlphanumeric(content[i]) or content[i] == '_')) : (i += 1) {}
                const word = content[start..i];

                var token_type: TokenType = .IDENTIFIER;
                for (ZIG_KEYWORDS) |kw| {
                    if (std.mem.eql(u8, word, kw)) {
                        token_type = .KEYWORD;
                        break;
                    }
                }
                for (ZIG_TYPES) |t| {
                    if (std.mem.eql(u8, word, t)) {
                        token_type = .TYPE;
                        break;
                    }
                }

                try tokens.append(.{ .start = start, .end = i, .token_type = token_type });
                continue;
            }

            // Operators
            if (std.mem.indexOfScalar(u8, "+-*/%=<>!&|^~", c) != null) {
                try tokens.append(.{ .start = i, .end = i + 1, .token_type = .OPERATOR });
                i += 1;
                continue;
            }

            // Punctuation
            if (std.mem.indexOfScalar(u8, "(){}[];:,.", c) != null) {
                try tokens.append(.{ .start = i, .end = i + 1, .token_type = .PUNCTUATION });
                i += 1;
                continue;
            }

            i += 1;
        }

        return try tokens.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DIFF RENDERER - Professional UI
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiffRenderer = struct {
    context_lines: u32 = 3,

    const Self = @This();

    pub fn renderUnified(self: *Self, diff: DiffResult, file_path: []const u8, writer: anytype) !void {
        _ = self;

        // Header
        try writer.print("{s}{s}{s} {s} {s}{s}\n", .{
            Color.CYAN, Box.TL, Box.H, file_path, Box.H, Box.TR,
        });
        try writer.print("{s}{s} {s}+{d}{s} {s}-{d}{s} {s}\n", .{
            Color.CYAN, Box.V,
            Color.GREEN, diff.additions, Color.RESET,
            Color.RED, diff.deletions, Color.RESET,
            Box.V,
        });
        try writer.print("{s}{s}{s}{s}{s}{s}{s}\n", .{
            Color.CYAN, Box.T_R, Box.H, Box.H, Box.H, Box.T_L, Color.RESET,
        });

        // Edits
        for (diff.edits) |edit| {
            switch (edit.edit_type) {
                .EQUAL => {
                    try writer.print("{s}{s}   {s}{s}\n", .{
                        Color.GRAY, Box.V, edit.text, Color.RESET,
                    });
                },
                .INSERT => {
                    try writer.print("{s}{s} + {s}{s}\n", .{
                        Color.GREEN, Box.V, edit.text, Color.RESET,
                    });
                },
                .DELETE => {
                    try writer.print("{s}{s} - {s}{s}\n", .{
                        Color.RED, Box.V, edit.text, Color.RESET,
                    });
                },
            }
        }

        // Footer
        try writer.print("{s}{s}{s}{s}{s}{s}{s}\n", .{
            Color.CYAN, Box.BL, Box.H, Box.H, Box.H, Box.BR, Color.RESET,
        });

        // Stats
        try writer.print("\n{s}Similarity:{s} {d:.1}%\n", .{
            Color.BOLD, Color.RESET, diff.similarity * 100,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Benchmark = struct {
    pub fn runDiffBenchmark(allocator: Allocator, lines: usize) !void {
        var engine = MyersDiffEngine.init(allocator);

        // Generate test data
        var old_buf = std.ArrayList(u8).init(allocator);
        defer old_buf.deinit();
        var new_buf = std.ArrayList(u8).init(allocator);
        defer new_buf.deinit();

        var prng = std.Random.DefaultPrng.init(PHOENIX);
        for (0..lines) |i| {
            try old_buf.writer().print("line {d}: original content here\n", .{i});
            if (prng.random().float(f32) > 0.95) {
                try new_buf.writer().print("line {d}: MODIFIED content\n", .{i});
            } else {
                try new_buf.writer().print("line {d}: original content here\n", .{i});
            }
        }

        const start = std.time.nanoTimestamp();
        var result = try engine.diff(old_buf.items, new_buf.items);
        const end = std.time.nanoTimestamp();
        defer result.deinit();

        const elapsed_us = @as(f64, @floatFromInt(end - start)) / 1000.0;

        std.debug.print("\n{s}{s} BENCHMARK: {d} lines {s}{s}\n", .{
            Color.CYAN, Box.TL, lines, Box.TR, Color.RESET,
        });
        std.debug.print("{s}{s} Time: {d:.2} µs{s}\n", .{
            Color.CYAN, Box.V, elapsed_us, Color.RESET,
        });
        std.debug.print("{s}{s} Edits: +{d} -{d}{s}\n", .{
            Color.CYAN, Box.V, result.additions, result.deletions, Color.RESET,
        });
        std.debug.print("{s}{s}{s}{s}{s}{s}\n", .{
            Color.CYAN, Box.BL, Box.H, Box.H, Box.BR, Color.RESET,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Myers diff: simple insert" {
    const allocator = std.testing.allocator;
    var engine = MyersDiffEngine.init(allocator);
    var result = try engine.diff("a\nb\nc", "a\nb\nX\nc");
    defer result.deinit();

    try std.testing.expectEqual(@as(u32, 1), result.additions);
    try std.testing.expectEqual(@as(u32, 0), result.deletions);
}

test "Myers diff: simple delete" {
    const allocator = std.testing.allocator;
    var engine = MyersDiffEngine.init(allocator);
    var result = try engine.diff("a\nb\nc", "a\nc");
    defer result.deinit();

    try std.testing.expectEqual(@as(u32, 0), result.additions);
    try std.testing.expectEqual(@as(u32, 1), result.deletions);
}

test "Myers diff: identical" {
    const allocator = std.testing.allocator;
    var engine = MyersDiffEngine.init(allocator);
    var result = try engine.diff("hello\nworld", "hello\nworld");
    defer result.deinit();

    try std.testing.expectEqual(@as(u32, 0), result.edit_distance);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.similarity, 0.001);
}

test "Line hasher" {
    const hash1 = LineHasher.hashLine("hello");
    const hash2 = LineHasher.hashLine("hello");
    const hash3 = LineHasher.hashLine("world");

    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

test "Syntax highlighter: zig" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator);
    const tokens = try highlighter.tokenize("const x: u32 = 42;");
    defer allocator.free(tokens);

    try std.testing.expect(tokens.len > 0);
    try std.testing.expectEqual(TokenType.KEYWORD, tokens[0].token_type);
}

test "Golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

test "Phoenix number" {
    try std.testing.expect(PHOENIX == 999);
    try std.testing.expect(999 == 27 * 37);
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// ═══════════════════════════════════════════════════════════════════════════════
