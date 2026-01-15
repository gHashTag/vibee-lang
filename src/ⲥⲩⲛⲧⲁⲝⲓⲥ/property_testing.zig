// Property-Based Testing Generator for VIBEE
// Based on QuickCheck (Claessen & Hughes, 2000)
// Part of PAS Phase 1 implementation

const std = @import("std");
const parser = @import("parser.zig");

// ============================================================================
// RANDOM GENERATORS
// ============================================================================

pub const Generator = struct {
    random: std.Random,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, seed: u64) Generator {
        var prng = std.Random.DefaultPrng.init(seed);
        return .{
            .random = prng.random(),
            .allocator = allocator,
        };
    }

    /// Generate random integer in range
    pub fn int(self: *Generator, comptime T: type, min: T, max: T) T {
        return self.random.intRangeAtMost(T, min, max);
    }

    /// Generate random boolean
    pub fn boolean(self: *Generator) bool {
        return self.random.boolean();
    }

    /// Generate random float
    pub fn float(self: *Generator, min: f64, max: f64) f64 {
        return min + self.random.float(f64) * (max - min);
    }

    /// Generate random string of given length
    pub fn string(self: *Generator, min_len: usize, max_len: usize) ![]u8 {
        const len = self.random.intRangeAtMost(usize, min_len, max_len);
        const buf = try self.allocator.alloc(u8, len);
        
        for (buf) |*c| {
            // Generate printable ASCII
            c.* = @intCast(self.random.intRangeAtMost(u8, 32, 126));
        }
        
        return buf;
    }

    /// Generate random alphanumeric string
    pub fn alphanumeric(self: *Generator, min_len: usize, max_len: usize) ![]u8 {
        const len = self.random.intRangeAtMost(usize, min_len, max_len);
        const buf = try self.allocator.alloc(u8, len);
        
        const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        
        for (buf) |*c| {
            c.* = chars[self.random.intRangeAtMost(usize, 0, chars.len - 1)];
        }
        
        return buf;
    }

    /// Generate random YAML-safe identifier
    pub fn identifier(self: *Generator) ![]u8 {
        const len = self.random.intRangeAtMost(usize, 1, 20);
        const buf = try self.allocator.alloc(u8, len);
        
        const first_chars = "abcdefghijklmnopqrstuvwxyz_";
        const rest_chars = "abcdefghijklmnopqrstuvwxyz0123456789_";
        
        buf[0] = first_chars[self.random.intRangeAtMost(usize, 0, first_chars.len - 1)];
        
        for (buf[1..]) |*c| {
            c.* = rest_chars[self.random.intRangeAtMost(usize, 0, rest_chars.len - 1)];
        }
        
        return buf;
    }

    /// Generate random array of given type
    pub fn array(self: *Generator, comptime T: type, min_len: usize, max_len: usize, gen_elem: *const fn (*Generator) T) ![]T {
        const len = self.random.intRangeAtMost(usize, min_len, max_len);
        const buf = try self.allocator.alloc(T, len);
        
        for (buf) |*elem| {
            elem.* = gen_elem(self);
        }
        
        return buf;
    }

    /// Choose random element from slice
    pub fn oneOf(self: *Generator, comptime T: type, choices: []const T) T {
        const idx = self.random.intRangeAtMost(usize, 0, choices.len - 1);
        return choices[idx];
    }
};

// ============================================================================
// SHRINKING
// ============================================================================

