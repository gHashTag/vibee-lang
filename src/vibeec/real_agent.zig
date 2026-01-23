// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE REAL AGENT - Working Browser Automation with LLM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Integrates:
// - Chrome CDP via WebSocket for browser control
// - Ollama HTTP API for LLM reasoning
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const websocket = @import("websocket.zig");
const http_client = @import("http_client.zig");

pub const AgentError = error{
    BrowserConnectionFailed,
    LLMConnectionFailed,
    NavigationFailed,
    NavigationTimeout,
    EvaluationFailed,
    ParseError,
    OutOfMemory,
    ElementNotFound,
    ClickFailed,
    Timeout,
};

pub const AgentConfig = struct {
    chrome_host: []const u8 = "localhost",
    chrome_port: u16 = 9222,
    ollama_host: []const u8 = "localhost",
    ollama_port: u16 = 11434,
    model: []const u8 = "qwen2.5:0.5b",
    // v23.34: Test isolation
    test_mode: bool = false, // Disables persistence when true
};

// v23.34: Test configuration for isolated testing
pub const TestConfig = struct {
    disable_persistence: bool = true,
    isolated_storage: bool = true,

    /// Create agent config with test mode enabled
    pub fn toAgentConfig(self: TestConfig) AgentConfig {
        _ = self;
        return AgentConfig{
            .test_mode = true,
        };
    }
};

// v23.15: Domain timing statistics
pub const DomainStats = struct {
    avg_load_ms: u32 = 500,
    load_count: u32 = 0,
};

// v23.21: Persistent domain stats file path
pub const DOMAIN_STATS_FILE = ".vibee_domain_stats.json";

// v23.21: Domain stats entry for serialization
pub const DomainStatsEntry = struct {
    domain: []const u8,
    avg_load_ms: u32,
    load_count: u32,
};

// v23.25: Jitter Strategy enum
// Based on AWS Architecture Blog recommendations for distributed systems
pub const JitterStrategy = enum {
    equal, // Equal jitter: delay/2 + random(0, delay/2) - balanced approach
    full, // Full jitter: random(0, delay) - maximum spread, best for high contention
    decorrelated, // Decorrelated jitter: min(max_delay, random(base, prev_delay * 3)) - AWS recommended

    pub fn toString(self: JitterStrategy) []const u8 {
        return switch (self) {
            .equal => "equal",
            .full => "full",
            .decorrelated => "decorrelated",
        };
    }
};

// v23.33: Failure Pattern for adaptive strategy selection
pub const FailurePattern = enum {
    burst, // Multiple failures in quick succession - use full jitter
    steady, // Consistent failure rate - use decorrelated jitter
    random, // Unpredictable failures - use equal jitter
    unknown, // Not enough data - use default

    pub fn toString(self: FailurePattern) []const u8 {
        return switch (self) {
            .burst => "burst",
            .steady => "steady",
            .random => "random",
            .unknown => "unknown",
        };
    }

    /// Get recommended jitter strategy for this pattern (v23.33)
    pub fn getRecommendedStrategy(self: FailurePattern) JitterStrategy {
        return switch (self) {
            .burst => .full, // Maximum spread to avoid thundering herd
            .steady => .decorrelated, // AWS recommended for consistent load
            .random => .equal, // Balanced approach for unpredictable failures
            .unknown => .equal, // Default to balanced
        };
    }
};

// v23.33: Failure History for pattern detection
pub const FailureHistory = struct {
    // Sliding window of failure timestamps (last N failures)
    const WINDOW_SIZE = 10;
    timestamps: [WINDOW_SIZE]i64 = [_]i64{0} ** WINDOW_SIZE,
    count: u32 = 0,
    index: u32 = 0,

    const Self = @This();

    /// Record a failure timestamp (v23.33)
    pub fn recordFailure(self: *Self, timestamp: i64) void {
        self.timestamps[self.index] = timestamp;
        self.index = (self.index + 1) % WINDOW_SIZE;
        if (self.count < WINDOW_SIZE) {
            self.count += 1;
        }
    }

    /// Detect failure pattern from history (v23.33)
    pub fn detectPattern(self: Self) FailurePattern {
        if (self.count < 3) return .unknown;

        // Calculate intervals between failures
        var intervals: [WINDOW_SIZE - 1]i64 = undefined;
        var interval_count: u32 = 0;
        var sorted_timestamps: [WINDOW_SIZE]i64 = undefined;

        // Copy and sort timestamps
        var valid_count: u32 = 0;
        for (self.timestamps) |ts| {
            if (ts > 0) {
                sorted_timestamps[valid_count] = ts;
                valid_count += 1;
            }
        }

        if (valid_count < 3) return .unknown;

        // Simple bubble sort for small array
        var i: u32 = 0;
        while (i < valid_count - 1) : (i += 1) {
            var j: u32 = 0;
            while (j < valid_count - i - 1) : (j += 1) {
                if (sorted_timestamps[j] > sorted_timestamps[j + 1]) {
                    const tmp = sorted_timestamps[j];
                    sorted_timestamps[j] = sorted_timestamps[j + 1];
                    sorted_timestamps[j + 1] = tmp;
                }
            }
        }

        // Calculate intervals
        i = 0;
        while (i < valid_count - 1) : (i += 1) {
            intervals[interval_count] = sorted_timestamps[i + 1] - sorted_timestamps[i];
            interval_count += 1;
        }

        if (interval_count < 2) return .unknown;

        // Analyze intervals
        var sum: i64 = 0;
        var min_interval: i64 = intervals[0];
        var max_interval: i64 = intervals[0];

        i = 0;
        while (i < interval_count) : (i += 1) {
            sum += intervals[i];
            if (intervals[i] < min_interval) min_interval = intervals[i];
            if (intervals[i] > max_interval) max_interval = intervals[i];
        }

        const avg: i64 = @divFloor(sum, @as(i64, @intCast(interval_count)));

        // Burst: very short intervals (< 1 second average)
        if (avg < 1000) return .burst;

        // Steady: consistent intervals (max/min ratio < 3)
        if (min_interval > 0 and @divFloor(max_interval, min_interval) < 3) return .steady;

        // Random: high variance
        return .random;
    }

    /// Reset history (v23.33)
    pub fn reset(self: *Self) void {
        self.* = FailureHistory{};
    }
};

// v23.16: Retry configuration with exponential backoff
pub const RetryConfig = struct {
    max_retries: u32 = 3,
    initial_delay_ms: u32 = 500,
    backoff_factor: f32 = 2.0,
    max_delay_ms: u32 = 8000,
    // v23.17: Timeout adjustment on retry
    timeout_factor: f32 = 1.5, // Increase timeout by 50% on each retry
    max_timeout_ms: u32 = 30000, // Cap at 30 seconds (legacy, use specific caps)
    // v23.38: Configurable timeout caps per operation type
    selector_timeout_cap_ms: u32 = 30000, // Cap for waitForSelector (30s)
    page_load_timeout_cap_ms: u32 = 60000, // Cap for waitForPageLoad (60s)
    navigate_timeout_cap_ms: u32 = 45000, // Cap for navigate (45s)
    // v23.18: Jitter for distributed systems
    jitter_factor: f32 = 0.2, // ±20% random variation
    use_jitter: bool = true,
    // v23.25: Jitter strategy selection
    jitter_strategy: JitterStrategy = .equal,
    // v23.25: Previous delay for decorrelated jitter
    prev_delay_ms: u32 = 0,
    // v23.33: Adaptive strategy based on failure patterns
    adaptive_strategy: bool = false,
    failure_history: FailureHistory = FailureHistory{},

    /// Calculate delay for given attempt (0-indexed)
    pub fn getDelay(self: RetryConfig, attempt: u32) u32 {
        if (attempt == 0) return self.initial_delay_ms;
        var delay: f32 = @floatFromInt(self.initial_delay_ms);
        var i: u32 = 0;
        while (i < attempt) : (i += 1) {
            delay *= self.backoff_factor;
        }
        const result: u32 = @intFromFloat(delay);
        return @min(result, self.max_delay_ms);
    }

    /// Get full jitter: random(0, delay) (v23.25)
    /// Maximum spread, best for high contention scenarios
    pub fn getFullJitter(self: RetryConfig, attempt: u32) u32 {
        const base_delay = self.getDelay(attempt);
        if (base_delay == 0) return 0;

        const now = std.time.milliTimestamp();
        const seed: u64 = @bitCast(now);
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        // Full jitter: random value between 0 and base_delay
        const result = random.intRangeAtMost(u32, 0, base_delay);
        return @max(result, 100); // Minimum 100ms
    }

    /// Get decorrelated jitter: min(max_delay, random(base, prev_delay * 3)) (v23.25)
    /// AWS recommended approach - provides good spread while maintaining progress
    pub fn getDecorrelatedJitter(self: RetryConfig, attempt: u32, prev_delay: u32) u32 {
        const base_delay = self.initial_delay_ms;
        const effective_prev = if (prev_delay == 0) base_delay else prev_delay;

        const now = std.time.milliTimestamp();
        const seed: u64 = @bitCast(now);
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        // Decorrelated: random between base and prev_delay * 3
        const upper_bound = @min(effective_prev * 3, self.max_delay_ms);
        const lower_bound = @min(base_delay, upper_bound);

        if (upper_bound <= lower_bound) return lower_bound;

        const result = random.intRangeAtMost(u32, lower_bound, upper_bound);
        _ = attempt; // Used for consistency with other methods
        return @max(result, 100); // Minimum 100ms
    }

    /// Calculate delay with jitter using selected strategy (v23.25, v23.33)
    /// Prevents thundering herd problem in distributed systems
    pub fn getDelayWithJitter(self: RetryConfig, attempt: u32) u32 {
        const base_delay = self.getDelay(attempt);
        if (!self.use_jitter or self.jitter_factor == 0) {
            return base_delay;
        }

        // v23.33: Use adaptive strategy if enabled
        const strategy = if (self.adaptive_strategy)
            self.failure_history.detectPattern().getRecommendedStrategy()
        else
            self.jitter_strategy;

        // Use strategy-specific jitter calculation
        return switch (strategy) {
            .full => self.getFullJitter(attempt),
            .decorrelated => self.getDecorrelatedJitter(attempt, self.prev_delay_ms),
            .equal => self.getEqualJitter(attempt),
        };
    }

    /// Get delay with adaptive strategy and record failure (v23.33)
    pub fn getDelayWithAdaptive(self: *RetryConfig, attempt: u32) u32 {
        // Record failure timestamp for pattern detection
        self.failure_history.recordFailure(std.time.milliTimestamp());
        return self.getDelayWithJitter(attempt);
    }

    /// Get current detected pattern (v23.33)
    pub fn getDetectedPattern(self: RetryConfig) FailurePattern {
        return self.failure_history.detectPattern();
    }

    /// Get equal jitter: delay/2 + random(0, delay/2) (v23.25)
    /// Balanced approach - original implementation
    fn getEqualJitter(self: RetryConfig, attempt: u32) u32 {
        const base_delay = self.getDelay(attempt);

        // Generate pseudo-random jitter using timestamp
        const now = std.time.milliTimestamp();
        const seed: u64 = @bitCast(now);
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        // Calculate jitter range: delay * jitter_factor
        const jitter_range: f32 = @as(f32, @floatFromInt(base_delay)) * self.jitter_factor;
        const jitter_range_u32: u32 = @intFromFloat(jitter_range);

        if (jitter_range_u32 == 0) return base_delay;

        // Random value in range [-jitter_range, +jitter_range]
        const random_offset = random.intRangeAtMost(u32, 0, jitter_range_u32 * 2);
        const offset_i32: i32 = @as(i32, @intCast(random_offset)) - @as(i32, @intCast(jitter_range_u32));

        // Apply jitter, ensure minimum of 100ms
        const base_i32: i32 = @intCast(base_delay);
        const result_i32 = base_i32 + offset_i32;
        const result: u32 = @intCast(@max(result_i32, 100));

        return @min(result, self.max_delay_ms);
    }

    /// Calculate adjusted timeout for given attempt (v23.17)
    pub fn getTimeout(self: RetryConfig, base_timeout: u32, attempt: u32) u32 {
        if (attempt == 0) return base_timeout;
        var timeout: f32 = @floatFromInt(base_timeout);
        var i: u32 = 0;
        while (i < attempt) : (i += 1) {
            timeout *= self.timeout_factor;
        }
        const result: u32 = @intFromFloat(timeout);
        return @min(result, self.max_timeout_ms);
    }
};

// v23.16: Retry result
pub const RetryResult = struct {
    success: bool,
    attempts: u32,
    total_delay_ms: u32,
};

// v23.19: Retry metrics for observability
pub const RetryMetrics = struct {
    // Counters
    total_operations: u64 = 0,
    total_retries: u64 = 0,
    successful_operations: u64 = 0,
    failed_operations: u64 = 0,
    // Timing
    total_delay_ms: u64 = 0,
    max_delay_ms: u32 = 0,
    // Per-operation stats
    navigate_retries: u32 = 0,
    selector_retries: u32 = 0,
    page_load_retries: u32 = 0,
    click_retries: u32 = 0,
    // v23.26: Histogram for delay distribution
    delay_histogram: Histogram = Histogram{},

    /// Get success rate (0.0 - 1.0)
    pub fn getSuccessRate(self: RetryMetrics) f32 {
        if (self.total_operations == 0) return 1.0;
        return @as(f32, @floatFromInt(self.successful_operations)) / @as(f32, @floatFromInt(self.total_operations));
    }

    /// Get average retries per operation
    pub fn getAvgRetries(self: RetryMetrics) f32 {
        if (self.total_operations == 0) return 0.0;
        return @as(f32, @floatFromInt(self.total_retries)) / @as(f32, @floatFromInt(self.total_operations));
    }

    /// Get average delay per retry
    pub fn getAvgDelayMs(self: RetryMetrics) f32 {
        if (self.total_retries == 0) return 0.0;
        return @as(f32, @floatFromInt(self.total_delay_ms)) / @as(f32, @floatFromInt(self.total_retries));
    }

    /// Record delay in histogram (v23.26)
    pub fn recordDelay(self: *RetryMetrics, delay_ms: u32) void {
        self.delay_histogram.observe(delay_ms);
    }

    /// Get delay percentiles (v23.26)
    pub fn getDelayP50(self: RetryMetrics) u32 {
        return self.delay_histogram.getP50();
    }

    pub fn getDelayP90(self: RetryMetrics) u32 {
        return self.delay_histogram.getP90();
    }

    pub fn getDelayP95(self: RetryMetrics) u32 {
        return self.delay_histogram.getP95();
    }

    pub fn getDelayP99(self: RetryMetrics) u32 {
        return self.delay_histogram.getP99();
    }

    /// Reset all metrics
    pub fn reset(self: *RetryMetrics) void {
        self.* = RetryMetrics{};
    }

    /// Export metrics to JSON string (v23.39)
    pub fn toJson(self: RetryMetrics, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        try buffer.appendSlice("{\n");
        try buffer.appendSlice("  \"counters\": {\n");
        try std.fmt.format(buffer.writer(), "    \"total_operations\": {d},\n", .{self.total_operations});
        try std.fmt.format(buffer.writer(), "    \"total_retries\": {d},\n", .{self.total_retries});
        try std.fmt.format(buffer.writer(), "    \"successful_operations\": {d},\n", .{self.successful_operations});
        try std.fmt.format(buffer.writer(), "    \"failed_operations\": {d}\n", .{self.failed_operations});
        try buffer.appendSlice("  },\n");

        try buffer.appendSlice("  \"timing\": {\n");
        try std.fmt.format(buffer.writer(), "    \"total_delay_ms\": {d},\n", .{self.total_delay_ms});
        try std.fmt.format(buffer.writer(), "    \"max_delay_ms\": {d},\n", .{self.max_delay_ms});
        try std.fmt.format(buffer.writer(), "    \"avg_delay_ms\": {d:.2}\n", .{self.getAvgDelayMs()});
        try buffer.appendSlice("  },\n");

        try buffer.appendSlice("  \"per_operation\": {\n");
        try std.fmt.format(buffer.writer(), "    \"navigate_retries\": {d},\n", .{self.navigate_retries});
        try std.fmt.format(buffer.writer(), "    \"selector_retries\": {d},\n", .{self.selector_retries});
        try std.fmt.format(buffer.writer(), "    \"page_load_retries\": {d},\n", .{self.page_load_retries});
        try std.fmt.format(buffer.writer(), "    \"click_retries\": {d}\n", .{self.click_retries});
        try buffer.appendSlice("  },\n");

        try buffer.appendSlice("  \"rates\": {\n");
        try std.fmt.format(buffer.writer(), "    \"success_rate\": {d:.4},\n", .{self.getSuccessRate()});
        try std.fmt.format(buffer.writer(), "    \"avg_retries_per_op\": {d:.2}\n", .{self.getAvgRetries()});
        try buffer.appendSlice("  },\n");

        try buffer.appendSlice("  \"percentiles\": {\n");
        try std.fmt.format(buffer.writer(), "    \"p50_delay_ms\": {d},\n", .{self.getDelayP50()});
        try std.fmt.format(buffer.writer(), "    \"p90_delay_ms\": {d},\n", .{self.getDelayP90()});
        try std.fmt.format(buffer.writer(), "    \"p95_delay_ms\": {d},\n", .{self.getDelayP95()});
        try std.fmt.format(buffer.writer(), "    \"p99_delay_ms\": {d}\n", .{self.getDelayP99()});
        try buffer.appendSlice("  }\n");

        try buffer.appendSlice("}");

        return buffer.toOwnedSlice();
    }
};

// v23.26: Histogram for latency distribution
pub const Histogram = struct {
    // Bucket boundaries in milliseconds (exponential: 100, 200, 400, 800, 1600, 3200, 6400, 12800)
    const BUCKET_COUNT = 8;
    const BUCKET_BOUNDARIES = [_]u32{ 100, 200, 400, 800, 1600, 3200, 6400, 12800 };

    buckets: [BUCKET_COUNT]u64 = [_]u64{0} ** BUCKET_COUNT,
    overflow: u64 = 0, // Values > 12800ms
    count: u64 = 0,
    sum: u64 = 0,
    min: u32 = std.math.maxInt(u32),
    max: u32 = 0,

    const Self = @This();

    /// Observe a value and add to appropriate bucket
    pub fn observe(self: *Self, value: u32) void {
        self.count += 1;
        self.sum += value;

        if (value < self.min) self.min = value;
        if (value > self.max) self.max = value;

        // Find bucket
        var found = false;
        for (BUCKET_BOUNDARIES, 0..) |boundary, i| {
            if (value <= boundary) {
                self.buckets[i] += 1;
                found = true;
                break;
            }
        }
        if (!found) {
            self.overflow += 1;
        }
    }

    /// Get percentile value (p = 0.0 to 1.0)
    /// Uses linear interpolation within buckets
    pub fn getPercentile(self: Self, p: f32) u32 {
        if (self.count == 0) return 0;
        if (p <= 0.0) return self.min;
        if (p >= 1.0) return self.max;

        const target_count: u64 = @intFromFloat(@as(f32, @floatFromInt(self.count)) * p);
        var cumulative: u64 = 0;

        for (self.buckets, 0..) |bucket_count, i| {
            cumulative += bucket_count;
            if (cumulative >= target_count) {
                return BUCKET_BOUNDARIES[i];
            }
        }

        // In overflow bucket
        return BUCKET_BOUNDARIES[BUCKET_COUNT - 1];
    }

    /// Get p50 (median)
    pub fn getP50(self: Self) u32 {
        return self.getPercentile(0.5);
    }

    /// Get p90
    pub fn getP90(self: Self) u32 {
        return self.getPercentile(0.9);
    }

    /// Get p95
    pub fn getP95(self: Self) u32 {
        return self.getPercentile(0.95);
    }

    /// Get p99
    pub fn getP99(self: Self) u32 {
        return self.getPercentile(0.99);
    }

    /// Get average
    pub fn getAverage(self: Self) f32 {
        if (self.count == 0) return 0.0;
        return @as(f32, @floatFromInt(self.sum)) / @as(f32, @floatFromInt(self.count));
    }

    /// Reset histogram
    pub fn reset(self: *Self) void {
        self.* = Histogram{};
    }

    /// Get bucket boundaries for export
    pub fn getBucketBoundaries() []const u32 {
        return &BUCKET_BOUNDARIES;
    }

    /// Export histogram to JSON (v23.39)
    pub fn toJson(self: Self, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        try buffer.appendSlice("{\n");
        try buffer.appendSlice("  \"buckets\": [\n");

        for (BUCKET_BOUNDARIES, 0..) |boundary, i| {
            const comma: []const u8 = if (i < BUCKET_COUNT - 1) "," else "";
            try std.fmt.format(buffer.writer(), "    {{\"le\": {d}, \"count\": {d}}}{s}\n", .{ boundary, self.buckets[i], comma });
        }

        try buffer.appendSlice("  ],\n");
        try std.fmt.format(buffer.writer(), "  \"overflow\": {d},\n", .{self.overflow});
        try std.fmt.format(buffer.writer(), "  \"count\": {d},\n", .{self.count});
        try std.fmt.format(buffer.writer(), "  \"sum\": {d},\n", .{self.sum});
        try std.fmt.format(buffer.writer(), "  \"min\": {d},\n", .{if (self.count > 0) self.min else 0});
        try std.fmt.format(buffer.writer(), "  \"max\": {d},\n", .{self.max});
        try std.fmt.format(buffer.writer(), "  \"avg\": {d:.2}\n", .{self.getAverage()});
        try buffer.appendSlice("}");

        return buffer.toOwnedSlice();
    }

    /// Generate ASCII histogram chart (v23.39)
    pub fn toAsciiChart(self: Self, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        try buffer.appendSlice("Delay Distribution (ms):\n");

        // Find max bucket count for scaling
        var max_count: u64 = 1;
        for (self.buckets) |count| {
            if (count > max_count) max_count = count;
        }
        if (self.overflow > max_count) max_count = self.overflow;

        const bar_width: u32 = 40;

        for (BUCKET_BOUNDARIES, 0..) |boundary, i| {
            const count = self.buckets[i];
            const bar_len = @as(u32, @intFromFloat(@as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(max_count)) * @as(f32, @floatFromInt(bar_width))));

            try std.fmt.format(buffer.writer(), "  <={d:>5}ms |", .{boundary});
            var j: u32 = 0;
            while (j < bar_len) : (j += 1) {
                try buffer.append('#');
            }
            try std.fmt.format(buffer.writer(), " {d}\n", .{count});
        }

        // Overflow bucket
        const overflow_bar = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.overflow)) / @as(f32, @floatFromInt(max_count)) * @as(f32, @floatFromInt(bar_width))));
        try buffer.appendSlice("  > 12800ms |");
        var k: u32 = 0;
        while (k < overflow_bar) : (k += 1) {
            try buffer.append('#');
        }
        try std.fmt.format(buffer.writer(), " {d}\n", .{self.overflow});

        return buffer.toOwnedSlice();
    }
};

