// VIBEEC Parser - Parses .vibee YAML specifications
// Supports full Given/When/Then behavioral format

const std = @import("std");

pub const Spec = struct {
    name: []const u8,
    version: []const u8,
    language: []const u8,
    module: []const u8,
    description: []const u8,
    behaviors: []Behavior,
    types: []Type,
    functions: []Function,
    imports: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const Spec) void {
        for (self.behaviors) |b| {
            self.allocator.free(b.test_cases);
        }
        self.allocator.free(self.behaviors);
        for (self.types) |t| {
            self.allocator.free(t.fields);
        }
        self.allocator.free(self.types);
        for (self.functions) |f| {
            self.allocator.free(f.params);
        }
        self.allocator.free(self.functions);
        self.allocator.free(self.imports);
    }
};

pub const Behavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
    test_cases: []TestCase,
};

pub const TestCase = struct {
    name: []const u8,
    input: []const u8,
    expected: []const u8,
};

pub const Type = struct {
    name: []const u8,
    fields: []Field,
};

pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
};

pub const Function = struct {
    name: []const u8,
    params: []Field,
    returns: []const u8,
};

pub const ParseError = error{
    InvalidYaml,
    MissingRequiredField,
    InvalidBehavior,
    OutOfMemory,
};

const ParserState = enum {
    Root,
    Behaviors,
    BehaviorItem,
    TestCases,
    TestCaseItem,
    Types,
    TypeItem,
    Functions,
    FunctionItem,
    Imports,
};