pub const Shrinker = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Shrinker {
        return .{ .allocator = allocator };
    }

    /// Shrink an integer towards zero
    pub fn shrinkInt(self: *Shrinker, comptime T: type, value: T) ![]T {
        if (value == 0) return &[_]T{};
        
        var candidates = std.ArrayList(T).init(self.allocator);
        
        // Try zero
        try candidates.append(0);
        
        // Try halving
        if (value > 0) {
            var v = value;
            while (v > 0) {
                v = @divFloor(v, 2);
                if (v != value) try candidates.append(v);
            }
        } else {
            var v = value;
            while (v < 0) {
                v = @divFloor(v, 2);
                if (v != value) try candidates.append(v);
            }
        }
        
        // Try decrementing
        if (value > 0) {
            try candidates.append(value - 1);
        } else {
            try candidates.append(value + 1);
        }
        
        return candidates.toOwnedSlice();
    }

    /// Shrink a string by removing characters
    pub fn shrinkString(self: *Shrinker, value: []const u8) ![][]const u8 {
        if (value.len == 0) return &[_][]const u8{};
        
        var candidates = std.ArrayList([]const u8).init(self.allocator);
        
        // Try empty string
        try candidates.append("");
        
        // Try removing each character
        for (0..value.len) |i| {
            var new_str = try self.allocator.alloc(u8, value.len - 1);
            @memcpy(new_str[0..i], value[0..i]);
            @memcpy(new_str[i..], value[i + 1 ..]);
            try candidates.append(new_str);
        }
        
        // Try first half
        if (value.len > 1) {
            try candidates.append(value[0 .. value.len / 2]);
        }
        
        // Try second half
        if (value.len > 1) {
            try candidates.append(value[value.len / 2 ..]);
        }
        
        return candidates.toOwnedSlice();
    }

    /// Shrink an array by removing elements
    pub fn shrinkArray(self: *Shrinker, comptime T: type, value: []const T) ![][]const T {
        if (value.len == 0) return &[_][]const T{};
        
        var candidates = std.ArrayList([]const T).init(self.allocator);
        
        // Try empty array
        try candidates.append(&[_]T{});
        
        // Try removing each element
        for (0..value.len) |i| {
            var new_arr = try self.allocator.alloc(T, value.len - 1);
            @memcpy(new_arr[0..i], value[0..i]);
            @memcpy(new_arr[i..], value[i + 1 ..]);
            try candidates.append(new_arr);
        }
        
        // Try first half
        if (value.len > 1) {
            try candidates.append(value[0 .. value.len / 2]);
        }
        
        return candidates.toOwnedSlice();
    }
};

// ============================================================================
// PROPERTY DEFINITION
// ============================================================================

pub const Property = struct {
    name: []const u8,
    predicate: *const fn (*const anyopaque) bool,
    generator: *const fn (*Generator) *anyopaque,
    shrinker: ?*const fn (*Shrinker, *const anyopaque) *anyopaque,
};

// ============================================================================
// TEST RESULT
// ============================================================================

pub const TestResult = struct {
    passed: bool,
    iterations: u32,
    counterexample: ?[]const u8,
    shrink_steps: u32,
    seed: u64,

    pub fn success(iterations: u32, seed: u64) TestResult {
        return .{
            .passed = true,
            .iterations = iterations,
            .counterexample = null,
            .shrink_steps = 0,
            .seed = seed,
        };
    }

    pub fn failure(iterations: u32, counterexample: []const u8, shrink_steps: u32, seed: u64) TestResult {
        return .{
            .passed = false,
            .iterations = iterations,
            .counterexample = counterexample,
            .shrink_steps = shrink_steps,
            .seed = seed,
        };
    }
};

// ============================================================================
// PROPERTY TESTER
// ============================================================================

pub const PropertyTester = struct {
    allocator: std.mem.Allocator,
    generator: Generator,
    shrinker: Shrinker,
    default_iterations: u32,
    seed: u64,

    pub fn init(allocator: std.mem.Allocator, seed: ?u64) PropertyTester {
        const actual_seed = seed orelse @as(u64, @intCast(std.time.milliTimestamp()));
        
        return .{
            .allocator = allocator,
            .generator = Generator.init(allocator, actual_seed),
            .shrinker = Shrinker.init(allocator),
            .default_iterations = 100,
            .seed = actual_seed,
        };
    }

    /// Check a property with integer input
    pub fn checkInt(self: *PropertyTester, comptime T: type, min: T, max: T, predicate: *const fn (T) bool) !TestResult {
        for (0..self.default_iterations) |i| {
            const value = self.generator.int(T, min, max);
            
            if (!predicate(value)) {
                // Shrink to find minimal counterexample
                const shrunk = try self.shrinkToMinimal(T, value, predicate);
                
                var buf: [64]u8 = undefined;
                const counterexample = std.fmt.bufPrint(&buf, "{}", .{shrunk.value}) catch "?";
                
                return TestResult.failure(
                    @intCast(i + 1),
                    counterexample,
                    shrunk.steps,
                    self.seed,
                );
            }
        }
        
        return TestResult.success(self.default_iterations, self.seed);
    }

    /// Check a property with string input
    pub fn checkString(self: *PropertyTester, min_len: usize, max_len: usize, predicate: *const fn ([]const u8) bool) !TestResult {
        for (0..self.default_iterations) |i| {
            const value = try self.generator.string(min_len, max_len);
            defer self.allocator.free(value);
            
            if (!predicate(value)) {
                return TestResult.failure(
                    @intCast(i + 1),
                    value,
                    0,
                    self.seed,
                );
            }
        }
        
        return TestResult.success(self.default_iterations, self.seed);
    }

    fn shrinkToMinimal(self: *PropertyTester, comptime T: type, value: T, predicate: *const fn (T) bool) !struct { value: T, steps: u32 } {
        var current = value;
        var steps: u32 = 0;
        var changed = true;
        
        while (changed) {
            changed = false;
            
            const candidates = try self.shrinker.shrinkInt(T, current);
            defer self.allocator.free(candidates);
            
            for (candidates) |candidate| {
                if (!predicate(candidate)) {
                    current = candidate;
                    steps += 1;
                    changed = true;
                    break;
                }
            }
        }
        
        return .{ .value = current, .steps = steps };
    }
};