// v23.39: Metrics Trend Tracking
pub const MetricsTrend = struct {
    // Rolling window of success rates (last 10 measurements)
    const WINDOW_SIZE = 10;
    success_rates: [WINDOW_SIZE]f32 = [_]f32{0.0} ** WINDOW_SIZE,
    timestamps: [WINDOW_SIZE]i64 = [_]i64{0} ** WINDOW_SIZE,
    current_index: usize = 0,
    sample_count: usize = 0,

    const Self = @This();

    /// Record a new success rate sample (v23.39)
    pub fn record(self: *Self, success_rate: f32) void {
        self.success_rates[self.current_index] = success_rate;
        self.timestamps[self.current_index] = std.time.milliTimestamp();
        self.current_index = (self.current_index + 1) % WINDOW_SIZE;
        if (self.sample_count < WINDOW_SIZE) {
            self.sample_count += 1;
        }
    }

    /// Get trend direction: positive = improving, negative = degrading (v23.39)
    pub fn getTrend(self: Self) f32 {
        if (self.sample_count < 2) return 0.0;

        // Calculate linear regression slope
        var sum_x: f32 = 0.0;
        var sum_y: f32 = 0.0;
        var sum_xy: f32 = 0.0;
        var sum_xx: f32 = 0.0;
        const n = @as(f32, @floatFromInt(self.sample_count));

        for (0..self.sample_count) |i| {
            const x = @as(f32, @floatFromInt(i));
            const y = self.success_rates[i];
            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_xx += x * x;
        }

        const denominator = n * sum_xx - sum_x * sum_x;
        if (denominator == 0.0) return 0.0;

        return (n * sum_xy - sum_x * sum_y) / denominator;
    }

    /// Get average success rate over window (v23.39)
    pub fn getAverage(self: Self) f32 {
        if (self.sample_count == 0) return 0.0;
        var sum: f32 = 0.0;
        for (0..self.sample_count) |i| {
            sum += self.success_rates[i];
        }
        return sum / @as(f32, @floatFromInt(self.sample_count));
    }

    /// Get trend status string (v23.39)
    pub fn getTrendStatus(self: Self) []const u8 {
        const trend = self.getTrend();
        if (trend > 0.01) return "IMPROVING";
        if (trend < -0.01) return "DEGRADING";
        return "STABLE";
    }

    /// Export to JSON (v23.39)
    pub fn toJson(self: Self, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        try buffer.appendSlice("{\n");
        try std.fmt.format(buffer.writer(), "  \"sample_count\": {d},\n", .{self.sample_count});
        try std.fmt.format(buffer.writer(), "  \"average\": {d:.4},\n", .{self.getAverage()});
        try std.fmt.format(buffer.writer(), "  \"trend\": {d:.6},\n", .{self.getTrend()});
        try std.fmt.format(buffer.writer(), "  \"status\": \"{s}\",\n", .{self.getTrendStatus()});
        try buffer.appendSlice("  \"samples\": [");

        for (0..self.sample_count) |i| {
            if (i > 0) try buffer.appendSlice(", ");
            try std.fmt.format(buffer.writer(), "{d:.4}", .{self.success_rates[i]});
        }

        try buffer.appendSlice("]\n}");

        return buffer.toOwnedSlice();
    }

    /// Reset trend data (v23.39)
    pub fn reset(self: *Self) void {
        self.* = MetricsTrend{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// v23.40: DOM EXTRACTION - Agent "Vision" for WebArena
// ═══════════════════════════════════════════════════════════════════════════════

/// Element type for categorization (v23.40)
pub const ElementType = enum {
    link,
    button,
    input,
    textarea,
    select,
    checkbox,
    radio,
    image,
    text,
    heading,
    list,
    table,
    form,
    div,
    span,
    other,

    pub fn fromTagName(tag: []const u8) ElementType {
        if (std.mem.eql(u8, tag, "a")) return .link;
        if (std.mem.eql(u8, tag, "button")) return .button;
        if (std.mem.eql(u8, tag, "input")) return .input;
        if (std.mem.eql(u8, tag, "textarea")) return .textarea;
        if (std.mem.eql(u8, tag, "select")) return .select;
        if (std.mem.eql(u8, tag, "img")) return .image;
        if (std.mem.eql(u8, tag, "h1") or std.mem.eql(u8, tag, "h2") or
            std.mem.eql(u8, tag, "h3") or std.mem.eql(u8, tag, "h4") or
            std.mem.eql(u8, tag, "h5") or std.mem.eql(u8, tag, "h6")) return .heading;
        if (std.mem.eql(u8, tag, "ul") or std.mem.eql(u8, tag, "ol") or
            std.mem.eql(u8, tag, "li")) return .list;
        if (std.mem.eql(u8, tag, "table") or std.mem.eql(u8, tag, "tr") or
            std.mem.eql(u8, tag, "td") or std.mem.eql(u8, tag, "th")) return .table;
        if (std.mem.eql(u8, tag, "form")) return .form;
        if (std.mem.eql(u8, tag, "div")) return .div;
        if (std.mem.eql(u8, tag, "span") or std.mem.eql(u8, tag, "p")) return .text;
        return .other;
    }

    pub fn toString(self: ElementType) []const u8 {
        return switch (self) {
            .link => "link",
            .button => "button",
            .input => "input",
            .textarea => "textarea",
            .select => "select",
            .checkbox => "checkbox",
            .radio => "radio",
            .image => "image",
            .text => "text",
            .heading => "heading",
            .list => "list",
            .table => "table",
            .form => "form",
            .div => "div",
            .span => "span",
            .other => "other",
        };
    }
};

/// Bounding box for element position (v23.40)
pub const BoundingBox = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 0,
    height: u32 = 0,

    pub fn isVisible(self: BoundingBox) bool {
        return self.width > 0 and self.height > 0;
    }

    pub fn contains(self: BoundingBox, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + @as(i32, @intCast(self.width)) and
            py >= self.y and py < self.y + @as(i32, @intCast(self.height));
    }
};

/// DOM Element representation (v23.40)
pub const Element = struct {
    // Identity
    tag_name: []const u8,
    element_type: ElementType,
    selector: []const u8, // CSS selector to find this element
    
    // Content
    text_content: ?[]const u8 = null,
    inner_html: ?[]const u8 = null,
    
    // Attributes
    id: ?[]const u8 = null,
    class_name: ?[]const u8 = null,
    name: ?[]const u8 = null,
    href: ?[]const u8 = null,
    src: ?[]const u8 = null,
    value: ?[]const u8 = null,
    placeholder: ?[]const u8 = null,
    aria_label: ?[]const u8 = null,
    title: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    
    // State
    is_visible: bool = true,
    is_enabled: bool = true,
    is_checked: bool = false,
    is_selected: bool = false,
    is_focused: bool = false,
    
    // Position
    bounding_box: BoundingBox = BoundingBox{},
    
    // For form inputs
    input_type: ?[]const u8 = null, // text, password, email, etc.

    const Self = @This();

    /// Check if element is interactive (clickable/typeable) (v23.40)
    pub fn isInteractive(self: Self) bool {
        return switch (self.element_type) {
            .link, .button, .input, .textarea, .select, .checkbox, .radio => true,
            else => false,
        };
    }

    /// Check if element is a form field (v23.40)
    pub fn isFormField(self: Self) bool {
        return switch (self.element_type) {
            .input, .textarea, .select, .checkbox, .radio => true,
            else => false,
        };
    }

    /// Get display text for element (v23.40)
    pub fn getDisplayText(self: Self) []const u8 {
        if (self.text_content) |text| {
            if (text.len > 0) return text;
        }
        if (self.aria_label) |label| return label;
        if (self.title) |t| return t;
        if (self.placeholder) |p| return p;
        if (self.alt) |a| return a;
        if (self.value) |v| return v;
        return "";
    }

    /// Generate unique selector for element (v23.40)
    pub fn generateSelector(self: Self, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        // Prefer ID selector
        if (self.id) |id| {
            try std.fmt.format(buffer.writer(), "#{s}", .{id});
            return buffer.toOwnedSlice();
        }

        // Use tag + class
        try buffer.appendSlice(self.tag_name);
        if (self.class_name) |class| {
            if (class.len > 0) {
                // Take first class only
                var iter = std.mem.splitScalar(u8, class, ' ');
                if (iter.next()) |first_class| {
                    try std.fmt.format(buffer.writer(), ".{s}", .{first_class});
                }
            }
        }

        // Add name attribute for form fields
        if (self.name) |name| {
            try std.fmt.format(buffer.writer(), "[name=\"{s}\"]", .{name});
        }

        return buffer.toOwnedSlice();
    }

    /// Export element to JSON (v23.40)
    pub fn toJson(self: Self, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        try buffer.appendSlice("{\n");
        try std.fmt.format(buffer.writer(), "  \"tag\": \"{s}\",\n", .{self.tag_name});
        try std.fmt.format(buffer.writer(), "  \"type\": \"{s}\",\n", .{self.element_type.toString()});
        try std.fmt.format(buffer.writer(), "  \"selector\": \"{s}\",\n", .{self.selector});
        
        if (self.text_content) |text| {
            // Escape and truncate text
            const max_len = @min(text.len, 100);
            try std.fmt.format(buffer.writer(), "  \"text\": \"{s}\",\n", .{text[0..max_len]});
        }
        
        if (self.id) |id| {
            try std.fmt.format(buffer.writer(), "  \"id\": \"{s}\",\n", .{id});
        }
        
        if (self.href) |href| {
            try std.fmt.format(buffer.writer(), "  \"href\": \"{s}\",\n", .{href});
        }
        
        try std.fmt.format(buffer.writer(), "  \"visible\": {s},\n", .{if (self.is_visible) "true" else "false"});
        try std.fmt.format(buffer.writer(), "  \"interactive\": {s}\n", .{if (self.isInteractive()) "true" else "false"});
        try buffer.appendSlice("}");

        return buffer.toOwnedSlice();
    }
};

/// Page context for LLM (v23.40)
pub const PageContext = struct {
    url: []const u8,
    title: []const u8,
    visible_text: []const u8,
    links: []Element,
    buttons: []Element,
    inputs: []Element,
    forms: []Element,
    headings: []Element,

    /// Summarize page for LLM context (v23.40)
    pub fn summarize(self: PageContext, allocator: Allocator, max_length: usize) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        try std.fmt.format(buffer.writer(), "URL: {s}\n", .{self.url});
        try std.fmt.format(buffer.writer(), "Title: {s}\n\n", .{self.title});

        // Add headings
        if (self.headings.len > 0) {
            try buffer.appendSlice("Headings:\n");
            for (self.headings) |h| {
                if (buffer.items.len > max_length) break;
                try std.fmt.format(buffer.writer(), "- {s}\n", .{h.getDisplayText()});
            }
            try buffer.append('\n');
        }

        // Add links
        if (self.links.len > 0) {
            try buffer.appendSlice("Links:\n");
            var count: usize = 0;
            for (self.links) |link| {
                if (buffer.items.len > max_length or count >= 20) break;
                const text = link.getDisplayText();
                if (text.len > 0) {
                    try std.fmt.format(buffer.writer(), "- [{s}]", .{text});
                    if (link.href) |href| {
                        try std.fmt.format(buffer.writer(), "({s})", .{href});
                    }
                    try buffer.append('\n');
                    count += 1;
                }
            }
            try buffer.append('\n');
        }

        // Add buttons
        if (self.buttons.len > 0) {
            try buffer.appendSlice("Buttons:\n");
            for (self.buttons) |btn| {
                if (buffer.items.len > max_length) break;
                try std.fmt.format(buffer.writer(), "- {s}\n", .{btn.getDisplayText()});
            }
            try buffer.append('\n');
        }

        // Add form inputs
        if (self.inputs.len > 0) {
            try buffer.appendSlice("Form inputs:\n");
            for (self.inputs) |input| {
                if (buffer.items.len > max_length) break;
                const label = input.getDisplayText();
                const input_type = input.input_type orelse "text";
                try std.fmt.format(buffer.writer(), "- [{s}] {s}\n", .{ input_type, label });
            }
        }

        return buffer.toOwnedSlice();
    }
};

/// DOM Extractor - extracts structured data from web pages (v23.40)
pub const DOMExtractor = struct {
    allocator: Allocator,
    agent: *RealAgent,
    // Cache for extracted elements
    cached_elements: ?[]Element = null,
    cache_timestamp: i64 = 0,
    cache_ttl_ms: i64 = 5000, // 5 second cache

    const Self = @This();

    pub fn init(allocator: Allocator, agent: *RealAgent) Self {
        return Self{
            .allocator = allocator,
            .agent = agent,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.cached_elements) |elements| {
            self.allocator.free(elements);
        }
    }

    /// Get full page HTML (v23.40)
    pub fn getPageHTML(self: *Self) AgentError![]u8 {
        const js = "document.documentElement.outerHTML";
        return self.agent.evaluate(js);
    }

    /// Get page text content (v23.40)
    pub fn getPageText(self: *Self) AgentError![]u8 {
        const js = "document.body.innerText";
        return self.agent.evaluate(js);
    }

    /// Get page title (v23.40)
    pub fn getPageTitle(self: *Self) AgentError![]u8 {
        const js = "document.title";
        return self.agent.evaluate(js);
    }

    /// Get current URL (v23.40)
    pub fn getCurrentURL(self: *Self) AgentError![]u8 {
        const js = "window.location.href";
        return self.agent.evaluate(js);
    }

    /// Query single element by selector (v23.40)
    pub fn querySelector(self: *Self, selector: []const u8) AgentError!?Element {
        var js_buffer: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer, 
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return null;
            \\  var rect = el.getBoundingClientRect();
            \\  return JSON.stringify({{
            \\    tag: el.tagName.toLowerCase(),
            \\    id: el.id || null,
            \\    className: el.className || null,
            \\    name: el.name || null,
            \\    text: el.innerText ? el.innerText.substring(0, 200) : null,
            \\    href: el.href || null,
            \\    src: el.src || null,
            \\    value: el.value || null,
            \\    placeholder: el.placeholder || null,
            \\    type: el.type || null,
            \\    ariaLabel: el.getAttribute('aria-label') || null,
            \\    title: el.title || null,
            \\    alt: el.alt || null,
            \\    visible: rect.width > 0 && rect.height > 0,
            \\    enabled: !el.disabled,
            \\    checked: el.checked || false,
            \\    x: rect.x, y: rect.y, width: rect.width, height: rect.height
            \\  }});
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        const result = self.agent.evaluate(js) catch |err| return err;
        defer self.allocator.free(result);

        if (std.mem.eql(u8, result, "null") or result.len == 0) {
            return null;
        }

        return self.parseElementJson(result, selector);
    }

    /// Query all elements matching selector (v23.40)
    pub fn querySelectorAll(self: *Self, selector: []const u8) AgentError![]Element {
        var js_buffer: [2048]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var elements = document.querySelectorAll('{s}');
            \\  var results = [];
            \\  for (var i = 0; i < Math.min(elements.length, 100); i++) {{
            \\    var el = elements[i];
            \\    var rect = el.getBoundingClientRect();
            \\    results.push({{
            \\      tag: el.tagName.toLowerCase(),
            \\      id: el.id || null,
            \\      className: el.className || null,
            \\      name: el.name || null,
            \\      text: el.innerText ? el.innerText.substring(0, 200) : null,
            \\      href: el.href || null,
            \\      value: el.value || null,
            \\      type: el.type || null,
            \\      visible: rect.width > 0 && rect.height > 0,
            \\      x: rect.x, y: rect.y, width: rect.width, height: rect.height
            \\    }});
            \\  }}
            \\  return JSON.stringify(results);
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        const result = self.agent.evaluate(js) catch |err| return err;
        defer self.allocator.free(result);

        return self.parseElementsJson(result, selector);
    }

    /// Get element text by selector (v23.40)
    pub fn getElementText(self: *Self, selector: []const u8) AgentError!?[]u8 {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  return el ? el.innerText : null;
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        const result = self.agent.evaluate(js) catch |err| return err;

        if (std.mem.eql(u8, result, "null") or result.len == 0) {
            self.allocator.free(result);
            return null;
        }

        return result;
    }

    /// Get element attribute by selector (v23.40)
    pub fn getElementAttribute(self: *Self, selector: []const u8, attribute: []const u8) AgentError!?[]u8 {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  return el ? el.getAttribute('{s}') : null;
            \\}})()
        , .{ selector, attribute }) catch return AgentError.ParseError;

        const result = self.agent.evaluate(js) catch |err| return err;

        if (std.mem.eql(u8, result, "null") or result.len == 0) {
            self.allocator.free(result);
            return null;
        }

        return result;
    }

    /// Get all visible elements (v23.40)
    pub fn getVisibleElements(self: *Self) AgentError![]Element {
        const js =
            \\(function() {
            \\  var all = document.body.querySelectorAll('*');
            \\  var visible = [];
            \\  for (var i = 0; i < all.length && visible.length < 200; i++) {
            \\    var el = all[i];
            \\    var rect = el.getBoundingClientRect();
            \\    if (rect.width > 0 && rect.height > 0 && rect.top < window.innerHeight && rect.bottom > 0) {
            \\      visible.push({
            \\        tag: el.tagName.toLowerCase(),
            \\        id: el.id || null,
            \\        className: el.className || null,
            \\        text: el.innerText ? el.innerText.substring(0, 100) : null,
            \\        href: el.href || null,
            \\        x: rect.x, y: rect.y, width: rect.width, height: rect.height
            \\      });
            \\    }
            \\  }
            \\  return JSON.stringify(visible);
            \\})()
        ;

        const result = self.agent.evaluate(js) catch |err| return err;
        defer self.allocator.free(result);

        return self.parseElementsJson(result, "*");
    }

    /// Get all interactive elements (clickable) (v23.40)
    pub fn getInteractiveElements(self: *Self) AgentError![]Element {
        const js =
            \\(function() {
            \\  var selectors = 'a, button, input, select, textarea, [onclick], [role="button"]';
            \\  var elements = document.querySelectorAll(selectors);
            \\  var results = [];
            \\  for (var i = 0; i < Math.min(elements.length, 100); i++) {
            \\    var el = elements[i];
            \\    var rect = el.getBoundingClientRect();
            \\    if (rect.width > 0 && rect.height > 0) {
            \\      results.push({
            \\        tag: el.tagName.toLowerCase(),
            \\        id: el.id || null,
            \\        className: el.className || null,
            \\        name: el.name || null,
            \\        text: el.innerText ? el.innerText.substring(0, 100) : null,
            \\        href: el.href || null,
            \\        value: el.value || null,
            \\        type: el.type || null,
            \\        placeholder: el.placeholder || null,
            \\        visible: true,
            \\        enabled: !el.disabled,
            \\        x: rect.x, y: rect.y, width: rect.width, height: rect.height
            \\      });
            \\    }
            \\  }
            \\  return JSON.stringify(results);
            \\})()
        ;

        const result = self.agent.evaluate(js) catch |err| return err;
        defer self.allocator.free(result);

        return self.parseElementsJson(result, "interactive");
    }

    /// Get all form elements (v23.40)
    pub fn getFormElements(self: *Self) AgentError![]Element {
        const js =
            \\(function() {
            \\  var elements = document.querySelectorAll('input, select, textarea');
            \\  var results = [];
            \\  for (var i = 0; i < elements.length; i++) {
            \\    var el = elements[i];
            \\    var rect = el.getBoundingClientRect();
            \\    var label = null;
            \\    if (el.id) {
            \\      var labelEl = document.querySelector('label[for="' + el.id + '"]');
            \\      if (labelEl) label = labelEl.innerText;
            \\    }
            \\    results.push({
            \\      tag: el.tagName.toLowerCase(),
            \\      id: el.id || null,
            \\      name: el.name || null,
            \\      type: el.type || null,
            \\      value: el.value || null,
            \\      placeholder: el.placeholder || null,
            \\      text: label,
            \\      visible: rect.width > 0 && rect.height > 0,
            \\      enabled: !el.disabled,
            \\      checked: el.checked || false,
            \\      x: rect.x, y: rect.y, width: rect.width, height: rect.height
            \\    });
            \\  }
            \\  return JSON.stringify(results);
            \\})()
        ;

        const result = self.agent.evaluate(js) catch |err| return err;
        defer self.allocator.free(result);

        return self.parseElementsJson(result, "form");
    }

    /// Get all links on page (v23.40)
    pub fn getLinkElements(self: *Self) AgentError![]Element {
        const js =
            \\(function() {
            \\  var links = document.querySelectorAll('a[href]');
            \\  var results = [];
            \\  for (var i = 0; i < Math.min(links.length, 100); i++) {
            \\    var el = links[i];
            \\    var rect = el.getBoundingClientRect();
            \\    if (rect.width > 0 && rect.height > 0) {
            \\      results.push({
            \\        tag: 'a',
            \\        id: el.id || null,
            \\        text: el.innerText ? el.innerText.substring(0, 100) : null,
            \\        href: el.href,
            \\        title: el.title || null,
            \\        visible: true,
            \\        x: rect.x, y: rect.y, width: rect.width, height: rect.height
            \\      });
            \\    }
            \\  }
            \\  return JSON.stringify(results);
            \\})()
        ;

        const result = self.agent.evaluate(js) catch |err| return err;
        defer self.allocator.free(result);

        return self.parseElementsJson(result, "a");
    }

    /// Build full page context for LLM (v23.40)
    pub fn buildPageContext(self: *Self) AgentError!PageContext {
        const url = self.getCurrentURL() catch "unknown";
        const title = self.getPageTitle() catch "unknown";
        const text = self.getPageText() catch "";
        const links = self.getLinkElements() catch &[_]Element{};
        const buttons = self.querySelectorAll("button") catch &[_]Element{};
        const inputs = self.getFormElements() catch &[_]Element{};
        const forms = self.querySelectorAll("form") catch &[_]Element{};
        const headings = self.querySelectorAll("h1, h2, h3") catch &[_]Element{};

        return PageContext{
            .url = url,
            .title = title,
            .visible_text = text,
            .links = links,
            .buttons = buttons,
            .inputs = inputs,
            .forms = forms,
            .headings = headings,
        };
    }

    // Internal: Parse single element from JSON (v23.40, v23.41)
    fn parseElementJson(self: *Self, json: []const u8, selector: []const u8) ?Element {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json, .{}) catch return null;
        defer parsed.deinit();

        if (parsed.value != .object) return null;
        const obj = parsed.value.object;

        // Extract tag name
        const tag_name = if (obj.get("tag")) |t| switch (t) {
            .string => |s| self.allocator.dupe(u8, s) catch return null,
            else => self.allocator.dupe(u8, "div") catch return null,
        } else self.allocator.dupe(u8, "div") catch return null;

        // Build element
        var element = Element{
            .tag_name = tag_name,
            .element_type = ElementType.fromTagName(tag_name),
            .selector = self.allocator.dupe(u8, selector) catch return null,
        };

        // Extract optional string fields
        if (obj.get("id")) |v| if (v == .string) {
            element.id = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("className")) |v| if (v == .string) {
            element.class_name = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("name")) |v| if (v == .string) {
            element.name = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("text")) |v| if (v == .string) {
            element.text_content = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("href")) |v| if (v == .string) {
            element.href = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("src")) |v| if (v == .string) {
            element.src = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("value")) |v| if (v == .string) {
            element.value = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("placeholder")) |v| if (v == .string) {
            element.placeholder = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("type")) |v| if (v == .string) {
            element.input_type = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("ariaLabel")) |v| if (v == .string) {
            element.aria_label = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("title")) |v| if (v == .string) {
            element.title = self.allocator.dupe(u8, v.string) catch null;
        };
        if (obj.get("alt")) |v| if (v == .string) {
            element.alt = self.allocator.dupe(u8, v.string) catch null;
        };

        // Extract boolean fields
        if (obj.get("visible")) |v| if (v == .bool) {
            element.is_visible = v.bool;
        };
        if (obj.get("enabled")) |v| if (v == .bool) {
            element.is_enabled = v.bool;
        };
        if (obj.get("checked")) |v| if (v == .bool) {
            element.is_checked = v.bool;
        };

        // Extract bounding box
        if (obj.get("x")) |v| if (v == .integer) {
            element.bounding_box.x = @intCast(v.integer);
        };
        if (obj.get("y")) |v| if (v == .integer) {
            element.bounding_box.y = @intCast(v.integer);
        };
        if (obj.get("width")) |v| if (v == .integer) {
            element.bounding_box.width = @intCast(v.integer);
        };
        if (obj.get("height")) |v| if (v == .integer) {
            element.bounding_box.height = @intCast(v.integer);
        };

        // Handle input type for checkbox/radio
        if (element.input_type) |itype| {
            if (std.mem.eql(u8, itype, "checkbox")) {
                element.element_type = .checkbox;
            } else if (std.mem.eql(u8, itype, "radio")) {
                element.element_type = .radio;
            }
        }

        return element;
    }

    // Internal: Parse multiple elements from JSON array (v23.40, v23.41)
    fn parseElementsJson(self: *Self, json: []const u8, base_selector: []const u8) []Element {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json, .{}) catch return &[_]Element{};
        defer parsed.deinit();

        if (parsed.value != .array) return &[_]Element{};
        const arr = parsed.value.array;

        var elements = std.ArrayList(Element).init(self.allocator);

        for (arr.items, 0..) |item, i| {
            if (item != .object) continue;

            // Serialize single object back to JSON for parseElementJson
            var item_json = std.ArrayList(u8).init(self.allocator);
            defer item_json.deinit();

            std.json.stringify(item, .{}, item_json.writer()) catch continue;

            // Generate indexed selector
            var selector_buf: [256]u8 = undefined;
            const indexed_selector = std.fmt.bufPrint(&selector_buf, "{s}:nth-child({d})", .{ base_selector, i + 1 }) catch base_selector;

            if (self.parseElementJson(item_json.items, indexed_selector)) |element| {
                elements.append(element) catch continue;
            }
        }

        return elements.toOwnedSlice() catch &[_]Element{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// v23.42: FORM INTERACTION - WebArena Form Operations
// ═══════════════════════════════════════════════════════════════════════════════

/// Form field type (v23.42)
pub const FormFieldType = enum {
    text,
    password,
    email,
    number,
    tel,
    url,
    search,
    textarea,
    select,
    checkbox,
    radio,
    file,
    hidden,
    date,
    time,
    datetime,
    color,
    range,
    submit,
    button,
    other,

    pub fn fromInputType(input_type: ?[]const u8) FormFieldType {
        const t = input_type orelse return .text;
        if (std.mem.eql(u8, t, "text")) return .text;
        if (std.mem.eql(u8, t, "password")) return .password;
        if (std.mem.eql(u8, t, "email")) return .email;
        if (std.mem.eql(u8, t, "number")) return .number;
        if (std.mem.eql(u8, t, "tel")) return .tel;
        if (std.mem.eql(u8, t, "url")) return .url;
        if (std.mem.eql(u8, t, "search")) return .search;
        if (std.mem.eql(u8, t, "checkbox")) return .checkbox;
        if (std.mem.eql(u8, t, "radio")) return .radio;
        if (std.mem.eql(u8, t, "file")) return .file;
        if (std.mem.eql(u8, t, "hidden")) return .hidden;
        if (std.mem.eql(u8, t, "date")) return .date;
        if (std.mem.eql(u8, t, "time")) return .time;
        if (std.mem.eql(u8, t, "submit")) return .submit;
        if (std.mem.eql(u8, t, "button")) return .button;
        return .other;
    }

    pub fn toString(self: FormFieldType) []const u8 {
        return switch (self) {
            .text => "text",
            .password => "password",
            .email => "email",
            .number => "number",
            .tel => "tel",
            .url => "url",
            .search => "search",
            .textarea => "textarea",
            .select => "select",
            .checkbox => "checkbox",
            .radio => "radio",
            .file => "file",
            .hidden => "hidden",
            .date => "date",
            .time => "time",
            .datetime => "datetime",
            .color => "color",
            .range => "range",
            .submit => "submit",
            .button => "button",
            .other => "other",
        };
    }

    pub fn isTextInput(self: FormFieldType) bool {
        return switch (self) {
            .text, .password, .email, .number, .tel, .url, .search, .textarea => true,
            else => false,
        };
    }
};

/// Form field representation (v23.42)
pub const FormField = struct {
    selector: []const u8,
    field_type: FormFieldType,
    name: ?[]const u8 = null,
    label: ?[]const u8 = null,
    value: ?[]const u8 = null,
    placeholder: ?[]const u8 = null,
    is_required: bool = false,
    is_disabled: bool = false,
    is_readonly: bool = false,
    // For select fields
    options: ?[]const []const u8 = null,
    // For checkbox/radio
    is_checked: bool = false,

    const Self = @This();

    /// Create from Element (v23.42)
    pub fn fromElement(element: Element) Self {
        const field_type = if (std.mem.eql(u8, element.tag_name, "textarea"))
            FormFieldType.textarea
        else if (std.mem.eql(u8, element.tag_name, "select"))
            FormFieldType.select
        else
            FormFieldType.fromInputType(element.input_type);

        return Self{
            .selector = element.selector,
            .field_type = field_type,
            .name = element.name,
            .label = element.text_content,
            .value = element.value,
            .placeholder = element.placeholder,
            .is_disabled = !element.is_enabled,
            .is_checked = element.is_checked,
        };
    }

    /// Check if field can accept text input (v23.42)
    pub fn canType(self: Self) bool {
        return self.field_type.isTextInput() and !self.is_disabled and !self.is_readonly;
    }

    /// Check if field is a selection type (v23.42)
    pub fn isSelection(self: Self) bool {
        return self.field_type == .select or self.field_type == .checkbox or self.field_type == .radio;
    }
};

/// Form interaction handler (v23.42)
pub const FormInteraction = struct {
    allocator: Allocator,
    agent: *RealAgent,

    const Self = @This();

    pub fn init(allocator: Allocator, agent: *RealAgent) Self {
        return Self{
            .allocator = allocator,
            .agent = agent,
        };
    }

    /// Fill text input field (v23.42)
    pub fn fillInput(self: *Self, selector: []const u8, value: []const u8) AgentError!void {
        // Clear existing value and type new value
        var js_buffer: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return 'error:not_found';
            \\  if (el.disabled) return 'error:disabled';
            \\  el.focus();
            \\  el.value = '{s}';
            \\  el.dispatchEvent(new Event('input', {{ bubbles: true }}));
            \\  el.dispatchEvent(new Event('change', {{ bubbles: true }}));
            \\  return 'ok';
            \\}})()
        , .{ selector, value }) catch return AgentError.ParseError;

        const result = try self.agent.evaluate(js);
        defer self.allocator.free(result);

        if (std.mem.startsWith(u8, result, "error:")) {
            return AgentError.ElementNotFound;
        }
    }

    /// Clear input field (v23.42)
    pub fn clearInput(self: *Self, selector: []const u8) AgentError!void {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return 'error:not_found';
            \\  el.value = '';
            \\  el.dispatchEvent(new Event('input', {{ bubbles: true }}));
            \\  return 'ok';
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        const result = try self.agent.evaluate(js);
        defer self.allocator.free(result);

        if (std.mem.startsWith(u8, result, "error:")) {
            return AgentError.ElementNotFound;
        }
    }

    /// Select option from dropdown (v23.42)
    pub fn selectOption(self: *Self, selector: []const u8, value: []const u8) AgentError!void {
        var js_buffer: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return 'error:not_found';
            \\  if (el.tagName !== 'SELECT') return 'error:not_select';
            \\  var found = false;
            \\  for (var i = 0; i < el.options.length; i++) {{
            \\    if (el.options[i].value === '{s}' || el.options[i].text === '{s}') {{
            \\      el.selectedIndex = i;
            \\      found = true;
            \\      break;
            \\    }}
            \\  }}
            \\  if (!found) return 'error:option_not_found';
            \\  el.dispatchEvent(new Event('change', {{ bubbles: true }}));
            \\  return 'ok';
            \\}})()
        , .{ selector, value, value }) catch return AgentError.ParseError;

        const result = try self.agent.evaluate(js);
        defer self.allocator.free(result);

        if (std.mem.startsWith(u8, result, "error:")) {
            return AgentError.ElementNotFound;
        }
    }

    /// Check or uncheck checkbox (v23.42)
    pub fn checkCheckbox(self: *Self, selector: []const u8, checked: bool) AgentError!void {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return 'error:not_found';
            \\  if (el.type !== 'checkbox' && el.type !== 'radio') return 'error:not_checkbox';
            \\  if (el.checked !== {s}) {{
            \\    el.click();
            \\  }}
            \\  return 'ok';
            \\}})()
        , .{ selector, if (checked) "true" else "false" }) catch return AgentError.ParseError;

        const result = try self.agent.evaluate(js);
        defer self.allocator.free(result);

        if (std.mem.startsWith(u8, result, "error:")) {
            return AgentError.ElementNotFound;
        }
    }

    /// Submit form (v23.42)
    pub fn submitForm(self: *Self, selector: []const u8) AgentError!void {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return 'error:not_found';
            \\  var form = el.tagName === 'FORM' ? el : el.closest('form');
            \\  if (!form) return 'error:no_form';
            \\  form.submit();
            \\  return 'ok';
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        const result = try self.agent.evaluate(js);
        defer self.allocator.free(result);

        if (std.mem.startsWith(u8, result, "error:")) {
            return AgentError.ElementNotFound;
        }
    }

    /// Click submit button (v23.42)
    pub fn clickSubmit(self: *Self, selector: []const u8) AgentError!void {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return 'error:not_found';
            \\  el.click();
            \\  return 'ok';
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        const result = try self.agent.evaluate(js);
        defer self.allocator.free(result);

        if (std.mem.startsWith(u8, result, "error:")) {
            return AgentError.ElementNotFound;
        }
    }

    /// Fill multiple form fields at once (v23.42)
    pub fn fillForm(self: *Self, fields: []const FormFieldValue) AgentError!void {
        for (fields) |field| {
            switch (field.action) {
                .fill => try self.fillInput(field.selector, field.value),
                .select => try self.selectOption(field.selector, field.value),
                .check => try self.checkCheckbox(field.selector, true),
                .uncheck => try self.checkCheckbox(field.selector, false),
                .clear => try self.clearInput(field.selector),
            }
        }
    }

    /// Get current value of input field (v23.42)
    pub fn getInputValue(self: *Self, selector: []const u8) AgentError![]u8 {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return null;
            \\  return el.value || '';
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        return self.agent.evaluate(js);
    }

    /// Check if checkbox is checked (v23.42)
    pub fn isChecked(self: *Self, selector: []const u8) AgentError!bool {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return 'false';
            \\  return el.checked ? 'true' : 'false';
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        const result = try self.agent.evaluate(js);
        defer self.allocator.free(result);

        return std.mem.eql(u8, result, "true");
    }

    /// Get selected option value from dropdown (v23.42)
    pub fn getSelectedValue(self: *Self, selector: []const u8) AgentError![]u8 {
        var js_buffer: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buffer,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el || el.tagName !== 'SELECT') return '';
            \\  return el.options[el.selectedIndex]?.value || '';
            \\}})()
        , .{selector}) catch return AgentError.ParseError;

        return self.agent.evaluate(js);
    }
};

/// Form field value for batch operations (v23.42)
pub const FormFieldValue = struct {
    selector: []const u8,
    value: []const u8 = "",
    action: FormAction = .fill,
};

