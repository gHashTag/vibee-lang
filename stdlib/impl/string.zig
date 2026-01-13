// ============================================================================
// VIBEE STDLIB - STRING MODULE
// String manipulation functions
// ============================================================================

const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;

// ============================================================================
// STRING LENGTH AND CHECKS
// ============================================================================

/// Get string length
pub fn len(s: []const u8) usize {
    return s.len;
}

/// Check if string is empty
pub fn isEmpty(s: []const u8) bool {
    return s.len == 0;
}

/// Check if string is blank (empty or only whitespace)
pub fn isBlank(s: []const u8) bool {
    for (s) |c| {
        if (!ascii.isWhitespace(c)) return false;
    }
    return true;
}

// ============================================================================
// CASE CONVERSION
// ============================================================================

/// Convert to uppercase
pub fn toUpper(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = ascii.toUpper(c);
    }
    return result;
}

/// Convert to lowercase
pub fn toLower(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = ascii.toLower(c);
    }
    return result;
}

/// Capitalize first letter
pub fn capitalize(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    if (s.len == 0) return try allocator.alloc(u8, 0);
    
    const result = try allocator.alloc(u8, s.len);
    result[0] = ascii.toUpper(s[0]);
    @memcpy(result[1..], s[1..]);
    return result;
}

// ============================================================================
// TRIMMING
// ============================================================================

/// Trim whitespace from both ends
pub fn trim(s: []const u8) []const u8 {
    return mem.trim(u8, s, &ascii.whitespace);
}

/// Trim whitespace from left
pub fn trimLeft(s: []const u8) []const u8 {
    return mem.trimLeft(u8, s, &ascii.whitespace);
}

/// Trim whitespace from right
pub fn trimRight(s: []const u8) []const u8 {
    return mem.trimRight(u8, s, &ascii.whitespace);
}

// ============================================================================
// SEARCHING
// ============================================================================

/// Check if string contains substring
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return mem.indexOf(u8, haystack, needle) != null;
}

/// Find index of substring
pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    return mem.indexOf(u8, haystack, needle);
}

/// Find last index of substring
pub fn lastIndexOf(haystack: []const u8, needle: []const u8) ?usize {
    return mem.lastIndexOf(u8, haystack, needle);
}

/// Check if string starts with prefix
pub fn startsWith(s: []const u8, prefix: []const u8) bool {
    return mem.startsWith(u8, s, prefix);
}

/// Check if string ends with suffix
pub fn endsWith(s: []const u8, suffix: []const u8) bool {
    return mem.endsWith(u8, s, suffix);
}

/// Count occurrences of substring
pub fn count(haystack: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;
    
    var cnt: usize = 0;
    var i: usize = 0;
    while (i <= haystack.len - needle.len) {
        if (mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            cnt += 1;
            i += needle.len;
        } else {
            i += 1;
        }
    }
    return cnt;
}

// ============================================================================
// SPLITTING AND JOINING
// ============================================================================

/// Split string by delimiter
pub fn split(allocator: std.mem.Allocator, s: []const u8, delimiter: []const u8) ![][]const u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    
    var iter = mem.splitSequence(u8, s, delimiter);
    while (iter.next()) |part| {
        try parts.append(part);
    }
    
    return parts.toOwnedSlice();
}

/// Join strings with separator
pub fn join(allocator: std.mem.Allocator, parts: []const []const u8, separator: []const u8) ![]u8 {
    if (parts.len == 0) return try allocator.alloc(u8, 0);
    
    // Calculate total length
    var total_len: usize = 0;
    for (parts) |part| {
        total_len += part.len;
    }
    total_len += separator.len * (parts.len - 1);
    
    // Build result
    const result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;
    
    for (parts, 0..) |part, i| {
        @memcpy(result[pos..][0..part.len], part);
        pos += part.len;
        
        if (i < parts.len - 1) {
            @memcpy(result[pos..][0..separator.len], separator);
            pos += separator.len;
        }
    }
    
    return result;
}

// ============================================================================
// REPLACEMENT
// ============================================================================

/// Replace all occurrences of old with new
pub fn replace(allocator: std.mem.Allocator, s: []const u8, old: []const u8, new: []const u8) ![]u8 {
    if (old.len == 0) {
        const result = try allocator.alloc(u8, s.len);
        @memcpy(result, s);
        return result;
    }
    
    const cnt = count(s, old);
    if (cnt == 0) {
        const result = try allocator.alloc(u8, s.len);
        @memcpy(result, s);
        return result;
    }
    
    const new_len = s.len - (cnt * old.len) + (cnt * new.len);
    const result = try allocator.alloc(u8, new_len);
    
    var src_pos: usize = 0;
    var dst_pos: usize = 0;
    
    while (src_pos < s.len) {
        if (src_pos + old.len <= s.len and mem.eql(u8, s[src_pos..][0..old.len], old)) {
            @memcpy(result[dst_pos..][0..new.len], new);
            dst_pos += new.len;
            src_pos += old.len;
        } else {
            result[dst_pos] = s[src_pos];
            dst_pos += 1;
            src_pos += 1;
        }
    }
    
    return result;
}

// ============================================================================
// PADDING
// ============================================================================

/// Pad string on left to reach target length
pub fn padLeft(allocator: std.mem.Allocator, s: []const u8, target_len: usize, pad_char: u8) ![]u8 {
    if (s.len >= target_len) {
        const result = try allocator.alloc(u8, s.len);
        @memcpy(result, s);
        return result;
    }
    
    const result = try allocator.alloc(u8, target_len);
    const pad_len = target_len - s.len;
    
    @memset(result[0..pad_len], pad_char);
    @memcpy(result[pad_len..], s);
    
    return result;
}

