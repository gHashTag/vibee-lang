// VIBEE E2E Test - Real Browser Integration
// Tests actual browser automation with Chrome headless
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const real_agent = @import("real_agent.zig");
const planning_agent = @import("planning_agent.zig");

pub const E2ETestResult = struct {
    test_name: []const u8,
    passed: bool,
    steps: u32,
    latency_ms: u64,
    error_message: ?[]const u8,
};

pub const E2ETestSuite = struct {
    allocator: Allocator,
    results: std.ArrayList(E2ETestResult),
    ws_url: []const u8,
    total_passed: u32,
    total_failed: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, ws_url: []const u8) Self {
        return Self{
            .allocator = allocator,
            .results = std.ArrayList(E2ETestResult).init(allocator),
            .ws_url = ws_url,
            .total_passed = 0,
            .total_failed = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit();
    }

    /// Run navigation test
    pub fn testNavigation(self: *Self) !void {
        const start = std.time.milliTimestamp();

        var agent = real_agent.RealAgent.init(self.allocator, .{});
        defer agent.deinit();

        // Connect to browser
        agent.connectBrowser(self.ws_url) catch {
            try self.addResult("Navigation", false, 0, 0, "Failed to connect to browser");
            return;
        };

        // Navigate to example.com
        agent.navigate("https://example.com") catch {
            try self.addResult("Navigation", false, 0, 0, "Failed to navigate");
            return;
        };

        // Wait for page load
        std.time.sleep(2 * std.time.ns_per_s);

        // Get URL
        const url = agent.getURL() catch {
            try self.addResult("Navigation", false, 1, 0, "Failed to get URL");
            return;
        };
        defer self.allocator.free(url);

        const elapsed = std.time.milliTimestamp() - start;

        // Check result
        if (std.mem.indexOf(u8, url, "example.com") != null) {
            try self.addResult("Navigation", true, 1, @intCast(elapsed), null);
        } else {
            try self.addResult("Navigation", false, 1, @intCast(elapsed), "URL mismatch");
        }
    }

    /// Run title extraction test
    pub fn testGetTitle(self: *Self) !void {
        const start = std.time.milliTimestamp();

        var agent = real_agent.RealAgent.init(self.allocator, .{});
        defer agent.deinit();

        agent.connectBrowser(self.ws_url) catch {
            try self.addResult("GetTitle", false, 0, 0, "Failed to connect");
            return;
        };

        agent.navigate("https://example.com") catch {
            try self.addResult("GetTitle", false, 0, 0, "Failed to navigate");
            return;
        };

        std.time.sleep(2 * std.time.ns_per_s);

        const title = agent.getTitle() catch {
            try self.addResult("GetTitle", false, 1, 0, "Failed to get title");
            return;
        };
        defer self.allocator.free(title);

        const elapsed = std.time.milliTimestamp() - start;

        if (std.mem.indexOf(u8, title, "Example") != null) {
            try self.addResult("GetTitle", true, 1, @intCast(elapsed), null);
        } else {
            try self.addResult("GetTitle", false, 1, @intCast(elapsed), "Title mismatch");
        }
    }

    /// Run click test
    pub fn testClick(self: *Self) !void {
        const start = std.time.milliTimestamp();

        var agent = real_agent.RealAgent.init(self.allocator, .{});
        defer agent.deinit();

        agent.connectBrowser(self.ws_url) catch {
            try self.addResult("Click", false, 0, 0, "Failed to connect");
            return;
        };

        agent.navigate("https://example.com") catch {
            try self.addResult("Click", false, 0, 0, "Failed to navigate");
            return;
        };

        std.time.sleep(2 * std.time.ns_per_s);

        // Click on the "More information" link
        agent.clickSelector("a") catch {
            try self.addResult("Click", false, 1, 0, "Failed to click");
            return;
        };

        std.time.sleep(2 * std.time.ns_per_s);

        // Check if URL changed
        const url = agent.getURL() catch {
            try self.addResult("Click", false, 2, 0, "Failed to get URL after click");
            return;
        };
        defer self.allocator.free(url);

        const elapsed = std.time.milliTimestamp() - start;

        // Should navigate to iana.org
        if (std.mem.indexOf(u8, url, "iana.org") != null) {
            try self.addResult("Click", true, 2, @intCast(elapsed), null);
        } else {
            try self.addResult("Click", false, 2, @intCast(elapsed), "URL did not change to iana.org");
        }
    }

    /// Run full agent test with Ollama
    pub fn testPlanningAgent(self: *Self) !void {
        const start = std.time.milliTimestamp();

        var agent = planning_agent.PlanningAgent.init(
            self.allocator,
            "Go to example.com and tell me the page title",
            5, // max steps
        );
        defer agent.deinit();

        // Connect to browser
        agent.connect(self.ws_url) catch {
            try self.addResult("PlanningAgent", false, 0, 0, "Failed to connect");
            return;
        };

        // Run agent
        const result = agent.run() catch {
            try self.addResult("PlanningAgent", false, agent.state.current_step, 0, "Agent run failed");
            return;
        };

        const elapsed = std.time.milliTimestamp() - start;

        // Check if goal was achieved
        if (agent.state.done and std.mem.indexOf(u8, result, "Example") != null) {
            try self.addResult("PlanningAgent", true, agent.state.current_step, @intCast(elapsed), null);
        } else {
            try self.addResult("PlanningAgent", false, agent.state.current_step, @intCast(elapsed), "Goal not achieved");
        }
    }

    fn addResult(self: *Self, name: []const u8, passed: bool, steps: u32, latency: u64, err: ?[]const u8) !void {
        try self.results.append(E2ETestResult{
            .test_name = name,
            .passed = passed,
            .steps = steps,
            .latency_ms = latency,
            .error_message = err,
        });

        if (passed) {
            self.total_passed += 1;
        } else {
            self.total_failed += 1;
        }
    }

    /// Print results
    pub fn printResults(self: *Self) void {
        const stdout = std.io.getStdOut().writer();

        stdout.print("\n", .{}) catch {};
        stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{}) catch {};
        stdout.print("║              VIBEE E2E TEST RESULTS v23.5                        ║\n", .{}) catch {};
        stdout.print("║                    φ² + 1/φ² = 3                                 ║\n", .{}) catch {};
        stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{}) catch {};

        for (self.results.items) |result| {
            const status = if (result.passed) "✅ PASS" else "❌ FAIL";
            stdout.print("║  {s}: {s:<15} Steps: {d} Latency: {d}ms\n", .{
                status,
                result.test_name,
                result.steps,
                result.latency_ms,
            }) catch {};
            if (result.error_message) |err| {
                stdout.print("║      Error: {s}\n", .{err}) catch {};
            }
        }

        stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
        const total = self.total_passed + self.total_failed;
        const rate = if (total > 0) @as(f64, @floatFromInt(self.total_passed)) / @as(f64, @floatFromInt(total)) * 100.0 else 0.0;
        stdout.print("║  TOTAL: {d}/{d} passed ({d:.1}%)\n", .{ self.total_passed, total, rate }) catch {};
        stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{}) catch {};
    }
};

