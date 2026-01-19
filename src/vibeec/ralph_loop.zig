// ═══════════════════════════════════════════════════════════════════════════════
// RALPH LOOP - Autonomous Development Loop with Intelligent Exit Detection
// ═══════════════════════════════════════════════════════════════════════════════
//
// Based on: https://github.com/frankbria/ralph-claude-code
// Pattern: Autonomous AI development with intelligent exit detection
//
// Components:
//   - Response Analyzer: Exit signal detection, confidence scoring
//   - Circuit Breaker: Prevents runaway loops (Michael Nygard pattern)
//   - Rate Limiter: API call management
//
// PAS DAEMONS: PRE (caching), HSH (deduplication), MLS (exit detection)
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const circuit_breaker = @import("circuit_breaker.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LoopState = enum {
    idle,
    analyzing,
    specifying,
    generating,
    testing,
    iterating,
    completed,
    failed,

    pub fn toString(self: LoopState) []const u8 {
        return switch (self) {
            .idle => "IDLE",
            .analyzing => "ANALYZING",
            .specifying => "SPECIFYING",
            .generating => "GENERATING",
            .testing => "TESTING",
            .iterating => "ITERATING",
            .completed => "COMPLETED",
            .failed => "FAILED",
        };
    }
};

pub const ExitCondition = enum {
    none,
    tests_passing,
    max_iterations,
    circuit_open,
    user_interrupt,
    explicit_signal,

    pub fn toString(self: ExitCondition) []const u8 {
        return switch (self) {
            .none => "NONE",
            .tests_passing => "TESTS_PASSING",
            .max_iterations => "MAX_ITERATIONS",
            .circuit_open => "CIRCUIT_OPEN",
            .user_interrupt => "USER_INTERRUPT",
            .explicit_signal => "EXPLICIT_SIGNAL",
        };
    }
};

pub const LoopConfig = struct {
    max_iterations: u32 = 10,
    confidence_threshold: u32 = 40,
    enable_circuit_breaker: bool = true,
    enable_rate_limiting: bool = true,
    rate_limit_per_hour: u32 = 100,
};

pub const IterationResult = struct {
    iteration: u32,
    state: LoopState,
    files_changed: u32,
    tests_run: u32,
    tests_passed: u32,
    errors: u32,
    confidence: u32,
    exit_signal: bool,
    duration_ms: u64,
};

pub const LoopResult = struct {
    state: LoopState,
    exit_condition: ExitCondition,
    iterations: u32,
    total_files_changed: u32,
    total_tests_run: u32,
    total_tests_passed: u32,
    total_errors: u32,
    total_duration_ms: u64,
    circuit_breaker_opens: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// RESPONSE ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ResponseAnalyzer = struct {
    allocator: Allocator,
    completion_keywords: []const []const u8,
    test_patterns: []const []const u8,
    no_work_patterns: []const []const u8,

    const Self = @This();

    const default_completion_keywords = [_][]const u8{
        "done",
        "complete",
        "finished",
        "all tasks complete",
        "project complete",
        "ready for review",
        "EXIT_SIGNAL: true",
    };

    const default_test_patterns = [_][]const u8{
        "zig test",
        "All tests passed",
        "tests passed",
        "OK",
    };

    const default_no_work_patterns = [_][]const u8{
        "nothing to do",
        "no changes",
        "already implemented",
        "up to date",
    };

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .completion_keywords = &default_completion_keywords,
            .test_patterns = &default_test_patterns,
            .no_work_patterns = &default_no_work_patterns,
        };
    }

    pub fn analyze(self: *const Self, output: []const u8) AnalysisResult {
        var result = AnalysisResult{};

        // Check for explicit EXIT_SIGNAL
        if (std.mem.indexOf(u8, output, "EXIT_SIGNAL: true") != null) {
            result.exit_signal = true;
            result.confidence = 100;
            result.has_completion_signal = true;
            return result;
        }

        // Check completion keywords
        for (self.completion_keywords) |keyword| {
            if (containsIgnoreCase(output, keyword)) {
                result.has_completion_signal = true;
                result.confidence += 10;
                break;
            }
        }

        // Check test patterns
        for (self.test_patterns) |pattern| {
            if (std.mem.indexOf(u8, output, pattern) != null) {
                result.tests_detected = true;
                result.confidence += 15;
                break;
            }
        }

        // Check "All tests passed"
        if (std.mem.indexOf(u8, output, "All") != null and
            std.mem.indexOf(u8, output, "passed") != null)
        {
            result.tests_passed = true;
            result.confidence += 30;
        }

        // Check no work patterns
        for (self.no_work_patterns) |pattern| {
            if (containsIgnoreCase(output, pattern)) {
                result.no_work_remaining = true;
                result.confidence += 20;
                break;
            }
        }

        // Determine exit signal based on confidence
        if (result.confidence >= 40 or result.has_completion_signal) {
            result.exit_signal = true;
        }

        return result;
    }

    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len > haystack.len) return false;

        var i: usize = 0;
        while (i <= haystack.len - needle.len) : (i += 1) {
            var match = true;
            for (needle, 0..) |c, j| {
                const h = haystack[i + j];
                if (std.ascii.toLower(c) != std.ascii.toLower(h)) {
                    match = false;
                    break;
                }
            }
            if (match) return true;
        }
        return false;
    }
};