/// Pad string on right to reach target length
pub fn padRight(allocator: std.mem.Allocator, s: []const u8, target_len: usize, pad_char: u8) ![]u8 {
    if (s.len >= target_len) {
        const result = try allocator.alloc(u8, s.len);
        @memcpy(result, s);
        return result;
    }
    
    const result = try allocator.alloc(u8, target_len);
    @memcpy(result[0..s.len], s);
    @memset(result[s.len..], pad_char);
    
    return result;
}

// ============================================================================
// SUBSTRING
// ============================================================================

/// Get substring
pub fn substring(s: []const u8, start: usize, end_opt: ?usize) []const u8 {
    const end = end_opt orelse s.len;
    if (start >= s.len) return "";
    const actual_end = @min(end, s.len);
    if (start >= actual_end) return "";
    return s[start..actual_end];
}

/// Get character at index
pub fn charAt(s: []const u8, index: usize) ?u8 {
    if (index >= s.len) return null;
    return s[index];
}

// ============================================================================
// REVERSAL
// ============================================================================

/// Reverse string
pub fn reverse(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[s.len - 1 - i] = c;
    }
    return result;
}

// ============================================================================
// REPETITION
// ============================================================================

/// Repeat string n times
pub fn repeat(allocator: std.mem.Allocator, s: []const u8, n: usize) ![]u8 {
    if (n == 0 or s.len == 0) return try allocator.alloc(u8, 0);
    
    const result = try allocator.alloc(u8, s.len * n);
    for (0..n) |i| {
        @memcpy(result[i * s.len ..][0..s.len], s);
    }
    return result;
}

// ============================================================================
// COMPARISON
// ============================================================================

/// Compare strings (case-sensitive)
pub fn compare(a: []const u8, b: []const u8) std.math.Order {
    return mem.order(u8, a, b);
}

/// Check if strings are equal
pub fn equals(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

/// Check if strings are equal (case-insensitive)
pub fn equalsIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ascii.toLower(ca) != ascii.toLower(cb)) return false;
    }
    return true;
}

// ============================================================================
// TESTS
// ============================================================================

test "len and isEmpty" {
    try std.testing.expectEqual(@as(usize, 5), len("hello"));
    try std.testing.expect(isEmpty(""));
    try std.testing.expect(!isEmpty("a"));
}

test "isBlank" {
    try std.testing.expect(isBlank(""));
    try std.testing.expect(isBlank("   "));
    try std.testing.expect(!isBlank("  a  "));
}

test "case conversion" {
    const upper = try toUpper(std.testing.allocator, "hello");
    defer std.testing.allocator.free(upper);
    try std.testing.expectEqualStrings("HELLO", upper);
    
    const lower = try toLower(std.testing.allocator, "HELLO");
    defer std.testing.allocator.free(lower);
    try std.testing.expectEqualStrings("hello", lower);
}

test "trim" {
    try std.testing.expectEqualStrings("hello", trim("  hello  "));
    try std.testing.expectEqualStrings("hello", trimLeft("  hello"));
    try std.testing.expectEqualStrings("hello", trimRight("hello  "));
}

test "searching" {
    try std.testing.expect(contains("hello world", "world"));
    try std.testing.expect(!contains("hello world", "foo"));
    try std.testing.expectEqual(@as(?usize, 6), indexOf("hello world", "world"));
    try std.testing.expect(startsWith("hello", "hel"));
    try std.testing.expect(endsWith("hello", "llo"));
}

test "count" {
    try std.testing.expectEqual(@as(usize, 3), count("abcabcabc", "abc"));
    try std.testing.expectEqual(@as(usize, 0), count("hello", "xyz"));
}

test "split and join" {
    const parts = try split(std.testing.allocator, "a,b,c", ",");
    defer std.testing.allocator.free(parts);
    try std.testing.expectEqual(@as(usize, 3), parts.len);
    
    const joined = try join(std.testing.allocator, &[_][]const u8{ "a", "b", "c" }, "-");
    defer std.testing.allocator.free(joined);
    try std.testing.expectEqualStrings("a-b-c", joined);
}

test "replace" {
    const result = try replace(std.testing.allocator, "hello world", "world", "vibee");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("hello vibee", result);
}

test "padding" {
    const left = try padLeft(std.testing.allocator, "42", 5, '0');
    defer std.testing.allocator.free(left);
    try std.testing.expectEqualStrings("00042", left);
    
    const right = try padRight(std.testing.allocator, "hi", 5, ' ');
    defer std.testing.allocator.free(right);
    try std.testing.expectEqualStrings("hi   ", right);
}

test "substring" {
    try std.testing.expectEqualStrings("ell", substring("hello", 1, 4));
    try std.testing.expectEqualStrings("llo", substring("hello", 2, null));
}

test "reverse" {
    const rev = try reverse(std.testing.allocator, "hello");
    defer std.testing.allocator.free(rev);
    try std.testing.expectEqualStrings("olleh", rev);
}

test "repeat" {
    const rep = try repeat(std.testing.allocator, "ab", 3);
    defer std.testing.allocator.free(rep);
    try std.testing.expectEqualStrings("ababab", rep);
}

test "comparison" {
    try std.testing.expect(equals("hello", "hello"));
    try std.testing.expect(!equals("hello", "world"));
    try std.testing.expect(equalsIgnoreCase("Hello", "hello"));
}
