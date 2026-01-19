// ═══════════════════════════════════════════════════════════════════════════════
// CIRCUIT BREAKER - Prevents Runaway Loops (Michael Nygard Pattern)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Based on "Release It!" by Michael Nygard
// Prevents infinite loops and token waste in autonomous development
//
// States:
//   CLOSED    - Normal operation, progress detected
//   HALF_OPEN - Monitoring mode, checking for recovery
//   OPEN      - Failure detected, execution halted
//
// PAS DAEMONS: PRE (state persistence), HSH (error fingerprinting)
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// CIRCUIT BREAKER TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const CircuitState = enum {
    closed, // Normal operation
    half_open, // Monitoring mode
    open, // Execution halted

    pub fn toString(self: CircuitState) []const u8 {
        return switch (self) {
            .closed => "CLOSED",
            .half_open => "HALF_OPEN",
            .open => "OPEN",
        };
    }
};

pub const Config = struct {
    no_progress_threshold: u32 = 3, // Open after N loops without progress
    same_error_threshold: u32 = 5, // Open after N loops with same error
    output_decline_threshold: u32 = 70, // Open if output declines by >70%
    recovery_threshold: u32 = 1, // Close after N successful loops in half_open
};

pub const LoopResult = struct {
    loop_number: u32,
    files_changed: u32,
    has_errors: bool,
    output_length: usize,
    error_hash: ?u64 = null,
    tests_passed: bool = false,
};

pub const StateTransition = struct {
    from_state: CircuitState,
    to_state: CircuitState,
    reason: []const u8,
    loop_number: u32,
    timestamp: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CIRCUIT BREAKER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CircuitBreaker = struct {
    allocator: Allocator,
    config: Config,
    state: CircuitState,
    consecutive_no_progress: u32,
    consecutive_same_error: u32,
    last_progress_loop: u32,
    last_error_hash: ?u64,
    last_output_length: usize,
    total_opens: u32,
    current_loop: u32,
    history: std.ArrayList(StateTransition),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .config = Config{},
            .state = .closed,
            .consecutive_no_progress = 0,
            .consecutive_same_error = 0,
            .last_progress_loop = 0,
            .last_error_hash = null,
            .last_output_length = 0,
            .total_opens = 0,
            .current_loop = 0,
            .history = std.ArrayList(StateTransition).init(allocator),
        };
    }

    pub fn initWithConfig(allocator: Allocator, config: Config) Self {
        var cb = init(allocator);
        cb.config = config;
        return cb;
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit();
    }

    /// Check if execution is allowed
    pub fn canExecute(self: *const Self) bool {
        return self.state != .open;
    }

    /// Record loop result and update state
    pub fn recordResult(self: *Self, result: LoopResult) !bool {
        self.current_loop = result.loop_number;

        // Detect progress
        const has_progress = result.files_changed > 0 or result.tests_passed;

        if (has_progress) {
            self.consecutive_no_progress = 0;
            self.last_progress_loop = result.loop_number;
        } else {
            self.consecutive_no_progress += 1;
        }

        // Detect same error repetition
        if (result.has_errors) {
            if (result.error_hash) |hash| {
                if (self.last_error_hash) |last_hash| {
                    if (hash == last_hash) {
                        self.consecutive_same_error += 1;
                    } else {
                        self.consecutive_same_error = 1;
                    }
                } else {
                    self.consecutive_same_error = 1;
                }
                self.last_error_hash = hash;
            }
        } else {
            self.consecutive_same_error = 0;
            self.last_error_hash = null;
        }

        // State transitions
        const old_state = self.state;
        var reason: []const u8 = "";

        switch (self.state) {
            .closed => {
                if (self.consecutive_no_progress >= self.config.no_progress_threshold) {
                    self.state = .open;
                    self.total_opens += 1;
                    reason = "No progress detected";
                } else if (self.consecutive_same_error >= self.config.same_error_threshold) {
                    self.state = .open;
                    self.total_opens += 1;
                    reason = "Same error repeated";
                } else if (self.consecutive_no_progress >= 2) {
                    self.state = .half_open;
                    reason = "Monitoring: possible stagnation";
                }
            },
            .half_open => {
                if (has_progress) {
                    self.state = .closed;
                    reason = "Progress detected, recovered";
                } else if (self.consecutive_no_progress >= self.config.no_progress_threshold) {
                    self.state = .open;
                    self.total_opens += 1;
                    reason = "No recovery, opening circuit";
                }
            },
            .open => {
                // Stay open until manual reset
                reason = "Circuit is open";
            },
        }

        // Record transition if state changed
        if (old_state != self.state) {
            try self.history.append(StateTransition{
                .from_state = old_state,
                .to_state = self.state,
                .reason = reason,
                .loop_number = result.loop_number,
                .timestamp = std.time.timestamp(),
            });
        }

        self.last_output_length = result.output_length;

        return self.state != .open;
    }

    /// Reset circuit breaker to closed state
    pub fn reset(self: *Self) void {
        const old_state = self.state;
        self.state = .closed;
        self.consecutive_no_progress = 0;
        self.consecutive_same_error = 0;
        self.last_error_hash = null;

        if (old_state != .closed) {
            self.history.append(StateTransition{
                .from_state = old_state,
                .to_state = .closed,
                .reason = "Manual reset",
                .loop_number = self.current_loop,
                .timestamp = std.time.timestamp(),
            }) catch {};
        }
    }

    /// Get current state
    pub fn getState(self: *const Self) CircuitState {
        return self.state;
    }

    /// Get statistics
    pub fn getStats(self: *const Self) Stats {
        return Stats{
            .state = self.state,
            .consecutive_no_progress = self.consecutive_no_progress,
            .consecutive_same_error = self.consecutive_same_error,
            .last_progress_loop = self.last_progress_loop,
            .total_opens = self.total_opens,
            .current_loop = self.current_loop,
            .history_count = @intCast(self.history.items.len),
        };
    }

    /// Hash error message for deduplication
    pub fn hashError(error_msg: []const u8) u64 {
        var hash: u64 = 0xcbf29ce484222325; // FNV offset basis
        for (error_msg) |c| {
            hash ^= c;
            hash *%= 0x100000001b3; // FNV prime
        }
        return hash;
    }
};

