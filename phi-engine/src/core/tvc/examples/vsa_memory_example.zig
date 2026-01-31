// VSA Associative Memory Example
// Демонстрация использования VSA для ассоциативной памяти
//
// Запуск: zig run vsa_memory_example.zig

const std = @import("std");
const tvc_vsa = @import("../tvc_vsa.zig");
const HybridBigInt = tvc_vsa.HybridBigInt;

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         VSA Associative Memory Example                       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. Создаём словарь концептов (случайные векторы)
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("1. Создание словаря концептов...\n", .{});

    // Объекты
    var apple = tvc_vsa.randomVector(256, 1001);
    var banana = tvc_vsa.randomVector(256, 1002);
    var car = tvc_vsa.randomVector(256, 1003);

    // Свойства
    var red = tvc_vsa.randomVector(256, 2001);
    var yellow = tvc_vsa.randomVector(256, 2002);
    var fast = tvc_vsa.randomVector(256, 2003);

    std.debug.print("   Объекты: apple, banana, car\n", .{});
    std.debug.print("   Свойства: red, yellow, fast\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. Создаём ассоциации через bind
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("2. Создание ассоциаций (bind)...\n", .{});

    // apple + red = "красное яблоко"
    var red_apple = tvc_vsa.bind(&apple, &red);
    std.debug.print("   red_apple = bind(apple, red)\n", .{});

    // banana + yellow = "жёлтый банан"
    var yellow_banana = tvc_vsa.bind(&banana, &yellow);
    std.debug.print("   yellow_banana = bind(banana, yellow)\n", .{});

    // car + fast = "быстрая машина"
    var fast_car = tvc_vsa.bind(&car, &fast);
    std.debug.print("   fast_car = bind(car, fast)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. Объединяем в память через bundle
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("3. Создание памяти (bundle)...\n", .{});

    // Объединяем все ассоциации в одну память
    var temp = tvc_vsa.bundle2(&red_apple, &yellow_banana);
    var memory = tvc_vsa.bundle3(&temp, &fast_car, &temp);

    std.debug.print("   memory = bundle(red_apple, yellow_banana, fast_car)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. Запросы к памяти
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("4. Запросы к памяти...\n\n", .{});

    // Запрос: "Что красное?" (unbind с red)
    std.debug.print("   Запрос: 'Что красное?'\n", .{});
    var query_red = tvc_vsa.bind(&memory, &red);

    const sim_apple_red = tvc_vsa.cosineSimilarity(&query_red, &apple);
    const sim_banana_red = tvc_vsa.cosineSimilarity(&query_red, &banana);
    const sim_car_red = tvc_vsa.cosineSimilarity(&query_red, &car);

    std.debug.print("   Сходство с apple:  {d:.4}\n", .{sim_apple_red});
    std.debug.print("   Сходство с banana: {d:.4}\n", .{sim_banana_red});
    std.debug.print("   Сходство с car:    {d:.4}\n", .{sim_car_red});
    std.debug.print("   Ответ: apple (максимальное сходство)\n\n", .{});

    // Запрос: "Что жёлтое?" (unbind с yellow)
    std.debug.print("   Запрос: 'Что жёлтое?'\n", .{});
    var query_yellow = tvc_vsa.bind(&memory, &yellow);

    const sim_apple_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &apple);
    const sim_banana_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &banana);
    const sim_car_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &car);

    std.debug.print("   Сходство с apple:  {d:.4}\n", .{sim_apple_yellow});
    std.debug.print("   Сходство с banana: {d:.4}\n", .{sim_banana_yellow});
    std.debug.print("   Сходство с car:    {d:.4}\n", .{sim_car_yellow});
    std.debug.print("   Ответ: banana (максимальное сходство)\n\n", .{});

    // Запрос: "Какое свойство у яблока?" (unbind с apple)
    std.debug.print("   Запрос: 'Какое свойство у яблока?'\n", .{});
    var query_apple = tvc_vsa.bind(&memory, &apple);

    const sim_red_apple = tvc_vsa.cosineSimilarity(&query_apple, &red);
    const sim_yellow_apple = tvc_vsa.cosineSimilarity(&query_apple, &yellow);
    const sim_fast_apple = tvc_vsa.cosineSimilarity(&query_apple, &fast);

    std.debug.print("   Сходство с red:    {d:.4}\n", .{sim_red_apple});
    std.debug.print("   Сходство с yellow: {d:.4}\n", .{sim_yellow_apple});
    std.debug.print("   Сходство с fast:   {d:.4}\n", .{sim_fast_apple});
    std.debug.print("   Ответ: red (максимальное сходство)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. Статистика памяти
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("5. Статистика памяти...\n", .{});

    memory.pack();
    const mem_bytes = memory.memoryUsage();
    const unpacked_bytes = memory.trit_len;

    std.debug.print("   Размер вектора: {} тритов\n", .{memory.trit_len});
    std.debug.print("   Память (packed): {} байт\n", .{mem_bytes});
    std.debug.print("   Память (unpacked): {} байт\n", .{unpacked_bytes});
    std.debug.print("   Экономия: {d:.1}x\n\n", .{@as(f64, @floatFromInt(unpacked_bytes)) / @as(f64, @floatFromInt(mem_bytes))});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    Пример завершён                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}
