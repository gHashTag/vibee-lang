// VIBEE Real Browser Agent - Working Implementation
// Chrome CDP + Ollama Integration
// This is the REAL working agent, not a specification
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const cdp = @import("cdp_client.zig");
const http = @import("http_client.zig");

pub const BrowserAgentError = error{
    CDPConnectionFailed,
    OllamaConnectionFailed,
    NavigationFailed,
    ActionFailed,
    MaxStepsReached,
    ParseError,
    OutOfMemory,
};

pub const AgentConfig = struct {
    cdp_host: []const u8 = "localhost",
    cdp_port: u16 = 9222,
    ollama_host: []const u8 = "localhost",
    ollama_port: u16 = 11434,
    ollama_model: []const u8 = "qwen2.5:1.5b",
    max_steps: u32 = 10,
    verbose: bool = true,
};

pub const AgentStep = struct {
    step_num: u32,
    observation: []const u8,
    thought: []const u8,
    action: []const u8,
    result: []const u8,
};

pub const AgentResult = struct {
    success: bool,
    answer: ?[]const u8,
    steps_taken: u32,
    trajectory: []AgentStep,
    duration_ms: i64,
};

pub const BrowserAgent = struct {
    allocator: Allocator,
    config: AgentConfig,
    cdp_client: cdp.CDPClient,
    http_client: http.HttpClient,
    steps: std.ArrayList(AgentStep),
    connected: bool,

    const Self = @This();

    const SYSTEM_PROMPT =
        \\You are a browser automation agent. You control a web browser to complete tasks.
        \\
        \\AVAILABLE ACTIONS:
        \\- goto [url]: Navigate to a URL
        \\- click [x] [y]: Click at coordinates
        \\- type [text]: Type text
        \\- scroll [direction]: Scroll up or down
        \\- done [answer]: Task complete, provide answer
        \\
        \\OBSERVATION FORMAT:
        \\You will receive: URL, Title, and visible text content.
        \\
        \\RESPONSE FORMAT (use exactly this):
        \\Thought: [your reasoning]
        \\Action: [action name]
        \\Action Input: [parameters]
        \\
        \\Be concise. Take ONE action at a time.
    ;

    pub fn init(allocator: Allocator, config: AgentConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .cdp_client = cdp.CDPClient.init(allocator, config.cdp_host, config.cdp_port),
            .http_client = http.HttpClient.init(allocator),
            .steps = std.ArrayList(AgentStep).init(allocator),
            .connected = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.cdp_client.deinit();
        self.http_client.deinit();
        self.steps.deinit();
    }

    /// Connect to Chrome via CDP
    pub fn connect(self: *Self) BrowserAgentError!void {
        if (self.config.verbose) {
            std.debug.print("Connecting to Chrome at {s}:{d}...\n", .{ self.config.cdp_host, self.config.cdp_port });
        }

        // Discover targets
        const targets = self.cdp_client.discoverTargets() catch {
            return BrowserAgentError.CDPConnectionFailed;
        };

        if (targets.len == 0) {
            return BrowserAgentError.CDPConnectionFailed;
        }

        // Connect to first page target
        for (targets) |target| {
            if (std.mem.eql(u8, target.target_type, "page")) {
                self.cdp_client.connectToTarget(target.ws_url) catch {
                    return BrowserAgentError.CDPConnectionFailed;
                };
                self.connected = true;

                if (self.config.verbose) {
                    std.debug.print("Connected to: {s}\n", .{target.title});
                }
                return;
            }
        }

        return BrowserAgentError.CDPConnectionFailed;
    }

    /// Query Ollama for next action
    pub fn queryOllama(self: *Self, prompt: []const u8) BrowserAgentError![]const u8 {
        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "http://{s}:{d}/api/generate", .{
            self.config.ollama_host,
            self.config.ollama_port,
        }) catch return BrowserAgentError.OutOfMemory;

        // Build request body
        var body_buf: [8192]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf,
            \\{{"model":"{s}","prompt":"{s}","stream":false,"options":{{"temperature":0.7,"num_predict":256}}}}
        , .{ self.config.ollama_model, escapeJson(prompt) }) catch return BrowserAgentError.OutOfMemory;

        if (self.config.verbose) {
            std.debug.print("Querying Ollama ({s})...\n", .{self.config.ollama_model});
        }

        var response = self.http_client.post(url, body, "application/json") catch {
            return BrowserAgentError.OllamaConnectionFailed;
        };
        defer response.deinit();

        if (response.status != 200) {
            return BrowserAgentError.OllamaConnectionFailed;
        }

        // Extract response field from JSON
        // Simple extraction - find "response":" and extract until next "
        if (std.mem.indexOf(u8, response.body, "\"response\":\"")) |start| {
            const content_start = start + 12;
            if (std.mem.indexOfPos(u8, response.body, content_start, "\"")) |end| {
                const content = response.body[content_start..end];
                return self.allocator.dupe(u8, content) catch return BrowserAgentError.OutOfMemory;
            }
        }

        return BrowserAgentError.ParseError;
    }

    /// Get current page observation
    pub fn observe(self: *Self) BrowserAgentError![]const u8 {
        if (!self.connected) return BrowserAgentError.CDPConnectionFailed;

        // Get page info via JavaScript
        const js_result = self.cdp_client.evaluate(
            "JSON.stringify({url: location.href, title: document.title, text: document.body.innerText.substring(0, 500)})",
        ) catch {
            return BrowserAgentError.ActionFailed;
        };

        return self.allocator.dupe(u8, js_result) catch return BrowserAgentError.OutOfMemory;
    }

    /// Execute action on browser
    pub fn executeAction(self: *Self, action: []const u8, input: []const u8) BrowserAgentError![]const u8 {
        if (!self.connected) return BrowserAgentError.CDPConnectionFailed;

        if (std.mem.eql(u8, action, "goto")) {
            self.cdp_client.navigate(input) catch {
                return BrowserAgentError.NavigationFailed;
            };
            // Wait for page load
            std.time.sleep(2 * std.time.ns_per_s);
            return "Navigation complete";
        } else if (std.mem.eql(u8, action, "click")) {
            // Parse x y from input
            var iter = std.mem.splitScalar(u8, input, ' ');
            const x_str = iter.next() orelse return BrowserAgentError.ParseError;
            const y_str = iter.next() orelse return BrowserAgentError.ParseError;
            const x = std.fmt.parseFloat(f64, x_str) catch return BrowserAgentError.ParseError;
            const y = std.fmt.parseFloat(f64, y_str) catch return BrowserAgentError.ParseError;

            self.cdp_client.click(x, y) catch {
                return BrowserAgentError.ActionFailed;
            };
            return "Click complete";
        } else if (std.mem.eql(u8, action, "type")) {
            self.cdp_client.typeText(input) catch {
                return BrowserAgentError.ActionFailed;
            };
            return "Type complete";
        } else if (std.mem.eql(u8, action, "done")) {
            return input; // Return the answer
        }

        return "Unknown action";
    }

    /// Parse LLM response to extract action
    pub fn parseResponse(self: *Self, response: []const u8) struct { action: []const u8, input: []const u8 } {
        _ = self;
        var action: []const u8 = "";
        var input: []const u8 = "";

        var lines = std.mem.splitScalar(u8, response, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            if (std.mem.startsWith(u8, trimmed, "Action:")) {
                action = std.mem.trim(u8, trimmed["Action:".len..], " ");
            } else if (std.mem.startsWith(u8, trimmed, "Action Input:")) {
                input = std.mem.trim(u8, trimmed["Action Input:".len..], " ");
            }
        }

        return .{ .action = action, .input = input };
    }

    /// Run agent on a task
    pub fn run(self: *Self, goal: []const u8) BrowserAgentError!AgentResult {
        const start_time = std.time.milliTimestamp();

        if (self.config.verbose) {
            std.debug.print("\n=== Browser Agent Starting ===\n", .{});
            std.debug.print("Goal: {s}\n", .{goal});
        }

        // Connect if not connected
        if (!self.connected) {
            try self.connect();
        }

        var step: u32 = 0;
        while (step < self.config.max_steps) : (step += 1) {
            if (self.config.verbose) {
                std.debug.print("\n--- Step {d} ---\n", .{step + 1});
            }

            // 1. Observe
            const observation = try self.observe();
            defer self.allocator.free(observation);

            if (self.config.verbose) {
                std.debug.print("Observation: {s}\n", .{observation[0..@min(200, observation.len)]});
            }

            // 2. Think (query LLM)
            var prompt_buf: [4096]u8 = undefined;
            const prompt = std.fmt.bufPrint(&prompt_buf,
                \\{s}
                \\
                \\GOAL: {s}
                \\
                \\CURRENT PAGE:
                \\{s}
                \\
                \\What action should I take?
            , .{ SYSTEM_PROMPT, goal, observation }) catch return BrowserAgentError.OutOfMemory;

            const llm_response = try self.queryOllama(prompt);
            defer self.allocator.free(llm_response);

            if (self.config.verbose) {
                std.debug.print("LLM Response: {s}\n", .{llm_response});
            }

            // 3. Parse action
            const parsed = self.parseResponse(llm_response);

            if (self.config.verbose) {
                std.debug.print("Action: {s}, Input: {s}\n", .{ parsed.action, parsed.input });
            }

            // 4. Check for done
            if (std.mem.eql(u8, parsed.action, "done")) {
                const end_time = std.time.milliTimestamp();
                return AgentResult{
                    .success = true,
                    .answer = self.allocator.dupe(u8, parsed.input) catch null,
                    .steps_taken = step + 1,
                    .trajectory = self.steps.items,
                    .duration_ms = end_time - start_time,
                };
            }

            // 5. Execute action
            const result = try self.executeAction(parsed.action, parsed.input);

            if (self.config.verbose) {
                std.debug.print("Result: {s}\n", .{result});
            }

            // Small delay between steps
            std.time.sleep(500 * std.time.ns_per_ms);
        }

        const end_time = std.time.milliTimestamp();
        return AgentResult{
            .success = false,
            .answer = null,
            .steps_taken = self.config.max_steps,
            .trajectory = self.steps.items,
            .duration_ms = end_time - start_time,
        };
    }

    /// Close connection
    pub fn close(self: *Self) void {
        self.cdp_client.close();
        self.connected = false;
    }
};