pub const Stats = struct {
    state: CircuitState,
    consecutive_no_progress: u32,
    consecutive_same_error: u32,
    last_progress_loop: u32,
    total_opens: u32,
    current_loop: u32,
    history_count: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CircuitBreaker: initial state is closed" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    try testing.expectEqual(CircuitState.closed, cb.getState());
    try testing.expect(cb.canExecute());
}

test "CircuitBreaker: stays closed with progress" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    // Loop with progress
    _ = try cb.recordResult(LoopResult{
        .loop_number = 1,
        .files_changed = 2,
        .has_errors = false,
        .output_length = 1000,
    });

    try testing.expectEqual(CircuitState.closed, cb.getState());
    try testing.expectEqual(@as(u32, 0), cb.consecutive_no_progress);
}

test "CircuitBreaker: transitions to half_open after 2 no-progress" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    // 2 loops without progress
    _ = try cb.recordResult(LoopResult{
        .loop_number = 1,
        .files_changed = 0,
        .has_errors = false,
        .output_length = 1000,
    });
    _ = try cb.recordResult(LoopResult{
        .loop_number = 2,
        .files_changed = 0,
        .has_errors = false,
        .output_length = 1000,
    });

    try testing.expectEqual(CircuitState.half_open, cb.getState());
}

test "CircuitBreaker: opens after 3 no-progress" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    // 3 loops without progress
    for (0..3) |i| {
        _ = try cb.recordResult(LoopResult{
            .loop_number = @intCast(i + 1),
            .files_changed = 0,
            .has_errors = false,
            .output_length = 1000,
        });
    }

    try testing.expectEqual(CircuitState.open, cb.getState());
    try testing.expect(!cb.canExecute());
}

