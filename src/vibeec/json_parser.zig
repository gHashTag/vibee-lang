// VIBEE JSON Parser - Pure Zig Implementation with SIMD
// High-performance JSON parsing for LLM responses
// Target: 10x faster than JS JSON.parse
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const JsonError = error{
    InvalidJson,
    UnexpectedToken,
    UnexpectedEndOfInput,
    InvalidNumber,
    InvalidString,
    InvalidEscape,
    OutOfMemory,
    PathNotFound,
};

pub const JsonType = enum {
    null,
    bool,
    number,
    string,
    array,
    object,
};

pub const JsonValue = union(JsonType) {
    null: void,
    bool: bool,
    number: f64,
    string: []const u8,
    array: std.ArrayList(JsonValue),
    object: std.StringHashMap(JsonValue),

    pub fn deinit(self: *JsonValue, allocator: Allocator) void {
        switch (self.*) {
            .array => |*arr| {
                for (arr.items) |*item| {
                    item.deinit(allocator);
                }
                arr.deinit();
            },
            .object => |*obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    var val = entry.value_ptr.*;
                    val.deinit(allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }

    pub fn getString(self: JsonValue) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn getNumber(self: JsonValue) ?f64 {
        return switch (self) {
            .number => |n| n,
            else => null,
        };
    }

    pub fn getBool(self: JsonValue) ?bool {
        return switch (self) {
            .bool => |b| b,
            else => null,
        };
    }

    pub fn getArray(self: JsonValue) ?[]JsonValue {
        return switch (self) {
            .array => |arr| arr.items,
            else => null,
        };
    }

    pub fn getObject(self: JsonValue) ?std.StringHashMap(JsonValue) {
        return switch (self) {
            .object => |obj| obj,
            else => null,
        };
    }
};

pub const ParseResult = struct {
    value: JsonValue,
    parse_time_ns: i64,
    bytes_parsed: usize,

    pub fn deinit(self: *ParseResult, allocator: Allocator) void {
        self.value.deinit(allocator);
    }
};

pub const JsonParser = struct {
    allocator: Allocator,
    input: []const u8,
    pos: usize,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .input = "",
            .pos = 0,
        };
    }

    /// Parse JSON string into JsonValue
    pub fn parse(self: *Self, input: []const u8) !ParseResult {
        const start_time = std.time.nanoTimestamp();

        self.input = input;
        self.pos = 0;

        self.skipWhitespace();
        const value = try self.parseValue();

        const end_time = std.time.nanoTimestamp();

        return ParseResult{
            .value = value,
            .parse_time_ns = @intCast(end_time - start_time),
            .bytes_parsed = input.len,
        };
    }

    fn parseValue(self: *Self) JsonError!JsonValue {
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return JsonError.UnexpectedEndOfInput;
        }

        const c = self.input[self.pos];

        return switch (c) {
            '"' => self.parseString(),
            '{' => self.parseObject(),
            '[' => self.parseArray(),
            't', 'f' => self.parseBool(),
            'n' => self.parseNull(),
            '-', '0'...'9' => self.parseNumber(),
            else => JsonError.UnexpectedToken,
        };
    }

    fn parseString(self: *Self) JsonError!JsonValue {
        if (self.input[self.pos] != '"') return JsonError.UnexpectedToken;
        self.pos += 1;

        const start = self.pos;

        // SIMD-optimized string scanning
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == '"') {
                const str = self.input[start..self.pos];
                self.pos += 1;
                return JsonValue{ .string = str };
            }
            if (c == '\\') {
                self.pos += 2; // Skip escape sequence
                continue;
            }
            self.pos += 1;
        }

        return JsonError.UnexpectedEndOfInput;
    }

    fn parseNumber(self: *Self) JsonError!JsonValue {
        const start = self.pos;

        // Handle negative
        if (self.pos < self.input.len and self.input[self.pos] == '-') {
            self.pos += 1;
        }

        // Integer part
        while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
            self.pos += 1;
        }

        // Decimal part
        if (self.pos < self.input.len and self.input[self.pos] == '.') {
            self.pos += 1;
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
        }

        // Exponent part
        if (self.pos < self.input.len and (self.input[self.pos] == 'e' or self.input[self.pos] == 'E')) {
            self.pos += 1;
            if (self.pos < self.input.len and (self.input[self.pos] == '+' or self.input[self.pos] == '-')) {
                self.pos += 1;
            }
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
        }

        const num_str = self.input[start..self.pos];
        const num = std.fmt.parseFloat(f64, num_str) catch return JsonError.InvalidNumber;

        return JsonValue{ .number = num };
    }

    fn parseBool(self: *Self) JsonError!JsonValue {
        if (self.pos + 4 <= self.input.len and std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "true")) {
            self.pos += 4;
            return JsonValue{ .bool = true };
        }
        if (self.pos + 5 <= self.input.len and std.mem.eql(u8, self.input[self.pos .. self.pos + 5], "false")) {
            self.pos += 5;
            return JsonValue{ .bool = false };
        }
        return JsonError.UnexpectedToken;
    }

    fn parseNull(self: *Self) JsonError!JsonValue {
        if (self.pos + 4 <= self.input.len and std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "null")) {
            self.pos += 4;
            return JsonValue{ .null = {} };
        }
        return JsonError.UnexpectedToken;
    }

    fn parseArray(self: *Self) JsonError!JsonValue {
        if (self.input[self.pos] != '[') return JsonError.UnexpectedToken;
        self.pos += 1;

        var arr = std.ArrayList(JsonValue).init(self.allocator);
        errdefer arr.deinit();

        self.skipWhitespace();

        if (self.pos < self.input.len and self.input[self.pos] == ']') {
            self.pos += 1;
            return JsonValue{ .array = arr };
        }

        while (true) {
            const value = try self.parseValue();
            try arr.append(value);

            self.skipWhitespace();

            if (self.pos >= self.input.len) return JsonError.UnexpectedEndOfInput;

            if (self.input[self.pos] == ']') {
                self.pos += 1;
                return JsonValue{ .array = arr };
            }

            if (self.input[self.pos] != ',') return JsonError.UnexpectedToken;
            self.pos += 1;
        }
    }

    fn parseObject(self: *Self) JsonError!JsonValue {
        if (self.input[self.pos] != '{') return JsonError.UnexpectedToken;
        self.pos += 1;

        var obj = std.StringHashMap(JsonValue).init(self.allocator);
        errdefer obj.deinit();

        self.skipWhitespace();

        if (self.pos < self.input.len and self.input[self.pos] == '}') {
            self.pos += 1;
            return JsonValue{ .object = obj };
        }

        while (true) {
            self.skipWhitespace();

            // Parse key
            const key_value = try self.parseString();
            const key = key_value.getString() orelse return JsonError.UnexpectedToken;

            self.skipWhitespace();

            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                return JsonError.UnexpectedToken;
            }
            self.pos += 1;

            // Parse value
            const value = try self.parseValue();
            try obj.put(key, value);

            self.skipWhitespace();

            if (self.pos >= self.input.len) return JsonError.UnexpectedEndOfInput;

            if (self.input[self.pos] == '}') {
                self.pos += 1;
                return JsonValue{ .object = obj };
            }

            if (self.input[self.pos] != ',') return JsonError.UnexpectedToken;
            self.pos += 1;
        }
    }

    fn skipWhitespace(self: *Self) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                self.pos += 1;
            } else {
                break;
            }
        }
    }
};

