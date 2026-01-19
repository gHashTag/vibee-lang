// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC CODEGEN WASM - ZIG/WASM CODE GENERATOR FROM .VIBEE SPECS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Zig код для компиляции в WASM из .vibee спецификаций
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const parser = @import("parser_v3.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// СВЯЩЕННЫЕ КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const VERSION = "24.φ";

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ СПЕЦИФИКАЦИИ
// ═══════════════════════════════════════════════════════════════════════════════

pub const VibeeSpec = struct {
    name: []const u8,
    version: []const u8,
    targets: []const []const u8,
    constants: []const Constant,
    types: []const TypeDef,
    creation_patterns: []const CreationPattern,
    behaviors: []const Behavior,
    algorithms: []const Algorithm,
    wasm_exports: WasmExports,
};

pub const Constant = struct {
    name: []const u8,
    value: f64,
    description: []const u8,
};

pub const TypeDef = struct {
    name: []const u8,
    base: ?[]const u8,
    fields: []const Field,
    generic: ?[]const u8,
    description: []const u8,
};

pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
};

pub const CreationPattern = struct {
    name: []const u8,
    source: []const u8,
    transformer: []const u8,
    result: []const u8,
};

pub const Behavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
    test_cases: []const TestCase,
};

pub const TestCase = struct {
    input: []const u8,
    expected: []const u8,
};

pub const Algorithm = struct {
    name: []const u8,
    description: []const u8,
    complexity: []const u8,
    pattern: []const u8,
    steps: []const []const u8,
};

pub const WasmExports = struct {
    functions: []const []const u8,
    memory: []const MemoryExport,
};

