// uiutil.zig - UI Utilities Module
// Generated from: crush/internal/uiutil
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Truncate string to max width with ellipsis
pub fn truncate(allocator: std.mem.Allocator, s: []const u8, max_width: usize) ![]u8 {
    if (s.len <= max_width) {
        return try allocator.dupe(u8, s);
    }

    if (max_width <= 3) {
        return try allocator.dupe(u8, s[0..max_width]);
    }

    var result = try allocator.alloc(u8, max_width);
    @memcpy(result[0 .. max_width - 3], s[0 .. max_width - 3]);
    @memcpy(result[max_width - 3 ..], "...");
    return result;
}

/// Pad string to width (left aligned)
pub fn padRight(allocator: std.mem.Allocator, s: []const u8, width: usize) ![]u8 {
    if (s.len >= width) {
        return try allocator.dupe(u8, s);
    }

    var result = try allocator.alloc(u8, width);
    @memcpy(result[0..s.len], s);
    @memset(result[s.len..], ' ');
    return result;
}

/// Pad string to width (right aligned)
pub fn padLeft(allocator: std.mem.Allocator, s: []const u8, width: usize) ![]u8 {
    if (s.len >= width) {
        return try allocator.dupe(u8, s);
    }

    var result = try allocator.alloc(u8, width);
    const padding = width - s.len;
    @memset(result[0..padding], ' ');
    @memcpy(result[padding..], s);
    return result;
}

/// Center string in width
pub fn center(allocator: std.mem.Allocator, s: []const u8, width: usize) ![]u8 {
    if (s.len >= width) {
        return try allocator.dupe(u8, s);
    }

    var result = try allocator.alloc(u8, width);
    const left_pad = (width - s.len) / 2;
    const right_pad = width - s.len - left_pad;

    @memset(result[0..left_pad], ' ');
    @memcpy(result[left_pad .. left_pad + s.len], s);
    @memset(result[left_pad + s.len ..], ' ');
    _ = right_pad;

    return result;
}

/// Wrap text to width
pub fn wrap(allocator: std.mem.Allocator, text: []const u8, width: usize) ![][]const u8 {
    if (text.len == 0 or width == 0) {
        return try allocator.alloc([]const u8, 0);
    }

    var lines = std.ArrayList([]const u8).init(allocator);
    var current_line = std.ArrayList(u8).init(allocator);
    var word_start: usize = 0;

    for (text, 0..) |c, i| {
        if (c == ' ' or c == '\n' or i == text.len - 1) {
            const word_end = if (i == text.len - 1 and c != ' ' and c != '\n') i + 1 else i;
            const word = text[word_start..word_end];

            if (current_line.items.len + word.len + 1 > width and current_line.items.len > 0) {
                try lines.append(try current_line.toOwnedSlice());
                current_line = std.ArrayList(u8).init(allocator);
            }

            if (current_line.items.len > 0) {
                try current_line.append(' ');
            }
            try current_line.appendSlice(word);

            if (c == '\n') {
                try lines.append(try current_line.toOwnedSlice());
                current_line = std.ArrayList(u8).init(allocator);
            }

            word_start = i + 1;
        }
    }

    if (current_line.items.len > 0) {
        try lines.append(try current_line.toOwnedSlice());
    } else {
        current_line.deinit();
    }

    return lines.toOwnedSlice();
}

/// Format duration in human readable form
pub fn formatDuration(allocator: std.mem.Allocator, ms: i64) ![]u8 {
    if (ms < 1000) {
        return try std.fmt.allocPrint(allocator, "{d}ms", .{ms});
    } else if (ms < 60000) {
        const secs = @as(f64, @floatFromInt(ms)) / 1000.0;
        return try std.fmt.allocPrint(allocator, "{d:.1}s", .{secs});
    } else if (ms < 3600000) {
        const mins = @divFloor(ms, 60000);
        const secs = @mod(@divFloor(ms, 1000), 60);
        return try std.fmt.allocPrint(allocator, "{d}m {d}s", .{ mins, secs });
    } else {
        const hours = @divFloor(ms, 3600000);
        const mins = @mod(@divFloor(ms, 60000), 60);
        return try std.fmt.allocPrint(allocator, "{d}h {d}m", .{ hours, mins });
    }
}

/// Format bytes in human readable form
pub fn formatBytes(allocator: std.mem.Allocator, bytes: u64) ![]u8 {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var size: f64 = @floatFromInt(bytes);
    var unit_idx: usize = 0;

    while (size >= 1024 and unit_idx < units.len - 1) {
        size /= 1024;
        unit_idx += 1;
    }

    if (unit_idx == 0) {
        return try std.fmt.allocPrint(allocator, "{d} {s}", .{ bytes, units[0] });
    }
    return try std.fmt.allocPrint(allocator, "{d:.1} {s}", .{ size, units[unit_idx] });
}

/// Strip ANSI escape codes
pub fn stripAnsi(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    var in_escape = false;

    for (s) |c| {
        if (c == 0x1b) {
            in_escape = true;
        } else if (in_escape) {
            if (c == 'm') {
                in_escape = false;
            }
        } else {
            try result.append(c);
        }
    }

    return result.toOwnedSlice();
}

// Tests
test "truncate_short" {
    const allocator = std.testing.allocator;
    const result = try truncate(allocator, "hello", 10);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "truncate_long" {
    const allocator = std.testing.allocator;
    const result = try truncate(allocator, "hello world", 8);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello...", result);
}

test "pad_right" {
    const allocator = std.testing.allocator;
    const result = try padRight(allocator, "hi", 5);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hi   ", result);
}

test "pad_left" {
    const allocator = std.testing.allocator;
    const result = try padLeft(allocator, "hi", 5);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("   hi", result);
}

test "center" {
    const allocator = std.testing.allocator;
    const result = try center(allocator, "hi", 6);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("  hi  ", result);
}

test "format_duration_ms" {
    const allocator = std.testing.allocator;
    const result = try formatDuration(allocator, 500);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("500ms", result);
}

test "format_duration_seconds" {
    const allocator = std.testing.allocator;
    const result = try formatDuration(allocator, 2500);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("2.5s", result);
}

test "format_bytes" {
    const allocator = std.testing.allocator;

    const b = try formatBytes(allocator, 500);
    defer allocator.free(b);
    try std.testing.expectEqualStrings("500 B", b);

    const kb = try formatBytes(allocator, 1536);
    defer allocator.free(kb);
    try std.testing.expectEqualStrings("1.5 KB", kb);
}

test "strip_ansi" {
    const allocator = std.testing.allocator;
    const result = try stripAnsi(allocator, "\x1b[31mred\x1b[0m text");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("red text", result);
}
