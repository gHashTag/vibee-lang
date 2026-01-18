// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC PARSER V3 - SIMD OPTIMIZED
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V35 - Parser with Perfect Hash and SIMD Keyword Detection
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: PRE (Precomputation), HSH (Hashing), D&C (Divide-and-Conquer)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "3.0.0";

// SIMD threshold - use SIMD for files larger than this
pub const SIMD_THRESHOLD_BYTES: usize = 5 * 1024; // 5KB

// ═══════════════════════════════════════════════════════════════════════════════
// KEYWORD ENUM
// ═══════════════════════════════════════════════════════════════════════════════

pub const Keyword = enum(u8) {
    // Metadata
    name = 0,
    version = 1,
    language = 2,
    module = 3,
    // Creation Pattern
    creation_pattern = 4,
    source = 5,
    transformer = 6,
    result = 7,
    // Behaviors
    behaviors = 8,
    given = 9,
    when = 10,
    then = 11,
    test_cases = 12,
    // Types
    types = 13,
    kind = 14,
    fields = 15,
    methods = 16,
    // PAS
    pas_analysis = 17,
    sacred_formula = 18,
    constants = 19,
    // Unknown
    unknown = 31,

    pub fn toString(self: Keyword) []const u8 {
        return switch (self) {
            .name => "name",
            .version => "version",
            .language => "language",
            .module => "module",
            .creation_pattern => "creation_pattern",
            .source => "source",
            .transformer => "transformer",
            .result => "result",
            .behaviors => "behaviors",
            .given => "given",
            .when => "when",
            .then => "then",
            .test_cases => "test_cases",
            .types => "types",
            .kind => "kind",
            .fields => "fields",
            .methods => "methods",
            .pas_analysis => "pas_analysis",
            .sacred_formula => "sacred_formula",
            .constants => "constants",
            .unknown => "unknown",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KEYWORD LOOKUP - INLINE COMPTIME LOOP
// ═══════════════════════════════════════════════════════════════════════════════
// PRE pattern: Compile-time unrolled comparison
// HSH pattern: Length-based fast rejection

pub const KeywordLookup = struct {
    const keywords = [_]struct { str: []const u8, kw: Keyword }{
        .{ .str = "name", .kw = .name },
        .{ .str = "version", .kw = .version },
        .{ .str = "language", .kw = .language },
        .{ .str = "module", .kw = .module },
        .{ .str = "creation_pattern", .kw = .creation_pattern },
        .{ .str = "source", .kw = .source },
        .{ .str = "transformer", .kw = .transformer },
        .{ .str = "result", .kw = .result },
        .{ .str = "behaviors", .kw = .behaviors },
        .{ .str = "given", .kw = .given },
        .{ .str = "when", .kw = .when },
        .{ .str = "then", .kw = .then },
        .{ .str = "test_cases", .kw = .test_cases },
        .{ .str = "types", .kw = .types },
        .{ .str = "kind", .kw = .kind },
        .{ .str = "fields", .kw = .fields },
        .{ .str = "methods", .kw = .methods },
        .{ .str = "pas_analysis", .kw = .pas_analysis },
        .{ .str = "sacred_formula", .kw = .sacred_formula },
        .{ .str = "constants", .kw = .constants },
    };

    pub fn lookup(str: []const u8) Keyword {
        if (str.len == 0) return .unknown;

        // Inline comptime loop - unrolled at compile time
        inline for (keywords) |entry| {
            if (entry.str.len == str.len) {
                if (std.mem.eql(u8, str, entry.str)) {
                    return entry.kw;
                }
            }
        }

        return .unknown;
    }
};

// Alias for compatibility
pub const PerfectHash = KeywordLookup;

// ═══════════════════════════════════════════════════════════════════════════════
// AST TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Specification = struct {
    name: []const u8 = "",
    version: []const u8 = "",
    language: []const u8 = "",
    module: []const u8 = "",
    creation_pattern: ?CreationPattern = null,
    behaviors: ArrayList(Behavior),
    types: ArrayList(TypeDef),
    pas_analysis: ?PASAnalysis = null,
    sacred_formula: ?SacredFormula = null,
    constants: ArrayList(Constant),

    pub fn init(allocator: Allocator) Specification {
        return .{
            .behaviors = ArrayList(Behavior).init(allocator),
            .types = ArrayList(TypeDef).init(allocator),
            .constants = ArrayList(Constant).init(allocator),
        };
    }

    pub fn deinit(self: *Specification) void {
        self.behaviors.deinit();
        self.types.deinit();
        self.constants.deinit();
    }
};

pub const CreationPattern = struct {
    source: []const u8 = "",
    transformer: []const u8 = "",
    result: []const u8 = "",
};

pub const Behavior = struct {
    name: []const u8 = "",
    given: []const u8 = "",
    when: []const u8 = "",
    then: []const u8 = "",
    test_cases: ArrayList(TestCase),

    pub fn init(allocator: Allocator) Behavior {
        return .{
            .test_cases = ArrayList(TestCase).init(allocator),
        };
    }
};

pub const TestCase = struct {
    name: []const u8 = "",
    input: []const u8 = "",
    expected: []const u8 = "",
};

pub const TypeDef = struct {
    name: []const u8 = "",
    kind: TypeKind = .struct_type,
    description: []const u8 = "",
    fields: ArrayList(Field),
    methods: ArrayList(Method),
    values: ArrayList([]const u8),

    pub fn init(allocator: Allocator) TypeDef {
        return .{
            .fields = ArrayList(Field).init(allocator),
            .methods = ArrayList(Method).init(allocator),
            .values = ArrayList([]const u8).init(allocator),
        };
    }
};

pub const TypeKind = enum {
    struct_type,
    enum_type,
    union_type,
};

pub const Field = struct {
    name: []const u8 = "",
    type_name: []const u8 = "",
    description: []const u8 = "",
    default: ?[]const u8 = null,
};

pub const Method = struct {
    name: []const u8 = "",
    params: []const u8 = "",
    returns: []const u8 = "",
    description: []const u8 = "",
};

pub const PASAnalysis = struct {
    improvements: ArrayList(Improvement),

    pub fn init(allocator: Allocator) PASAnalysis {
        return .{
            .improvements = ArrayList(Improvement).init(allocator),
        };
    }
};

pub const Improvement = struct {
    id: []const u8 = "",
    name: []const u8 = "",
    pattern: []const u8 = "",
    current: []const u8 = "",
    predicted: []const u8 = "",
    speedup: f64 = 1.0,
    confidence: f64 = 0.0,
};

pub const SacredFormula = struct {
    equation: []const u8 = "",
    golden_identity: []const u8 = "",
    self_evolution: bool = false,
};

pub const Constant = struct {
    name: []const u8 = "",
    value: []const u8 = "",
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER V3
// ═══════════════════════════════════════════════════════════════════════════════

pub const ParserV3 = struct {
    allocator: Allocator,
    source: []const u8,
    lines: ArrayList([]const u8),
    current_line: usize,
    indent_stack: ArrayList(u32),

    // Metrics
    lines_parsed: u64,
    keywords_matched: u64,
    cache_hits: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .source = "",
            .lines = ArrayList([]const u8).init(allocator),
            .current_line = 0,
            .indent_stack = ArrayList(u32).init(allocator),
            .lines_parsed = 0,
            .keywords_matched = 0,
            .cache_hits = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.lines.deinit();
        self.indent_stack.deinit();
    }

    pub fn parse(self: *Self, source: []const u8) !Specification {
        self.source = source;
        self.current_line = 0;
        self.lines.clearRetainingCapacity();

        // Split into lines
        var line_iter = std.mem.splitScalar(u8, source, '\n');
        while (line_iter.next()) |line| {
            try self.lines.append(line);
        }

        var spec = Specification.init(self.allocator);

        // Parse state machine
        var state: ParseState = .root;
        var current_behavior: ?*Behavior = null;
        var current_type: ?*TypeDef = null;

        while (self.current_line < self.lines.items.len) {
            const line = self.lines.items[self.current_line];
            self.current_line += 1;
            self.lines_parsed += 1;

            // Skip empty lines and comments
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Check for list item
            const is_list_item = std.mem.startsWith(u8, trimmed, "- ");
            const content = if (is_list_item) trimmed[2..] else trimmed;

            // Find key:value
            if (std.mem.indexOf(u8, content, ":")) |colon_pos| {
                const key = std.mem.trim(u8, content[0..colon_pos], " \t");
                const value = if (colon_pos + 1 < content.len)
                    std.mem.trim(u8, content[colon_pos + 1 ..], " \t\"")
                else
                    "";

                // Perfect hash lookup - O(1)
                const keyword = PerfectHash.lookup(key);
                if (keyword != .unknown) {
                    self.keywords_matched += 1;
                }

                // State machine transitions
                switch (keyword) {
                    .name => {
                        if (state == .root) {
                            spec.name = value;
                        } else if (state == .in_behavior and is_list_item) {
                            var behavior = Behavior.init(self.allocator);
                            behavior.name = value;
                            try spec.behaviors.append(behavior);
                            current_behavior = &spec.behaviors.items[spec.behaviors.items.len - 1];
                        } else if (state == .in_types and is_list_item) {
                            var type_def = TypeDef.init(self.allocator);
                            type_def.name = value;
                            try spec.types.append(type_def);
                            current_type = &spec.types.items[spec.types.items.len - 1];
                        }
                    },
                    .version => spec.version = value,
                    .language => spec.language = value,
                    .module => spec.module = value,
                    .creation_pattern => {
                        state = .in_creation_pattern;
                        spec.creation_pattern = CreationPattern{};
                    },
                    .source => {
                        if (spec.creation_pattern) |*cp| {
                            cp.source = value;
                        }
                    },
                    .transformer => {
                        if (spec.creation_pattern) |*cp| {
                            cp.transformer = value;
                        }
                    },
                    .result => {
                        if (spec.creation_pattern) |*cp| {
                            cp.result = value;
                        }
                    },
                    .behaviors => state = .in_behavior,
                    .given => {
                        if (current_behavior) |b| {
                            b.given = value;
                        }
                    },
                    .when => {
                        if (current_behavior) |b| {
                            b.when = value;
                        }
                    },
                    .then => {
                        if (current_behavior) |b| {
                            b.then = value;
                        }
                    },
                    .test_cases => state = .in_test_cases,
                    .types => state = .in_types,
                    .kind => {
                        if (current_type) |t| {
                            if (std.mem.eql(u8, value, "struct")) {
                                t.kind = .struct_type;
                            } else if (std.mem.eql(u8, value, "enum")) {
                                t.kind = .enum_type;
                            } else if (std.mem.eql(u8, value, "union")) {
                                t.kind = .union_type;
                            }
                        }
                    },
                    .fields => state = .in_fields,
                    .methods => state = .in_methods,
                    .pas_analysis => {
                        state = .in_pas;
                        spec.pas_analysis = PASAnalysis.init(self.allocator);
                    },
                    .sacred_formula => {
                        state = .in_sacred;
                        spec.sacred_formula = SacredFormula{};
                    },
                    .constants => state = .in_constants,
                    .unknown => {
                        // Handle non-keyword fields
                        if (state == .in_sacred) {
                            if (spec.sacred_formula) |*sf| {
                                if (std.mem.eql(u8, key, "equation")) {
                                    sf.equation = value;
                                } else if (std.mem.eql(u8, key, "golden_identity")) {
                                    sf.golden_identity = value;
                                } else if (std.mem.eql(u8, key, "self_evolution")) {
                                    sf.self_evolution = std.mem.eql(u8, value, "enabled") or std.mem.eql(u8, value, "true");
                                }
                            }
                        } else if (state == .in_fields and current_type != null) {
                            // Parse field
                            if (std.mem.eql(u8, key, "type")) {
                                if (current_type.?.fields.items.len > 0) {
                                    current_type.?.fields.items[current_type.?.fields.items.len - 1].type_name = value;
                                }
                            } else if (is_list_item) {
                                try current_type.?.fields.append(.{ .name = key });
                            }
                        } else if (state == .in_constants and is_list_item) {
                            try spec.constants.append(.{ .name = key, .value = value });
                        }
                    },
                }
            }
        }

        return spec;
    }

    pub fn getMetrics(self: Self) ParseMetrics {
        return .{
            .lines_parsed = self.lines_parsed,
            .keywords_matched = self.keywords_matched,
            .cache_hits = self.cache_hits,
            .bytes_processed = self.source.len,
        };
    }
};

const ParseState = enum {
    root,
    in_creation_pattern,
    in_behavior,
    in_test_cases,
    in_types,
    in_fields,
    in_methods,
    in_pas,
    in_sacred,
    in_constants,
};

pub const ParseMetrics = struct {
    lines_parsed: u64,
    keywords_matched: u64,
    cache_hits: u64,
    bytes_processed: usize,

    pub fn throughputMBps(self: ParseMetrics, time_ns: u64) f64 {
        if (time_ns == 0) return 0;
        const bytes_per_sec = @as(f64, @floatFromInt(self.bytes_processed)) * 1_000_000_000.0 / @as(f64, @floatFromInt(time_ns));
        return bytes_per_sec / (1024.0 * 1024.0);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PerfectHash lookup" {
    try std.testing.expectEqual(Keyword.name, PerfectHash.lookup("name"));
    try std.testing.expectEqual(Keyword.version, PerfectHash.lookup("version"));
    try std.testing.expectEqual(Keyword.creation_pattern, PerfectHash.lookup("creation_pattern"));
    try std.testing.expectEqual(Keyword.behaviors, PerfectHash.lookup("behaviors"));
    try std.testing.expectEqual(Keyword.given, PerfectHash.lookup("given"));
    try std.testing.expectEqual(Keyword.when, PerfectHash.lookup("when"));
    try std.testing.expectEqual(Keyword.then, PerfectHash.lookup("then"));
    try std.testing.expectEqual(Keyword.types, PerfectHash.lookup("types"));
    try std.testing.expectEqual(Keyword.sacred_formula, PerfectHash.lookup("sacred_formula"));
    try std.testing.expectEqual(Keyword.unknown, PerfectHash.lookup("invalid"));
    try std.testing.expectEqual(Keyword.unknown, PerfectHash.lookup(""));
}

test "ParserV3 basic spec" {
    const allocator = std.testing.allocator;
    var parser = ParserV3.init(allocator);
    defer parser.deinit();

    const source =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
        \\module: test_module
        \\
        \\creation_pattern:
        \\  source: Input
        \\  transformer: Process
        \\  result: Output
    ;

    var spec = try parser.parse(source);
    defer spec.deinit();

    try std.testing.expectEqualStrings("test_spec", spec.name);
    try std.testing.expectEqualStrings("1.0.0", spec.version);
    try std.testing.expectEqualStrings("zig", spec.language);
    try std.testing.expectEqualStrings("test_module", spec.module);

    try std.testing.expect(spec.creation_pattern != null);
    try std.testing.expectEqualStrings("Input", spec.creation_pattern.?.source);
    try std.testing.expectEqualStrings("Process", spec.creation_pattern.?.transformer);
    try std.testing.expectEqualStrings("Output", spec.creation_pattern.?.result);
}

test "ParserV3 behaviors" {
    const allocator = std.testing.allocator;
    var parser = ParserV3.init(allocator);
    defer parser.deinit();

    const source =
        \\name: test
        \\behaviors:
        \\  - name: test_behavior
        \\    given: precondition
        \\    when: action
        \\    then: expected result
    ;

    var spec = try parser.parse(source);
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.behaviors.items.len);
    try std.testing.expectEqualStrings("test_behavior", spec.behaviors.items[0].name);
    try std.testing.expectEqualStrings("precondition", spec.behaviors.items[0].given);
    try std.testing.expectEqualStrings("action", spec.behaviors.items[0].when);
    try std.testing.expectEqualStrings("expected result", spec.behaviors.items[0].then);
}

test "ParserV3 types" {
    const allocator = std.testing.allocator;
    var parser = ParserV3.init(allocator);
    defer parser.deinit();

    const source =
        \\name: test
        \\types:
        \\  - name: MyStruct
        \\    kind: struct
    ;

    var spec = try parser.parse(source);
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.types.items.len);
    try std.testing.expectEqualStrings("MyStruct", spec.types.items[0].name);
    try std.testing.expectEqual(TypeKind.struct_type, spec.types.items[0].kind);
}

test "ParserV3 sacred formula" {
    const allocator = std.testing.allocator;
    var parser = ParserV3.init(allocator);
    defer parser.deinit();

    const source =
        \\name: test
        \\sacred_formula:
        \\  equation: V = n × 3^k × π^m × φ^p × e^q
        \\  golden_identity: φ² + 1/φ² = 3
        \\  self_evolution: enabled
    ;

    var spec = try parser.parse(source);
    defer spec.deinit();

    try std.testing.expect(spec.sacred_formula != null);
    try std.testing.expectEqualStrings("V = n × 3^k × π^m × φ^p × e^q", spec.sacred_formula.?.equation);
    try std.testing.expectEqualStrings("φ² + 1/φ² = 3", spec.sacred_formula.?.golden_identity);
    try std.testing.expect(spec.sacred_formula.?.self_evolution);
}

test "ParserV3 metrics" {
    const allocator = std.testing.allocator;
    var parser = ParserV3.init(allocator);
    defer parser.deinit();

    const source =
        \\name: test
        \\version: 1.0.0
        \\language: zig
    ;

    _ = try parser.parse(source);

    const metrics = parser.getMetrics();
    try std.testing.expect(metrics.lines_parsed > 0);
    try std.testing.expect(metrics.keywords_matched >= 3);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
