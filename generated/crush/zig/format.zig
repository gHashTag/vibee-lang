// format.zig - Spinner Animation Module
// Generated from: specs/crush/format.vibee via generated/crush/tri/format.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

/// Animation frame for spinner
pub const Frame = struct {
    chars: []const u8,
    duration_ms: u32,
};

/// Default spinner frames (dots animation)
pub const default_frames = [_]Frame{
    .{ .chars = "⠋", .duration_ms = 80 },
    .{ .chars = "⠙", .duration_ms = 80 },
    .{ .chars = "⠹", .duration_ms = 80 },
    .{ .chars = "⠸", .duration_ms = 80 },
    .{ .chars = "⠼", .duration_ms = 80 },
    .{ .chars = "⠴", .duration_ms = 80 },
    .{ .chars = "⠦", .duration_ms = 80 },
    .{ .chars = "⠧", .duration_ms = 80 },
    .{ .chars = "⠇", .duration_ms = 80 },
    .{ .chars = "⠏", .duration_ms = 80 },
};

/// Animation settings
pub const Settings = struct {
    frames: []const Frame = &default_frames,
    message: []const u8 = "",
    show_elapsed: bool = false,
};

/// Spinner state
pub const SpinnerState = enum {
    idle,
    running,
    stopped,
};

/// Spinner wraps animation for non-interactive mode
/// Creation Pattern: AnimationSettings → SpinnerEngine → TerminalAnimation
pub const Spinner = struct {
    settings: Settings,
    state: SpinnerState,
    current_frame: usize,
    start_time: ?i64,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new spinner with given settings
    pub fn init(allocator: std.mem.Allocator, settings: Settings) Self {
        return Self{
            .settings = settings,
            .state = .idle,
            .current_frame = 0,
            .start_time = null,
            .allocator = allocator,
        };
    }

    /// Start the spinner animation
    pub fn start(self: *Self) void {
        self.state = .running;
        self.start_time = std.time.milliTimestamp();
        self.current_frame = 0;
    }

    /// Stop the spinner animation
    pub fn stop(self: *Self) void {
        self.state = .stopped;
    }

    /// Get current frame to display
    pub fn currentFrame(self: *const Self) []const u8 {
        if (self.settings.frames.len == 0) return "";
        return self.settings.frames[self.current_frame].chars;
    }

    /// Advance to next frame
    pub fn tick(self: *Self) void {
        if (self.state != .running) return;
        self.current_frame = (self.current_frame + 1) % self.settings.frames.len;
    }

    /// Get elapsed time in milliseconds
    pub fn elapsedMs(self: *const Self) ?i64 {
        if (self.start_time) |start_ts| {
            return std.time.milliTimestamp() - start_ts;
        }
        return null;
    }

    /// Render current view
    pub fn view(self: *const Self, writer: anytype) !void {
        if (self.state == .stopped) return;

        try writer.writeAll(self.currentFrame());

        if (self.settings.message.len > 0) {
            try writer.writeAll(" ");
            try writer.writeAll(self.settings.message);
        }

        if (self.settings.show_elapsed) {
            if (self.elapsedMs()) |ms| {
                try writer.print(" ({d}ms)", .{ms});
            }
        }
    }

    /// Check if spinner is running
    pub fn isRunning(self: *const Self) bool {
        return self.state == .running;
    }
};

/// ANSI escape sequence to erase entire line
pub const ERASE_LINE = "\x1b[2K\r";

/// Clear the current line (used when spinner stops)
pub fn clearLine(writer: anytype) !void {
    try writer.writeAll(ERASE_LINE);
}

// Tests
test "spinner_init" {
    const allocator = std.testing.allocator;
    const settings = Settings{ .message = "Loading..." };
    const spinner = Spinner.init(allocator, settings);

    try std.testing.expectEqual(SpinnerState.idle, spinner.state);
    try std.testing.expectEqualStrings("Loading...", spinner.settings.message);
}

test "spinner_start_stop" {
    const allocator = std.testing.allocator;
    var spinner = Spinner.init(allocator, .{});

    spinner.start();
    try std.testing.expectEqual(SpinnerState.running, spinner.state);
    try std.testing.expect(spinner.start_time != null);

    spinner.stop();
    try std.testing.expectEqual(SpinnerState.stopped, spinner.state);
}

test "spinner_tick" {
    const allocator = std.testing.allocator;
    var spinner = Spinner.init(allocator, .{});

    spinner.start();
    try std.testing.expectEqual(@as(usize, 0), spinner.current_frame);

    spinner.tick();
    try std.testing.expectEqual(@as(usize, 1), spinner.current_frame);

    // Tick through all frames
    for (0..default_frames.len - 1) |_| {
        spinner.tick();
    }
    try std.testing.expectEqual(@as(usize, 0), spinner.current_frame); // Wrapped around
}

test "spinner_view" {
    const allocator = std.testing.allocator;
    var spinner = Spinner.init(allocator, .{ .message = "Test" });

    spinner.start();

    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try spinner.view(stream.writer());

    const output = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "Test") != null);
}

test "spinner_idle_no_tick" {
    const allocator = std.testing.allocator;
    var spinner = Spinner.init(allocator, .{});

    // Tick while idle should not advance frame
    spinner.tick();
    try std.testing.expectEqual(@as(usize, 0), spinner.current_frame);
}

test "clearLine" {
    var buf: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try clearLine(stream.writer());

    try std.testing.expectEqualStrings(ERASE_LINE, stream.getWritten());
}