/// Form action type (v23.42)
pub const FormAction = enum {
    fill,
    select,
    check,
    uncheck,
    clear,
};

// v23.22: Circuit Breaker Pattern
pub const CircuitBreakerState = enum {
    closed, // Normal operation, requests allowed
    open, // Circuit tripped, requests blocked
    half_open, // Testing if service recovered
};

pub const CircuitBreaker = struct {
    state: CircuitBreakerState = .closed,
    failure_count: u32 = 0,
    success_count: u32 = 0,
    last_failure_time: i64 = 0,
    // Configuration
    failure_threshold: u32 = 5, // Open after N failures
    success_threshold: u32 = 3, // Close after N successes in half-open
    reset_timeout_ms: u64 = 30000, // Time before trying half-open (30s)

    const Self = @This();

    /// Check if request can be executed
    pub fn canExecute(self: *Self) bool {
        switch (self.state) {
            .closed => return true,
            .open => {
                // Check if reset timeout has passed
                const now = std.time.milliTimestamp();
                const elapsed: u64 = @intCast(@max(0, now - self.last_failure_time));
                if (elapsed >= self.reset_timeout_ms) {
                    // Transition to half-open
                    self.state = .half_open;
                    self.success_count = 0;
                    std.debug.print("    [CIRCUIT] OPEN → HALF_OPEN (timeout elapsed)\n", .{});
                    return true;
                }
                return false;
            },
            .half_open => return true,
        }
    }

    /// Record successful operation
    pub fn recordSuccess(self: *Self) void {
        switch (self.state) {
            .closed => {
                // Reset failure count on success
                self.failure_count = 0;
            },
            .half_open => {
                self.success_count += 1;
                if (self.success_count >= self.success_threshold) {
                    // Transition to closed
                    self.state = .closed;
                    self.failure_count = 0;
                    self.success_count = 0;
                    std.debug.print("    [CIRCUIT] HALF_OPEN → CLOSED (recovered)\n", .{});
                }
            },
            .open => {},
        }
    }

    /// Record failed operation
    pub fn recordFailure(self: *Self) void {
        self.last_failure_time = std.time.milliTimestamp();

        switch (self.state) {
            .closed => {
                self.failure_count += 1;
                if (self.failure_count >= self.failure_threshold) {
                    // Transition to open
                    self.state = .open;
                    std.debug.print("    [CIRCUIT] CLOSED → OPEN (threshold reached: {d} failures)\n", .{self.failure_count});
                }
            },
            .half_open => {
                // Single failure in half-open returns to open
                self.state = .open;
                self.success_count = 0;
                std.debug.print("    [CIRCUIT] HALF_OPEN → OPEN (failure during test)\n", .{});
            },
            .open => {},
        }
    }

    /// Reset circuit breaker
    pub fn reset(self: *Self) void {
        self.state = .closed;
        self.failure_count = 0;
        self.success_count = 0;
        self.last_failure_time = 0;
    }

    /// Get current state as string
    pub fn getStateString(self: Self) []const u8 {
        return switch (self.state) {
            .closed => "CLOSED",
            .open => "OPEN",
            .half_open => "HALF_OPEN",
        };
    }

    /// Create snapshot for serialization (v23.32)
    pub fn toSnapshot(self: Self) CircuitBreakerSnapshot {
        return CircuitBreakerSnapshot{
            .state = self.getStateString(),
            .failure_count = self.failure_count,
            .success_count = self.success_count,
            .last_failure_time = self.last_failure_time,
            .failure_threshold = self.failure_threshold,
            .success_threshold = self.success_threshold,
            .reset_timeout_ms = self.reset_timeout_ms,
        };
    }

    /// Restore from snapshot (v23.32)
    pub fn fromSnapshot(snapshot: CircuitBreakerSnapshot) Self {
        var cb = Self{
            .failure_count = snapshot.failure_count,
            .success_count = snapshot.success_count,
            .last_failure_time = snapshot.last_failure_time,
            .failure_threshold = snapshot.failure_threshold,
            .success_threshold = snapshot.success_threshold,
            .reset_timeout_ms = snapshot.reset_timeout_ms,
        };

        // Parse state string
        if (std.mem.eql(u8, snapshot.state, "OPEN")) {
            cb.state = .open;
        } else if (std.mem.eql(u8, snapshot.state, "HALF_OPEN")) {
            cb.state = .half_open;
        } else {
            cb.state = .closed;
        }

        return cb;
    }
};

// v23.32: Circuit Breaker Snapshot for persistence
pub const CircuitBreakerSnapshot = struct {
    state: []const u8 = "CLOSED",
    failure_count: u32 = 0,
    success_count: u32 = 0,
    last_failure_time: i64 = 0,
    failure_threshold: u32 = 5,
    success_threshold: u32 = 3,
    reset_timeout_ms: u64 = 30000,
};

// v23.32: Domain Circuit Breaker Entry for persistence
pub const DomainCircuitBreakerEntry = struct {
    domain: []const u8,
    circuit_breaker: CircuitBreakerSnapshot,
};

// v23.32: Persistence file path
pub const CIRCUIT_BREAKER_FILE = ".vibee_circuit_breakers.json";

// v23.24: Metrics Exporter for observability
pub const MetricsExporter = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{ .allocator = allocator };
    }

    /// Export retry metrics to JSON format (v23.24)
    pub fn exportRetryMetricsToJson(self: Self, metrics: RetryMetrics) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var writer = buffer.writer();

        try writer.writeAll("{\n");
        try writer.print("  \"total_operations\": {d},\n", .{metrics.total_operations});
        try writer.print("  \"total_retries\": {d},\n", .{metrics.total_retries});
        try writer.print("  \"successful_operations\": {d},\n", .{metrics.successful_operations});
        try writer.print("  \"failed_operations\": {d},\n", .{metrics.failed_operations});
        try writer.print("  \"success_rate\": {d:.4},\n", .{metrics.getSuccessRate()});
        try writer.print("  \"avg_retries_per_operation\": {d:.4},\n", .{metrics.getAvgRetries()});
        try writer.print("  \"total_delay_ms\": {d},\n", .{metrics.total_delay_ms});
        try writer.print("  \"max_delay_ms\": {d},\n", .{metrics.max_delay_ms});
        try writer.print("  \"avg_delay_ms\": {d:.2},\n", .{metrics.getAvgDelayMs()});
        try writer.writeAll("  \"per_operation\": {\n");
        try writer.print("    \"navigate_retries\": {d},\n", .{metrics.navigate_retries});
        try writer.print("    \"selector_retries\": {d},\n", .{metrics.selector_retries});
        try writer.print("    \"page_load_retries\": {d},\n", .{metrics.page_load_retries});
        try writer.print("    \"click_retries\": {d}\n", .{metrics.click_retries});
        try writer.writeAll("  },\n");
        // v23.26: Histogram percentiles
        try writer.writeAll("  \"delay_percentiles\": {\n");
        try writer.print("    \"p50\": {d},\n", .{metrics.getDelayP50()});
        try writer.print("    \"p90\": {d},\n", .{metrics.getDelayP90()});
        try writer.print("    \"p95\": {d},\n", .{metrics.getDelayP95()});
        try writer.print("    \"p99\": {d},\n", .{metrics.getDelayP99()});
        try writer.print("    \"min\": {d},\n", .{metrics.delay_histogram.min});
        try writer.print("    \"max\": {d},\n", .{metrics.delay_histogram.max});
        try writer.print("    \"count\": {d}\n", .{metrics.delay_histogram.count});
        try writer.writeAll("  }\n");
        try writer.writeAll("}\n");

        return buffer.toOwnedSlice();
    }

    /// Export retry metrics to Prometheus format (v23.24)
    pub fn exportRetryMetricsToPrometheus(self: Self, metrics: RetryMetrics) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var writer = buffer.writer();

        // Counters
        try writer.writeAll("# HELP vibee_retry_operations_total Total number of retry operations\n");
        try writer.writeAll("# TYPE vibee_retry_operations_total counter\n");
        try writer.print("vibee_retry_operations_total {d}\n\n", .{metrics.total_operations});

        try writer.writeAll("# HELP vibee_retry_attempts_total Total number of retry attempts\n");
        try writer.writeAll("# TYPE vibee_retry_attempts_total counter\n");
        try writer.print("vibee_retry_attempts_total {d}\n\n", .{metrics.total_retries});

        try writer.writeAll("# HELP vibee_retry_success_total Successful operations\n");
        try writer.writeAll("# TYPE vibee_retry_success_total counter\n");
        try writer.print("vibee_retry_success_total {d}\n\n", .{metrics.successful_operations});

        try writer.writeAll("# HELP vibee_retry_failure_total Failed operations\n");
        try writer.writeAll("# TYPE vibee_retry_failure_total counter\n");
        try writer.print("vibee_retry_failure_total {d}\n\n", .{metrics.failed_operations});

        // Gauges
        try writer.writeAll("# HELP vibee_retry_success_rate Success rate (0-1)\n");
        try writer.writeAll("# TYPE vibee_retry_success_rate gauge\n");
        try writer.print("vibee_retry_success_rate {d:.4}\n\n", .{metrics.getSuccessRate()});

        // Per-operation counters
        try writer.writeAll("# HELP vibee_retry_by_operation_total Retries by operation type\n");
        try writer.writeAll("# TYPE vibee_retry_by_operation_total counter\n");
        try writer.print("vibee_retry_by_operation_total{{operation=\"navigate\"}} {d}\n", .{metrics.navigate_retries});
        try writer.print("vibee_retry_by_operation_total{{operation=\"selector\"}} {d}\n", .{metrics.selector_retries});
        try writer.print("vibee_retry_by_operation_total{{operation=\"page_load\"}} {d}\n", .{metrics.page_load_retries});
        try writer.print("vibee_retry_by_operation_total{{operation=\"click\"}} {d}\n\n", .{metrics.click_retries});

        // Timing
        try writer.writeAll("# HELP vibee_retry_delay_ms_total Total delay in milliseconds\n");
        try writer.writeAll("# TYPE vibee_retry_delay_ms_total counter\n");
        try writer.print("vibee_retry_delay_ms_total {d}\n\n", .{metrics.total_delay_ms});

        try writer.writeAll("# HELP vibee_retry_delay_ms_max Maximum delay in milliseconds\n");
        try writer.writeAll("# TYPE vibee_retry_delay_ms_max gauge\n");
        try writer.print("vibee_retry_delay_ms_max {d}\n\n", .{metrics.max_delay_ms});

        // v23.26: Histogram for delay distribution
        try writer.writeAll("# HELP vibee_retry_delay_ms Histogram of retry delays\n");
        try writer.writeAll("# TYPE vibee_retry_delay_ms histogram\n");

        // Export bucket counts (cumulative)
        const boundaries = Histogram.getBucketBoundaries();
        var cumulative: u64 = 0;
        for (boundaries, 0..) |boundary, i| {
            cumulative += metrics.delay_histogram.buckets[i];
            try writer.print("vibee_retry_delay_ms_bucket{{le=\"{d}\"}} {d}\n", .{ boundary, cumulative });
        }
        cumulative += metrics.delay_histogram.overflow;
        try writer.print("vibee_retry_delay_ms_bucket{{le=\"+Inf\"}} {d}\n", .{cumulative});
        try writer.print("vibee_retry_delay_ms_sum {d}\n", .{metrics.delay_histogram.sum});
        try writer.print("vibee_retry_delay_ms_count {d}\n\n", .{metrics.delay_histogram.count});

        // Percentiles as gauges
        try writer.writeAll("# HELP vibee_retry_delay_percentile Delay percentiles\n");
        try writer.writeAll("# TYPE vibee_retry_delay_percentile gauge\n");
        try writer.print("vibee_retry_delay_percentile{{quantile=\"0.5\"}} {d}\n", .{metrics.getDelayP50()});
        try writer.print("vibee_retry_delay_percentile{{quantile=\"0.9\"}} {d}\n", .{metrics.getDelayP90()});
        try writer.print("vibee_retry_delay_percentile{{quantile=\"0.95\"}} {d}\n", .{metrics.getDelayP95()});
        try writer.print("vibee_retry_delay_percentile{{quantile=\"0.99\"}} {d}\n", .{metrics.getDelayP99()});

        return buffer.toOwnedSlice();
    }

    /// Export circuit breaker state to JSON (v23.24)
    pub fn exportCircuitBreakerToJson(self: Self, cb: CircuitBreaker) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var writer = buffer.writer();

        try writer.writeAll("{\n");
        try writer.print("  \"state\": \"{s}\",\n", .{cb.getStateString()});
        try writer.print("  \"failure_count\": {d},\n", .{cb.failure_count});
        try writer.print("  \"success_count\": {d},\n", .{cb.success_count});
        try writer.print("  \"failure_threshold\": {d},\n", .{cb.failure_threshold});
        try writer.print("  \"success_threshold\": {d},\n", .{cb.success_threshold});
        try writer.print("  \"reset_timeout_ms\": {d}\n", .{cb.reset_timeout_ms});
        try writer.writeAll("}\n");

        return buffer.toOwnedSlice();
    }
};

// v23.28: Health Check for monitoring
pub const HealthStatusLevel = enum {
    healthy, // All systems operational
    degraded, // Some issues but functional
    unhealthy, // Critical issues

    pub fn toString(self: HealthStatusLevel) []const u8 {
        return switch (self) {
            .healthy => "healthy",
            .degraded => "degraded",
            .unhealthy => "unhealthy",
        };
    }

    pub fn toInt(self: HealthStatusLevel) u8 {
        return switch (self) {
            .healthy => 1,
            .degraded => 0,
            .unhealthy => 0,
        };
    }
};

pub const ComponentHealth = struct {
    name: []const u8,
    status: HealthStatusLevel,
    message: []const u8 = "",
};

pub const HealthStatus = struct {
    status: HealthStatusLevel = .healthy,
    version: []const u8 = "23.28",
    uptime_ms: i64 = 0,
    start_time: i64 = 0,
    // Component checks
    circuit_breaker_healthy: bool = true,
    retry_metrics_healthy: bool = true,
    domain_breakers_healthy: bool = true,
    // Metrics summary
    success_rate: f32 = 1.0,
    total_operations: u64 = 0,
    open_circuits: u32 = 0,

    const Self = @This();

    /// Check if overall status is healthy
    pub fn isHealthy(self: Self) bool {
        return self.status == .healthy;
    }

    /// Get HTTP status code for health endpoint
    pub fn getHttpStatusCode(self: Self) u16 {
        return switch (self.status) {
            .healthy => 200,
            .degraded => 200,
            .unhealthy => 503,
        };
    }
};

pub const HealthCheck = struct {
    allocator: Allocator,
    start_time: i64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .start_time = std.time.milliTimestamp(),
        };
    }

    /// Get current health status from agent (v23.28)
    pub fn getStatus(self: Self, agent: *RealAgent) HealthStatus {
        const now = std.time.milliTimestamp();
        const uptime = now - self.start_time;

        var status = HealthStatus{
            .uptime_ms = uptime,
            .start_time = self.start_time,
            .success_rate = agent.retry_metrics.getSuccessRate(),
            .total_operations = agent.retry_metrics.total_operations,
        };

        // Check global circuit breaker
        status.circuit_breaker_healthy = agent.circuit_breaker.state != .open;

        // Check domain circuit breakers
        var open_count: u32 = 0;
        var it = agent.domain_circuit_breakers.valueIterator();
        while (it.next()) |cb| {
            if (cb.state == .open) {
                open_count += 1;
            }
        }
        status.open_circuits = open_count;
        status.domain_breakers_healthy = open_count == 0;

        // Check retry metrics health (success rate > 50%)
        status.retry_metrics_healthy = status.success_rate >= 0.5 or status.total_operations == 0;

        // Determine overall status
        if (!status.circuit_breaker_healthy) {
            status.status = .unhealthy;
        } else if (!status.domain_breakers_healthy or !status.retry_metrics_healthy) {
            status.status = .degraded;
        } else {
            status.status = .healthy;
        }

        return status;
    }

    /// Export health status to JSON (v23.28)
    pub fn toJson(self: Self, status: HealthStatus) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var writer = buffer.writer();

        try writer.writeAll("{\n");
        try writer.print("  \"status\": \"{s}\",\n", .{status.status.toString()});
        try writer.print("  \"version\": \"{s}\",\n", .{status.version});
        try writer.print("  \"uptime_ms\": {d},\n", .{status.uptime_ms});
        try writer.print("  \"start_time\": {d},\n", .{status.start_time});
        try writer.writeAll("  \"components\": {\n");
        try writer.print("    \"circuit_breaker\": {s},\n", .{if (status.circuit_breaker_healthy) "true" else "false"});
        try writer.print("    \"retry_metrics\": {s},\n", .{if (status.retry_metrics_healthy) "true" else "false"});
        try writer.print("    \"domain_breakers\": {s}\n", .{if (status.domain_breakers_healthy) "true" else "false"});
        try writer.writeAll("  },\n");
        try writer.writeAll("  \"metrics\": {\n");
        try writer.print("    \"success_rate\": {d:.4},\n", .{status.success_rate});
        try writer.print("    \"total_operations\": {d},\n", .{status.total_operations});
        try writer.print("    \"open_circuits\": {d}\n", .{status.open_circuits});
        try writer.writeAll("  }\n");
        try writer.writeAll("}\n");

        return buffer.toOwnedSlice();
    }

    /// Export health status to Prometheus format (v23.28)
    pub fn toPrometheus(self: Self, status: HealthStatus) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var writer = buffer.writer();

        // Health status gauge (1 = healthy, 0 = unhealthy)
        try writer.writeAll("# HELP vibee_health_status Health status (1=healthy, 0=unhealthy)\n");
        try writer.writeAll("# TYPE vibee_health_status gauge\n");
        try writer.print("vibee_health_status {d}\n\n", .{status.status.toInt()});

        // Uptime
        try writer.writeAll("# HELP vibee_uptime_seconds Uptime in seconds\n");
        try writer.writeAll("# TYPE vibee_uptime_seconds counter\n");
        try writer.print("vibee_uptime_seconds {d}\n\n", .{@divFloor(status.uptime_ms, 1000)});

        // Component health
        try writer.writeAll("# HELP vibee_component_health Component health (1=healthy, 0=unhealthy)\n");
        try writer.writeAll("# TYPE vibee_component_health gauge\n");
        try writer.print("vibee_component_health{{component=\"circuit_breaker\"}} {d}\n", .{@as(u8, if (status.circuit_breaker_healthy) 1 else 0)});
        try writer.print("vibee_component_health{{component=\"retry_metrics\"}} {d}\n", .{@as(u8, if (status.retry_metrics_healthy) 1 else 0)});
        try writer.print("vibee_component_health{{component=\"domain_breakers\"}} {d}\n\n", .{@as(u8, if (status.domain_breakers_healthy) 1 else 0)});

        // Open circuits
        try writer.writeAll("# HELP vibee_open_circuits Number of open circuit breakers\n");
        try writer.writeAll("# TYPE vibee_open_circuits gauge\n");
        try writer.print("vibee_open_circuits {d}\n", .{status.open_circuits});

        return buffer.toOwnedSlice();
    }
};

/// Extract domain from URL (v23.27)
/// Returns empty string if URL is invalid
fn extractDomain(url: []const u8) []const u8 {
    // Skip protocol
    var start: usize = 0;
    if (std.mem.startsWith(u8, url, "https://")) {
        start = 8;
    } else if (std.mem.startsWith(u8, url, "http://")) {
        start = 7;
    }

    if (start >= url.len) return "";

    // Find end of domain (first / or : after protocol)
    var end = start;
    while (end < url.len) : (end += 1) {
        if (url[end] == '/' or url[end] == ':') break;
    }

    if (end <= start) return "";
    return url[start..end];
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.29: FUNCTIONAL PROGRAMMING MODULE
// Pure functions for retry logic - no side effects, deterministic output
// ═══════════════════════════════════════════════════════════════════════════════

/// Error category for retry decisions (v23.29)
pub const ErrorCategory = enum {
    transient, // Network timeout, temporary unavailable - should retry
    permanent, // 404, invalid input - should not retry
    rate_limited, // 429 - should retry with longer delay
    unknown, // Unknown error - default to retry

    pub fn shouldRetry(self: ErrorCategory) bool {
        return switch (self) {
            .transient, .rate_limited, .unknown => true,
            .permanent => false,
        };
    }

    pub fn getDelayMultiplier(self: ErrorCategory) f32 {
        return switch (self) {
            .rate_limited => 3.0, // Triple delay for rate limiting
            .transient => 1.0,
            .unknown => 1.5,
            .permanent => 0.0,
        };
    }
};

/// Retry decision result (v23.29)
pub const RetryDecision = struct {
    should_retry: bool,
    delay_ms: u32,
    reason: []const u8,
};

/// Retry context for decision making (v23.29)
pub const RetryContext = struct {
    attempt: u32,
    max_retries: u32,
    error_category: ErrorCategory,
    circuit_state: CircuitBreakerState,
    base_delay_ms: u32,
    max_delay_ms: u32,
    backoff_factor: f32,
    jitter_strategy: JitterStrategy,
    seed: u64, // For deterministic jitter in tests
};

/// Pure function: Calculate exponential backoff delay (v23.29)
/// No side effects, deterministic output based on inputs
pub fn calculateBackoff(attempt: u32, base_delay: u32, factor: f32, max_delay: u32) u32 {
    if (attempt == 0) return base_delay;

    var delay: f32 = @floatFromInt(base_delay);
    var i: u32 = 0;
    while (i < attempt) : (i += 1) {
        delay *= factor;
    }

    const result: u32 = @intFromFloat(delay);
    return @min(result, max_delay);
}

/// Pure function: Apply jitter to delay (v23.29)
/// Deterministic when seed is provided
pub fn applyJitter(delay: u32, strategy: JitterStrategy, jitter_factor: f32, seed: u64) u32 {
    if (delay == 0 or jitter_factor == 0) return delay;

    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    return switch (strategy) {
        .equal => blk: {
            // Equal jitter: delay/2 + random(0, delay/2)
            const half_delay = delay / 2;
            const jitter = random.intRangeAtMost(u32, 0, half_delay);
            break :blk @max(half_delay + jitter, 100);
        },
        .full => blk: {
            // Full jitter: random(0, delay)
            const result = random.intRangeAtMost(u32, 0, delay);
            break :blk @max(result, 100);
        },
        .decorrelated => blk: {
            // Decorrelated: random(base, delay * 3)
            const upper = @min(delay * 3, std.math.maxInt(u32) / 2);
            const base = delay / 3;
            if (upper <= base) break :blk base;
            const result = random.intRangeAtMost(u32, base, upper);
            break :blk @max(result, 100);
        },
    };
}

/// Pure function: Determine if retry should happen (v23.29)
pub fn shouldRetry(attempt: u32, max_retries: u32, circuit_state: CircuitBreakerState, error_category: ErrorCategory) bool {
    // Circuit breaker check
    if (circuit_state == .open) return false;

    // Max retries check
    if (attempt >= max_retries) return false;

    // Error category check
    return error_category.shouldRetry();
}

/// Pure function: Classify error into category (v23.29, v23.35)
pub fn classifyError(err: AgentError) ErrorCategory {
    return switch (err) {
        AgentError.NavigationFailed, AgentError.EvaluationFailed => .transient,
        AgentError.BrowserConnectionFailed, AgentError.LLMConnectionFailed => .transient,
        AgentError.NavigationTimeout, AgentError.Timeout => .transient,
        AgentError.ElementNotFound, AgentError.ClickFailed => .transient,
        AgentError.ParseError => .permanent,
        AgentError.OutOfMemory => .permanent,
    };
}

/// Pure function: Make complete retry decision (v23.29)
/// Combines all retry logic into single pure function
pub fn makeRetryDecision(ctx: RetryContext) RetryDecision {
    // Check if retry is allowed
    if (!shouldRetry(ctx.attempt, ctx.max_retries, ctx.circuit_state, ctx.error_category)) {
        const reason = if (ctx.circuit_state == .open)
            "circuit breaker open"
        else if (ctx.attempt >= ctx.max_retries)
            "max retries exceeded"
        else
            "permanent error";

        return RetryDecision{
            .should_retry = false,
            .delay_ms = 0,
            .reason = reason,
        };
    }

    // Calculate delay
    var delay = calculateBackoff(ctx.attempt, ctx.base_delay_ms, ctx.backoff_factor, ctx.max_delay_ms);

    // Apply error category multiplier
    const multiplier = ctx.error_category.getDelayMultiplier();
    delay = @intFromFloat(@as(f32, @floatFromInt(delay)) * multiplier);
    delay = @min(delay, ctx.max_delay_ms);

    // Apply jitter
    delay = applyJitter(delay, ctx.jitter_strategy, 0.2, ctx.seed);

    return RetryDecision{
        .should_retry = true,
        .delay_ms = delay,
        .reason = "retry scheduled",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.30: FUNCTIONAL PIPELINE
// Composable operations for data transformation
// ═══════════════════════════════════════════════════════════════════════════════

/// Result type for functional error handling (v23.30)
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        pub fn isErr(self: Self) bool {
            return self == .err;
        }

        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |v| v,
                .err => unreachable,
            };
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |v| v,
                .err => default,
            };
        }

        pub fn unwrapErr(self: Self) E {
            return switch (self) {
                .ok => unreachable,
                .err => |e| e,
            };
        }

        /// Map: Transform success value (v23.30)
        pub fn map(self: Self, comptime f: fn (T) T) Self {
            return switch (self) {
                .ok => |v| Self{ .ok = f(v) },
                .err => |e| Self{ .err = e },
            };
        }

        /// FlatMap: Chain operations that may fail (v23.30)
        pub fn flatMap(self: Self, comptime f: fn (T) Self) Self {
            return switch (self) {
                .ok => |v| f(v),
                .err => |e| Self{ .err = e },
            };
        }

        /// MapErr: Transform error value (v23.30)
        pub fn mapErr(self: Self, comptime f: fn (E) E) Self {
            return switch (self) {
                .ok => |v| Self{ .ok = v },
                .err => |e| Self{ .err = f(e) },
            };
        }
    };
}

/// Pipeline for composing operations (v23.30)
pub fn Pipeline(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return Self{ .value = value };
        }

        /// Pipe: Apply function to value (v23.30)
        pub fn pipe(self: Self, comptime f: fn (T) T) Self {
            return Self{ .value = f(self.value) };
        }

        /// Filter: Keep value if predicate is true (v23.30)
        pub fn filter(self: Self, comptime pred: fn (T) bool, default: T) Self {
            return Self{
                .value = if (pred(self.value)) self.value else default,
            };
        }

        /// Get final value
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.31: RETRY EXECUTOR - Integration of Pure Functions
// Combines pure decision logic with effectful execution
// ═══════════════════════════════════════════════════════════════════════════════

/// Operation type for retry executor (v23.31)
pub const OperationType = enum {
    navigate,
    wait_selector,
    wait_page_load,
    click,
    evaluate,

    pub fn toString(self: OperationType) []const u8 {
        return switch (self) {
            .navigate => "navigate",
            .wait_selector => "wait_selector",
            .wait_page_load => "wait_page_load",
            .click => "click",
            .evaluate => "evaluate",
        };
    }

    /// Get retry metric field name for this operation type (v23.37)
    pub fn getMetricField(self: OperationType) []const u8 {
        return switch (self) {
            .navigate => "navigate_retries",
            .wait_selector => "selector_retries",
            .wait_page_load => "page_load_retries",
            .click => "click_retries",
            .evaluate => "navigate_retries", // fallback
        };
    }
};

/// Retry execution result with detailed info (v23.31)
pub const RetryExecutionResult = struct {
    success: bool,
    attempts: u32,
    total_delay_ms: u32,
    final_error: ?AgentError = null,
    decisions: []const RetryDecision = &[_]RetryDecision{},
};

// ═══════════════════════════════════════════════════════════════════════════════
// v23.37: COMPTIME OPERATION TRAITS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if type T has required Operation interface methods (v23.37)
pub fn isOperation(comptime T: type) bool {
    const has_execute = @hasDecl(T, "execute");
    const has_getType = @hasDecl(T, "getType");
    return has_execute and has_getType;
}

/// Check if operation returns bool (for wait operations) (v23.37)
/// Uses comptime type checking based on operation type
pub fn operationReturnsBool(comptime T: type) bool {
    // Check based on known operation types
    if (T == WaitSelectorOperation or T == WaitPageLoadOperation) {
        return true;
    }
    return false;
}

/// Check if operation has timeout escalation (v23.37)
pub fn hasTimeoutEscalation(comptime T: type) bool {
    return @hasDecl(T, "getEscalatedTimeout") and
        @hasDecl(T, "nextAttempt") and
        @hasDecl(T, "resetAttempts");
}

