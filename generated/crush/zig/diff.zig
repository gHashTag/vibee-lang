// diff.zig - Unified Diff Generation Module
// Generated from: specs/crush/diff.vibee via generated/crush/tri/diff.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

/// Result of diff generation
pub const DiffResult = struct {
    unified: []const u8,
    additions: usize,
    removals: usize,
};

/// Line change type
pub const ChangeType = enum {
    context,
    addition,
    removal,
};

/// A single line in the diff
pub const DiffLine = struct {
    change_type: ChangeType,
    content: []const u8,
    old_line: ?usize,
    new_line: ?usize,
};

/// Generate unified diff from two file contents
/// Creation Pattern: FileContents → UnifiedDiffGenerator → DiffOutput
pub fn generateDiff(
    allocator: std.mem.Allocator,
    before_content: []const u8,
    after_content: []const u8,
    filename: []const u8,
) !DiffResult {
    // Normalize filename (trim leading slash)
    const normalized_name = if (filename.len > 0 and filename[0] == '/')
        filename[1..]
    else
        filename;

    // Split into lines
    var before_lines = std.ArrayList([]const u8).init(allocator);
    defer before_lines.deinit();
    var after_lines = std.ArrayList([]const u8).init(allocator);
    defer after_lines.deinit();

    try splitLines(before_content, &before_lines);
    try splitLines(after_content, &after_lines);

    // Simple diff algorithm (line by line comparison)
    var diff_output = std.ArrayList(u8).init(allocator);
    defer diff_output.deinit();

    var additions: usize = 0;
    var removals: usize = 0;

    // Check if files are identical
    if (std.mem.eql(u8, before_content, after_content)) {
        return DiffResult{
            .unified = "",
            .additions = 0,
            .removals = 0,
        };
    }

    // Write header
    try diff_output.appendSlice("--- a/");
    try diff_output.appendSlice(normalized_name);
    try diff_output.append('\n');
    try diff_output.appendSlice("+++ b/");
    try diff_output.appendSlice(normalized_name);
    try diff_output.append('\n');

    // Simple hunk header
    try diff_output.appendSlice("@@ -1,");
    try appendNumber(&diff_output, before_lines.items.len);
    try diff_output.appendSlice(" +1,");
    try appendNumber(&diff_output, after_lines.items.len);
    try diff_output.appendSlice(" @@\n");

    // Generate diff lines using LCS
    const lcs = try computeLCS(allocator, before_lines.items, after_lines.items);
    defer allocator.free(lcs);

    var before_idx: usize = 0;
    var after_idx: usize = 0;
    var lcs_idx: usize = 0;

    while (before_idx < before_lines.items.len or after_idx < after_lines.items.len) {
        if (lcs_idx < lcs.len and
            before_idx < before_lines.items.len and
            after_idx < after_lines.items.len and
            std.mem.eql(u8, before_lines.items[before_idx], lcs[lcs_idx]) and
            std.mem.eql(u8, after_lines.items[after_idx], lcs[lcs_idx]))
        {
            // Context line
            try diff_output.append(' ');
            try diff_output.appendSlice(before_lines.items[before_idx]);
            try diff_output.append('\n');
            before_idx += 1;
            after_idx += 1;
            lcs_idx += 1;
        } else if (before_idx < before_lines.items.len and
            (lcs_idx >= lcs.len or !std.mem.eql(u8, before_lines.items[before_idx], lcs[lcs_idx])))
        {
            // Removal
            try diff_output.append('-');
            try diff_output.appendSlice(before_lines.items[before_idx]);
            try diff_output.append('\n');
            before_idx += 1;
            removals += 1;
        } else if (after_idx < after_lines.items.len) {
            // Addition
            try diff_output.append('+');
            try diff_output.appendSlice(after_lines.items[after_idx]);
            try diff_output.append('\n');
            after_idx += 1;
            additions += 1;
        }
    }

    const result = try allocator.dupe(u8, diff_output.items);

    return DiffResult{
        .unified = result,
        .additions = additions,
        .removals = removals,
    };
}

/// Split content into lines
fn splitLines(content: []const u8, lines: *std.ArrayList([]const u8)) !void {
    var start: usize = 0;
    for (content, 0..) |c, i| {
        if (c == '\n') {
            try lines.append(content[start..i]);
            start = i + 1;
        }
    }
    if (start < content.len) {
        try lines.append(content[start..]);
    }
}