pub fn parse(allocator: std.mem.Allocator, content: []const u8) ParseError!Spec {
    var spec = Spec{
        .name = "unknown",
        .version = "1.0.0",
        .language = "zig",
        .module = "module",
        .description = "",
        .behaviors = &[_]Behavior{},
        .types = &[_]Type{},
        .functions = &[_]Function{},
        .imports = &[_][]const u8{},
        .allocator = allocator,
    };

    var behaviors = std.ArrayList(Behavior).init(allocator);
    var types = std.ArrayList(Type).init(allocator);
    var functions = std.ArrayList(Function).init(allocator);
    var imports = std.ArrayList([]const u8).init(allocator);

    var state: ParserState = .Root;
    var current_behavior: ?Behavior = null;
    var current_test_cases = std.ArrayList(TestCase).init(allocator);
    var current_type: ?Type = null;
    var current_fields = std.ArrayList(Field).init(allocator);
    var current_function: ?Function = null;
    var current_params = std.ArrayList(Field).init(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        const indent = getIndent(line);

        // State transitions based on keywords
        if (std.mem.startsWith(u8, trimmed, "behaviors:")) {
            state = .Behaviors;
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "types:")) {
            if (current_behavior) |*b| {
                b.test_cases = current_test_cases.toOwnedSlice() catch return ParseError.OutOfMemory;
                behaviors.append(b.*) catch return ParseError.OutOfMemory;
                current_behavior = null;
            }
            state = .Types;
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "functions:")) {
            if (current_type) |*t| {
                t.fields = current_fields.toOwnedSlice() catch return ParseError.OutOfMemory;
                types.append(t.*) catch return ParseError.OutOfMemory;
                current_type = null;
            }
            state = .Functions;
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "imports:")) {
            if (current_function) |*f| {
                f.params = current_params.toOwnedSlice() catch return ParseError.OutOfMemory;
                functions.append(f.*) catch return ParseError.OutOfMemory;
                current_function = null;
            }
            state = .Imports;
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "test_cases:")) {
            state = .TestCases;
            continue;
        }

        switch (state) {
            .Root => {
                if (std.mem.startsWith(u8, trimmed, "name:")) {
                    spec.name = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "version:")) {
                    spec.version = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "language:")) {
                    spec.language = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "module:")) {
                    spec.module = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "description:")) {
                    spec.description = extractValue(trimmed);
                }
            },
            .Behaviors, .BehaviorItem => {
                if (std.mem.startsWith(u8, trimmed, "- name:")) {
                    if (current_behavior) |*b| {
                        b.test_cases = current_test_cases.toOwnedSlice() catch return ParseError.OutOfMemory;
                        behaviors.append(b.*) catch return ParseError.OutOfMemory;
                        current_test_cases = std.ArrayList(TestCase).init(allocator);
                    }
                    current_behavior = Behavior{
                        .name = extractValue(trimmed[2..]),
                        .given = "",
                        .when = "",
                        .then = "",
                        .test_cases = &[_]TestCase{},
                    };
                    state = .BehaviorItem;
                } else if (std.mem.startsWith(u8, trimmed, "given:")) {
                    if (current_behavior) |*b| b.given = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "when:")) {
                    if (current_behavior) |*b| b.when = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "then:")) {
                    if (current_behavior) |*b| b.then = extractValue(trimmed);
                }
            },
            .TestCases, .TestCaseItem => {
                if (std.mem.startsWith(u8, trimmed, "- name:")) {
                    const tc = TestCase{
                        .name = extractValue(trimmed[2..]),
                        .input = "",
                        .expected = "",
                    };
                    current_test_cases.append(tc) catch return ParseError.OutOfMemory;
                    state = .TestCaseItem;
                } else if (std.mem.startsWith(u8, trimmed, "input:")) {
                    if (current_test_cases.items.len > 0) {
                        current_test_cases.items[current_test_cases.items.len - 1].input = extractValue(trimmed);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "expected:")) {
                    if (current_test_cases.items.len > 0) {
                        current_test_cases.items[current_test_cases.items.len - 1].expected = extractValue(trimmed);
                    }
                } else if (indent < 6 and (std.mem.startsWith(u8, trimmed, "given:") or std.mem.startsWith(u8, trimmed, "when:") or std.mem.startsWith(u8, trimmed, "then:"))) {
                    state = .BehaviorItem;
                    if (std.mem.startsWith(u8, trimmed, "given:")) {
                        if (current_behavior) |*b| b.given = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "when:")) {
                        if (current_behavior) |*b| b.when = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "then:")) {
                        if (current_behavior) |*b| b.then = extractValue(trimmed);
                    }
                }
            },
            .Types, .TypeItem => {
                if (indent == 2 and !std.mem.startsWith(u8, trimmed, "-")) {
                    if (current_type) |*t| {
                        t.fields = current_fields.toOwnedSlice() catch return ParseError.OutOfMemory;
                        types.append(t.*) catch return ParseError.OutOfMemory;
                        current_fields = std.ArrayList(Field).init(allocator);
                    }
                    const colon_pos = std.mem.indexOf(u8, trimmed, ":") orelse continue;
                    current_type = Type{
                        .name = trimmed[0..colon_pos],
                        .fields = &[_]Field{},
                    };
                    state = .TypeItem;
                } else if (indent == 4) {
                    const colon_pos = std.mem.indexOf(u8, trimmed, ":") orelse continue;
                    const field = Field{
                        .name = trimmed[0..colon_pos],
                        .type_name = extractValue(trimmed),
                    };
                    current_fields.append(field) catch return ParseError.OutOfMemory;
                }
            },
            .Functions, .FunctionItem => {
                if (std.mem.startsWith(u8, trimmed, "- name:")) {
                    if (current_function) |*f| {
                        f.params = current_params.toOwnedSlice() catch return ParseError.OutOfMemory;
                        functions.append(f.*) catch return ParseError.OutOfMemory;
                        current_params = std.ArrayList(Field).init(allocator);
                    }
                    current_function = Function{
                        .name = extractValue(trimmed[2..]),
                        .params = &[_]Field{},
                        .returns = "void",
                    };
                    state = .FunctionItem;
                } else if (std.mem.startsWith(u8, trimmed, "params:")) {
                    const params_str = extractValue(trimmed);
                    if (params_str.len > 2 and params_str[0] == '{') {
                        const inner = params_str[1 .. params_str.len - 1];
                        var param_iter = std.mem.splitSequence(u8, inner, ", ");
                        while (param_iter.next()) |param| {
                            const colon = std.mem.indexOf(u8, param, ":") orelse continue;
                            const field = Field{
                                .name = std.mem.trim(u8, param[0..colon], " "),
                                .type_name = std.mem.trim(u8, param[colon + 1 ..], " "),
                            };
                            current_params.append(field) catch return ParseError.OutOfMemory;
                        }
                    }
                } else if (std.mem.startsWith(u8, trimmed, "returns:")) {
                    if (current_function) |*f| f.returns = extractValue(trimmed);
                }
            },
            .Imports => {
                if (std.mem.startsWith(u8, trimmed, "- ")) {
                    imports.append(trimmed[2..]) catch return ParseError.OutOfMemory;
                }
            },
        }

    }

    // Save remaining items
    if (current_behavior) |*b| {
        b.test_cases = current_test_cases.toOwnedSlice() catch return ParseError.OutOfMemory;
        behaviors.append(b.*) catch return ParseError.OutOfMemory;
    }
    if (current_type) |*t| {
        t.fields = current_fields.toOwnedSlice() catch return ParseError.OutOfMemory;
        types.append(t.*) catch return ParseError.OutOfMemory;
    }
    if (current_function) |*f| {
        f.params = current_params.toOwnedSlice() catch return ParseError.OutOfMemory;
        functions.append(f.*) catch return ParseError.OutOfMemory;
    }

    spec.behaviors = behaviors.toOwnedSlice() catch return ParseError.OutOfMemory;
    spec.types = types.toOwnedSlice() catch return ParseError.OutOfMemory;
    spec.functions = functions.toOwnedSlice() catch return ParseError.OutOfMemory;
    spec.imports = imports.toOwnedSlice() catch return ParseError.OutOfMemory;

    return spec;
}

