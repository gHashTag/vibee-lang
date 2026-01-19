// cmd.zig - Command Module
// Generated from: crush/internal/cmd
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Command result
pub const Result = struct {
    success: bool,
    output: ?[]const u8,
    err_msg: ?[]const u8,
    exit_code: u8,
};

/// Command definition
pub const Command = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    aliases: []const []const u8,
    hidden: bool = false,
    run_fn: ?*const fn (*Context) Result = null,

    const Self = @This();

    pub fn init(name: []const u8, description: []const u8) Self {
        return Self{
            .name = name,
            .description = description,
            .usage = name,
            .aliases = &[_][]const u8{},
        };
    }

    pub fn withUsage(self: *Self, usage: []const u8) *Self {
        self.usage = usage;
        return self;
    }

    pub fn withHidden(self: *Self, hidden: bool) *Self {
        self.hidden = hidden;
        return self;
    }
};

/// Command context
pub const Context = struct {
    args: []const []const u8,
    flags: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, args: []const []const u8) Self {
        return Self{
            .args = args,
            .flags = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.flags.deinit();
    }

    pub fn setFlag(self: *Self, name: []const u8, value: []const u8) !void {
        try self.flags.put(name, value);
    }

    pub fn getFlag(self: *Self, name: []const u8) ?[]const u8 {
        return self.flags.get(name);
    }

    pub fn hasFlag(self: *Self, name: []const u8) bool {
        return self.flags.contains(name);
    }

    pub fn argCount(self: *Self) usize {
        return self.args.len;
    }

    pub fn getArg(self: *Self, index: usize) ?[]const u8 {
        if (index < self.args.len) {
            return self.args[index];
        }
        return null;
    }
};

/// Command registry
pub const Registry = struct {
    commands: std.StringHashMap(Command),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .commands = std.StringHashMap(Command).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.commands.deinit();
    }

    pub fn register(self: *Self, cmd: Command) !void {
        try self.commands.put(cmd.name, cmd);
    }

    pub fn get(self: *Self, name: []const u8) ?Command {
        return self.commands.get(name);
    }

    pub fn list(self: *Self, allocator: std.mem.Allocator) ![]Command {
        var result = std.ArrayList(Command).init(allocator);
        var iter = self.commands.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.hidden) {
                try result.append(entry.value_ptr.*);
            }
        }
        return result.toOwnedSlice();
    }

    pub fn count(self: *Self) usize {
        return self.commands.count();
    }
};

/// Parse command line arguments
pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !Context {
    var ctx = Context.init(allocator, args);

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.startsWith(u8, arg, "--")) {
            const flag = arg[2..];
            if (std.mem.indexOf(u8, flag, "=")) |eq_idx| {
                try ctx.setFlag(flag[0..eq_idx], flag[eq_idx + 1 ..]);
            } else if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                try ctx.setFlag(flag, args[i + 1]);
                i += 1;
            } else {
                try ctx.setFlag(flag, "true");
            }
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len == 2) {
            const flag = arg[1..2];
            if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                try ctx.setFlag(flag, args[i + 1]);
                i += 1;
            } else {
                try ctx.setFlag(flag, "true");
            }
        }
    }

    return ctx;
}

// Tests
test "command_init" {
    const cmd = Command.init("test", "Test command");
    try std.testing.expectEqualStrings("test", cmd.name);
    try std.testing.expectEqualStrings("Test command", cmd.description);
}

test "command_builder" {
    var cmd = Command.init("hidden", "Hidden command");
    _ = cmd.withHidden(true).withUsage("hidden [options]");

    try std.testing.expect(cmd.hidden);
    try std.testing.expectEqualStrings("hidden [options]", cmd.usage);
}

test "context_flags" {
    const allocator = std.testing.allocator;
    var ctx = Context.init(allocator, &[_][]const u8{});
    defer ctx.deinit();

    try ctx.setFlag("verbose", "true");
    try std.testing.expect(ctx.hasFlag("verbose"));
    try std.testing.expectEqualStrings("true", ctx.getFlag("verbose").?);
}

test "context_args" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "cmd", "arg1", "arg2" };
    var ctx = Context.init(allocator, &args);
    defer ctx.deinit();

    try std.testing.expectEqual(@as(usize, 3), ctx.argCount());
    try std.testing.expectEqualStrings("arg1", ctx.getArg(1).?);
}

test "registry" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    try registry.register(Command.init("test", "Test"));
    try std.testing.expectEqual(@as(usize, 1), registry.count());

    const cmd = registry.get("test");
    try std.testing.expect(cmd != null);
}

test "parse_args_long_flag" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "cmd", "--verbose", "--output", "file.txt" };
    var ctx = try parseArgs(allocator, &args);
    defer ctx.deinit();

    try std.testing.expectEqualStrings("true", ctx.getFlag("verbose").?);
    try std.testing.expectEqualStrings("file.txt", ctx.getFlag("output").?);
}

test "parse_args_equals" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "cmd", "--name=value" };
    var ctx = try parseArgs(allocator, &args);
    defer ctx.deinit();

    try std.testing.expectEqualStrings("value", ctx.getFlag("name").?);
}

test "result" {
    const result = Result{
        .success = true,
        .output = "done",
        .err_msg = null,
        .exit_code = 0,
    };
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
