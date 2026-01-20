// ═══════════════════════════════════════════════════════════════════════════════
// PRO UI DESIGN V49 - Generated from specs/pro_ui_design_v49.vibee
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
//
// Scientific References:
// - Fitts (1954) - Target acquisition time
// - Hick (1952) - Choice reaction time
// - Miller (1956) - Working memory 7±2
// - Card, Moran, Newell (1983) - GOMS Model
// - Nielsen (1994) - 10 Usability Heuristics
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const TRINITY: u32 = 3;
pub const GOLDEN_RATIO: f64 = 1.618033988749895;

// Fitts' Law constants
pub const FITTS_A: f64 = 50.0; // Intercept (ms)
pub const FITTS_B: f64 = 150.0; // Slope (ms/bit)

// Hick's Law constant
pub const HICK_B: f64 = 150.0; // ms per bit

// Miller's Law
pub const MILLER_CAPACITY: u8 = 7;

// Frame timing
pub const TARGET_FPS: u32 = 60;
pub const FRAME_TIME_NS: u64 = 16_666_667; // ~16.67ms

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const RGB = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn toAnsi(self: RGB) [19]u8 {
        var buf: [19]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d}m", .{ self.r, self.g, self.b }) catch {};
        return buf;
    }

    pub fn toBgAnsi(self: RGB) [19]u8 {
        var buf: [19]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[48;2;{d};{d};{d}m", .{ self.r, self.g, self.b }) catch {};
        return buf;
    }
};

pub const TextStyle = struct {
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    dim: bool = false,
    reverse: bool = false,
};

pub const Rect = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,

    pub fn contains(self: Rect, px: u16, py: u16) bool {
        return px >= self.x and px < self.x + self.width and
            py >= self.y and py < self.y + self.height;
    }

    pub fn area(self: Rect) u32 {
        return @as(u32, self.width) * @as(u32, self.height);
    }
};

pub const Cell = struct {
    char: u21 = ' ',
    fg: RGB = .{ .r = 255, .g = 255, .b = 255 },
    bg: RGB = .{ .r = 0, .g = 0, .b = 0 },
    style: TextStyle = .{},
};

pub const FlexDirection = enum { ROW, COLUMN };
pub const JustifyContent = enum { START, END, CENTER, SPACE_BETWEEN, SPACE_AROUND };
pub const AlignItems = enum { START, END, CENTER, STRETCH };

// ═══════════════════════════════════════════════════════════════════════════════
// THEME SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

pub const Theme = struct {
    name: []const u8,
    bg_primary: RGB,
    bg_secondary: RGB,
    fg_primary: RGB,
    fg_secondary: RGB,
    accent: RGB,
    success: RGB,
    warning: RGB,
    @"error": RGB,
    diff_add: RGB,
    diff_del: RGB,
};

pub const THEME_DRACULA = Theme{
    .name = "Dracula",
    .bg_primary = .{ .r = 40, .g = 42, .b = 54 },
    .bg_secondary = .{ .r = 68, .g = 71, .b = 90 },
    .fg_primary = .{ .r = 248, .g = 248, .b = 242 },
    .fg_secondary = .{ .r = 98, .g = 114, .b = 164 },
    .accent = .{ .r = 189, .g = 147, .b = 249 },
    .success = .{ .r = 80, .g = 250, .b = 123 },
    .warning = .{ .r = 255, .g = 184, .b = 108 },
    .@"error" = .{ .r = 255, .g = 85, .b = 85 },
    .diff_add = .{ .r = 80, .g = 250, .b = 123 },
    .diff_del = .{ .r = 255, .g = 85, .b = 85 },
};