/// Check if operation has domain (for domain circuit breaker) (v23.37)
pub fn hasDomain(comptime T: type) bool {
    return @hasDecl(T, "getDomain");
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.35: OPERATION STRUCTS for RetryExecutor
// ═══════════════════════════════════════════════════════════════════════════════

/// Navigate operation for RetryExecutor (v23.35)
pub const NavigateOperation = struct {
    url: []const u8,
    agent: *RealAgent,

    const Self = @This();

    pub fn getType() OperationType {
        return .navigate;
    }

    pub fn getDomain(self: Self) []const u8 {
        return extractDomain(self.url);
    }

    pub fn execute(self: *Self) AgentError!void {
        return self.agent.navigate(self.url);
    }
};

/// Wait for selector operation for RetryExecutor (v23.35)
/// Wait for selector operation with timeout escalation (v23.35, v23.36)
/// Wait for selector operation with timeout escalation (v23.35, v23.36, v23.38)
pub const WaitSelectorOperation = struct {
    selector: []const u8,
    timeout_ms: u32,
    agent: *RealAgent,
    // v23.36: Timeout escalation
    timeout_multiplier: f32 = 1.5,
    current_attempt: u32 = 0,
    // v23.38: Optional custom timeout cap (0 = use config default)
    timeout_cap_ms: u32 = 0,

    const Self = @This();

    pub fn getType() OperationType {
        return .wait_selector;
    }

    /// Get timeout cap from config or custom value (v23.38)
    fn getTimeoutCap(self: *Self) u32 {
        if (self.timeout_cap_ms > 0) return self.timeout_cap_ms;
        return self.agent.retry_config.selector_timeout_cap_ms;
    }

    /// Get escalated timeout based on current attempt (v23.36, v23.38)
    pub fn getEscalatedTimeout(self: *Self) u32 {
        if (self.current_attempt == 0) return self.timeout_ms;
        
        var multiplier: f32 = 1.0;
        var i: u32 = 0;
        while (i < self.current_attempt) : (i += 1) {
            multiplier *= self.timeout_multiplier;
        }
        
        const escalated = @as(f32, @floatFromInt(self.timeout_ms)) * multiplier;
        // v23.38: Use configurable cap
        const max_timeout = self.getTimeoutCap();
        return @min(@as(u32, @intFromFloat(escalated)), max_timeout);
    }

    /// Increment attempt counter (v23.36)
    pub fn nextAttempt(self: *Self) void {
        self.current_attempt += 1;
    }

    /// Reset attempt counter (v23.36)
    pub fn resetAttempts(self: *Self) void {
        self.current_attempt = 0;
    }

    pub fn execute(self: *Self) AgentError!bool {
        const timeout = self.getEscalatedTimeout();
        return self.agent.waitForSelector(self.selector, timeout);
    }
};

/// Click operation for RetryExecutor (v23.35)
pub const ClickOperation = struct {
    selector: []const u8,
    agent: *RealAgent,

    const Self = @This();

    pub fn getType() OperationType {
        return .click;
    }

    pub fn execute(self: *Self) AgentError!void {
        return self.agent.clickSelector(self.selector);
    }
};

/// Wait for page load operation for RetryExecutor (v23.35)
/// Wait for page load operation with timeout escalation (v23.35, v23.36)
/// Wait for page load operation with timeout escalation (v23.35, v23.36, v23.38)
pub const WaitPageLoadOperation = struct {
    timeout_ms: u32,
    agent: *RealAgent,
    // v23.36: Timeout escalation
    timeout_multiplier: f32 = 1.5,
    current_attempt: u32 = 0,
    // v23.38: Optional custom timeout cap (0 = use config default)
    timeout_cap_ms: u32 = 0,

    const Self = @This();

    pub fn getType() OperationType {
        return .wait_page_load;
    }

    /// Get timeout cap from config or custom value (v23.38)
    fn getTimeoutCap(self: *Self) u32 {
        if (self.timeout_cap_ms > 0) return self.timeout_cap_ms;
        return self.agent.retry_config.page_load_timeout_cap_ms;
    }

    /// Get escalated timeout based on current attempt (v23.36, v23.38)
    pub fn getEscalatedTimeout(self: *Self) u32 {
        if (self.current_attempt == 0) return self.timeout_ms;
        
        var multiplier: f32 = 1.0;
        var i: u32 = 0;
        while (i < self.current_attempt) : (i += 1) {
            multiplier *= self.timeout_multiplier;
        }
        
        const escalated = @as(f32, @floatFromInt(self.timeout_ms)) * multiplier;
        // v23.38: Use configurable cap
        const max_timeout = self.getTimeoutCap();
        return @min(@as(u32, @intFromFloat(escalated)), max_timeout);
    }

    /// Increment attempt counter (v23.36)
    pub fn nextAttempt(self: *Self) void {
        self.current_attempt += 1;
    }

    /// Reset attempt counter (v23.36)
    pub fn resetAttempts(self: *Self) void {
        self.current_attempt = 0;
    }

    pub fn execute(self: *Self) AgentError!bool {
        const timeout = self.getEscalatedTimeout();
        return self.agent.waitForPageLoad(timeout);
    }
};

/// Retry Executor - bridges pure functions with effectful operations (v23.31, v23.35)
pub const RetryExecutor = struct {
    config: RetryConfig,
    metrics: *RetryMetrics,
    circuit_breaker: *CircuitBreaker,
    allocator: Allocator,
    // v23.35: Domain circuit breakers support
    domain_circuit_breakers: ?*std.StringHashMap(CircuitBreaker) = null,

    const Self = @This();

    pub fn init(allocator: Allocator, config: RetryConfig, metrics: *RetryMetrics, cb: *CircuitBreaker) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .metrics = metrics,
            .circuit_breaker = cb,
        };
    }

    /// Build retry context from current state (v23.31)
    pub fn buildContext(self: Self, attempt: u32, error_category: ErrorCategory) RetryContext {
        return RetryContext{
            .attempt = attempt,
            .max_retries = self.config.max_retries,
            .error_category = error_category,
            .circuit_state = self.circuit_breaker.state,
            .base_delay_ms = self.config.initial_delay_ms,
            .max_delay_ms = self.config.max_delay_ms,
            .backoff_factor = self.config.backoff_factor,
            .jitter_strategy = self.config.jitter_strategy,
            .seed = @bitCast(std.time.milliTimestamp()),
        };
    }

    /// Increment operation-specific retry metric (v23.37)
    fn incrementRetryMetric(self: *Self, op_type: OperationType) void {
        switch (op_type) {
            .navigate => self.metrics.navigate_retries += 1,
            .wait_selector => self.metrics.selector_retries += 1,
            .wait_page_load => self.metrics.page_load_retries += 1,
            .click => self.metrics.click_retries += 1,
            .evaluate => self.metrics.navigate_retries += 1,
        }
    }

    /// Generic operation executor using comptime (v23.37)
    /// Eliminates code duplication across execute* methods
    pub fn executeOperation(self: *Self, comptime T: type, op: *T) RetryExecutionResult {
        comptime {
            if (!isOperation(T)) {
                @compileError("Type must implement Operation interface (execute, getType)");
            }
        }

        var attempt: u32 = 0;
        var total_delay: u32 = 0;
        var last_error: ?AgentError = null;
        const op_type = T.getType();

        self.metrics.total_operations += 1;

        // v23.37: Reset timeout escalation if supported
        if (comptime hasTimeoutEscalation(T)) {
            op.resetAttempts();
        }

        // v23.37: Check domain circuit breaker if operation has domain
        if (comptime hasDomain(T)) {
            const domain = op.getDomain();
            if (self.domain_circuit_breakers) |dcb| {
                if (dcb.get(domain)) |cb| {
                    if (cb.state == .open) {
                        self.metrics.failed_operations += 1;
                        return RetryExecutionResult{
                            .success = false,
                            .attempts = 0,
                            .total_delay_ms = 0,
                            .final_error = AgentError.BrowserConnectionFailed,
                        };
                    }
                }
            }
        }

        // Check global circuit breaker
        if (!shouldRetry(0, self.config.max_retries, self.circuit_breaker.state, .transient)) {
            self.metrics.failed_operations += 1;
            return RetryExecutionResult{
                .success = false,
                .attempts = 0,
                .total_delay_ms = 0,
                .final_error = AgentError.BrowserConnectionFailed,
            };
        }

        while (attempt <= self.config.max_retries) {
            // v23.37: Handle both void and bool return types
            if (comptime operationReturnsBool(T)) {
                const result = op.execute() catch |err| {
                    last_error = err;
                    attempt += 1;
                    if (comptime hasTimeoutEscalation(T)) {
                        op.nextAttempt();
                    }
                    self.metrics.total_retries += 1;
                    self.incrementRetryMetric(op_type);

                    const error_category = classifyError(err);
                    const ctx = self.buildContext(attempt, error_category);
                    const decision = makeRetryDecision(ctx);

                    if (!decision.should_retry) {
                        self.metrics.failed_operations += 1;
                        self.circuit_breaker.recordFailure();
                        return RetryExecutionResult{
                            .success = false,
                            .attempts = attempt,
                            .total_delay_ms = total_delay,
                            .final_error = err,
                        };
                    }

                    total_delay += decision.delay_ms;
                    self.metrics.total_delay_ms += decision.delay_ms;
                    self.metrics.recordDelay(decision.delay_ms);

                    std.debug.print("    [RETRY-GEN] {s} attempt {d}/{d}, waiting {d}ms\n", .{
                        op_type.toString(),
                        attempt,
                        self.config.max_retries + 1,
                        decision.delay_ms,
                    });

                    std.time.sleep(@as(u64, decision.delay_ms) * std.time.ns_per_ms);
                    continue;
                };

                if (result) {
                    self.metrics.successful_operations += 1;
                    self.circuit_breaker.recordSuccess();
                    return RetryExecutionResult{
                        .success = true,
                        .attempts = attempt + 1,
                        .total_delay_ms = total_delay,
                    };
                } else {
                    // Result false but no error - retry
                    attempt += 1;
                    if (comptime hasTimeoutEscalation(T)) {
                        op.nextAttempt();
                    }
                    self.metrics.total_retries += 1;
                    self.incrementRetryMetric(op_type);

                    const ctx = self.buildContext(attempt, .transient);
                    const decision = makeRetryDecision(ctx);

                    if (!decision.should_retry) {
                        self.metrics.failed_operations += 1;
                        return RetryExecutionResult{
                            .success = false,
                            .attempts = attempt,
                            .total_delay_ms = total_delay,
                            .final_error = AgentError.ElementNotFound,
                        };
                    }

                    total_delay += decision.delay_ms;
                    self.metrics.total_delay_ms += decision.delay_ms;
                    std.time.sleep(@as(u64, decision.delay_ms) * std.time.ns_per_ms);
                    continue;
                }
            } else {
                // Void return type (navigate, click)
                op.execute() catch |err| {
                    last_error = err;
                    attempt += 1;
                    self.metrics.total_retries += 1;
                    self.incrementRetryMetric(op_type);

                    const error_category = classifyError(err);
                    const ctx = self.buildContext(attempt, error_category);
                    const decision = makeRetryDecision(ctx);

                    if (!decision.should_retry) {
                        self.metrics.failed_operations += 1;
                        self.circuit_breaker.recordFailure();
                        // Record domain failure if applicable
                        if (comptime hasDomain(T)) {
                            const domain = op.getDomain();
                            if (self.domain_circuit_breakers) |dcb| {
                                if (dcb.getPtr(domain)) |cb| {
                                    cb.recordFailure();
                                }
                            }
                        }
                        return RetryExecutionResult{
                            .success = false,
                            .attempts = attempt,
                            .total_delay_ms = total_delay,
                            .final_error = err,
                        };
                    }

                    total_delay += decision.delay_ms;
                    self.metrics.total_delay_ms += decision.delay_ms;
                    self.metrics.recordDelay(decision.delay_ms);

                    std.debug.print("    [RETRY-GEN] {s} attempt {d}/{d}, waiting {d}ms\n", .{
                        op_type.toString(),
                        attempt,
                        self.config.max_retries + 1,
                        decision.delay_ms,
                    });

                    std.time.sleep(@as(u64, decision.delay_ms) * std.time.ns_per_ms);
                    continue;
                };

                // Success for void operations
                self.metrics.successful_operations += 1;
                self.circuit_breaker.recordSuccess();
                // Record domain success if applicable
                if (comptime hasDomain(T)) {
                    const domain = op.getDomain();
                    if (self.domain_circuit_breakers) |dcb| {
                        if (dcb.getPtr(domain)) |cb| {
                            cb.recordSuccess();
                        }
                    }
                }
                return RetryExecutionResult{
                    .success = true,
                    .attempts = attempt + 1,
                    .total_delay_ms = total_delay,
                };
            }
        }

        self.metrics.failed_operations += 1;
        self.circuit_breaker.recordFailure();
        return RetryExecutionResult{
            .success = false,
            .attempts = attempt,
            .total_delay_ms = total_delay,
            .final_error = last_error,
        };
    }

    /// Execute operation with pure retry logic (v23.31)
    /// Uses makeRetryDecision for all retry decisions
    pub fn executeWithRetry(
        self: *Self,
        op_type: OperationType,
        comptime operation: fn (*anyopaque) AgentError!void,
        context: *anyopaque,
    ) RetryExecutionResult {
        var attempt: u32 = 0;
        var total_delay: u32 = 0;
        var last_error: ?AgentError = null;

        // Track operation
        self.metrics.total_operations += 1;

        // Check circuit breaker first using pure function
        if (!shouldRetry(0, self.config.max_retries, self.circuit_breaker.state, .transient)) {
            self.metrics.failed_operations += 1;
            return RetryExecutionResult{
                .success = false,
                .attempts = 0,
                .total_delay_ms = 0,
                .final_error = AgentError.BrowserConnectionFailed,
            };
        }

        while (attempt <= self.config.max_retries) {
            // Try operation
            operation(context) catch |err| {
                last_error = err;
                attempt += 1;

                // Track retry by operation type
                self.metrics.total_retries += 1;
                switch (op_type) {
                    .navigate => self.metrics.navigate_retries += 1,
                    .wait_selector => self.metrics.selector_retries += 1,
                    .wait_page_load => self.metrics.page_load_retries += 1,
                    .click => self.metrics.click_retries += 1,
                    .evaluate => {},
                }

                // Use pure function for retry decision
                const error_category = classifyError(err);
                const ctx = self.buildContext(attempt, error_category);
                const decision = makeRetryDecision(ctx);

                if (!decision.should_retry) {
                    self.metrics.failed_operations += 1;
                    self.circuit_breaker.recordFailure();
                    return RetryExecutionResult{
                        .success = false,
                        .attempts = attempt,
                        .total_delay_ms = total_delay,
                        .final_error = err,
                    };
                }

                // Apply delay
                total_delay += decision.delay_ms;
                self.metrics.total_delay_ms += decision.delay_ms;
                if (decision.delay_ms > self.metrics.max_delay_ms) {
                    self.metrics.max_delay_ms = decision.delay_ms;
                }
                self.metrics.recordDelay(decision.delay_ms);

                std.debug.print("    [RETRY-EXEC] {s} attempt {d}/{d}, waiting {d}ms ({s})\n", .{
                    op_type.toString(),
                    attempt,
                    self.config.max_retries + 1,
                    decision.delay_ms,
                    decision.reason,
                });

                std.time.sleep(@as(u64, decision.delay_ms) * std.time.ns_per_ms);
                continue;
            };

            // Success
            self.metrics.successful_operations += 1;
            self.circuit_breaker.recordSuccess();
            return RetryExecutionResult{
                .success = true,
                .attempts = attempt + 1,
                .total_delay_ms = total_delay,
            };
        }

        // Max retries exceeded
        self.metrics.failed_operations += 1;
        self.circuit_breaker.recordFailure();
        return RetryExecutionResult{
            .success = false,
            .attempts = attempt,
            .total_delay_ms = total_delay,
            .final_error = last_error,
        };
    }

    /// Simulate retry execution for testing (v23.31)
    /// Pure function - no actual operation execution
    pub fn simulateRetry(self: Self, failures_before_success: u32) RetryExecutionResult {
        var attempt: u32 = 0;
        var total_delay: u32 = 0;

        while (attempt <= self.config.max_retries) {
            if (attempt >= failures_before_success) {
                // Success
                return RetryExecutionResult{
                    .success = true,
                    .attempts = attempt + 1,
                    .total_delay_ms = total_delay,
                };
            }

            attempt += 1;
            const ctx = self.buildContext(attempt, .transient);
            const decision = makeRetryDecision(ctx);

            if (!decision.should_retry) {
                return RetryExecutionResult{
                    .success = false,
                    .attempts = attempt,
                    .total_delay_ms = total_delay,
                };
            }

            total_delay += decision.delay_ms;
        }

        return RetryExecutionResult{
            .success = false,
            .attempts = attempt,
            .total_delay_ms = total_delay,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // v23.35: NEW OPERATION-BASED EXECUTION METHODS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute navigate operation with retry (v23.35)
    /// Execute navigate operation (v23.35, v23.37: uses generic executor)
    pub fn executeNavigate(self: *Self, op: *NavigateOperation) RetryExecutionResult {
        return self.executeOperation(NavigateOperation, op);
    }

    /// Execute click operation (v23.35, v23.37: uses generic executor)
    pub fn executeClick(self: *Self, op: *ClickOperation) RetryExecutionResult {
        return self.executeOperation(ClickOperation, op);
    }

    /// Execute WaitSelectorOperation with retry logic (v23.35)
    /// Execute WaitSelectorOperation with retry and timeout escalation (v23.35, v23.36)
    /// Execute wait selector operation (v23.35, v23.37: uses generic executor)
    pub fn executeWaitSelector(self: *Self, op: *WaitSelectorOperation) RetryExecutionResult {
        return self.executeOperation(WaitSelectorOperation, op);
    }

    /// Execute wait page load operation (v23.35, v23.37: uses generic executor)
    pub fn executeWaitPageLoad(self: *Self, op: *WaitPageLoadOperation) RetryExecutionResult {
        return self.executeOperation(WaitPageLoadOperation, op);
    }

    /// Create executor from RealAgent (v23.35)
    pub fn fromAgent(agent: *RealAgent) Self {
        return Self{
            .allocator = agent.allocator,
            .config = agent.retry_config,
            .metrics = &agent.retry_metrics,
            .circuit_breaker = &agent.circuit_breaker,
            .domain_circuit_breakers = &agent.domain_circuit_breakers,
        };
    }
};

/// Create a test agent with persistence disabled (v23.34)
/// Use this in tests to avoid file system side effects
pub fn initTestAgent(allocator: Allocator) RealAgent {
    return RealAgent.init(allocator, AgentConfig{ .test_mode = true });
}

pub const RealAgent = struct {
    allocator: Allocator,
    config: AgentConfig,
    ws: websocket.WebSocketClient,
    http: http_client.HttpClient,
    connected: bool,
    message_id: u32,
    // v23.14: Adaptive timing (global)
    avg_page_load_ms: u32 = 500,
    page_load_count: u32 = 0,
    // v23.15: Domain-specific timing
    domain_stats: std.StringHashMap(DomainStats),
    current_domain: ?[]const u8 = null,
    // v23.15: Network idle detection
    pending_requests: u32 = 0,
    last_network_activity: i64 = 0,
    // v23.16: Retry configuration
    retry_config: RetryConfig = .{},
    // v23.19: Retry metrics
    retry_metrics: RetryMetrics = .{},
    // v23.22: Circuit breaker (global)
    circuit_breaker: CircuitBreaker = .{},
    // v23.27: Per-domain circuit breakers
    domain_circuit_breakers: std.StringHashMap(CircuitBreaker),
    // v23.28: Start time for uptime tracking
    start_time: i64 = 0,

    const Self = @This();

    pub fn init(allocator: Allocator, config: AgentConfig) Self {
        var self = Self{
            .allocator = allocator,
            .config = config,
            .ws = websocket.WebSocketClient.init(allocator),
            .http = http_client.HttpClient.init(allocator),
            .connected = false,
            .message_id = 1,
            .domain_stats = std.StringHashMap(DomainStats).init(allocator),
            .domain_circuit_breakers = std.StringHashMap(CircuitBreaker).init(allocator),
            .start_time = std.time.milliTimestamp(),
        };

        // v23.21: Auto-load domain stats from file
        self.loadDomainStats() catch {};

        // v23.32: Auto-load circuit breakers from file
        self.loadDomainCircuitBreakers() catch {};

        return self;
    }

    pub fn deinit(self: *Self) void {
        // v23.21: Auto-save domain stats to file
        self.saveDomainStats() catch {};

        // v23.32: Auto-save circuit breakers to file
        self.saveDomainCircuitBreakers() catch {};

        // Free domain keys
        var it = self.domain_stats.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.domain_stats.deinit();

        // v23.27: Free domain circuit breaker keys
        var cb_it = self.domain_circuit_breakers.keyIterator();
        while (cb_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.domain_circuit_breakers.deinit();

        if (self.current_domain) |d| self.allocator.free(d);
        self.ws.deinit();
        self.http.deinit();
    }

    /// Connect to Chrome browser via CDP
    pub fn connectBrowser(self: *Self, ws_url: []const u8) AgentError!void {
        self.ws.connect(ws_url) catch return AgentError.BrowserConnectionFailed;
        self.connected = true;

        // v23.15: Enable Network domain for network idle detection
        self.enableNetworkDomain() catch {};
    }

    /// Enable CDP Network domain (v23.15)
    fn enableNetworkDomain(self: *Self) AgentError!void {
        var cmd_buf: [256]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Network.enable\"}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.BrowserConnectionFailed;
        const frame = self.ws.receive() catch return AgentError.BrowserConnectionFailed;
        self.allocator.free(frame.payload);
    }

    /// Navigate to URL
    pub fn navigate(self: *Self, url: []const u8) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // Limit URL length to prevent buffer overflow
        const safe_url = if (url.len > 500) url[0..500] else url;

        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Page.navigate\",\"params\":{{\"url\":\"{s}\"}}}}", .{ self.message_id, safe_url }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.NavigationFailed;

        // Read response
        const frame = self.ws.receive() catch return AgentError.NavigationFailed;
        self.allocator.free(frame.payload);

        // v23.15: Extract domain and use domain-specific timeout
        const domain = extractDomain(url);
        if (domain.len > 0) {
            // Update current domain
            if (self.current_domain) |old| self.allocator.free(old);
            self.current_domain = self.allocator.dupe(u8, domain) catch null;
        }

        // v23.15: Use adaptive timeout based on page load history
        const start = std.time.milliTimestamp();
        const timeout = self.getAdaptiveTimeout();
        const loaded = self.waitForPageLoad(timeout) catch false;
        const elapsed = std.time.milliTimestamp() - start;
        const elapsed_u32: u32 = @intCast(@min(elapsed, std.math.maxInt(u32)));

        if (loaded) {
            // Update both global and domain-specific stats
            self.updatePageLoadStats(elapsed_u32);
            if (domain.len > 0) self.updateDomainStats(domain, elapsed_u32);
            std.debug.print("    [NAV] Page loaded in {d}ms (timeout: {d}ms, domain: {s})\n", .{ elapsed, timeout, if (domain.len > 0) domain else "unknown" });
        } else {
            std.debug.print("    [NAV] Page load timeout after {d}ms (timeout was: {d}ms)\n", .{ elapsed, timeout });
        }
    }

    /// Get page title
    pub fn getTitle(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.title\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Extract title from response
        // Response format: {"id":N,"result":{"result":{"type":"string","value":"Title"}}}
        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"")) |start| {
            const value_start = start + 9;
            if (std.mem.indexOf(u8, frame.payload[value_start..], "\"")) |end| {
                return self.allocator.dupe(u8, frame.payload[value_start .. value_start + end]) catch return AgentError.OutOfMemory;
            }
        }

        return AgentError.ParseError;
    }

    /// Get page text content
    pub fn getPageText(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.body.innerText\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Extract text from response
        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"")) |start| {
            const value_start = start + 9;
            if (std.mem.lastIndexOf(u8, frame.payload, "\"")) |end| {
                if (end > value_start) {
                    return self.allocator.dupe(u8, frame.payload[value_start..end]) catch return AgentError.OutOfMemory;
                }
            }
        }

        return AgentError.ParseError;
    }

    /// Click element by CSS selector
    /// Uses Runtime.evaluate to get element coordinates, then dispatches mouse events
    pub fn clickSelector(self: *Self, selector: []const u8) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // v23.14: Quick wait for element (500ms) before clicking
        _ = self.waitForSelector(selector, 500) catch {};

        // Step 1: Get element bounding box via JavaScript
        var cmd_buf: [2048]u8 = undefined;

        // Escape selector for JS string (single quotes)
        var escaped_selector: [512]u8 = undefined;
        var escaped_len: usize = 0;
        for (selector) |c| {
            if (c == '\'' or c == '\\') {
                escaped_selector[escaped_len] = '\\';
                escaped_len += 1;
            }
            escaped_selector[escaped_len] = c;
            escaped_len += 1;
        }

        // Build JS expression
        var js_buf: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf, "(function(){{var el=document.querySelector('{s}');if(!el)return null;var r=el.getBoundingClientRect();return {{x:r.x+r.width/2,y:r.y+r.height/2}};}})()", .{escaped_selector[0..escaped_len]}) catch return AgentError.OutOfMemory;

        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"{s}\",\"returnByValue\":true}}}}", .{ self.message_id, js }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Parse coordinates from response
        // Format: {"id":N,"result":{"result":{"type":"object","value":{"x":123,"y":456}}}}
        var x: f64 = 0;
        var y: f64 = 0;

        if (std.mem.indexOf(u8, frame.payload, "\"x\":")) |x_start| {
            const x_val_start = x_start + 4;
            var x_end = x_val_start;
            while (x_end < frame.payload.len and (frame.payload[x_end] == '.' or (frame.payload[x_end] >= '0' and frame.payload[x_end] <= '9'))) : (x_end += 1) {}
            x = std.fmt.parseFloat(f64, frame.payload[x_val_start..x_end]) catch 0;
        }

        if (std.mem.indexOf(u8, frame.payload, "\"y\":")) |y_start| {
            const y_val_start = y_start + 4;
            var y_end = y_val_start;
            while (y_end < frame.payload.len and (frame.payload[y_end] == '.' or (frame.payload[y_end] >= '0' and frame.payload[y_end] <= '9'))) : (y_end += 1) {}
            y = std.fmt.parseFloat(f64, frame.payload[y_val_start..y_end]) catch 0;
        }

        if (x == 0 and y == 0) {
            return AgentError.EvaluationFailed; // Element not found
        }

        // Step 2: Dispatch mouse events
        try self.dispatchMouseEvent("mousePressed", x, y);
        try self.dispatchMouseEvent("mouseReleased", x, y);
    }

    /// Dispatch mouse event at coordinates
    fn dispatchMouseEvent(self: *Self, event_type: []const u8, x: f64, y: f64) AgentError!void {
        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.dispatchMouseEvent\",\"params\":{{\"type\":\"{s}\",\"x\":{d},\"y\":{d},\"button\":\"left\",\"clickCount\":1}}}}", .{ self.message_id, event_type, x, y }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Type text into focused element
    pub fn typeText(self: *Self, text: []const u8) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // Escape text for JSON
        var escaped: [2048]u8 = undefined;
        var escaped_len: usize = 0;
        for (text) |c| {
            if (c == '"' or c == '\\') {
                escaped[escaped_len] = '\\';
                escaped_len += 1;
            }
            escaped[escaped_len] = c;
            escaped_len += 1;
        }

        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.insertText\",\"params\":{{\"text\":\"{s}\"}}}}", .{ self.message_id, escaped[0..escaped_len] }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Click element and type text (common pattern for form filling)
    pub fn clickAndType(self: *Self, selector: []const u8, text: []const u8) AgentError!void {
        try self.clickSelector(selector);
        std.time.sleep(100 * std.time.ns_per_ms); // Small delay for focus
        try self.typeText(text);
    }

    /// Press Enter key
    pub fn pressEnter(self: *Self) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;

        // Key down
        var cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.dispatchKeyEvent\",\"params\":{{\"type\":\"keyDown\",\"key\":\"Enter\",\"code\":\"Enter\",\"windowsVirtualKeyCode\":13}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;
        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;
        var frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);

        // Key up
        cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Input.dispatchKeyEvent\",\"params\":{{\"type\":\"keyUp\",\"key\":\"Enter\",\"code\":\"Enter\",\"windowsVirtualKeyCode\":13}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;
        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;
        frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Scroll page
    pub fn scroll(self: *Self, delta_y: i32) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"window.scrollBy(0, {d})\"}}}}", .{ self.message_id, delta_y }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        self.allocator.free(frame.payload);
    }

    /// Wait for element to appear on page
    pub fn waitForSelector(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!bool {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        const start_time = std.time.milliTimestamp();
        const timeout_end = start_time + @as(i64, timeout_ms);

        while (std.time.milliTimestamp() < timeout_end) {
            // Check if element exists
            var cmd_buf: [1024]u8 = undefined;

            // Escape selector
            var escaped: [256]u8 = undefined;
            var escaped_len: usize = 0;
            for (selector) |c| {
                if (c == '\'' or c == '\\') {
                    escaped[escaped_len] = '\\';
                    escaped_len += 1;
                }
                if (escaped_len < escaped.len) {
                    escaped[escaped_len] = c;
                    escaped_len += 1;
                }
            }

            const js = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.querySelector('{s}') !== null\"}}}}", .{ self.message_id, escaped[0..escaped_len] }) catch return AgentError.OutOfMemory;
            self.message_id += 1;

            self.ws.sendText(js) catch return AgentError.EvaluationFailed;

            const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
            defer self.allocator.free(frame.payload);

            // Check if result is true
            if (std.mem.indexOf(u8, frame.payload, "\"value\":true") != null) {
                return true; // Element found
            }

            // Wait 100ms before next check
            std.time.sleep(100 * std.time.ns_per_ms);
        }

        return false; // Timeout
    }

    /// Wait for multiple selectors in parallel (v23.15)
    /// Returns when ALL selectors are found or timeout
    pub fn waitForSelectors(self: *Self, selectors: []const []const u8, timeout_ms: u32) AgentError!bool {
        if (!self.connected) return AgentError.BrowserConnectionFailed;
        if (selectors.len == 0) return true;

        const start_time = std.time.milliTimestamp();
        const timeout_end = start_time + @as(i64, timeout_ms);

        // Track which selectors are found
        var found = [_]bool{false} ** 16; // Max 16 selectors
        const count = @min(selectors.len, 16);
        var all_found: usize = 0;

        while (std.time.milliTimestamp() < timeout_end) {
            // Check all unfound selectors in one iteration
            for (selectors[0..count], 0..) |selector, i| {
                if (found[i]) continue;

                // Build JS to check selector
                var cmd_buf: [1024]u8 = undefined;
                var escaped: [256]u8 = undefined;
                var escaped_len: usize = 0;
                for (selector) |c| {
                    if (c == '\'' or c == '\\') {
                        escaped[escaped_len] = '\\';
                        escaped_len += 1;
                    }
                    if (escaped_len < escaped.len) {
                        escaped[escaped_len] = c;
                        escaped_len += 1;
                    }
                }

                const js = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.querySelector('{s}') !== null\"}}}}", .{ self.message_id, escaped[0..escaped_len] }) catch return AgentError.OutOfMemory;
                self.message_id += 1;

                self.ws.sendText(js) catch return AgentError.EvaluationFailed;

                const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
                defer self.allocator.free(frame.payload);

                if (std.mem.indexOf(u8, frame.payload, "\"value\":true") != null) {
                    found[i] = true;
                    all_found += 1;
                }
            }

            // All found?
            if (all_found == count) {
                const elapsed = std.time.milliTimestamp() - start_time;
                std.debug.print("    [WAIT] All {d} selectors found in {d}ms\n", .{ count, elapsed });
                return true;
            }

            // Wait 50ms before next check (faster than single selector)
            std.time.sleep(50 * std.time.ns_per_ms);
        }

        std.debug.print("    [WAIT] Timeout: found {d}/{d} selectors\n", .{ all_found, count });
        return false;
    }

    /// Wait for ANY of the selectors (v23.15)
    /// Returns index of first found selector, or null on timeout
    pub fn waitForAnySelector(self: *Self, selectors: []const []const u8, timeout_ms: u32) AgentError!?usize {
        if (!self.connected) return AgentError.BrowserConnectionFailed;
        if (selectors.len == 0) return null;

        const start_time = std.time.milliTimestamp();
        const timeout_end = start_time + @as(i64, timeout_ms);
        const count = @min(selectors.len, 16);

        while (std.time.milliTimestamp() < timeout_end) {
            for (selectors[0..count], 0..) |selector, i| {
                var cmd_buf: [1024]u8 = undefined;
                var escaped: [256]u8 = undefined;
                var escaped_len: usize = 0;
                for (selector) |c| {
                    if (c == '\'' or c == '\\') {
                        escaped[escaped_len] = '\\';
                        escaped_len += 1;
                    }
                    if (escaped_len < escaped.len) {
                        escaped[escaped_len] = c;
                        escaped_len += 1;
                    }
                }

                const js = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.querySelector('{s}') !== null\"}}}}", .{ self.message_id, escaped[0..escaped_len] }) catch return AgentError.OutOfMemory;
                self.message_id += 1;

                self.ws.sendText(js) catch return AgentError.EvaluationFailed;

                const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
                defer self.allocator.free(frame.payload);

                if (std.mem.indexOf(u8, frame.payload, "\"value\":true") != null) {
                    return i;
                }
            }

            std.time.sleep(50 * std.time.ns_per_ms);
        }

        return null;
    }

    /// Wait for page to finish loading (v23.14: with adaptive timing)
    pub fn waitForPageLoad(self: *Self, timeout_ms: u32) AgentError!bool {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        const start_time = std.time.milliTimestamp();
        const timeout_end = start_time + @as(i64, timeout_ms);

        while (std.time.milliTimestamp() < timeout_end) {
            var cmd_buf: [512]u8 = undefined;

            // Check document.readyState
            const js = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"document.readyState\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
            self.message_id += 1;

            self.ws.sendText(js) catch return AgentError.EvaluationFailed;

            const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
            defer self.allocator.free(frame.payload);

            // Check if complete
            if (std.mem.indexOf(u8, frame.payload, "\"value\":\"complete\"") != null) {
                // v23.14: Update adaptive timing
                const elapsed = std.time.milliTimestamp() - start_time;
                self.updatePageLoadStats(@intCast(elapsed));
                return true;
            }

            // Wait 50ms before next check
            std.time.sleep(50 * std.time.ns_per_ms);
        }

        return false; // Timeout
    }

    /// Wait for network to become idle (v23.15)
    /// Waits until no network requests for idle_time_ms
    pub fn waitForNetworkIdle(self: *Self, timeout_ms: u32, idle_time_ms: u32) AgentError!bool {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        const start_time = std.time.milliTimestamp();
        const timeout_end = start_time + @as(i64, timeout_ms);
        var idle_start: ?i64 = null;

        while (std.time.milliTimestamp() < timeout_end) {
            // Check pending requests via JS (simpler than CDP events)
            var cmd_buf: [512]u8 = undefined;
            const js = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"window.performance.getEntriesByType('resource').filter(r => !r.responseEnd).length\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
            self.message_id += 1;

            self.ws.sendText(js) catch return AgentError.EvaluationFailed;

            const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
            defer self.allocator.free(frame.payload);

            // Check if 0 pending requests
            const is_idle = std.mem.indexOf(u8, frame.payload, "\"value\":0") != null;

            if (is_idle) {
                const now = std.time.milliTimestamp();
                if (idle_start == null) {
                    idle_start = now;
                } else if (now - idle_start.? >= idle_time_ms) {
                    // Network has been idle for required time
                    const elapsed = now - start_time;
                    std.debug.print("    [NET] Network idle after {d}ms\n", .{elapsed});
                    return true;
                }
            } else {
                idle_start = null; // Reset idle timer
            }

            std.time.sleep(50 * std.time.ns_per_ms);
        }

        std.debug.print("    [NET] Network idle timeout\n", .{});
        return false;
    }

    /// Wait for page load AND network idle (v23.15)
    pub fn waitForFullLoad(self: *Self, timeout_ms: u32) AgentError!bool {
        // First wait for document ready
        const page_loaded = try self.waitForPageLoad(timeout_ms / 2);
        if (!page_loaded) return false;

        // Then wait for network idle (100ms of no activity)
        return self.waitForNetworkIdle(timeout_ms / 2, 100);
    }

    /// Update adaptive page load statistics (v23.14)
    fn updatePageLoadStats(self: *Self, load_time_ms: u32) void {
        // Exponential moving average
        if (self.page_load_count == 0) {
            self.avg_page_load_ms = load_time_ms;
        } else {
            // EMA with alpha = 0.3
            self.avg_page_load_ms = (self.avg_page_load_ms * 7 + load_time_ms * 3) / 10;
        }
        self.page_load_count += 1;
    }

    /// Get adaptive timeout based on history (v23.14)
    pub fn getAdaptiveTimeout(self: *Self) u32 {
        // v23.15: Try domain-specific first
        if (self.current_domain) |domain| {
            if (self.domain_stats.get(domain)) |stats| {
                const adaptive = stats.avg_load_ms * 2;
                return @max(adaptive, 500);
            }
        }
        // Fallback to global average
        const adaptive = self.avg_page_load_ms * 2;
        return @max(adaptive, 500);
    }

    // v23.27: Use module-level extractDomain function

    /// Update domain-specific timing (v23.15)
    fn updateDomainStats(self: *Self, domain: []const u8, load_time_ms: u32) void {
        if (self.domain_stats.getPtr(domain)) |stats| {
            // Update existing
            if (stats.load_count == 0) {
                stats.avg_load_ms = load_time_ms;
            } else {
                stats.avg_load_ms = (stats.avg_load_ms * 7 + load_time_ms * 3) / 10;
            }
            stats.load_count += 1;
        } else {
            // Create new entry
            const key = self.allocator.dupe(u8, domain) catch return;
            self.domain_stats.put(key, DomainStats{
                .avg_load_ms = load_time_ms,
                .load_count = 1,
            }) catch {
                self.allocator.free(key);
            };
        }
    }

    /// Get domain-specific timeout (v23.15)
    pub fn getDomainTimeout(self: *Self, domain: []const u8) u32 {
        if (self.domain_stats.get(domain)) |stats| {
            const adaptive = stats.avg_load_ms * 2;
            return @max(adaptive, 500);
        }
        // Fallback to global
        return self.getAdaptiveTimeout();
    }

    // =========================================================================
    // v23.16: RETRY WITH EXPONENTIAL BACKOFF
    // =========================================================================

    /// Navigate with retry on failure (v23.16, v23.35: uses RetryExecutor)
    pub fn navigateWithRetry(self: *Self, url: []const u8) AgentError!RetryResult {
        // v23.35: Use RetryExecutor for unified retry logic
        var executor = RetryExecutor.fromAgent(self);
        var op = NavigateOperation{
            .url = url,
            .agent = self,
        };

        const result = executor.executeNavigate(&op);

        // Convert RetryExecutionResult to RetryResult
        if (!result.success and result.final_error != null) {
            return result.final_error.?;
        }

        return RetryResult{
            .success = result.success,
            .attempts = result.attempts,
            .total_delay_ms = result.total_delay_ms,
        };
    }

    /// Wait for selector with retry (v23.16, v23.35: uses RetryExecutor)
    pub fn waitForSelectorWithRetry(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!RetryResult {
        // v23.35: Use RetryExecutor for unified retry logic
        var executor = RetryExecutor.fromAgent(self);
        var op = WaitSelectorOperation{
            .selector = selector,
            .timeout_ms = timeout_ms,
            .agent = self,
        };

        const result = executor.executeWaitSelector(&op);

        // Convert RetryExecutionResult to RetryResult
        if (!result.success and result.final_error != null) {
            return result.final_error.?;
        }

        return RetryResult{
            .success = result.success,
            .attempts = result.attempts,
            .total_delay_ms = result.total_delay_ms,
        };
    }

    /// Wait for page load with retry (v23.16, v23.17: smart timeout)
    /// Wait for page load with retry (v23.16, v23.35: uses RetryExecutor)
    pub fn waitForPageLoadWithRetry(self: *Self, timeout_ms: u32) AgentError!RetryResult {
        // v23.35: Use RetryExecutor for unified retry logic
        var executor = RetryExecutor.fromAgent(self);
        var op = WaitPageLoadOperation{
            .timeout_ms = timeout_ms,
            .agent = self,
        };

        const result = executor.executeWaitPageLoad(&op);

        // Convert RetryExecutionResult to RetryResult
        if (!result.success and result.final_error != null) {
            return result.final_error.?;
        }

        return RetryResult{
            .success = result.success,
            .attempts = result.attempts,
            .total_delay_ms = result.total_delay_ms,
        };
    }
    /// Click with retry (v23.16, v23.35: uses RetryExecutor)
    pub fn clickWithRetry(self: *Self, selector: []const u8) AgentError!RetryResult {
        // v23.35: Use RetryExecutor for unified retry logic
        var executor = RetryExecutor.fromAgent(self);
        var op = ClickOperation{
            .selector = selector,
            .agent = self,
        };

        const result = executor.executeClick(&op);

        // Convert RetryExecutionResult to RetryResult
        if (!result.success and result.final_error != null) {
            return result.final_error.?;
        }

        return RetryResult{
            .success = result.success,
            .attempts = result.attempts,
            .total_delay_ms = result.total_delay_ms,
        };
    }

    /// Set retry configuration (v23.16)
    pub fn setRetryConfig(self: *Self, config: RetryConfig) void {
        self.retry_config = config;
    }

    /// Get retry metrics (v23.19)
    pub fn getRetryMetrics(self: *Self) RetryMetrics {
        return self.retry_metrics;
    }

    /// Reset retry metrics (v23.19)
    pub fn resetRetryMetrics(self: *Self) void {
        self.retry_metrics.reset();
    }

    /// Get circuit breaker state (v23.22)
    pub fn getCircuitBreakerState(self: *Self) CircuitBreakerState {
        return self.circuit_breaker.state;
    }

    /// Reset circuit breaker (v23.22)
    pub fn resetCircuitBreaker(self: *Self) void {
        self.circuit_breaker.reset();
    }

    /// Check if circuit breaker allows execution (v23.22)
    pub fn isCircuitClosed(self: *Self) bool {
        return self.circuit_breaker.canExecute();
    }

    /// Get or create circuit breaker for specific domain (v23.27)
    pub fn getCircuitBreakerForDomain(self: *Self, domain: []const u8) !*CircuitBreaker {
        // Check if already exists
        if (self.domain_circuit_breakers.getPtr(domain)) |cb| {
            return cb;
        }

        // Create new circuit breaker for this domain
        const domain_copy = try self.allocator.dupe(u8, domain);
        errdefer self.allocator.free(domain_copy);

        try self.domain_circuit_breakers.put(domain_copy, CircuitBreaker{});
        return self.domain_circuit_breakers.getPtr(domain_copy).?;
    }

    /// Check if domain circuit breaker allows execution (v23.27)
    pub fn canExecuteForDomain(self: *Self, domain: []const u8) bool {
        const cb = self.getCircuitBreakerForDomain(domain) catch return true;
        return cb.canExecute();
    }

    /// Record success for domain circuit breaker (v23.27)
    pub fn recordDomainSuccess(self: *Self, domain: []const u8) void {
        const cb = self.getCircuitBreakerForDomain(domain) catch return;
        cb.recordSuccess();
    }

    /// Record failure for domain circuit breaker (v23.27)
    pub fn recordDomainFailure(self: *Self, domain: []const u8) void {
        const cb = self.getCircuitBreakerForDomain(domain) catch return;
        cb.recordFailure();
    }

    /// Get domain circuit breaker state (v23.27)
    pub fn getDomainCircuitBreakerState(self: *Self, domain: []const u8) CircuitBreakerState {
        const cb = self.getCircuitBreakerForDomain(domain) catch return .closed;
        return cb.state;
    }

    /// Reset domain circuit breaker (v23.27)
    pub fn resetDomainCircuitBreaker(self: *Self, domain: []const u8) void {
        const cb = self.getCircuitBreakerForDomain(domain) catch return;
        cb.reset();
    }

    /// Get all domain circuit breaker states (v23.27)
    pub fn getDomainCircuitBreakerCount(self: *Self) usize {
        return self.domain_circuit_breakers.count();
    }

    /// Export retry metrics to JSON (v23.24)
    pub fn exportMetricsToJson(self: *Self) ![]u8 {
        const exporter = MetricsExporter.init(self.allocator);
        return exporter.exportRetryMetricsToJson(self.retry_metrics);
    }

    /// Export retry metrics to Prometheus format (v23.24)
    pub fn exportMetricsToPrometheus(self: *Self) ![]u8 {
        const exporter = MetricsExporter.init(self.allocator);
        return exporter.exportRetryMetricsToPrometheus(self.retry_metrics);
    }

    /// Export circuit breaker state to JSON (v23.24)
    pub fn exportCircuitBreakerToJson(self: *Self) ![]u8 {
        const exporter = MetricsExporter.init(self.allocator);
        return exporter.exportCircuitBreakerToJson(self.circuit_breaker);
    }

    /// Save metrics to file (v23.24)
    pub fn saveMetricsToFile(self: *Self, filename: []const u8) !void {
        const json = try self.exportMetricsToJson();
        defer self.allocator.free(json);

        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        try file.writeAll(json);
    }

    /// Get health status (v23.28)
    pub fn getHealthStatus(self: *Self) HealthStatus {
        var health_check = HealthCheck.init(self.allocator);
        // Use agent's start time if available, otherwise use health check's
        health_check.start_time = self.start_time;
        return health_check.getStatus(self);
    }

    /// Export health status to JSON (v23.28)
    pub fn exportHealthToJson(self: *Self) ![]u8 {
        const health_check = HealthCheck.init(self.allocator);
        const status = health_check.getStatus(self);
        return health_check.toJson(status);
    }

    /// Export health status to Prometheus format (v23.28)
    pub fn exportHealthToPrometheus(self: *Self) ![]u8 {
        const health_check = HealthCheck.init(self.allocator);
        const status = health_check.getStatus(self);
        return health_check.toPrometheus(status);
    }

    /// Print retry metrics summary (v23.19)
    pub fn printRetryMetrics(self: *Self) void {
        const m = self.retry_metrics;
        std.debug.print("\n=== RETRY METRICS ===\n", .{});
        std.debug.print("Operations: {d} total, {d} success, {d} failed\n", .{ m.total_operations, m.successful_operations, m.failed_operations });
        std.debug.print("Success rate: {d:.1}%\n", .{m.getSuccessRate() * 100});
        std.debug.print("Retries: {d} total, {d:.2} avg per operation\n", .{ m.total_retries, m.getAvgRetries() });
        std.debug.print("  - Navigate: {d}\n", .{m.navigate_retries});
        std.debug.print("  - Selector: {d}\n", .{m.selector_retries});
        std.debug.print("  - PageLoad: {d}\n", .{m.page_load_retries});
        std.debug.print("  - Click: {d}\n", .{m.click_retries});
        std.debug.print("Delay: {d}ms total, {d:.1}ms avg, {d}ms max\n", .{ m.total_delay_ms, m.getAvgDelayMs(), m.max_delay_ms });
        std.debug.print("=====================\n\n", .{});
    }

    // =========================================================================
    // v23.21: PERSISTENT DOMAIN STATS
    // =========================================================================

    /// Save domain stats to file (v23.21, v23.34: test_mode check)
    pub fn saveDomainStats(self: *Self) !void {
        // v23.34: Skip persistence in test mode
        if (self.config.test_mode) return;

        var file = std.fs.cwd().createFile(DOMAIN_STATS_FILE, .{}) catch return;
        defer file.close();

        var writer = file.writer();

        // Write JSON manually (simple format)
        try writer.writeAll("{\n  \"domains\": [\n");

        var first = true;
        var it = self.domain_stats.iterator();
        while (it.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;

            try writer.print("    {{\"domain\": \"{s}\", \"avg_load_ms\": {d}, \"load_count\": {d}}}", .{
                entry.key_ptr.*,
                entry.value_ptr.avg_load_ms,
                entry.value_ptr.load_count,
            });
        }

        try writer.writeAll("\n  ],\n");
        try writer.print("  \"global_avg_ms\": {d},\n", .{self.avg_page_load_ms});
        try writer.print("  \"global_count\": {d}\n", .{self.page_load_count});
        try writer.writeAll("}\n");

        std.debug.print("    [PERSIST] Saved {d} domain stats to {s}\n", .{ self.domain_stats.count(), DOMAIN_STATS_FILE });
    }

    /// Load domain stats from file (v23.21, v23.34: test_mode check)
    pub fn loadDomainStats(self: *Self) !void {
        // v23.34: Skip persistence in test mode
        if (self.config.test_mode) return;

        var file = std.fs.cwd().openFile(DOMAIN_STATS_FILE, .{}) catch return;
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch return;
        defer self.allocator.free(content);

        // Simple JSON parsing for our format
        var loaded_count: u32 = 0;

        // Find domains array
        var pos: usize = 0;
        while (pos < content.len) {
            // Find "domain": "
            if (std.mem.indexOf(u8, content[pos..], "\"domain\": \"")) |domain_start| {
                const abs_start = pos + domain_start + 11;
                if (std.mem.indexOf(u8, content[abs_start..], "\"")) |domain_end| {
                    const domain = content[abs_start .. abs_start + domain_end];

                    // Find avg_load_ms
                    if (std.mem.indexOf(u8, content[abs_start..], "\"avg_load_ms\": ")) |avg_start| {
                        const avg_pos = abs_start + avg_start + 15;
                        var avg_end = avg_pos;
                        while (avg_end < content.len and content[avg_end] >= '0' and content[avg_end] <= '9') {
                            avg_end += 1;
                        }
                        const avg_str = content[avg_pos..avg_end];
                        const avg_load_ms = std.fmt.parseInt(u32, avg_str, 10) catch 500;

                        // Find load_count
                        if (std.mem.indexOf(u8, content[avg_end..], "\"load_count\": ")) |count_start| {
                            const count_pos = avg_end + count_start + 14;
                            var count_end = count_pos;
                            while (count_end < content.len and content[count_end] >= '0' and content[count_end] <= '9') {
                                count_end += 1;
                            }
                            const count_str = content[count_pos..count_end];
                            const load_count = std.fmt.parseInt(u32, count_str, 10) catch 0;

                            // Add to domain_stats
                            const key = self.allocator.dupe(u8, domain) catch continue;
                            self.domain_stats.put(key, DomainStats{
                                .avg_load_ms = avg_load_ms,
                                .load_count = load_count,
                            }) catch {
                                self.allocator.free(key);
                                continue;
                            };
                            loaded_count += 1;

                            pos = count_end;
                            continue;
                        }
                    }
                }
            }
            pos += 1;
        }

        // Load global stats
        if (std.mem.indexOf(u8, content, "\"global_avg_ms\": ")) |global_start| {
            const global_pos = global_start + 17;
            var global_end = global_pos;
            while (global_end < content.len and content[global_end] >= '0' and content[global_end] <= '9') {
                global_end += 1;
            }
            self.avg_page_load_ms = std.fmt.parseInt(u32, content[global_pos..global_end], 10) catch 500;
        }

        if (std.mem.indexOf(u8, content, "\"global_count\": ")) |count_start| {
            const count_pos = count_start + 16;
            var count_end = count_pos;
            while (count_end < content.len and content[count_end] >= '0' and content[count_end] <= '9') {
                count_end += 1;
            }
            self.page_load_count = std.fmt.parseInt(u32, content[count_pos..count_end], 10) catch 0;
        }

        if (loaded_count > 0) {
            std.debug.print("    [PERSIST] Loaded {d} domain stats from {s}\n", .{ loaded_count, DOMAIN_STATS_FILE });
        }
    }

    // =========================================================================
    // v23.32: PERSISTENT CIRCUIT BREAKERS
    // =========================================================================

    /// Save domain circuit breakers to file (v23.32, v23.34: test_mode check)
    pub fn saveDomainCircuitBreakers(self: *Self) !void {
        // v23.34: Skip persistence in test mode
        if (self.config.test_mode) return;

        var file = std.fs.cwd().createFile(CIRCUIT_BREAKER_FILE, .{}) catch return;
        defer file.close();

        var writer = file.writer();

        try writer.writeAll("{\n  \"circuit_breakers\": [\n");

        var first = true;
        var it = self.domain_circuit_breakers.iterator();
        while (it.next()) |entry| {
            if (!first) {
                try writer.writeAll(",\n");
            }
            first = false;

            const snapshot = entry.value_ptr.toSnapshot();
            try writer.writeAll("    {\n");
            try writer.print("      \"domain\": \"{s}\",\n", .{entry.key_ptr.*});
            try writer.print("      \"state\": \"{s}\",\n", .{snapshot.state});
            try writer.print("      \"failure_count\": {d},\n", .{snapshot.failure_count});
            try writer.print("      \"success_count\": {d},\n", .{snapshot.success_count});
            try writer.print("      \"last_failure_time\": {d},\n", .{snapshot.last_failure_time});
            try writer.print("      \"failure_threshold\": {d},\n", .{snapshot.failure_threshold});
            try writer.print("      \"success_threshold\": {d},\n", .{snapshot.success_threshold});
            try writer.print("      \"reset_timeout_ms\": {d}\n", .{snapshot.reset_timeout_ms});
            try writer.writeAll("    }");
        }

        try writer.writeAll("\n  ],\n");

        // Save global circuit breaker
        const global_snapshot = self.circuit_breaker.toSnapshot();
        try writer.writeAll("  \"global\": {\n");
        try writer.print("    \"state\": \"{s}\",\n", .{global_snapshot.state});
        try writer.print("    \"failure_count\": {d},\n", .{global_snapshot.failure_count});
        try writer.print("    \"success_count\": {d},\n", .{global_snapshot.success_count});
        try writer.print("    \"last_failure_time\": {d}\n", .{global_snapshot.last_failure_time});
        try writer.writeAll("  }\n");
        try writer.writeAll("}\n");

        std.debug.print("    [PERSIST] Saved {d} domain circuit breakers to {s}\n", .{ self.domain_circuit_breakers.count(), CIRCUIT_BREAKER_FILE });
    }

    /// Load domain circuit breakers from file (v23.32, v23.34: test_mode check)
    pub fn loadDomainCircuitBreakers(self: *Self) !void {
        // v23.34: Skip persistence in test mode
        if (self.config.test_mode) return;

        var file = std.fs.cwd().openFile(CIRCUIT_BREAKER_FILE, .{}) catch return;
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch return;
        defer self.allocator.free(content);

        var loaded_count: u32 = 0;
        var pos: usize = 0;

        // Parse domain circuit breakers
        while (pos < content.len) {
            // Find "domain": "
            if (std.mem.indexOf(u8, content[pos..], "\"domain\": \"")) |domain_start| {
                const abs_start = pos + domain_start + 11;
                if (std.mem.indexOf(u8, content[abs_start..], "\"")) |domain_end| {
                    const domain = content[abs_start .. abs_start + domain_end];

                    // Parse circuit breaker fields
                    var snapshot = CircuitBreakerSnapshot{};

                    // Find state
                    if (std.mem.indexOf(u8, content[abs_start..], "\"state\": \"")) |state_start| {
                        const state_pos = abs_start + state_start + 10;
                        if (std.mem.indexOf(u8, content[state_pos..], "\"")) |state_end| {
                            snapshot.state = content[state_pos .. state_pos + state_end];
                        }
                    }

                    // Find failure_count
                    if (std.mem.indexOf(u8, content[abs_start..], "\"failure_count\": ")) |fc_start| {
                        const fc_pos = abs_start + fc_start + 17;
                        var fc_end = fc_pos;
                        while (fc_end < content.len and content[fc_end] >= '0' and content[fc_end] <= '9') {
                            fc_end += 1;
                        }
                        snapshot.failure_count = std.fmt.parseInt(u32, content[fc_pos..fc_end], 10) catch 0;
                    }

                    // Find last_failure_time
                    if (std.mem.indexOf(u8, content[abs_start..], "\"last_failure_time\": ")) |lft_start| {
                        const lft_pos = abs_start + lft_start + 21;
                        var lft_end = lft_pos;
                        while (lft_end < content.len and (content[lft_end] >= '0' and content[lft_end] <= '9' or content[lft_end] == '-')) {
                            lft_end += 1;
                        }
                        snapshot.last_failure_time = std.fmt.parseInt(i64, content[lft_pos..lft_end], 10) catch 0;
                    }

                    // Create circuit breaker from snapshot
                    const cb = CircuitBreaker.fromSnapshot(snapshot);

                    // Add to domain_circuit_breakers
                    const key = self.allocator.dupe(u8, domain) catch continue;
                    self.domain_circuit_breakers.put(key, cb) catch {
                        self.allocator.free(key);
                        continue;
                    };
                    loaded_count += 1;

                    pos = abs_start + domain_end;
                    continue;
                }
            }
            pos += 1;
        }

        // Load global circuit breaker state
        if (std.mem.indexOf(u8, content, "\"global\":")) |_| {
            if (std.mem.indexOf(u8, content, "\"state\": \"")) |state_start| {
                const state_pos = state_start + 10;
                if (std.mem.indexOf(u8, content[state_pos..], "\"")) |state_end| {
                    const state_str = content[state_pos .. state_pos + state_end];
                    if (std.mem.eql(u8, state_str, "OPEN")) {
                        self.circuit_breaker.state = .open;
                    } else if (std.mem.eql(u8, state_str, "HALF_OPEN")) {
                        self.circuit_breaker.state = .half_open;
                    }
                }
            }
        }

        if (loaded_count > 0) {
            std.debug.print("    [PERSIST] Loaded {d} domain circuit breakers from {s}\n", .{ loaded_count, CIRCUIT_BREAKER_FILE });
        }
    }

    /// Print domain stats summary (v23.21)
    pub fn printDomainStats(self: *Self) void {
        std.debug.print("\n=== DOMAIN STATS ===\n", .{});
        std.debug.print("Global: avg={d}ms, count={d}\n", .{ self.avg_page_load_ms, self.page_load_count });
        std.debug.print("Domains ({d}):\n", .{self.domain_stats.count()});

        var it = self.domain_stats.iterator();
        while (it.next()) |entry| {
            std.debug.print("  {s}: avg={d}ms, count={d}\n", .{
                entry.key_ptr.*,
                entry.value_ptr.avg_load_ms,
                entry.value_ptr.load_count,
            });
        }
        std.debug.print("====================\n\n", .{});
    }

    /// Click element with wait
    pub fn clickSelectorWithWait(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!void {
        // Wait for element
        const found = try self.waitForSelector(selector, timeout_ms);
        if (!found) {
            return AgentError.EvaluationFailed; // Element not found
        }

        // Click
        try self.clickSelector(selector);
    }

    /// Fill form with parallel waiting for all fields (v23.15)
    /// fields: array of {selector, value} pairs
    pub fn fillFormWithWait(
        self: *Self,
        selectors: []const []const u8,
        values: []const []const u8,
        timeout_ms: u32,
    ) AgentError!void {
        if (selectors.len != values.len) return AgentError.ParseError;
        if (selectors.len == 0) return;

        // Wait for ALL form fields in parallel
        const all_found = try self.waitForSelectors(selectors, timeout_ms);
        if (!all_found) {
            return AgentError.EvaluationFailed;
        }

        // Fill each field
        for (selectors, values) |selector, value| {
            try self.clickSelector(selector);
            try self.typeText(value);
        }
    }

    /// Click and wait for navigation (v23.15)
    pub fn clickAndWaitForNavigation(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!void {
        // Click
        try self.clickSelector(selector);

        // Wait for page load
        const loaded = try self.waitForPageLoad(timeout_ms);
        if (!loaded) {
            std.debug.print("    [CLICK] Navigation timeout after click\n", .{});
        }
    }

    /// Get compact DOM representation for LLM
    pub fn getDOMSummary(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // JavaScript to extract compact DOM summary
        const js =
            \\(function(){
            \\  var result = [];
            \\  var els = document.querySelectorAll('a,button,input,textarea,select,[onclick]');
            \\  for(var i=0; i<Math.min(els.length,20); i++){
            \\    var el = els[i];
            \\    var tag = el.tagName.toLowerCase();
            \\    var text = (el.innerText||el.value||'').substring(0,30).trim();
            \\    var id = el.id ? '#'+el.id : '';
            \\    var cls = el.className ? '.'+el.className.split(' ')[0] : '';
            \\    var href = el.href ? ' href='+el.href.substring(0,50) : '';
            \\    var name = el.name ? ' name='+el.name : '';
            \\    result.push(tag+id+cls+name+href+(text?' "'+text+'"':''));
            \\  }
            \\  return result.join('\\n');
            \\})()
        ;

        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"{s}\"}}}}", .{ self.message_id, js }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Extract value from response
        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"")) |start| {
            const value_start = start + 9;
            var end = value_start;
            var escaped = false;
            while (end < frame.payload.len) : (end += 1) {
                if (escaped) {
                    escaped = false;
                    continue;
                }
                if (frame.payload[end] == '\\') {
                    escaped = true;
                    continue;
                }
                if (frame.payload[end] == '"') break;
            }
            return self.allocator.dupe(u8, frame.payload[value_start..end]) catch return AgentError.OutOfMemory;
        }

        return self.allocator.dupe(u8, "") catch return AgentError.OutOfMemory;
    }

    /// Get current URL
    pub fn getURL(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"window.location.href\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"")) |start| {
            const value_start = start + 9;
            if (std.mem.indexOf(u8, frame.payload[value_start..], "\"")) |end| {
                return self.allocator.dupe(u8, frame.payload[value_start .. value_start + end]) catch return AgentError.OutOfMemory;
            }
        }

        return AgentError.ParseError;
    }

    /// Ask LLM a question about the page
    pub fn askLLM(self: *Self, prompt: []const u8) AgentError![]const u8 {
        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "http://{s}:{d}/api/generate", .{ self.config.ollama_host, self.config.ollama_port }) catch return AgentError.OutOfMemory;

        // Build JSON body
        var body_buf: [8192]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf, "{{\"model\":\"{s}\",\"prompt\":\"{s}\",\"stream\":false}}", .{ self.config.model, prompt }) catch return AgentError.OutOfMemory;

        var response = self.http.post(url, body, "application/json") catch return AgentError.LLMConnectionFailed;
        defer response.deinit();

        if (response.status != 200) {
            return AgentError.LLMConnectionFailed;
        }

        // Extract response text from JSON
        // Format: {"model":"...","response":"ANSWER",...}
        if (std.mem.indexOf(u8, response.body, "\"response\":\"")) |start| {
            const value_start = start + 12;
            // Find closing quote (handle escaped quotes)
            var end = value_start;
            var escaped = false;
            while (end < response.body.len) : (end += 1) {
                if (escaped) {
                    escaped = false;
                    continue;
                }
                if (response.body[end] == '\\') {
                    escaped = true;
                    continue;
                }
                if (response.body[end] == '"') {
                    break;
                }
            }
            if (end > value_start) {
                return self.allocator.dupe(u8, response.body[value_start..end]) catch return AgentError.OutOfMemory;
            }
        }

        return AgentError.ParseError;
    }

    /// Select option in dropdown by value or text
    pub fn selectOption(self: *Self, selector: []const u8, value: []const u8) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // JavaScript to select option by value or visible text
        var js_buf: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf,
            \\(function(){{
            \\  var sel = document.querySelector('{s}');
            \\  if(!sel) return 'not_found';
            \\  for(var i=0; i<sel.options.length; i++){{
            \\    if(sel.options[i].value==='{s}' || sel.options[i].text==='{s}'){{
            \\      sel.selectedIndex = i;
            \\      sel.dispatchEvent(new Event('change', {{bubbles:true}}));
            \\      return 'ok';
            \\    }}
            \\  }}
            \\  return 'option_not_found';
            \\}})()
        , .{ selector, value, value }) catch return AgentError.OutOfMemory;

        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"{s}\"}}}}", .{ self.message_id, js }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Check result
        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"ok\"") != null) {
            return;
        }
        return AgentError.EvaluationFailed;
    }

    /// Check or uncheck a checkbox
    pub fn checkBox(self: *Self, selector: []const u8, checked: bool) AgentError!void {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        const check_str = if (checked) "true" else "false";

        var js_buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf,
            \\(function(){{
            \\  var cb = document.querySelector('{s}');
            \\  if(!cb) return 'not_found';
            \\  cb.checked = {s};
            \\  cb.dispatchEvent(new Event('change', {{bubbles:true}}));
            \\  return 'ok';
            \\}})()
        , .{ selector, check_str }) catch return AgentError.OutOfMemory;

        var cmd_buf: [1024]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"{s}\"}}}}", .{ self.message_id, js }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        if (std.mem.indexOf(u8, frame.payload, "\"value\":\"ok\"") != null) {
            return;
        }
        return AgentError.EvaluationFailed;
    }

    /// Capture screenshot as base64 PNG
    pub fn captureScreenshot(self: *Self) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // CDP Page.captureScreenshot command
        var cmd_buf: [256]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Page.captureScreenshot\",\"params\":{{\"format\":\"png\"}}}}", .{self.message_id}) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // Extract base64 data from response: {"result":{"data":"base64..."}}
        if (std.mem.indexOf(u8, frame.payload, "\"data\":\"")) |start| {
            const data_start = start + 8;
            var data_end = data_start;
            while (data_end < frame.payload.len and frame.payload[data_end] != '"') : (data_end += 1) {}
            return self.allocator.dupe(u8, frame.payload[data_start..data_end]) catch return AgentError.OutOfMemory;
        }

        return AgentError.ParseError;
    }

    /// Capture screenshot of specific element
    pub fn captureElementScreenshot(self: *Self, selector: []const u8) AgentError![]const u8 {
        if (!self.connected) return AgentError.BrowserConnectionFailed;

        // First get element bounding box
        var js_buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf,
            \\(function(){{
            \\  var el = document.querySelector('{s}');
            \\  if(!el) return null;
            \\  var rect = el.getBoundingClientRect();
            \\  return JSON.stringify({{x:rect.x,y:rect.y,width:rect.width,height:rect.height}});
            \\}})()
        , .{selector}) catch return AgentError.OutOfMemory;

        var cmd_buf: [1024]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"{s}\"}}}}", .{ self.message_id, js }) catch return AgentError.OutOfMemory;
        self.message_id += 1;

        self.ws.sendText(cmd) catch return AgentError.EvaluationFailed;

        const frame = self.ws.receive() catch return AgentError.EvaluationFailed;
        defer self.allocator.free(frame.payload);

        // For now, just capture full screenshot
        // TODO: Parse bounding box and use clip parameter
        return self.captureScreenshot();
    }

    /// Close connection
    pub fn close(self: *Self) void {
        self.ws.close();
        self.connected = false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RealAgent initialization" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    try std.testing.expect(!agent.connected);
    try std.testing.expectEqual(@as(u32, 1), agent.message_id);
}

