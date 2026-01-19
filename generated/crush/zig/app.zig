// app.zig - Application Module
// Generated from: crush/internal/app
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Application state
pub const State = enum {
    starting,
    running,
    paused,
    stopping,
    stopped,

    pub fn toString(self: State) []const u8 {
        return switch (self) {
            .starting => "starting",
            .running => "running",
            .paused => "paused",
            .stopping => "stopping",
            .stopped => "stopped",
        };
    }
};

/// Application configuration
pub const Config = struct {
    name: []const u8,
    version: []const u8,
    debug: bool = false,
    log_file: ?[]const u8 = null,
    data_dir: ?[]const u8 = null,
};

/// Application context
pub const Context = struct {
    config: Config,
    state: State,
    start_time: i64,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: Config) Self {
        return Self{
            .config = config,
            .state = .stopped,
            .start_time = 0,
            .allocator = allocator,
        };
    }

    pub fn start(self: *Self) void {
        self.state = .starting;
        self.start_time = std.time.milliTimestamp();
        self.state = .running;
    }

    pub fn stop(self: *Self) void {
        self.state = .stopping;
        self.state = .stopped;
    }

    pub fn pause(self: *Self) void {
        if (self.state == .running) {
            self.state = .paused;
        }
    }

    pub fn resume_(self: *Self) void {
        if (self.state == .paused) {
            self.state = .running;
        }
    }

    pub fn isRunning(self: *Self) bool {
        return self.state == .running;
    }

    pub fn uptime(self: *Self) i64 {
        if (self.start_time == 0) return 0;
        return std.time.milliTimestamp() - self.start_time;
    }
};

/// Application builder
pub const Builder = struct {
    name: []const u8 = "app",
    version: []const u8 = "0.0.0",
    debug: bool = false,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn withName(self: *Self, name: []const u8) *Self {
        self.name = name;
        return self;
    }

    pub fn withVersion(self: *Self, version: []const u8) *Self {
        self.version = version;
        return self;
    }

    pub fn withDebug(self: *Self, debug: bool) *Self {
        self.debug = debug;
        return self;
    }

    pub fn build(self: *Self) Context {
        return Context.init(self.allocator, Config{
            .name = self.name,
            .version = self.version,
            .debug = self.debug,
        });
    }
};

// Tests
test "state_to_string" {
    try std.testing.expectEqualStrings("running", State.running.toString());
    try std.testing.expectEqualStrings("stopped", State.stopped.toString());
}

test "context_init" {
    const allocator = std.testing.allocator;
    const ctx = Context.init(allocator, Config{
        .name = "test",
        .version = "1.0.0",
    });

    try std.testing.expectEqual(State.stopped, ctx.state);
    try std.testing.expectEqualStrings("test", ctx.config.name);
}

test "context_lifecycle" {
    const allocator = std.testing.allocator;
    var ctx = Context.init(allocator, Config{
        .name = "test",
        .version = "1.0.0",
    });

    ctx.start();
    try std.testing.expect(ctx.isRunning());

    ctx.pause();
    try std.testing.expectEqual(State.paused, ctx.state);

    ctx.resume_();
    try std.testing.expect(ctx.isRunning());

    ctx.stop();
    try std.testing.expectEqual(State.stopped, ctx.state);
}

test "context_uptime" {
    const allocator = std.testing.allocator;
    var ctx = Context.init(allocator, Config{
        .name = "test",
        .version = "1.0.0",
    });

    try std.testing.expectEqual(@as(i64, 0), ctx.uptime());

    ctx.start();
    std.time.sleep(10 * std.time.ns_per_ms);
    try std.testing.expect(ctx.uptime() >= 10);
}

test "builder" {
    const allocator = std.testing.allocator;
    var builder = Builder.init(allocator);
    _ = builder.withName("myapp").withVersion("2.0.0").withDebug(true);

    const ctx = builder.build();
    try std.testing.expectEqualStrings("myapp", ctx.config.name);
    try std.testing.expectEqualStrings("2.0.0", ctx.config.version);
    try std.testing.expect(ctx.config.debug);
}
