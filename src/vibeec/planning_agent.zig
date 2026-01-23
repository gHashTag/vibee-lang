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
const openai = @import("openai_client.zig");
const anthropic = @import("anthropic_client.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const PageState = struct {
    url: []const u8,
    title: []const u8,
    text_preview: []const u8, // First 500 chars of page text
    dom_summary: []const u8, // Compact DOM for LLM
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
                .dom_summary = "",
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
    select_option, // For dropdown selection
    check_box, // For checkbox toggle
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

    /// Select option in dropdown: "selector:value"
    pub fn selectOption(selector_value: []const u8) Action {
        var action = Action{ .action_type = .select_option };
        const len = @min(selector_value.len, 255);
        @memcpy(action.arg_buf[0..len], selector_value[0..len]);
        action.arg_len = len;
        return action;
    }

    /// Check/uncheck checkbox: "selector:true" or "selector:false"
    pub fn checkBox(selector_checked: []const u8) Action {
        var action = Action{ .action_type = .check_box };
        const len = @min(selector_checked.len, 255);
        @memcpy(action.arg_buf[0..len], selector_checked[0..len]);
        action.arg_len = len;
        return action;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PLANNING AGENT
// ═══════════════════════════════════════════════════════════════════════════════
// ACTION CACHE - v23.10
// ═══════════════════════════════════════════════════════════════════════════════

pub const CachedAction = struct {
    action: Action,
    success_count: u32,
    fail_count: u32,
    last_used: i64,
};

pub const ActionCache = struct {
    allocator: Allocator,
    cache: std.StringHashMap(CachedAction),
    hits: u32,
    misses: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .cache = std.StringHashMap(CachedAction).init(allocator),
            .hits = 0,
            .misses = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all keys
        var it = self.cache.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.cache.deinit();
    }

    /// Normalize goal to cache key: extract domain + action type
    pub fn goalToKey(self: *Self, goal: []const u8) ![]const u8 {
        var key_buf: [128]u8 = undefined;
        var key_len: usize = 0;

        // Extract action type
        const action_keywords = [_]struct { pattern: []const u8, action: []const u8 }{
            .{ .pattern = "go to", .action = "nav" },
            .{ .pattern = "Go to", .action = "nav" },
            .{ .pattern = "navigate", .action = "nav" },
            .{ .pattern = "Navigate", .action = "nav" },
            .{ .pattern = "open", .action = "nav" },
            .{ .pattern = "Open", .action = "nav" },
            .{ .pattern = "visit", .action = "nav" },
            .{ .pattern = "Visit", .action = "nav" },
            .{ .pattern = "search", .action = "search" },
            .{ .pattern = "Search", .action = "search" },
            .{ .pattern = "click", .action = "click" },
            .{ .pattern = "Click", .action = "click" },
        };

        var action_type: []const u8 = "other";
        for (action_keywords) |kw| {
            if (std.mem.indexOf(u8, goal, kw.pattern) != null) {
                action_type = kw.action;
                break;
            }
        }

        // Copy action type
        @memcpy(key_buf[0..action_type.len], action_type);
        key_len = action_type.len;
        key_buf[key_len] = ':';
        key_len += 1;

        // Extract domain from goal
        const domain_markers = [_][]const u8{ ".com", ".org", ".net", ".io", ".dev" };
        for (domain_markers) |marker| {
            if (std.mem.indexOf(u8, goal, marker)) |marker_pos| {
                // Find start of domain
                var domain_start = marker_pos;
                while (domain_start > 0 and goal[domain_start - 1] != ' ' and goal[domain_start - 1] != '\t') {
                    domain_start -= 1;
                }
                const domain_end = marker_pos + marker.len;
                const domain = goal[domain_start..domain_end];
                const copy_len = @min(domain.len, key_buf.len - key_len - 1);
                @memcpy(key_buf[key_len .. key_len + copy_len], domain[0..copy_len]);
                key_len += copy_len;
                break;
            }
        }

        // If no domain found, use first 20 chars of goal
        if (key_len <= action_type.len + 1) {
            const goal_preview = goal[0..@min(goal.len, 20)];
            @memcpy(key_buf[key_len .. key_len + goal_preview.len], goal_preview);
            key_len += goal_preview.len;
        }

        return self.allocator.dupe(u8, key_buf[0..key_len]);
    }

    /// Lookup cached action for goal
    pub fn lookup(self: *Self, goal: []const u8) ?Action {
        const key = self.goalToKey(goal) catch return null;
        defer self.allocator.free(key);

        if (self.cache.get(key)) |*entry| {
            // Check if action is reliable (success > fail)
            if (entry.success_count > entry.fail_count) {
                self.hits += 1;
                std.debug.print("    [CACHE] HIT: {s} (success={d})\n", .{ key, entry.success_count });
                return entry.action;
            }
        }

        self.misses += 1;
        std.debug.print("    [CACHE] MISS: {s}\n", .{key});
        return null;
    }

    /// Store successful action in cache
    pub fn store(self: *Self, goal: []const u8, action: Action) void {
        const key = self.goalToKey(goal) catch return;

        if (self.cache.getPtr(key)) |entry| {
            // Update existing entry
            entry.success_count += 1;
            entry.last_used = std.time.timestamp();
            entry.action = action;
            self.allocator.free(key);
        } else {
            // New entry
            self.cache.put(key, CachedAction{
                .action = action,
                .success_count = 1,
                .fail_count = 0,
                .last_used = std.time.timestamp(),
            }) catch {
                self.allocator.free(key);
            };
        }
        std.debug.print("    [CACHE] STORE: goal cached\n", .{});
    }

    /// Mark action as failed (for invalidation)
    pub fn markFailed(self: *Self, goal: []const u8) void {
        const key = self.goalToKey(goal) catch return;
        defer self.allocator.free(key);

        if (self.cache.getPtr(key)) |entry| {
            entry.fail_count += 1;
            std.debug.print("    [CACHE] FAIL: {s} (fails={d})\n", .{ key, entry.fail_count });
        }
    }

    /// Get cache statistics
    pub fn getStats(self: *Self) struct { hits: u32, misses: u32, entries: u32 } {
        return .{
            .hits = self.hits,
            .misses = self.misses,
            .entries = @intCast(self.cache.count()),
        };
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PERSISTENCE - v23.11
    // ═══════════════════════════════════════════════════════════════════════

    const CACHE_VERSION: u32 = 1;
    const MAX_ENTRIES: usize = 100;
    const TTL_SECONDS: i64 = 24 * 60 * 60; // 24 hours

    /// Get cache file path (~/.vibee/cache.json)
    fn getCacheFilePath(self: *Self) ![]const u8 {
        _ = self;
        // Use /tmp for simplicity (cross-platform)
        return "/tmp/.vibee_cache.json";
    }

    /// Serialize cache to JSON string
    pub fn serializeToJson(self: *Self) ![]const u8 {
        var json_buf: [16384]u8 = undefined;
        var pos: usize = 0;

        // Header
        const header = "{\"version\":1,\"entries\":[";
        @memcpy(json_buf[pos .. pos + header.len], header);
        pos += header.len;

        // Entries
        var first = true;
        var it = self.cache.iterator();
        var count: usize = 0;

        while (it.next()) |entry| {
            if (count >= MAX_ENTRIES) break;

            // Check TTL
            const now = std.time.timestamp();
            if (now - entry.value_ptr.last_used > TTL_SECONDS) {
                continue; // Skip expired entries
            }

            if (!first) {
                json_buf[pos] = ',';
                pos += 1;
            }
            first = false;

            // Serialize entry
            const action = entry.value_ptr.action;
            const action_type_str = @tagName(action.action_type);
            const action_arg = action.getArg();

            // Escape key and arg for JSON
            var escaped_key: [256]u8 = undefined;
            var escaped_arg: [512]u8 = undefined;
            const key_escaped = escapeJsonString(entry.key_ptr.*, &escaped_key);
            const arg_escaped = escapeJsonString(action_arg, &escaped_arg);

            const entry_json = std.fmt.bufPrint(json_buf[pos..], "{{\"key\":\"{s}\",\"action_type\":\"{s}\",\"action_arg\":\"{s}\",\"success\":{d},\"fail\":{d},\"last_used\":{d}}}", .{
                key_escaped,
                action_type_str,
                arg_escaped,
                entry.value_ptr.success_count,
                entry.value_ptr.fail_count,
                entry.value_ptr.last_used,
            }) catch break;

            pos += entry_json.len;
            count += 1;
        }

        // Footer
        const footer = "]}";
        @memcpy(json_buf[pos .. pos + footer.len], footer);
        pos += footer.len;

        return self.allocator.dupe(u8, json_buf[0..pos]);
    }

    /// Escape string for JSON
    fn escapeJsonString(input: []const u8, output: []u8) []const u8 {
        var out_pos: usize = 0;
        for (input) |c| {
            if (out_pos >= output.len - 2) break;
            switch (c) {
                '"' => {
                    output[out_pos] = '\\';
                    out_pos += 1;
                    output[out_pos] = '"';
                    out_pos += 1;
                },
                '\\' => {
                    output[out_pos] = '\\';
                    out_pos += 1;
                    output[out_pos] = '\\';
                    out_pos += 1;
                },
                '\n' => {
                    output[out_pos] = '\\';
                    out_pos += 1;
                    output[out_pos] = 'n';
                    out_pos += 1;
                },
                '\r' => {
                    output[out_pos] = '\\';
                    out_pos += 1;
                    output[out_pos] = 'r';
                    out_pos += 1;
                },
                '\t' => {
                    output[out_pos] = '\\';
                    out_pos += 1;
                    output[out_pos] = 't';
                    out_pos += 1;
                },
                else => {
                    output[out_pos] = c;
                    out_pos += 1;
                },
            }
        }
        return output[0..out_pos];
    }

    /// Save cache to file
    pub fn saveToFile(self: *Self) !void {
        const path = try self.getCacheFilePath();
        const json = try self.serializeToJson();
        defer self.allocator.free(json);

        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            std.debug.print("[CACHE] Failed to create file: {}\n", .{err});
            return;
        };
        defer file.close();

        _ = file.write(json) catch |err| {
            std.debug.print("[CACHE] Failed to write: {}\n", .{err});
            return;
        };

        std.debug.print("[CACHE] Saved {d} entries to {s}\n", .{ self.cache.count(), path });
    }

    /// Load cache from file
    pub fn loadFromFile(self: *Self) !void {
        const path = try self.getCacheFilePath();

        const file = std.fs.cwd().openFile(path, .{}) catch {
            std.debug.print("[CACHE] No cache file found, starting fresh\n", .{});
            return;
        };
        defer file.close();

        var buf: [16384]u8 = undefined;
        const bytes_read = file.readAll(&buf) catch {
            std.debug.print("[CACHE] Failed to read cache file\n", .{});
            return;
        };

        if (bytes_read == 0) return;

        const json = buf[0..bytes_read];
        try self.deserializeFromJson(json);
    }

    /// Deserialize cache from JSON
    pub fn deserializeFromJson(self: *Self, json: []const u8) !void {
        // Simple JSON parsing - find entries array
        const entries_start = std.mem.indexOf(u8, json, "\"entries\":[") orelse return;
        const array_start = entries_start + 11;

        var pos = array_start;
        var loaded: u32 = 0;
        const now = std.time.timestamp();

        while (pos < json.len) {
            // Find next entry
            const entry_start = std.mem.indexOf(u8, json[pos..], "{\"key\":\"") orelse break;
            pos += entry_start;

            // Parse key
            const key_start = pos + 8;
            const key_end = std.mem.indexOf(u8, json[key_start..], "\"") orelse break;
            const key = json[key_start .. key_start + key_end];

            // Parse action_type
            const type_marker = std.mem.indexOf(u8, json[pos..], "\"action_type\":\"") orelse break;
            const type_start = pos + type_marker + 15;
            const type_end = std.mem.indexOf(u8, json[type_start..], "\"") orelse break;
            const action_type_str = json[type_start .. type_start + type_end];

            // Parse action_arg
            const arg_marker = std.mem.indexOf(u8, json[pos..], "\"action_arg\":\"") orelse break;
            const arg_start = pos + arg_marker + 14;
            const arg_end = std.mem.indexOf(u8, json[arg_start..], "\"") orelse break;
            const action_arg = json[arg_start .. arg_start + arg_end];

            // Parse success count
            const success_marker = std.mem.indexOf(u8, json[pos..], "\"success\":") orelse break;
            const success_start = pos + success_marker + 10;
            var success_end = success_start;
            while (success_end < json.len and json[success_end] >= '0' and json[success_end] <= '9') {
                success_end += 1;
            }
            const success_count = std.fmt.parseInt(u32, json[success_start..success_end], 10) catch 0;

            // Parse fail count
            const fail_marker = std.mem.indexOf(u8, json[pos..], "\"fail\":") orelse break;
            const fail_start = pos + fail_marker + 7;
            var fail_end = fail_start;
            while (fail_end < json.len and json[fail_end] >= '0' and json[fail_end] <= '9') {
                fail_end += 1;
            }
            const fail_count = std.fmt.parseInt(u32, json[fail_start..fail_end], 10) catch 0;

            // Parse last_used
            const last_marker = std.mem.indexOf(u8, json[pos..], "\"last_used\":") orelse break;
            const last_start = pos + last_marker + 12;
            var last_end = last_start;
            while (last_end < json.len and json[last_end] >= '0' and json[last_end] <= '9') {
                last_end += 1;
            }
            const last_used = std.fmt.parseInt(i64, json[last_start..last_end], 10) catch 0;

            // Check TTL
            if (now - last_used > TTL_SECONDS) {
                pos = last_end;
                continue; // Skip expired
            }

            // Create action
            const action = if (std.mem.eql(u8, action_type_str, "navigate"))
                Action.navigate(action_arg)
            else if (std.mem.eql(u8, action_type_str, "click"))
                Action.click(action_arg)
            else if (std.mem.eql(u8, action_type_str, "type_text"))
                Action.typeText(action_arg)
            else if (std.mem.eql(u8, action_type_str, "press_enter"))
                Action.pressEnter()
            else
                Action.navigate(action_arg); // Default

            // Store in cache
            const key_copy = self.allocator.dupe(u8, key) catch continue;
            self.cache.put(key_copy, CachedAction{
                .action = action,
                .success_count = success_count,
                .fail_count = fail_count,
                .last_used = last_used,
            }) catch {
                self.allocator.free(key_copy);
                continue;
            };

            loaded += 1;
            pos = last_end;
        }

        std.debug.print("[CACHE] Loaded {d} entries from file\n", .{loaded});
    }

    /// Clean expired entries
    pub fn cleanExpired(self: *Self) void {
        const now = std.time.timestamp();
        var to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();

        var it = self.cache.iterator();
        while (it.next()) |entry| {
            if (now - entry.value_ptr.last_used > TTL_SECONDS) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |key| {
            _ = self.cache.remove(key);
            self.allocator.free(key);
        }

        if (to_remove.items.len > 0) {
            std.debug.print("[CACHE] Cleaned {d} expired entries\n", .{to_remove.items.len});
        }
    }
};

// Global cache instance (shared across agent instances)
var global_cache: ?ActionCache = null;
var cache_loaded: bool = false;

pub fn getGlobalCache(allocator: Allocator) *ActionCache {
    if (global_cache == null) {
        global_cache = ActionCache.init(allocator);
        // Load from file on first access
        if (!cache_loaded) {
            global_cache.?.loadFromFile() catch {};
            cache_loaded = true;
        }
    }
    return &global_cache.?;
}

/// Save global cache to file (call before exit)
pub fn saveGlobalCache() void {
    if (global_cache) |*cache| {
        cache.cleanExpired();
        cache.saveToFile() catch {};
    }
}

pub const LLMProvider = enum {
    ollama, // Local Ollama (default)
    openai, // OpenAI GPT-4
    groq, // Groq (fast, free)
    anthropic, // Anthropic Claude
    huggingface, // HuggingFace
    together, // Together AI
};

pub const PlanningAgent = struct {
    allocator: Allocator,
    browser: real_agent.RealAgent,
    http: http_client.HttpClient,
    llm_client: ?openai.OpenAIClient,
    anthropic_client: ?anthropic.AnthropicClient,
    state: AgentState,
    model: []const u8,
    use_json_mode: bool,
    current_provider: LLMProvider,
    // Static buffers to avoid memory leaks
    url_buf: [512]u8 = undefined,
    title_buf: [256]u8 = undefined,
    dom_buf: [1024]u8 = undefined,

    const Self = @This();

    const few_shot = @import("few_shot_examples.zig");
    const SYSTEM_PROMPT = few_shot.FEW_SHOT_COMPACT;

    // JSON format prompt for structured output with DOM awareness
    const JSON_PROMPT =
        \\You are a browser agent. Return ONLY valid JSON.
        \\Actions: navigate, click, type, enter, scroll, done
        \\
        \\Format: {"action":"ACTION","arg":"ARGUMENT"}
        \\
        \\DOM Elements format: tag#id.class name=X href=Y "text"
        \\Use selectors from DOM: #id, .class, tag, or text content
        \\
        \\Examples:
        \\{"action":"navigate","arg":"https://example.com"}
        \\{"action":"click","arg":"#submit-btn"}
        \\{"action":"click","arg":".search-input"}
        \\{"action":"click","arg":"a"}
        \\{"action":"type","arg":"hello"}
        \\{"action":"enter","arg":""}
        \\{"action":"scroll","arg":"down"}
        \\{"action":"done","arg":"Task completed"}
    ;

    pub fn init(allocator: Allocator, goal: []const u8, max_steps: u32) Self {
        return Self{
            .allocator = allocator,
            .browser = real_agent.RealAgent.init(allocator, .{}),
            .http = http_client.HttpClient.init(allocator),
            .llm_client = null,
            .anthropic_client = null,
            .state = AgentState.init(allocator, goal, max_steps),
            .model = "qwen2.5:1.5b", // v23.9: faster model for lower latency
            .use_json_mode = false,
            .current_provider = .ollama,
        };
    }

    /// Initialize with OpenAI GPT-4
    pub fn initWithOpenAI(allocator: Allocator, goal: []const u8, max_steps: u32, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .browser = real_agent.RealAgent.init(allocator, .{}),
            .http = http_client.HttpClient.init(allocator),
            .llm_client = openai.OpenAIClient.init(allocator, api_key),
            .anthropic_client = null,
            .state = AgentState.init(allocator, goal, max_steps),
            .model = openai.OPENAI_MODEL,
            .use_json_mode = false,
            .current_provider = .openai,
        };
    }

    /// Initialize with Groq (FREE, FAST!)
    pub fn initWithGroq(allocator: Allocator, goal: []const u8, max_steps: u32, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .browser = real_agent.RealAgent.init(allocator, .{}),
            .http = http_client.HttpClient.init(allocator),
            .llm_client = openai.OpenAIClient.initGroq(allocator, api_key),
            .anthropic_client = null,
            .state = AgentState.init(allocator, goal, max_steps),
            .model = openai.GROQ_MODEL,
            .use_json_mode = false,
            .current_provider = .groq,
        };
    }

    /// Initialize with HuggingFace (FREE with API key!)
    pub fn initWithHuggingFace(allocator: Allocator, goal: []const u8, max_steps: u32, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .browser = real_agent.RealAgent.init(allocator, .{}),
            .http = http_client.HttpClient.init(allocator),
            .llm_client = openai.OpenAIClient.initHuggingFace(allocator, api_key),
            .anthropic_client = null,
            .state = AgentState.init(allocator, goal, max_steps),
            .model = openai.HUGGINGFACE_MODEL,
            .use_json_mode = false,
            .current_provider = .huggingface,
        };
    }

    /// Initialize with Anthropic Claude
    pub fn initWithAnthropic(allocator: Allocator, goal: []const u8, max_steps: u32, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .browser = real_agent.RealAgent.init(allocator, .{}),
            .http = http_client.HttpClient.init(allocator),
            .llm_client = null,
            .anthropic_client = anthropic.AnthropicClient.init(allocator, api_key),
            .state = AgentState.init(allocator, goal, max_steps),
            .model = anthropic.DEFAULT_MODEL,
            .use_json_mode = false,
            .current_provider = .anthropic,
        };
    }

    /// Initialize with Claude 3 Opus (best reasoning)
    pub fn initWithClaudeOpus(allocator: Allocator, goal: []const u8, max_steps: u32, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .browser = real_agent.RealAgent.init(allocator, .{}),
            .http = http_client.HttpClient.init(allocator),
            .llm_client = null,
            .anthropic_client = anthropic.AnthropicClient.initWithModel(allocator, api_key, anthropic.CLAUDE_3_OPUS),
            .state = AgentState.init(allocator, goal, max_steps),
            .model = anthropic.CLAUDE_3_OPUS,
            .use_json_mode = false,
            .current_provider = .anthropic,
        };
    }

    /// Switch LLM provider at runtime
    pub fn setProvider(self: *Self, provider: LLMProvider, api_key: ?[]const u8) void {
        // Cleanup existing clients
        if (self.llm_client) |*client| {
            client.deinit();
            self.llm_client = null;
        }
        if (self.anthropic_client) |*client| {
            client.deinit();
            self.anthropic_client = null;
        }

        switch (provider) {
            .openai => {
                if (api_key) |key| {
                    self.llm_client = openai.OpenAIClient.init(self.allocator, key);
                    self.model = openai.OPENAI_MODEL;
                    self.current_provider = .openai;
                }
            },
            .groq => {
                if (api_key) |key| {
                    self.llm_client = openai.OpenAIClient.initGroq(self.allocator, key);
                    self.model = openai.GROQ_MODEL;
                    self.current_provider = .groq;
                }
            },
            .together => {
                if (api_key) |key| {
                    self.llm_client = openai.OpenAIClient.initTogether(self.allocator, key);
                    self.model = openai.TOGETHER_MODEL;
                    self.current_provider = .together;
                }
            },
            .ollama => {
                self.llm_client = openai.OpenAIClient.initOllama(self.allocator);
                self.model = openai.OLLAMA_MODEL;
                self.current_provider = .ollama;
            },
            .huggingface => {
                if (api_key) |key| {
                    self.llm_client = openai.OpenAIClient.initHuggingFace(self.allocator, key);
                    self.model = openai.HUGGINGFACE_MODEL;
                    self.current_provider = .huggingface;
                }
            },
            .anthropic => {
                if (api_key) |key| {
                    self.anthropic_client = anthropic.AnthropicClient.init(self.allocator, key);
                    self.model = anthropic.DEFAULT_MODEL;
                    self.current_provider = .anthropic;
                }
            },
        }
    }

    /// Enable JSON mode for structured output
    pub fn enableJsonMode(self: *Self) void {
        self.use_json_mode = true;
    }

    /// Analyze page with vision (screenshot + GPT-4V)
    pub fn analyzeWithVision(self: *Self, prompt: []const u8) ![]const u8 {
        // Capture screenshot
        const screenshot = self.browser.captureScreenshot() catch return error.ScreenshotFailed;
        defer self.allocator.free(screenshot);

        // Use GPT-4V for analysis
        if (self.llm_client) |*client| {
            var response = client.chatWithVision(prompt, screenshot) catch return error.VisionFailed;
            defer response.deinit();
            return self.allocator.dupe(u8, response.content) catch return error.OutOfMemory;
        }

        return error.NoVisionClient;
    }

    /// Find element by visual description
    pub fn findElementByVision(self: *Self, description: []const u8) ![]const u8 {
        var prompt_buf: [1024]u8 = undefined;
        const prompt = std.fmt.bufPrint(&prompt_buf,
            \\Look at this webpage screenshot. Find the element that matches: "{s}"
            \\Return ONLY a CSS selector for that element (e.g., #id, .class, button, a).
            \\If you can't find it, return "not_found".
        , .{description}) catch return error.OutOfMemory;

        return self.analyzeWithVision(prompt);
    }

    pub fn deinit(self: *Self) void {
        self.browser.deinit();
        self.http.deinit();
        if (self.llm_client) |*client| {
            client.deinit();
        }
        if (self.anthropic_client) |*client| {
            client.deinit();
        }
        self.state.deinit();
    }

    /// Connect to Chrome browser
    pub fn connect(self: *Self, ws_url: []const u8) !void {
        try self.browser.connectBrowser(ws_url);
    }

    /// Main agent loop: Observe → Think → Act → Repeat
    /// v23.10: Added action caching for sub-second repeated goals
    pub fn run(self: *Self) ![]const u8 {
        std.debug.print("\n[AGENT] Starting task: {s}\n", .{self.state.goal});
        std.debug.print("[AGENT] Max steps: {d}\n\n", .{self.state.max_steps});

        // v23.10: Check cache FIRST for instant execution
        var cache = getGlobalCache(self.allocator);
        if (cache.lookup(self.state.goal)) |cached_action| {
            std.debug.print("[CACHE] Using cached action!\n", .{});
            self.state.current_step = 1;

            // Execute cached action directly
            try self.act(cached_action);

            // Quick verify
            std.time.sleep(500 * std.time.ns_per_ms);
            try self.observe();

            if (self.quickGoalCheck()) {
                self.state.done = true;
                self.state.result = "Goal achieved (cached)";
                cache.store(self.state.goal, cached_action); // Reinforce success
                std.debug.print("[CACHE] Cached action succeeded!\n", .{});
                return self.state.result.?;
            } else {
                // Cache miss - action didn't work, mark as failed
                cache.markFailed(self.state.goal);
                std.debug.print("[CACHE] Cached action failed, falling back to LLM\n", .{});
            }
        }

        // Track first action for caching
        var first_action: ?Action = null;

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

            // Save first action for caching
            if (first_action == null and action.action_type != .fail) {
                first_action = action;
            }

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
            } else {
                // 4. REFLECT: Check if goal achieved
                std.debug.print("[REFLECT] Checking if goal achieved...\n", .{});
                if (self.reflect()) {
                    self.state.done = true;
                    self.state.result = "Goal achieved (auto-detected)";
                    std.debug.print("[REFLECT] Goal achieved!\n", .{});

                    // v23.10: Cache successful first action
                    if (first_action) |fa| {
                        cache.store(self.state.goal, fa);
                    }
                }
            }

            std.debug.print("\n", .{});

            // Minimal delay between steps (reduced from 500ms to 100ms)
            std.time.sleep(100 * std.time.ns_per_ms);
        }

        if (!self.state.done) {
            std.debug.print("[TIMEOUT] Max steps reached\n", .{});
            return "Max steps reached without completion";
        }

        // v23.10: Cache on success
        if (self.state.done and first_action != null) {
            const result = self.state.result orelse "";
            if (std.mem.indexOf(u8, result, "achieved") != null or
                std.mem.indexOf(u8, result, "completed") != null)
            {
                cache.store(self.state.goal, first_action.?);
            }
        }

        // v23.11: Save cache to file after each successful run
        saveGlobalCache();

        return self.state.result orelse "Task completed";
    }

    /// OBSERVE: Collect current page state
    /// Note: Uses static buffers to avoid memory leaks
    fn observe(self: *Self) !void {
        // Get URL into static buffer
        const url_result = self.browser.getURL() catch null;
        if (url_result) |url| {
            const len = @min(url.len, self.url_buf.len - 1);
            @memcpy(self.url_buf[0..len], url[0..len]);
            self.url_buf[len] = 0;
            self.state.current_page.url = self.url_buf[0..len];
            self.allocator.free(url);
        } else {
            self.state.current_page.url = "about:blank";
        }

        // Get title into static buffer
        const title_result = self.browser.getTitle() catch null;
        if (title_result) |title| {
            const len = @min(title.len, self.title_buf.len - 1);
            @memcpy(self.title_buf[0..len], title[0..len]);
            self.title_buf[len] = 0;
            self.state.current_page.title = self.title_buf[0..len];
            self.allocator.free(title);
        } else {
            self.state.current_page.title = "Unknown";
        }

        // Skip text preview for now to avoid memory issues
        self.state.current_page.text_preview = "";

        // Get DOM summary for enhanced observation
        const dom = self.browser.getDOMSummary() catch null;
        if (dom) |d| {
            const len = @min(d.len, self.dom_buf.len - 1);
            @memcpy(self.dom_buf[0..len], d[0..len]);
            self.dom_buf[len] = 0;
            self.state.current_page.dom_summary = self.dom_buf[0..len];
            self.allocator.free(d);
        } else {
            self.state.current_page.dom_summary = "";
        }

        self.state.current_page.step_number = self.state.current_step;
    }

    /// Get DOM summary for enhanced observation
    pub fn getDOMSummary(self: *Self) []const u8 {
        const dom = self.browser.getDOMSummary() catch return "";
        defer self.allocator.free(dom);

        // Copy to static buffer
        const len = @min(dom.len, 1000);
        @memcpy(self.dom_buf[0..len], dom[0..len]);
        return self.dom_buf[0..len];
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

        // Try JSON mode first - includes DOM summary
        if (self.use_json_mode) {
            const dom_preview = if (self.state.current_page.dom_summary.len > 0)
                self.state.current_page.dom_summary[0..@min(self.state.current_page.dom_summary.len, 500)]
            else
                "";

            const json_prompt = if (dom_preview.len > 0)
                std.fmt.bufPrint(&prompt_buf,
                    \\{s}
                    \\
                    \\GOAL: {s}
                    \\URL: {s}
                    \\Title: {s}
                    \\
                    \\DOM Elements:
                    \\{s}
                    \\
                    \\Return JSON:
                , .{
                    JSON_PROMPT,
                    self.state.goal,
                    url_preview,
                    title_preview,
                    dom_preview,
                }) catch return Action.fail("Prompt too long")
            else
                std.fmt.bufPrint(&prompt_buf,
                    \\{s}
                    \\
                    \\GOAL: {s}
                    \\URL: {s}
                    \\Title: {s}
                    \\
                    \\Return JSON:
                , .{
                    JSON_PROMPT,
                    self.state.goal,
                    url_preview,
                    title_preview,
                }) catch return Action.fail("Prompt too long");

            const response = self.callLLMWithFormat(json_prompt, true) catch return Action.fail("LLM call failed");
            defer self.allocator.free(response);

            std.debug.print("    LLM JSON: {s}\n", .{response[0..@min(response.len, 100)]});

            // Try JSON parsing
            if (parseJsonAction(response)) |action| {
                return action;
            }
            // Fall through to text parsing
        }

        // Text mode (fallback or default) - now includes DOM summary
        const dom_preview = if (self.state.current_page.dom_summary.len > 0)
            self.state.current_page.dom_summary[0..@min(self.state.current_page.dom_summary.len, 500)]
        else
            "";

        const prompt = if (dom_preview.len > 0)
            std.fmt.bufPrint(&prompt_buf,
                \\{s}
                \\
                \\GOAL: {s}
                \\URL: {s}
                \\Title: {s}
                \\Step: {d}/{d}
                \\
                \\DOM Elements:
                \\{s}
                \\
                \\Next action:
            , .{
                SYSTEM_PROMPT,
                self.state.goal,
                url_preview,
                title_preview,
                self.state.current_step,
                self.state.max_steps,
                dom_preview,
            }) catch return Action.fail("Prompt too long")
        else
            std.fmt.bufPrint(&prompt_buf,
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

    /// ACT: Execute the action with retry logic
    fn act(self: *Self, action: Action) !void {
        const arg = action.getArg();
        const max_retries: u32 = 3;

        switch (action.action_type) {
            .navigate => {
                if (arg.len > 0) {
                    std.debug.print("    Navigating to: {s}\n", .{arg});
                    try self.browser.navigate(arg);
                    std.time.sleep(800 * std.time.ns_per_ms); // Reduced from 2s
                }
            },
            .click => {
                if (arg.len > 0 and arg.len < 100) {
                    std.debug.print("    Clicking: {s}\n", .{arg});

                    // Smart retry with exponential backoff and alternative selectors
                    var retry: u32 = 0;
                    var success = false;

                    while (retry < max_retries and !success) : (retry += 1) {
                        // Try original selector first
                        self.browser.clickSelectorWithWait(arg, 2000) catch {
                            // Exponential backoff: 500ms, 1000ms, 2000ms
                            const delay_ms: u64 = 500 * std.math.pow(u64, 2, retry);
                            std.debug.print("    Retry {d}/{d} (wait {d}ms)...\n", .{ retry + 1, max_retries, delay_ms });
                            std.time.sleep(delay_ms * std.time.ns_per_ms);

                            // Try alternative selectors on retry
                            if (retry > 0) {
                                // If selector is tag, try with :first-child
                                if (arg[0] != '#' and arg[0] != '.') {
                                    var alt_buf: [128]u8 = undefined;
                                    const alt = std.fmt.bufPrint(&alt_buf, "{s}:first-child", .{arg}) catch arg;
                                    self.browser.clickSelectorWithWait(alt, 1000) catch {
                                        continue;
                                    };
                                    success = true;
                                }
                            }
                            continue;
                        };
                        success = true;
                    }

                    if (!success) {
                        std.debug.print("    Click failed after {d} retries\n", .{max_retries});
                    }
                    std.time.sleep(300 * std.time.ns_per_ms); // Reduced from 1s
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
                std.time.sleep(500 * std.time.ns_per_ms); // Reduced from 2s
            },
            .scroll => {
                const delta = action.scroll_delta;
                std.debug.print("    Scrolling: {d}\n", .{delta});
                try self.browser.scroll(delta);
            },
            .select_option => {
                // Format: "selector:value"
                if (std.mem.indexOf(u8, arg, ":")) |sep| {
                    const selector = arg[0..sep];
                    const value = arg[sep + 1 ..];
                    std.debug.print("    Selecting option: {s} = {s}\n", .{ selector, value });
                    self.browser.selectOption(selector, value) catch {
                        std.debug.print("    Select failed\n", .{});
                    };
                }
            },
            .check_box => {
                // Format: "selector:true" or "selector:false"
                if (std.mem.indexOf(u8, arg, ":")) |sep| {
                    const selector = arg[0..sep];
                    const checked_str = arg[sep + 1 ..];
                    const checked = std.mem.eql(u8, checked_str, "true");
                    std.debug.print("    Checkbox: {s} = {}\n", .{ selector, checked });
                    self.browser.checkBox(selector, checked) catch {
                        std.debug.print("    Checkbox failed\n", .{});
                    };
                }
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

    /// REFLECT: Check if goal is achieved - optimized v23.9
    fn reflect(self: *Self) bool {
        // First: Quick heuristic check (no LLM call) - FAST PATH
        if (self.quickGoalCheck()) {
            std.debug.print("    [REFLECT] Goal achieved via quick check!\n", .{});
            return true;
        }

        // v23.9: Skip LLM reflect entirely for simple navigation goals
        // LLM reflect adds ~5-10s latency with minimal benefit for nav tasks
        const goal = self.state.goal;
        const url = self.state.current_page.url;
        
        // If goal is simple navigation and we have a valid URL, skip LLM
        const nav_keywords = [_][]const u8{ "Go to", "go to", "Navigate", "navigate", "Open", "open", "Visit", "visit" };
        for (nav_keywords) |kw| {
            if (std.mem.indexOf(u8, goal, kw) != null) {
                if (url.len > 10 and !std.mem.eql(u8, url, "about:blank")) {
                    std.debug.print("    [REFLECT] Skip LLM for nav goal (URL valid)\n", .{});
                    return false; // Let quickGoalCheck handle it next iteration
                }
            }
        }

        // v23.9: For step 1, skip LLM reflect (action just executed)
        if (self.state.current_step == 1) {
            std.debug.print("    [REFLECT] Skip LLM on step 1\n", .{});
            return false;
        }

        // LLM-based check only if heuristics fail and not a simple nav goal
        var prompt_buf: [2048]u8 = undefined;

        const url_preview = if (self.state.current_page.url.len > 50)
            self.state.current_page.url[0..50]
        else
            self.state.current_page.url;

        const title_preview = if (self.state.current_page.title.len > 50)
            self.state.current_page.title[0..50]
        else
            self.state.current_page.title;

        const prompt = std.fmt.bufPrint(&prompt_buf,
            \\Is the goal achieved? Answer only YES or NO.
            \\GOAL: {s}
            \\URL: {s}
            \\Title: {s}
            \\Answer:
        , .{
            self.state.goal,
            url_preview,
            title_preview,
        }) catch return false;

        // Call LLM (single attempt, no retry for reflect)
        const response = self.callLLMOnce(prompt) catch return false;
        defer self.allocator.free(response);

        // Check for YES
        if (std.mem.indexOf(u8, response, "YES") != null or
            std.mem.indexOf(u8, response, "yes") != null or
            std.mem.indexOf(u8, response, "Yes") != null)
        {
            return true;
        }

        return false;
    }

    /// Quick heuristic goal check (no LLM) - optimized v23.8
    fn quickGoalCheck(self: *Self) bool {
        const goal = self.state.goal;
        const url = self.state.current_page.url;
        const title = self.state.current_page.title;

        // FAST PATH: Extract any domain from goal and check if URL contains it
        // This handles "Go to example.com", "Navigate to google.com", etc.
        const domain_markers = [_][]const u8{ ".com", ".org", ".net", ".io", ".dev" };
        for (domain_markers) |marker| {
            if (std.mem.indexOf(u8, goal, marker)) |marker_pos| {
                // Find start of domain (go backwards to find space or start)
                var domain_start = marker_pos;
                while (domain_start > 0 and goal[domain_start - 1] != ' ' and goal[domain_start - 1] != '\t') {
                    domain_start -= 1;
                }
                const domain_end = marker_pos + marker.len;
                if (domain_end > domain_start) {
                    const domain = goal[domain_start..domain_end];
                    // Check if URL contains this domain
                    if (std.mem.indexOf(u8, url, domain) != null) {
                        std.debug.print("    [GOAL] Quick match: {s} in URL\n", .{domain});
                        return true;
                    }
                }
            }
        }

        // Pattern 1: Navigation goals - "Go to X", "Navigate to X", "Open X"
        const nav_patterns = [_][]const u8{ "Go to ", "go to ", "Navigate to ", "navigate to ", "Open ", "open ", "Visit ", "visit " };
        for (nav_patterns) |pattern| {
            if (std.mem.indexOf(u8, goal, pattern) != null) {
                // Extract domain from goal and check URL
                const domains = [_][]const u8{
                    "example.com",     "google.com",      "github.com",
                    "wikipedia.org",   "duckduckgo.com",  "bing.com",
                    "httpbin.org",     "ecosia.org",      "news.ycombinator.com",
                    "jsonplaceholder", "ziglang.org",
                };
                for (domains) |domain| {
                    if (std.mem.indexOf(u8, goal, domain) != null and
                        std.mem.indexOf(u8, url, domain) != null)
                    {
                        return true;
                    }
                }
            }
        }

        // Pattern 2: Search goals - check if on search results page
        const search_patterns = [_][]const u8{ "search for", "Search for", "find ", "Find ", "look up", "Look up" };
        for (search_patterns) |pattern| {
            if (std.mem.indexOf(u8, goal, pattern) != null) {
                // Check if URL contains search indicators
                if (std.mem.indexOf(u8, url, "search") != null or
                    std.mem.indexOf(u8, url, "?q=") != null or
                    std.mem.indexOf(u8, url, "&q=") != null or
                    std.mem.indexOf(u8, url, "query=") != null)
                {
                    return true;
                }
            }
        }

        // Pattern 3: Information extraction - "tell me", "what is", "find the"
        const info_patterns = [_][]const u8{ "tell me", "Tell me", "what is", "What is", "find the", "Find the", "extract", "Extract" };
        for (info_patterns) |pattern| {
            if (std.mem.indexOf(u8, goal, pattern) != null) {
                // If we have a title and URL, we likely have the info
                if (title.len > 0 and !std.mem.eql(u8, title, "Unknown") and url.len > 10) {
                    // Check if goal mentions title
                    if (std.mem.indexOf(u8, goal, "title") != null or
                        std.mem.indexOf(u8, goal, "Title") != null)
                    {
                        return true;
                    }
                }
            }
        }

        // Pattern 4: Click goals - check if URL changed after click
        if (std.mem.indexOf(u8, goal, "click") != null or
            std.mem.indexOf(u8, goal, "Click") != null)
        {
            // If we're past step 1 and URL is not blank, click likely succeeded
            if (self.state.current_step > 1 and !std.mem.eql(u8, url, "about:blank")) {
                return false; // Let LLM decide
            }
        }

        // "Tell me the title" - if we have a title, we're done
        if (std.mem.indexOf(u8, goal, "title") != null or
            std.mem.indexOf(u8, goal, "Title") != null)
        {
            if (title.len > 0 and !std.mem.eql(u8, title, "Unknown")) {
                return true;
            }
        }

        return false;
    }

    /// Call LLM (with optional JSON mode)
    fn callLLM(self: *Self, prompt: []const u8) ![]const u8 {
        return self.callLLMWithFormat(prompt, false);
    }

    /// Call LLM with JSON format option - supports OpenAI/Groq/HuggingFace/Anthropic or Ollama
    /// Includes retry logic for invalid responses - v23.9 reduced delays
    fn callLLMWithFormat(self: *Self, prompt: []const u8, json_mode: bool) ![]const u8 {
        _ = json_mode; // TODO: implement JSON mode for OpenAI client

        const max_retries: u32 = 2; // Reduced from 3
        var retry: u32 = 0;

        while (retry < max_retries) : (retry += 1) {
            const response = self.callLLMOnce(prompt) catch |err| {
                if (retry < max_retries - 1) {
                    std.time.sleep(200 * std.time.ns_per_ms); // Reduced from 500ms
                    continue;
                }
                return err;
            };

            // Validate response
            if (validateLLMResponse(response)) {
                return response;
            }

            // Invalid response - log and retry
            std.debug.print("    [LLM] Invalid response (retry {d}/{d}): {s}\n", .{ retry + 1, max_retries, response[0..@min(response.len, 50)] });
            self.allocator.free(response);

            if (retry < max_retries - 1) {
                std.time.sleep(100 * std.time.ns_per_ms); // Reduced from 300ms
            }
        }

        // All retries failed - return error
        return error.InvalidResponse;
    }

    /// Single LLM call without retry
    fn callLLMOnce(self: *Self, prompt: []const u8) ![]const u8 {
        // Use Anthropic Claude if configured
        if (self.current_provider == .anthropic) {
            if (self.anthropic_client) |*client| {
                var response = client.chat(prompt) catch return error.ConnectionFailed;
                defer response.deinit();
                return self.allocator.dupe(u8, response.content) catch return error.OutOfMemory;
            }
        }

        // Use OpenAI-compatible client if configured
        if (self.current_provider != .ollama) {
            if (self.llm_client) |*client| {
                var response = client.chat(prompt) catch return error.ConnectionFailed;
                defer response.deinit();
                return self.allocator.dupe(u8, response.content) catch return error.OutOfMemory;
            }
        }

        // Fallback to direct Ollama API
        return self.callOllamaDirectly(prompt);
    }

    /// Direct Ollama API call (legacy fallback)
    fn callOllamaDirectly(self: *Self, prompt: []const u8) ![]const u8 {
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

/// Validate LLM response format
pub fn validateLLMResponse(response: []const u8) bool {
    const trimmed = std.mem.trim(u8, response, " \t\n\r");
    if (trimmed.len == 0) return false;

    // Valid commands start with these keywords
    const valid_starts = [_][]const u8{
        "navigate ",
        "navigate\t",
        "click ",
        "click\t",
        "type ",
        "type\t",
        "enter",
        "scroll ",
        "done ",
        "done\t",
        "select ",
        "check ",
    };

    for (valid_starts) |start| {
        if (std.mem.startsWith(u8, trimmed, start)) {
            // Additional validation for navigate - must have URL
            if (std.mem.startsWith(u8, trimmed, "navigate")) {
                const rest = std.mem.trim(u8, trimmed[8..], " \t");
                // Must not be literal "URL" or empty
                if (rest.len == 0 or std.mem.eql(u8, rest, "URL")) {
                    return false;
                }
                // Should contain . or be a valid URL
                if (std.mem.indexOf(u8, rest, ".") != null or
                    std.mem.startsWith(u8, rest, "http"))
                {
                    return true;
                }
                return false;
            }
            return true;
        }
    }

    // Also valid if it's just "enter"
    if (std.mem.eql(u8, trimmed, "enter")) return true;

    // Check if response contains a URL (fallback)
    if (std.mem.indexOf(u8, trimmed, "https://") != null or
        std.mem.indexOf(u8, trimmed, "http://") != null)
    {
        return true;
    }

    return false;
}

/// Parse JSON action response
fn parseJsonAction(response: []const u8) ?Action {
    // Find "action" field
    const action_start = std.mem.indexOf(u8, response, "\"action\"") orelse return null;
    const action_value_start = std.mem.indexOf(u8, response[action_start..], ":") orelse return null;
    const after_colon = response[action_start + action_value_start + 1 ..];

    // Find action value
    const quote1 = std.mem.indexOf(u8, after_colon, "\"") orelse return null;
    const quote2 = std.mem.indexOf(u8, after_colon[quote1 + 1 ..], "\"") orelse return null;
    const action_type = after_colon[quote1 + 1 .. quote1 + 1 + quote2];

    // Find "arg" field
    var arg: []const u8 = "";
    if (std.mem.indexOf(u8, response, "\"arg\"")) |arg_start| {
        const arg_colon = std.mem.indexOf(u8, response[arg_start..], ":") orelse return null;
        const arg_after = response[arg_start + arg_colon + 1 ..];
        const arg_q1 = std.mem.indexOf(u8, arg_after, "\"") orelse return null;
        const arg_q2 = std.mem.indexOf(u8, arg_after[arg_q1 + 1 ..], "\"") orelse return null;
        arg = arg_after[arg_q1 + 1 .. arg_q1 + 1 + arg_q2];
    }

    // Map action type to Action
    if (std.mem.eql(u8, action_type, "navigate")) {
        return Action.navigate(arg);
    } else if (std.mem.eql(u8, action_type, "click")) {
        return Action.click(arg);
    } else if (std.mem.eql(u8, action_type, "type")) {
        return Action.typeText(arg);
    } else if (std.mem.eql(u8, action_type, "enter")) {
        return Action.pressEnter();
    } else if (std.mem.eql(u8, action_type, "scroll")) {
        if (std.mem.eql(u8, arg, "up")) {
            return Action.scroll(-300);
        }
        return Action.scroll(300);
    } else if (std.mem.eql(u8, action_type, "done")) {
        return Action.done(arg);
    } else if (std.mem.eql(u8, action_type, "select")) {
        return Action.selectOption(arg);
    } else if (std.mem.eql(u8, action_type, "check") or std.mem.eql(u8, action_type, "checkbox")) {
        return Action.checkBox(arg);
    }

    return null;
}

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

    // Handle escaped newlines from LLM (literal backslash-n)
    // First try to find the action keyword
    const keywords = [_][]const u8{ "navigate ", "click ", "type ", "enter", "scroll ", "done " };
    for (keywords) |kw| {
        if (std.mem.indexOf(u8, trimmed, kw)) |start| {
            trimmed = trimmed[start..];
            // Now trim at newline
            if (std.mem.indexOf(u8, trimmed, "\\n")) |nl| {
                trimmed = trimmed[0..nl];
            }
            break;
        }
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
    } else if (std.mem.startsWith(u8, trimmed, "click ") or std.mem.startsWith(u8, trimmed, "click\t")) {
        var arg = std.mem.trim(u8, trimmed[6..], " \t\n\r");
        // Remove comments like "(assuming...)"
        if (std.mem.indexOf(u8, arg, " (")) |paren| {
            arg = arg[0..paren];
        }
        if (std.mem.indexOf(u8, arg, "(")) |paren| {
            arg = arg[0..paren];
        }
        arg = std.mem.trim(u8, arg, " \t\n\r");
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

test "PlanningAgent with OpenAI initialization" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.initWithOpenAI(allocator, "Test goal", 5, "test-api-key");
    defer agent.deinit();

    try std.testing.expectEqualStrings("Test goal", agent.state.goal);
    try std.testing.expectEqual(LLMProvider.openai, agent.current_provider);
    try std.testing.expect(agent.llm_client != null);
}

test "PlanningAgent with Groq initialization" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.initWithGroq(allocator, "Test goal", 5, "test-groq-key");
    defer agent.deinit();

    try std.testing.expectEqual(LLMProvider.groq, agent.current_provider);
    try std.testing.expectEqualStrings(openai.GROQ_MODEL, agent.model);
}

test "PlanningAgent with HuggingFace initialization" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.initWithHuggingFace(allocator, "Test goal", 5, "hf_test_key");
    defer agent.deinit();

    try std.testing.expectEqual(LLMProvider.huggingface, agent.current_provider);
    try std.testing.expectEqualStrings(openai.HUGGINGFACE_MODEL, agent.model);
}

test "PlanningAgent with Anthropic initialization" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.initWithAnthropic(allocator, "Test goal", 5, "sk-ant-test");
    defer agent.deinit();

    try std.testing.expectEqual(LLMProvider.anthropic, agent.current_provider);
    try std.testing.expectEqualStrings(anthropic.DEFAULT_MODEL, agent.model);
    try std.testing.expect(agent.anthropic_client != null);
}

test "PlanningAgent with Claude Opus initialization" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.initWithClaudeOpus(allocator, "Test goal", 5, "sk-ant-test");
    defer agent.deinit();

    try std.testing.expectEqual(LLMProvider.anthropic, agent.current_provider);
    try std.testing.expectEqualStrings(anthropic.CLAUDE_3_OPUS, agent.model);
}

test "PlanningAgent setProvider" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.init(allocator, "Test goal", 5);
    defer agent.deinit();

    // Initially Ollama
    try std.testing.expectEqual(LLMProvider.ollama, agent.current_provider);

    // Switch to Groq
    agent.setProvider(.groq, "test-groq-key");
    try std.testing.expectEqual(LLMProvider.groq, agent.current_provider);
    try std.testing.expectEqualStrings(openai.GROQ_MODEL, agent.model);

    // Switch to Anthropic
    agent.setProvider(.anthropic, "sk-ant-test");
    try std.testing.expectEqual(LLMProvider.anthropic, agent.current_provider);
    try std.testing.expectEqualStrings(anthropic.DEFAULT_MODEL, agent.model);

    // Switch to Ollama (no API key needed)
    agent.setProvider(.ollama, null);
    try std.testing.expectEqualStrings(openai.OLLAMA_MODEL, agent.model);
}

test "LLM Provider comparison - model names" {
    // GPT-4 vs Ollama model comparison
    try std.testing.expectEqualStrings("gpt-4o-mini", openai.OPENAI_MODEL);
    try std.testing.expectEqualStrings("llama3.2:3b", openai.OLLAMA_MODEL);
    try std.testing.expectEqualStrings("llama-3.3-70b-versatile", openai.GROQ_MODEL);
    try std.testing.expectEqualStrings("Qwen/Qwen2.5-72B-Instruct", openai.HUGGINGFACE_MODEL);

    // Verify all providers have different URLs
    try std.testing.expect(!std.mem.eql(u8, openai.OPENAI_URL, openai.OLLAMA_URL));
    try std.testing.expect(!std.mem.eql(u8, openai.GROQ_URL, openai.OLLAMA_URL));
    try std.testing.expect(!std.mem.eql(u8, openai.HUGGINGFACE_URL, openai.OLLAMA_URL));
}

test "Provider switching preserves state" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.init(allocator, "Navigate to example.com", 10);
    defer agent.deinit();

    // Verify initial state
    try std.testing.expectEqualStrings("Navigate to example.com", agent.state.goal);
    try std.testing.expectEqual(@as(u32, 10), agent.state.max_steps);

    // Switch provider
    agent.setProvider(.openai, "sk-test-key");

    // State should be preserved
    try std.testing.expectEqualStrings("Navigate to example.com", agent.state.goal);
    try std.testing.expectEqual(@as(u32, 10), agent.state.max_steps);
    try std.testing.expectEqual(LLMProvider.openai, agent.current_provider);
}

test "Claude vs GPT-4 model comparison" {
    // Compare model names and capabilities
    try std.testing.expectEqualStrings("gpt-4o-mini", openai.OPENAI_MODEL);
    try std.testing.expectEqualStrings("claude-3-5-sonnet-20241022", anthropic.DEFAULT_MODEL);
    try std.testing.expectEqualStrings("claude-3-opus-20240229", anthropic.CLAUDE_3_OPUS);

    // Verify different API endpoints
    try std.testing.expect(!std.mem.eql(u8, openai.OPENAI_URL, anthropic.ANTHROPIC_URL));

    // Verify Anthropic uses Messages API (different from OpenAI)
    try std.testing.expect(std.mem.indexOf(u8, anthropic.ANTHROPIC_URL, "/messages") != null);
    try std.testing.expect(std.mem.indexOf(u8, openai.OPENAI_URL, "/chat/completions") != null);
}

test "All LLM providers available" {
    const allocator = std.testing.allocator;

    // Test all provider initializations
    var agent1 = PlanningAgent.initWithOpenAI(allocator, "goal", 5, "key");
    defer agent1.deinit();
    try std.testing.expectEqual(LLMProvider.openai, agent1.current_provider);

    var agent2 = PlanningAgent.initWithGroq(allocator, "goal", 5, "key");
    defer agent2.deinit();
    try std.testing.expectEqual(LLMProvider.groq, agent2.current_provider);

    var agent3 = PlanningAgent.initWithAnthropic(allocator, "goal", 5, "key");
    defer agent3.deinit();
    try std.testing.expectEqual(LLMProvider.anthropic, agent3.current_provider);

    var agent4 = PlanningAgent.initWithHuggingFace(allocator, "goal", 5, "key");
    defer agent4.deinit();
    try std.testing.expectEqual(LLMProvider.huggingface, agent4.current_provider);

    var agent5 = PlanningAgent.init(allocator, "goal", 5);
    defer agent5.deinit();
    try std.testing.expectEqual(LLMProvider.ollama, agent5.current_provider);
}

test "Vision methods exist" {
    const allocator = std.testing.allocator;
    var agent = PlanningAgent.initWithOpenAI(allocator, "Find the login button", 5, "test-key");
    defer agent.deinit();

    // Methods should exist (will fail without browser connection)
    _ = agent.analyzeWithVision("What do you see?") catch |err| {
        // Expected to fail without browser
        try std.testing.expect(err == error.ScreenshotFailed);
    };

    _ = agent.findElementByVision("login button") catch |err| {
        try std.testing.expect(err == error.ScreenshotFailed);
    };
}

test "Vision model constant" {
    try std.testing.expectEqualStrings("gpt-4o", openai.GPT4V_MODEL);
}

test "validateLLMResponse - valid responses" {
    // Valid navigate
    try std.testing.expect(validateLLMResponse("navigate https://example.com"));
    try std.testing.expect(validateLLMResponse("navigate https://google.com/search"));
    try std.testing.expect(validateLLMResponse("navigate http://localhost:8080"));

    // Valid click
    try std.testing.expect(validateLLMResponse("click a"));
    try std.testing.expect(validateLLMResponse("click button"));
    try std.testing.expect(validateLLMResponse("click #submit"));
    try std.testing.expect(validateLLMResponse("click .nav-link"));

    // Valid type
    try std.testing.expect(validateLLMResponse("type hello world"));
    try std.testing.expect(validateLLMResponse("type search query"));

    // Valid enter
    try std.testing.expect(validateLLMResponse("enter"));

    // Valid done
    try std.testing.expect(validateLLMResponse("done Task completed"));
    try std.testing.expect(validateLLMResponse("done The title is Example"));
}

test "validateLLMResponse - invalid responses" {
    // Invalid - literal "URL"
    try std.testing.expect(!validateLLMResponse("navigate URL"));

    // Invalid - empty
    try std.testing.expect(!validateLLMResponse(""));
    try std.testing.expect(!validateLLMResponse("   "));

    // Invalid - explanation instead of command
    try std.testing.expect(!validateLLMResponse("I will navigate to the website"));
    try std.testing.expect(!validateLLMResponse("Let me click on the button"));

    // Invalid - just text
    try std.testing.expect(!validateLLMResponse("hello world"));
    try std.testing.expect(!validateLLMResponse("example.com")); // no navigate prefix
}

test "DOM element selection from parseJsonAction" {
    // Test parsing JSON with DOM selectors
    const json1 = "{\"action\":\"click\",\"arg\":\"#submit-btn\"}";
    const action1 = parseJsonAction(json1);
    try std.testing.expect(action1 != null);
    try std.testing.expectEqual(ActionType.click, action1.?.action_type);
    try std.testing.expectEqualStrings("#submit-btn", action1.?.getArg());

    const json2 = "{\"action\":\"click\",\"arg\":\".search-input\"}";
    const action2 = parseJsonAction(json2);
    try std.testing.expect(action2 != null);
    try std.testing.expectEqualStrings(".search-input", action2.?.getArg());

    const json3 = "{\"action\":\"click\",\"arg\":\"button\"}";
    const action3 = parseJsonAction(json3);
    try std.testing.expect(action3 != null);
    try std.testing.expectEqualStrings("button", action3.?.getArg());
}

test "DOM summary in PageState" {
    const allocator = std.testing.allocator;
    var state = AgentState.init(allocator, "Click the submit button", 5);
    defer state.deinit();

    // Simulate DOM summary
    state.current_page.dom_summary = "button#submit.btn \"Submit\"\ninput.search name=q\na href=https://example.com \"Home\"";

    // Verify DOM summary is stored
    try std.testing.expect(state.current_page.dom_summary.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, state.current_page.dom_summary, "button#submit") != null);
}

