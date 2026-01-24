//! Сравнение эффективности поиска: Binary Search vs Ternary Search
//! φ² + 1/φ² = 3

const std = @import("std");

pub fn main() !void {
    const range: f64 = 1_000_000_000_000;

    const binary_steps = @log2(range);
    const ternary_steps = std.math.log(f64, 3.0, range);

    std.debug.print("🚀 Сравнение алгоритмической плотности:\n", .{});
    std.debug.print("Диапазон поиска: {d}\n", .{range});
    std.debug.print("Шагов в бинарной системе: {d:.2}\n", .{binary_steps});
    std.debug.print("Шагов в троичной системе: {d:.2}\n", .{ternary_steps});
    std.debug.print("Преимущество Trinity: {d:.2}%\n", .{(binary_steps / ternary_steps - 1) * 100});

    // Эмуляция Radix Economy
    // E = R * log_R(N)
    const radix_binary = 2.0 * binary_steps;
    const radix_ternary = 3.0 * ternary_steps; // Хотя 3 больше 2, плотность информации выше

    std.debug.print("\nЭкономика основания (меньше - лучше):\n", .{});
    std.debug.print("Binary (R=2): {d:.2}\n", .{radix_binary});
    std.debug.print("Ternary (R=3): {d:.2}\n", .{radix_ternary});
    std.debug.print("Теоретический оптимум (R=e): {d:.2}\n", .{std.math.e * std.math.log(f64, std.math.e, range)});
}
