// ═══════════════════════════════════════════════════════════════════════════════
// ZIG CODEGEN - Генератор Zig кода из .vibee спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Zig код для компиляции в WASM
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const vibee_parser = @import("vibee_parser.zig");

const VibeeSpec = vibee_parser.VibeeSpec;
const Constant = vibee_parser.Constant;
const TypeDef = vibee_parser.TypeDef;
const CreationPattern = vibee_parser.CreationPattern;
const Behavior = vibee_parser.Behavior;
const TestCase = vibee_parser.TestCase;

// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeBuilder = struct {
    allocator: Allocator,
    buffer: std.ArrayListUnmanaged(u8),
    indent: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = .empty,
            .indent = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, str);
    }

    pub fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(self.allocator, str);
        try self.buffer.append(self.allocator, '\n');
    }

    pub fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice(self.allocator, "    ");
        }
    }

    pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer(self.allocator);
        try writer.print(fmt, args);
    }

    pub fn newline(self: *Self) !void {
        try self.buffer.append(self.allocator, '\n');
    }

    pub fn incIndent(self: *Self) void {
        self.indent += 1;
    }

    pub fn decIndent(self: *Self) void {
        if (self.indent > 0) self.indent -= 1;
    }

    pub fn getOutput(self: *Self) []const u8 {
        return self.buffer.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ZIG CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const ZigCodeGen = struct {
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
    pub fn generate(self: *Self, spec: *const VibeeSpec) ![]const u8 {
        try self.writeHeader(spec);
        try self.writeImports();
        try self.writeConstants(spec.constants.items);
        try self.writeTypes(spec.types.items);
        try self.writeMemoryBuffers();
        try self.writeCreationPatterns(spec.creation_patterns.items);
        try self.writeBehaviorFunctions(spec.behaviors.items);
        try self.writeTests(spec.behaviors.items);

        return self.builder.getOutput();
    }

    /// Generate functions from behaviors with implementation blocks
    fn writeBehaviorFunctions(self: *Self, behaviors: []const Behavior) !void {
        var has_impl = false;
        for (behaviors) |b| {
            if (b.implementation.len > 0) {
                has_impl = true;
                break;
            }
        }
        if (!has_impl) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BEHAVIOR IMPLEMENTATIONS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (behaviors) |b| {
            if (b.implementation.len == 0) continue;

            try self.builder.writeFmt("/// {s}\n", .{b.given});
            try self.builder.writeFmt("/// When: {s}\n", .{b.when});
            try self.builder.writeFmt("/// Then: {s}\n", .{b.then});
            try self.builder.writeFmt("pub fn {s}() void {{\n", .{b.name});
            self.builder.incIndent();

            // Write implementation code (trimmed)
            const impl = std.mem.trim(u8, b.implementation, " \t\n\r");
            if (impl.len > 0) {
                try self.builder.write(impl);
                try self.builder.newline();
            } else {
                try self.builder.writeLine("// TODO: implementation");
            }

            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.newline();
        }
    }

    fn writeHeader(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeFmt("// {s} v{s} - Generated from .vibee specification\n", .{ spec.name, spec.version });
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// Священная формула: V = n × 3^k × π^m × φ^p × e^q");
        try self.builder.writeLine("// Золотая идентичность: φ² + 1/φ² = 3");
        try self.builder.writeLine("//");
        try self.builder.writeFmt("// Author: {s}\n", .{spec.author});
        try self.builder.writeLine("// DO NOT EDIT - This file is auto-generated");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
    }

    fn writeImports(self: *Self) !void {
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
            if (c.description.len > 0) {
                try self.builder.writeFmt("/// {s}\n", .{c.description});
            }
            try self.builder.writeFmt("pub const {s}: f64 = {d};\n", .{ c.name, c.value });
            try self.builder.newline();
        }

        // Добавляем базовые φ-константы только если их нет в спецификации
        var has_phi = false;
        for (constants) |c| {
            if (std.mem.eql(u8, c.name, "PHI")) {
                has_phi = true;
                break;
            }
        }

        // Добавляем базовые φ-константы если их нет
        try self.builder.writeLine("// Базовые φ-константы (Sacred Formula)");

        var has_phi_inv = false;
        var has_phi_sq = false;
        var has_trinity = false;
        var has_sqrt5 = false;
        var has_tau = false;
        var has_pi = false;
        var has_e = false;
        var has_phoenix = false;

        for (constants) |c| {
            if (std.mem.eql(u8, c.name, "PHI_INV")) has_phi_inv = true;
            if (std.mem.eql(u8, c.name, "PHI_SQ")) has_phi_sq = true;
            if (std.mem.eql(u8, c.name, "TRINITY")) has_trinity = true;
            if (std.mem.eql(u8, c.name, "SQRT5")) has_sqrt5 = true;
            if (std.mem.eql(u8, c.name, "TAU")) has_tau = true;
            if (std.mem.eql(u8, c.name, "PI")) has_pi = true;
            if (std.mem.eql(u8, c.name, "E")) has_e = true;
            if (std.mem.eql(u8, c.name, "PHOENIX")) has_phoenix = true;
        }

        if (!has_phi) try self.builder.writeLine("pub const PHI: f64 = 1.618033988749895;");
        if (!has_phi_inv) try self.builder.writeLine("pub const PHI_INV: f64 = 0.618033988749895;");
        if (!has_phi_sq) try self.builder.writeLine("pub const PHI_SQ: f64 = 2.618033988749895;");
        if (!has_trinity) try self.builder.writeLine("pub const TRINITY: f64 = 3.0;");
        if (!has_sqrt5) try self.builder.writeLine("pub const SQRT5: f64 = 2.2360679774997896;");
        if (!has_tau) try self.builder.writeLine("pub const TAU: f64 = 6.283185307179586;");
        if (!has_pi) try self.builder.writeLine("pub const PI: f64 = 3.141592653589793;");
        if (!has_e) try self.builder.writeLine("pub const E: f64 = 2.718281828459045;");
        if (!has_phoenix) try self.builder.writeLine("pub const PHOENIX: i64 = 999;");
        try self.builder.newline();
    }

    fn writeTypes(self: *Self, types: []const TypeDef) !void {
        if (types.len == 0) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ТИПЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (types) |t| {
            try self.builder.writeFmt("/// {s}\n", .{t.description});

            if (t.base) |base| {
                try self.builder.writeFmt("pub const {s} = {s};\n", .{ t.name, base });
            } else {
                try self.builder.writeFmt("pub const {s} = struct {{\n", .{t.name});
                self.builder.incIndent();

                for (t.fields.items) |field| {
                    try self.builder.writeIndent();
                    const clean_type = cleanTypeName(field.type_name);
                    const safe_name = escapeReservedWord(field.name);
                    try self.builder.writeFmt("{s}: {s},\n", .{ safe_name, mapType(clean_type) });
                }

                self.builder.decIndent();
                try self.builder.writeLine("};");
            }
            try self.builder.newline();
        }
    }

    fn writeMemoryBuffers(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ПАМЯТЬ ДЛЯ WASM");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        try self.builder.writeLine("var global_buffer: [65536]u8 align(16) = undefined;");
        try self.builder.writeLine("var f64_buffer: [8192]f64 align(16) = undefined;");
        try self.builder.newline();

        try self.builder.writeLine("export fn get_global_buffer_ptr() [*]u8 {");
        try self.builder.writeLine("    return &global_buffer;");
        try self.builder.writeLine("}");
        try self.builder.newline();

        try self.builder.writeLine("export fn get_f64_buffer_ptr() [*]f64 {");
        try self.builder.writeLine("    return &f64_buffer;");
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn writeCreationPatterns(self: *Self, patterns: []const CreationPattern) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// CREATION PATTERNS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (patterns) |p| {
            try self.builder.writeFmt("/// {s}\n", .{p.transformer});
            try self.builder.writeFmt("/// Source: {s} -> Result: {s}\n", .{ p.source, p.result });
            try self.generatePatternFunction(p);
            try self.builder.newline();
        }

        // Генерируем стандартные φ-функции
        try self.generateStandardFunctions();
    }

    fn generatePatternFunction(self: *Self, pattern: CreationPattern) !void {
        if (std.mem.eql(u8, pattern.name, "phi_power")) {
            try self.builder.writeLine("fn phi_power(n: i32) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 1.0;");
            try self.builder.writeLine("if (n == 1) return PHI;");
            try self.builder.writeLine("if (n == -1) return PHI_INV;");
            try self.builder.newline();
            try self.builder.writeLine("var result: f64 = 1.0;");
            try self.builder.writeLine("var base: f64 = if (n < 0) PHI_INV else PHI;");
            try self.builder.writeLine("var exp: u32 = if (n < 0) @intCast(-n) else @intCast(n);");
            try self.builder.newline();
            try self.builder.writeLine("while (exp > 0) {");
            self.builder.incIndent();
            try self.builder.writeLine("if (exp & 1 == 1) result *= base;");
            try self.builder.writeLine("base *= base;");
            try self.builder.writeLine("exp >>= 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "fibonacci")) {
            try self.builder.writeLine("fn fibonacci(n: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 0;");
            try self.builder.writeLine("if (n <= 2) return 1;");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.writeLine("return @intFromFloat(@round((phi_n - psi_n) / SQRT5));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "lucas")) {
            try self.builder.writeLine("fn lucas(n: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 2;");
            try self.builder.writeLine("if (n == 1) return 1;");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.writeLine("return @intFromFloat(@round(phi_n + psi_n));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "factorial")) {
            try self.builder.writeLine("/// Factorial n! - O(n)");
            try self.builder.writeLine("fn factorial(n: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n <= 1) return 1;");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u64 = 2;");
            try self.builder.writeLine("while (i <= n) : (i += 1) result *%= i;");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "gcd")) {
            try self.builder.writeLine("/// GCD using Euclidean algorithm - O(log(min(a,b)))");
            try self.builder.writeLine("fn gcd(a: u64, b: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("var x = a;");
            try self.builder.writeLine("var y = b;");
            try self.builder.writeLine("while (y != 0) {");
            self.builder.incIndent();
            try self.builder.writeLine("const t = y;");
            try self.builder.writeLine("y = x % y;");
            try self.builder.writeLine("x = t;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return x;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "lcm")) {
            try self.builder.writeLine("/// LCM using GCD - O(log(min(a,b)))");
            try self.builder.writeLine("fn lcm(a: u64, b: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (a == 0 or b == 0) return 0;");
            try self.builder.writeLine("return (a / gcd(a, b)) * b;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "digital_root")) {
            try self.builder.writeLine("/// Digital root (repeated digit sum until single digit) - O(1)");
            try self.builder.writeLine("fn digital_root(n: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 0;");
            try self.builder.writeLine("const r = n % 9;");
            try self.builder.writeLine("return if (r == 0) 9 else r;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "trinity_power")) {
            try self.builder.writeLine("/// Trinity power 3^k with lookup table - O(1) for k < 20");
            try self.builder.writeLine("fn trinity_power(k: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("const powers = [_]u64{ 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049, 177147, 531441, 1594323, 4782969, 14348907, 43046721, 129140163, 387420489, 1162261467 };");
            try self.builder.writeLine("if (k < powers.len) return powers[k];");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < k) : (i += 1) result *= 3;");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "sacred_formula")) {
            try self.builder.writeLine("/// Sacred formula: V = n × 3^k × π^m × φ^p × e^q");
            try self.builder.writeLine("fn sacred_formula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return n * math.pow(f64, 3.0, k) * math.pow(f64, PI, m) * math.pow(f64, PHI, p) * math.pow(f64, E, q);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "golden_identity")) {
            try self.builder.writeLine("/// Golden identity: φ² + 1/φ² = 3");
            try self.builder.writeLine("fn golden_identity() f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return PHI * PHI + 1.0 / (PHI * PHI);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "binomial")) {
            try self.builder.writeLine("/// Binomial coefficient C(n,k) = n! / (k! * (n-k)!)");
            try self.builder.writeLine("fn binomial(n: u64, k: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (k > n) return 0;");
            try self.builder.writeLine("if (k == 0 or k == n) return 1;");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u64 = 0;");
            try self.builder.writeLine("while (i < k) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("result = result * (n - i) / (i + 1);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        }
    }

    fn generateStandardFunctions(self: *Self) !void {
        // Trit type and operations
        try self.builder.writeLine("/// Trit - ternary digit (-1, 0, +1)");
        try self.builder.writeLine("pub const Trit = enum(i8) {");
        try self.builder.writeLine("    negative = -1, // ▽ FALSE");
        try self.builder.writeLine("    zero = 0,      // ○ UNKNOWN");
        try self.builder.writeLine("    positive = 1,  // △ TRUE");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_and(a: Trit, b: Trit) Trit {");
        try self.builder.writeLine("        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));");
        try self.builder.writeLine("    }");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_or(a: Trit, b: Trit) Trit {");
        try self.builder.writeLine("        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));");
        try self.builder.writeLine("    }");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_not(a: Trit) Trit {");
        try self.builder.writeLine("        return @enumFromInt(-@intFromEnum(a));");
        try self.builder.writeLine("    }");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_xor(a: Trit, b: Trit) Trit {");
        try self.builder.writeLine("        const av = @intFromEnum(a);");
        try self.builder.writeLine("        const bv = @intFromEnum(b);");
        try self.builder.writeLine("        if (av == 0 or bv == 0) return .zero;");
        try self.builder.writeLine("        if (av == bv) return .negative;");
        try self.builder.writeLine("        return .positive;");
        try self.builder.writeLine("    }");
        try self.builder.writeLine("};");
        try self.builder.newline();

        // verify_trinity
        try self.builder.writeLine("/// Проверка TRINITY identity: φ² + 1/φ² = 3");
        try self.builder.writeLine("fn verify_trinity() f64 {");
        try self.builder.writeLine("    return PHI * PHI + 1.0 / (PHI * PHI);");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // phi_lerp
        try self.builder.writeLine("/// φ-интерполяция");
        try self.builder.writeLine("fn phi_lerp(a: f64, b: f64, t: f64) f64 {");
        try self.builder.writeLine("    const phi_t = math.pow(f64, t, PHI_INV);");
        try self.builder.writeLine("    return a + (b - a) * phi_t;");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // generate_phi_spiral
        try self.builder.writeLine("/// Генерация φ-спирали");
        try self.builder.writeLine("fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {");
        self.builder.incIndent();
        try self.builder.writeLine("const max_points = f64_buffer.len / 2;");
        try self.builder.writeLine("const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;");
        try self.builder.writeLine("var i: u32 = 0;");
        try self.builder.writeLine("while (i < count) : (i += 1) {");
        self.builder.incIndent();
        try self.builder.writeLine("const fi: f64 = @floatFromInt(i);");
        try self.builder.writeLine("const angle = fi * TAU * PHI_INV;");
        try self.builder.writeLine("const radius = scale * math.pow(f64, PHI, fi * 0.1);");
        try self.builder.writeLine("f64_buffer[i * 2] = cx + radius * @cos(angle);");
        try self.builder.writeLine("f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.writeLine("return count;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn writeTests(self: *Self, behaviors: []const Behavior) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TESTS - Generated from behaviors and test_cases");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        // Отслеживаем уже добавленные тесты
        var added_tests = std.StringHashMap(void).init(self.allocator);
        defer added_tests.deinit();

        for (behaviors) |b| {
            // Пропускаем дубликаты
            if (added_tests.contains(b.name)) continue;
            added_tests.put(b.name, {}) catch continue;

            try self.builder.writeFmt("test \"{s}\" {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeFmt("// Given: {s}\n", .{b.given});
            try self.builder.writeFmt("// When: {s}\n", .{b.when});
            try self.builder.writeFmt("// Then: {s}\n", .{b.then});

            // Генерируем assertions из test_cases
            if (b.test_cases.items.len > 0) {
                for (b.test_cases.items) |tc| {
                    try self.generateTestAssertion(b.name, tc);
                }
            } else {
                // Fallback для известных тестов без test_cases
                try self.generateKnownTestAssertion(b.name);
            }

            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.newline();
        }

        // Добавляем базовый тест констант если его нет
        if (!added_tests.contains("phi_constants")) {
            try self.builder.writeLine("test \"phi_constants\" {");
            try self.builder.writeLine("    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);");
            try self.builder.writeLine("    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);");
            try self.builder.writeLine("}");
        }
    }

    fn generateTestAssertion(self: *Self, behavior_name: []const u8, tc: TestCase) !void {
        // Парсим input: { n: 0 } или { a: 0, b: 100, t: 0.5 }
        // Убираем кавычки если есть
        const input = stripQuotes(tc.input);
        // Извлекаем только число из expected (может содержать комментарий)
        const expected = extractNumber(stripQuotes(tc.expected));

        // Используем tc.name если есть, иначе behavior_name
        const func_name = if (tc.name.len > 0) tc.name else behavior_name;

        // Определяем функцию по имени
        if (std.mem.startsWith(u8, func_name, "phi_power")) {
            // Извлекаем n из input
            if (extractIntParam(input, "n")) |n| {
                if (tc.tolerance) |tol| {
                    try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_power({d}), {s}, {d});\n", .{ n, expected, tol });
                } else {
                    try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_power({d}), {s}, 1e-10);\n", .{ n, expected });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "fibonacci") or std.mem.startsWith(u8, func_name, "test_fibonacci")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(fibonacci({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "lucas") or std.mem.startsWith(u8, func_name, "test_lucas")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(lucas({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.eql(u8, func_name, "trinity_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);");
        } else if (std.mem.startsWith(u8, func_name, "phi_spiral")) {
            // phi_spiral тесты
            try self.builder.writeLine("const count = generate_phi_spiral(100, 10.0, 0.0, 0.0);");
            try self.builder.writeLine("try std.testing.expect(count > 0);");
        } else if (std.mem.startsWith(u8, func_name, "phi_lerp")) {
            // phi_lerp тесты - используем большую tolerance из-за приближённых значений в spec
            if (extractFloatParam(input, "t")) |t| {
                const a = extractFloatParam(input, "a") orelse 0.0;
                const b_val = extractFloatParam(input, "b") orelse 100.0;
                const tol = tc.tolerance orelse 1.0; // Большая tolerance для phi_lerp
                try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_lerp({d}, {d}, {d}), {s}, {d});\n", .{ a, b_val, t, expected, tol });
            }
        } else if (std.mem.startsWith(u8, func_name, "factorial") or std.mem.startsWith(u8, func_name, "test_factorial")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(factorial({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "gcd") or std.mem.startsWith(u8, func_name, "test_gcd")) {
            const a = extractIntParam(input, "a") orelse 0;
            const b_val = extractIntParam(input, "b") orelse 0;
            if (a != 0 or b_val != 0) {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(gcd({d}, {d}), {d});\n", .{ a, b_val, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "lcm") or std.mem.startsWith(u8, func_name, "test_lcm")) {
            const a = extractIntParam(input, "a") orelse 0;
            const b_val = extractIntParam(input, "b") orelse 0;
            if (a != 0 or b_val != 0) {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(lcm({d}, {d}), {d});\n", .{ a, b_val, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "digital_root") or std.mem.startsWith(u8, func_name, "test_digital_root")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(digital_root({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "trinity_power") or std.mem.startsWith(u8, func_name, "test_trinity_power")) {
            if (extractIntParam(input, "k")) |k| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(trinity_power({d}), {d});\n", .{ k, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "golden_identity") or std.mem.startsWith(u8, func_name, "test_golden_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(golden_identity(), 3.0, 1e-10);");
        } else if (std.mem.startsWith(u8, func_name, "binomial") or std.mem.startsWith(u8, func_name, "test_binomial")) {
            const n = extractIntParam(input, "n") orelse 0;
            const k = extractIntParam(input, "k") orelse 0;
            if (n != 0) {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(binomial({d}, {d}), {d});\n", .{ n, k, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "sacred_formula") or std.mem.startsWith(u8, func_name, "test_sacred_formula")) {
            const n = extractFloatParam(input, "n") orelse 1.0;
            const k = extractFloatParam(input, "k") orelse 0.0;
            const m = extractFloatParam(input, "m") orelse 0.0;
            const p = extractFloatParam(input, "p") orelse 0.0;
            const q = extractFloatParam(input, "q") orelse 0.0;
            const tol = tc.tolerance orelse 1e-6;
            try self.builder.writeFmt("try std.testing.expectApproxEqAbs(sacred_formula({d}, {d}, {d}, {d}, {d}), {s}, {d});\n", .{ n, k, m, p, q, expected, tol });
        } else if (std.mem.startsWith(u8, func_name, "trit_and") or std.mem.startsWith(u8, func_name, "test_trit_and")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .negative), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .zero), .zero);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .positive), .positive);");
        } else if (std.mem.startsWith(u8, func_name, "trit_or") or std.mem.startsWith(u8, func_name, "test_trit_or")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.positive, .negative), .positive);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.negative, .zero), .zero);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.negative, .negative), .negative);");
        } else if (std.mem.startsWith(u8, func_name, "trit_not") or std.mem.startsWith(u8, func_name, "test_trit_not")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.positive), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.zero), .zero);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.negative), .positive);");
        } else if (std.mem.startsWith(u8, func_name, "verify_trinity") or std.mem.startsWith(u8, func_name, "test_verify_trinity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);");
        } else {
            // Неизвестный тест - генерируем комментарий
            try self.builder.writeFmt("// Test case: input={s}, expected={s}\n", .{ input, expected });
        }
    }

    fn generateKnownTestAssertion(self: *Self, name: []const u8) !void {
        if (std.mem.eql(u8, name, "trinity_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_zero")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(0), 1.0, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_one")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(1), PHI, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_negative")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(-1), PHI_INV, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_squared")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(2), PHI_SQ, 1e-10);");
        } else if (std.mem.eql(u8, name, "fibonacci_base_cases")) {
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(0), 0);");
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(1), 1);");
        } else if (std.mem.eql(u8, name, "fibonacci_sequence")) {
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(10), 55);");
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(20), 6765);");
        } else if (std.mem.eql(u8, name, "lucas_base_cases")) {
            try self.builder.writeLine("try std.testing.expectEqual(lucas(0), 2);");
            try self.builder.writeLine("try std.testing.expectEqual(lucas(1), 1);");
        } else if (std.mem.eql(u8, name, "lucas_sequence")) {
            try self.builder.writeLine("try std.testing.expectEqual(lucas(10), 123);");
        } else if (std.mem.eql(u8, name, "factorial_base") or std.mem.eql(u8, name, "test_factorial")) {
            try self.builder.writeLine("try std.testing.expectEqual(factorial(0), 1);");
            try self.builder.writeLine("try std.testing.expectEqual(factorial(1), 1);");
            try self.builder.writeLine("try std.testing.expectEqual(factorial(5), 120);");
            try self.builder.writeLine("try std.testing.expectEqual(factorial(10), 3628800);");
        } else if (std.mem.eql(u8, name, "gcd_test") or std.mem.eql(u8, name, "test_gcd")) {
            try self.builder.writeLine("try std.testing.expectEqual(gcd(999, 27), 27);");
            try self.builder.writeLine("try std.testing.expectEqual(gcd(48, 18), 6);");
            try self.builder.writeLine("try std.testing.expectEqual(gcd(17, 13), 1);");
        } else if (std.mem.eql(u8, name, "lcm_test") or std.mem.eql(u8, name, "test_lcm")) {
            try self.builder.writeLine("try std.testing.expectEqual(lcm(4, 6), 12);");
            try self.builder.writeLine("try std.testing.expectEqual(lcm(3, 9), 9);");
        } else if (std.mem.eql(u8, name, "digital_root_test") or std.mem.eql(u8, name, "test_digital_root")) {
            try self.builder.writeLine("try std.testing.expectEqual(digital_root(999), 9);");
            try self.builder.writeLine("try std.testing.expectEqual(digital_root(27), 9);");
            try self.builder.writeLine("try std.testing.expectEqual(digital_root(123), 6);");
        } else if (std.mem.eql(u8, name, "trinity_power_test") or std.mem.eql(u8, name, "test_trinity_power")) {
            try self.builder.writeLine("try std.testing.expectEqual(trinity_power(0), 1);");
            try self.builder.writeLine("try std.testing.expectEqual(trinity_power(3), 27);");
            try self.builder.writeLine("try std.testing.expectEqual(trinity_power(9), 19683);");
        } else if (std.mem.eql(u8, name, "golden_identity_test") or std.mem.eql(u8, name, "test_golden_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(golden_identity(), 3.0, 1e-10);");
        } else if (std.mem.eql(u8, name, "binomial_test") or std.mem.eql(u8, name, "test_binomial")) {
            try self.builder.writeLine("try std.testing.expectEqual(binomial(5, 2), 10);");
            try self.builder.writeLine("try std.testing.expectEqual(binomial(10, 3), 120);");
        } else if (std.mem.eql(u8, name, "trit_and_test") or std.mem.eql(u8, name, "test_trit_and")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .negative), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .positive), .positive);");
        } else if (std.mem.eql(u8, name, "trit_or_test") or std.mem.eql(u8, name, "test_trit_or")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.positive, .negative), .positive);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.negative, .negative), .negative);");
        } else if (std.mem.eql(u8, name, "trit_not_test") or std.mem.eql(u8, name, "test_trit_not")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.positive), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.zero), .zero);");
        } else {
            try self.builder.writeLine("// TODO: Add test assertions");
        }
    }

    fn stripQuotes(value: []const u8) []const u8 {
        if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
            return value[1 .. value.len - 1];
        }
        return value;
    }

    fn parseU64(value: []const u8) ?u64 {
        const trimmed = std.mem.trim(u8, value, " \t");
        return std.fmt.parseInt(u64, trimmed, 10) catch null;
    }

    fn parseF64(value: []const u8) ?f64 {
        const trimmed = std.mem.trim(u8, value, " \t");
        return std.fmt.parseFloat(f64, trimmed) catch null;
    }

    fn extractNumber(value: []const u8) []const u8 {
        // Извлекаем только число из строки типа "65.47  # comment"
        var end: usize = 0;
        // Пропускаем начальные пробелы
        var start: usize = 0;
        while (start < value.len and (value[start] == ' ' or value[start] == '\t')) {
            start += 1;
        }
        end = start;
        // Читаем число (может быть отрицательным, с точкой)
        if (end < value.len and value[end] == '-') {
            end += 1;
        }
        while (end < value.len and ((value[end] >= '0' and value[end] <= '9') or value[end] == '.')) {
            end += 1;
        }
        if (end > start) {
            return value[start..end];
        }
        return value;
    }

    fn extractIntParam(input: []const u8, param: []const u8) ?i32 {
        // Ищем "param: value" в строке типа "{ n: 0 }"
        var search_buf: [64]u8 = undefined;
        const search = std.fmt.bufPrint(&search_buf, "{s}:", .{param}) catch return null;

        if (std.mem.indexOf(u8, input, search)) |idx| {
            var start = idx + search.len;
            // Пропускаем пробелы
            while (start < input.len and (input[start] == ' ' or input[start] == '\t')) {
                start += 1;
            }
            // Читаем число (может быть отрицательным)
            var end = start;
            if (end < input.len and input[end] == '-') {
                end += 1;
            }
            while (end < input.len and input[end] >= '0' and input[end] <= '9') {
                end += 1;
            }
            if (end > start) {
                return std.fmt.parseInt(i32, input[start..end], 10) catch null;
            }
        }
        return null;
    }

    fn extractFloatParam(input: []const u8, param: []const u8) ?f64 {
        var search_buf: [64]u8 = undefined;
        const search = std.fmt.bufPrint(&search_buf, "{s}:", .{param}) catch return null;

        if (std.mem.indexOf(u8, input, search)) |idx| {
            var start = idx + search.len;
            while (start < input.len and (input[start] == ' ' or input[start] == '\t')) {
                start += 1;
            }
            var end = start;
            if (end < input.len and input[end] == '-') {
                end += 1;
            }
            while (end < input.len and ((input[end] >= '0' and input[end] <= '9') or input[end] == '.')) {
                end += 1;
            }
            if (end > start) {
                return std.fmt.parseFloat(f64, input[start..end]) catch null;
            }
        }
        return null;
    }

    fn escapeReservedWord(name: []const u8) []const u8 {
        // Zig reserved words that might appear as field names
        if (std.mem.eql(u8, name, "error")) return "@\"error\"";
        if (std.mem.eql(u8, name, "type")) return "@\"type\"";
        if (std.mem.eql(u8, name, "return")) return "@\"return\"";
        if (std.mem.eql(u8, name, "break")) return "@\"break\"";
        if (std.mem.eql(u8, name, "continue")) return "@\"continue\"";
        if (std.mem.eql(u8, name, "if")) return "@\"if\"";
        if (std.mem.eql(u8, name, "else")) return "@\"else\"";
        if (std.mem.eql(u8, name, "while")) return "@\"while\"";
        if (std.mem.eql(u8, name, "for")) return "@\"for\"";
        if (std.mem.eql(u8, name, "fn")) return "@\"fn\"";
        if (std.mem.eql(u8, name, "const")) return "@\"const\"";
        if (std.mem.eql(u8, name, "var")) return "@\"var\"";
        if (std.mem.eql(u8, name, "pub")) return "@\"pub\"";
        if (std.mem.eql(u8, name, "try")) return "@\"try\"";
        if (std.mem.eql(u8, name, "catch")) return "@\"catch\"";
        return name;
    }

    fn cleanTypeName(type_name: []const u8) []const u8 {
        var result = type_name;

        // Remove comments (# ...)
        if (std.mem.indexOf(u8, result, "#")) |pos| {
            result = result[0..pos];
        }

        // Remove default values (= "...")
        if (std.mem.indexOf(u8, result, "=")) |pos| {
            result = result[0..pos];
        }

        // Handle union types (A | B) -> use first type
        if (std.mem.indexOf(u8, result, "|")) |pos| {
            result = result[0..pos];
        }

        return std.mem.trim(u8, result, " \t");
    }

    fn mapType(type_name: []const u8) []const u8 {
        // Primitive types
        if (std.mem.eql(u8, type_name, "f64")) return "f64";
        if (std.mem.eql(u8, type_name, "f32")) return "f32";
        if (std.mem.eql(u8, type_name, "i32")) return "i32";
        if (std.mem.eql(u8, type_name, "i64")) return "i64";
        if (std.mem.eql(u8, type_name, "u32")) return "u32";
        if (std.mem.eql(u8, type_name, "u64")) return "u64";
        if (std.mem.eql(u8, type_name, "bool")) return "bool";

        // VIBEE types -> Zig types
        if (std.mem.eql(u8, type_name, "String")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Int")) return "i64";
        if (std.mem.eql(u8, type_name, "Float")) return "f64";
        if (std.mem.eql(u8, type_name, "Bool")) return "bool";
        if (std.mem.eql(u8, type_name, "Bytes")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Timestamp")) return "i64";
        if (std.mem.eql(u8, type_name, "Duration")) return "i64";
        if (std.mem.eql(u8, type_name, "Any")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Void")) return "void";
        if (std.mem.eql(u8, type_name, "Error")) return "anyerror";

        // Generic types Option<T> -> ?T
        if (std.mem.startsWith(u8, type_name, "Option<")) {
            return "?[]const u8"; // Simplified: Option<T> -> ?[]const u8
        }

        // Generic types List<T> -> []T
        if (std.mem.startsWith(u8, type_name, "List<")) {
            return "[]const u8"; // Simplified: List<T> -> slice
        }

        // Plain List type -> slice
        if (std.mem.eql(u8, type_name, "List")) {
            return "[]const u8";
        }

        // Generic types Map<K,V> -> std.StringHashMap
        if (std.mem.startsWith(u8, type_name, "Map<")) {
            return "std.StringHashMap([]const u8)";
        }

        // Plain Map type -> std.StringHashMap
        if (std.mem.eql(u8, type_name, "Map")) {
            return "std.StringHashMap([]const u8)";
        }

        // Handle trailing ? (nullable) - convert Type? to ?Type
        if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
            return "?[]const u8"; // Simplified
        }

        // Object type
        if (std.mem.eql(u8, type_name, "Object")) {
            return "[]const u8";
        }

        // Unknown complex types -> []const u8
        if (std.mem.eql(u8, type_name, "JsonSchema")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Role")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "PluginManifest")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "PluginConfig")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "StreamEvent")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "TokenStats")) return "[]const u8";

        return type_name;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateFromFile(allocator: Allocator, vibee_path: []const u8, output_path: []const u8) !void {
    // Читаем .vibee файл
    const file = try std.fs.cwd().openFile(vibee_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    // Парсим
    var parser = vibee_parser.VibeeParser.init(allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    // Генерируем Zig код
    var codegen = ZigCodeGen.init(allocator);
    defer codegen.deinit();

    const output = try codegen.generate(&spec);

    // Записываем в файл
    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    try out_file.writeAll(output);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════════════════════

test "code builder" {
    var builder = CodeBuilder.init(std.testing.allocator);
    defer builder.deinit();

    try builder.writeLine("const x = 1;");
    try builder.writeLine("const y = 2;");

    const output = builder.getOutput();
    try std.testing.expect(output.len > 0);
}

test "generate empty spec" {
    var spec = VibeeSpec.init(std.testing.allocator);
    defer spec.deinit();

    spec.name = "test";
    spec.version = "1.0";
    spec.author = "Test";

    var codegen = ZigCodeGen.init(std.testing.allocator);
    defer codegen.deinit();

    const output = try codegen.generate(&spec);
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "PHI") != null);
}