pub const AnalysisResult = struct {
    exit_signal: bool = false,
    has_completion_signal: bool = false,
    tests_detected: bool = false,
    tests_passed: bool = false,
    no_work_remaining: bool = false,
    confidence: u32 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// RALPH LOOP
// ═══════════════════════════════════════════════════════════════════════════════

pub const RalphLoop = struct {
    allocator: Allocator,
    config: LoopConfig,
    state: LoopState,
    iteration: u32,
    circuit: circuit_breaker.CircuitBreaker,
    analyzer: ResponseAnalyzer,
    exit_condition: ExitCondition,
    // Metrics
    total_files_changed: u32,
    total_tests_run: u32,
    total_tests_passed: u32,
    total_errors: u32,
    total_duration_ms: u64,
    api_calls_this_hour: u32,
    hour_start: i64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .config = LoopConfig{},
            .state = .idle,
            .iteration = 0,
            .circuit = circuit_breaker.CircuitBreaker.init(allocator),
            .analyzer = ResponseAnalyzer.init(allocator),
            .exit_condition = .none,
            .total_files_changed = 0,
            .total_tests_run = 0,
            .total_tests_passed = 0,
            .total_errors = 0,
            .total_duration_ms = 0,
            .api_calls_this_hour = 0,
            .hour_start = std.time.timestamp(),
        };
    }

    pub fn initWithConfig(allocator: Allocator, config: LoopConfig) Self {
        var loop = init(allocator);
        loop.config = config;
        return loop;
    }

    pub fn deinit(self: *Self) void {
        self.circuit.deinit();
    }

    /// Check if loop can continue
    pub fn canContinue(self: *Self) bool {
        // Check circuit breaker
        if (self.config.enable_circuit_breaker and !self.circuit.canExecute()) {
            self.exit_condition = .circuit_open;
            self.state = .failed;
            return false;
        }

        // Check max iterations
        if (self.iteration >= self.config.max_iterations) {
            self.exit_condition = .max_iterations;
            self.state = .failed;
            return false;
        }

        // Check rate limiting
        if (self.config.enable_rate_limiting) {
            const now = std.time.timestamp();
            if (now - self.hour_start >= 3600) {
                // Reset hourly counter
                self.hour_start = now;
                self.api_calls_this_hour = 0;
            }
            if (self.api_calls_this_hour >= self.config.rate_limit_per_hour) {
                return false;
            }
        }

        return self.state != .completed and self.state != .failed;
    }

    /// Process iteration result
    pub fn processIteration(self: *Self, result: IterationResult) !void {
        self.iteration = result.iteration;
        self.state = result.state;
        self.total_files_changed += result.files_changed;
        self.total_tests_run += result.tests_run;
        self.total_tests_passed += result.tests_passed;
        self.total_errors += result.errors;
        self.total_duration_ms += result.duration_ms;
        self.api_calls_this_hour += 1;

        // Update circuit breaker
        if (self.config.enable_circuit_breaker) {
            _ = try self.circuit.recordResult(circuit_breaker.LoopResult{
                .loop_number = result.iteration,
                .files_changed = result.files_changed,
                .has_errors = result.errors > 0,
                .output_length = 0,
                .tests_passed = result.tests_passed == result.tests_run and result.tests_run > 0,
            });
        }

        // Check exit signal
        if (result.exit_signal) {
            if (result.tests_passed == result.tests_run and result.tests_run > 0) {
                self.exit_condition = .tests_passing;
                self.state = .completed;
            } else {
                self.exit_condition = .explicit_signal;
                self.state = .completed;
            }
        }
    }

    /// Analyze output and determine if should exit
    pub fn analyzeOutput(self: *Self, output: []const u8) AnalysisResult {
        return self.analyzer.analyze(output);
    }

    /// Get final result
    pub fn getResult(self: *const Self) LoopResult {
        return LoopResult{
            .state = self.state,
            .exit_condition = self.exit_condition,
            .iterations = self.iteration,
            .total_files_changed = self.total_files_changed,
            .total_tests_run = self.total_tests_run,
            .total_tests_passed = self.total_tests_passed,
            .total_errors = self.total_errors,
            .total_duration_ms = self.total_duration_ms,
            .circuit_breaker_opens = self.circuit.total_opens,
        };
    }

    /// Reset loop for new task
    pub fn reset(self: *Self) void {
        self.state = .idle;
        self.iteration = 0;
        self.exit_condition = .none;
        self.total_files_changed = 0;
        self.total_tests_run = 0;
        self.total_tests_passed = 0;
        self.total_errors = 0;
        self.total_duration_ms = 0;
        self.circuit.reset();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RalphLoop: initial state" {
    var loop = RalphLoop.init(testing.allocator);
    defer loop.deinit();

    try testing.expectEqual(LoopState.idle, loop.state);
    try testing.expectEqual(@as(u32, 0), loop.iteration);
    try testing.expect(loop.canContinue());
}

