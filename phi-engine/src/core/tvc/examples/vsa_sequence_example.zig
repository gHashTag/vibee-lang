// VSA Sequence Encoding Example
// Демонстрация кодирования последовательностей с помощью permute
//
// Запуск: zig run vsa_sequence_example.zig

const std = @import("std");
const tvc_vsa = @import("../tvc_vsa.zig");
const HybridBigInt = tvc_vsa.HybridBigInt;

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         VSA Sequence Encoding Example                        ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. Создаём словарь слов
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("1. Создание словаря слов...\n", .{});

    var the = tvc_vsa.randomVector(256, 100);
    var cat = tvc_vsa.randomVector(256, 101);
    var sat = tvc_vsa.randomVector(256, 102);
    var on = tvc_vsa.randomVector(256, 103);
    var mat = tvc_vsa.randomVector(256, 104);
    var dog = tvc_vsa.randomVector(256, 105);
    var ran = tvc_vsa.randomVector(256, 106);

    std.debug.print("   Слова: the, cat, sat, on, mat, dog, ran\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. Кодируем предложение "the cat sat"
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("2. Кодирование предложения 'the cat sat'...\n", .{});
    std.debug.print("   Формула: sentence = word[0] + permute(word[1], 1) + permute(word[2], 2)\n\n", .{});

    // Ручное кодирование для демонстрации
    var p0 = the; // permute(the, 0) = the
    var p1 = tvc_vsa.permute(&cat, 1);
    var p2 = tvc_vsa.permute(&sat, 2);

    var temp = p0.add(&p1);
    var sentence1 = temp.add(&p2);

    std.debug.print("   sentence1 = the + permute(cat, 1) + permute(sat, 2)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. Проверяем позиции слов в предложении
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("3. Проверка позиций слов в 'the cat sat'...\n\n", .{});

    // Проверяем "the" на разных позициях
    std.debug.print("   Слово 'the':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &the, pos);
        const marker = if (pos == 0) " <-- правильная позиция" else "";
        std.debug.print("     позиция {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    std.debug.print("\n   Слово 'cat':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &cat, pos);
        const marker = if (pos == 1) " <-- правильная позиция" else "";
        std.debug.print("     позиция {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    std.debug.print("\n   Слово 'sat':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &sat, pos);
        const marker = if (pos == 2) " <-- правильная позиция" else "";
        std.debug.print("     позиция {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. Кодируем второе предложение "the dog ran"
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("\n4. Кодирование предложения 'the dog ran'...\n", .{});

    var items2 = [_]HybridBigInt{ the, dog, ran };
    var sentence2 = tvc_vsa.encodeSequence(&items2);

    std.debug.print("   sentence2 = encodeSequence([the, dog, ran])\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. Сравниваем предложения
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("5. Сравнение предложений...\n", .{});

    const sim_sentences = tvc_vsa.cosineSimilarity(&sentence1, &sentence2);
    std.debug.print("   Сходство 'the cat sat' и 'the dog ran': {d:.4}\n", .{sim_sentences});
    std.debug.print("   (Оба начинаются с 'the', поэтому есть некоторое сходство)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 6. Демонстрация permute/inverse_permute
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("6. Демонстрация permute/inverse_permute...\n", .{});

    var original = tvc_vsa.randomVector(256, 999);
    var shifted = tvc_vsa.permute(&original, 7);
    var recovered = tvc_vsa.inversePermute(&shifted, 7);

    const sim_original = tvc_vsa.cosineSimilarity(&original, &recovered);
    std.debug.print("   original -> permute(7) -> inverse_permute(7) -> recovered\n", .{});
    std.debug.print("   Сходство original и recovered: {d:.4}\n", .{sim_original});
    std.debug.print("   (Должно быть ~1.0, т.к. inverse_permute отменяет permute)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 7. Ортогональность permuted векторов
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("7. Ортогональность permuted векторов...\n", .{});

    var v = tvc_vsa.randomVector(256, 12345);
    var v_p1 = tvc_vsa.permute(&v, 1);
    var v_p10 = tvc_vsa.permute(&v, 10);
    var v_p50 = tvc_vsa.permute(&v, 50);

    std.debug.print("   Сходство v и permute(v, 1):  {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p1)});
    std.debug.print("   Сходство v и permute(v, 10): {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p10)});
    std.debug.print("   Сходство v и permute(v, 50): {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p50)});
    std.debug.print("   (Permuted векторы почти ортогональны оригиналу)\n\n", .{});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    Пример завершён                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}
