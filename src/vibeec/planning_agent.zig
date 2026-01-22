// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE PLANNING AGENT - Multi-step Observe-Think-Act Loop
// ═══════════════════════════════════════════════════════════════════════════════
//
// Architecture:
//   1. OBSERVE: Collect page state (URL, title, DOM summary)
//   2. THINK: Ask LLM for next action based on goal + state + history
//   3. ACT: Execute the action (click, type, navigate, etc.)
//   4. LOOP: Repeat until "done" or max_steps
//
// Target: WebArena benchmark ~40-45%
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const real_agent = @import("real_agent.zig");
const http_client = @import("http_client.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const PageState = struct {
    url: []const u8,
    title: []const u8,
    text_preview: []const u8, // First 500 chars of page text
    step_number: u32,
};

pub const AgentState = struct {
    goal: []const u8,
    current_page: PageState,
    history: std.ArrayList(HistoryEntry),
    max_steps: u32,
    current_step: u32,
    done: bool,
    result: ?[]const u8,

    pub fn init(allocator: Allocator, goal: []const u8, max_steps: u32) AgentState {
        return AgentState{
            .goal = goal,
            .current_page = PageState{
                .url = "",
                .title = "",
                .text_preview = "",
                .step_number = 0,
            },
            .history = std.ArrayList(HistoryEntry).init(allocator),
            .max_steps = max_steps,
            .current_step = 0,
            .done = false,
            .result = null,
        };
    }

    pub fn deinit(self: *AgentState) void {
        self.history.deinit();
    }
};