test "parseActionDirect with DOM selectors" {
    // Test direct parsing with DOM selectors
    const action1 = parseActionDirect("click #login-btn");
    try std.testing.expectEqual(ActionType.click, action1.action_type);
    try std.testing.expectEqualStrings("#login-btn", action1.getArg());

    const action2 = parseActionDirect("click .nav-link");
    try std.testing.expectEqual(ActionType.click, action2.action_type);
    try std.testing.expectEqualStrings(".nav-link", action2.getArg());

    const action3 = parseActionDirect("click input[name=email]");
    try std.testing.expectEqual(ActionType.click, action3.action_type);
}

test "Form actions - selectOption" {
    const action = Action.selectOption("select#country:US");
    try std.testing.expectEqual(ActionType.select_option, action.action_type);
    try std.testing.expectEqualStrings("select#country:US", action.getArg());
}

test "Form actions - checkBox" {
    const action1 = Action.checkBox("input#agree:true");
    try std.testing.expectEqual(ActionType.check_box, action1.action_type);
    try std.testing.expectEqualStrings("input#agree:true", action1.getArg());

    const action2 = Action.checkBox("input#newsletter:false");
    try std.testing.expectEqual(ActionType.check_box, action2.action_type);
    try std.testing.expectEqualStrings("input#newsletter:false", action2.getArg());
}

