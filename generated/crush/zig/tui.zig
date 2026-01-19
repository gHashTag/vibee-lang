// tui.zig - Terminal UI Module
// Generated from: crush/internal/tui
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Key codes
pub const Key = enum {
    enter,
    tab,
    backspace,
    escape,
    up,
    down,
    left,
    right,
    home,
    end,
    page_up,
    page_down,
    delete,
    space,
    ctrl_c,
    ctrl_d,
    ctrl_z,

    pub fn toString(self: Key) []const u8 {
        return switch (self) {
            .enter => "enter",
            .tab => "tab",
            .backspace => "backspace",
            .escape => "escape",
            .up => "up",
            .down => "down",
            .left => "left",
            .right => "right",
            .home => "home",
            .end => "end",
            .page_up => "page_up",
            .page_down => "page_down",
            .delete => "delete",
            .space => "space",
            .ctrl_c => "ctrl+c",
            .ctrl_d => "ctrl+d",
            .ctrl_z => "ctrl+z",
        };
    }
};

/// Style attributes
pub const Style = struct {
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    strikethrough: bool = false,
    fg_color: ?Color = null,
    bg_color: ?Color = null,

    pub fn reset() Style {
        return Style{};
    }

    pub fn withBold(self: Style) Style {
        var s = self;
        s.bold = true;
        return s;
    }

    pub fn withItalic(self: Style) Style {
        var s = self;
        s.italic = true;
        return s;
    }

    pub fn withFg(self: Style, color: Color) Style {
        var s = self;
        s.fg_color = color;
        return s;
    }

    pub fn withBg(self: Style, color: Color) Style {
        var s = self;
        s.bg_color = color;
        return s;
    }
};

/// Colors
pub const Color = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,

    pub fn toAnsi(self: Color) u8 {
        return switch (self) {
            .black => 30,
            .red => 31,
            .green => 32,
            .yellow => 33,
            .blue => 34,
            .magenta => 35,
            .cyan => 36,
            .white => 37,
            .bright_black => 90,
            .bright_red => 91,
            .bright_green => 92,
            .bright_yellow => 93,
            .bright_blue => 94,
            .bright_magenta => 95,
            .bright_cyan => 96,
            .bright_white => 97,
        };
    }
};

/// Size
pub const Size = struct {
    width: u16,
    height: u16,
};

/// Position
pub const Pos = struct {
    x: u16,
    y: u16,
};

/// Box model
pub const Box = struct {
    pos: Pos,
    size: Size,

    pub fn contains(self: Box, x: u16, y: u16) bool {
        return x >= self.pos.x and x < self.pos.x + self.size.width and
            y >= self.pos.y and y < self.pos.y + self.size.height;
    }

    pub fn intersects(self: Box, other: Box) bool {
        return self.pos.x < other.pos.x + other.size.width and
            self.pos.x + self.size.width > other.pos.x and
            self.pos.y < other.pos.y + other.size.height and
            self.pos.y + self.size.height > other.pos.y;
    }
};

/// Component interface
pub const Component = struct {
    render_fn: *const fn (*anyopaque, *Buffer) void,
    update_fn: *const fn (*anyopaque, Msg) ?Cmd,
    ptr: *anyopaque,

    pub fn render(self: Component, buf: *Buffer) void {
        self.render_fn(self.ptr, buf);
    }

    pub fn update(self: Component, msg: Msg) ?Cmd {
        return self.update_fn(self.ptr, msg);
    }
};

/// Message type
pub const Msg = union(enum) {
    key: Key,
    char: u8,
    resize: Size,
    tick,
    quit,
};

/// Command type
pub const Cmd = enum {
    none,
    quit,
    refresh,
};

/// Buffer for rendering
pub const Buffer = struct {
    cells: [][]Cell,
    width: u16,
    height: u16,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub const Cell = struct {
        char: u21 = ' ',
        style: Style = Style{},
    };

    pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Self {
        const cells = try allocator.alloc([]Cell, height);
        for (cells) |*row| {
            row.* = try allocator.alloc(Cell, width);
            for (row.*) |*cell| {
                cell.* = Cell{};
            }
        }

        return Self{
            .cells = cells,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.cells) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.cells);
    }

    pub fn setCell(self: *Self, x: u16, y: u16, char: u21, style: Style) void {
        if (x < self.width and y < self.height) {
            self.cells[y][x] = Cell{ .char = char, .style = style };
        }
    }

    pub fn setString(self: *Self, x: u16, y: u16, str: []const u8, style: Style) void {
        var cx = x;
        for (str) |c| {
            if (cx >= self.width) break;
            self.setCell(cx, y, c, style);
            cx += 1;
        }
    }

    pub fn clear(self: *Self) void {
        for (self.cells) |row| {
            for (row) |*cell| {
                cell.* = Cell{};
            }
        }
    }
};

// Tests
test "key_to_string" {
    try std.testing.expectEqualStrings("enter", Key.enter.toString());
    try std.testing.expectEqualStrings("ctrl+c", Key.ctrl_c.toString());
}

test "color_to_ansi" {
    try std.testing.expectEqual(@as(u8, 31), Color.red.toAnsi());
    try std.testing.expectEqual(@as(u8, 32), Color.green.toAnsi());
}

test "style_builder" {
    const style = Style.reset().withBold().withFg(.red);
    try std.testing.expect(style.bold);
    try std.testing.expectEqual(Color.red, style.fg_color.?);
}

test "box_contains" {
    const box = Box{
        .pos = Pos{ .x = 10, .y = 10 },
        .size = Size{ .width = 20, .height = 10 },
    };

    try std.testing.expect(box.contains(15, 15));
    try std.testing.expect(!box.contains(5, 5));
    try std.testing.expect(!box.contains(35, 15));
}

test "box_intersects" {
    const box1 = Box{
        .pos = Pos{ .x = 0, .y = 0 },
        .size = Size{ .width = 10, .height = 10 },
    };
    const box2 = Box{
        .pos = Pos{ .x = 5, .y = 5 },
        .size = Size{ .width = 10, .height = 10 },
    };
    const box3 = Box{
        .pos = Pos{ .x = 20, .y = 20 },
        .size = Size{ .width = 10, .height = 10 },
    };

    try std.testing.expect(box1.intersects(box2));
    try std.testing.expect(!box1.intersects(box3));
}

test "buffer_init" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 80, 24);
    defer buf.deinit();

    try std.testing.expectEqual(@as(u16, 80), buf.width);
    try std.testing.expectEqual(@as(u16, 24), buf.height);
}

test "buffer_set_cell" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 80, 24);
    defer buf.deinit();

    buf.setCell(5, 5, 'X', Style{});
    try std.testing.expectEqual(@as(u21, 'X'), buf.cells[5][5].char);
}

test "buffer_set_string" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 80, 24);
    defer buf.deinit();

    buf.setString(0, 0, "Hello", Style{});
    try std.testing.expectEqual(@as(u21, 'H'), buf.cells[0][0].char);
    try std.testing.expectEqual(@as(u21, 'e'), buf.cells[0][1].char);
}

test "msg_types" {
    const key_msg = Msg{ .key = .enter };
    const char_msg = Msg{ .char = 'a' };
    const resize_msg = Msg{ .resize = Size{ .width = 80, .height = 24 } };

    try std.testing.expectEqual(Key.enter, key_msg.key);
    try std.testing.expectEqual(@as(u8, 'a'), char_msg.char);
    try std.testing.expectEqual(@as(u16, 80), resize_msg.resize.width);
}