// ============================================================================
// VIBEE SPEC GENERATOR
// ============================================================================

pub const SpecGenerator = struct {
    allocator: std.mem.Allocator,
    generator: Generator,

    pub fn init(allocator: std.mem.Allocator, seed: u64) SpecGenerator {
        return .{
            .allocator = allocator,
            .generator = Generator.init(allocator, seed),
        };
    }

    /// Generate random VIBEE specification
    pub fn generateSpec(self: *SpecGenerator) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        const writer = buf.writer();

        // Name
        const name = try self.generator.identifier();
        defer self.allocator.free(name);
        try writer.print("name: {s}\n", .{name});

        // Version
        const major = self.generator.int(u8, 0, 9);
        const minor = self.generator.int(u8, 0, 99);
        const patch = self.generator.int(u8, 0, 99);
        try writer.print("version: \"{}.{}.{}\"\n", .{ major, minor, patch });

        // Language
        const languages = [_][]const u8{ "zig", "rust", "go", "python" };
        const lang = self.generator.oneOf([]const u8, &languages);
        try writer.print("language: {s}\n", .{lang});

        // Module
        const module = try self.generator.identifier();
        defer self.allocator.free(module);
        try writer.print("module: {s}\n", .{module});

        // Behaviors
        try writer.writeAll("\nbehaviors:\n");
        
        const num_behaviors = self.generator.int(u8, 1, 5);
        for (0..num_behaviors) |_| {
            try self.generateBehavior(writer);
        }

        return buf.toOwnedSlice();
    }

    fn generateBehavior(self: *SpecGenerator, writer: anytype) !void {
        const name = try self.generator.identifier();
        defer self.allocator.free(name);
        
        try writer.print("  - name: {s}\n", .{name});
        try writer.writeAll("    given: A test precondition\n");
        try writer.writeAll("    when: An action is performed\n");
        try writer.writeAll("    then: Expected result occurs\n");
        
        // Test cases
        if (self.generator.boolean()) {
            try writer.writeAll("    test_cases:\n");
            
            const num_cases = self.generator.int(u8, 1, 3);
            for (0..num_cases) |i| {
                try writer.print("      - name: test_{}\n", .{i});
                try writer.writeAll("        input: {value: 1}\n");
                try writer.writeAll("        expected: {result: 1}\n");
            }
        }
    }

    /// Generate edge case specifications
    pub fn generateEdgeCases(self: *SpecGenerator) ![][]const u8 {
        var cases = std.ArrayList([]const u8).init(self.allocator);

        // Empty spec
        try cases.append("name: empty\nversion: \"1.0.0\"\nlanguage: zig\nmodule: empty\n");

        // Minimal spec
        try cases.append(
            \\name: minimal
            \\version: "1.0.0"
            \\language: zig
            \\module: minimal
            \\behaviors:
            \\  - name: test
            \\    given: G
            \\    when: W
            \\    then: T
        );

        // Spec with unicode
        try cases.append(
            \\name: unicode_test
            \\version: "1.0.0"
            \\language: zig
            \\module: unicode
            \\description: "Тест с юникодом 日本語"
            \\behaviors:
            \\  - name: unicode_behavior
            \\    given: Условие
            \\    when: Действие
            \\    then: Результат
        );

        // Spec with many behaviors
        var many_behaviors = std.ArrayList(u8).init(self.allocator);
        const mb_writer = many_behaviors.writer();
        try mb_writer.writeAll("name: many_behaviors\nversion: \"1.0.0\"\nlanguage: zig\nmodule: many\nbehaviors:\n");
        for (0..100) |i| {
            try mb_writer.print("  - name: behavior_{}\n    given: G\n    when: W\n    then: T\n", .{i});
        }
        try cases.append(try many_behaviors.toOwnedSlice());

        // Spec with deep nesting
        try cases.append(
            \\name: deep_nesting
            \\version: "1.0.0"
            \\language: zig
            \\module: deep
            \\types:
            \\  - name: Level1
            \\    fields:
            \\      - name: level2
            \\        type: Level2
            \\  - name: Level2
            \\    fields:
            \\      - name: level3
            \\        type: Level3
            \\  - name: Level3
            \\    fields:
            \\      - name: value
            \\        type: int
        );

        return cases.toOwnedSlice();
    }
};

