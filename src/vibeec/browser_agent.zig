// VIBEE Browser Agent - LLM + Browser Integration
// Full ReAct loop for WebArena tasks
// Observe → Think → Act → Repeat
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const openai = @import("openai_client.zig");
const browser_mod = @import("browser.zig");
const task_mod = @import("webarena_task.zig");

pub const BrowserAgentError = error{
    LLMError,
    BrowserError,
    ParseError,
    MaxStepsReached,
    Timeout,
    OutOfMemory,
};

pub const BrowserAgentConfig = struct {
    // LLM settings
    llm_api_key: []const u8,
    llm_provider: openai.Provider = .groq, // Default to FREE Groq!
    llm_model: []const u8 = openai.GROQ_MODEL,

    // Browser settings
    browser_host: []const u8 = "localhost",
    browser_port: u16 = 9222,

    // Execution settings
    max_steps: u32 = 30,
    timeout_ms: u64 = 120000,
    verbose: bool = false,
};

pub const StepResult = struct {
    step_number: u32,
    observation: []const u8,
    thought: []const u8,
    action: []const u8,
    action_input: []const u8,
    action_result: []const u8,
    tokens_used: u32,
};

pub const BrowserAgentResult = struct {
    task_id: i64,
    success: bool,
    final_answer: ?[]const u8,
    steps_taken: u32,
    total_tokens: u32,
    elapsed_ms: u64,
    allocator: Allocator,

    pub fn deinit(self: *BrowserAgentResult) void {
        if (self.final_answer) |ans| {
            self.allocator.free(ans);
        }
    }
};

pub const BrowserAgent = struct {
    allocator: Allocator,
    config: BrowserAgentConfig,
    llm: openai.OpenAIClient,
    browser: browser_mod.Browser,
    history: std.ArrayList([]const u8),
    total_tokens: u32,

    const Self = @This();

    const SYSTEM_PROMPT =
        \\You are an autonomous web agent that completes tasks on websites.
        \\
        \\AVAILABLE ACTIONS:
        \\- click [selector]: Click on an element (e.g., click [#submit-btn] or click [.nav-link])
        \\- type [text]: Type text into the focused input (e.g., type "search query")
        \\- goto [url]: Navigate to URL (e.g., goto "https://example.com")
        \\- scroll [direction]: Scroll up or down (e.g., scroll down)
        \\- go_back: Go back to previous page
        \\- press [key]: Press a key (e.g., press "Enter")
        \\- stop [answer]: Complete task with final answer
        \\
        \\FORMAT (use exactly this format):
        \\Thought: [your reasoning about the current page and what to do next]
        \\Action: [action name]
        \\Action Input: [action parameters]
        \\
        \\RULES:
        \\1. Analyze the page observation carefully before acting
        \\2. Take ONE action at a time
        \\3. Use stop [answer] when the task is complete
        \\4. Be concise in your reasoning
        \\5. If stuck, try scrolling or going back
    ;

    pub fn init(allocator: Allocator, config: BrowserAgentConfig) Self {
        // Initialize LLM based on provider
        var llm = switch (config.llm_provider) {
            .openai => openai.OpenAIClient.init(allocator, config.llm_api_key),
            .groq => openai.OpenAIClient.initGroq(allocator, config.llm_api_key),
            .together => openai.OpenAIClient.initTogether(allocator, config.llm_api_key),
            .ollama => openai.OpenAIClient.initOllama(allocator),
            .huggingface => openai.OpenAIClient.initHuggingFace(allocator, config.llm_api_key),
        };
        llm.setModel(config.llm_model);

        // Initialize browser
        const browser_config = browser_mod.BrowserConfig{
            .host = config.browser_host,
            .port = config.browser_port,
        };

        return Self{
            .allocator = allocator,
            .config = config,
            .llm = llm,
            .browser = browser_mod.Browser.init(allocator, browser_config),
            .history = std.ArrayList([]const u8).init(allocator),
            .total_tokens = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit();
        self.browser.deinit();
        self.llm.deinit();
    }

    /// Connect to browser
    pub fn connect(self: *Self) BrowserAgentError!void {
        self.browser.connect() catch return BrowserAgentError.BrowserError;
    }

    /// Run a WebArena task
    pub fn runTask(self: *Self, task: *const task_mod.WebArenaTask) BrowserAgentError!BrowserAgentResult {
        const start_time = std.time.milliTimestamp();

        // Clear history
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.clearRetainingCapacity();
        self.total_tokens = 0;

        // Navigate to start URL
        self.browser.goto(task.getStartUrl()) catch return BrowserAgentError.BrowserError;

        // Add task intent to history
        const task_msg = std.fmt.allocPrint(self.allocator, "Task: {s}\nStart URL: {s}", .{ task.getIntent(), task.getStartUrl() }) catch return BrowserAgentError.OutOfMemory;
        self.history.append(task_msg) catch return BrowserAgentError.OutOfMemory;

        var step: u32 = 0;
        while (step < self.config.max_steps) : (step += 1) {
            // 1. OBSERVE - Get page state
            const observation = self.browser.getObservation(4000) catch return BrowserAgentError.BrowserError;

            // 2. Build prompt with observation
            const prompt = self.buildPrompt(observation) catch return BrowserAgentError.OutOfMemory;
            defer self.allocator.free(prompt);

            if (self.config.verbose) {
                std.debug.print("\n=== Step {d} ===\nObservation: {s}\n", .{ step + 1, observation });
            }

            // 3. THINK - Call LLM
            var response = self.llm.chatWithSystem(SYSTEM_PROMPT, prompt) catch return BrowserAgentError.LLMError;
            defer response.deinit();

            self.total_tokens += response.total_tokens;

            if (self.config.verbose) {
                std.debug.print("LLM Response:\n{s}\n", .{response.content});
            }

            // 4. Parse response
            const parsed = self.parseResponse(response.content) catch return BrowserAgentError.ParseError;

            // Add to history
            const step_msg = std.fmt.allocPrint(self.allocator, "Step {d}:\nObservation: {s}\n{s}", .{ step + 1, observation, response.content }) catch return BrowserAgentError.OutOfMemory;
            self.history.append(step_msg) catch return BrowserAgentError.OutOfMemory;

            // 5. Check for final answer
            if (std.mem.eql(u8, parsed.action, "stop") or std.mem.eql(u8, parsed.action, "final_answer")) {
                const answer = self.allocator.dupe(u8, parsed.action_input) catch return BrowserAgentError.OutOfMemory;
                const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

                // Check if answer is correct
                const success = task.evaluate(parsed.action_input, self.browser.current_url);

                return BrowserAgentResult{
                    .task_id = task.task_id,
                    .success = success,
                    .final_answer = answer,
                    .steps_taken = step + 1,
                    .total_tokens = self.total_tokens,
                    .elapsed_ms = elapsed,
                    .allocator = self.allocator,
                };
            }

            // 6. ACT - Execute action in browser
            _ = self.browser.executeAction(parsed.action, parsed.action_input) catch |err| {
                if (self.config.verbose) {
                    std.debug.print("Action failed: {}\n", .{err});
                }
                // Continue anyway - let LLM recover
            };

            // Small delay between steps
            std.time.sleep(500 * std.time.ns_per_ms);
        }

        // Max steps reached
        const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
        return BrowserAgentResult{
            .task_id = task.task_id,
            .success = false,
            .final_answer = null,
            .steps_taken = step,
            .total_tokens = self.total_tokens,
            .elapsed_ms = elapsed,
            .allocator = self.allocator,
        };
    }

    /// Build prompt with current observation
    fn buildPrompt(self: *Self, observation: []const u8) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);
        errdefer prompt.deinit();

        // Add history (last few steps)
        const history_start = if (self.history.items.len > 3) self.history.items.len - 3 else 0;
        for (self.history.items[history_start..]) |item| {
            try prompt.appendSlice(item);
            try prompt.appendSlice("\n\n");
        }

        // Add current observation
        try prompt.appendSlice("Current page observation:\n");
        try prompt.appendSlice(observation);
        try prompt.appendSlice("\n\nWhat is your next action?");

        return prompt.toOwnedSlice();
    }

    /// Parse LLM response to extract action
    fn parseResponse(self: *Self, response: []const u8) !struct { action: []const u8, action_input: []const u8 } {
        _ = self;

        var action: []const u8 = "";
        var action_input: []const u8 = "";

        // Find "Action:" line
        if (std.mem.indexOf(u8, response, "Action:")) |action_start| {
            const after_action = response[action_start + 7 ..];
            // Find end of line
            const action_end = std.mem.indexOf(u8, after_action, "\n") orelse after_action.len;
            action = std.mem.trim(u8, after_action[0..action_end], " \t\r");
        }

        // Find "Action Input:" line
        if (std.mem.indexOf(u8, response, "Action Input:")) |input_start| {
            const after_input = response[input_start + 13 ..];
            // Find end of line or end of string
            const input_end = std.mem.indexOf(u8, after_input, "\n") orelse after_input.len;
            action_input = std.mem.trim(u8, after_input[0..input_end], " \t\r");
        }

        if (action.len == 0) {
            return error.ParseError;
        }

        return .{ .action = action, .action_input = action_input };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "BrowserAgent initialization" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{
        .llm_api_key = "test-key",
        .llm_provider = .groq,
    });
    defer agent.deinit();

    try std.testing.expectEqual(@as(u32, 30), agent.config.max_steps);
    try std.testing.expectEqualStrings(openai.GROQ_URL, agent.llm.base_url);
}

test "BrowserAgent with Ollama" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{
        .llm_api_key = "",
        .llm_provider = .ollama,
        .llm_model = openai.OLLAMA_MODEL,
    });
    defer agent.deinit();

    try std.testing.expectEqualStrings(openai.OLLAMA_URL, agent.llm.base_url);
}