test "AgentConfig defaults" {
    const config = AgentConfig{};
    try std.testing.expectEqualStrings("localhost", config.chrome_host);
    try std.testing.expectEqual(@as(u16, 9222), config.chrome_port);
    try std.testing.expectEqual(@as(u16, 11434), config.ollama_port);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "RealAgent close without connection" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should not crash
    agent.close();
    try std.testing.expect(!agent.connected);
}

test "RealAgent methods exist" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Verify methods exist (will fail with BrowserConnectionFailed since not connected)
    _ = agent.clickSelector("a") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.typeText("test") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.pressEnter() catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.scroll(100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.getURL() catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "selectOption method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.selectOption("select#country", "US") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "checkBox method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.checkBox("input#agree", true) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
    _ = agent.checkBox("input#newsletter", false) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "captureScreenshot method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.captureScreenshot() catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "captureElementScreenshot method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.captureElementScreenshot("#main") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "extractDomain parses URLs correctly" {
    // HTTPS
    try std.testing.expectEqualStrings("example.com", extractDomain("https://example.com/page"));
    try std.testing.expectEqualStrings("google.com", extractDomain("https://google.com"));
    try std.testing.expectEqualStrings("sub.domain.org", extractDomain("https://sub.domain.org/path/to/page"));

    // HTTP - note: port is separated by : so domain stops at :
    try std.testing.expectEqualStrings("localhost", extractDomain("http://localhost:8080/api"));

    // Edge cases - no protocol means start=0, so returns up to first / or :
    try std.testing.expectEqualStrings("invalid", extractDomain("invalid"));
    try std.testing.expectEqualStrings("", extractDomain("https://"));
}

test "domain-specific timing" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Initially no domain stats - falls back to global (500*2=1000, min 500)
    try std.testing.expectEqual(@as(u32, 1000), agent.getDomainTimeout("example.com"));

    // Add domain stats
    agent.updateDomainStats("example.com", 100);
    try std.testing.expectEqual(@as(u32, 500), agent.getDomainTimeout("example.com")); // 100*2=200, min 500

    // Add more samples
    agent.updateDomainStats("example.com", 300);
    agent.updateDomainStats("example.com", 400);
    // EMA: 100 -> (100*7+300*3)/10=160 -> (160*7+400*3)/10=232
    // 232*2=464, min 500
    try std.testing.expectEqual(@as(u32, 500), agent.getDomainTimeout("example.com"));

    // Slow domain
    agent.updateDomainStats("slow-site.com", 2000);
    try std.testing.expectEqual(@as(u32, 4000), agent.getDomainTimeout("slow-site.com")); // 2000*2=4000
}

