// VIBEE WebArena Task Parser
// Parses WebArena benchmark task configs
// Pure Zig implementation
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("json_parser.zig");

pub const TaskError = error{
    ParseError,
    InvalidFormat,
    MissingField,
    OutOfMemory,
};

pub const EvalType = enum {
    string_match,
    url_match,
    program_html,

    pub fn fromString(s: []const u8) ?EvalType {
        if (std.mem.eql(u8, s, "string_match")) return .string_match;
        if (std.mem.eql(u8, s, "url_match")) return .url_match;
        if (std.mem.eql(u8, s, "program_html")) return .program_html;
        return null;
    }
};

pub const TaskEval = struct {
    eval_types: []EvalType,
    reference_answers: ?[][]const u8,
    reference_url: []const u8,

    pub fn deinit(self: *TaskEval, allocator: Allocator) void {
        allocator.free(self.eval_types);
        if (self.reference_answers) |answers| {
            allocator.free(answers);
        }
    }
};

pub const ActionSequence = struct {
    action_set_tag: []const u8,
    actions: [][]const u8,

    pub fn deinit(self: *ActionSequence, allocator: Allocator) void {
        allocator.free(self.actions);
    }
};

pub const WebArenaTask = struct {
    allocator: Allocator,
    task_id: i64,
    sites: [][]const u8,
    require_login: bool,
    storage_state: ?[]const u8,
    start_url: []const u8,
    intent_template: []const u8,
    intent: []const u8,
    require_reset: bool,
    eval: TaskEval,
    reference_action_sequence: ?ActionSequence,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.sites);
        self.eval.deinit(self.allocator);
        if (self.reference_action_sequence) |*seq| {
            seq.deinit(self.allocator);
        }
    }

    /// Get the start URL for this task
    pub fn getStartUrl(self: *const Self) []const u8 {
        return self.start_url;
    }

    /// Get the task intent (human-readable description)
    pub fn getIntent(self: *const Self) []const u8 {
        return self.intent;
    }

    /// Check if task requires login
    pub fn requiresLogin(self: *const Self) bool {
        return self.require_login;
    }

    /// Evaluate string match
    pub fn evaluateStringMatch(self: *const Self, response: []const u8) bool {
        if (self.eval.reference_answers) |answers| {
            for (answers) |answer| {
                if (std.mem.indexOf(u8, response, answer) != null) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Evaluate URL match
    pub fn evaluateUrlMatch(self: *const Self, current_url: []const u8) bool {
        if (self.eval.reference_url.len == 0) return false;
        return std.mem.eql(u8, current_url, self.eval.reference_url);
    }

    /// Check if any evaluation passes
    pub fn evaluate(self: *const Self, response: []const u8, current_url: []const u8) bool {
        for (self.eval.eval_types) |eval_type| {
            switch (eval_type) {
                .string_match => {
                    if (self.evaluateStringMatch(response)) return true;
                },
                .url_match => {
                    if (self.evaluateUrlMatch(current_url)) return true;
                },
                .program_html => {
                    // Not implemented yet
                },
            }
        }
        return false;
    }
};

/// Parse WebArena task from JSON string
pub fn parseTask(allocator: Allocator, json_str: []const u8) TaskError!WebArenaTask {
    var parser = json.JsonParser.init(allocator);
    var result = parser.parse(json_str) catch return TaskError.ParseError;
    defer result.deinit(allocator);

    const root = result.value.getObject() orelse return TaskError.InvalidFormat;

    // Extract task_id
    const task_id_val = root.get("task_id") orelse return TaskError.MissingField;
    const task_id: i64 = @intFromFloat(task_id_val.getNumber() orelse return TaskError.InvalidFormat);

    // Extract sites
    const sites_val = root.get("sites") orelse return TaskError.MissingField;
    const sites_arr = sites_val.getArray() orelse return TaskError.InvalidFormat;
    var sites = allocator.alloc([]const u8, sites_arr.len) catch return TaskError.OutOfMemory;
    for (sites_arr, 0..) |site, i| {
        sites[i] = site.getString() orelse "";
    }

    // Extract require_login
    const require_login = if (root.get("require_login")) |v| v.getBool() orelse false else false;

    // Extract storage_state
    const storage_state = if (root.get("storage_state")) |v| v.getString() else null;

    // Extract start_url
    const start_url = if (root.get("start_url")) |v| v.getString() orelse "" else "";

    // Extract intent_template
    const intent_template = if (root.get("intent_template")) |v| v.getString() orelse "" else "";

    // Extract intent
    const intent = if (root.get("intent")) |v| v.getString() orelse "" else "";

    // Extract require_reset
    const require_reset = if (root.get("require_reset")) |v| v.getBool() orelse false else false;

    // Extract eval
    var eval_types = std.ArrayList(EvalType).init(allocator);
    var reference_answers: ?[][]const u8 = null;
    var reference_url: []const u8 = "";

    if (root.get("eval")) |eval_obj| {
        if (eval_obj.getObject()) |eval| {
            // eval_types
            if (eval.get("eval_types")) |types_val| {
                if (types_val.getArray()) |types_arr| {
                    for (types_arr) |t| {
                        if (t.getString()) |type_str| {
                            if (EvalType.fromString(type_str)) |et| {
                                eval_types.append(et) catch {};
                            }
                        }
                    }
                }
            }

            // reference_answers
            if (eval.get("reference_answers")) |answers_val| {
                if (answers_val.getArray()) |answers_arr| {
                    var answers = allocator.alloc([]const u8, answers_arr.len) catch return TaskError.OutOfMemory;
                    for (answers_arr, 0..) |a, i| {
                        answers[i] = a.getString() orelse "";
                    }
                    reference_answers = answers;
                }
            }

            // reference_url
            if (eval.get("reference_url")) |url_val| {
                reference_url = url_val.getString() orelse "";
            }
        }
    }

    const task_eval = TaskEval{
        .eval_types = eval_types.toOwnedSlice() catch return TaskError.OutOfMemory,
        .reference_answers = reference_answers,
        .reference_url = reference_url,
    };

    return WebArenaTask{
        .allocator = allocator,
        .task_id = task_id,
        .sites = sites,
        .require_login = require_login,
        .storage_state = storage_state,
        .start_url = start_url,
        .intent_template = intent_template,
        .intent = intent,
        .require_reset = require_reset,
        .eval = task_eval,
        .reference_action_sequence = null,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "parse WebArena task" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "task_id": 1,
        \\  "sites": ["reddit"],
        \\  "require_login": true,
        \\  "storage_state": "./.auth/reddit_state.json",
        \\  "start_url": "http://example.com/",
        \\  "intent_template": "tell me all subreddits starting with '{{character}}'",
        \\  "intent": "tell me all subreddits starting with 'a'",
        \\  "require_reset": false,
        \\  "eval": {
        \\    "eval_types": ["string_match"],
        \\    "reference_answers": ["announcements Art AskReddit"],
        \\    "reference_url": ""
        \\  }
        \\}
    ;

    var task = try parseTask(allocator, json_str);
    defer task.deinit();

    try std.testing.expectEqual(@as(i64, 1), task.task_id);
    try std.testing.expect(task.require_login);
    try std.testing.expectEqualStrings("http://example.com/", task.getStartUrl());
    try std.testing.expectEqualStrings("tell me all subreddits starting with 'a'", task.getIntent());
}

test "evaluate string match" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "task_id": 1,
        \\  "sites": ["test"],
        \\  "require_login": false,
        \\  "start_url": "http://test.com",
        \\  "intent": "test",
        \\  "require_reset": false,
        \\  "eval": {
        \\    "eval_types": ["string_match"],
        \\    "reference_answers": ["hello world"],
        \\    "reference_url": ""
        \\  }
        \\}
    ;

    var task = try parseTask(allocator, json_str);
    defer task.deinit();

    try std.testing.expect(task.evaluateStringMatch("The answer is hello world!"));
    try std.testing.expect(!task.evaluateStringMatch("goodbye"));
}