pub const THEME_NORD = Theme{
    .name = "Nord",
    .bg_primary = .{ .r = 46, .g = 52, .b = 64 },
    .bg_secondary = .{ .r = 59, .g = 66, .b = 82 },
    .fg_primary = .{ .r = 236, .g = 239, .b = 244 },
    .fg_secondary = .{ .r = 76, .g = 86, .b = 106 },
    .accent = .{ .r = 136, .g = 192, .b = 208 },
    .success = .{ .r = 163, .g = 190, .b = 140 },
    .warning = .{ .r = 235, .g = 203, .b = 139 },
    .@"error" = .{ .r = 191, .g = 97, .b = 106 },
    .diff_add = .{ .r = 163, .g = 190, .b = 140 },
    .diff_del = .{ .r = 191, .g = 97, .b = 106 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ANSIRenderer = struct {
    pub const RESET = "\x1b[0m";
    pub const BOLD = "\x1b[1m";
    pub const DIM = "\x1b[2m";
    pub const ITALIC = "\x1b[3m";
    pub const UNDERLINE = "\x1b[4m";
    pub const REVERSE = "\x1b[7m";

    pub const CLEAR_SCREEN = "\x1b[2J";
    pub const CLEAR_LINE = "\x1b[2K";
    pub const HIDE_CURSOR = "\x1b[?25l";
    pub const SHOW_CURSOR = "\x1b[?25h";
    pub const HOME = "\x1b[H";

    pub fn moveTo(writer: anytype, x: u16, y: u16) !void {
        try writer.print("\x1b[{d};{d}H", .{ y + 1, x + 1 });
    }

    pub fn setFg(writer: anytype, color: RGB) !void {
        try writer.print("\x1b[38;2;{d};{d};{d}m", .{ color.r, color.g, color.b });
    }

    pub fn setBg(writer: anytype, color: RGB) !void {
        try writer.print("\x1b[48;2;{d};{d};{d}m", .{ color.r, color.g, color.b });
    }

    pub fn setStyle(writer: anytype, style: TextStyle) !void {
        if (style.bold) try writer.writeAll(BOLD);
        if (style.dim) try writer.writeAll(DIM);
        if (style.italic) try writer.writeAll(ITALIC);
        if (style.underline) try writer.writeAll(UNDERLINE);
        if (style.reverse) try writer.writeAll(REVERSE);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BOX RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

pub const BoxStyle = enum {
    SINGLE,
    DOUBLE,
    ROUNDED,
    HEAVY,

    pub fn chars(self: BoxStyle) struct { tl: []const u8, tr: []const u8, bl: []const u8, br: []const u8, h: []const u8, v: []const u8 } {
        return switch (self) {
            .SINGLE => .{ .tl = "┌", .tr = "┐", .bl = "└", .br = "┘", .h = "─", .v = "│" },
            .DOUBLE => .{ .tl = "╔", .tr = "╗", .bl = "╚", .br = "╝", .h = "═", .v = "║" },
            .ROUNDED => .{ .tl = "╭", .tr = "╮", .bl = "╰", .br = "╯", .h = "─", .v = "│" },
            .HEAVY => .{ .tl = "┏", .tr = "┓", .bl = "┗", .br = "┛", .h = "━", .v = "┃" },
        };
    }
};

pub const BoxRenderer = struct {
    theme: Theme,

    const Self = @This();

    pub fn init(theme: Theme) Self {
        return Self{ .theme = theme };
    }

    pub fn drawBox(self: *Self, writer: anytype, rect: Rect, style: BoxStyle, title: ?[]const u8) !void {
        const c = style.chars();

        // Set colors
        try ANSIRenderer.setFg(writer, self.theme.accent);

        // Top border
        try ANSIRenderer.moveTo(writer, rect.x, rect.y);
        try writer.writeAll(c.tl);

        if (title) |t| {
            const title_len = @min(t.len, rect.width - 4);
            try writer.writeAll(c.h);
            try writer.writeAll(" ");
            try ANSIRenderer.setFg(writer, self.theme.fg_primary);
            try writer.writeAll(t[0..title_len]);
            try ANSIRenderer.setFg(writer, self.theme.accent);
            try writer.writeAll(" ");
            for (0..(rect.width - title_len - 4)) |_| {
                try writer.writeAll(c.h);
            }
        } else {
            for (0..(rect.width - 2)) |_| {
                try writer.writeAll(c.h);
            }
        }
        try writer.writeAll(c.tr);

        // Side borders
        for (1..(rect.height - 1)) |i| {
            try ANSIRenderer.moveTo(writer, rect.x, rect.y + @as(u16, @intCast(i)));
            try writer.writeAll(c.v);
            try ANSIRenderer.moveTo(writer, rect.x + rect.width - 1, rect.y + @as(u16, @intCast(i)));
            try writer.writeAll(c.v);
        }

        // Bottom border
        try ANSIRenderer.moveTo(writer, rect.x, rect.y + rect.height - 1);
        try writer.writeAll(c.bl);
        for (0..(rect.width - 2)) |_| {
            try writer.writeAll(c.h);
        }
        try writer.writeAll(c.br);

        try writer.writeAll(ANSIRenderer.RESET);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProgressBar = struct {
    theme: Theme,
    width: u16,

    const BLOCKS = [_][]const u8{ " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█" };

    const Self = @This();

    pub fn init(theme: Theme, width: u16) Self {
        return Self{ .theme = theme, .width = width };
    }

    pub fn render(self: *Self, writer: anytype, progress: f32) !void {
        const filled = @as(f32, @floatFromInt(self.width)) * @min(1.0, @max(0.0, progress));
        const full_blocks = @as(u16, @intFromFloat(filled));
        const partial = @as(usize, @intFromFloat((filled - @as(f32, @floatFromInt(full_blocks))) * 8.0));

        try ANSIRenderer.setFg(writer, self.theme.success);

        for (0..full_blocks) |_| {
            try writer.writeAll("█");
        }

        if (full_blocks < self.width) {
            try writer.writeAll(BLOCKS[partial]);
            try ANSIRenderer.setFg(writer, self.theme.fg_secondary);
            for (0..(self.width - full_blocks - 1)) |_| {
                try writer.writeAll("░");
            }
        }

        try writer.writeAll(ANSIRenderer.RESET);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TABLE RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TableRenderer = struct {
    theme: Theme,

    const Self = @This();

    pub fn init(theme: Theme) Self {
        return Self{ .theme = theme };
    }

    pub fn render(self: *Self, writer: anytype, headers: []const []const u8, rows: []const []const []const u8, widths: []const u16) !void {
        // Header
        try ANSIRenderer.setFg(writer, self.theme.accent);
        try writer.writeAll("╔");
        for (widths, 0..) |w, i| {
            for (0..w + 2) |_| try writer.writeAll("═");
            if (i < widths.len - 1) try writer.writeAll("╤");
        }
        try writer.writeAll("╗\n");

        // Header row
        try writer.writeAll("║");
        for (headers, 0..) |h, i| {
            try writer.writeAll(" ");
            try ANSIRenderer.setFg(writer, self.theme.fg_primary);
            try writer.print("{s: <[1]}", .{ h, widths[i] });
            try ANSIRenderer.setFg(writer, self.theme.accent);
            try writer.writeAll(" │");
        }
        try writer.writeAll("\n");

        // Separator
        try writer.writeAll("╠");
        for (widths, 0..) |w, i| {
            for (0..w + 2) |_| try writer.writeAll("═");
            if (i < widths.len - 1) try writer.writeAll("╪");
        }
        try writer.writeAll("╣\n");

        // Data rows
        for (rows) |row| {
            try writer.writeAll("║");
            for (row, 0..) |cell, i| {
                try writer.writeAll(" ");
                try ANSIRenderer.setFg(writer, self.theme.fg_primary);
                try writer.print("{s: <[1]}", .{ cell, widths[i] });
                try ANSIRenderer.setFg(writer, self.theme.accent);
                try writer.writeAll(" │");
            }
            try writer.writeAll("\n");
        }

        // Footer
        try writer.writeAll("╚");
        for (widths, 0..) |w, i| {
            for (0..w + 2) |_| try writer.writeAll("═");
            if (i < widths.len - 1) try writer.writeAll("╧");
        }
        try writer.writeAll("╝\n");

        try writer.writeAll(ANSIRenderer.RESET);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRO DIFF VIEW
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiffMode = enum { UNIFIED, SIDE_BY_SIDE };

pub const ProDiffView = struct {
    theme: Theme,

    const Self = @This();

    pub fn init(theme: Theme) Self {
        return Self{ .theme = theme };
    }

    pub fn renderHunk(self: *Self, writer: anytype, old_line: ?[]const u8, new_line: ?[]const u8, old_num: u32, new_num: u32) !void {
        // Line numbers
        try ANSIRenderer.setFg(writer, self.theme.fg_secondary);
        if (old_line != null) {
            try writer.print("{d: >4} ", .{old_num});
        } else {
            try writer.writeAll("     ");
        }
        if (new_line != null) {
            try writer.print("{d: >4} ", .{new_num});
        } else {
            try writer.writeAll("     ");
        }

        // Content
        if (old_line == null and new_line != null) {
            // Addition
            try ANSIRenderer.setBg(writer, .{ .r = 30, .g = 60, .b = 30 });
            try ANSIRenderer.setFg(writer, self.theme.diff_add);
            try writer.writeAll("+ ");
            try writer.writeAll(new_line.?);
        } else if (old_line != null and new_line == null) {
            // Deletion
            try ANSIRenderer.setBg(writer, .{ .r = 60, .g = 30, .b = 30 });
            try ANSIRenderer.setFg(writer, self.theme.diff_del);
            try writer.writeAll("- ");
            try writer.writeAll(old_line.?);
        } else if (old_line != null and new_line != null) {
            // Equal
            try ANSIRenderer.setFg(writer, self.theme.fg_primary);
            try writer.writeAll("  ");
            try writer.writeAll(old_line.?);
        }

        try writer.writeAll(ANSIRenderer.RESET);
        try writer.writeAll("\n");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FITTS' LAW CALCULATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub fn fittsTime(distance: f64, width: f64) f64 {
    // T = a + b × log₂(D/W + 1)
    return FITTS_A + FITTS_B * @log2(distance / width + 1.0);
}

pub fn hickTime(choices: u32) f64 {
    // T = b × log₂(n + 1)
    return HICK_B * @log2(@as(f64, @floatFromInt(choices)) + 1.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOUBLE BUFFER RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

pub const DoubleBufferRenderer = struct {
    front: [][]Cell,
    back: [][]Cell,
    width: u16,
    height: u16,
    allocator: Allocator,
    dirty: bool,

    const Self = @This();

    pub fn init(allocator: Allocator, width: u16, height: u16) !Self {
        const front = try allocator.alloc([]Cell, height);
        const back = try allocator.alloc([]Cell, height);

        for (0..height) |i| {
            front[i] = try allocator.alloc(Cell, width);
            back[i] = try allocator.alloc(Cell, width);
            @memset(front[i], Cell{});
            @memset(back[i], Cell{});
        }

        return Self{
            .front = front,
            .back = back,
            .width = width,
            .height = height,
            .allocator = allocator,
            .dirty = true,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.front) |row| self.allocator.free(row);
        for (self.back) |row| self.allocator.free(row);
        self.allocator.free(self.front);
        self.allocator.free(self.back);
    }

    pub fn setCell(self: *Self, x: u16, y: u16, cell: Cell) void {
        if (x < self.width and y < self.height) {
            self.back[y][x] = cell;
            self.dirty = true;
        }
    }

    pub fn render(self: *Self, writer: anytype) !void {
        if (!self.dirty) return;

        var changes: u32 = 0;
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const front_cell = self.front[y][x];
                const back_cell = self.back[y][x];

                if (front_cell.char != back_cell.char or
                    front_cell.fg.r != back_cell.fg.r or
                    front_cell.bg.r != back_cell.bg.r)
                {
                    try ANSIRenderer.moveTo(writer, @intCast(x), @intCast(y));
                    try ANSIRenderer.setFg(writer, back_cell.fg);
                    try ANSIRenderer.setBg(writer, back_cell.bg);

                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(back_cell.char, &buf) catch 1;
                    try writer.writeAll(buf[0..len]);

                    self.front[y][x] = back_cell;
                    changes += 1;
                }
            }
        }

        self.dirty = false;
    }

    pub fn changedCells(self: *Self) u32 {
        var count: u32 = 0;
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                if (self.front[y][x].char != self.back[y][x].char) {
                    count += 1;
                }
            }
        }
        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Benchmark = struct {
    pub fn measureRenderTime(allocator: Allocator, width: u16, height: u16) !struct { time_us: f64, cells: u32, fps: f64 } {
        var buffer = try DoubleBufferRenderer.init(allocator, width, height);
        defer buffer.deinit();

        // Fill with random data
        var prng = std.Random.DefaultPrng.init(PHOENIX);
        for (0..height) |y| {
            for (0..width) |x| {
                buffer.setCell(@intCast(x), @intCast(y), .{
                    .char = 'A' + @as(u21, prng.random().int(u8) % 26),
                    .fg = .{ .r = prng.random().int(u8), .g = prng.random().int(u8), .b = prng.random().int(u8) },
                });
            }
        }

        // Measure render time
        const null_writer = std.io.null_writer;
        const start = std.time.nanoTimestamp();
        try buffer.render(null_writer);
        const end = std.time.nanoTimestamp();

        const time_us = @as(f64, @floatFromInt(end - start)) / 1000.0;
        const cells = @as(u32, width) * @as(u32, height);
        const fps = 1_000_000.0 / time_us;

        return .{ .time_us = time_us, .cells = cells, .fps = fps };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RGB to ANSI" {
    const red = RGB{ .r = 255, .g = 0, .b = 0 };
    const ansi = red.toAnsi();
    try std.testing.expect(ansi[0] == '\x1b');
}

test "Rect contains" {
    const rect = Rect{ .x = 10, .y = 10, .width = 20, .height = 10 };
    try std.testing.expect(rect.contains(15, 15));
    try std.testing.expect(!rect.contains(5, 5));
}

test "BoxStyle chars" {
    const double = BoxStyle.DOUBLE.chars();
    try std.testing.expectEqualStrings("╔", double.tl);
    try std.testing.expectEqualStrings("╗", double.tr);
}

test "Fitts' Law" {
    const time = fittsTime(100.0, 10.0);
    try std.testing.expect(time > 0);
    try std.testing.expect(time < 1000); // Reasonable range
}

test "Hick's Law" {
    const time2 = hickTime(2);
    const time8 = hickTime(8);
    try std.testing.expect(time8 > time2); // More choices = more time
}

test "DoubleBufferRenderer" {
    const allocator = std.testing.allocator;
    var buffer = try DoubleBufferRenderer.init(allocator, 80, 24);
    defer buffer.deinit();

    buffer.setCell(0, 0, .{ .char = 'X' });
    try std.testing.expect(buffer.dirty);
}

test "Benchmark render" {
    const allocator = std.testing.allocator;
    const result = try Benchmark.measureRenderTime(allocator, 80, 24);

    try std.testing.expect(result.time_us > 0);
    try std.testing.expectEqual(@as(u32, 1920), result.cells);

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ UI RENDER BENCHMARK (80x24)                                       ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Cells: {d: >5} | Time: {d: >8.2} µs | FPS: {d: >8.1}              ║\n", .{
        result.cells,
        result.time_us,
        result.fps,
    });
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});
}

test "Golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

test "Phoenix number" {
    try std.testing.expect(PHOENIX == 999);
    try std.testing.expect(999 == 27 * 37);
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// ═══════════════════════════════════════════════════════════════════════════════