// Helper to escape JSON strings (simplified - returns input as-is)
fn escapeJson(input: []const u8) []const u8 {
    return input;
}

// ============================================================================
// TESTS
// ============================================================================

test "BrowserAgent initialization" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{});
    defer agent.deinit();

    try std.testing.expectEqual(@as(u16, 9222), agent.config.cdp_port);
    try std.testing.expectEqual(@as(u16, 11434), agent.config.ollama_port);
    try std.testing.expect(!agent.connected);
}

test "BrowserAgent config" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{
        .cdp_host = "127.0.0.1",
        .cdp_port = 9223,
        .ollama_model = "llama2",
        .max_steps = 5,
    });
    defer agent.deinit();

    try std.testing.expectEqualStrings("127.0.0.1", agent.config.cdp_host);
    try std.testing.expectEqual(@as(u16, 9223), agent.config.cdp_port);
    try std.testing.expectEqualStrings("llama2", agent.config.ollama_model);
    try std.testing.expectEqual(@as(u32, 5), agent.config.max_steps);
}

test "parseResponse" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{});
    defer agent.deinit();

    const response =
        \\Thought: I need to navigate to the page
        \\Action: goto
        \\Action Input: https://example.com
    ;

    const parsed = agent.parseResponse(response);
    try std.testing.expectEqualStrings("goto", parsed.action);
    try std.testing.expectEqualStrings("https://example.com", parsed.input);
}