pub const HistoryEntry = struct {
    step: u32,
    action: Action,
    observation: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ActionType = enum {
    navigate,
    click,
    type_text,
    press_enter,
    scroll,
    done,
    fail,
};

pub const Action = struct {
    action_type: ActionType,
    // Static buffers to avoid memory issues
    arg_buf: [256]u8 = undefined,
    arg_len: usize = 0,
    scroll_delta: i32 = 0,

    pub fn getArg(self: *const Action) []const u8 {
        return self.arg_buf[0..self.arg_len];
    }

    pub fn navigate(url: []const u8) Action {
        var action = Action{ .action_type = .navigate };
        const len = @min(url.len, 255);
        @memcpy(action.arg_buf[0..len], url[0..len]);
        action.arg_len = len;
        return action;
    }

    pub fn click(selector: []const u8) Action {
        var action = Action{ .action_type = .click };
        const len = @min(selector.len, 255);
        @memcpy(action.arg_buf[0..len], selector[0..len]);
        action.arg_len = len;
        return action;
    }

    pub fn typeText(text: []const u8) Action {
        var action = Action{ .action_type = .type_text };
        const len = @min(text.len, 255);
        @memcpy(action.arg_buf[0..len], text[0..len]);
        action.arg_len = len;
        return action;
    }

    pub fn pressEnter() Action {
        return Action{ .action_type = .press_enter };
    }

    pub fn scroll(delta: i32) Action {
        var action = Action{ .action_type = .scroll };
        action.scroll_delta = delta;
        return action;
    }

    pub fn done(result: []const u8) Action {
        var action = Action{ .action_type = .done };
        const len = @min(result.len, 255);
        @memcpy(action.arg_buf[0..len], result[0..len]);
        action.arg_len = len;
        return action;
    }

    pub fn fail(reason: []const u8) Action {
        var action = Action{ .action_type = .fail };
        const len = @min(reason.len, 255);
        @memcpy(action.arg_buf[0..len], reason[0..len]);
        action.arg_len = len;
        return action;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PLANNING AGENT
// ═══════════════════════════════════════════════════════════════════════════════

pub const PlanningAgent = struct {
    allocator: Allocator,
    browser: real_agent.RealAgent,
    http: http_client.HttpClient,
    state: AgentState,
    model: []const u8,

    const Self = @This();

    const SYSTEM_PROMPT =
        \\Browser agent. ONE action per reply.
        \\navigate https://example.com
        \\click a
        \\type hello
        \\enter
        \\done RESULT
    ;

    pub fn init(allocator: Allocator, goal: []const u8, max_steps: u32) Self {
        return Self{
            .allocator = allocator,
            .browser = real_agent.RealAgent.init(allocator, .{}),
            .http = http_client.HttpClient.init(allocator),
            .state = AgentState.init(allocator, goal, max_steps),
            .model = "qwen2.5:1.5b",
        };
    }

    pub fn deinit(self: *Self) void {
        self.browser.deinit();
        self.http.deinit();
        self.state.deinit();
    }

    /// Connect to Chrome browser
    pub fn connect(self: *Self, ws_url: []const u8) !void {
        try self.browser.connectBrowser(ws_url);
    }

    /// Main agent loop: Observe → Think → Act → Repeat
    pub fn run(self: *Self) ![]const u8 {
        std.debug.print("\n[AGENT] Starting task: {s}\n", .{self.state.goal});
        std.debug.print("[AGENT] Max steps: {d}\n\n", .{self.state.max_steps});

        while (!self.state.done and self.state.current_step < self.state.max_steps) {
            self.state.current_step += 1;
            std.debug.print("═══ Step {d}/{d} ═══\n", .{ self.state.current_step, self.state.max_steps });

            // 1. OBSERVE
            std.debug.print("[OBSERVE] ", .{});
            try self.observe();
            std.debug.print("URL: {s}, Title: {s}\n", .{
                self.state.current_page.url,
                self.state.current_page.title,
            });

            // 2. THINK
            std.debug.print("[THINK] Asking LLM...\n", .{});
            const action = try self.think();
            std.debug.print("[THINK] Action: {s}\n", .{@tagName(action.action_type)});

            // 3. ACT
            std.debug.print("[ACT] Executing...\n", .{});
            try self.act(action);

            // Check if done
            if (action.action_type == .done) {
                self.state.done = true;
                const arg = action.getArg();
                self.state.result = if (arg.len > 0) arg else "Task completed";
                std.debug.print("[DONE] Result: {s}\n", .{self.state.result.?});
            } else if (action.action_type == .fail) {
                self.state.done = true;
                const arg = action.getArg();
                self.state.result = if (arg.len > 0) arg else "Unknown error";
                std.debug.print("[FAIL] Reason: {s}\n", .{self.state.result.?});
            }

            std.debug.print("\n", .{});

            // Small delay between steps
            std.time.sleep(500 * std.time.ns_per_ms);
        }

        if (!self.state.done) {
            std.debug.print("[TIMEOUT] Max steps reached\n", .{});
            return "Max steps reached without completion";
        }

        return self.state.result orelse "Task completed";
    }

    /// OBSERVE: Collect current page state
    fn observe(self: *Self) !void {
        // Get URL
        const url = self.browser.getURL() catch "about:blank";
        self.state.current_page.url = url;

        // Get title
        const title = self.browser.getTitle() catch "Unknown";
        self.state.current_page.title = title;

        // Get text preview (first 500 chars)
        const text = self.browser.getPageText() catch "";
        const preview_len = @min(text.len, 500);
        self.state.current_page.text_preview = text[0..preview_len];

        self.state.current_page.step_number = self.state.current_step;
    }

    /// THINK: Ask LLM for next action
    fn think(self: *Self) !Action {
        // Build simple prompt
        var prompt_buf: [4096]u8 = undefined;

        // Truncate URL and title for prompt
        const url_preview = if (self.state.current_page.url.len > 50)
            self.state.current_page.url[0..50]
        else
            self.state.current_page.url;

        const title_preview = if (self.state.current_page.title.len > 50)
            self.state.current_page.title[0..50]
        else
            self.state.current_page.title;

        const prompt = std.fmt.bufPrint(&prompt_buf,
            \\{s}
            \\
            \\GOAL: {s}
            \\URL: {s}
            \\Title: {s}
            \\Step: {d}/{d}
            \\
            \\Next action:
        , .{
            SYSTEM_PROMPT,
            self.state.goal,
            url_preview,
            title_preview,
            self.state.current_step,
            self.state.max_steps,
        }) catch return Action.fail("Prompt too long");

        // Call LLM
        const response = self.callLLM(prompt) catch return Action.fail("LLM call failed");
        defer self.allocator.free(response);

        std.debug.print("    LLM raw: {s}\n", .{response[0..@min(response.len, 100)]});

        // Parse action from response
        return self.parseAction(response);
    }

    /// ACT: Execute the action
    fn act(self: *Self, action: Action) !void {
        const arg = action.getArg();

        switch (action.action_type) {
            .navigate => {
                if (arg.len > 0) {
                    std.debug.print("    Navigating to: {s}\n", .{arg});
                    try self.browser.navigate(arg);
                    std.time.sleep(2 * std.time.ns_per_s); // Wait for page load
                }
            },
            .click => {
                if (arg.len > 0 and arg.len < 100) {
                    std.debug.print("    Clicking: {s}\n", .{arg});
                    self.browser.clickSelector(arg) catch {
                        std.debug.print("    Click failed\n", .{});
                    };
                    std.time.sleep(1 * std.time.ns_per_s);
                }
            },
            .type_text => {
                if (arg.len > 0) {
                    std.debug.print("    Typing: {s}\n", .{arg});
                    try self.browser.typeText(arg);
                }
            },
            .press_enter => {
                std.debug.print("    Pressing Enter\n", .{});
                try self.browser.pressEnter();
                std.time.sleep(2 * std.time.ns_per_s);
            },
            .scroll => {
                const delta = action.scroll_delta;
                std.debug.print("    Scrolling: {d}\n", .{delta});
                try self.browser.scroll(delta);
            },
            .done, .fail => {
                // No browser action needed
            },
        }

        // Add to history
        self.state.history.append(HistoryEntry{
            .step = self.state.current_step,
            .action = action,
            .observation = self.state.current_page.title,
        }) catch {};
    }

    /// Parse LLM response into Action
    fn parseAction(self: *Self, response: []const u8) Action {
        _ = self;

        // Find "ACTION:" in response
        const action_prefix = "ACTION:";
        const action_start = std.mem.indexOf(u8, response, action_prefix) orelse {
            // Try to find action without prefix
            return parseActionDirect(response);
        };

        const after_prefix = response[action_start + action_prefix.len ..];
        const trimmed = std.mem.trim(u8, after_prefix, " \t\n\r");

        return parseActionDirect(trimmed);
    }

    /// Call Ollama LLM
    fn callLLM(self: *Self, prompt: []const u8) ![]const u8 {
        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "http://localhost:11434/api/generate", .{}) catch return error.OutOfMemory;

        // Escape prompt for JSON
        var escaped: [8192]u8 = undefined;
        var escaped_len: usize = 0;
        for (prompt) |c| {
            if (c == '"' or c == '\\') {
                escaped[escaped_len] = '\\';
                escaped_len += 1;
            } else if (c == '\n') {
                escaped[escaped_len] = '\\';
                escaped_len += 1;
                escaped[escaped_len] = 'n';
                escaped_len += 1;
                continue;
            }
            if (escaped_len < escaped.len) {
                escaped[escaped_len] = c;
                escaped_len += 1;
            }
        }

        var body_buf: [16384]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf, "{{\"model\":\"{s}\",\"prompt\":\"{s}\",\"stream\":false}}", .{ self.model, escaped[0..escaped_len] }) catch return error.OutOfMemory;

        var response = self.http.post(url, body, "application/json") catch return error.ConnectionFailed;
        defer response.deinit();

        if (response.status != 200) {
            return error.RequestFailed;
        }

        // Extract response text
        if (std.mem.indexOf(u8, response.body, "\"response\":\"")) |start| {
            const value_start = start + 12;
            var end = value_start;
            var esc = false;
            while (end < response.body.len) : (end += 1) {
                if (esc) {
                    esc = false;
                    continue;
                }
                if (response.body[end] == '\\') {
                    esc = true;
                    continue;
                }
                if (response.body[end] == '"') break;
            }
            return self.allocator.dupe(u8, response.body[value_start..end]) catch return error.OutOfMemory;
        }

        return error.ParseError;
    }
};

/// Extract URL from text
fn extractUrl(input: []const u8) []const u8 {
    // Find http in the string
    if (std.mem.indexOf(u8, input, "http")) |start| {
        var end = start;
        // Find end of URL (space, newline, backslash, or end of string)
        while (end < input.len) : (end += 1) {
            const c = input[end];
            if (c == ' ' or c == '\n' or c == '\r' or c == '\t' or c == '"' or c == '\'' or c == '\\' or c == '`') {
                break;
            }
        }
        const url = input[start..end];
        // Limit URL length
        if (url.len > 150) {
            return url[0..150];
        }
        return url;
    }
    return "";
}

/// Parse action string directly
fn parseActionDirect(text: []const u8) Action {
    // Trim whitespace
    var trimmed = std.mem.trim(u8, text, " \t\n\r");

    if (trimmed.len == 0) {
        return Action.fail("Empty action");
    }

    // Limit length to prevent memory issues
    if (trimmed.len > 300) {
        trimmed = trimmed[0..300];
    }

    if (std.mem.startsWith(u8, trimmed, "navigate")) {
        const url = extractUrl(trimmed);
        if (url.len > 0) {
            return Action.navigate(url);
        }
        // Maybe just "navigate example.com"
        const after = std.mem.trim(u8, trimmed[8..], " \t\n\r:");
        if (after.len > 0 and after.len < 100) {
            return Action.navigate(after);
        }
    } else if (std.mem.startsWith(u8, trimmed, "click ")) {
        const arg = std.mem.trim(u8, trimmed[6..], " \t\n\r");
        if (arg.len > 0 and arg.len < 50) {
            return Action.click(arg);
        }
    } else if (std.mem.startsWith(u8, trimmed, "type ")) {
        const arg = trimmed[5..];
        if (arg.len > 0 and arg.len < 200) {
            return Action.typeText(arg);
        }
    } else if (std.mem.eql(u8, trimmed, "enter") or std.mem.startsWith(u8, trimmed, "enter ")) {
        return Action.pressEnter();
    } else if (std.mem.startsWith(u8, trimmed, "scroll ")) {
        const dir = trimmed[7..];
        if (std.mem.startsWith(u8, dir, "down")) {
            return Action.scroll(300);
        } else {
            return Action.scroll(-300);
        }
    } else if (std.mem.startsWith(u8, trimmed, "done ")) {
        return Action.done(trimmed[5..]);
    } else if (std.mem.eql(u8, trimmed, "done")) {
        return Action.done("Task completed");
    } else if (std.mem.startsWith(u8, trimmed, "fail ")) {
        return Action.fail(trimmed[5..]);
    }

    // Default: if contains URL, navigate
    const url = extractUrl(trimmed);
    if (url.len > 0) {
        return Action.navigate(url);
    }

    // If LLM just says "title" or similar, treat as done
    if (std.mem.eql(u8, trimmed, "title") or std.mem.startsWith(u8, trimmed, "title:") or std.mem.startsWith(u8, trimmed, "Title:")) {
        return Action.done("See page title above");
    }

    return Action.fail("Unknown action");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Action constructors" {
    const nav = Action.navigate("https://example.com");
    try std.testing.expectEqual(ActionType.navigate, nav.action_type);
    try std.testing.expectEqualStrings("https://example.com", nav.getArg());

    const clk = Action.click("a.link");
    try std.testing.expectEqual(ActionType.click, clk.action_type);
    try std.testing.expectEqualStrings("a.link", clk.getArg());

    const typ = Action.typeText("hello");
    try std.testing.expectEqual(ActionType.type_text, typ.action_type);
    try std.testing.expectEqualStrings("hello", typ.getArg());

    const ent = Action.pressEnter();
    try std.testing.expectEqual(ActionType.press_enter, ent.action_type);

    const scr = Action.scroll(500);
    try std.testing.expectEqual(ActionType.scroll, scr.action_type);
    try std.testing.expectEqual(@as(i32, 500), scr.scroll_delta);

    const dn = Action.done("result");
    try std.testing.expectEqual(ActionType.done, dn.action_type);
    try std.testing.expectEqualStrings("result", dn.getArg());
}

test "parseActionDirect" {
    const nav = parseActionDirect("navigate https://google.com");
    try std.testing.expectEqual(ActionType.navigate, nav.action_type);

    const clk = parseActionDirect("click button.submit");
    try std.testing.expectEqual(ActionType.click, clk.action_type);

    const typ = parseActionDirect("type hello world");
    try std.testing.expectEqual(ActionType.type_text, typ.action_type);

    const ent = parseActionDirect("enter");
    try std.testing.expectEqual(ActionType.press_enter, ent.action_type);

    const scr = parseActionDirect("scroll down");
    try std.testing.expectEqual(ActionType.scroll, scr.action_type);

    const dn = parseActionDirect("done The title is Example");
    try std.testing.expectEqual(ActionType.done, dn.action_type);
}

test "AgentState initialization" {
    const allocator = std.testing.allocator;
    var state = AgentState.init(allocator, "Test goal", 10);
    defer state.deinit();

    try std.testing.expectEqualStrings("Test goal", state.goal);
    try std.testing.expectEqual(@as(u32, 10), state.max_steps);
    try std.testing.expectEqual(@as(u32, 0), state.current_step);
    try std.testing.expect(!state.done);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