test "CircuitBreaker: opens after 5 same errors" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    const error_hash = CircuitBreaker.hashError("compilation error");

    // 5 loops with same error
    for (0..5) |i| {
        _ = try cb.recordResult(LoopResult{
            .loop_number = @intCast(i + 1),
            .files_changed = 1, // Has progress but same error
            .has_errors = true,
            .output_length = 1000,
            .error_hash = error_hash,
        });
    }

    try testing.expectEqual(CircuitState.open, cb.getState());
}

test "CircuitBreaker: recovers from half_open with progress" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    // Get to half_open
    _ = try cb.recordResult(LoopResult{ .loop_number = 1, .files_changed = 0, .has_errors = false, .output_length = 1000 });
    _ = try cb.recordResult(LoopResult{ .loop_number = 2, .files_changed = 0, .has_errors = false, .output_length = 1000 });

    try testing.expectEqual(CircuitState.half_open, cb.getState());

    // Progress detected
    _ = try cb.recordResult(LoopResult{
        .loop_number = 3,
        .files_changed = 1,
        .has_errors = false,
        .output_length = 1000,
    });

    try testing.expectEqual(CircuitState.closed, cb.getState());
}

test "CircuitBreaker: reset works" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    // Get to open state
    for (0..3) |i| {
        _ = try cb.recordResult(LoopResult{
            .loop_number = @intCast(i + 1),
            .files_changed = 0,
            .has_errors = false,
            .output_length = 1000,
        });
    }

    try testing.expectEqual(CircuitState.open, cb.getState());

    // Reset
    cb.reset();

    try testing.expectEqual(CircuitState.closed, cb.getState());
    try testing.expect(cb.canExecute());
}

test "CircuitBreaker: error hashing" {
    const hash1 = CircuitBreaker.hashError("error: type mismatch");
    const hash2 = CircuitBreaker.hashError("error: type mismatch");
    const hash3 = CircuitBreaker.hashError("error: undefined variable");

    try testing.expectEqual(hash1, hash2);
    try testing.expect(hash1 != hash3);
}

test "CircuitBreaker: stats tracking" {
    var cb = CircuitBreaker.init(testing.allocator);
    defer cb.deinit();

    _ = try cb.recordResult(LoopResult{ .loop_number = 1, .files_changed = 1, .has_errors = false, .output_length = 1000 });
    _ = try cb.recordResult(LoopResult{ .loop_number = 2, .files_changed = 0, .has_errors = false, .output_length = 1000 });

    const stats = cb.getStats();
    try testing.expectEqual(@as(u32, 2), stats.current_loop);
    try testing.expectEqual(@as(u32, 1), stats.last_progress_loop);
    try testing.expectEqual(@as(u32, 1), stats.consecutive_no_progress);
}

test "CircuitBreaker: custom config" {
    const config = Config{
        .no_progress_threshold = 5,
        .same_error_threshold = 10,
    };

    var cb = CircuitBreaker.initWithConfig(testing.allocator, config);
    defer cb.deinit();

    // 3 no-progress should NOT open with threshold 5
    for (0..3) |i| {
        _ = try cb.recordResult(LoopResult{
            .loop_number = @intCast(i + 1),
            .files_changed = 0,
            .has_errors = false,
            .output_length = 1000,
        });
    }

    try testing.expect(cb.getState() != .open);
}

test "CircuitState: toString" {
    try testing.expectEqualStrings("CLOSED", CircuitState.closed.toString());
    try testing.expectEqualStrings("HALF_OPEN", CircuitState.half_open.toString());
    try testing.expectEqualStrings("OPEN", CircuitState.open.toString());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const result = phi_sq + phi_inv_sq;
    try testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