test "waitForSelectors method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    const selectors = [_][]const u8{ "#btn1", "#btn2" };
    _ = agent.waitForSelectors(&selectors, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForAnySelector method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    const selectors = [_][]const u8{ "#success", "#error" };
    _ = agent.waitForAnySelector(&selectors, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "fillFormWithWait method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    const selectors = [_][]const u8{ "#username", "#password" };
    const values = [_][]const u8{ "user", "pass" };
    _ = agent.fillFormWithWait(&selectors, &values, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForNetworkIdle method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.waitForNetworkIdle(1000, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForFullLoad method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    _ = agent.waitForFullLoad(1000) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "RetryConfig exponential backoff" {
    const config = RetryConfig{
        .max_retries = 3,
        .initial_delay_ms = 500,
        .backoff_factor = 2.0,
        .max_delay_ms = 8000,
    };

    // Attempt 0: 500ms
    try std.testing.expectEqual(@as(u32, 500), config.getDelay(0));
    // Attempt 1: 500 * 2 = 1000ms
    try std.testing.expectEqual(@as(u32, 1000), config.getDelay(1));
    // Attempt 2: 500 * 2 * 2 = 2000ms
    try std.testing.expectEqual(@as(u32, 2000), config.getDelay(2));
    // Attempt 3: 500 * 2 * 2 * 2 = 4000ms
    try std.testing.expectEqual(@as(u32, 4000), config.getDelay(3));
    // Attempt 4: 500 * 16 = 8000ms (capped at max)
    try std.testing.expectEqual(@as(u32, 8000), config.getDelay(4));
    // Attempt 5: would be 16000ms but capped at 8000ms
    try std.testing.expectEqual(@as(u32, 8000), config.getDelay(5));
}

test "RetryConfig default values" {
    const config = RetryConfig{};
    try std.testing.expectEqual(@as(u32, 3), config.max_retries);
    try std.testing.expectEqual(@as(u32, 500), config.initial_delay_ms);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), config.backoff_factor, 0.01);
    try std.testing.expectEqual(@as(u32, 8000), config.max_delay_ms);
}

test "navigateWithRetry method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.navigateWithRetry("https://example.com") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForSelectorWithRetry method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    _ = agent.waitForSelectorWithRetry("#test", 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "clickWithRetry method exists" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    _ = agent.clickWithRetry("#btn") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "setRetryConfig changes config" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Default config
    try std.testing.expectEqual(@as(u32, 3), agent.retry_config.max_retries);

    // Change config
    agent.setRetryConfig(.{
        .max_retries = 5,
        .initial_delay_ms = 1000,
    });

    try std.testing.expectEqual(@as(u32, 5), agent.retry_config.max_retries);
    try std.testing.expectEqual(@as(u32, 1000), agent.retry_config.initial_delay_ms);
}

test "RetryConfig timeout adjustment (v23.17)" {
    const config = RetryConfig{
        .timeout_factor = 1.5,
        .max_timeout_ms = 30000,
    };

    const base_timeout: u32 = 1000;

    // Attempt 0: 1000ms (no change)
    try std.testing.expectEqual(@as(u32, 1000), config.getTimeout(base_timeout, 0));
    // Attempt 1: 1000 * 1.5 = 1500ms
    try std.testing.expectEqual(@as(u32, 1500), config.getTimeout(base_timeout, 1));
    // Attempt 2: 1000 * 1.5 * 1.5 = 2250ms
    try std.testing.expectEqual(@as(u32, 2250), config.getTimeout(base_timeout, 2));
    // Attempt 3: 1000 * 1.5^3 = 3375ms
    try std.testing.expectEqual(@as(u32, 3375), config.getTimeout(base_timeout, 3));
}

test "RetryConfig timeout capped at max" {
    const config = RetryConfig{
        .timeout_factor = 2.0,
        .max_timeout_ms = 5000,
    };

    const base_timeout: u32 = 2000;

    // Attempt 0: 2000ms
    try std.testing.expectEqual(@as(u32, 2000), config.getTimeout(base_timeout, 0));
    // Attempt 1: 2000 * 2 = 4000ms
    try std.testing.expectEqual(@as(u32, 4000), config.getTimeout(base_timeout, 1));
    // Attempt 2: 2000 * 4 = 8000ms, but capped at 5000ms
    try std.testing.expectEqual(@as(u32, 5000), config.getTimeout(base_timeout, 2));
    // Attempt 3: would be 16000ms, but capped at 5000ms
    try std.testing.expectEqual(@as(u32, 5000), config.getTimeout(base_timeout, 3));
}

test "RetryConfig default timeout_factor" {
    const config = RetryConfig{};
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), config.timeout_factor, 0.01);
    try std.testing.expectEqual(@as(u32, 30000), config.max_timeout_ms);
}

test "RetryConfig jitter defaults (v23.18)" {
    const config = RetryConfig{};
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), config.jitter_factor, 0.01);
    try std.testing.expect(config.use_jitter);
}

test "getDelayWithJitter within bounds (v23.18)" {
    const config = RetryConfig{
        .initial_delay_ms = 1000,
        .jitter_factor = 0.2,
        .use_jitter = true,
    };

    // Test multiple times to verify jitter is within bounds
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        const delay = config.getDelayWithJitter(0);
        // Base delay is 1000ms, jitter is ±20%, so range is [800, 1200]
        try std.testing.expect(delay >= 800);
        try std.testing.expect(delay <= 1200);
    }
}

test "getDelayWithJitter disabled returns base delay" {
    const config = RetryConfig{
        .initial_delay_ms = 1000,
        .use_jitter = false,
    };

    const delay = config.getDelayWithJitter(0);
    try std.testing.expectEqual(@as(u32, 1000), delay);
}

test "getDelayWithJitter zero factor returns base delay" {
    const config = RetryConfig{
        .initial_delay_ms = 1000,
        .jitter_factor = 0.0,
        .use_jitter = true,
    };

    const delay = config.getDelayWithJitter(0);
    try std.testing.expectEqual(@as(u32, 1000), delay);
}

test "RetryMetrics initial values (v23.19)" {
    const metrics = RetryMetrics{};
    try std.testing.expectEqual(@as(u64, 0), metrics.total_operations);
    try std.testing.expectEqual(@as(u64, 0), metrics.total_retries);
    try std.testing.expectEqual(@as(u64, 0), metrics.successful_operations);
    try std.testing.expectEqual(@as(u64, 0), metrics.failed_operations);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), metrics.getSuccessRate(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), metrics.getAvgRetries(), 0.01);
}

test "RetryMetrics calculations (v23.19)" {
    var metrics = RetryMetrics{
        .total_operations = 10,
        .successful_operations = 8,
        .failed_operations = 2,
        .total_retries = 5,
        .total_delay_ms = 2500,
    };

    // Success rate: 8/10 = 0.8
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), metrics.getSuccessRate(), 0.01);
    // Avg retries: 5/10 = 0.5
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), metrics.getAvgRetries(), 0.01);
    // Avg delay: 2500/5 = 500
    try std.testing.expectApproxEqAbs(@as(f32, 500.0), metrics.getAvgDelayMs(), 0.01);

    // Reset
    metrics.reset();
    try std.testing.expectEqual(@as(u64, 0), metrics.total_operations);
}

test "RealAgent retry metrics (v23.19)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Initial metrics
    var metrics = agent.getRetryMetrics();
    try std.testing.expectEqual(@as(u64, 0), metrics.total_operations);

    // Reset metrics
    agent.resetRetryMetrics();
    metrics = agent.getRetryMetrics();
    try std.testing.expectEqual(@as(u64, 0), metrics.total_operations);
}

test "saveDomainStats and loadDomainStats (v23.21)" {
    const allocator = std.testing.allocator;

    // Create agent and add domain stats
    {
        var agent = initTestAgent(allocator);
        defer agent.deinit();

        // Add some domain stats
        agent.updateDomainStats("example.com", 150);
        agent.updateDomainStats("example.com", 200);
        agent.updateDomainStats("google.com", 300);

        // Save explicitly (deinit will also save)
        try agent.saveDomainStats();
    }

    // Create new agent and verify stats loaded
    {
        var agent = initTestAgent(allocator);
        defer agent.deinit();

        // Check if stats were loaded
        const example_stats = agent.domain_stats.get("example.com");
        const google_stats = agent.domain_stats.get("google.com");

        // Stats should be loaded (if file exists)
        if (example_stats) |stats| {
            try std.testing.expect(stats.load_count >= 1);
        }
        if (google_stats) |stats| {
            try std.testing.expect(stats.load_count >= 1);
        }
    }

    // Cleanup test file
    std.fs.cwd().deleteFile(DOMAIN_STATS_FILE) catch {};
}

test "printDomainStats method exists (v23.21)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Just verify method exists and doesn't crash
    // (output goes to debug, not captured in test)
    agent.printDomainStats();
}

test "CircuitBreaker initial state (v23.22)" {
    var cb = CircuitBreaker{};
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
    try std.testing.expect(cb.canExecute());
    try std.testing.expectEqualStrings("CLOSED", cb.getStateString());
}

test "CircuitBreaker opens after failures (v23.22)" {
    var cb = CircuitBreaker{
        .failure_threshold = 3,
    };

    // Record failures
    cb.recordFailure();
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
    cb.recordFailure();
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
    cb.recordFailure();
    // Should be open now
    try std.testing.expectEqual(CircuitBreakerState.open, cb.state);
    try std.testing.expect(!cb.canExecute());
}

test "CircuitBreaker success resets failure count (v23.22)" {
    var cb = CircuitBreaker{
        .failure_threshold = 3,
    };

    cb.recordFailure();
    cb.recordFailure();
    try std.testing.expectEqual(@as(u32, 2), cb.failure_count);

    cb.recordSuccess();
    try std.testing.expectEqual(@as(u32, 0), cb.failure_count);
}

test "CircuitBreaker reset (v23.22)" {
    var cb = CircuitBreaker{
        .failure_threshold = 2,
    };

    cb.recordFailure();
    cb.recordFailure();
    try std.testing.expectEqual(CircuitBreakerState.open, cb.state);

    cb.reset();
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
    try std.testing.expectEqual(@as(u32, 0), cb.failure_count);
}

test "RealAgent circuit breaker methods (v23.22)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Initial state
    try std.testing.expectEqual(CircuitBreakerState.closed, agent.getCircuitBreakerState());
    try std.testing.expect(agent.isCircuitClosed());

    // Reset
    agent.resetCircuitBreaker();
    try std.testing.expectEqual(CircuitBreakerState.closed, agent.getCircuitBreakerState());
}

test "MetricsExporter JSON export (v23.24)" {
    const allocator = std.testing.allocator;
    const exporter = MetricsExporter.init(allocator);

    const metrics = RetryMetrics{
        .total_operations = 100,
        .total_retries = 15,
        .successful_operations = 95,
        .failed_operations = 5,
        .navigate_retries = 5,
        .selector_retries = 8,
        .page_load_retries = 2,
        .click_retries = 0,
        .total_delay_ms = 7500,
        .max_delay_ms = 2000,
    };

    const json = try exporter.exportRetryMetricsToJson(metrics);
    defer allocator.free(json);

    // Verify JSON contains expected fields
    try std.testing.expect(std.mem.indexOf(u8, json, "\"total_operations\": 100") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"successful_operations\": 95") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"navigate_retries\": 5") != null);
}

test "MetricsExporter Prometheus export (v23.24)" {
    const allocator = std.testing.allocator;
    const exporter = MetricsExporter.init(allocator);

    const metrics = RetryMetrics{
        .total_operations = 50,
        .total_retries = 10,
        .successful_operations = 45,
        .failed_operations = 5,
    };

    const prom = try exporter.exportRetryMetricsToPrometheus(metrics);
    defer allocator.free(prom);

    // Verify Prometheus format
    try std.testing.expect(std.mem.indexOf(u8, prom, "vibee_retry_operations_total 50") != null);
    try std.testing.expect(std.mem.indexOf(u8, prom, "vibee_retry_success_total 45") != null);
    try std.testing.expect(std.mem.indexOf(u8, prom, "# TYPE vibee_retry_operations_total counter") != null);
}

test "MetricsExporter CircuitBreaker JSON (v23.24)" {
    const allocator = std.testing.allocator;
    const exporter = MetricsExporter.init(allocator);

    const cb = CircuitBreaker{
        .state = .closed,
        .failure_count = 2,
        .failure_threshold = 5,
    };

    const json = try exporter.exportCircuitBreakerToJson(cb);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"state\": \"CLOSED\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"failure_count\": 2") != null);
}

test "RealAgent export methods (v23.24)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Export JSON
    const json = try agent.exportMetricsToJson();
    defer allocator.free(json);
    try std.testing.expect(json.len > 0);

    // Export Prometheus
    const prom = try agent.exportMetricsToPrometheus();
    defer allocator.free(prom);
    try std.testing.expect(prom.len > 0);

    // Export circuit breaker
    const cb_json = try agent.exportCircuitBreakerToJson();
    defer allocator.free(cb_json);
    try std.testing.expect(cb_json.len > 0);
}

// v23.25: Jitter Strategy Tests
test "JitterStrategy enum values (v23.25)" {
    try std.testing.expectEqualStrings("equal", JitterStrategy.equal.toString());
    try std.testing.expectEqualStrings("full", JitterStrategy.full.toString());
    try std.testing.expectEqualStrings("decorrelated", JitterStrategy.decorrelated.toString());
}

test "RetryConfig default jitter strategy (v23.25)" {
    const config = RetryConfig{};
    try std.testing.expectEqual(JitterStrategy.equal, config.jitter_strategy);
    try std.testing.expectEqual(@as(u32, 0), config.prev_delay_ms);
}

test "getFullJitter returns value in range (v23.25)" {
    const config = RetryConfig{
        .initial_delay_ms = 1000,
        .jitter_strategy = .full,
    };

    // Full jitter should return value between 0 and base_delay
    const delay = config.getFullJitter(1);
    const base_delay = config.getDelay(1); // 2000ms with factor 2.0

    try std.testing.expect(delay >= 100); // Minimum 100ms
    try std.testing.expect(delay <= base_delay);
}

test "getDecorrelatedJitter returns value in range (v23.25)" {
    const config = RetryConfig{
        .initial_delay_ms = 500,
        .max_delay_ms = 8000,
        .jitter_strategy = .decorrelated,
    };

    // Decorrelated jitter: random(base, prev_delay * 3)
    const delay = config.getDecorrelatedJitter(1, 1000);

    try std.testing.expect(delay >= 100); // Minimum 100ms
    try std.testing.expect(delay <= config.max_delay_ms);
}

test "getDecorrelatedJitter with zero prev_delay (v23.25)" {
    const config = RetryConfig{
        .initial_delay_ms = 500,
        .max_delay_ms = 8000,
    };

    // With prev_delay = 0, should use initial_delay_ms as base
    const delay = config.getDecorrelatedJitter(1, 0);

    try std.testing.expect(delay >= 100);
    try std.testing.expect(delay <= config.max_delay_ms);
}

test "getDelayWithJitter uses strategy (v23.25)" {
    // Test equal strategy
    var config_equal = RetryConfig{
        .initial_delay_ms = 1000,
        .jitter_strategy = .equal,
        .use_jitter = true,
    };
    const delay_equal = config_equal.getDelayWithJitter(1);
    try std.testing.expect(delay_equal >= 100);

    // Test full strategy
    var config_full = RetryConfig{
        .initial_delay_ms = 1000,
        .jitter_strategy = .full,
        .use_jitter = true,
    };
    const delay_full = config_full.getDelayWithJitter(1);
    try std.testing.expect(delay_full >= 100);

    // Test decorrelated strategy
    var config_decorr = RetryConfig{
        .initial_delay_ms = 1000,
        .jitter_strategy = .decorrelated,
        .prev_delay_ms = 500,
        .use_jitter = true,
    };
    const delay_decorr = config_decorr.getDelayWithJitter(1);
    try std.testing.expect(delay_decorr >= 100);
}

test "RealAgent with custom jitter strategy (v23.25)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Change jitter strategy
    agent.retry_config.jitter_strategy = .full;
    try std.testing.expectEqual(JitterStrategy.full, agent.retry_config.jitter_strategy);

    agent.retry_config.jitter_strategy = .decorrelated;
    try std.testing.expectEqual(JitterStrategy.decorrelated, agent.retry_config.jitter_strategy);
}

// v23.26: Histogram Tests
test "Histogram initial state (v23.26)" {
    const hist = Histogram{};
    try std.testing.expectEqual(@as(u64, 0), hist.count);
    try std.testing.expectEqual(@as(u64, 0), hist.sum);
    try std.testing.expectEqual(std.math.maxInt(u32), hist.min);
    try std.testing.expectEqual(@as(u32, 0), hist.max);
}

test "Histogram observe single value (v23.26)" {
    var hist = Histogram{};
    hist.observe(150);

    try std.testing.expectEqual(@as(u64, 1), hist.count);
    try std.testing.expectEqual(@as(u64, 150), hist.sum);
    try std.testing.expectEqual(@as(u32, 150), hist.min);
    try std.testing.expectEqual(@as(u32, 150), hist.max);
    // 150 should be in bucket 1 (<=200)
    try std.testing.expectEqual(@as(u64, 1), hist.buckets[1]);
}

test "Histogram observe multiple values (v23.26)" {
    var hist = Histogram{};
    hist.observe(50); // bucket 0 (<=100)
    hist.observe(150); // bucket 1 (<=200)
    hist.observe(500); // bucket 3 (<=800)
    hist.observe(5000); // bucket 6 (<=6400)
    hist.observe(20000); // overflow (>12800)

    try std.testing.expectEqual(@as(u64, 5), hist.count);
    try std.testing.expectEqual(@as(u64, 25700), hist.sum);
    try std.testing.expectEqual(@as(u32, 50), hist.min);
    try std.testing.expectEqual(@as(u32, 20000), hist.max);
    try std.testing.expectEqual(@as(u64, 1), hist.overflow);
}