test "parseResponse extracts action" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{ .llm_api_key = "test" });
    defer agent.deinit();

    const response =
        \\Thought: I need to click the search button
        \\Action: click
        \\Action Input: [#search-btn]
    ;

    const parsed = try agent.parseResponse(response);
    try std.testing.expectEqualStrings("click", parsed.action);
    try std.testing.expectEqualStrings("[#search-btn]", parsed.action_input);
}

test "parseResponse extracts stop action" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{ .llm_api_key = "test" });
    defer agent.deinit();

    const response =
        \\Thought: I found the answer
        \\Action: stop
        \\Action Input: The answer is 42
    ;

    const parsed = try agent.parseResponse(response);
    try std.testing.expectEqualStrings("stop", parsed.action);
    try std.testing.expectEqualStrings("The answer is 42", parsed.action_input);
}

test "BrowserAgentConfig defaults" {
    const config = BrowserAgentConfig{
        .llm_api_key = "key",
    };
    try std.testing.expectEqual(openai.Provider.groq, config.llm_provider);
    try std.testing.expectEqual(@as(u32, 30), config.max_steps);
    try std.testing.expectEqualStrings("localhost", config.browser_host);
}

test "BrowserAgent with HuggingFace" {
    const allocator = std.testing.allocator;
    var agent = BrowserAgent.init(allocator, .{
        .llm_api_key = "hf_test_key",
        .llm_provider = .huggingface,
        .llm_model = openai.HUGGINGFACE_MODEL,
    });
    defer agent.deinit();

    try std.testing.expectEqualStrings(openai.HUGGINGFACE_URL, agent.llm.base_url);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
