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

// v23.16: Retry configuration with exponential backoff
pub const RetryConfig = struct {
    max_retries: u32 = 3,
    initial_delay_ms: u32 = 500,
    backoff_factor: f32 = 2.0,
    max_delay_ms: u32 = 8000,
    // v23.17: Timeout adjustment on retry
    timeout_factor: f32 = 1.5, // Increase timeout by 50% on each retry
    max_timeout_ms: u32 = 30000, // Cap at 30 seconds

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

    const Self = @This();

    pub fn init(allocator: Allocator, config: AgentConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .ws = websocket.WebSocketClient.init(allocator),
            .http = http_client.HttpClient.init(allocator),
            .connected = false,
            .message_id = 1,
            .domain_stats = std.StringHashMap(DomainStats).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
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
        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        while (attempts <= self.retry_config.max_retries) {
            // Try navigation
            self.navigate(url) catch |err| {
                attempts += 1;
                if (attempts > self.retry_config.max_retries) {
                    std.debug.print("    [RETRY] Navigate failed after {d} attempts\n", .{attempts});
                    return err;
                }

                // Calculate backoff delay
                const delay = self.retry_config.getDelay(attempts - 1);
                total_delay += delay;
                std.debug.print("    [RETRY] Navigate attempt {d}/{d} failed, waiting {d}ms\n", .{ attempts, self.retry_config.max_retries + 1, delay });

                // Wait before retry
                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            // Success
            return RetryResult{
                .success = true,
                .attempts = attempts + 1,
                .total_delay_ms = total_delay,
            };
        }

        return RetryResult{
            .success = false,
            .attempts = attempts,
            .total_delay_ms = total_delay,
        };
    }

    /// Wait for selector with retry (v23.16)
    pub fn waitForSelectorWithRetry(self: *Self, selector: []const u8, timeout_ms: u32) AgentError!RetryResult {
        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        while (attempts <= self.retry_config.max_retries) {
            // v23.17: Increase timeout on each retry
            const current_timeout = self.retry_config.getTimeout(timeout_ms, attempts);

            const found = self.waitForSelector(selector, current_timeout) catch |err| {
                attempts += 1;
                if (attempts > self.retry_config.max_retries) {
                    return err;
                }
                const delay = self.retry_config.getDelay(attempts - 1);
                const next_timeout = self.retry_config.getTimeout(timeout_ms, attempts);
                total_delay += delay;
                std.debug.print("    [RETRY] waitForSelector attempt {d} failed, waiting {d}ms, next timeout: {d}ms\n", .{ attempts, delay, next_timeout });
                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            if (found) {
                return RetryResult{
                    .success = true,
                    .attempts = attempts + 1,
                    .total_delay_ms = total_delay,
                };
            }

            // Not found, retry with backoff and increased timeout
            attempts += 1;
            if (attempts > self.retry_config.max_retries) {
                break;
            }

            const delay = self.retry_config.getDelay(attempts - 1);
            const next_timeout = self.retry_config.getTimeout(timeout_ms, attempts);
            total_delay += delay;
            std.debug.print("    [RETRY] Selector not found, attempt {d}/{d}, waiting {d}ms, next timeout: {d}ms\n", .{ attempts, self.retry_config.max_retries + 1, delay, next_timeout });
            std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
        }

        return RetryResult{
            .success = false,
            .attempts = attempts,
            .total_delay_ms = total_delay,
        };
    }

    /// Wait for page load with retry (v23.16, v23.17: smart timeout)
    pub fn waitForPageLoadWithRetry(self: *Self, timeout_ms: u32) AgentError!RetryResult {
        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        while (attempts <= self.retry_config.max_retries) {
            // v23.17: Increase timeout on each retry
            const current_timeout = self.retry_config.getTimeout(timeout_ms, attempts);

            const loaded = self.waitForPageLoad(current_timeout) catch |err| {
                attempts += 1;
                if (attempts > self.retry_config.max_retries) {
                    return err;
                }
                const delay = self.retry_config.getDelay(attempts - 1);
                total_delay += delay;
                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            if (loaded) {
                return RetryResult{
                    .success = true,
                    .attempts = attempts + 1,
                    .total_delay_ms = total_delay,
                };
            }

            attempts += 1;
            if (attempts > self.retry_config.max_retries) {
                break;
            }

            const delay = self.retry_config.getDelay(attempts - 1);
            const next_timeout = self.retry_config.getTimeout(timeout_ms, attempts);
            total_delay += delay;
            std.debug.print("    [RETRY] Page load timeout, attempt {d}/{d}, waiting {d}ms, next timeout: {d}ms\n", .{ attempts, self.retry_config.max_retries + 1, delay, next_timeout });
            std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
        }

        return RetryResult{
            .success = false,
            .attempts = attempts,
            .total_delay_ms = total_delay,
        };
    }

    /// Click with retry (v23.16)
    pub fn clickWithRetry(self: *Self, selector: []const u8) AgentError!RetryResult {
        var attempts: u32 = 0;
        var total_delay: u32 = 0;

        while (attempts <= self.retry_config.max_retries) {
            self.clickSelector(selector) catch |err| {
                attempts += 1;
                if (attempts > self.retry_config.max_retries) {
                    return err;
                }
                const delay = self.retry_config.getDelay(attempts - 1);
                total_delay += delay;
                std.debug.print("    [RETRY] Click failed, attempt {d}, waiting {d}ms\n", .{ attempts, delay });
                std.time.sleep(@as(u64, delay) * std.time.ns_per_ms);
                continue;
            };

            return RetryResult{
                .success = true,
                .attempts = attempts + 1,
                .total_delay_ms = total_delay,
            };
        }

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
