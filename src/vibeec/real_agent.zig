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
    EvaluationFailed,
    ParseError,
    OutOfMemory,
};

pub const AgentConfig = struct {
    chrome_host: []const u8 = "localhost",
    chrome_port: u16 = 9222,
    ollama_host: []const u8 = "localhost",
    ollama_port: u16 = 11434,
    model: []const u8 = "qwen2.5:0.5b",
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

// v23.16: Retry configuration with exponential backoff
pub const RetryConfig = struct {
    max_retries: u32 = 3,
    initial_delay_ms: u32 = 500,
    backoff_factor: f32 = 2.0,
    max_delay_ms: u32 = 8000,
    // v23.17: Timeout adjustment on retry
    timeout_factor: f32 = 1.5, // Increase timeout by 50% on each retry
    max_timeout_ms: u32 = 30000, // Cap at 30 seconds
    // v23.18: Jitter for distributed systems
    jitter_factor: f32 = 0.2, // ±20% random variation
    use_jitter: bool = true,
    // v23.25: Jitter strategy selection
    jitter_strategy: JitterStrategy = .equal,
    // v23.25: Previous delay for decorrelated jitter
    prev_delay_ms: u32 = 0,

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

    /// Calculate delay with jitter using selected strategy (v23.25)
    /// Prevents thundering herd problem in distributed systems
    pub fn getDelayWithJitter(self: RetryConfig, attempt: u32) u32 {
        const base_delay = self.getDelay(attempt);
        if (!self.use_jitter or self.jitter_factor == 0) {
            return base_delay;
        }

        // Use strategy-specific jitter calculation
        return switch (self.jitter_strategy) {
            .full => self.getFullJitter(attempt),
            .decorrelated => self.getDecorrelatedJitter(attempt, self.prev_delay_ms),
            .equal => self.getEqualJitter(attempt),
        };
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

    /// Reset all metrics
    pub fn reset(self: *RetryMetrics) void {
        self.* = RetryMetrics{};
    }
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
};

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
        try writer.print("vibee_retry_delay_ms_max {d}\n", .{metrics.max_delay_ms});

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
    // v23.22: Circuit breaker
    circuit_breaker: CircuitBreaker = .{},

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
        };

        // v23.21: Auto-load domain stats from file
        self.loadDomainStats() catch {};

        return self;
    }

    pub fn deinit(self: *Self) void {
        // v23.21: Auto-save domain stats to file
        self.saveDomainStats() catch {};

        // Free domain keys
        var it = self.domain_stats.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.domain_stats.deinit();
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
        if (domain) |d| {
            // Update current domain
            if (self.current_domain) |old| self.allocator.free(old);
            self.current_domain = self.allocator.dupe(u8, d) catch null;
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
            if (domain) |d| self.updateDomainStats(d, elapsed_u32);
            std.debug.print("    [NAV] Page loaded in {d}ms (timeout: {d}ms, domain: {s})\n", .{ elapsed, timeout, domain orelse "unknown" });
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

    /// Extract domain from URL (v23.15)
    fn extractDomain(url: []const u8) ?[]const u8 {
        // Skip protocol
        var start: usize = 0;
        if (std.mem.startsWith(u8, url, "https://")) {
            start = 8;
        } else if (std.mem.startsWith(u8, url, "http://")) {
            start = 7;
        }
        if (start >= url.len) return null;

        // Find end of domain (first / or end)
        const rest = url[start..];
        const end = std.mem.indexOf(u8, rest, "/") orelse rest.len;
        if (end == 0) return null;

        return rest[0..end];
    }

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

    /// Navigate with retry on failure (v23.16)
    pub fn navigateWithRetry(self: *Self, url: []const u8) AgentError!RetryResult {
        // v23.22: Check circuit breaker
        if (!self.circuit_breaker.canExecute()) {
            std.debug.print("    [CIRCUIT] Request blocked - circuit is OPEN\n", .{});
            return RetryResult{
                .success = false,
                .attempts = 0,
                .total_delay_ms = 0,
            };
        }

        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        // v23.19: Track operation
        self.retry_metrics.total_operations += 1;

        while (attempts <= self.retry_config.max_retries) {
            // Try navigation
            self.navigate(url) catch |err| {
                attempts += 1;
                // v23.19: Track retry
                self.retry_metrics.total_retries += 1;
                self.retry_metrics.navigate_retries += 1;

                if (attempts > self.retry_config.max_retries) {
                    // v23.22: Record failure
                    self.circuit_breaker.recordFailure();
                    // v23.19: Track failure
                    self.retry_metrics.failed_operations += 1;
                    std.debug.print("    [RETRY] Navigate failed after {d} attempts\n", .{attempts});
                    return err;
                }

                // Calculate backoff delay
                const delay = self.retry_config.getDelayWithJitter(attempts - 1);
                total_delay += delay;
                // v23.19: Track delay
                self.retry_metrics.total_delay_ms += delay;
                if (delay > self.retry_metrics.max_delay_ms) {
                    self.retry_metrics.max_delay_ms = delay;
                }

                std.debug.print("    [RETRY] Navigate attempt {d}/{d} failed, waiting {d}ms\n", .{ attempts, self.retry_config.max_retries + 1, delay });

                // Wait before retry
                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            // v23.19: Track success
            self.retry_metrics.successful_operations += 1;
            // v23.22: Record success
            self.circuit_breaker.recordSuccess();

            return RetryResult{
                .success = true,
                .attempts = attempts + 1,
                .total_delay_ms = total_delay,
            };
        }

        // v23.19: Track failure (max retries exceeded)
        self.retry_metrics.failed_operations += 1;
        // v23.22: Record failure
        self.circuit_breaker.recordFailure();

        return RetryResult{
            .success = false,
            .attempts = attempts,
            .total_delay_ms = total_delay,
        };
    }

    /// Wait for selector with retry (v23.16, v23.19: metrics)
    pub fn waitForSelectorWithRetry(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!RetryResult {
        // v23.23: Check circuit breaker
        if (!self.circuit_breaker.canExecute()) {
            std.debug.print("    [CIRCUIT] waitForSelector blocked - circuit is OPEN\n", .{});
            return RetryResult{ .success = false, .attempts = 0, .total_delay_ms = 0 };
        }

        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        // v23.19: Track operation
        self.retry_metrics.total_operations += 1;

        while (attempts <= self.retry_config.max_retries) {
            // v23.17: Increase timeout on each retry
            const current_timeout = self.retry_config.getTimeout(timeout_ms, attempts);

            const found = self.waitForSelector(selector, current_timeout) catch |err| {
                attempts += 1;
                self.retry_metrics.total_retries += 1;
                self.retry_metrics.selector_retries += 1;

                if (attempts > self.retry_config.max_retries) {
                    self.retry_metrics.failed_operations += 1;
                    self.circuit_breaker.recordFailure(); // v23.23
                    return err;
                }
                const delay = self.retry_config.getDelayWithJitter(attempts - 1);
                const next_timeout = self.retry_config.getTimeout(timeout_ms, attempts);
                total_delay += delay;
                self.retry_metrics.total_delay_ms += delay;
                if (delay > self.retry_metrics.max_delay_ms) self.retry_metrics.max_delay_ms = delay;

                std.debug.print("    [RETRY] waitForSelector attempt {d} failed, waiting {d}ms, next timeout: {d}ms\n", .{ attempts, delay, next_timeout });
                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            if (found) {
                self.retry_metrics.successful_operations += 1;
                self.circuit_breaker.recordSuccess(); // v23.23
                return RetryResult{
                    .success = true,
                    .attempts = attempts + 1,
                    .total_delay_ms = total_delay,
                };
            }

            // Not found, retry with backoff and increased timeout
            attempts += 1;
            self.retry_metrics.total_retries += 1;
            self.retry_metrics.selector_retries += 1;

            if (attempts > self.retry_config.max_retries) {
                break;
            }

            const delay = self.retry_config.getDelayWithJitter(attempts - 1);
            const next_timeout = self.retry_config.getTimeout(timeout_ms, attempts);
            total_delay += delay;
            self.retry_metrics.total_delay_ms += delay;
            if (delay > self.retry_metrics.max_delay_ms) self.retry_metrics.max_delay_ms = delay;

            std.debug.print("    [RETRY] Selector not found, attempt {d}/{d}, waiting {d}ms, next timeout: {d}ms\n", .{ attempts, self.retry_config.max_retries + 1, delay, next_timeout });
            std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
        }

        self.retry_metrics.failed_operations += 1;
        self.circuit_breaker.recordFailure(); // v23.23
        return RetryResult{
            .success = false,
            .attempts = attempts,
            .total_delay_ms = total_delay,
        };
    }

    /// Wait for page load with retry (v23.16, v23.17: smart timeout)
    pub fn waitForPageLoadWithRetry(self: *Self, timeout_ms: u32) AgentError!RetryResult {
        // v23.23: Check circuit breaker
        if (!self.circuit_breaker.canExecute()) {
            std.debug.print("    [CIRCUIT] waitForPageLoad blocked - circuit is OPEN\n", .{});
            return RetryResult{ .success = false, .attempts = 0, .total_delay_ms = 0 };
        }

        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        // v23.20: Track operation
        self.retry_metrics.total_operations += 1;

        while (attempts <= self.retry_config.max_retries) {
            // v23.17: Increase timeout on each retry
            const current_timeout = self.retry_config.getTimeout(timeout_ms, attempts);

            const loaded = self.waitForPageLoad(current_timeout) catch |err| {
                attempts += 1;
                // v23.20: Track retry
                self.retry_metrics.total_retries += 1;
                self.retry_metrics.page_load_retries += 1;

                if (attempts > self.retry_config.max_retries) {
                    self.retry_metrics.failed_operations += 1;
                    self.circuit_breaker.recordFailure(); // v23.23
                    return err;
                }
                const delay = self.retry_config.getDelayWithJitter(attempts - 1);
                total_delay += delay;
                self.retry_metrics.total_delay_ms += delay;
                if (delay > self.retry_metrics.max_delay_ms) self.retry_metrics.max_delay_ms = delay;

                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            if (loaded) {
                self.retry_metrics.successful_operations += 1;
                self.circuit_breaker.recordSuccess(); // v23.23
                return RetryResult{
                    .success = true,
                    .attempts = attempts + 1,
                    .total_delay_ms = total_delay,
                };
            }

            attempts += 1;
            // v23.20: Track retry
            self.retry_metrics.total_retries += 1;
            self.retry_metrics.page_load_retries += 1;

            if (attempts > self.retry_config.max_retries) {
                break;
            }

            const delay = self.retry_config.getDelayWithJitter(attempts - 1);
            const next_timeout = self.retry_config.getTimeout(timeout_ms, attempts);
            total_delay += delay;
            self.retry_metrics.total_delay_ms += delay;
            if (delay > self.retry_metrics.max_delay_ms) self.retry_metrics.max_delay_ms = delay;

            std.debug.print("    [RETRY] Page load timeout, attempt {d}/{d}, waiting {d}ms, next timeout: {d}ms\n", .{ attempts, self.retry_config.max_retries + 1, delay, next_timeout });
            std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
        }

        self.retry_metrics.failed_operations += 1;
        self.circuit_breaker.recordFailure(); // v23.23
        return RetryResult{
            .success = false,
            .attempts = attempts,
            .total_delay_ms = total_delay,
        };
    }

    /// Click with retry (v23.16, v23.20: metrics)
    pub fn clickWithRetry(self: *Self, selector: []const u8) AgentError!RetryResult {
        // v23.23: Check circuit breaker
        if (!self.circuit_breaker.canExecute()) {
            std.debug.print("    [CIRCUIT] click blocked - circuit is OPEN\n", .{});
            return RetryResult{ .success = false, .attempts = 0, .total_delay_ms = 0 };
        }

        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        // v23.20: Track operation
        self.retry_metrics.total_operations += 1;

        while (attempts <= self.retry_config.max_retries) {
            self.clickSelector(selector) catch |err| {
                attempts += 1;
                // v23.20: Track retry
                self.retry_metrics.total_retries += 1;
                self.retry_metrics.click_retries += 1;

                if (attempts > self.retry_config.max_retries) {
                    self.retry_metrics.failed_operations += 1;
                    self.circuit_breaker.recordFailure(); // v23.23
                    return err;
                }
                const delay = self.retry_config.getDelayWithJitter(attempts - 1);
                total_delay += delay;
                self.retry_metrics.total_delay_ms += delay;
                if (delay > self.retry_metrics.max_delay_ms) self.retry_metrics.max_delay_ms = delay;

                std.debug.print("    [RETRY] Click failed, attempt {d}, waiting {d}ms\n", .{ attempts, delay });
                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            self.retry_metrics.successful_operations += 1;
            self.circuit_breaker.recordSuccess(); // v23.23
            return RetryResult{
                .success = true,
                .attempts = attempts + 1,
                .total_delay_ms = total_delay,
            };
        }

        self.retry_metrics.failed_operations += 1;
        self.circuit_breaker.recordFailure(); // v23.23
        return RetryResult{
            .success = false,
            .attempts = attempts,
            .total_delay_ms = total_delay,
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

    /// Save domain stats to file (v23.21)
    pub fn saveDomainStats(self: *Self) !void {
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

    /// Load domain stats from file (v23.21)
    pub fn loadDomainStats(self: *Self) !void {
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
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should not crash
    agent.close();
    try std.testing.expect(!agent.connected);
}

test "RealAgent methods exist" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.selectOption("select#country", "US") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "checkBox method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.captureScreenshot() catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "captureElementScreenshot method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.captureElementScreenshot("#main") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "extractDomain parses URLs correctly" {
    // HTTPS
    try std.testing.expectEqualStrings("example.com", RealAgent.extractDomain("https://example.com/page").?);
    try std.testing.expectEqualStrings("google.com", RealAgent.extractDomain("https://google.com").?);
    try std.testing.expectEqualStrings("sub.domain.org", RealAgent.extractDomain("https://sub.domain.org/path/to/page").?);

    // HTTP
    try std.testing.expectEqualStrings("localhost:8080", RealAgent.extractDomain("http://localhost:8080/api").?);

    // Edge cases - "invalid" returns "invalid" since no protocol
    try std.testing.expectEqualStrings("invalid", RealAgent.extractDomain("invalid").?);
    try std.testing.expect(RealAgent.extractDomain("https://") == null);
}

test "domain-specific timing" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    const selectors = [_][]const u8{ "#btn1", "#btn2" };
    _ = agent.waitForSelectors(&selectors, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForAnySelector method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    const selectors = [_][]const u8{ "#success", "#error" };
    _ = agent.waitForAnySelector(&selectors, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "fillFormWithWait method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    const selectors = [_][]const u8{ "#username", "#password" };
    const values = [_][]const u8{ "user", "pass" };
    _ = agent.fillFormWithWait(&selectors, &values, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForNetworkIdle method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.waitForNetworkIdle(1000, 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForFullLoad method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Should fail with BrowserConnectionFailed since not connected
    _ = agent.navigateWithRetry("https://example.com") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "waitForSelectorWithRetry method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    _ = agent.waitForSelectorWithRetry("#test", 100) catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "clickWithRetry method exists" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    _ = agent.clickWithRetry("#btn") catch |err| {
        try std.testing.expect(err == AgentError.BrowserConnectionFailed);
    };
}

test "setRetryConfig changes config" {
    const allocator = std.testing.allocator;
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
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
        var agent = RealAgent.init(allocator, .{});
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
        var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
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
    var agent = RealAgent.init(allocator, .{});
    defer agent.deinit();

    // Change jitter strategy
    agent.retry_config.jitter_strategy = .full;
    try std.testing.expectEqual(JitterStrategy.full, agent.retry_config.jitter_strategy);

    agent.retry_config.jitter_strategy = .decorrelated;
    try std.testing.expectEqual(JitterStrategy.decorrelated, agent.retry_config.jitter_strategy);
}