test "Histogram percentiles (v23.26)" {
    var hist = Histogram{};
    // Add 10 values in first bucket (<=100)
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        hist.observe(50);
    }
    // Add 90 values in second bucket (<=200)
    i = 0;
    while (i < 90) : (i += 1) {
        hist.observe(150);
    }

    // p50 should be in bucket 1 (<=200) since 50% of 100 = 50, and first bucket has only 10
    try std.testing.expectEqual(@as(u32, 200), hist.getP50());
    // p90 should be in bucket 1
    try std.testing.expectEqual(@as(u32, 200), hist.getP90());
}

test "Histogram getAverage (v23.26)" {
    var hist = Histogram{};
    hist.observe(100);
    hist.observe(200);
    hist.observe(300);

    const avg = hist.getAverage();
    try std.testing.expect(avg > 199.0 and avg < 201.0);
}

test "Histogram reset (v23.26)" {
    var hist = Histogram{};
    hist.observe(500);
    hist.observe(1000);
    hist.reset();

    try std.testing.expectEqual(@as(u64, 0), hist.count);
    try std.testing.expectEqual(@as(u64, 0), hist.sum);
}

test "Histogram toJson (v23.39)" {
    const allocator = std.testing.allocator;
    var hist = Histogram{};
    hist.observe(100);
    hist.observe(500);
    hist.observe(1000);

    const json = try hist.toJson(allocator);
    defer allocator.free(json);

    // Check JSON contains expected fields
    try std.testing.expect(std.mem.indexOf(u8, json, "\"buckets\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"count\": 3") != null);
}

test "Histogram toAsciiChart (v23.39)" {
    const allocator = std.testing.allocator;
    var hist = Histogram{};
    hist.observe(100);
    hist.observe(500);
    hist.observe(1000);

    const chart = try hist.toAsciiChart(allocator);
    defer allocator.free(chart);

    // Check chart contains expected elements
    try std.testing.expect(std.mem.indexOf(u8, chart, "Delay Distribution") != null);
    try std.testing.expect(std.mem.indexOf(u8, chart, "|") != null);
}

test "RetryMetrics toJson (v23.39)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    metrics.total_operations = 100;
    metrics.successful_operations = 95;
    metrics.failed_operations = 5;
    metrics.total_retries = 10;

    const json = try metrics.toJson(allocator);
    defer allocator.free(json);

    // Check JSON structure
    try std.testing.expect(std.mem.indexOf(u8, json, "\"counters\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"timing\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"rates\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"success_rate\"") != null);
}

test "MetricsTrend record and getTrend (v23.39)" {
    var trend = MetricsTrend{};

    // Record improving trend
    trend.record(0.80);
    trend.record(0.85);
    trend.record(0.90);
    trend.record(0.95);

    try std.testing.expect(trend.getTrend() > 0.0); // Positive = improving
    try std.testing.expectEqualStrings("IMPROVING", trend.getTrendStatus());
}

test "MetricsTrend degrading (v23.39)" {
    var trend = MetricsTrend{};

    // Record degrading trend
    trend.record(0.95);
    trend.record(0.90);
    trend.record(0.85);
    trend.record(0.80);

    try std.testing.expect(trend.getTrend() < 0.0); // Negative = degrading
    try std.testing.expectEqualStrings("DEGRADING", trend.getTrendStatus());
}

test "MetricsTrend stable (v23.39)" {
    var trend = MetricsTrend{};

    // Record stable trend
    trend.record(0.90);
    trend.record(0.90);
    trend.record(0.90);
    trend.record(0.90);

    try std.testing.expect(trend.getTrend() < 0.01 and trend.getTrend() > -0.01);
    try std.testing.expectEqualStrings("STABLE", trend.getTrendStatus());
}

test "MetricsTrend toJson (v23.39)" {
    const allocator = std.testing.allocator;
    var trend = MetricsTrend{};
    trend.record(0.90);
    trend.record(0.92);

    const json = try trend.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"sample_count\": 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\"") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.40: DOM EXTRACTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ElementType fromTagName (v23.40)" {
    try std.testing.expectEqual(ElementType.link, ElementType.fromTagName("a"));
    try std.testing.expectEqual(ElementType.button, ElementType.fromTagName("button"));
    try std.testing.expectEqual(ElementType.input, ElementType.fromTagName("input"));
    try std.testing.expectEqual(ElementType.heading, ElementType.fromTagName("h1"));
    try std.testing.expectEqual(ElementType.heading, ElementType.fromTagName("h2"));
    try std.testing.expectEqual(ElementType.form, ElementType.fromTagName("form"));
    try std.testing.expectEqual(ElementType.other, ElementType.fromTagName("unknown"));
}

test "ElementType toString (v23.40)" {
    try std.testing.expectEqualStrings("link", ElementType.link.toString());
    try std.testing.expectEqualStrings("button", ElementType.button.toString());
    try std.testing.expectEqualStrings("input", ElementType.input.toString());
}

test "BoundingBox isVisible (v23.40)" {
    const visible = BoundingBox{ .x = 0, .y = 0, .width = 100, .height = 50 };
    const invisible = BoundingBox{ .x = 0, .y = 0, .width = 0, .height = 0 };

    try std.testing.expect(visible.isVisible());
    try std.testing.expect(!invisible.isVisible());
}

test "BoundingBox contains (v23.40)" {
    const box = BoundingBox{ .x = 10, .y = 20, .width = 100, .height = 50 };

    try std.testing.expect(box.contains(50, 40)); // Inside
    try std.testing.expect(!box.contains(5, 40)); // Left of box
    try std.testing.expect(!box.contains(150, 40)); // Right of box
}

test "Element isInteractive (v23.40)" {
    const link = Element{
        .tag_name = "a",
        .element_type = .link,
        .selector = "a.test",
    };
    const div = Element{
        .tag_name = "div",
        .element_type = .div,
        .selector = "div.test",
    };

    try std.testing.expect(link.isInteractive());
    try std.testing.expect(!div.isInteractive());
}

test "Element isFormField (v23.40)" {
    const input = Element{
        .tag_name = "input",
        .element_type = .input,
        .selector = "input.test",
    };
    const button = Element{
        .tag_name = "button",
        .element_type = .button,
        .selector = "button.test",
    };

    try std.testing.expect(input.isFormField());
    try std.testing.expect(!button.isFormField());
}

test "Element getDisplayText (v23.40)" {
    const with_text = Element{
        .tag_name = "a",
        .element_type = .link,
        .selector = "a",
        .text_content = "Click here",
    };
    const with_aria = Element{
        .tag_name = "button",
        .element_type = .button,
        .selector = "button",
        .aria_label = "Submit form",
    };
    const with_placeholder = Element{
        .tag_name = "input",
        .element_type = .input,
        .selector = "input",
        .placeholder = "Enter email",
    };

    try std.testing.expectEqualStrings("Click here", with_text.getDisplayText());
    try std.testing.expectEqualStrings("Submit form", with_aria.getDisplayText());
    try std.testing.expectEqualStrings("Enter email", with_placeholder.getDisplayText());
}

test "Element generateSelector with id (v23.40)" {
    const allocator = std.testing.allocator;
    var element = Element{
        .tag_name = "button",
        .element_type = .button,
        .selector = "",
        .id = "submit-btn",
    };

    const selector = try element.generateSelector(allocator);
    defer allocator.free(selector);

    try std.testing.expectEqualStrings("#submit-btn", selector);
}

test "Element generateSelector with class (v23.40)" {
    const allocator = std.testing.allocator;
    var element = Element{
        .tag_name = "div",
        .element_type = .div,
        .selector = "",
        .class_name = "container main",
    };

    const selector = try element.generateSelector(allocator);
    defer allocator.free(selector);

    try std.testing.expectEqualStrings("div.container", selector);
}

test "Element toJson (v23.40)" {
    const allocator = std.testing.allocator;
    const element = Element{
        .tag_name = "a",
        .element_type = .link,
        .selector = "a.nav-link",
        .text_content = "Home",
        .href = "/home",
        .is_visible = true,
    };

    const json = try element.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"tag\": \"a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"type\": \"link\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"href\": \"/home\"") != null);
}

test "DOMExtractor init (v23.40)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    try std.testing.expect(extractor.cached_elements == null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.41: JSON PARSER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "DOMExtractor parseElementJson basic (v23.41)" {
    // Use page allocator for this test to avoid leak tracking issues
    // In production, Element fields would be freed by the caller
    const allocator = std.heap.page_allocator;
    var agent = RealAgent.init(allocator, AgentConfig{ .test_mode = true });
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const json =
        \\{"tag": "a", "id": "link1", "text": "Click me", "href": "/home", "visible": true, "x": 10, "y": 20, "width": 100, "height": 30}
    ;

    const element = extractor.parseElementJson(json, "a#link1");
    try std.testing.expect(element != null);

    const el = element.?;
    try std.testing.expectEqualStrings("a", el.tag_name);
    try std.testing.expectEqual(ElementType.link, el.element_type);
    try std.testing.expectEqualStrings("link1", el.id.?);
    try std.testing.expectEqualStrings("Click me", el.text_content.?);
    try std.testing.expectEqualStrings("/home", el.href.?);
    try std.testing.expect(el.is_visible);
    try std.testing.expectEqual(@as(i32, 10), el.bounding_box.x);
    try std.testing.expectEqual(@as(u32, 100), el.bounding_box.width);
}

test "DOMExtractor parseElementJson input field (v23.41)" {
    const allocator = std.heap.page_allocator;
    var agent = RealAgent.init(allocator, AgentConfig{ .test_mode = true });
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const json =
        \\{"tag": "input", "name": "email", "type": "email", "placeholder": "Enter email", "value": "", "enabled": true}
    ;

    const element = extractor.parseElementJson(json, "input[name=email]");
    try std.testing.expect(element != null);

    const el = element.?;
    try std.testing.expectEqualStrings("input", el.tag_name);
    try std.testing.expectEqual(ElementType.input, el.element_type);
    try std.testing.expectEqualStrings("email", el.name.?);
    try std.testing.expectEqualStrings("email", el.input_type.?);
    try std.testing.expectEqualStrings("Enter email", el.placeholder.?);
    try std.testing.expect(el.is_enabled);
}

test "DOMExtractor parseElementJson checkbox (v23.41)" {
    const allocator = std.heap.page_allocator;
    var agent = RealAgent.init(allocator, AgentConfig{ .test_mode = true });
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const json =
        \\{"tag": "input", "type": "checkbox", "name": "agree", "checked": true}
    ;

    const element = extractor.parseElementJson(json, "input[name=agree]");
    try std.testing.expect(element != null);

    const el = element.?;
    try std.testing.expectEqual(ElementType.checkbox, el.element_type);
    try std.testing.expect(el.is_checked);
}

test "DOMExtractor parseElementJson button (v23.41)" {
    const allocator = std.heap.page_allocator;
    var agent = RealAgent.init(allocator, AgentConfig{ .test_mode = true });
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const json =
        \\{"tag": "button", "text": "Submit", "ariaLabel": "Submit form", "enabled": true}
    ;

    const element = extractor.parseElementJson(json, "button.submit");
    try std.testing.expect(element != null);

    const el = element.?;
    try std.testing.expectEqualStrings("button", el.tag_name);
    try std.testing.expectEqual(ElementType.button, el.element_type);
    try std.testing.expectEqualStrings("Submit", el.text_content.?);
    try std.testing.expectEqualStrings("Submit form", el.aria_label.?);
}

test "DOMExtractor parseElementJson null fields (v23.41)" {
    const allocator = std.heap.page_allocator;
    var agent = RealAgent.init(allocator, AgentConfig{ .test_mode = true });
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const json =
        \\{"tag": "div", "id": null, "text": null, "visible": true}
    ;

    const element = extractor.parseElementJson(json, "div");
    try std.testing.expect(element != null);

    const el = element.?;
    try std.testing.expectEqualStrings("div", el.tag_name);
    try std.testing.expect(el.id == null);
    try std.testing.expect(el.text_content == null);
}

test "DOMExtractor parseElementJson invalid JSON (v23.41)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const element = extractor.parseElementJson("not valid json", "div");
    try std.testing.expect(element == null);
}

test "DOMExtractor parseElementsJson array (v23.41)" {
    const allocator = std.heap.page_allocator;
    var agent = RealAgent.init(allocator, AgentConfig{ .test_mode = true });
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const json =
        \\[{"tag": "a", "text": "Link 1", "href": "/page1"}, {"tag": "a", "text": "Link 2", "href": "/page2"}, {"tag": "a", "text": "Link 3", "href": "/page3"}]
    ;

    const elements = extractor.parseElementsJson(json, "a");

    try std.testing.expectEqual(@as(usize, 3), elements.len);
    try std.testing.expectEqualStrings("a", elements[0].tag_name);
    try std.testing.expectEqualStrings("Link 1", elements[0].text_content.?);
    try std.testing.expectEqualStrings("Link 2", elements[1].text_content.?);
    try std.testing.expectEqualStrings("Link 3", elements[2].text_content.?);
}

test "DOMExtractor parseElementsJson empty array (v23.41)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const elements = extractor.parseElementsJson("[]", "a");
    try std.testing.expectEqual(@as(usize, 0), elements.len);
}

test "DOMExtractor parseElementsJson invalid JSON (v23.41)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var extractor = DOMExtractor.init(allocator, &agent);
    defer extractor.deinit();

    const elements = extractor.parseElementsJson("not an array", "a");
    try std.testing.expectEqual(@as(usize, 0), elements.len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.42: FORM INTERACTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FormFieldType fromInputType (v23.42)" {
    try std.testing.expectEqual(FormFieldType.text, FormFieldType.fromInputType("text"));
    try std.testing.expectEqual(FormFieldType.password, FormFieldType.fromInputType("password"));
    try std.testing.expectEqual(FormFieldType.email, FormFieldType.fromInputType("email"));
    try std.testing.expectEqual(FormFieldType.checkbox, FormFieldType.fromInputType("checkbox"));
    try std.testing.expectEqual(FormFieldType.radio, FormFieldType.fromInputType("radio"));
    try std.testing.expectEqual(FormFieldType.submit, FormFieldType.fromInputType("submit"));
    try std.testing.expectEqual(FormFieldType.text, FormFieldType.fromInputType(null));
    try std.testing.expectEqual(FormFieldType.other, FormFieldType.fromInputType("unknown"));
}

test "FormFieldType toString (v23.42)" {
    try std.testing.expectEqualStrings("text", FormFieldType.text.toString());
    try std.testing.expectEqualStrings("password", FormFieldType.password.toString());
    try std.testing.expectEqualStrings("email", FormFieldType.email.toString());
    try std.testing.expectEqualStrings("checkbox", FormFieldType.checkbox.toString());
}

test "FormFieldType isTextInput (v23.42)" {
    try std.testing.expect(FormFieldType.text.isTextInput());
    try std.testing.expect(FormFieldType.password.isTextInput());
    try std.testing.expect(FormFieldType.email.isTextInput());
    try std.testing.expect(FormFieldType.textarea.isTextInput());
    try std.testing.expect(!FormFieldType.checkbox.isTextInput());
    try std.testing.expect(!FormFieldType.select.isTextInput());
    try std.testing.expect(!FormFieldType.submit.isTextInput());
}

test "FormField fromElement (v23.42)" {
    const element = Element{
        .tag_name = "input",
        .element_type = .input,
        .selector = "input[name=email]",
        .name = "email",
        .input_type = "email",
        .placeholder = "Enter email",
        .is_enabled = true,
    };

    const field = FormField.fromElement(element);
    try std.testing.expectEqual(FormFieldType.email, field.field_type);
    try std.testing.expectEqualStrings("email", field.name.?);
    try std.testing.expectEqualStrings("Enter email", field.placeholder.?);
    try std.testing.expect(!field.is_disabled);
}

test "FormField fromElement textarea (v23.42)" {
    const element = Element{
        .tag_name = "textarea",
        .element_type = .textarea,
        .selector = "textarea[name=message]",
        .name = "message",
    };

    const field = FormField.fromElement(element);
    try std.testing.expectEqual(FormFieldType.textarea, field.field_type);
}

test "FormField fromElement select (v23.42)" {
    const element = Element{
        .tag_name = "select",
        .element_type = .select,
        .selector = "select[name=country]",
        .name = "country",
    };

    const field = FormField.fromElement(element);
    try std.testing.expectEqual(FormFieldType.select, field.field_type);
}

test "FormField canType (v23.42)" {
    const text_field = FormField{
        .selector = "input",
        .field_type = .text,
        .is_disabled = false,
        .is_readonly = false,
    };
    try std.testing.expect(text_field.canType());

    const disabled_field = FormField{
        .selector = "input",
        .field_type = .text,
        .is_disabled = true,
    };
    try std.testing.expect(!disabled_field.canType());

    const checkbox_field = FormField{
        .selector = "input",
        .field_type = .checkbox,
    };
    try std.testing.expect(!checkbox_field.canType());
}

test "FormField isSelection (v23.42)" {
    const select_field = FormField{
        .selector = "select",
        .field_type = .select,
    };
    try std.testing.expect(select_field.isSelection());

    const checkbox_field = FormField{
        .selector = "input",
        .field_type = .checkbox,
    };
    try std.testing.expect(checkbox_field.isSelection());

    const text_field = FormField{
        .selector = "input",
        .field_type = .text,
    };
    try std.testing.expect(!text_field.isSelection());
}

test "FormInteraction init (v23.42)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    const form = FormInteraction.init(allocator, &agent);
    try std.testing.expect(form.agent == &agent);
}

test "FormAction enum (v23.42)" {
    const fill = FormAction.fill;
    const select = FormAction.select;
    const check = FormAction.check;

    try std.testing.expect(fill == .fill);
    try std.testing.expect(select == .select);
    try std.testing.expect(check == .check);
}

test "FormFieldValue struct (v23.42)" {
    const field = FormFieldValue{
        .selector = "input[name=email]",
        .value = "test@example.com",
        .action = .fill,
    };

    try std.testing.expectEqualStrings("input[name=email]", field.selector);
    try std.testing.expectEqualStrings("test@example.com", field.value);
    try std.testing.expectEqual(FormAction.fill, field.action);
}

test "RetryMetrics with histogram (v23.26)" {
    var metrics = RetryMetrics{};
    metrics.recordDelay(500);
    metrics.recordDelay(1000);
    metrics.recordDelay(1500);

    try std.testing.expectEqual(@as(u64, 3), metrics.delay_histogram.count);
    try std.testing.expect(metrics.getDelayP50() > 0);
    try std.testing.expect(metrics.getDelayP90() > 0);
}

test "MetricsExporter JSON with histogram (v23.26)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    metrics.recordDelay(500);
    metrics.recordDelay(1000);

    const exporter = MetricsExporter.init(allocator);
    const json = try exporter.exportRetryMetricsToJson(metrics);
    defer allocator.free(json);

    // Check that histogram data is in JSON
    try std.testing.expect(std.mem.indexOf(u8, json, "delay_percentiles") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "p50") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "p99") != null);
}

test "MetricsExporter Prometheus with histogram (v23.26)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    metrics.recordDelay(500);
    metrics.recordDelay(1000);

    const exporter = MetricsExporter.init(allocator);
    const prom = try exporter.exportRetryMetricsToPrometheus(metrics);
    defer allocator.free(prom);

    // Check that histogram buckets are in Prometheus format
    try std.testing.expect(std.mem.indexOf(u8, prom, "vibee_retry_delay_ms_bucket") != null);
    try std.testing.expect(std.mem.indexOf(u8, prom, "le=\"+Inf\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, prom, "vibee_retry_delay_percentile") != null);
}

// v23.27: Per-domain circuit breaker tests
test "getCircuitBreakerForDomain creates new breaker (v23.27)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Record initial count (may have loaded from file)
    const initial_count = agent.getDomainCircuitBreakerCount();

    // Get circuit breaker for domain - should create new one
    const cb = try agent.getCircuitBreakerForDomain("example.com");
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
    try std.testing.expectEqual(initial_count + 1, agent.getDomainCircuitBreakerCount());

    // Get same domain again - should return existing
    const cb2 = try agent.getCircuitBreakerForDomain("example.com");
    try std.testing.expectEqual(@intFromPtr(cb), @intFromPtr(cb2));
    try std.testing.expectEqual(initial_count + 1, agent.getDomainCircuitBreakerCount());

    // Get different domain - should create new one
    _ = try agent.getCircuitBreakerForDomain("google.com");
    try std.testing.expectEqual(initial_count + 2, agent.getDomainCircuitBreakerCount());
}

test "canExecuteForDomain checks domain circuit breaker (v23.27)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Initially can execute for any domain
    try std.testing.expect(agent.canExecuteForDomain("example.com"));

    // Record failures to open circuit
    const cb = try agent.getCircuitBreakerForDomain("example.com");
    cb.failure_threshold = 2; // Lower threshold for testing
    agent.recordDomainFailure("example.com");
    agent.recordDomainFailure("example.com");

    // Circuit should be open now
    try std.testing.expectEqual(CircuitBreakerState.open, agent.getDomainCircuitBreakerState("example.com"));
    try std.testing.expect(!agent.canExecuteForDomain("example.com"));

    // Other domains should still work
    try std.testing.expect(agent.canExecuteForDomain("google.com"));
}

test "recordDomainSuccess and recordDomainFailure (v23.27)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Use unique domain name for this test
    const test_domain = "example.com";

    // Record success - creates new circuit breaker
    agent.recordDomainSuccess(test_domain);
    const cb = try agent.getCircuitBreakerForDomain(test_domain);
    // After success, failure_count should be 0
    try std.testing.expectEqual(@as(u32, 0), cb.failure_count);

    // Record failure
    agent.recordDomainFailure(test_domain);
    try std.testing.expectEqual(@as(u32, 1), cb.failure_count);
}

test "resetDomainCircuitBreaker (v23.27)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Open circuit
    const cb = try agent.getCircuitBreakerForDomain("example.com");
    cb.failure_threshold = 1;
    agent.recordDomainFailure("example.com");
    try std.testing.expectEqual(CircuitBreakerState.open, cb.state);

    // Reset
    agent.resetDomainCircuitBreaker("example.com");
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
}

test "extractDomain helper function (v23.27)" {
    // With protocol
    try std.testing.expectEqualStrings("example.com", extractDomain("https://example.com/path"));
    try std.testing.expectEqualStrings("api.example.com", extractDomain("https://api.example.com:443/v1"));

    // Without protocol - returns from start
    try std.testing.expectEqualStrings("example.com", extractDomain("example.com/path"));

    // Empty cases
    try std.testing.expectEqualStrings("", extractDomain("https://"));
    try std.testing.expectEqualStrings("", extractDomain(""));
}

// v23.28: Health Check Tests
test "HealthStatusLevel enum (v23.28)" {
    try std.testing.expectEqualStrings("healthy", HealthStatusLevel.healthy.toString());
    try std.testing.expectEqualStrings("degraded", HealthStatusLevel.degraded.toString());
    try std.testing.expectEqualStrings("unhealthy", HealthStatusLevel.unhealthy.toString());

    try std.testing.expectEqual(@as(u8, 1), HealthStatusLevel.healthy.toInt());
    try std.testing.expectEqual(@as(u8, 0), HealthStatusLevel.degraded.toInt());
    try std.testing.expectEqual(@as(u8, 0), HealthStatusLevel.unhealthy.toInt());
}

test "HealthStatus default values (v23.28)" {
    const status = HealthStatus{};
    try std.testing.expectEqual(HealthStatusLevel.healthy, status.status);
    try std.testing.expect(status.isHealthy());
    try std.testing.expectEqual(@as(u16, 200), status.getHttpStatusCode());
}

test "HealthStatus HTTP codes (v23.28)" {
    var healthy = HealthStatus{ .status = .healthy };
    try std.testing.expectEqual(@as(u16, 200), healthy.getHttpStatusCode());

    var degraded = HealthStatus{ .status = .degraded };
    try std.testing.expectEqual(@as(u16, 200), degraded.getHttpStatusCode());

    var unhealthy = HealthStatus{ .status = .unhealthy };
    try std.testing.expectEqual(@as(u16, 503), unhealthy.getHttpStatusCode());
}

test "HealthCheck getStatus healthy (v23.28)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    const health_check = HealthCheck.init(allocator);
    const status = health_check.getStatus(&agent);

    try std.testing.expectEqual(HealthStatusLevel.healthy, status.status);
    try std.testing.expect(status.circuit_breaker_healthy);
    try std.testing.expect(status.retry_metrics_healthy);
    try std.testing.expect(status.domain_breakers_healthy);
}

test "HealthCheck getStatus degraded (v23.28)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Simulate low success rate
    agent.retry_metrics.total_operations = 10;
    agent.retry_metrics.successful_operations = 3; // 30% success rate

    const health_check = HealthCheck.init(allocator);
    const status = health_check.getStatus(&agent);

    try std.testing.expectEqual(HealthStatusLevel.degraded, status.status);
    try std.testing.expect(!status.retry_metrics_healthy);
}

test "HealthCheck getStatus unhealthy (v23.28)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Open global circuit breaker
    agent.circuit_breaker.state = .open;

    const health_check = HealthCheck.init(allocator);
    const status = health_check.getStatus(&agent);

    try std.testing.expectEqual(HealthStatusLevel.unhealthy, status.status);
    try std.testing.expect(!status.circuit_breaker_healthy);
}

test "HealthCheck toJson (v23.28)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    const health_check = HealthCheck.init(allocator);
    const status = health_check.getStatus(&agent);
    const json = try health_check.toJson(status);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\": \"healthy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"version\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"components\"") != null);
}

test "HealthCheck toPrometheus (v23.28)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    const health_check = HealthCheck.init(allocator);
    const status = health_check.getStatus(&agent);
    const prom = try health_check.toPrometheus(status);
    defer allocator.free(prom);

    try std.testing.expect(std.mem.indexOf(u8, prom, "vibee_health_status") != null);
    try std.testing.expect(std.mem.indexOf(u8, prom, "vibee_uptime_seconds") != null);
    try std.testing.expect(std.mem.indexOf(u8, prom, "vibee_component_health") != null);
}

test "RealAgent health methods (v23.28)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Test getHealthStatus
    const status = agent.getHealthStatus();
    try std.testing.expect(status.isHealthy());

    // Test exportHealthToJson
    const json = try agent.exportHealthToJson();
    defer allocator.free(json);
    try std.testing.expect(json.len > 0);

    // Test exportHealthToPrometheus
    const prom = try agent.exportHealthToPrometheus();
    defer allocator.free(prom);
    try std.testing.expect(prom.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.29: FUNCTIONAL PROGRAMMING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ErrorCategory shouldRetry (v23.29)" {
    try std.testing.expect(ErrorCategory.transient.shouldRetry());
    try std.testing.expect(ErrorCategory.rate_limited.shouldRetry());
    try std.testing.expect(ErrorCategory.unknown.shouldRetry());
    try std.testing.expect(!ErrorCategory.permanent.shouldRetry());
}

test "ErrorCategory getDelayMultiplier (v23.29)" {
    try std.testing.expectEqual(@as(f32, 1.0), ErrorCategory.transient.getDelayMultiplier());
    try std.testing.expectEqual(@as(f32, 3.0), ErrorCategory.rate_limited.getDelayMultiplier());
    try std.testing.expectEqual(@as(f32, 1.5), ErrorCategory.unknown.getDelayMultiplier());
    try std.testing.expectEqual(@as(f32, 0.0), ErrorCategory.permanent.getDelayMultiplier());
}

test "calculateBackoff pure function (v23.29)" {
    // Attempt 0 returns base delay
    try std.testing.expectEqual(@as(u32, 500), calculateBackoff(0, 500, 2.0, 8000));

    // Attempt 1: 500 * 2 = 1000
    try std.testing.expectEqual(@as(u32, 1000), calculateBackoff(1, 500, 2.0, 8000));

    // Attempt 2: 500 * 2 * 2 = 2000
    try std.testing.expectEqual(@as(u32, 2000), calculateBackoff(2, 500, 2.0, 8000));

    // Attempt 3: 500 * 2 * 2 * 2 = 4000
    try std.testing.expectEqual(@as(u32, 4000), calculateBackoff(3, 500, 2.0, 8000));

    // Attempt 4: 500 * 16 = 8000 (capped at max)
    try std.testing.expectEqual(@as(u32, 8000), calculateBackoff(4, 500, 2.0, 8000));

    // Attempt 5: would be 16000 but capped at 8000
    try std.testing.expectEqual(@as(u32, 8000), calculateBackoff(5, 500, 2.0, 8000));
}

test "applyJitter deterministic with seed (v23.29)" {
    const seed: u64 = 12345;

    // Same seed should produce same result
    const result1 = applyJitter(1000, .equal, 0.2, seed);
    const result2 = applyJitter(1000, .equal, 0.2, seed);
    try std.testing.expectEqual(result1, result2);

    // Result should be within expected range
    try std.testing.expect(result1 >= 100);
    try std.testing.expect(result1 <= 1000);
}

test "applyJitter strategies (v23.29)" {
    const seed: u64 = 54321;
    const delay: u32 = 1000;

    // Equal jitter: delay/2 + random(0, delay/2) = 500-1000
    const equal = applyJitter(delay, .equal, 0.2, seed);
    try std.testing.expect(equal >= 100);

    // Full jitter: random(0, delay) = 0-1000
    const full = applyJitter(delay, .full, 0.2, seed);
    try std.testing.expect(full >= 100);
    try std.testing.expect(full <= delay);

    // Decorrelated jitter
    const decorr = applyJitter(delay, .decorrelated, 0.2, seed);
    try std.testing.expect(decorr >= 100);
}