/// Compute Longest Common Subsequence
fn computeLCS(
    allocator: std.mem.Allocator,
    before: []const []const u8,
    after: []const []const u8,
) ![][]const u8 {
    if (before.len == 0 or after.len == 0) {
        return try allocator.alloc([]const u8, 0);
    }

    // Build LCS table
    const m = before.len;
    const n = after.len;

    var dp = try allocator.alloc([]usize, m + 1);
    defer {
        for (dp) |row| allocator.free(row);
        allocator.free(dp);
    }

    for (dp) |*row| {
        row.* = try allocator.alloc(usize, n + 1);
        @memset(row.*, 0);
    }

    for (1..m + 1) |i| {
        for (1..n + 1) |j| {
            if (std.mem.eql(u8, before[i - 1], after[j - 1])) {
                dp[i][j] = dp[i - 1][j - 1] + 1;
            } else {
                dp[i][j] = @max(dp[i - 1][j], dp[i][j - 1]);
            }
        }
    }

    // Backtrack to find LCS
    var lcs = std.ArrayList([]const u8).init(allocator);
    var i = m;
    var j = n;

    while (i > 0 and j > 0) {
        if (std.mem.eql(u8, before[i - 1], after[j - 1])) {
            try lcs.insert(0, before[i - 1]);
            i -= 1;
            j -= 1;
        } else if (dp[i - 1][j] > dp[i][j - 1]) {
            i -= 1;
        } else {
            j -= 1;
        }
    }

    return lcs.toOwnedSlice();
}

/// Append number to buffer
fn appendNumber(buf: *std.ArrayList(u8), n: usize) !void {
    var temp: [20]u8 = undefined;
    const slice = std.fmt.bufPrint(&temp, "{d}", .{n}) catch unreachable;
    try buf.appendSlice(slice);
}

/// Count additions in a diff string
pub fn countAdditions(diff: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < diff.len) {
        if (diff[i] == '\n' or i == 0) {
            const start = if (diff[i] == '\n') i + 1 else i;
            if (start < diff.len and diff[start] == '+') {
                if (start + 3 >= diff.len or !std.mem.eql(u8, diff[start .. start + 3], "+++")) {
                    count += 1;
                }
            }
        }
        i += 1;
    }
    return count;
}

/// Count removals in a diff string
pub fn countRemovals(diff: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < diff.len) {
        if (diff[i] == '\n' or i == 0) {
            const start = if (diff[i] == '\n') i + 1 else i;
            if (start < diff.len and diff[start] == '-') {
                if (start + 3 >= diff.len or !std.mem.eql(u8, diff[start .. start + 3], "---")) {
                    count += 1;
                }
            }
        }
        i += 1;
    }
    return count;
}

// Tests
test "generateDiff_simple_addition" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "line1\nline2", "line1\nline2\nline3", "test.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expectEqual(@as(usize, 1), result.additions);
    try std.testing.expectEqual(@as(usize, 0), result.removals);
}

test "generateDiff_simple_removal" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "line1\nline2\nline3", "line1\nline2", "test.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expectEqual(@as(usize, 0), result.additions);
    try std.testing.expectEqual(@as(usize, 1), result.removals);
}

test "generateDiff_modification" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "hello", "world", "test.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expectEqual(@as(usize, 1), result.additions);
    try std.testing.expectEqual(@as(usize, 1), result.removals);
}

test "generateDiff_no_change" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "same content", "same content", "test.txt");

    try std.testing.expectEqual(@as(usize, 0), result.additions);
    try std.testing.expectEqual(@as(usize, 0), result.removals);
    try std.testing.expectEqualStrings("", result.unified);
}

test "generateDiff_empty_before" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "", "new content", "test.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expectEqual(@as(usize, 1), result.additions);
    try std.testing.expectEqual(@as(usize, 0), result.removals);
}

test "generateDiff_empty_after" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "old content", "", "test.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expectEqual(@as(usize, 0), result.additions);
    try std.testing.expectEqual(@as(usize, 1), result.removals);
}

test "generateDiff_filename_normalization" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "old", "new", "/path/to/file.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expect(std.mem.indexOf(u8, result.unified, "a/path/to/file.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.unified, "b/path/to/file.txt") != null);
}

test "generateDiff_header_format" {
    const allocator = std.testing.allocator;
    const result = try generateDiff(allocator, "old", "new", "file.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expect(std.mem.startsWith(u8, result.unified, "--- a/file.txt"));
    try std.testing.expect(std.mem.indexOf(u8, result.unified, "+++ b/file.txt") != null);
}

test "generateDiff_multiple_lines" {
    const allocator = std.testing.allocator;
    const before = "line1\nline2\nline3\nline4";
    const after = "line1\nmodified\nline3\nline4\nline5";
    const result = try generateDiff(allocator, before, after, "test.txt");
    defer if (result.unified.len > 0) allocator.free(result.unified);

    try std.testing.expect(result.additions >= 1);
    try std.testing.expect(result.removals >= 1);
}

test "countAdditions" {
    const diff = "--- a/file\n+++ b/file\n@@ -1 +1 @@\n-old\n+new\n+another";
    try std.testing.expectEqual(@as(usize, 2), countAdditions(diff));
}

test "countRemovals" {
    const diff = "--- a/file\n+++ b/file\n@@ -1 +1 @@\n-old\n-another\n+new";
    try std.testing.expectEqual(@as(usize, 2), countRemovals(diff));
}
