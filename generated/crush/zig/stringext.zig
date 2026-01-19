// stringext.zig - String Extension Utilities
// Generated from: specs/crush/stringext.vibee via generated/crush/tri/stringext.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

/// Capitalize converts a string to title case.
/// Each word's first letter is capitalized, rest are lowercased.
/// Creation Pattern: RawString → TitleCaseConverter → TransformedString
pub fn capitalize(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) {
        return try allocator.alloc(u8, 0);
    }

    var result = try allocator.alloc(u8, text.len);
    var capitalize_next = true;

    for (text, 0..) |c, i| {
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
            result[i] = c;
            capitalize_next = true;
        } else if (capitalize_next) {
            result[i] = std.ascii.toUpper(c);
            capitalize_next = false;
        } else {
            result[i] = std.ascii.toLower(c);
        }
    }

    return result;
}

/// ContainsAny checks if the string contains any of the given substrings.
/// Returns true on first match, false if none found.
/// Creation Pattern: (RawString, Patterns) → MultiPatternSearch → bool
pub fn containsAny(str: []const u8, args: []const []const u8) bool {
    if (str.len == 0 or args.len == 0) {
        return false;
    }

    for (args) |arg| {
        if (arg.len == 0) continue;
        if (std.mem.indexOf(u8, str, arg) != null) {
            return true;
        }
    }

    return false;
}

/// Check if string contains a single substring
pub fn contains(str: []const u8, substr: []const u8) bool {
    return std.mem.indexOf(u8, str, substr) != null;
}

/// Convert string to lowercase
pub fn toLower(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, text.len);
    for (text, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }
    return result;
}

/// Convert string to uppercase
pub fn toUpper(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, text.len);
    for (text, 0..) |c, i| {
        result[i] = std.ascii.toUpper(c);
    }
    return result;
}

/// Trim whitespace from both ends
pub fn trim(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\n\r");
}

/// Trim whitespace from left
pub fn trimLeft(text: []const u8) []const u8 {
    return std.mem.trimLeft(u8, text, " \t\n\r");
}

/// Trim whitespace from right
pub fn trimRight(text: []const u8) []const u8 {
    return std.mem.trimRight(u8, text, " \t\n\r");
}

// Tests
test "capitalize_word" {
    const allocator = std.testing.allocator;
    const result = try capitalize(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "capitalize_sentence" {
    const allocator = std.testing.allocator;
    const result = try capitalize(allocator, "hello world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello World", result);
}

test "capitalize_already_upper" {
    const allocator = std.testing.allocator;
    const result = try capitalize(allocator, "HELLO");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "capitalize_empty" {
    const allocator = std.testing.allocator;
    const result = try capitalize(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "capitalize_single_char" {
    const allocator = std.testing.allocator;
    const result = try capitalize(allocator, "a");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("A", result);
}

test "containsAny_first" {
    const args = [_][]const u8{ "hello", "foo", "bar" };
    try std.testing.expect(containsAny("hello world", &args));
}

test "containsAny_middle" {
    const args = [_][]const u8{ "foo", "world", "bar" };
    try std.testing.expect(containsAny("hello world", &args));
}

test "containsAny_none" {
    const args = [_][]const u8{ "foo", "bar", "baz" };
    try std.testing.expect(!containsAny("hello world", &args));
}

test "containsAny_empty_args" {
    const args = [_][]const u8{};
    try std.testing.expect(!containsAny("hello", &args));
}

test "containsAny_empty_string" {
    const args = [_][]const u8{"hello"};
    try std.testing.expect(!containsAny("", &args));
}

test "containsAny_partial_match" {
    const args = [_][]const u8{"ell"};
    try std.testing.expect(containsAny("hello world", &args));
}

test "contains" {
    try std.testing.expect(contains("hello world", "world"));
    try std.testing.expect(!contains("hello world", "foo"));
}

test "toLower" {
    const allocator = std.testing.allocator;
    const result = try toLower(allocator, "HELLO");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "toUpper" {
    const allocator = std.testing.allocator;
    const result = try toUpper(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO", result);
}

test "trim" {
    try std.testing.expectEqualStrings("hello", trim("  hello  "));
    try std.testing.expectEqualStrings("hello", trim("\t\nhello\r\n"));
}

test "trimLeft" {
    try std.testing.expectEqualStrings("hello  ", trimLeft("  hello  "));
}

test "trimRight" {
    try std.testing.expectEqualStrings("  hello", trimRight("  hello  "));
}
