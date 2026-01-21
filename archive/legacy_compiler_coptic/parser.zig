// VIBEEC Parser - Parses .vibee YAML specifications
// Supports full Given/When/Then behavioral format
// Enhanced with Creation Pattern support from mathematical experiments

const std = @import("std");

// ============================================================================
// CREATION PATTERN TYPES (from Collatz/Goldbach/TwinPrimes experiments)
// ============================================================================

/// Iteration strategy for transformers
pub const IterationType = enum {
    single, // Apply transformer once
    until_fixed_point, // Apply until value stops changing
    until_condition, // Apply until condition is met
    bounded, // Apply up to max_steps times
    infinite, // Generate infinite stream (lazy)

    pub fn fromString(s: []const u8) ?IterationType {
        if (std.mem.eql(u8, s, "single")) return .single;
        if (std.mem.eql(u8, s, "until_fixed_point")) return .until_fixed_point;
        if (std.mem.eql(u8, s, "until_condition")) return .until_condition;
        if (std.mem.eql(u8, s, "bounded")) return .bounded;
        if (std.mem.eql(u8, s, "infinite")) return .infinite;
        return null;
    }
};

/// Transformer classification (from experiment patterns)
pub const TransformerType = enum {
    pure, // f(x) -> y, no side effects (Collatz step)
    iterative, // f^n(x) until condition (Collatz sequence)
    filter, // f(x) -> bool, select matching (Twin primes)
    mapping, // f(x, y) -> z, combine inputs (Goldbach)
    generator, // () -> Stream<T>, produce values (Prime sieve)

    pub fn fromString(s: []const u8) ?TransformerType {
        if (std.mem.eql(u8, s, "pure")) return .pure;
        if (std.mem.eql(u8, s, "iterative")) return .iterative;
        if (std.mem.eql(u8, s, "filter")) return .filter;
        if (std.mem.eql(u8, s, "mapping")) return .mapping;
        if (std.mem.eql(u8, s, "generator")) return .generator;
        return null;
    }
};

/// Creation Pattern: Source → Transformer → Result
pub const CreationPattern = struct {
    source: []const u8, // Input type/domain
    transformer: []const u8, // Function name
    result: []const u8, // Output type/target
    iteration: IterationType, // How to apply transformer
    condition: []const u8, // Stop condition (for iterative)
    max_steps: usize, // Maximum iterations (for bounded)
};

/// Transformer definition with type classification
pub const Transformer = struct {
    name: []const u8,
    transformer_type: TransformerType,
    input: []const u8,
    output: []const u8,
    rule: []const u8, // Transformation rule/logic
};

/// Test generation configuration
pub const TestGeneration = struct {
    boundary: bool, // Generate edge case tests
    stress: bool, // Generate stress tests
    property: bool, // Generate property-based tests
    stress_limits: []usize, // Stress test limits [1000, 10000, ...]
    coverage_target: usize, // Target coverage percentage
};

/// Type constraint for constrained types
pub const TypeConstraint = struct {
    base_type: []const u8,
    constraint: []const u8, // e.g., "> 0", "% 2 == 0", "is_prime"
};

/// State variable for JS modules
pub const StateVar = struct {
    name: []const u8,
    type_name: []const u8,
    default_value: []const u8,
};

