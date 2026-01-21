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
        const writer = self.buffer.writer();
        try writer.print(fmt, args);
    }
    
    pub fn newline(self: *Self) !void {
        try self.buffer.append('\n');
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
        try self.writeTests(spec.behaviors.items);
        
        return self.builder.getOutput();
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
        
        if (!has_phi) {
            try self.builder.writeLine("// Базовые φ-константы (defaults)");
            try self.builder.writeLine("pub const PHI: f64 = 1.618033988749895;");
            try self.builder.writeLine("pub const PHI_INV: f64 = 0.618033988749895;");
            try self.builder.writeLine("pub const PHI_SQ: f64 = 2.618033988749895;");
            try self.builder.writeLine("pub const TRINITY: f64 = 3.0;");
            try self.builder.writeLine("pub const SQRT5: f64 = 2.2360679774997896;");
            try self.builder.writeLine("pub const TAU: f64 = 6.283185307179586;");
            try self.builder.newline();
        }
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
            try self.builder.writeLine("pub export fn phi_power(n: i32) f64 {");
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
            try self.builder.writeLine("pub export fn fibonacci(n: u32) u64 {");
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
            try self.builder.writeLine("pub export fn lucas(n: u32) u64 {");
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
        }
    }
    
    fn generateStandardFunctions(self: *Self) !void {
        // verify_trinity
        try self.builder.writeLine("/// Проверка TRINITY identity: φ² + 1/φ² = 3");
        try self.builder.writeLine("pub export fn verify_trinity() f64 {");
        try self.builder.writeLine("    return PHI * PHI + 1.0 / (PHI * PHI);");
        try self.builder.writeLine("}");
        try self.builder.newline();
        
        // phi_lerp
        try self.builder.writeLine("/// φ-интерполяция");
        try self.builder.writeLine("pub export fn phi_lerp(a: f64, b: f64, t: f64) f64 {");
        try self.builder.writeLine("    const phi_t = math.pow(f64, t, PHI_INV);");
        try self.builder.writeLine("    return a + (b - a) * phi_t;");
        try self.builder.writeLine("}");
        try self.builder.newline();
        
        // generate_phi_spiral
        try self.builder.writeLine("/// Генерация φ-спирали");
        try self.builder.writeLine("pub export fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {");
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
        const input = tc.input;
        // Извлекаем только число из expected (может содержать комментарий)
        const expected = extractNumber(tc.expected);
        
        // Определяем функцию по имени behavior
        if (std.mem.startsWith(u8, behavior_name, "phi_power")) {
            // Извлекаем n из input
            if (extractIntParam(input, "n")) |n| {
                if (tc.tolerance) |tol| {
                    try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_power({d}), {s}, {d});\n", .{n, expected, tol});
                } else {
                    try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_power({d}), {s}, 1e-10);\n", .{n, expected});
                }
            }
        } else if (std.mem.startsWith(u8, behavior_name, "fibonacci")) {
            if (extractIntParam(input, "n")) |n| {
                try self.builder.writeFmt("try std.testing.expectEqual(fibonacci({d}), {s});\n", .{n, expected});
            }
        } else if (std.mem.startsWith(u8, behavior_name, "lucas")) {
            if (extractIntParam(input, "n")) |n| {
                try self.builder.writeFmt("try std.testing.expectEqual(lucas({d}), {s});\n", .{n, expected});
            }
        } else if (std.mem.eql(u8, behavior_name, "trinity_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);");
        } else if (std.mem.startsWith(u8, behavior_name, "phi_spiral")) {
            // phi_spiral тесты
            try self.builder.writeLine("const count = generate_phi_spiral(100, 10.0, 0.0, 0.0);");
            try self.builder.writeLine("try std.testing.expect(count > 0);");
        } else if (std.mem.startsWith(u8, behavior_name, "phi_lerp")) {
            // phi_lerp тесты - используем большую tolerance из-за приближённых значений в spec
            if (extractFloatParam(input, "t")) |t| {
                const a = extractFloatParam(input, "a") orelse 0.0;
                const b_val = extractFloatParam(input, "b") orelse 100.0;
                const tol = tc.tolerance orelse 1.0; // Большая tolerance для phi_lerp
                try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_lerp({d}, {d}, {d}), {s}, {d});\n", .{a, b_val, t, expected, tol});
            }
        } else {
            // Неизвестный тест - генерируем комментарий
            try self.builder.writeFmt("// Test case: input={s}, expected={s}\n", .{input, expected});
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
        } else {
            try self.builder.writeLine("// TODO: Add test assertions");
        }
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