// ============================================================================
// STANDARD PROPERTIES FOR VIBEE
// ============================================================================

pub const StandardProperties = struct {
    /// Parser should not crash on any input
    pub fn parserNoCrash(input: []const u8) bool {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        
        _ = parser.parse(arena.allocator(), input) catch {
            // Errors are OK, crashes are not
            return true;
        };
        
        return true;
    }

    /// Parse-unparse roundtrip (if implemented)
    pub fn parseRoundtrip(input: []const u8) bool {
        _ = input;
        // TODO: Implement when unparser is available
        return true;
    }

    /// Spec name should be preserved
    pub fn namePreserved(input: []const u8) bool {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        
        const spec = parser.parse(arena.allocator(), input) catch return true;
        
        // Name should not be empty if parsing succeeded
        return spec.name.len > 0;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "generator int" {
    const allocator = std.testing.allocator;
    var gen = Generator.init(allocator, 12345);

    for (0..100) |_| {
        const value = gen.int(i32, -100, 100);
        try std.testing.expect(value >= -100 and value <= 100);
    }
}

test "generator string" {
    const allocator = std.testing.allocator;
    var gen = Generator.init(allocator, 12345);

    const s = try gen.string(5, 10);
    defer allocator.free(s);

    try std.testing.expect(s.len >= 5 and s.len <= 10);
}

test "generator identifier" {
    const allocator = std.testing.allocator;
    var gen = Generator.init(allocator, 12345);

    const id = try gen.identifier();
    defer allocator.free(id);

    try std.testing.expect(id.len >= 1 and id.len <= 20);
    // First char should be letter or underscore
    try std.testing.expect((id[0] >= 'a' and id[0] <= 'z') or id[0] == '_');
}

test "shrinker int" {
    const allocator = std.testing.allocator;
    var shrinker = Shrinker.init(allocator);

    const candidates = try shrinker.shrinkInt(i32, 100);
    defer allocator.free(candidates);

    try std.testing.expect(candidates.len > 0);
    // Should include 0
    var has_zero = false;
    for (candidates) |c| {
        if (c == 0) has_zero = true;
    }
    try std.testing.expect(has_zero);
}

test "property tester success" {
    const allocator = std.testing.allocator;
    var tester = PropertyTester.init(allocator, 12345);

    // Property: all positive integers are >= 0
    const result = try tester.checkInt(i32, 0, 1000, struct {
        fn check(x: i32) bool {
            return x >= 0;
        }
    }.check);

    try std.testing.expect(result.passed);
}

test "property tester failure with shrinking" {
    const allocator = std.testing.allocator;
    var tester = PropertyTester.init(allocator, 12345);

    // Property: all integers are < 50 (will fail)
    const result = try tester.checkInt(i32, 0, 100, struct {
        fn check(x: i32) bool {
            return x < 50;
        }
    }.check);

    try std.testing.expect(!result.passed);
    // Counterexample should be shrunk to 50
    try std.testing.expectEqualStrings("50", result.counterexample.?);
}

test "spec generator" {
    const allocator = std.testing.allocator;
    var gen = SpecGenerator.init(allocator, 12345);

    const spec = try gen.generateSpec();
    defer allocator.free(spec);

    // Should contain required fields
    try std.testing.expect(std.mem.indexOf(u8, spec, "name:") != null);
    try std.testing.expect(std.mem.indexOf(u8, spec, "version:") != null);
    try std.testing.expect(std.mem.indexOf(u8, spec, "language:") != null);
}

test "edge cases generation" {
    const allocator = std.testing.allocator;
    var gen = SpecGenerator.init(allocator, 12345);

    const cases = try gen.generateEdgeCases();
    defer {
        for (cases) |case| {
            allocator.free(case);
        }
        allocator.free(cases);
    }

    try std.testing.expect(cases.len >= 5);
}

test "standard property - parser no crash" {
    // Test with various inputs
    const inputs = [_][]const u8{
        "",
        "invalid",
        "name: test\n",
        "name: test\nversion: \"1.0.0\"\n",
        "::::",
        "\n\n\n",
    };

    for (inputs) |input| {
        try std.testing.expect(StandardProperties.parserNoCrash(input));
    }
}