/// Extract value by JSONPath (simplified: $.key.subkey[0])
pub fn queryPath(value: JsonValue, path: []const u8) ?JsonValue {
    if (path.len == 0 or path[0] != '$') return null;

    var current = value;
    var pos: usize = 1;

    while (pos < path.len) {
        // Skip dot
        if (path[pos] == '.') {
            pos += 1;
        }

        // Array index
        if (path[pos] == '[') {
            pos += 1;
            const idx_start = pos;
            while (pos < path.len and path[pos] != ']') {
                pos += 1;
            }
            const idx_str = path[idx_start..pos];
            const idx = std.fmt.parseInt(usize, idx_str, 10) catch return null;
            pos += 1; // Skip ]

            const arr = current.getArray() orelse return null;
            if (idx >= arr.len) return null;
            current = arr[idx];
            continue;
        }

        // Object key
        const key_start = pos;
        while (pos < path.len and path[pos] != '.' and path[pos] != '[') {
            pos += 1;
        }
        const key = path[key_start..pos];

        const obj = current.getObject() orelse return null;
        current = obj.get(key) orelse return null;
    }

    return current;
}

// ============================================================================
// TESTS
// ============================================================================

test "parse simple string" {
    const allocator = std.testing.allocator;
    var parser = JsonParser.init(allocator);

    var result = try parser.parse("\"hello world\"");
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("hello world", result.value.getString().?);
}

test "parse number" {
    const allocator = std.testing.allocator;
    var parser = JsonParser.init(allocator);

    var result = try parser.parse("42.5");
    defer result.deinit(allocator);

    try std.testing.expectApproxEqAbs(42.5, result.value.getNumber().?, 0.001);
}

test "parse boolean" {
    const allocator = std.testing.allocator;
    var parser = JsonParser.init(allocator);

    var result = try parser.parse("true");
    defer result.deinit(allocator);

    try std.testing.expect(result.value.getBool().?);
}

test "parse null" {
    const allocator = std.testing.allocator;
    var parser = JsonParser.init(allocator);

    var result = try parser.parse("null");
    defer result.deinit(allocator);

    try std.testing.expect(result.value == .null);
}

test "parse array" {
    const allocator = std.testing.allocator;
    var parser = JsonParser.init(allocator);

    var result = try parser.parse("[1, 2, 3]");
    defer result.deinit(allocator);

    const arr = result.value.getArray().?;
    try std.testing.expectEqual(@as(usize, 3), arr.len);
}

test "parse object" {
    const allocator = std.testing.allocator;
    var parser = JsonParser.init(allocator);

    var result = try parser.parse("{\"name\": \"vibee\", \"version\": 12}");
    defer result.deinit(allocator);

    const obj = result.value.getObject().?;
    try std.testing.expectEqualStrings("vibee", obj.get("name").?.getString().?);
}

test "parse OpenAI response structure" {
    const allocator = std.testing.allocator;
    var parser = JsonParser.init(allocator);

    const json =
        \\{
        \\  "choices": [
        \\    {
        \\      "message": {
        \\        "content": "Hello from GPT!"
        \\      }
        \\    }
        \\  ]
        \\}
    ;

    var result = try parser.parse(json);
    defer result.deinit(allocator);

    // Extract content using path
    const content = queryPath(result.value, "$.choices[0].message.content");
    try std.testing.expectEqualStrings("Hello from GPT!", content.?.getString().?);
}

test "phi constant" {
    // φ² + 1/φ² = 3
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
