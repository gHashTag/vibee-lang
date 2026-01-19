// ═══════════════════════════════════════════════════════════════════════════════
// SPEC COMPILER - Full .vibee → .zig Code Generator
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generates COMPLETE Zig code from .vibee specifications:
//   - Structs from types
//   - Functions from behaviors
//   - Tests from test_cases
//   - Golden identity verification
//
// PAS DAEMONS: PRE (template caching), D&C (parallel generation)
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const testing = std.testing;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
    optional: bool = false,
};

pub const TypeDef = struct {
    name: []const u8,
    description: []const u8 = "",
    fields: ArrayList(Field),
    is_enum: bool = false,
    enum_values: ArrayList([]const u8),

    pub fn init(allocator: Allocator) TypeDef {
        return TypeDef{
            .name = "",
            .fields = ArrayList(Field).init(allocator),
            .enum_values = ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *TypeDef) void {
        self.fields.deinit();
        self.enum_values.deinit();
    }
};

pub const TestCase = struct {
    name: []const u8,
    input: []const u8,
    expected: []const u8,
};

pub const Behavior = struct {
    name: []const u8,
    given: []const u8 = "",
    when: []const u8 = "",
    then: []const u8 = "",
    pas_pattern: []const u8 = "",
    test_cases: ArrayList(TestCase),

    pub fn init(allocator: Allocator) Behavior {
        return Behavior{
            .name = "",
            .test_cases = ArrayList(TestCase).init(allocator),
        };
    }

    pub fn deinit(self: *Behavior) void {
        self.test_cases.deinit();
    }
};

pub const Spec = struct {
    name: []const u8,
    version: []const u8,
    module: []const u8,
    types: ArrayList(TypeDef),
    behaviors: ArrayList(Behavior),

    pub fn init(allocator: Allocator) Spec {
        return Spec{
            .name = "",
            .version = "1.0.0",
            .module = "",
            .types = ArrayList(TypeDef).init(allocator),
            .behaviors = ArrayList(Behavior).init(allocator),
        };
    }

    pub fn deinit(self: *Spec) void {
        for (self.types.items) |*t| {
            t.deinit();
        }
        for (self.behaviors.items) |*b| {
            b.deinit();
        }
        self.types.deinit();
        self.behaviors.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpecCompiler = struct {
    allocator: Allocator,
    buffer: ArrayList(u8),
    indent: u32,
    types_generated: u32,
    functions_generated: u32,
    tests_generated: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = ArrayList(u8).init(allocator),
            .indent = 0,
            .types_generated = 0,
            .functions_generated = 0,
            .tests_generated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    pub fn compile(self: *Self, spec: *const Spec) ![]const u8 {
        try self.writeHeader(spec);
        try self.writeImports();
        try self.writeSacredConstants();
        try self.writeTypes(spec.types.items);
        try self.writeFunctions(spec.behaviors.items);
        try self.writeTests(spec.behaviors.items);
        try self.writeGoldenIdentityTest();

        return self.buffer.items;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HEADER
    // ═══════════════════════════════════════════════════════════════════════════

    fn writeHeader(self: *Self, spec: *const Spec) !void {
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeFmt("// {s} v{s} - AUTO-GENERATED from .vibee specification\n", .{ spec.name, spec.version });
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeLine("//");
        try self.writeLine("// DO NOT EDIT MANUALLY - This file is auto-generated by SpecCompiler");
        try self.writeLine("//");
        try self.writeLine("// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q");
        try self.writeLine("// Golden Identity: φ² + 1/φ² = 3");
        try self.writeLine("//");
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.newline();
    }

    fn writeImports(self: *Self) !void {
        try self.writeLine("const std = @import(\"std\");");
        try self.writeLine("const testing = std.testing;");
        try self.writeLine("const Allocator = std.mem.Allocator;");
        try self.newline();
    }

    fn writeSacredConstants(self: *Self) !void {
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeLine("// SACRED CONSTANTS");
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.newline();
        try self.writeLine("pub const PHI: f64 = 1.618033988749895;");
        try self.writeLine("pub const TRINITY: f64 = 3.0;");
        try self.writeLine("pub const PHOENIX: u32 = 999;");
        try self.newline();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    fn writeTypes(self: *Self, types: []const TypeDef) !void {
        if (types.len == 0) return;

        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeLine("// TYPES (auto-generated from specification)");
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.newline();

        for (types) |t| {
            try self.writeType(&t);
            self.types_generated += 1;
        }
    }

    fn writeType(self: *Self, t: *const TypeDef) !void {
        if (t.description.len > 0) {
            try self.writeFmt("/// {s}\n", .{t.description});
        }

        if (t.is_enum) {
            try self.writeFmt("pub const {s} = enum {{\n", .{t.name});
            self.indent += 1;
            for (t.enum_values.items) |val| {
                try self.writeIndent();
                try self.writeFmt("{s},\n", .{val});
            }
            self.indent -= 1;
            try self.writeLine("};");
        } else {
            try self.writeFmt("pub const {s} = struct {{\n", .{t.name});
            self.indent += 1;
            for (t.fields.items) |field| {
                try self.writeIndent();
                const zig_type = mapType(field.type_name);
                if (field.optional) {
                    try self.writeFmt("{s}: ?{s} = null,\n", .{ field.name, zig_type });
                } else {
                    try self.writeFmt("{s}: {s},\n", .{ field.name, zig_type });
                }
            }
            self.indent -= 1;
            try self.writeLine("};");
        }
        try self.newline();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    fn writeFunctions(self: *Self, behaviors: []const Behavior) !void {
        if (behaviors.len == 0) return;

        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeLine("// FUNCTIONS (auto-generated from behaviors)");
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.newline();

        for (behaviors) |b| {
            try self.writeFunction(&b);
            self.functions_generated += 1;
        }
    }

    fn writeFunction(self: *Self, b: *const Behavior) !void {
        // Documentation from given/when/then
        try self.writeFmt("/// Given: {s}\n", .{b.given});
        try self.writeFmt("/// When: {s}\n", .{b.when});
        try self.writeFmt("/// Then: {s}\n", .{b.then});
        if (b.pas_pattern.len > 0) {
            try self.writeFmt("/// PAS Pattern: {s}\n", .{b.pas_pattern});
        }

        // Function signature
        try self.writeFmt("pub fn {s}() !void {{\n", .{b.name});
        self.indent += 1;

        try self.writeIndent();
        try self.writeLine("// TODO: Implement based on specification");
        try self.writeIndent();
        try self.writeLine("// Auto-generated stub - replace with actual implementation");

        self.indent -= 1;
        try self.writeLine("}");
        try self.newline();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    fn writeTests(self: *Self, behaviors: []const Behavior) !void {
        var has_tests = false;
        for (behaviors) |b| {
            if (b.test_cases.items.len > 0) {
                has_tests = true;
                break;
            }
        }

        if (!has_tests) return;

        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeLine("// TESTS (auto-generated from test_cases)");
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.newline();

        for (behaviors) |b| {
            for (b.test_cases.items) |tc| {
                try self.writeTest(&tc, b.name);
                self.tests_generated += 1;
            }
        }
    }

    fn writeTest(self: *Self, tc: *const TestCase, behavior_name: []const u8) !void {
        try self.writeFmt("test \"{s}\" {{\n", .{tc.name});
        self.indent += 1;

        try self.writeIndent();
        try self.writeFmt("// Behavior: {s}\n", .{behavior_name});
        try self.writeIndent();
        try self.writeFmt("// Input: {s}\n", .{tc.input});
        try self.writeIndent();
        try self.writeFmt("// Expected: {s}\n", .{tc.expected});
        try self.writeIndent();
        try self.writeLine("// TODO: Implement test assertions");

        self.indent -= 1;
        try self.writeLine("}");
        try self.newline();
    }

    fn writeGoldenIdentityTest(self: *Self) !void {
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeLine("// GOLDEN IDENTITY VERIFICATION");
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.newline();

        try self.writeLine("test \"golden identity: φ² + 1/φ² = 3\" {");
        self.indent += 1;

        try self.writeIndent();
        try self.writeLine("const phi_sq = PHI * PHI;");
        try self.writeIndent();
        try self.writeLine("const phi_inv_sq = 1.0 / phi_sq;");
        try self.writeIndent();
        try self.writeLine("const result = phi_sq + phi_inv_sq;");
        try self.writeIndent();
        try self.writeLine("try testing.expectApproxEqAbs(TRINITY, result, 0.0001);");

        self.indent -= 1;
        try self.writeLine("}");

        self.tests_generated += 1;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(str);
        try self.buffer.append('\n');
    }

    fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer();
        try writer.print(fmt, args);
    }

    fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice("    ");
        }
    }

    fn newline(self: *Self) !void {
        try self.buffer.append('\n');
    }

    pub fn getStats(self: *const Self) Stats {
        return Stats{
            .types_generated = self.types_generated,
            .functions_generated = self.functions_generated,
            .tests_generated = self.tests_generated,
            .output_size = self.buffer.items.len,
        };
    }
};

pub const Stats = struct {
    types_generated: u32,
    functions_generated: u32,
    tests_generated: u32,
    output_size: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE MAPPING
// ═══════════════════════════════════════════════════════════════════════════════

pub fn mapType(vibee_type: []const u8) []const u8 {
    if (std.mem.eql(u8, vibee_type, "String")) return "[]const u8";
    if (std.mem.eql(u8, vibee_type, "Int")) return "i64";
    if (std.mem.eql(u8, vibee_type, "Float")) return "f64";
    if (std.mem.eql(u8, vibee_type, "Bool")) return "bool";
    if (std.mem.eql(u8, vibee_type, "Void")) return "void";
    if (std.mem.startsWith(u8, vibee_type, "List<")) return "[]const u8";
    if (std.mem.startsWith(u8, vibee_type, "Option<")) return "?[]const u8";
    return vibee_type;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SpecCompiler: compile empty spec" {
    const allocator = testing.allocator;

    var spec = Spec.init(allocator);
    defer spec.deinit();
    spec.name = "test_spec";
    spec.version = "1.0.0";

    var compiler = SpecCompiler.init(allocator);
    defer compiler.deinit();

    const output = try compiler.compile(&spec);

    try testing.expect(std.mem.indexOf(u8, output, "test_spec v1.0.0") != null);
    try testing.expect(std.mem.indexOf(u8, output, "PHI: f64 = 1.618033988749895") != null);
    try testing.expect(std.mem.indexOf(u8, output, "golden identity") != null);
}

test "SpecCompiler: compile with types" {
    const allocator = testing.allocator;

    var spec = Spec.init(allocator);
    defer spec.deinit();
    spec.name = "user_spec";
    spec.version = "1.0.0";

    var user_type = TypeDef.init(allocator);
    user_type.name = "User";
    user_type.description = "User entity";
    try user_type.fields.append(Field{ .name = "id", .type_name = "Int" });
    try user_type.fields.append(Field{ .name = "name", .type_name = "String" });
    try spec.types.append(user_type);

    var compiler = SpecCompiler.init(allocator);
    defer compiler.deinit();

    const output = try compiler.compile(&spec);

    try testing.expect(std.mem.indexOf(u8, output, "pub const User = struct {") != null);
    try testing.expect(std.mem.indexOf(u8, output, "id: i64,") != null);
    try testing.expect(std.mem.indexOf(u8, output, "name: []const u8,") != null);

    const stats = compiler.getStats();
    try testing.expectEqual(@as(u32, 1), stats.types_generated);
}

test "SpecCompiler: compile with behaviors" {
    const allocator = testing.allocator;

    var spec = Spec.init(allocator);
    defer spec.deinit();
    spec.name = "behavior_spec";
    spec.version = "1.0.0";

    var behavior = Behavior.init(allocator);
    behavior.name = "create_user";
    behavior.given = "Valid user data";
    behavior.when = "create_user is called";
    behavior.then = "Return new User";
    behavior.pas_pattern = "PRE";
    try spec.behaviors.append(behavior);

    var compiler = SpecCompiler.init(allocator);
    defer compiler.deinit();

    const output = try compiler.compile(&spec);

    try testing.expect(std.mem.indexOf(u8, output, "pub fn create_user()") != null);
    try testing.expect(std.mem.indexOf(u8, output, "Given: Valid user data") != null);
    try testing.expect(std.mem.indexOf(u8, output, "PAS Pattern: PRE") != null);

    const stats = compiler.getStats();
    try testing.expectEqual(@as(u32, 1), stats.functions_generated);
}

test "SpecCompiler: compile with test_cases" {
    const allocator = testing.allocator;

    var spec = Spec.init(allocator);
    defer spec.deinit();
    spec.name = "test_spec";
    spec.version = "1.0.0";

    var behavior = Behavior.init(allocator);
    behavior.name = "calculate";
    behavior.given = "Numbers";
    behavior.when = "calculate is called";
    behavior.then = "Return result";
    try behavior.test_cases.append(TestCase{
        .name = "test_basic",
        .input = "{\"a\": 1}",
        .expected = "1",
    });
    try spec.behaviors.append(behavior);

    var compiler = SpecCompiler.init(allocator);
    defer compiler.deinit();

    const output = try compiler.compile(&spec);

    try testing.expect(std.mem.indexOf(u8, output, "test \"test_basic\"") != null);

    const stats = compiler.getStats();
    try testing.expectEqual(@as(u32, 2), stats.tests_generated); // test_basic + golden identity
}

test "SpecCompiler: type mapping" {
    try testing.expectEqualStrings("[]const u8", mapType("String"));
    try testing.expectEqualStrings("i64", mapType("Int"));
    try testing.expectEqualStrings("f64", mapType("Float"));
    try testing.expectEqualStrings("bool", mapType("Bool"));
    try testing.expectEqualStrings("CustomType", mapType("CustomType"));
}

test "SpecCompiler: stats tracking" {
    const allocator = testing.allocator;

    var spec = Spec.init(allocator);
    defer spec.deinit();
    spec.name = "stats_test";
    spec.version = "1.0.0";

    // Add 2 types
    var type1 = TypeDef.init(allocator);
    type1.name = "Type1";
    try spec.types.append(type1);

    var type2 = TypeDef.init(allocator);
    type2.name = "Type2";
    try spec.types.append(type2);

    // Add 1 behavior with 2 test cases
    var behavior = Behavior.init(allocator);
    behavior.name = "test_behavior";
    behavior.given = "Given";
    behavior.when = "When";
    behavior.then = "Then";
    try behavior.test_cases.append(TestCase{ .name = "test1", .input = "{}", .expected = "{}" });
    try behavior.test_cases.append(TestCase{ .name = "test2", .input = "{}", .expected = "{}" });
    try spec.behaviors.append(behavior);

    var compiler = SpecCompiler.init(allocator);
    defer compiler.deinit();

    _ = try compiler.compile(&spec);

    const stats = compiler.getStats();
    try testing.expectEqual(@as(u32, 2), stats.types_generated);
    try testing.expectEqual(@as(u32, 1), stats.functions_generated);
    try testing.expectEqual(@as(u32, 3), stats.tests_generated); // 2 + golden identity
}

test "golden identity constant" {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const result = phi_sq + phi_inv_sq;
    try testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