fn extractValue(line: []const u8) []const u8 {
    const colon_pos = std.mem.indexOf(u8, line, ":") orelse return "";
    const value = std.mem.trim(u8, line[colon_pos + 1 ..], " \t\"'");
    return value;
}

fn getIndent(line: []const u8) usize {
    var count: usize = 0;
    for (line) |c| {
        if (c == ' ') count += 1 else break;
    }
    return count;
}

// ============================================================================
// Tests
// ============================================================================

test "parse simple spec" {
    const content =
        \\name: test
        \\version: "1.0.0"
        \\language: zig
        \\module: test_module
        \\
        \\behaviors:
        \\  - name: test_behavior
        \\    given: Input provided
        \\    when: Function called
        \\    then: Result returned
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expectEqualStrings("test", spec.name);
    try std.testing.expectEqualStrings("zig", spec.language);
    try std.testing.expect(spec.behaviors.len == 1);
}

test "parse multiple behaviors" {
    const content =
        \\name: multi
        \\version: "1.0.0"
        \\language: zig
        \\module: multi
        \\
        \\behaviors:
        \\  - name: first
        \\    given: A
        \\    when: B
        \\    then: C
        \\  - name: second
        \\    given: X
        \\    when: Y
        \\    then: Z
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(spec.behaviors.len == 2);
}

test "parse functions" {
    const content =
        \\name: funcs
        \\version: "1.0.0"
        \\language: zig
        \\module: funcs
        \\
        \\functions:
        \\  - name: add
        \\    params: {a: int, b: int}
        \\    returns: int
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(spec.functions.len == 1);
    try std.testing.expectEqualStrings("add", spec.functions[0].name);
}

test "parse imports" {
    const content =
        \\name: imports_test
        \\version: "1.0.0"
        \\language: zig
        \\module: imports_test
        \\
        \\imports:
        \\  - std
        \\  - std.time
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(spec.imports.len == 2);
}