/// Run all E2E tests
pub fn runAllTests(allocator: Allocator, ws_url: []const u8) !void {
    var suite = E2ETestSuite.init(allocator, ws_url);
    defer suite.deinit();

    std.debug.print("\n[E2E] Starting tests with browser at {s}\n", .{ws_url});

    // Run tests
    std.debug.print("[E2E] Test 1: Navigation\n", .{});
    try suite.testNavigation();

    std.debug.print("[E2E] Test 2: GetTitle\n", .{});
    try suite.testGetTitle();

    std.debug.print("[E2E] Test 3: Click\n", .{});
    try suite.testClick();

    // Only run PlanningAgent test if Ollama is available
    std.debug.print("[E2E] Test 4: PlanningAgent (requires Ollama)\n", .{});
    try suite.testPlanningAgent();

    suite.printResults();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Default WebSocket URL - can be overridden
    const ws_url = "ws://localhost:9222/devtools/page/1D3702FEE924E47155EB50E12BF9DE28";

    try runAllTests(allocator, ws_url);
}

// ============================================================================
// TESTS
// ============================================================================

test "E2ETestSuite initialization" {
    const allocator = std.testing.allocator;
    var suite = E2ETestSuite.init(allocator, "ws://test");
    defer suite.deinit();

    try std.testing.expectEqual(@as(u32, 0), suite.total_passed);
    try std.testing.expectEqual(@as(u32, 0), suite.total_failed);
}

test "E2ETestResult struct" {
    const result = E2ETestResult{
        .test_name = "Test",
        .passed = true,
        .steps = 3,
        .latency_ms = 1500,
        .error_message = null,
    };

    try std.testing.expect(result.passed);
    try std.testing.expectEqual(@as(u32, 3), result.steps);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
