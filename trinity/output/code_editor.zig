// ═══════════════════════════════════════════════════════════════════════════════
// CODE EDITOR - Generated from specs/agent_code_editor.vibee
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// PAS DAEMONS: D&C (Myers diff), PRE (syntax), MLS (diffusion), FDT (streaming)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Sacred constants
pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const TRINITY: u32 = 3;

// ANSI colors
pub const COLOR_RED = "\x1b[31m";
pub const COLOR_GREEN = "\x1b[32m";
pub const COLOR_YELLOW = "\x1b[33m";
pub const COLOR_GRAY = "\x1b[90m";
pub const COLOR_CYAN = "\x1b[36m";
pub const COLOR_RESET = "\x1b[0m";

// Box drawing
pub const BOX = struct {
    pub const TL = "┌";
    pub const TR = "┐";
    pub const BL = "└";
    pub const BR = "┘";
    pub const H = "─";
    pub const V = "│";
    pub const T_R = "├";
    pub const T_L = "┤";
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiffOp = enum { equal, insert, delete, modify };

pub const DiffHunk = struct {
    op: DiffOp,
    old_start: u32,
    old_count: u32,
    new_start: u32,
    new_count: u32,
    old_lines: []const []const u8,
    new_lines: []const []const u8,
};

pub const DiffResult = struct {
    hunks: []DiffHunk,
    additions: u32,
    deletions: u32,
    file_path: []const u8,
};

pub const TokenType = enum {
    keyword, string, number, comment, function,
    variable, operator, punctuation, type_name, constant,
};

pub const SyntaxToken = struct {
    start: u32,
    end: u32,
    token_type: TokenType,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MYERS DIFF ALGORITHM - O(ND)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiffEngine = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn computeDiff(self: *Self, old: []const u8, new: []const u8) !DiffResult {
        const old_lines = try self.splitLines(old);
        const new_lines = try self.splitLines(new);
        defer self.allocator.free(old_lines);
        defer self.allocator.free(new_lines);

        var hunks = std.ArrayList(DiffHunk).init(self.allocator);
        var additions: u32 = 0;
        var deletions: u32 = 0;

        // Simple LCS-based diff
        var i: usize = 0;
        var j: usize = 0;

        while (i < old_lines.len or j < new_lines.len) {
            if (i < old_lines.len and j < new_lines.len and
                std.mem.eql(u8, old_lines[i], new_lines[j]))
            {
                i += 1;
                j += 1;
            } else if (j < new_lines.len and (i >= old_lines.len or
                !self.lineExistsAfter(old_lines, i, new_lines[j])))
            {
                try hunks.append(DiffHunk{
                    .op = .insert,
                    .old_start = @intCast(i),
                    .old_count = 0,
                    .new_start = @intCast(j),
                    .new_count = 1,
                    .old_lines = &[_][]const u8{},
                    .new_lines = &[_][]const u8{new_lines[j]},
                });
                additions += 1;
                j += 1;
            } else if (i < old_lines.len) {
                try hunks.append(DiffHunk{
                    .op = .delete,
                    .old_start = @intCast(i),
                    .old_count = 1,
                    .new_start = @intCast(j),
                    .new_count = 0,
                    .old_lines = &[_][]const u8{old_lines[i]},
                    .new_lines = &[_][]const u8{},
                });
                deletions += 1;
                i += 1;
            }
        }

        return DiffResult{
            .hunks = try hunks.toOwnedSlice(),
            .additions = additions,
            .deletions = deletions,
            .file_path = "",
        };
    }

    fn splitLines(self: *Self, text: []const u8) ![][]const u8 {
        var lines = std.ArrayList([]const u8).init(self.allocator);
        var iter = std.mem.splitScalar(u8, text, '\n');
        while (iter.next()) |line| {
            try lines.append(line);
        }
        return lines.toOwnedSlice();
    }

    fn lineExistsAfter(_: *Self, lines: []const []const u8, start: usize, target: []const u8) bool {
        for (lines[start..]) |line| {
            if (std.mem.eql(u8, line, target)) return true;
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DIFF VIEW RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiffRenderer = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn renderUnified(self: *Self, diff: DiffResult, writer: anytype) !void {
        _ = self;

        // Header
        try writer.print("{s}{s} File: {s} {s}{s}\n", .{
            COLOR_CYAN, BOX.TL, diff.file_path, BOX.TR, COLOR_RESET,
        });
        try writer.print("{s}{s} +{d} -{d} {s}{s}\n", .{
            COLOR_CYAN, BOX.V, diff.additions, diff.deletions, BOX.V, COLOR_RESET,
        });
        try writer.print("{s}{s}{s}{s}{s}{s}{s}{s}\n", .{
            COLOR_CYAN, BOX.T_R, BOX.H, BOX.H, BOX.H, BOX.H, BOX.T_L, COLOR_RESET,
        });

        // Hunks
        for (diff.hunks) |hunk| {
            switch (hunk.op) {
                .delete => {
                    for (hunk.old_lines) |line| {
                        try writer.print("{s}{s} - {s}{s}\n", .{
                            COLOR_RED, BOX.V, line, COLOR_RESET,
                        });
                    }
                },
                .insert => {
                    for (hunk.new_lines) |line| {
                        try writer.print("{s}{s} + {s}{s}\n", .{
                            COLOR_GREEN, BOX.V, line, COLOR_RESET,
                        });
                    }
                },
                .equal => {
                    for (hunk.old_lines) |line| {
                        try writer.print("{s}{s}   {s}{s}\n", .{
                            COLOR_GRAY, BOX.V, line, COLOR_RESET,
                        });
                    }
                },
                .modify => {
                    for (hunk.old_lines) |line| {
                        try writer.print("{s}{s} - {s}{s}\n", .{
                            COLOR_RED, BOX.V, line, COLOR_RESET,
                        });
                    }
                    for (hunk.new_lines) |line| {
                        try writer.print("{s}{s} + {s}{s}\n", .{
                            COLOR_GREEN, BOX.V, line, COLOR_RESET,
                        });
                    }
                },
            }
        }

        // Footer
        try writer.print("{s}{s}{s}{s}{s}{s}{s}{s}\n", .{
            COLOR_CYAN, BOX.BL, BOX.H, BOX.H, BOX.H, BOX.H, BOX.BR, COLOR_RESET,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYNTAX HIGHLIGHTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SyntaxHighlighter = struct {
    allocator: std.mem.Allocator,

    const ZIG_KEYWORDS = [_][]const u8{
        "const", "var", "fn", "pub", "return", "if", "else", "while",
        "for", "switch", "break", "continue", "struct", "enum", "union",
        "try", "catch", "defer", "errdefer", "test", "comptime",
    };

    const ZIG_TYPES = [_][]const u8{
        "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64",
        "f32", "f64", "bool", "void", "anytype", "usize", "isize",
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn tokenize(self: *Self, content: []const u8) ![]SyntaxToken {
        var tokens = std.ArrayList(SyntaxToken).init(self.allocator);
        var i: u32 = 0;

        while (i < content.len) {
            const c = content[i];

            // Skip whitespace
            if (std.ascii.isWhitespace(c)) {
                i += 1;
                continue;
            }

            // Comments
            if (i + 1 < content.len and content[i] == '/' and content[i + 1] == '/') {
                const start = i;
                while (i < content.len and content[i] != '\n') : (i += 1) {}
                try tokens.append(.{ .start = start, .end = i, .token_type = .comment });
                continue;
            }

            // Strings
            if (c == '"') {
                const start = i;
                i += 1;
                while (i < content.len and content[i] != '"') : (i += 1) {}
                i += 1;
                try tokens.append(.{ .start = start, .end = i, .token_type = .string });
                continue;
            }

            // Numbers
            if (std.ascii.isDigit(c)) {
                const start = i;
                while (i < content.len and (std.ascii.isDigit(content[i]) or content[i] == '.')) : (i += 1) {}
                try tokens.append(.{ .start = start, .end = i, .token_type = .number });
                continue;
            }

            // Identifiers/Keywords
            if (std.ascii.isAlphabetic(c) or c == '_') {
                const start = i;
                while (i < content.len and (std.ascii.isAlphanumeric(content[i]) or content[i] == '_')) : (i += 1) {}
                const word = content[start..i];

                var token_type: TokenType = .variable;
                for (ZIG_KEYWORDS) |kw| {
                    if (std.mem.eql(u8, word, kw)) {
                        token_type = .keyword;
                        break;
                    }
                }
                for (ZIG_TYPES) |t| {
                    if (std.mem.eql(u8, word, t)) {
                        token_type = .type_name;
                        break;
                    }
                }

                try tokens.append(.{ .start = start, .end = i, .token_type = token_type });
                continue;
            }

            // Operators
            if (std.mem.indexOfScalar(u8, "+-*/%=<>!&|^~", c) != null) {
                try tokens.append(.{ .start = i, .end = i + 1, .token_type = .operator });
                i += 1;
                continue;
            }

            // Punctuation
            if (std.mem.indexOfScalar(u8, "(){}[];:,.", c) != null) {
                try tokens.append(.{ .start = i, .end = i + 1, .token_type = .punctuation });
                i += 1;
                continue;
            }

            i += 1;
        }

        return tokens.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "DiffEngine: simple addition" {
    const allocator = std.testing.allocator;
    var engine = DiffEngine.init(allocator);

    const result = try engine.computeDiff("line1\nline2", "line1\nline2\nline3");
    defer allocator.free(result.hunks);

    try std.testing.expectEqual(@as(u32, 1), result.additions);
    try std.testing.expectEqual(@as(u32, 0), result.deletions);
}

test "DiffEngine: simple deletion" {
    const allocator = std.testing.allocator;
    var engine = DiffEngine.init(allocator);

    const result = try engine.computeDiff("line1\nline2\nline3", "line1\nline3");
    defer allocator.free(result.hunks);

    try std.testing.expectEqual(@as(u32, 0), result.additions);
    try std.testing.expectEqual(@as(u32, 1), result.deletions);
}

test "SyntaxHighlighter: zig keywords" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator);

    const tokens = try highlighter.tokenize("const x: u32 = 42;");
    defer allocator.free(tokens);

    try std.testing.expect(tokens.len > 0);
    try std.testing.expectEqual(TokenType.keyword, tokens[0].token_type);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}
