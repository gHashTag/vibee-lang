// uicmd.zig - UI Commands Module
// Generated from: crush/internal/uicmd
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// UI Command types
pub const CommandType = enum {
    navigate,
    select,
    scroll,
    input,
    submit,
    cancel,
    refresh,
    help,
    quit,

    pub fn toString(self: CommandType) []const u8 {
        return switch (self) {
            .navigate => "navigate",
            .select => "select",
            .scroll => "scroll",
            .input => "input",
            .submit => "submit",
            .cancel => "cancel",
            .refresh => "refresh",
            .help => "help",
            .quit => "quit",
        };
    }
};

/// Navigation direction
pub const Direction = enum {
    up,
    down,
    left,
    right,
    home,
    end,
    page_up,
    page_down,
};

/// UI Command
pub const UICommand = struct {
    cmd_type: CommandType,
    direction: ?Direction = null,
    value: ?[]const u8 = null,
    index: ?usize = null,
};

/// Command handler
pub const Handler = struct {
    handlers: std.AutoHashMap(CommandType, *const fn (UICommand) void),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .handlers = std.AutoHashMap(CommandType, *const fn (UICommand) void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.handlers.deinit();
    }

    pub fn register(self: *Self, cmd_type: CommandType, handler: *const fn (UICommand) void) !void {
        try self.handlers.put(cmd_type, handler);
    }

    pub fn handle(self: *Self, cmd: UICommand) bool {
        if (self.handlers.get(cmd.cmd_type)) |handler| {
            handler(cmd);
            return true;
        }
        return false;
    }

    pub fn hasHandler(self: *Self, cmd_type: CommandType) bool {
        return self.handlers.contains(cmd_type);
    }
};

/// Key binding
pub const KeyBinding = struct {
    key: []const u8,
    command: UICommand,
    description: []const u8,
};

/// Key map
pub const KeyMap = struct {
    bindings: std.StringHashMap(UICommand),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .bindings = std.StringHashMap(UICommand).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.bindings.deinit();
    }

    pub fn bind(self: *Self, key: []const u8, cmd: UICommand) !void {
        try self.bindings.put(key, cmd);
    }

    pub fn get(self: *Self, key: []const u8) ?UICommand {
        return self.bindings.get(key);
    }

    pub fn unbind(self: *Self, key: []const u8) void {
        _ = self.bindings.remove(key);
    }

    pub fn count(self: *Self) usize {
        return self.bindings.count();
    }
};

/// Default key bindings
pub fn defaultKeyMap(allocator: std.mem.Allocator) !KeyMap {
    var km = KeyMap.init(allocator);

    try km.bind("up", UICommand{ .cmd_type = .navigate, .direction = .up });
    try km.bind("down", UICommand{ .cmd_type = .navigate, .direction = .down });
    try km.bind("left", UICommand{ .cmd_type = .navigate, .direction = .left });
    try km.bind("right", UICommand{ .cmd_type = .navigate, .direction = .right });
    try km.bind("enter", UICommand{ .cmd_type = .submit });
    try km.bind("esc", UICommand{ .cmd_type = .cancel });
    try km.bind("q", UICommand{ .cmd_type = .quit });
    try km.bind("?", UICommand{ .cmd_type = .help });

    return km;
}

// Tests
test "command_type_to_string" {
    try std.testing.expectEqualStrings("navigate", CommandType.navigate.toString());
    try std.testing.expectEqualStrings("quit", CommandType.quit.toString());
}

test "ui_command" {
    const cmd = UICommand{
        .cmd_type = .navigate,
        .direction = .up,
    };
    try std.testing.expectEqual(CommandType.navigate, cmd.cmd_type);
    try std.testing.expectEqual(Direction.up, cmd.direction.?);
}

test "key_map_bind" {
    const allocator = std.testing.allocator;
    var km = KeyMap.init(allocator);
    defer km.deinit();

    try km.bind("enter", UICommand{ .cmd_type = .submit });
    const cmd = km.get("enter");

    try std.testing.expect(cmd != null);
    try std.testing.expectEqual(CommandType.submit, cmd.?.cmd_type);
}

test "key_map_unbind" {
    const allocator = std.testing.allocator;
    var km = KeyMap.init(allocator);
    defer km.deinit();

    try km.bind("q", UICommand{ .cmd_type = .quit });
    km.unbind("q");

    try std.testing.expect(km.get("q") == null);
}

test "default_key_map" {
    const allocator = std.testing.allocator;
    var km = try defaultKeyMap(allocator);
    defer km.deinit();

    try std.testing.expect(km.count() >= 8);
    try std.testing.expect(km.get("up") != null);
    try std.testing.expect(km.get("enter") != null);
}

test "handler_register" {
    const allocator = std.testing.allocator;
    var handler = Handler.init(allocator);
    defer handler.deinit();

    const dummy = struct {
        fn handle(_: UICommand) void {}
    }.handle;

    try handler.register(.quit, dummy);
    try std.testing.expect(handler.hasHandler(.quit));
}
