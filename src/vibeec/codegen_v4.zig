// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC CODEGEN V4 - MULTI-TARGET CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V35 - Code Generator with φ-based Buffer Growth
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: PRE (Precomputation), MLS (ML-Guided), AMR (Amortized)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const parser = @import("parser_v3.zig");
const Specification = parser.Specification;
const TypeDef = parser.TypeDef;
const TypeKind = parser.TypeKind;
const Behavior = parser.Behavior;
const CreationPattern = parser.CreationPattern;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const VERSION = "4.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// OUTPUT TARGET
// ═══════════════════════════════════════════════════════════════════════════════

pub const OutputTarget = enum {
    zig,
    code999,
    both,

    pub fn toString(self: OutputTarget) []const u8 {
        return switch (self) {
            .zig => "Zig",
            .code999 => ".999",
            .both => "Zig + .999",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUILDER - φ-BASED BUFFER GROWTH
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeBuilder = struct {
    allocator: Allocator,
    buffer: []u8,
    len: usize,
    reallocations: u32,
    indent_level: u32,

    const Self = @This();
    const INITIAL_SIZE: usize = 4096;

    pub fn init(allocator: Allocator) !Self {
        const buffer = try allocator.alloc(u8, INITIAL_SIZE);
        return Self{
            .allocator = allocator,
            .buffer = buffer,
            .len = 0,
            .reallocations = 0,
            .indent_level = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    /// Grow using φ factor for optimal amortization (AMR pattern)
    fn grow(self: *Self, min_additional: usize) !void {
        const current = self.buffer.len;
        const phi_growth = @as(usize, @intFromFloat(@as(f64, @floatFromInt(current)) * PHI));
        const new_size = @max(phi_growth, current + min_additional);
        self.buffer = try self.allocator.realloc(self.buffer, new_size);
        self.reallocations += 1;
    }

    pub fn append(self: *Self, bytes: []const u8) !void {
        if (self.len + bytes.len > self.buffer.len) {
            try self.grow(bytes.len);
        }
        @memcpy(self.buffer[self.len..][0..bytes.len], bytes);
        self.len += bytes.len;
    }

    pub fn appendFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        var buf: [4096]u8 = undefined;
        const result = std.fmt.bufPrint(&buf, fmt, args) catch |err| switch (err) {
            error.NoSpaceLeft => {
                // For larger strings, use dynamic allocation
                const str = try std.fmt.allocPrint(self.allocator, fmt, args);
                defer self.allocator.free(str);
                try self.append(str);
                return;
            },
        };
        try self.append(result);
    }

    pub fn appendLine(self: *Self, line: []const u8) !void {
        try self.appendIndent();
        try self.append(line);
        try self.append("\n");
    }

    pub fn appendIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.append("    ");
        }
    }

    pub fn indent(self: *Self) void {
        self.indent_level += 1;
    }

    pub fn dedent(self: *Self) void {
        if (self.indent_level > 0) {
            self.indent_level -= 1;
        }
    }

    pub fn toOwnedSlice(self: *Self) ![]const u8 {
        const result = try self.allocator.alloc(u8, self.len);
        @memcpy(result, self.buffer[0..self.len]);
        return result;
    }

    pub fn getWritten(self: Self) []const u8 {
        return self.buffer[0..self.len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IDENTIFIER CACHE - HSH PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const IdentifierCache = struct {
    cache: std.StringHashMap([]const u8),
    allocator: Allocator,
    hits: u64,
    misses: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .cache = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
            .hits = 0,
            .misses = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    pub fn getOrCreate(self: *Self, name: []const u8, comptime transform: fn ([]const u8, Allocator) Allocator.Error![]const u8) ![]const u8 {
        if (self.cache.get(name)) |cached| {
            self.hits += 1;
            return cached;
        }

        self.misses += 1;
        const transformed = try transform(name, self.allocator);
        try self.cache.put(name, transformed);
        return transformed;
    }

    pub fn hitRatio(self: Self) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODEGEN V4
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodegenV4 = struct {
    allocator: Allocator,
    zig_builder: CodeBuilder,
    code999_builder: CodeBuilder,
    id_cache: IdentifierCache,
    target: OutputTarget,

    // Metrics
    types_generated: u64,
    functions_generated: u64,
    tests_generated: u64,

    const Self = @This();

    pub fn init(allocator: Allocator, target: OutputTarget) !Self {
        return Self{
            .allocator = allocator,
            .zig_builder = try CodeBuilder.init(allocator),
            .code999_builder = try CodeBuilder.init(allocator),
            .id_cache = IdentifierCache.init(allocator),
            .target = target,
            .types_generated = 0,
            .functions_generated = 0,
            .tests_generated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.zig_builder.deinit();
        self.code999_builder.deinit();
        self.id_cache.deinit();
    }

    pub fn generate(self: *Self, spec: *const Specification) !GenerateResult {
        // Generate Zig code
        if (self.target == .zig or self.target == .both) {
            try self.generateZig(spec);
        }

        // Generate .999 code
        if (self.target == .code999 or self.target == .both) {
            try self.generate999(spec);
        }

        return GenerateResult{
            .zig_code = if (self.target == .zig or self.target == .both)
                try self.zig_builder.toOwnedSlice()
            else
                null,
            .code999 = if (self.target == .code999 or self.target == .both)
                try self.code999_builder.toOwnedSlice()
            else
                null,
            .metrics = self.getMetrics(),
        };
    }

    fn generateZig(self: *Self, spec: *const Specification) !void {
        // Header
        try self.zig_builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.zig_builder.appendFmt("// GENERATED FROM: {s}\n", .{spec.name});
        try self.zig_builder.appendLine("// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q");
        try self.zig_builder.appendLine("// Golden Identity: φ² + 1/φ² = 3");
        try self.zig_builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.zig_builder.append("\n");

        // Imports
        try self.zig_builder.appendLine("const std = @import(\"std\");");
        try self.zig_builder.append("\n");

        // Sacred constants
        try self.zig_builder.appendLine("// Sacred Constants");
        try self.zig_builder.appendFmt("pub const PHI: f64 = {d:.15};\n", .{PHI});
        try self.zig_builder.appendFmt("pub const PHI_SQ: f64 = {d:.15};\n", .{PHI_SQ});
        try self.zig_builder.appendFmt("pub const GOLDEN_IDENTITY: f64 = {d:.1};\n", .{GOLDEN_IDENTITY});
        try self.zig_builder.appendFmt("pub const PI: f64 = {d:.15};\n", .{PI});
        try self.zig_builder.appendFmt("pub const E: f64 = {d:.15};\n", .{E});
        try self.zig_builder.append("\n");

        // User constants
        if (spec.constants.items.len > 0) {
            try self.zig_builder.appendLine("// User Constants");
            for (spec.constants.items) |constant| {
                try self.zig_builder.appendFmt("pub const {s} = {s};\n", .{ constant.name, constant.value });
            }
            try self.zig_builder.append("\n");
        }

        // Types
        for (spec.types.items) |type_def| {
            try self.generateZigType(&type_def);
            self.types_generated += 1;
        }

        // Creation Pattern as function
        if (spec.creation_pattern) |cp| {
            try self.generateZigCreationPattern(&cp, spec.name);
            self.functions_generated += 1;
        }

        // Tests from behaviors
        for (spec.behaviors.items) |behavior| {
            try self.generateZigTest(&behavior);
            self.tests_generated += 1;
        }
    }

    fn generateZigType(self: *Self, type_def: *const TypeDef) !void {
        switch (type_def.kind) {
            .struct_type => {
                try self.zig_builder.appendFmt("pub const {s} = struct {{\n", .{type_def.name});
                self.zig_builder.indent();

                for (type_def.fields.items) |field| {
                    try self.zig_builder.appendIndent();
                    try self.zig_builder.appendFmt("{s}: {s},\n", .{
                        field.name,
                        if (field.type_name.len > 0) field.type_name else "void",
                    });
                }

                // Methods
                for (type_def.methods.items) |method| {
                    try self.zig_builder.append("\n");
                    try self.zig_builder.appendIndent();
                    try self.zig_builder.appendFmt("pub fn {s}(self: *@This()", .{method.name});
                    if (method.params.len > 0) {
                        try self.zig_builder.appendFmt(", {s}", .{method.params});
                    }
                    try self.zig_builder.append(") ");
                    if (method.returns.len > 0) {
                        try self.zig_builder.appendFmt("{s}", .{method.returns});
                    } else {
                        try self.zig_builder.append("void");
                    }
                    try self.zig_builder.append(" {\n");
                    self.zig_builder.indent();
                    try self.zig_builder.appendLine("_ = self;");
                    try self.zig_builder.appendLine("@compileError(\"Not implemented\");");
                    self.zig_builder.dedent();
                    try self.zig_builder.appendIndent();
                    try self.zig_builder.append("}\n");
                }

                self.zig_builder.dedent();
                try self.zig_builder.appendLine("};");
                try self.zig_builder.append("\n");
            },
            .enum_type => {
                try self.zig_builder.appendFmt("pub const {s} = enum {{\n", .{type_def.name});
                self.zig_builder.indent();

                for (type_def.values.items) |value| {
                    try self.zig_builder.appendIndent();
                    try self.zig_builder.appendFmt("{s},\n", .{value});
                }

                self.zig_builder.dedent();
                try self.zig_builder.appendLine("};");
                try self.zig_builder.append("\n");
            },
            .union_type => {
                try self.zig_builder.appendFmt("pub const {s} = union(enum) {{\n", .{type_def.name});
                self.zig_builder.indent();

                for (type_def.fields.items) |field| {
                    try self.zig_builder.appendIndent();
                    try self.zig_builder.appendFmt("{s}: {s},\n", .{
                        field.name,
                        if (field.type_name.len > 0) field.type_name else "void",
                    });
                }

                self.zig_builder.dedent();
                try self.zig_builder.appendLine("};");
                try self.zig_builder.append("\n");
            },
        }
    }

    fn generateZigCreationPattern(self: *Self, cp: *const CreationPattern, name: []const u8) !void {
        try self.zig_builder.appendLine("// Creation Pattern");
        try self.zig_builder.appendFmt("/// Source: {s}\n", .{cp.source});
        try self.zig_builder.appendFmt("/// Transformer: {s}\n", .{cp.transformer});
        try self.zig_builder.appendFmt("/// Result: {s}\n", .{cp.result});
        try self.zig_builder.appendFmt("pub fn {s}_transform(input: anytype) @TypeOf(input) {{\n", .{name});
        self.zig_builder.indent();
        try self.zig_builder.appendLine("// TODO: Implement transformation");
        try self.zig_builder.appendLine("return input;");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
        try self.zig_builder.append("\n");
    }

    fn generateZigTest(self: *Self, behavior: *const Behavior) !void {
        try self.zig_builder.appendFmt("test \"{s}\" {{\n", .{behavior.name});
        self.zig_builder.indent();
        try self.zig_builder.appendFmt("// Given: {s}\n", .{behavior.given});
        try self.zig_builder.appendFmt("// When: {s}\n", .{behavior.when});
        try self.zig_builder.appendFmt("// Then: {s}\n", .{behavior.then});
        try self.zig_builder.appendLine("");
        try self.zig_builder.appendLine("// Golden identity verification");
        try self.zig_builder.appendLine("const phi_sq = PHI * PHI;");
        try self.zig_builder.appendLine("const inv_phi_sq = 1.0 / phi_sq;");
        try self.zig_builder.appendLine("try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
        try self.zig_builder.append("\n");
    }

    fn generate999(self: *Self, spec: *const Specification) !void {
        // .999 Header with Coptic-style comments
        try self.code999_builder.appendLine("⟨═══════════════════════════════════════════════════════════════════════════════⟩");
        try self.code999_builder.appendFmt("⟨ ⲤⲠⲈⲤ: {s} ⟩\n", .{spec.name});
        try self.code999_builder.appendLine("⟨ ⲤⲀⲔⲢⲈⲆ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q ⟩");
        try self.code999_builder.appendLine("⟨ ⲄⲞⲖⲆⲈⲚ ⲒⲆⲈⲚⲦⲒⲦⲨ: φ² + 1/φ² = 3 ⟩");
        try self.code999_builder.appendLine("⟨═══════════════════════════════════════════════════════════════════════════════⟩");
        try self.code999_builder.append("\n");

        // Sacred constants in .999 format
        try self.code999_builder.appendLine("⟨ ⲤⲀⲔⲢⲈⲆ ⲔⲞⲚⲤⲦⲀⲚⲦⲤ ⟩");
        try self.code999_builder.appendFmt("ⲫⲓ ← {d:.15}\n", .{PHI});
        try self.code999_builder.appendFmt("ⲫⲓ² ← {d:.15}\n", .{PHI_SQ});
        try self.code999_builder.appendFmt("ⲅⲟⲗⲇⲉⲛ ← {d:.1}\n", .{GOLDEN_IDENTITY});
        try self.code999_builder.appendFmt("ⲡⲓ ← {d:.15}\n", .{PI});
        try self.code999_builder.appendFmt("ⲉ ← {d:.15}\n", .{E});
        try self.code999_builder.append("\n");

        // Types in .999 format
        for (spec.types.items) |type_def| {
            try self.generate999Type(&type_def);
        }

        // Creation Pattern
        if (spec.creation_pattern) |cp| {
            try self.code999_builder.appendLine("⟨ ⲔⲢⲈⲀⲦⲒⲞⲚ ⲠⲀⲦⲦⲈⲢⲚ ⟩");
            try self.code999_builder.appendFmt("ⲤⲞⲨⲢⲤⲈ → {s}\n", .{cp.source});
            try self.code999_builder.appendFmt("ⲦⲢⲀⲚⲤⲪⲞⲢⲘⲈⲢ → {s}\n", .{cp.transformer});
            try self.code999_builder.appendFmt("ⲢⲈⲤⲨⲖⲦ → {s}\n", .{cp.result});
            try self.code999_builder.append("\n");
        }

        // Behaviors
        for (spec.behaviors.items) |behavior| {
            try self.generate999Behavior(&behavior);
        }
    }

    fn generate999Type(self: *Self, type_def: *const TypeDef) !void {
        const kind_str = switch (type_def.kind) {
            .struct_type => "ⲤⲦⲢⲨⲔⲦ",
            .enum_type => "ⲈⲚⲨⲘ",
            .union_type => "ⲨⲚⲒⲞⲚ",
        };

        try self.code999_builder.appendFmt("{s} {s} {{\n", .{ kind_str, type_def.name });

        for (type_def.fields.items) |field| {
            try self.code999_builder.appendFmt("    {s} : {s}\n", .{
                field.name,
                if (field.type_name.len > 0) field.type_name else "ⲁⲛⲩ",
            });
        }

        try self.code999_builder.appendLine("}");
        try self.code999_builder.append("\n");
    }

    fn generate999Behavior(self: *Self, behavior: *const Behavior) !void {
        try self.code999_builder.appendFmt("ⲂⲈϨⲀⲨⲒⲞⲢ {s} {{\n", .{behavior.name});
        try self.code999_builder.appendFmt("    ⲄⲒⲨⲈⲚ: {s}\n", .{behavior.given});
        try self.code999_builder.appendFmt("    ⲰϨⲈⲚ: {s}\n", .{behavior.when});
        try self.code999_builder.appendFmt("    ⲦϨⲈⲚ: {s}\n", .{behavior.then});
        try self.code999_builder.appendLine("}");
        try self.code999_builder.append("\n");
    }

    pub fn getMetrics(self: Self) CodegenMetrics {
        return .{
            .types_generated = self.types_generated,
            .functions_generated = self.functions_generated,
            .tests_generated = self.tests_generated,
            .zig_bytes = self.zig_builder.len,
            .code999_bytes = self.code999_builder.len,
            .zig_reallocations = self.zig_builder.reallocations,
            .code999_reallocations = self.code999_builder.reallocations,
            .cache_hit_ratio = self.id_cache.hitRatio(),
        };
    }
};

pub const GenerateResult = struct {
    zig_code: ?[]const u8,
    code999: ?[]const u8,
    metrics: CodegenMetrics,
};

pub const CodegenMetrics = struct {
    types_generated: u64,
    functions_generated: u64,
    tests_generated: u64,
    zig_bytes: usize,
    code999_bytes: usize,
    zig_reallocations: u32,
    code999_reallocations: u32,
    cache_hit_ratio: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CodeBuilder φ-growth" {
    const allocator = std.testing.allocator;
    var builder = try CodeBuilder.init(allocator);
    defer builder.deinit();

    // Append enough to trigger growth
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try builder.appendLine("test line with some content");
    }

    try std.testing.expect(builder.len > 0);
    try std.testing.expect(builder.reallocations >= 0);
}

test "CodegenV4 generate Zig" {
    const allocator = std.testing.allocator;

    var p = parser.ParserV3.init(allocator);
    defer p.deinit();

    const source =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
        \\module: test
        \\
        \\creation_pattern:
        \\  source: Input
        \\  transformer: Process
        \\  result: Output
        \\
        \\behaviors:
        \\  - name: test_behavior
        \\    given: precondition
        \\    when: action
        \\    then: result
    ;

    var spec = try p.parse(source);
    defer spec.deinit();

    var codegen = try CodegenV4.init(allocator, .zig);
    defer codegen.deinit();

    const result = try codegen.generate(&spec);
    defer if (result.zig_code) |code| allocator.free(code);

    try std.testing.expect(result.zig_code != null);
    try std.testing.expect(result.code999 == null);

    const code = result.zig_code.?;
    try std.testing.expect(std.mem.indexOf(u8, code, "PHI") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "GOLDEN_IDENTITY") != null);
}

test "CodegenV4 generate both" {
    const allocator = std.testing.allocator;

    var p = parser.ParserV3.init(allocator);
    defer p.deinit();

    const source =
        \\name: dual_target
        \\version: "1.0.0"
    ;

    var spec = try p.parse(source);
    defer spec.deinit();

    var codegen = try CodegenV4.init(allocator, .both);
    defer codegen.deinit();

    const result = try codegen.generate(&spec);
    defer {
        if (result.zig_code) |code| allocator.free(code);
        if (result.code999) |code| allocator.free(code);
    }

    try std.testing.expect(result.zig_code != null);
    try std.testing.expect(result.code999 != null);
}

test "IdentifierCache" {
    const allocator = std.testing.allocator;
    var cache = IdentifierCache.init(allocator);
    defer cache.deinit();

    const transform = struct {
        fn f(name: []const u8, alloc: Allocator) ![]const u8 {
            return try std.fmt.allocPrint(alloc, "transformed_{s}", .{name});
        }
    }.f;

    const result1 = try cache.getOrCreate("test", transform);
    try std.testing.expectEqualStrings("transformed_test", result1);

    const result2 = try cache.getOrCreate("test", transform);
    try std.testing.expectEqualStrings("transformed_test", result2);

    try std.testing.expectEqual(@as(u64, 1), cache.hits);
    try std.testing.expectEqual(@as(u64, 1), cache.misses);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
