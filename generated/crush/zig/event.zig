// event.zig - Event/Analytics Module
// Generated from: specs/crush/event.vibee
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const builtin = @import("builtin");

/// Event properties
pub const Properties = struct {
    data: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .data = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    pub fn set(self: *Self, key: []const u8, value: []const u8) !*Self {
        try self.data.put(key, value);
        return self;
    }

    pub fn get(self: *Self, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn count(self: *Self) usize {
        return self.data.count();
    }
};

/// Tracked event
pub const TrackedEvent = struct {
    name: []const u8,
    properties: Properties,
    timestamp: i64,
    distinct_id: []const u8,
};

/// Event tracker state
var initialized: bool = false;
var distinct_id: []const u8 = "anonymous";
var non_interactive: bool = false;
var events_sent: usize = 0;

/// Base properties added to all events
pub fn getBaseProperties(allocator: std.mem.Allocator) !Properties {
    var props = Properties.init(allocator);

    // Add system info
    const os_name = switch (builtin.os.tag) {
        .linux => "linux",
        .macos => "darwin",
        .windows => "windows",
        else => "unknown",
    };

    const arch_name = switch (builtin.cpu.arch) {
        .x86_64 => "amd64",
        .aarch64 => "arm64",
        else => "unknown",
    };

    _ = try props.set("OS", os_name);
    _ = try props.set("ARCH", arch_name);
    _ = try props.set("NonInteractive", if (non_interactive) "true" else "false");

    return props;
}

/// Initialize event tracker
pub fn init() void {
    if (initialized) return;

    // Generate or load distinct ID
    distinct_id = "zig-crush-client";
    initialized = true;
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Set non-interactive mode
pub fn setNonInteractive(value: bool) void {
    non_interactive = value;
}

/// Get distinct ID
pub fn getId() []const u8 {
    return distinct_id;
}

/// Send event (stub - would send to analytics service)
pub fn send(event_name: []const u8, props: ?*Properties) void {
    if (!initialized) return;

    _ = event_name;
    _ = props;

    events_sent += 1;
}

/// Track error event
pub fn trackError(err_type: []const u8, err_message: []const u8) void {
    if (!initialized) return;

    _ = err_type;
    _ = err_message;

    events_sent += 1;
}

/// Flush pending events
pub fn flush() void {
    // In real implementation, would flush to analytics service
}

/// Get events sent count
pub fn getEventsSent() usize {
    return events_sent;
}

/// Reset tracker (for testing)
pub fn reset() void {
    initialized = false;
    distinct_id = "anonymous";
    non_interactive = false;
    events_sent = 0;
}

// Tests
test "init" {
    reset();
    init();
    try std.testing.expect(isInitialized());
}

test "get_id" {
    reset();
    init();
    try std.testing.expect(getId().len > 0);
}

test "set_non_interactive" {
    reset();
    setNonInteractive(true);
    try std.testing.expect(non_interactive);
}

test "send_event" {
    reset();
    init();

    send("test_event", null);
    try std.testing.expectEqual(@as(usize, 1), getEventsSent());
}

test "track_error" {
    reset();
    init();

    trackError("TestError", "test message");
    try std.testing.expectEqual(@as(usize, 1), getEventsSent());
}

test "base_properties" {
    const allocator = std.testing.allocator;
    var props = try getBaseProperties(allocator);
    defer props.deinit();

    try std.testing.expect(props.get("OS") != null);
    try std.testing.expect(props.get("ARCH") != null);
}

test "properties_set_get" {
    const allocator = std.testing.allocator;
    var props = Properties.init(allocator);
    defer props.deinit();

    _ = try props.set("key1", "value1");
    _ = try props.set("key2", "value2");

    try std.testing.expectEqualStrings("value1", props.get("key1").?);
    try std.testing.expectEqual(@as(usize, 2), props.count());
}

test "not_initialized_by_default" {
    reset();
    try std.testing.expect(!isInitialized());
}