test "parseJsonAction with form actions" {
    // Test select action
    const json1 = "{\"action\":\"select\",\"arg\":\"#country:USA\"}";
    const action1 = parseJsonAction(json1);
    try std.testing.expect(action1 != null);
    try std.testing.expectEqual(ActionType.select_option, action1.?.action_type);
    try std.testing.expectEqualStrings("#country:USA", action1.?.getArg());

    // Test checkbox action
    const json2 = "{\"action\":\"check\",\"arg\":\"#terms:true\"}";
    const action2 = parseJsonAction(json2);
    try std.testing.expect(action2 != null);
    try std.testing.expectEqual(ActionType.check_box, action2.?.action_type);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION CACHE TESTS - v23.10
// ═══════════════════════════════════════════════════════════════════════════════

test "ActionCache initialization" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const stats = cache.getStats();
    try std.testing.expectEqual(@as(u32, 0), stats.hits);
    try std.testing.expectEqual(@as(u32, 0), stats.misses);
    try std.testing.expectEqual(@as(u32, 0), stats.entries);
}

test "ActionCache goalToKey - navigation" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const key = try cache.goalToKey("Go to example.com");
    defer std.testing.allocator.free(key);

    // Should extract "nav:example.com"
    try std.testing.expect(std.mem.indexOf(u8, key, "nav") != null);
    try std.testing.expect(std.mem.indexOf(u8, key, "example.com") != null);
}

