// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC DEBUGGER - BREAKPOINTS, STEPPING, INSPECTION
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V38 - Interactive Debugging with Time-Travel
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: HSH (breakpoint lookup), D&C (state decomposition), PRE (snapshots)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const AutoHashMap = std.AutoHashMap;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

// Debugger Configuration
pub const MAX_BREAKPOINTS: usize = 256;
pub const MAX_SNAPSHOTS: usize = 100;
pub const MAX_WATCH_EXPRESSIONS: usize = 32;

// ═══════════════════════════════════════════════════════════════════════════════
// BREAKPOINT
// ═══════════════════════════════════════════════════════════════════════════════

pub const BreakpointKind = enum {
    line,
    function,
    conditional,
    watchpoint,
};

pub const Breakpoint = struct {
    id: u32,
    kind: BreakpointKind,
    file: []const u8,
    line: u32,
    column: u32,
    condition: ?[]const u8,
    hit_count: u32,
    enabled: bool,

    pub fn matches(self: Breakpoint, file: []const u8, line: u32) bool {
        if (!self.enabled) return false;
        return std.mem.eql(u8, self.file, file) and self.line == line;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BREAKPOINT MANAGER - HSH PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const BreakpointManager = struct {
    allocator: Allocator,
    breakpoints: ArrayList(Breakpoint),
    // HSH: O(1) lookup by file:line
    location_map: AutoHashMap(u64, u32),
    next_id: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .breakpoints = ArrayList(Breakpoint).init(allocator),
            .location_map = AutoHashMap(u64, u32).init(allocator),
            .next_id = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        self.breakpoints.deinit();
        self.location_map.deinit();
    }

    fn hashLocation(file: []const u8, line: u32) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(file);
        hasher.update(std.mem.asBytes(&line));
        return hasher.final();
    }

    pub fn add(self: *Self, file: []const u8, line: u32, condition: ?[]const u8) !u32 {
        const id = self.next_id;
        self.next_id += 1;

        try self.breakpoints.append(.{
            .id = id,
            .kind = if (condition != null) .conditional else .line,
            .file = file,
            .line = line,
            .column = 0,
            .condition = condition,
            .hit_count = 0,
            .enabled = true,
        });

        const hash = hashLocation(file, line);
        try self.location_map.put(hash, id);

        return id;
    }

    pub fn remove(self: *Self, id: u32) bool {
        for (self.breakpoints.items, 0..) |bp, i| {
            if (bp.id == id) {
                const hash = hashLocation(bp.file, bp.line);
                _ = self.location_map.remove(hash);
                _ = self.breakpoints.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn toggle(self: *Self, id: u32) bool {
        for (self.breakpoints.items) |*bp| {
            if (bp.id == id) {
                bp.enabled = !bp.enabled;
                return true;
            }
        }
        return false;
    }

    pub fn check(self: *Self, file: []const u8, line: u32) ?*Breakpoint {
        const hash = hashLocation(file, line);
        if (self.location_map.get(hash)) |id| {
            for (self.breakpoints.items) |*bp| {
                if (bp.id == id and bp.enabled) {
                    bp.hit_count += 1;
                    return bp;
                }
            }
        }
        return null;
    }

    pub fn count(self: *const Self) usize {
        return self.breakpoints.items.len;
    }

    pub fn list(self: *const Self) []const Breakpoint {
        return self.breakpoints.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTION STATE SNAPSHOT - PRE PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const StackValue = struct {
    tag: u8,
    data: i64,
};

pub const Snapshot = struct {
    id: u32,
    ip: u32,
    sp: u32,
    fp: u32,
    stack: []StackValue,
    locals: []StackValue,
    timestamp: i64,

    pub fn deinit(self: *Snapshot, allocator: Allocator) void {
        allocator.free(self.stack);
        allocator.free(self.locals);
    }
};

pub const SnapshotManager = struct {
    allocator: Allocator,
    snapshots: ArrayList(Snapshot),
    next_id: u32,
    max_snapshots: usize,

    const Self = @This();

    pub fn init(allocator: Allocator, max_snapshots: usize) Self {
        return Self{
            .allocator = allocator,
            .snapshots = ArrayList(Snapshot).init(allocator),
            .next_id = 1,
            .max_snapshots = max_snapshots,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.snapshots.items) |*snap| {
            snap.deinit(self.allocator);
        }
        self.snapshots.deinit();
    }

    pub fn capture(self: *Self, ip: u32, sp: u32, fp: u32, stack: []const StackValue, locals: []const StackValue) !u32 {
        // Remove oldest if at max
        if (self.snapshots.items.len >= self.max_snapshots) {
            var old = self.snapshots.orderedRemove(0);
            old.deinit(self.allocator);
        }

        const id = self.next_id;
        self.next_id += 1;

        const stack_copy = try self.allocator.dupe(StackValue, stack);
        const locals_copy = try self.allocator.dupe(StackValue, locals);

        try self.snapshots.append(.{
            .id = id,
            .ip = ip,
            .sp = sp,
            .fp = fp,
            .stack = stack_copy,
            .locals = locals_copy,
            .timestamp = std.time.milliTimestamp(),
        });

        return id;
    }

    pub fn get(self: *const Self, id: u32) ?*const Snapshot {
        for (self.snapshots.items) |*snap| {
            if (snap.id == id) return snap;
        }
        return null;
    }

    pub fn latest(self: *const Self) ?*const Snapshot {
        if (self.snapshots.items.len == 0) return null;
        return &self.snapshots.items[self.snapshots.items.len - 1];
    }

    pub fn count(self: *const Self) usize {
        return self.snapshots.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STEP MODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const StepMode = enum {
    none,
    step_into,
    step_over,
    step_out,
    step_back,
    run_to_cursor,
};

// ═══════════════════════════════════════════════════════════════════════════════
// WATCH EXPRESSION
// ═══════════════════════════════════════════════════════════════════════════════

pub const WatchExpression = struct {
    id: u32,
    expression: []const u8,
    last_value: ?[]const u8,
    enabled: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEBUGGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Debugger = struct {
    allocator: Allocator,
    breakpoints: BreakpointManager,
    snapshots: SnapshotManager,
    watches: ArrayList(WatchExpression),

    // State
    paused: bool,
    step_mode: StepMode,
    step_depth: u32,
    current_file: []const u8,
    current_line: u32,

    // Metrics
    breakpoints_hit: u64,
    steps_executed: u64,
    snapshots_taken: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .breakpoints = BreakpointManager.init(allocator),
            .snapshots = SnapshotManager.init(allocator, MAX_SNAPSHOTS),
            .watches = ArrayList(WatchExpression).init(allocator),
            .paused = false,
            .step_mode = .none,
            .step_depth = 0,
            .current_file = "",
            .current_line = 0,
            .breakpoints_hit = 0,
            .steps_executed = 0,
            .snapshots_taken = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.breakpoints.deinit();
        self.snapshots.deinit();
        self.watches.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BREAKPOINT COMMANDS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn setBreakpoint(self: *Self, file: []const u8, line: u32) !u32 {
        return self.breakpoints.add(file, line, null);
    }

    pub fn setConditionalBreakpoint(self: *Self, file: []const u8, line: u32, condition: []const u8) !u32 {
        return self.breakpoints.add(file, line, condition);
    }

    pub fn removeBreakpoint(self: *Self, id: u32) bool {
        return self.breakpoints.remove(id);
    }

    pub fn toggleBreakpoint(self: *Self, id: u32) bool {
        return self.breakpoints.toggle(id);
    }

    pub fn clearAllBreakpoints(self: *Self) void {
        self.breakpoints.breakpoints.clearRetainingCapacity();
        self.breakpoints.location_map.clearRetainingCapacity();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STEPPING COMMANDS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn stepInto(self: *Self) void {
        self.step_mode = .step_into;
        self.paused = false;
    }

    pub fn stepOver(self: *Self, current_depth: u32) void {
        self.step_mode = .step_over;
        self.step_depth = current_depth;
        self.paused = false;
    }

    pub fn stepOut(self: *Self, current_depth: u32) void {
        self.step_mode = .step_out;
        self.step_depth = current_depth;
        self.paused = false;
    }

    pub fn stepBack(self: *Self) bool {
        if (self.snapshots.count() == 0) return false;
        self.step_mode = .step_back;
        return true;
    }

    pub fn continueExecution(self: *Self) void {
        self.step_mode = .none;
        self.paused = false;
    }

    pub fn pause(self: *Self) void {
        self.paused = true;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXECUTION HOOK
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn onInstruction(self: *Self, file: []const u8, line: u32, call_depth: u32) bool {
        self.current_file = file;
        self.current_line = line;
        self.steps_executed += 1;

        // Check breakpoints
        if (self.breakpoints.check(file, line)) |_| {
            self.breakpoints_hit += 1;
            self.paused = true;
            return true;
        }

        // Check step mode
        switch (self.step_mode) {
            .step_into => {
                self.paused = true;
                return true;
            },
            .step_over => {
                if (call_depth <= self.step_depth) {
                    self.paused = true;
                    return true;
                }
            },
            .step_out => {
                if (call_depth < self.step_depth) {
                    self.paused = true;
                    return true;
                }
            },
            else => {},
        }

        return self.paused;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SNAPSHOT COMMANDS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn takeSnapshot(self: *Self, ip: u32, sp: u32, fp: u32, stack: []const StackValue, locals: []const StackValue) !u32 {
        self.snapshots_taken += 1;
        return self.snapshots.capture(ip, sp, fp, stack, locals);
    }

    pub fn getSnapshot(self: *const Self, id: u32) ?*const Snapshot {
        return self.snapshots.get(id);
    }

    pub fn getLatestSnapshot(self: *const Self) ?*const Snapshot {
        return self.snapshots.latest();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WATCH EXPRESSIONS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn addWatch(self: *Self, expression: []const u8) !u32 {
        const id: u32 = @intCast(self.watches.items.len + 1);
        try self.watches.append(.{
            .id = id,
            .expression = expression,
            .last_value = null,
            .enabled = true,
        });
        return id;
    }

    pub fn removeWatch(self: *Self, id: u32) bool {
        for (self.watches.items, 0..) |watch, i| {
            if (watch.id == id) {
                _ = self.watches.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // METRICS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn getMetrics(self: *const Self) DebuggerMetrics {
        return .{
            .breakpoints_count = self.breakpoints.count(),
            .breakpoints_hit = self.breakpoints_hit,
            .steps_executed = self.steps_executed,
            .snapshots_count = self.snapshots.count(),
            .snapshots_taken = self.snapshots_taken,
            .watches_count = self.watches.items.len,
        };
    }
};

pub const DebuggerMetrics = struct {
    breakpoints_count: usize,
    breakpoints_hit: u64,
    steps_executed: u64,
    snapshots_count: usize,
    snapshots_taken: u64,
    watches_count: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BreakpointManager basic" {
    const allocator = std.testing.allocator;
    var mgr = BreakpointManager.init(allocator);
    defer mgr.deinit();

    const id = try mgr.add("test.vibee", 10, null);
    try std.testing.expectEqual(@as(u32, 1), id);
    try std.testing.expectEqual(@as(usize, 1), mgr.count());

    const bp = mgr.check("test.vibee", 10);
    try std.testing.expect(bp != null);
    try std.testing.expectEqual(@as(u32, 1), bp.?.hit_count);
}

test "BreakpointManager toggle" {
    const allocator = std.testing.allocator;
    var mgr = BreakpointManager.init(allocator);
    defer mgr.deinit();

    const id = try mgr.add("test.vibee", 10, null);

    // Initially enabled
    try std.testing.expect(mgr.check("test.vibee", 10) != null);

    // Toggle off
    try std.testing.expect(mgr.toggle(id));
    try std.testing.expect(mgr.check("test.vibee", 10) == null);

    // Toggle on
    try std.testing.expect(mgr.toggle(id));
    try std.testing.expect(mgr.check("test.vibee", 10) != null);
}

test "SnapshotManager" {
    const allocator = std.testing.allocator;
    var mgr = SnapshotManager.init(allocator, 5);
    defer mgr.deinit();

    const stack = [_]StackValue{.{ .tag = 1, .data = 42 }};
    const locals = [_]StackValue{.{ .tag = 2, .data = 100 }};

    const id = try mgr.capture(0, 1, 0, &stack, &locals);
    try std.testing.expectEqual(@as(u32, 1), id);

    const snap = mgr.get(id);
    try std.testing.expect(snap != null);
    try std.testing.expectEqual(@as(u32, 0), snap.?.ip);
}

test "Debugger stepping" {
    const allocator = std.testing.allocator;
    var dbg = Debugger.init(allocator);
    defer dbg.deinit();

    // Set breakpoint
    _ = try dbg.setBreakpoint("test.vibee", 5);

    // Should pause at breakpoint
    const should_pause = dbg.onInstruction("test.vibee", 5, 0);
    try std.testing.expect(should_pause);
    try std.testing.expect(dbg.paused);

    // Step into
    dbg.stepInto();
    try std.testing.expect(!dbg.paused);

    // Should pause on next instruction
    const should_pause2 = dbg.onInstruction("test.vibee", 6, 0);
    try std.testing.expect(should_pause2);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