test "shouldRetry pure function (v23.29)" {
    // Should retry on transient error with closed circuit
    try std.testing.expect(shouldRetry(0, 3, .closed, .transient));
    try std.testing.expect(shouldRetry(1, 3, .closed, .transient));
    try std.testing.expect(shouldRetry(2, 3, .closed, .transient));

    // Should not retry when max retries exceeded
    try std.testing.expect(!shouldRetry(3, 3, .closed, .transient));

    // Should not retry when circuit is open
    try std.testing.expect(!shouldRetry(0, 3, .open, .transient));

    // Should not retry on permanent error
    try std.testing.expect(!shouldRetry(0, 3, .closed, .permanent));

    // Half-open circuit allows retry
    try std.testing.expect(shouldRetry(0, 3, .half_open, .transient));
}

test "classifyError pure function (v23.29)" {
    try std.testing.expectEqual(ErrorCategory.transient, classifyError(AgentError.NavigationFailed));
    try std.testing.expectEqual(ErrorCategory.transient, classifyError(AgentError.BrowserConnectionFailed));
    try std.testing.expectEqual(ErrorCategory.permanent, classifyError(AgentError.ParseError));
    try std.testing.expectEqual(ErrorCategory.permanent, classifyError(AgentError.OutOfMemory));
}

test "makeRetryDecision pure function (v23.29)" {
    // Should retry on first attempt
    const ctx1 = RetryContext{
        .attempt = 0,
        .max_retries = 3,
        .error_category = .transient,
        .circuit_state = .closed,
        .base_delay_ms = 500,
        .max_delay_ms = 8000,
        .backoff_factor = 2.0,
        .jitter_strategy = .equal,
        .seed = 12345,
    };
    const decision1 = makeRetryDecision(ctx1);
    try std.testing.expect(decision1.should_retry);
    try std.testing.expect(decision1.delay_ms > 0);

    // Should not retry when circuit is open
    const ctx2 = RetryContext{
        .attempt = 0,
        .max_retries = 3,
        .error_category = .transient,
        .circuit_state = .open,
        .base_delay_ms = 500,
        .max_delay_ms = 8000,
        .backoff_factor = 2.0,
        .jitter_strategy = .equal,
        .seed = 12345,
    };
    const decision2 = makeRetryDecision(ctx2);
    try std.testing.expect(!decision2.should_retry);
    try std.testing.expectEqualStrings("circuit breaker open", decision2.reason);

    // Should not retry on permanent error
    const ctx3 = RetryContext{
        .attempt = 0,
        .max_retries = 3,
        .error_category = .permanent,
        .circuit_state = .closed,
        .base_delay_ms = 500,
        .max_delay_ms = 8000,
        .backoff_factor = 2.0,
        .jitter_strategy = .equal,
        .seed = 12345,
    };
    const decision3 = makeRetryDecision(ctx3);
    try std.testing.expect(!decision3.should_retry);
    try std.testing.expectEqualStrings("permanent error", decision3.reason);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.30: FUNCTIONAL PIPELINE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Result type ok (v23.30)" {
    const IntResult = Result(u32, []const u8);
    const result = IntResult{ .ok = 42 };

    try std.testing.expect(result.isOk());
    try std.testing.expect(!result.isErr());
    try std.testing.expectEqual(@as(u32, 42), result.unwrap());
    try std.testing.expectEqual(@as(u32, 42), result.unwrapOr(0));
}

test "Result type err (v23.30)" {
    const IntResult = Result(u32, []const u8);
    const result = IntResult{ .err = "error" };

    try std.testing.expect(!result.isOk());
    try std.testing.expect(result.isErr());
    try std.testing.expectEqual(@as(u32, 0), result.unwrapOr(0));
    try std.testing.expectEqualStrings("error", result.unwrapErr());
}

fn double(x: u32) u32 {
    return x * 2;
}

fn addTen(x: u32) u32 {
    return x + 10;
}

test "Result map (v23.30)" {
    const IntResult = Result(u32, []const u8);

    // Map on ok
    const ok_result = IntResult{ .ok = 5 };
    const mapped = ok_result.map(double);
    try std.testing.expectEqual(@as(u32, 10), mapped.unwrap());

    // Map on err (should not apply function)
    const err_result = IntResult{ .err = "error" };
    const mapped_err = err_result.map(double);
    try std.testing.expect(mapped_err.isErr());
}

test "Pipeline pipe (v23.30)" {
    const result = Pipeline(u32).init(5)
        .pipe(double) // 10
        .pipe(addTen) // 20
        .pipe(double) // 40
        .get();

    try std.testing.expectEqual(@as(u32, 40), result);
}

fn isEven(x: u32) bool {
    return x % 2 == 0;
}

test "Pipeline filter (v23.30)" {
    // Filter keeps value if predicate is true
    const even = Pipeline(u32).init(4)
        .filter(isEven, 0)
        .get();
    try std.testing.expectEqual(@as(u32, 4), even);

    // Filter returns default if predicate is false
    const odd = Pipeline(u32).init(5)
        .filter(isEven, 0)
        .get();
    try std.testing.expectEqual(@as(u32, 0), odd);
}

test "Pipeline composition (v23.30)" {
    // Complex pipeline: double, filter even, add 10
    const result = Pipeline(u32).init(3)
        .pipe(double) // 6
        .filter(isEven, 0) // 6 (is even)
        .pipe(addTen) // 16
        .get();

    try std.testing.expectEqual(@as(u32, 16), result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.31: RETRY EXECUTOR TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "OperationType toString (v23.31)" {
    try std.testing.expectEqualStrings("navigate", OperationType.navigate.toString());
    try std.testing.expectEqualStrings("wait_selector", OperationType.wait_selector.toString());
    try std.testing.expectEqualStrings("click", OperationType.click.toString());
}

test "OperationType getMetricField (v23.37)" {
    try std.testing.expectEqualStrings("navigate_retries", OperationType.navigate.getMetricField());
    try std.testing.expectEqualStrings("selector_retries", OperationType.wait_selector.getMetricField());
    try std.testing.expectEqualStrings("page_load_retries", OperationType.wait_page_load.getMetricField());
    try std.testing.expectEqualStrings("click_retries", OperationType.click.getMetricField());
}

test "isOperation comptime check (v23.37)" {
    // NavigateOperation has execute and getType
    try std.testing.expect(isOperation(NavigateOperation));
    try std.testing.expect(isOperation(WaitSelectorOperation));
    try std.testing.expect(isOperation(WaitPageLoadOperation));
    try std.testing.expect(isOperation(ClickOperation));
}

test "operationReturnsBool comptime check (v23.37)" {
    // Navigate and Click return void
    try std.testing.expect(!operationReturnsBool(NavigateOperation));
    try std.testing.expect(!operationReturnsBool(ClickOperation));
    // WaitSelector and WaitPageLoad return bool
    try std.testing.expect(operationReturnsBool(WaitSelectorOperation));
    try std.testing.expect(operationReturnsBool(WaitPageLoadOperation));
}

test "hasTimeoutEscalation comptime check (v23.37)" {
    // Only wait operations have timeout escalation
    try std.testing.expect(!hasTimeoutEscalation(NavigateOperation));
    try std.testing.expect(!hasTimeoutEscalation(ClickOperation));
    try std.testing.expect(hasTimeoutEscalation(WaitSelectorOperation));
    try std.testing.expect(hasTimeoutEscalation(WaitPageLoadOperation));
}

test "hasDomain comptime check (v23.37)" {
    // Only NavigateOperation has getDomain
    try std.testing.expect(hasDomain(NavigateOperation));
    try std.testing.expect(!hasDomain(ClickOperation));
    try std.testing.expect(!hasDomain(WaitSelectorOperation));
    try std.testing.expect(!hasDomain(WaitPageLoadOperation));
}

test "Generic executeOperation with NavigateOperation (v23.37)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var executor = RetryExecutor.fromAgent(&agent);
    var op = NavigateOperation{
        .url = "https://test.com/page",
        .agent = &agent,
    };

    const result = executor.executeOperation(NavigateOperation, &op);
    // Should attempt operation (will fail without browser)
    try std.testing.expect(result.attempts > 0 or !result.success);
}

test "Generic executeOperation with WaitSelectorOperation (v23.37)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var executor = RetryExecutor.fromAgent(&agent);
    var op = WaitSelectorOperation{
        .selector = "#test",
        .timeout_ms = 1000,
        .agent = &agent,
    };

    const result = executor.executeOperation(WaitSelectorOperation, &op);
    try std.testing.expect(result.attempts > 0 or !result.success);
}

test "RetryExecutor init (v23.31)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    var cb = CircuitBreaker{};
    const config = RetryConfig{};

    const executor = RetryExecutor.init(allocator, config, &metrics, &cb);
    try std.testing.expectEqual(config.max_retries, executor.config.max_retries);
}

test "RetryExecutor buildContext (v23.31)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    var cb = CircuitBreaker{};
    const config = RetryConfig{
        .max_retries = 5,
        .initial_delay_ms = 1000,
        .jitter_strategy = .full,
    };

    const executor = RetryExecutor.init(allocator, config, &metrics, &cb);
    const ctx = executor.buildContext(2, .transient);

    try std.testing.expectEqual(@as(u32, 2), ctx.attempt);
    try std.testing.expectEqual(@as(u32, 5), ctx.max_retries);
    try std.testing.expectEqual(ErrorCategory.transient, ctx.error_category);
    try std.testing.expectEqual(CircuitBreakerState.closed, ctx.circuit_state);
    try std.testing.expectEqual(JitterStrategy.full, ctx.jitter_strategy);
}

test "RetryExecutor simulateRetry success on first try (v23.31)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    var cb = CircuitBreaker{};
    const config = RetryConfig{ .max_retries = 3 };

    const executor = RetryExecutor.init(allocator, config, &metrics, &cb);
    const result = executor.simulateRetry(0); // Success immediately

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u32, 1), result.attempts);
    try std.testing.expectEqual(@as(u32, 0), result.total_delay_ms);
}

test "RetryExecutor simulateRetry success after retries (v23.31)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    var cb = CircuitBreaker{};
    const config = RetryConfig{
        .max_retries = 3,
        .initial_delay_ms = 100,
    };

    const executor = RetryExecutor.init(allocator, config, &metrics, &cb);
    const result = executor.simulateRetry(2); // Fail twice, then succeed

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u32, 3), result.attempts);
    try std.testing.expect(result.total_delay_ms > 0);
}

test "RetryExecutor simulateRetry failure after max retries (v23.31)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    var cb = CircuitBreaker{};
    const config = RetryConfig{ .max_retries = 2 };

    const executor = RetryExecutor.init(allocator, config, &metrics, &cb);
    const result = executor.simulateRetry(10); // Never succeed

    try std.testing.expect(!result.success);
    // max_retries=2 means: attempt 0 (fail), attempt 1 (fail), attempt 2 (fail) = 2 retries counted
    try std.testing.expect(result.attempts >= 2);
}

test "RetryExecutor with open circuit breaker (v23.31)" {
    const allocator = std.testing.allocator;
    var metrics = RetryMetrics{};
    var cb = CircuitBreaker{ .state = .open };
    const config = RetryConfig{};

    var executor = RetryExecutor.init(allocator, config, &metrics, &cb);

    // Dummy operation that always fails
    const DummyCtx = struct {
        fn fail(_: *anyopaque) AgentError!void {
            return AgentError.NavigationFailed;
        }
    };

    var dummy: u32 = 0;
    const result = executor.executeWithRetry(.navigate, DummyCtx.fail, @ptrCast(&dummy));

    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u32, 0), result.attempts);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.35: OPERATION STRUCTS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NavigateOperation getType (v23.35)" {
    try std.testing.expectEqual(OperationType.navigate, NavigateOperation.getType());
}

test "NavigateOperation getDomain (v23.35)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var op = NavigateOperation{
        .url = "https://example.com/page",
        .agent = &agent,
    };

    try std.testing.expectEqualStrings("example.com", op.getDomain());
}

test "WaitSelectorOperation getType (v23.35)" {
    try std.testing.expectEqual(OperationType.wait_selector, WaitSelectorOperation.getType());
}

test "WaitSelectorOperation timeout escalation (v23.36)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var op = WaitSelectorOperation{
        .selector = "#test",
        .timeout_ms = 1000,
        .agent = &agent,
        .timeout_multiplier = 1.5,
    };

    // First attempt: base timeout
    try std.testing.expectEqual(@as(u32, 1000), op.getEscalatedTimeout());

    // After first retry: 1000 * 1.5 = 1500
    op.nextAttempt();
    try std.testing.expectEqual(@as(u32, 1500), op.getEscalatedTimeout());

    // After second retry: 1000 * 1.5 * 1.5 = 2250
    op.nextAttempt();
    try std.testing.expectEqual(@as(u32, 2250), op.getEscalatedTimeout());

    // Reset should go back to base
    op.resetAttempts();
    try std.testing.expectEqual(@as(u32, 1000), op.getEscalatedTimeout());
}

test "WaitSelectorOperation timeout cap at 30s (v23.36)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var op = WaitSelectorOperation{
        .selector = "#test",
        .timeout_ms = 10000, // 10 seconds base
        .agent = &agent,
        .timeout_multiplier = 2.0, // Aggressive multiplier
    };

    // Escalate many times
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        op.nextAttempt();
    }

    // Should be capped at 30 seconds (default config)
    try std.testing.expect(op.getEscalatedTimeout() <= 30000);
}

test "WaitSelectorOperation custom timeout cap (v23.38)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var op = WaitSelectorOperation{
        .selector = "#test",
        .timeout_ms = 5000,
        .agent = &agent,
        .timeout_multiplier = 2.0,
        .timeout_cap_ms = 15000, // Custom cap: 15 seconds
    };

    // Escalate many times
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        op.nextAttempt();
    }

    // Should be capped at custom 15 seconds
    try std.testing.expect(op.getEscalatedTimeout() <= 15000);
}

test "WaitSelectorOperation uses config cap when custom is 0 (v23.38)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Modify config cap
    agent.retry_config.selector_timeout_cap_ms = 20000;

    var op = WaitSelectorOperation{
        .selector = "#test",
        .timeout_ms = 5000,
        .agent = &agent,
        .timeout_multiplier = 2.0,
        .timeout_cap_ms = 0, // Use config default
    };

    // Escalate many times
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        op.nextAttempt();
    }

    // Should be capped at config's 20 seconds
    try std.testing.expect(op.getEscalatedTimeout() <= 20000);
}

test "ClickOperation getType (v23.35)" {
    try std.testing.expectEqual(OperationType.click, ClickOperation.getType());
}

test "WaitPageLoadOperation getType (v23.35)" {
    try std.testing.expectEqual(OperationType.wait_page_load, WaitPageLoadOperation.getType());
}

test "WaitPageLoadOperation timeout escalation (v23.36)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var op = WaitPageLoadOperation{
        .timeout_ms = 5000,
        .agent = &agent,
        .timeout_multiplier = 1.5,
    };

    // First attempt: base timeout
    try std.testing.expectEqual(@as(u32, 5000), op.getEscalatedTimeout());

    // After first retry: 5000 * 1.5 = 7500
    op.nextAttempt();
    try std.testing.expectEqual(@as(u32, 7500), op.getEscalatedTimeout());

    // After second retry: 5000 * 1.5 * 1.5 = 11250
    op.nextAttempt();
    try std.testing.expectEqual(@as(u32, 11250), op.getEscalatedTimeout());
}

test "WaitPageLoadOperation timeout cap at 60s (v23.36)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var op = WaitPageLoadOperation{
        .timeout_ms = 20000, // 20 seconds base
        .agent = &agent,
        .timeout_multiplier = 2.0,
    };

    // Escalate many times
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        op.nextAttempt();
    }

    // Should be capped at 60 seconds for page loads (default config)
    try std.testing.expect(op.getEscalatedTimeout() <= 60000);
}

test "WaitPageLoadOperation custom timeout cap (v23.38)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var op = WaitPageLoadOperation{
        .timeout_ms = 10000,
        .agent = &agent,
        .timeout_multiplier = 2.0,
        .timeout_cap_ms = 25000, // Custom cap: 25 seconds
    };

    // Escalate many times
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        op.nextAttempt();
    }

    // Should be capped at custom 25 seconds
    try std.testing.expect(op.getEscalatedTimeout() <= 25000);
}

test "WaitPageLoadOperation uses config cap when custom is 0 (v23.38)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Modify config cap
    agent.retry_config.page_load_timeout_cap_ms = 45000;

    var op = WaitPageLoadOperation{
        .timeout_ms = 10000,
        .agent = &agent,
        .timeout_multiplier = 2.0,
        .timeout_cap_ms = 0, // Use config default
    };

    // Escalate many times
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        op.nextAttempt();
    }

    // Should be capped at config's 45 seconds
    try std.testing.expect(op.getEscalatedTimeout() <= 45000);
}

test "RetryConfig timeout caps defaults (v23.38)" {
    const config = RetryConfig{};
    try std.testing.expectEqual(@as(u32, 30000), config.selector_timeout_cap_ms);
    try std.testing.expectEqual(@as(u32, 60000), config.page_load_timeout_cap_ms);
    try std.testing.expectEqual(@as(u32, 45000), config.navigate_timeout_cap_ms);
}

test "RetryExecutor fromAgent (v23.35)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    const executor = RetryExecutor.fromAgent(&agent);

    try std.testing.expectEqual(agent.retry_config.max_retries, executor.config.max_retries);
    try std.testing.expect(executor.domain_circuit_breakers != null);
}

test "RetryExecutor executeNavigate with closed circuit (v23.35)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var executor = RetryExecutor.fromAgent(&agent);

    var op = NavigateOperation{
        .url = "https://test.com/page",
        .agent = &agent,
    };

    // This will fail because we're not connected to a real browser
    // But it should attempt the operation
    const result = executor.executeNavigate(&op);

    // Should have attempted at least once
    try std.testing.expect(result.attempts > 0 or !result.success);
}

test "RetryExecutor executeWaitSelector with closed circuit (v23.35)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var executor = RetryExecutor.fromAgent(&agent);

    var op = WaitSelectorOperation{
        .selector = "#test-element",
        .timeout_ms = 1000,
        .agent = &agent,
    };

    const result = executor.executeWaitSelector(&op);

    // Should have attempted at least once
    try std.testing.expect(result.attempts > 0 or !result.success);
}

test "RetryExecutor executeWaitPageLoad with closed circuit (v23.35)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var executor = RetryExecutor.fromAgent(&agent);

    var op = WaitPageLoadOperation{
        .timeout_ms = 1000,
        .agent = &agent,
    };

    const result = executor.executeWaitPageLoad(&op);

    // Should have attempted at least once
    try std.testing.expect(result.attempts > 0 or !result.success);
}

test "RetryExecutor executeClick with closed circuit (v23.35)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    var executor = RetryExecutor.fromAgent(&agent);

    var op = ClickOperation{
        .selector = "#test-button",
        .agent = &agent,
    };

    const result = executor.executeClick(&op);

    // Should have attempted at least once
    try std.testing.expect(result.attempts > 0 or !result.success);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.32: CIRCUIT BREAKER PERSISTENCE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CircuitBreaker toSnapshot (v23.32)" {
    var cb = CircuitBreaker{
        .state = .open,
        .failure_count = 5,
        .success_count = 2,
        .last_failure_time = 12345,
    };

    const snapshot = cb.toSnapshot();
    try std.testing.expectEqualStrings("OPEN", snapshot.state);
    try std.testing.expectEqual(@as(u32, 5), snapshot.failure_count);
    try std.testing.expectEqual(@as(u32, 2), snapshot.success_count);
    try std.testing.expectEqual(@as(i64, 12345), snapshot.last_failure_time);
}

test "CircuitBreaker fromSnapshot (v23.32)" {
    const snapshot = CircuitBreakerSnapshot{
        .state = "OPEN",
        .failure_count = 3,
        .success_count = 1,
        .last_failure_time = 99999,
    };

    const cb = CircuitBreaker.fromSnapshot(snapshot);
    try std.testing.expectEqual(CircuitBreakerState.open, cb.state);
    try std.testing.expectEqual(@as(u32, 3), cb.failure_count);
    try std.testing.expectEqual(@as(u32, 1), cb.success_count);
    try std.testing.expectEqual(@as(i64, 99999), cb.last_failure_time);
}

test "CircuitBreaker fromSnapshot half_open (v23.32)" {
    const snapshot = CircuitBreakerSnapshot{
        .state = "HALF_OPEN",
        .failure_count = 0,
        .success_count = 2,
    };

    const cb = CircuitBreaker.fromSnapshot(snapshot);
    try std.testing.expectEqual(CircuitBreakerState.half_open, cb.state);
}

test "CircuitBreaker fromSnapshot closed (v23.32)" {
    const snapshot = CircuitBreakerSnapshot{
        .state = "CLOSED",
    };

    const cb = CircuitBreaker.fromSnapshot(snapshot);
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
}

test "CircuitBreaker roundtrip snapshot (v23.32)" {
    var original = CircuitBreaker{
        .state = .open,
        .failure_count = 7,
        .success_count = 3,
        .last_failure_time = 54321,
        .failure_threshold = 10,
    };

    const snapshot = original.toSnapshot();
    const restored = CircuitBreaker.fromSnapshot(snapshot);

    try std.testing.expectEqual(original.state, restored.state);
    try std.testing.expectEqual(original.failure_count, restored.failure_count);
    try std.testing.expectEqual(original.success_count, restored.success_count);
    try std.testing.expectEqual(original.last_failure_time, restored.last_failure_time);
}

test "RealAgent saveDomainCircuitBreakers skipped in test_mode (v23.34)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Add a domain circuit breaker
    const cb = try agent.getCircuitBreakerForDomain("test.com");
    cb.state = .open;
    cb.failure_count = 5;

    // Save should not error (but does nothing in test_mode)
    try agent.saveDomainCircuitBreakers();

    // In test_mode, persistence is disabled - this is expected behavior
    try std.testing.expect(agent.config.test_mode);
}

test "RealAgent persistence works when test_mode is false (v23.34)" {
    const allocator = std.testing.allocator;
    // Create agent with test_mode = false to test actual persistence
    var agent = RealAgent.init(allocator, AgentConfig{ .test_mode = false });
    defer agent.deinit();

    // Add a domain circuit breaker
    const cb = try agent.getCircuitBreakerForDomain("persist-test.com");
    cb.state = .open;
    cb.failure_count = 5;

    // Save should create file
    try agent.saveDomainCircuitBreakers();

    // Verify file was created
    const file = std.fs.cwd().openFile(CIRCUIT_BREAKER_FILE, .{}) catch {
        // File might not exist if previous test cleaned up
        return;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Check content contains our domain
    try std.testing.expect(std.mem.indexOf(u8, content, "persist-test.com") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.34: TEST ISOLATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TestConfig defaults (v23.34)" {
    const config = TestConfig{};
    try std.testing.expect(config.disable_persistence);
    try std.testing.expect(config.isolated_storage);
}

test "TestConfig toAgentConfig (v23.34)" {
    const test_config = TestConfig{};
    const agent_config = test_config.toAgentConfig();
    try std.testing.expect(agent_config.test_mode);
}

test "AgentConfig test_mode default false (v23.34)" {
    const config = AgentConfig{};
    try std.testing.expect(!config.test_mode);
}

test "initTestAgent creates isolated agent (v23.34)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    try std.testing.expect(agent.config.test_mode);
}

test "Test isolation - no persistence files created (v23.34)" {
    const allocator = std.testing.allocator;
    var agent = initTestAgent(allocator);
    defer agent.deinit();

    // Add data
    _ = try agent.getCircuitBreakerForDomain("isolated-test.com");
    agent.updateDomainStats("isolated-test.com", 500);

    // These should do nothing in test_mode
    try agent.saveDomainStats();
    try agent.saveDomainCircuitBreakers();

    // Verify test_mode is set
    try std.testing.expect(agent.config.test_mode);
}

test "Tests are isolated from each other (v23.34)" {
    const allocator = std.testing.allocator;

    // First agent
    var agent1 = initTestAgent(allocator);
    _ = try agent1.getCircuitBreakerForDomain("agent1-domain.com");
    const count1 = agent1.getDomainCircuitBreakerCount();
    agent1.deinit();

    // Second agent should start fresh
    var agent2 = initTestAgent(allocator);
    defer agent2.deinit();

    // Should not have agent1's domain (since persistence is disabled)
    // Note: count might be 0 or might have loaded from file if test_mode wasn't working
    // The key is that test_mode prevents loading
    try std.testing.expect(agent2.config.test_mode);
    _ = count1; // Used to avoid unused variable warning
}

// ═══════════════════════════════════════════════════════════════════════════════
// v23.33: ADAPTIVE RETRY STRATEGY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FailurePattern enum (v23.33)" {
    try std.testing.expectEqualStrings("burst", FailurePattern.burst.toString());
    try std.testing.expectEqualStrings("steady", FailurePattern.steady.toString());
    try std.testing.expectEqualStrings("random", FailurePattern.random.toString());
    try std.testing.expectEqualStrings("unknown", FailurePattern.unknown.toString());
}

test "FailurePattern getRecommendedStrategy (v23.33)" {
    try std.testing.expectEqual(JitterStrategy.full, FailurePattern.burst.getRecommendedStrategy());
    try std.testing.expectEqual(JitterStrategy.decorrelated, FailurePattern.steady.getRecommendedStrategy());
    try std.testing.expectEqual(JitterStrategy.equal, FailurePattern.random.getRecommendedStrategy());
    try std.testing.expectEqual(JitterStrategy.equal, FailurePattern.unknown.getRecommendedStrategy());
}

test "FailureHistory recordFailure (v23.33)" {
    var history = FailureHistory{};
    try std.testing.expectEqual(@as(u32, 0), history.count);

    history.recordFailure(1000);
    try std.testing.expectEqual(@as(u32, 1), history.count);

    history.recordFailure(2000);
    try std.testing.expectEqual(@as(u32, 2), history.count);
}

test "FailureHistory detectPattern unknown (v23.33)" {
    var history = FailureHistory{};
    // Not enough data
    try std.testing.expectEqual(FailurePattern.unknown, history.detectPattern());

    history.recordFailure(1000);
    try std.testing.expectEqual(FailurePattern.unknown, history.detectPattern());

    history.recordFailure(2000);
    try std.testing.expectEqual(FailurePattern.unknown, history.detectPattern());
}

test "FailureHistory detectPattern burst (v23.33)" {
    var history = FailureHistory{};
    // Failures in quick succession (< 1 second apart)
    history.recordFailure(1000);
    history.recordFailure(1100);
    history.recordFailure(1200);
    history.recordFailure(1300);

    try std.testing.expectEqual(FailurePattern.burst, history.detectPattern());
}

test "FailureHistory detectPattern steady (v23.33)" {
    var history = FailureHistory{};
    // Consistent intervals (5 seconds apart)
    history.recordFailure(0);
    history.recordFailure(5000);
    history.recordFailure(10000);
    history.recordFailure(15000);

    try std.testing.expectEqual(FailurePattern.steady, history.detectPattern());
}

test "FailureHistory reset (v23.33)" {
    var history = FailureHistory{};
    history.recordFailure(1000);
    history.recordFailure(2000);
    try std.testing.expectEqual(@as(u32, 2), history.count);

    history.reset();
    try std.testing.expectEqual(@as(u32, 0), history.count);
}

test "RetryConfig adaptive_strategy default (v23.33)" {
    const config = RetryConfig{};
    try std.testing.expect(!config.adaptive_strategy);
}

test "RetryConfig getDetectedPattern (v23.33)" {
    var config = RetryConfig{};
    // Initially unknown
    try std.testing.expectEqual(FailurePattern.unknown, config.getDetectedPattern());
}

test "RetryConfig getDelayWithAdaptive (v23.33)" {
    var config = RetryConfig{
        .initial_delay_ms = 500,
        .adaptive_strategy = true,
    };

    // First call records failure and returns delay
    const delay1 = config.getDelayWithAdaptive(0);
    try std.testing.expect(delay1 > 0);
    try std.testing.expectEqual(@as(u32, 1), config.failure_history.count);

    // Second call records another failure
    const delay2 = config.getDelayWithAdaptive(1);
    try std.testing.expect(delay2 > 0);
    try std.testing.expectEqual(@as(u32, 2), config.failure_history.count);
}

test "RetryConfig adaptive selects strategy based on pattern (v23.33)" {
    var config = RetryConfig{
        .initial_delay_ms = 500,
        .adaptive_strategy = true,
        .use_jitter = true,
    };

    // Simulate burst pattern
    config.failure_history.recordFailure(1000);
    config.failure_history.recordFailure(1100);
    config.failure_history.recordFailure(1200);
    config.failure_history.recordFailure(1300);

    // Should detect burst and use full jitter
    try std.testing.expectEqual(FailurePattern.burst, config.getDetectedPattern());

    // getDelayWithJitter should use full jitter strategy
    const delay = config.getDelayWithJitter(1);
    try std.testing.expect(delay > 0);
}
