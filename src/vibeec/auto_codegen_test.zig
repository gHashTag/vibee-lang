// ═══════════════════════════════════════════════════════════════════════════════
// AUTO CODEGEN INTEGRATION TEST
// ═══════════════════════════════════════════════════════════════════════════════
//
// Тестирует полный pipeline: VibeeSpec -> AutoCodeGenerator -> Zig code
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const auto_codegen = @import("auto_codegen.zig");
const vibee_parser = @import("vibee_parser.zig");

const AutoCodeGenerator = auto_codegen.AutoCodeGenerator;
const VibeeSpec = vibee_parser.VibeeSpec;
const TypeDef = vibee_parser.TypeDef;
const Field = vibee_parser.Field;
const Behavior = vibee_parser.Behavior;
const TestCase = vibee_parser.TestCase;

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "generate code from minimal spec" {
    const allocator = testing.allocator;

    var spec = VibeeSpec.init(allocator);
    defer spec.deinit();

    spec.name = "test_spec";
    spec.version = "1.0.0";
    spec.author = "Test Author";

    var gen = AutoCodeGenerator.init(allocator);
    defer gen.deinit();

    const output = try gen.generate(&spec);

    // Проверяем наличие ключевых элементов
    try testing.expect(std.mem.indexOf(u8, output, "test_spec v1.0.0") != null);
    try testing.expect(std.mem.indexOf(u8, output, "AUTO-GENERATED") != null);
    try testing.expect(std.mem.indexOf(u8, output, "PHI: f64 = 1.618033988749895") != null);
    try testing.expect(std.mem.indexOf(u8, output, "TRINITY: f64 = 3.0") != null);
    try testing.expect(std.mem.indexOf(u8, output, "golden identity") != null);
}

test "generate struct from TypeDef" {
    const allocator = testing.allocator;

    var spec = VibeeSpec.init(allocator);
    defer spec.deinit();

    spec.name = "struct_test";
    spec.version = "1.0.0";
    spec.author = "Test";

    // Добавляем тип User
    var user_type = TypeDef.init(allocator);
    user_type.name = "User";
    user_type.description = "User entity";

    try user_type.fields.append(Field{ .name = "id", .type_name = "Int" });
    try user_type.fields.append(Field{ .name = "name", .type_name = "String" });

    try spec.types.append(user_type);

    var gen = AutoCodeGenerator.init(allocator);
    defer gen.deinit();

    const output = try gen.generate(&spec);

    // Проверяем генерацию структуры
    try testing.expect(std.mem.indexOf(u8, output, "pub const User = struct {") != null);
    try testing.expect(std.mem.indexOf(u8, output, "id: i64,") != null);
    try testing.expect(std.mem.indexOf(u8, output, "name: []const u8,") != null);
}

test "generate function from Behavior" {
    const allocator = testing.allocator;

    var spec = VibeeSpec.init(allocator);
    defer spec.deinit();

    spec.name = "behavior_test";
    spec.version = "1.0.0";
    spec.author = "Test";

    // Добавляем behavior
    var behavior = Behavior.init(allocator);
    behavior.name = "create_user";
    behavior.given = "Valid user data";
    behavior.when = "create_user is called";
    behavior.then = "Return new User";

    try spec.behaviors.append(behavior);

    var gen = AutoCodeGenerator.init(allocator);
    defer gen.deinit();

    const output = try gen.generate(&spec);

    // Проверяем генерацию функции
    try testing.expect(std.mem.indexOf(u8, output, "pub fn create_user()") != null);
    try testing.expect(std.mem.indexOf(u8, output, "Given: Valid user data") != null);
    try testing.expect(std.mem.indexOf(u8, output, "When: create_user is called") != null);
    try testing.expect(std.mem.indexOf(u8, output, "Then: Return new User") != null);
}

test "generate test from TestCase" {
    const allocator = testing.allocator;

    var spec = VibeeSpec.init(allocator);
    defer spec.deinit();

    spec.name = "test_case_test";
    spec.version = "1.0.0";
    spec.author = "Test";

    // Добавляем behavior с test case
    var behavior = Behavior.init(allocator);
    behavior.name = "calculate";
    behavior.given = "Numbers";
    behavior.when = "calculate is called";
    behavior.then = "Return result";

    try behavior.test_cases.append(TestCase{
        .name = "test_basic_calc",
        .input = "{\"a\": 1, \"b\": 2}",
        .expected = "3",
        .tolerance = null,
    });

    try spec.behaviors.append(behavior);

    var gen = AutoCodeGenerator.init(allocator);
    defer gen.deinit();

    const output = try gen.generate(&spec);

    // Проверяем генерацию теста
    try testing.expect(std.mem.indexOf(u8, output, "test \"test_basic_calc\"") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE MAPPING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "mapType handles all basic types" {
    try testing.expectEqualStrings("[]const u8", auto_codegen.mapType("String"));
    try testing.expectEqualStrings("i64", auto_codegen.mapType("Int"));
    try testing.expectEqualStrings("f64", auto_codegen.mapType("Float"));
    try testing.expectEqualStrings("bool", auto_codegen.mapType("Bool"));
    try testing.expectEqualStrings("void", auto_codegen.mapType("Void"));
}

test "mapType handles unknown types" {
    // Неизвестные типы возвращаются как есть
    try testing.expectEqualStrings("CustomType", auto_codegen.mapType("CustomType"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN IDENTITY VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

test "sacred constants are correct" {
    try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), auto_codegen.PHI, 0.0000001);
    try testing.expectApproxEqAbs(@as(f64, 3.0), auto_codegen.TRINITY, 0.0001);
    try testing.expectEqual(@as(i64, 999), auto_codegen.PHOENIX);
}

test "golden identity holds" {
    const phi = auto_codegen.PHI;
    const phi_sq = phi * phi;
    const phi_inv_sq = 1.0 / phi_sq;
    const result = phi_sq + phi_inv_sq;

    try testing.expectApproxEqAbs(auto_codegen.TRINITY, result, 0.0001);
}