test "RalphLoop: processes iteration" {
    var loop = RalphLoop.init(testing.allocator);
    defer loop.deinit();

    try loop.processIteration(IterationResult{
        .iteration = 1,
        .state = .testing,
        .files_changed = 2,
        .tests_run = 5,
        .tests_passed = 5,
        .errors = 0,
        .confidence = 80,
        .exit_signal = false,
        .duration_ms = 1000,
    });

    try testing.expectEqual(@as(u32, 1), loop.iteration);
    try testing.expectEqual(@as(u32, 2), loop.total_files_changed);
    try testing.expectEqual(@as(u32, 5), loop.total_tests_passed);
}

test "RalphLoop: exits on tests passing" {
    var loop = RalphLoop.init(testing.allocator);
    defer loop.deinit();

    try loop.processIteration(IterationResult{
        .iteration = 1,
        .state = .testing,
        .files_changed = 1,
        .tests_run = 3,
        .tests_passed = 3,
        .errors = 0,
        .confidence = 100,
        .exit_signal = true,
        .duration_ms = 500,
    });

    try testing.expectEqual(LoopState.completed, loop.state);
    try testing.expectEqual(ExitCondition.tests_passing, loop.exit_condition);
}

test "RalphLoop: respects max iterations" {
    const config = LoopConfig{
        .max_iterations = 3,
        .enable_circuit_breaker = false, // Disable to test max_iterations
    };
    var loop = RalphLoop.initWithConfig(testing.allocator, config);
    defer loop.deinit();

    // Simulate 3 iterations with progress (to avoid circuit breaker)
    for (0..3) |i| {
        try loop.processIteration(IterationResult{
            .iteration = @intCast(i + 1),
            .state = .testing,
            .files_changed = 1, // Has progress
            .tests_run = 1,
            .tests_passed = 0,
            .errors = 1,
            .confidence = 0,
            .exit_signal = false,
            .duration_ms = 100,
        });
    }

    try testing.expect(!loop.canContinue());
    try testing.expectEqual(ExitCondition.max_iterations, loop.exit_condition);
}

