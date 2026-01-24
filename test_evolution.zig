//! VIBEE Self-Evolution Test: Sacred Rewriting
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_compiler = @import("src/vibeec/coptic_compiler.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const source =
        \\// Тест самоэволюции: сложное выражение должно свернуться в 3.0
        \\const TRINITY_TEST = (phi * phi) + (1.0 / (phi * phi))
        \\func main() { print(TRINITY_TEST) }
    ;

    var compiler = coptic_compiler.Compiler.init(allocator, source, "test.vibee");
    compiler.options.evolve = true; // Активируем самоэволюцию
    compiler.options.target = .zig;

    std.debug.print("🚀 Инициирую самоэволюцию кода...\n", .{});
    const result = compiler.compile();

    if (result.errors.items.len > 0) {
        std.debug.print("❌ Ошибка компиляции: {s}\n", .{result.errors.items[0].message});
        return;
    }

    std.debug.print("✅ Самоэволюция завершена!\n", .{});
    std.debug.print("Символов в глобальной области: {d}\n", .{result.symbols_count});

    // В идеале здесь мы проверим, что в сгенерированном коде вместо формулы - число 3.0
    std.debug.print("--- Сгенерированный код ---\n{s}\n", .{result.code});
}
