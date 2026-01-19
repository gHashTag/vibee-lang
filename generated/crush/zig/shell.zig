// shell.zig - Shell Execution Module
// Generated from: crush/internal/shell
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Command result
pub const Result = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
    success: bool,
};

/// Shell options
pub const Options = struct {
    cwd: ?[]const u8 = null,
    env: ?std.StringHashMap([]const u8) = null,
    timeout_ms: ?u64 = null,
};

/// Execute shell command
pub fn exec(allocator: std.mem.Allocator, cmd: []const u8, options: Options) !Result {
    _ = options;

    var child = std.process.Child.init(&[_][]const u8{ "sh", "-c", cmd }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.reader().readAllAlloc(allocator, 1024 * 1024);
    const stderr = try child.stderr.?.reader().readAllAlloc(allocator, 1024 * 1024);

    const term = try child.wait();
    const exit_code = term.Exited;

    return Result{
        .stdout = stdout,
        .stderr = stderr,
        .exit_code = exit_code,
        .success = exit_code == 0,
    };
}

/// Quote string for shell
pub fn quote(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    try result.append('\'');

    for (s) |c| {
        if (c == '\'') {
            try result.appendSlice("'\\''");
        } else {
            try result.append(c);
        }
    }

    try result.append('\'');
    return result.toOwnedSlice();
}

/// Check if command exists
pub fn commandExists(cmd: []const u8) bool {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "which", cmd },
    }) catch return false;

    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);

    return result.term.Exited == 0;
}

/// Parse command line into arguments
pub fn parseArgs(allocator: std.mem.Allocator, cmdline: []const u8) ![][]const u8 {
    var args = std.ArrayList([]const u8).init(allocator);
    var current = std.ArrayList(u8).init(allocator);
    var in_quote = false;
    var quote_char: u8 = 0;

    for (cmdline) |c| {
        if (in_quote) {
            if (c == quote_char) {
                in_quote = false;
            } else {
                try current.append(c);
            }
        } else {
            if (c == '\'' or c == '"') {
                in_quote = true;
                quote_char = c;
            } else if (c == ' ' or c == '\t') {
                if (current.items.len > 0) {
                    try args.append(try current.toOwnedSlice());
                    current = std.ArrayList(u8).init(allocator);
                }
            } else {
                try current.append(c);
            }
        }
    }

    if (current.items.len > 0) {
        try args.append(try current.toOwnedSlice());
    } else {
        current.deinit();
    }

    return args.toOwnedSlice();
}

// Tests
test "quote_simple" {
    const allocator = std.testing.allocator;
    const result = try quote(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("'hello'", result);
}

test "quote_with_single_quote" {
    const allocator = std.testing.allocator;
    const result = try quote(allocator, "it's");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("'it'\\''s'", result);
}

test "parse_args_simple" {
    const allocator = std.testing.allocator;
    const args = try parseArgs(allocator, "echo hello world");
    defer {
        for (args) |arg| allocator.free(arg);
        allocator.free(args);
    }

    try std.testing.expectEqual(@as(usize, 3), args.len);
    try std.testing.expectEqualStrings("echo", args[0]);
    try std.testing.expectEqualStrings("hello", args[1]);
    try std.testing.expectEqualStrings("world", args[2]);
}

test "parse_args_quoted" {
    const allocator = std.testing.allocator;
    const args = try parseArgs(allocator, "echo 'hello world'");
    defer {
        for (args) |arg| allocator.free(arg);
        allocator.free(args);
    }

    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expectEqualStrings("echo", args[0]);
    try std.testing.expectEqualStrings("hello world", args[1]);
}

test "result_success" {
    const result = Result{
        .stdout = "output",
        .stderr = "",
        .exit_code = 0,
        .success = true,
    };
    try std.testing.expect(result.success);
}