/// Method definition for JS modules
pub const Method = struct {
    name: []const u8,
    params: []const u8,
    body: []const u8,
};

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
    // New Creation Pattern fields
    creation_pattern: ?CreationPattern,
    transformers: []Transformer,
    test_generation: ?TestGeneration,
    // JS Module fields
    source: ?[]const u8, // arXiv reference
    pas_patterns: ?[]const u8, // PAS patterns applied
    benefit: ?[]const u8, // Practical benefit
    emoji: ?[]const u8, // Module emoji
    keyboard_shortcut: ?[]const u8, // Keyboard shortcut
    state: ?[]StateVar, // State variables
    methods: ?[]Method, // Methods
    init_body: ?[]const u8, // Init function body
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
        self.allocator.free(self.transformers);
        if (self.test_generation) |tg| {
            self.allocator.free(tg.stress_limits);
        }
        if (self.state) |s| {
            self.allocator.free(s);
        }
        if (self.methods) |m| {
            self.allocator.free(m);
        }
    }

    /// Check if spec uses Creation Pattern
    pub fn hasCreationPattern(self: *const Spec) bool {
        return self.creation_pattern != null;
    }

    /// Get transformer type for a behavior
    pub fn getTransformerType(self: *const Spec, name: []const u8) ?TransformerType {
        for (self.transformers) |t| {
            if (std.mem.eql(u8, t.name, name)) {
                return t.transformer_type;
            }
        }
        return null;
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
    // New states for Creation Pattern
    CreationPattern,
    Transformers,
    TransformerItem,
    TestGeneration,
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
        // New Creation Pattern fields
        .creation_pattern = null,
        .transformers = &[_]Transformer{},
        .test_generation = null,
        // JS Module fields
        .source = null,
        .pas_patterns = null,
        .benefit = null,
        .emoji = null,
        .keyboard_shortcut = null,
        .state = null,
        .methods = null,
        .init_body = null,
        .allocator = allocator,
    };

    var behaviors = std.ArrayList(Behavior).init(allocator);
    var types = std.ArrayList(Type).init(allocator);
    var functions = std.ArrayList(Function).init(allocator);
    var imports = std.ArrayList([]const u8).init(allocator);
    var transformers = std.ArrayList(Transformer).init(allocator);

    // Creation pattern parsing state
    var current_creation_pattern: ?CreationPattern = null;
    var current_transformer: ?Transformer = null;
    var current_test_gen: ?TestGeneration = null;
    var stress_limits = std.ArrayList(usize).init(allocator);

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
        } else if (std.mem.startsWith(u8, trimmed, "creation_pattern:")) {
            // New: Parse Creation Pattern block
            current_creation_pattern = CreationPattern{
                .source = "",
                .transformer = "",
                .result = "",
                .iteration = .single,
                .condition = "",
                .max_steps = 10000,
            };
            state = .CreationPattern;
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "transformers:")) {
            // New: Parse Transformers block
            state = .Transformers;
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "test_generation:")) {
            // New: Parse Test Generation config
            current_test_gen = TestGeneration{
                .boundary = false,
                .stress = false,
                .property = false,
                .stress_limits = &[_]usize{},
                .coverage_target = 80,
            };
            state = .TestGeneration;
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
                } else if (std.mem.startsWith(u8, trimmed, "source:")) {
                    spec.source = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "pas_patterns:")) {
                    spec.pas_patterns = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "benefit:")) {
                    spec.benefit = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "emoji:")) {
                    spec.emoji = extractValue(trimmed);
                } else if (std.mem.startsWith(u8, trimmed, "keyboard_shortcut:")) {
                    spec.keyboard_shortcut = extractValue(trimmed);
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
            // New: Creation Pattern parsing
            .CreationPattern => {
                if (current_creation_pattern) |*cp| {
                    if (std.mem.startsWith(u8, trimmed, "source:")) {
                        cp.source = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "transformer:")) {
                        cp.transformer = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "result:")) {
                        cp.result = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "iteration:")) {
                        const iter_str = extractValue(trimmed);
                        cp.iteration = IterationType.fromString(iter_str) orelse .single;
                    } else if (std.mem.startsWith(u8, trimmed, "condition:")) {
                        cp.condition = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "max_steps:")) {
                        const steps_str = extractValue(trimmed);
                        cp.max_steps = std.fmt.parseInt(usize, steps_str, 10) catch 10000;
                    }
                }
            },
            // New: Transformers parsing
            .Transformers, .TransformerItem => {
                if (std.mem.startsWith(u8, trimmed, "- name:")) {
                    if (current_transformer) |t| {
                        transformers.append(t) catch return ParseError.OutOfMemory;
                    }
                    current_transformer = Transformer{
                        .name = extractValue(trimmed[2..]),
                        .transformer_type = .pure,
                        .input = "",
                        .output = "",
                        .rule = "",
                    };
                    state = .TransformerItem;
                } else if (current_transformer) |*t| {
                    if (std.mem.startsWith(u8, trimmed, "type:")) {
                        const type_str = extractValue(trimmed);
                        t.transformer_type = TransformerType.fromString(type_str) orelse .pure;
                    } else if (std.mem.startsWith(u8, trimmed, "input:")) {
                        t.input = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "output:")) {
                        t.output = extractValue(trimmed);
                    } else if (std.mem.startsWith(u8, trimmed, "rule:")) {
                        t.rule = extractValue(trimmed);
                    }
                }
            },
            // New: Test Generation parsing
            .TestGeneration => {
                if (current_test_gen) |*tg| {
                    if (std.mem.startsWith(u8, trimmed, "boundary:")) {
                        const val = extractValue(trimmed);
                        tg.boundary = std.mem.eql(u8, val, "true");
                    } else if (std.mem.startsWith(u8, trimmed, "stress:")) {
                        const val = extractValue(trimmed);
                        tg.stress = std.mem.eql(u8, val, "true");
                    } else if (std.mem.startsWith(u8, trimmed, "property:")) {
                        const val = extractValue(trimmed);
                        tg.property = std.mem.eql(u8, val, "true");
                    } else if (std.mem.startsWith(u8, trimmed, "coverage:")) {
                        const val = extractValue(trimmed);
                        tg.coverage_target = std.fmt.parseInt(usize, val, 10) catch 80;
                    } else if (std.mem.startsWith(u8, trimmed, "- ")) {
                        // Parse stress limits array
                        const limit_str = trimmed[2..];
                        const limit = std.fmt.parseInt(usize, limit_str, 10) catch continue;
                        stress_limits.append(limit) catch return ParseError.OutOfMemory;
                    }
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
    // Save new Creation Pattern items
    if (current_transformer) |t| {
        transformers.append(t) catch return ParseError.OutOfMemory;
    }
    if (current_test_gen) |*tg| {
        tg.stress_limits = stress_limits.toOwnedSlice() catch return ParseError.OutOfMemory;
    }

    spec.behaviors = behaviors.toOwnedSlice() catch return ParseError.OutOfMemory;
    spec.types = types.toOwnedSlice() catch return ParseError.OutOfMemory;
    spec.functions = functions.toOwnedSlice() catch return ParseError.OutOfMemory;
    spec.imports = imports.toOwnedSlice() catch return ParseError.OutOfMemory;
    // Assign new fields
    spec.creation_pattern = current_creation_pattern;
    spec.transformers = transformers.toOwnedSlice() catch return ParseError.OutOfMemory;
    spec.test_generation = current_test_gen;

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

// ============================================================================
// Creation Pattern Tests (from mathematical experiments)
// ============================================================================

test "parse creation pattern" {
    const content =
        \\name: collatz_test
        \\version: "1.0.0"
        \\language: zig
        \\module: collatz
        \\
        \\creation_pattern:
        \\  source: PositiveInteger
        \\  transformer: collatz_step
        \\  result: One
        \\  iteration: until_condition
        \\  condition: equals(1)
        \\  max_steps: 10000
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(spec.creation_pattern != null);
    const cp = spec.creation_pattern.?;
    try std.testing.expectEqualStrings("PositiveInteger", cp.source);
    try std.testing.expectEqualStrings("collatz_step", cp.transformer);
    try std.testing.expectEqualStrings("One", cp.result);
    try std.testing.expect(cp.iteration == .until_condition);
    try std.testing.expectEqualStrings("equals(1)", cp.condition);
    try std.testing.expect(cp.max_steps == 10000);
}

test "parse transformers" {
    const content =
        \\name: transformer_test
        \\version: "1.0.0"
        \\language: zig
        \\module: transformers
        \\
        \\transformers:
        \\  - name: collatz_step
        \\    type: pure
        \\    input: u64
        \\    output: u64
        \\  - name: twin_filter
        \\    type: filter
        \\    input: Prime
        \\    output: bool
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(spec.transformers.len == 2);
    try std.testing.expectEqualStrings("collatz_step", spec.transformers[0].name);
    try std.testing.expect(spec.transformers[0].transformer_type == .pure);
    try std.testing.expectEqualStrings("twin_filter", spec.transformers[1].name);
    try std.testing.expect(spec.transformers[1].transformer_type == .filter);
}

test "parse test generation config" {
    const content =
        \\name: testgen_test
        \\version: "1.0.0"
        \\language: zig
        \\module: testgen
        \\
        \\test_generation:
        \\  boundary: true
        \\  stress: true
        \\  property: false
        \\  coverage: 90
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(spec.test_generation != null);
    const tg = spec.test_generation.?;
    try std.testing.expect(tg.boundary == true);
    try std.testing.expect(tg.stress == true);
    try std.testing.expect(tg.property == false);
    try std.testing.expect(tg.coverage_target == 90);
}

test "iteration type from string" {
    try std.testing.expect(IterationType.fromString("single") == .single);
    try std.testing.expect(IterationType.fromString("until_fixed_point") == .until_fixed_point);
    try std.testing.expect(IterationType.fromString("until_condition") == .until_condition);
    try std.testing.expect(IterationType.fromString("bounded") == .bounded);
    try std.testing.expect(IterationType.fromString("infinite") == .infinite);
    try std.testing.expect(IterationType.fromString("unknown") == null);
}

test "transformer type from string" {
    try std.testing.expect(TransformerType.fromString("pure") == .pure);
    try std.testing.expect(TransformerType.fromString("iterative") == .iterative);
    try std.testing.expect(TransformerType.fromString("filter") == .filter);
    try std.testing.expect(TransformerType.fromString("mapping") == .mapping);
    try std.testing.expect(TransformerType.fromString("generator") == .generator);
    try std.testing.expect(TransformerType.fromString("unknown") == null);
}

test "spec has creation pattern" {
    const content =
        \\name: pattern_test
        \\version: "1.0.0"
        \\language: zig
        \\module: pattern
        \\
        \\creation_pattern:
        \\  source: Input
        \\  transformer: transform
        \\  result: Output
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(spec.hasCreationPattern());
}

test "spec without creation pattern" {
    const content =
        \\name: no_pattern_test
        \\version: "1.0.0"
        \\language: zig
        \\module: no_pattern
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expect(!spec.hasCreationPattern());
}