test "evaluate URL match" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "task_id": 2,
        \\  "sites": ["misc"],
        \\  "require_login": false,
        \\  "start_url": "http://test.com",
        \\  "intent": "navigate",
        \\  "require_reset": false,
        \\  "eval": {
        \\    "eval_types": ["url_match"],
        \\    "reference_url": "http://test.com/page#section"
        \\  }
        \\}
    ;

    var task = try parseTask(allocator, json_str);
    defer task.deinit();

    try std.testing.expect(task.evaluateUrlMatch("http://test.com/page#section"));
    try std.testing.expect(!task.evaluateUrlMatch("http://test.com/other"));
}

test "EvalType fromString" {
    try std.testing.expectEqual(EvalType.string_match, EvalType.fromString("string_match").?);
    try std.testing.expectEqual(EvalType.url_match, EvalType.fromString("url_match").?);
    try std.testing.expectEqual(EvalType.program_html, EvalType.fromString("program_html").?);
    try std.testing.expect(EvalType.fromString("invalid") == null);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "task with multiple sites" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "task_id": 100,
        \\  "sites": ["shopping", "reddit", "gitlab"],
        \\  "require_login": false,
        \\  "start_url": "http://multi.com",
        \\  "intent": "multi-site task",
        \\  "require_reset": true,
        \\  "eval": {
        \\    "eval_types": ["string_match", "url_match"],
        \\    "reference_answers": ["answer1", "answer2"],
        \\    "reference_url": "http://result.com"
        \\  }
        \\}
    ;

    var task = try parseTask(allocator, json_str);
    defer task.deinit();

    try std.testing.expectEqual(@as(i64, 100), task.task_id);
    try std.testing.expectEqual(@as(usize, 3), task.sites.len);
    try std.testing.expect(task.require_reset);
    try std.testing.expectEqual(@as(usize, 2), task.eval.eval_types.len);
}

test "task requiresLogin" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "task_id": 1,
        \\  "sites": ["test"],
        \\  "require_login": true,
        \\  "start_url": "http://test.com",
        \\  "intent": "test",
        \\  "require_reset": false,
        \\  "eval": {"eval_types": [], "reference_url": ""}
        \\}
    ;

    var task = try parseTask(allocator, json_str);
    defer task.deinit();

    try std.testing.expect(task.requiresLogin());
}

test "task combined evaluation" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "task_id": 1,
        \\  "sites": ["test"],
        \\  "require_login": false,
        \\  "start_url": "http://test.com",
        \\  "intent": "test",
        \\  "require_reset": false,
        \\  "eval": {
        \\    "eval_types": ["string_match", "url_match"],
        \\    "reference_answers": ["correct answer"],
        \\    "reference_url": "http://success.com"
        \\  }
        \\}
    ;

    var task = try parseTask(allocator, json_str);
    defer task.deinit();

    // String match should pass
    try std.testing.expect(task.evaluate("The correct answer is here", "http://other.com"));

    // URL match should pass
    try std.testing.expect(task.evaluate("wrong", "http://success.com"));

    // Neither should fail
    try std.testing.expect(!task.evaluate("wrong", "http://wrong.com"));
}
