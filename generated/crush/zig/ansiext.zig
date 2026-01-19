// ansiext.zig - ANSI Extension Module
// Generated from: specs/crush_ansiext.vibee via generated/crush/tri/ansiext.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

// Constants
pub const CONTROL_PICTURES_BASE: u21 = 0x2400;
pub const DEL_PICTURE: u21 = 0x2421;
pub const DEL: u8 = 0x7F;
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

/// Escape replaces control characters with Unicode Control Pictures.
/// Control characters (0x00-0x1F) are replaced with their corresponding
/// symbols in the Unicode Control Pictures block (U+2400-U+241F).
/// DEL (0x7F) is replaced with U+2421 (␡).
///
/// Creation Pattern: []const u8 → ControlCharReplacer → []u8
pub fn escape(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    for (content) |c| {
        if (c <= 0x1F) {
            // Control character: replace with Unicode Control Picture
            const codepoint: u21 = CONTROL_PICTURES_BASE + @as(u21, c);
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(codepoint, &buf) catch unreachable;
            try result.appendSlice(buf[0..len]);
        } else if (c == DEL) {
            // DEL character: replace with ␡
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(DEL_PICTURE, &buf) catch unreachable;
            try result.appendSlice(buf[0..len]);
        } else {
            // Normal character: keep as-is
            try result.append(c);
        }
    }

    return result.toOwnedSlice();
}

/// Check if a character is a control character
pub fn isControl(c: u8) bool {
    return c <= 0x1F or c == DEL;
}

/// Get the Unicode Control Picture for a control character
pub fn getControlPicture(c: u8) ?u21 {
    if (c <= 0x1F) {
        return CONTROL_PICTURES_BASE + @as(u21, c);
    } else if (c == DEL) {
        return DEL_PICTURE;
    }
    return null;
}

// Tests
test "escape_null" {
    const allocator = std.testing.allocator;
    const result = try escape(allocator, "\x00");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("␀", result);
}

test "escape_newline" {
    const allocator = std.testing.allocator;
    const result = try escape(allocator, "\n");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("␊", result);
}

test "escape_tab" {
    const allocator = std.testing.allocator;
    const result = try escape(allocator, "\t");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("␉", result);
}

test "escape_del" {
    const allocator = std.testing.allocator;
    const result = try escape(allocator, "\x7f");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("␡", result);
}

test "escape_normal" {
    const allocator = std.testing.allocator;
    const result = try escape(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "escape_mixed" {
    const allocator = std.testing.allocator;
    const result = try escape(allocator, "a\x00b");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("a␀b", result);
}

test "isControl" {
    try std.testing.expect(isControl(0x00));
    try std.testing.expect(isControl(0x1F));
    try std.testing.expect(isControl(DEL));
    try std.testing.expect(!isControl('a'));
    try std.testing.expect(!isControl(' '));
}

test "getControlPicture" {
    try std.testing.expectEqual(@as(?u21, 0x2400), getControlPicture(0x00));
    try std.testing.expectEqual(@as(?u21, 0x240A), getControlPicture('\n'));
    try std.testing.expectEqual(@as(?u21, DEL_PICTURE), getControlPicture(DEL));
    try std.testing.expectEqual(@as(?u21, null), getControlPicture('a'));
}