test "RalphLoop: circuit breaker integration" {
    const config = LoopConfig{
        .max_iterations = 10,
        .enable_circuit_breaker = true,
    };
    var loop = RalphLoop.initWithConfig(testing.allocator, config);
    defer loop.deinit();

    // 3 iterations without progress should trigger circuit breaker
    for (0..3) |i| {
        try loop.processIteration(IterationResult{
            .iteration = @intCast(i + 1),
            .state = .testing,
            .files_changed = 0,
            .tests_run = 0,
            .tests_passed = 0,
            .errors = 0,
            .confidence = 0,
            .exit_signal = false,
            .duration_ms = 100,
        });
    }

    try testing.expect(!loop.canContinue());
    try testing.expectEqual(ExitCondition.circuit_open, loop.exit_condition);
}

test "ResponseAnalyzer: detects EXIT_SIGNAL" {
    const analyzer = ResponseAnalyzer.init(testing.allocator);

    const output = "Task completed. EXIT_SIGNAL: true";
    const result = analyzer.analyze(output);

    try testing.expect(result.exit_signal);
    try testing.expectEqual(@as(u32, 100), result.confidence);
}

test "ResponseAnalyzer: detects tests passed" {
    const analyzer = ResponseAnalyzer.init(testing.allocator);

    const output = "Running tests...\nAll 5 tests passed.";
    const result = analyzer.analyze(output);

    try testing.expect(result.tests_passed);
    try testing.expect(result.confidence >= 30);
}

test "ResponseAnalyzer: detects completion keywords" {
    const analyzer = ResponseAnalyzer.init(testing.allocator);

    const output = "Project complete. Ready for review.";
    const result = analyzer.analyze(output);

    try testing.expect(result.has_completion_signal);
    try testing.expect(result.exit_signal);
}

test "ResponseAnalyzer: low confidence without signals" {
    const analyzer = ResponseAnalyzer.init(testing.allocator);

    const output = "Working on implementation...";
    const result = analyzer.analyze(output);

    try testing.expect(!result.exit_signal);
    try testing.expectEqual(@as(u32, 0), result.confidence);
}

test "RalphLoop: reset works" {
    var loop = RalphLoop.init(testing.allocator);
    defer loop.deinit();

    try loop.processIteration(IterationResult{
        .iteration = 5,
        .state = .completed,
        .files_changed = 10,
        .tests_run = 20,
        .tests_passed = 20,
        .errors = 0,
        .confidence = 100,
        .exit_signal = true,
        .duration_ms = 5000,
    });

    loop.reset();

    try testing.expectEqual(LoopState.idle, loop.state);
    try testing.expectEqual(@as(u32, 0), loop.iteration);
    try testing.expectEqual(ExitCondition.none, loop.exit_condition);
}

test "LoopState: toString" {
    try testing.expectEqualStrings("IDLE", LoopState.idle.toString());
    try testing.expectEqualStrings("COMPLETED", LoopState.completed.toString());
    try testing.expectEqualStrings("FAILED", LoopState.failed.toString());
}

test "ExitCondition: toString" {
    try testing.expectEqualStrings("TESTS_PASSING", ExitCondition.tests_passing.toString());
    try testing.expectEqualStrings("CIRCUIT_OPEN", ExitCondition.circuit_open.toString());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const result = phi_sq + phi_inv_sq;
    try testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