test "ActionCache goalToKey - search" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const key = try cache.goalToKey("Search for cats on google.com");
    defer std.testing.allocator.free(key);

    try std.testing.expect(std.mem.indexOf(u8, key, "search") != null);
    try std.testing.expect(std.mem.indexOf(u8, key, "google.com") != null);
}

test "ActionCache store and lookup" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const action = Action.navigate("https://example.com");
    cache.store("Go to example.com", action);

    // First lookup should miss (need success_count > fail_count)
    // Store again to increase success_count
    cache.store("Go to example.com", action);

    const result = cache.lookup("Go to example.com");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(ActionType.navigate, result.?.action_type);
}

test "ActionCache miss on unknown goal" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const result = cache.lookup("Do something random");
    try std.testing.expect(result == null);

    const stats = cache.getStats();
    try std.testing.expectEqual(@as(u32, 1), stats.misses);
}

test "ActionCache invalidation on failure" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const action = Action.navigate("https://example.com");
    cache.store("Go to example.com", action);
    cache.store("Go to example.com", action); // success_count = 2

    // Mark as failed twice
    cache.markFailed("Go to example.com");
    cache.markFailed("Go to example.com");
    cache.markFailed("Go to example.com"); // fail_count = 3

    // Now lookup should return null (fail > success)
    const result = cache.lookup("Go to example.com");
    try std.testing.expect(result == null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENCE TESTS - v23.11
// ═══════════════════════════════════════════════════════════════════════════════

test "ActionCache serializeToJson" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const action = Action.navigate("https://example.com");
    cache.store("Go to example.com", action);
    cache.store("Go to example.com", action);

    const json = try cache.serializeToJson();
    defer std.testing.allocator.free(json);

    // Check JSON structure
    try std.testing.expect(std.mem.indexOf(u8, json, "\"version\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"entries\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "nav:example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "navigate") != null);
}

test "ActionCache deserializeFromJson" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    const json = "{\"version\":1,\"entries\":[{\"key\":\"nav:test.com\",\"action_type\":\"navigate\",\"action_arg\":\"https://test.com\",\"success\":5,\"fail\":0,\"last_used\":9999999999}]}";

    try cache.deserializeFromJson(json);

    // Check entry was loaded
    const stats = cache.getStats();
    try std.testing.expectEqual(@as(u32, 1), stats.entries);
}

test "ActionCache serialize and deserialize roundtrip" {
    // Create and populate cache
    var cache1 = ActionCache.init(std.testing.allocator);
    defer cache1.deinit();

    cache1.store("Go to example.com", Action.navigate("https://example.com"));
    cache1.store("Go to example.com", Action.navigate("https://example.com"));
    cache1.store("Click button", Action.click("#submit"));
    cache1.store("Click button", Action.click("#submit"));

    // Serialize
    const json = try cache1.serializeToJson();
    defer std.testing.allocator.free(json);

    // Deserialize into new cache
    var cache2 = ActionCache.init(std.testing.allocator);
    defer cache2.deinit();

    try cache2.deserializeFromJson(json);

    // Check both caches have same entries
    const stats1 = cache1.getStats();
    const stats2 = cache2.getStats();
    try std.testing.expectEqual(stats1.entries, stats2.entries);
}

test "ActionCache TTL expiration" {
    var cache = ActionCache.init(std.testing.allocator);
    defer cache.deinit();

    // Create entry with old timestamp (expired)
    const old_json = "{\"version\":1,\"entries\":[{\"key\":\"nav:old.com\",\"action_type\":\"navigate\",\"action_arg\":\"https://old.com\",\"success\":5,\"fail\":0,\"last_used\":1000}]}";

    try cache.deserializeFromJson(old_json);

    // Entry should not be loaded (expired)
    const stats = cache.getStats();
    try std.testing.expectEqual(@as(u32, 0), stats.entries);
}
