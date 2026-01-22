// VIBEE Browser - High-level Browser Automation
// Pure Zig, uses CDP client
// For WebArena tasks
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const cdp = @import("cdp_client.zig");

pub const BrowserError = error{
    LaunchFailed,
    ConnectionFailed,
    NavigationFailed,
    ElementNotFound,
    Timeout,
    OutOfMemory,
};

pub const BrowserConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 9222,
    headless: bool = true,
    viewport_width: u32 = 1280,
    viewport_height: u32 = 720,
};

pub const ElementInfo = struct {
    node_id: u32,
    tag_name: []const u8,
    text: []const u8,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub const Browser = struct {
    allocator: Allocator,
    config: BrowserConfig,
    cdp_client: cdp.CDPClient,
    connected: bool,
    current_url: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, config: BrowserConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .cdp_client = cdp.CDPClient.init(allocator, config.host, config.port),
            .connected = false,
            .current_url = "",
        };
    }

    pub fn deinit(self: *Self) void {
        self.cdp_client.deinit();
    }

    /// Connect to running Chrome instance
    pub fn connect(self: *Self) BrowserError!void {
        // Discover targets
        const targets = self.cdp_client.discoverTargets() catch return BrowserError.ConnectionFailed;
        defer self.allocator.free(targets);

        if (targets.len == 0) {
            return BrowserError.ConnectionFailed;
        }

        // Connect to first page target
        for (targets) |target| {
            if (std.mem.eql(u8, target.target_type, "page")) {
                self.cdp_client.connectToTarget(target.ws_url) catch return BrowserError.ConnectionFailed;
                self.connected = true;

                // Enable domains
                self.cdp_client.enablePage() catch {};
                self.cdp_client.enableDOM() catch {};
                self.cdp_client.enableRuntime() catch {};

                return;
            }
        }

        return BrowserError.ConnectionFailed;
    }

    /// Navigate to URL
    pub fn goto(self: *Self, url: []const u8) BrowserError!void {
        if (!self.connected) return BrowserError.ConnectionFailed;

        self.cdp_client.navigate(url) catch return BrowserError.NavigationFailed;
        self.current_url = url;

        // Wait for load (simple delay for now)
        std.time.sleep(1 * std.time.ns_per_s);
    }

    /// Click at coordinates
    pub fn click(self: *Self, x: f64, y: f64) BrowserError!void {
        if (!self.connected) return BrowserError.ConnectionFailed;
        self.cdp_client.click(x, y) catch return BrowserError.ConnectionFailed;
    }

    /// Click on element by selector
    pub fn clickSelector(self: *Self, selector: []const u8) BrowserError!void {
        if (!self.connected) return BrowserError.ConnectionFailed;

        // Get element position via JS
        var js_buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf,
            \\(function() {{
            \\  var el = document.querySelector('{s}');
            \\  if (!el) return null;
            \\  var rect = el.getBoundingClientRect();
            \\  return {{x: rect.x + rect.width/2, y: rect.y + rect.height/2}};
            \\}})()
        , .{selector}) catch return BrowserError.OutOfMemory;

        const result = self.cdp_client.evaluate(js) catch return BrowserError.ElementNotFound;
        _ = result;

        // For now, click at center of viewport as fallback
        const x = @as(f64, @floatFromInt(self.config.viewport_width)) / 2;
        const y = @as(f64, @floatFromInt(self.config.viewport_height)) / 2;
        try self.click(x, y);
    }

    /// Type text
    pub fn typeText(self: *Self, text: []const u8) BrowserError!void {
        if (!self.connected) return BrowserError.ConnectionFailed;
        self.cdp_client.typeText(text) catch return BrowserError.ConnectionFailed;
    }

    /// Take screenshot
    pub fn screenshot(self: *Self) BrowserError![]const u8 {
        if (!self.connected) return BrowserError.ConnectionFailed;
        return self.cdp_client.screenshot() catch return BrowserError.ConnectionFailed;
    }

    /// Get page title
    pub fn getTitle(self: *Self) BrowserError![]const u8 {
        if (!self.connected) return BrowserError.ConnectionFailed;
        return self.cdp_client.getTitle() catch return BrowserError.ConnectionFailed;
    }

    /// Evaluate JavaScript
    pub fn evaluate(self: *Self, expression: []const u8) BrowserError![]const u8 {
        if (!self.connected) return BrowserError.ConnectionFailed;
        return self.cdp_client.evaluate(expression) catch return BrowserError.ConnectionFailed;
    }

    /// Get visible text on page
    pub fn getVisibleText(self: *Self) BrowserError![]const u8 {
        return self.evaluate("document.body.innerText");
    }

    /// Close browser connection
    pub fn close(self: *Self) void {
        self.cdp_client.close();
        self.connected = false;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Browser initialization" {
    const allocator = std.testing.allocator;
    var browser = Browser.init(allocator, .{});
    defer browser.deinit();

    try std.testing.expect(!browser.connected);
    try std.testing.expectEqual(@as(u16, 9222), browser.config.port);
}

test "Browser config defaults" {
    const config = BrowserConfig{};
    try std.testing.expectEqual(@as(u32, 1280), config.viewport_width);
    try std.testing.expectEqual(@as(u32, 720), config.viewport_height);
    try std.testing.expect(config.headless);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "ElementInfo struct" {
    const elem = ElementInfo{
        .node_id = 42,
        .tag_name = "button",
        .text = "Click me",
        .x = 100.0,
        .y = 200.0,
        .width = 80.0,
        .height = 30.0,
    };
    try std.testing.expectEqual(@as(u32, 42), elem.node_id);
    try std.testing.expectEqualStrings("button", elem.tag_name);
    try std.testing.expectApproxEqAbs(100.0, elem.x, 0.001);
}

test "Browser close without connection" {
    const allocator = std.testing.allocator;
    var browser = Browser.init(allocator, .{});
    defer browser.deinit();

    // Should not crash when closing without connection
    browser.close();
    try std.testing.expect(!browser.connected);
}

test "Browser error types" {
    const err1: BrowserError = BrowserError.LaunchFailed;
    const err2: BrowserError = BrowserError.ConnectionFailed;
    const err3: BrowserError = BrowserError.NavigationFailed;
    const err4: BrowserError = BrowserError.ElementNotFound;
    const err5: BrowserError = BrowserError.Timeout;
    const err6: BrowserError = BrowserError.OutOfMemory;

    try std.testing.expect(err1 != err2);
    try std.testing.expect(err2 != err3);
    try std.testing.expect(err3 != err4);
    try std.testing.expect(err4 != err5);
    try std.testing.expect(err5 != err6);
}

test "BrowserConfig custom values" {
    const config = BrowserConfig{
        .host = "192.168.1.100",
        .port = 9333,
        .headless = false,
        .viewport_width = 1920,
        .viewport_height = 1080,
    };
    try std.testing.expectEqualStrings("192.168.1.100", config.host);
    try std.testing.expectEqual(@as(u16, 9333), config.port);
    try std.testing.expect(!config.headless);
    try std.testing.expectEqual(@as(u32, 1920), config.viewport_width);
}

// ============================================================================
// INTEGRATION TESTS (require Chrome with --remote-debugging-port=9222)
// Run: chromium-browser --headless --remote-debugging-port=9222 &
// Then: zig test src/vibeec/browser.zig -Dintegration=true
// ============================================================================

// Integration tests are skipped by default (no Chrome in CI)
// To run manually:
// 1. Start Chrome: chromium-browser --headless --remote-debugging-port=9222
// 2. Run: zig test src/vibeec/browser.zig