pub const MemoryExport = struct {
    name: []const u8,
    size: usize,
    type_name: ?[]const u8,
    alignment: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeBuilder = struct {
    allocator: Allocator,
    buffer: ArrayList(u8),
    indent: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = ArrayList(u8).init(allocator),
            .indent = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    pub fn write(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(str);
    }

    pub fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(str);
        try self.buffer.append('\n');
    }

    pub fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice("    ");
        }
    }

    pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        var buf: [4096]u8 = undefined;
        const result = std.fmt.bufPrint(&buf, fmt, args) catch return error.FormatError;
        try self.buffer.appendSlice(result);
    }

    pub fn newline(self: *Self) !void {
        try self.buffer.append('\n');
    }

    pub fn indent_inc(self: *Self) void {
        self.indent += 1;
    }

    pub fn indent_dec(self: *Self) void {
        if (self.indent > 0) self.indent -= 1;
    }

    pub fn getOutput(self: *Self) []const u8 {
        return self.buffer.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ZIG/WASM CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const WasmCodeGen = struct {
    allocator: Allocator,
    builder: CodeBuilder,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .builder = CodeBuilder.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.builder.deinit();
    }

    /// Генерация полного Zig файла из спецификации
    pub fn generate(self: *Self, spec: VibeeSpec) ![]const u8 {
        try self.writeHeader(spec);
        try self.writeConstants(spec.constants);
        try self.writeTypes(spec.types);
        try self.writeMemoryBuffers(spec.wasm_exports.memory);
        try self.writeCreationPatterns(spec.creation_patterns);
        try self.writeAlgorithms(spec.algorithms);
        try self.writeTests(spec.behaviors);

        return self.builder.getOutput();
    }

    fn writeHeader(self: *Self, spec: VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeFmt("// {s} v{s} - Generated from .vibee specification\n", .{ spec.name, spec.version });
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// Священная формула: V = n × 3^k × π^m × φ^p × e^q");
        try self.builder.writeLine("// Золотая идентичность: φ² + 1/φ² = 3");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        try self.builder.writeLine("const std = @import(\"std\");");
        try self.builder.writeLine("const math = std.math;");
        try self.builder.newline();
    }

    fn writeConstants(self: *Self, constants: []const Constant) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// КОНСТАНТЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (constants) |c| {
            try self.builder.writeFmt("/// {s}\n", .{c.description});
            try self.builder.writeFmt("pub const {s}: f64 = {d};\n", .{ c.name, c.value });
            try self.builder.newline();
        }
    }

    fn writeTypes(self: *Self, types: []const TypeDef) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ТИПЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (types) |t| {
            try self.builder.writeFmt("/// {s}\n", .{t.description});

            if (t.base) |base| {
                // Alias type
                try self.builder.writeFmt("pub const {s} = {s};\n", .{ t.name, base });
            } else {
                // Struct type
                try self.builder.writeFmt("pub const {s} = struct {{\n", .{t.name});
                self.builder.indent_inc();

                for (t.fields) |field| {
                    try self.builder.writeIndent();
                    try self.builder.writeFmt("{s}: {s},\n", .{ field.name, mapType(field.type_name) });
                }

                self.builder.indent_dec();
                try self.builder.writeLine("};");
            }
            try self.builder.newline();
        }
    }

    fn writeMemoryBuffers(self: *Self, memory: []const MemoryExport) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ПАМЯТЬ ДЛЯ WASM");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (memory) |m| {
            if (m.type_name) |type_name| {
                try self.builder.writeFmt("var {s}: [{d}]{s} align({d}) = undefined;\n", .{ m.name, m.size, type_name, m.alignment });
            } else {
                try self.builder.writeFmt("var {s}: [{d}]u8 align({d}) = undefined;\n", .{ m.name, m.size, m.alignment });
            }
        }

        try self.builder.newline();

        // Generate getters for WASM
        for (memory) |m| {
            try self.builder.writeFmt("export fn get_{s}_ptr() [*]", .{m.name});
            if (m.type_name) |type_name| {
                try self.builder.writeFmt("{s}", .{type_name});
            } else {
                try self.builder.write("u8");
            }
            try self.builder.writeFmt(" {{\n    return &{s};\n}}\n\n", .{m.name});

            try self.builder.writeFmt("export fn get_{s}_size() usize {{\n    return {s}.len;\n}}\n\n", .{ m.name, m.name });
        }
    }

    fn writeCreationPatterns(self: *Self, patterns: []const CreationPattern) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// CREATION PATTERNS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (patterns) |p| {
            try self.builder.writeFmt("/// {s}\n", .{p.transformer});
            try self.builder.writeFmt("/// Source: {s} -> Result: {s}\n", .{ p.source, p.result });

            // Generate function signature based on pattern
            try self.generatePatternFunction(p);
            try self.builder.newline();
        }
    }

    fn generatePatternFunction(self: *Self, pattern: CreationPattern) !void {
        // Map common patterns to implementations
        if (std.mem.eql(u8, pattern.name, "phi_power")) {
            try self.builder.writeLine("export fn phi_power(n: i32) f64 {");
            self.builder.indent_inc();
            try self.builder.writeLine("if (n == 0) return 1.0;");
            try self.builder.writeLine("if (n == 1) return PHI;");
            try self.builder.writeLine("if (n == -1) return PHI_INV;");
            try self.builder.newline();
            try self.builder.writeLine("var result: f64 = 1.0;");
            try self.builder.writeLine("var base: f64 = if (n < 0) PHI_INV else PHI;");
            try self.builder.writeLine("var exp: u32 = if (n < 0) @intCast(-n) else @intCast(n);");
            try self.builder.newline();
            try self.builder.writeLine("while (exp > 0) {");
            self.builder.indent_inc();
            try self.builder.writeLine("if (exp & 1 == 1) result *= base;");
            try self.builder.writeLine("base *= base;");
            try self.builder.writeLine("exp >>= 1;");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return result;");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "fibonacci")) {
            try self.builder.writeLine("export fn fibonacci(n: u32) u64 {");
            self.builder.indent_inc();
            try self.builder.writeLine("if (n == 0) return 0;");
            try self.builder.writeLine("if (n <= 2) return 1;");
            try self.builder.newline();
            try self.builder.writeLine("// Формула Бине: F(n) = (φⁿ - ψⁿ) / √5");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.newline();
            try self.builder.writeLine("return @intFromFloat(@round((phi_n - psi_n) / SQRT5));");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "lucas")) {
            try self.builder.writeLine("export fn lucas(n: u32) u64 {");
            self.builder.indent_inc();
            try self.builder.writeLine("if (n == 0) return 2;");
            try self.builder.writeLine("if (n == 1) return 1;");
            try self.builder.newline();
            try self.builder.writeLine("// L(n) = φⁿ + ψⁿ");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.newline();
            try self.builder.writeLine("return @intFromFloat(@round(phi_n + psi_n));");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "phi_lerp")) {
            try self.builder.writeLine("export fn phi_lerp(a: f64, b: f64, t: f64) f64 {");
            self.builder.indent_inc();
            try self.builder.writeLine("const phi_t = math.pow(t, PHI_INV);");
            try self.builder.writeLine("return a + (b - a) * phi_t;");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "phi_spiral")) {
            try self.builder.writeLine("export fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {");
            self.builder.indent_inc();
            try self.builder.writeLine("const max_points = f64_buffer.len / 2;");
            try self.builder.writeLine("const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;");
            try self.builder.newline();
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < count) : (i += 1) {");
            self.builder.indent_inc();
            try self.builder.writeLine("const fi: f64 = @floatFromInt(i);");
            try self.builder.writeLine("const angle = fi * TAU * PHI_INV;");
            try self.builder.writeLine("const radius = scale * math.pow(PHI, fi * 0.1);");
            try self.builder.writeLine("f64_buffer[i * 2] = cx + radius * @cos(angle);");
            try self.builder.writeLine("f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return count;");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
        } else {
            // Generic pattern stub
            try self.builder.writeFmt("// TODO: Implement {s}\n", .{pattern.name});
            try self.builder.writeFmt("// Source: {s}\n", .{pattern.source});
            try self.builder.writeFmt("// Result: {s}\n", .{pattern.result});
        }
    }

    fn writeAlgorithms(self: *Self, algorithms: []const Algorithm) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ALGORITHMS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (algorithms) |alg| {
            try self.builder.writeFmt("// {s}\n", .{alg.name});
            try self.builder.writeFmt("// {s}\n", .{alg.description});
            try self.builder.writeFmt("// Complexity: {s}, Pattern: {s}\n", .{ alg.complexity, alg.pattern });
            try self.builder.writeLine("//");
            try self.builder.writeLine("// Steps:");
            for (alg.steps) |step| {
                try self.builder.writeFmt("//   {s}\n", .{step});
            }
            try self.builder.newline();
        }
    }

    fn writeTests(self: *Self, behaviors: []const Behavior) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TESTS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (behaviors) |b| {
            try self.builder.writeFmt("test \"{s}\" {{\n", .{b.name});
            self.builder.indent_inc();
            try self.builder.writeFmt("// Given: {s}\n", .{b.given});
            try self.builder.writeFmt("// When: {s}\n", .{b.when});
            try self.builder.writeFmt("// Then: {s}\n", .{b.then});

            for (b.test_cases) |tc| {
                try self.builder.writeFmt("// Input: {s}, Expected: {s}\n", .{ tc.input, tc.expected });
            }

            try self.builder.writeLine("// TODO: Implement test assertions");
            self.builder.indent_dec();
            try self.builder.writeLine("}");
            try self.builder.newline();
        }
    }

    /// Map .vibee types to Zig types
    fn mapType(type_name: []const u8) []const u8 {
        if (std.mem.eql(u8, type_name, "f64")) return "f64";
        if (std.mem.eql(u8, type_name, "f32")) return "f32";
        if (std.mem.eql(u8, type_name, "i32")) return "i32";
        if (std.mem.eql(u8, type_name, "i64")) return "i64";
        if (std.mem.eql(u8, type_name, "u32")) return "u32";
        if (std.mem.eql(u8, type_name, "u64")) return "u64";
        if (std.mem.eql(u8, type_name, "bool")) return "bool";
        if (std.mem.startsWith(u8, type_name, "Array<")) return "[]const u8"; // Simplified
        if (std.mem.startsWith(u8, type_name, "Option<")) return "?*anyopaque"; // Simplified
        return type_name;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFY TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

export fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "trinity identity" {
    const result = verify_trinity();
    try std.testing.expectApproxEqAbs(result, TRINITY, 1e-10);
}

test "phi constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}
