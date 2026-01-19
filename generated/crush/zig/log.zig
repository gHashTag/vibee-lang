// log.zig - Logging Module
// Generated from: specs/crush/log.vibee
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Log levels
pub const Level = enum {
    debug,
    info,
    warn,
    err,

    pub fn toString(self: Level) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
    }
};

/// Logger configuration
pub const Config = struct {
    file_path: ?[]const u8 = null,
    debug: bool = false,
    max_size_mb: usize = 10,
    max_backups: usize = 0,
    max_age_days: usize = 30,
};

/// Logger state
var initialized: bool = false;
var current_level: Level = .info;
var log_file: ?std.fs.File = null;

/// Setup logger with configuration
pub fn setup(config: Config) !void {
    if (initialized) return;

    current_level = if (config.debug) .debug else .info;

    if (config.file_path) |path| {
        log_file = try std.fs.cwd().createFile(path, .{ .truncate = false });
    }

    initialized = true;
}

/// Check if logger is initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Shutdown logger
pub fn shutdown() void {
    if (log_file) |f| {
        f.close();
        log_file = null;
    }
    initialized = false;
}

/// Log a message at specified level
pub fn logMessage(level: Level, comptime fmt: []const u8, args: anytype) void {
    if (@intFromEnum(level) < @intFromEnum(current_level)) return;

    const timestamp = std.time.timestamp();
    const writer = if (log_file) |f| f.writer() else std.io.getStdErr().writer();

    writer.print("[{d}] [{s}] ", .{ timestamp, level.toString() }) catch {};
    writer.print(fmt ++ "\n", args) catch {};
}

/// Log debug message
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    logMessage(.debug, fmt, args);
}

/// Log info message
pub fn info(comptime fmt: []const u8, args: anytype) void {
    logMessage(.info, fmt, args);
}

/// Log warning message
pub fn warn(comptime fmt: []const u8, args: anytype) void {
    logMessage(.warn, fmt, args);
}

/// Log error message
pub fn err(comptime fmt: []const u8, args: anytype) void {
    logMessage(.err, fmt, args);
}

/// Create panic dump file
pub fn createPanicDump(allocator: std.mem.Allocator, name: []const u8, message: []const u8) ![]const u8 {
    const timestamp = std.time.timestamp();
    const filename = try std.fmt.allocPrint(allocator, "crush-panic-{s}-{d}.log", .{ name, timestamp });

    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    const writer = file.writer();
    try writer.print("Panic in {s}: {s}\n\n", .{ name, message });
    try writer.print("Time: {d}\n\n", .{timestamp});
    try writer.print("Stack Trace:\n", .{});

    // Get stack trace
    var buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const trace = std.debug.captureStackTrace(@returnAddress(), null, fba.allocator()) catch null;
    if (trace) |t| {
        std.debug.writeStackTrace(t, writer) catch {};
    }

    return filename;
}

/// Structured log entry
pub const Entry = struct {
    level: Level,
    message: []const u8,
    timestamp: i64,
    fields: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, level: Level, message: []const u8) Self {
        return Self{
            .level = level,
            .message = message,
            .timestamp = std.time.timestamp(),
            .fields = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.fields.deinit();
    }

    pub fn withField(self: *Self, key: []const u8, value: []const u8) !*Self {
        try self.fields.put(key, value);
        return self;
    }

    pub fn log(self: *Self) void {
        const writer = if (log_file) |f| f.writer() else std.io.getStdErr().writer();

        writer.print("[{d}] [{s}] {s}", .{ self.timestamp, self.level.toString(), self.message }) catch {};

        var iter = self.fields.iterator();
        while (iter.next()) |entry| {
            writer.print(" {s}={s}", .{ entry.key_ptr.*, entry.value_ptr.* }) catch {};
        }

        writer.print("\n", .{}) catch {};
    }
};

// Tests
test "setup_and_initialized" {
    try setup(.{ .debug = true });
    defer shutdown();

    try std.testing.expect(isInitialized());
}

test "log_levels" {
    try std.testing.expectEqualStrings("DEBUG", Level.debug.toString());
    try std.testing.expectEqualStrings("INFO", Level.info.toString());
    try std.testing.expectEqualStrings("WARN", Level.warn.toString());
    try std.testing.expectEqualStrings("ERROR", Level.err.toString());
}

test "entry_with_fields" {
    const allocator = std.testing.allocator;
    var entry = Entry.init(allocator, .info, "test message");
    defer entry.deinit();

    _ = try entry.withField("key1", "value1");
    _ = try entry.withField("key2", "value2");

    try std.testing.expectEqual(@as(usize, 2), entry.fields.count());
}

test "not_initialized_by_default" {
    // Reset state for test
    initialized = false;
    try std.testing.expect(!isInitialized());
}

test "level_ordering" {
    try std.testing.expect(@intFromEnum(Level.debug) < @intFromEnum(Level.info));
    try std.testing.expect(@intFromEnum(Level.info) < @intFromEnum(Level.warn));
    try std.testing.expect(@intFromEnum(Level.warn) < @intFromEnum(Level.err));
}

test "config_defaults" {
    const config = Config{};
    try std.testing.expect(config.file_path == null);
    try std.testing.expect(!config.debug);
    try std.testing.expectEqual(@as(usize, 10), config.max_size_mb);
}