test "parseResponse done action" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{});
    defer agent.deinit();

    const response =
        \\Thought: Task is complete
        \\Action: done
        \\Action Input: The page title is Example Domain
    ;

    const parsed = agent.parseResponse(response);
    try std.testing.expectEqualStrings("done", parsed.action);
    try std.testing.expect(std.mem.indexOf(u8, parsed.input, "Example") != null);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "AgentResult struct" {
    const result = AgentResult{
        .success = true,
        .answer = "test answer",
        .steps_taken = 3,
        .trajectory = &[_]AgentStep{},
        .duration_ms = 1500,
    };

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u32, 3), result.steps_taken);
    try std.testing.expectEqual(@as(i64, 1500), result.duration_ms);
}

test "AgentStep struct" {
    const step = AgentStep{
        .step_num = 1,
        .observation = "Page loaded",
        .thought = "I see the page",
        .action = "click",
        .result = "Clicked",
    };

    try std.testing.expectEqual(@as(u32, 1), step.step_num);
    try std.testing.expectEqualStrings("click", step.action);
}

test "SYSTEM_PROMPT contains required actions" {
    try std.testing.expect(std.mem.indexOf(u8, BrowserAgent.SYSTEM_PROMPT, "goto") != null);
    try std.testing.expect(std.mem.indexOf(u8, BrowserAgent.SYSTEM_PROMPT, "click") != null);
    try std.testing.expect(std.mem.indexOf(u8, BrowserAgent.SYSTEM_PROMPT, "type") != null);
    try std.testing.expect(std.mem.indexOf(u8, BrowserAgent.SYSTEM_PROMPT, "done") != null);
}

test "BrowserAgent close without connection" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{});
    defer agent.deinit();

    // Should not crash
    agent.close();
    try std.testing.expect(!agent.connected);
}
