// ═══════════════════════════════════════════════════════════════════════════════
// GEN999 — Генератор 999 глав из спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Создаёт .999 файлы в 999/ⲕⲛⲓⲅⲁ/ из specs/999_chapters/*.vibee
//
// Author: Dmitrii Vasilev <reactnativeinitru@gmail.com>
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const PI: f64 = 3.14159265358979323846;
const PHI: f64 = 1.61803398874989484820;

const Volume = struct {
    number: u32,
    name_ru: []const u8,
    name_en: []const u8,
    color: []const u8,
    theme: []const u8,
    start_chapter: u32,
    end_chapter: u32,
};

const Book = struct {
    number: u32,
    title: []const u8,
    start_chapter: u32,
    end_chapter: u32,
};

const volumes = [_]Volume{
    .{ .number = 1, .name_ru = "Медное Царство", .name_en = "Copper Kingdom", .color = "#B87333", .theme = "Теория", .start_chapter = 1, .end_chapter = 333 },
    .{ .number = 2, .name_ru = "Серебряное Царство", .name_en = "Silver Kingdom", .color = "#C0C0C0", .theme = "Практика", .start_chapter = 334, .end_chapter = 666 },
    .{ .number = 3, .name_ru = "Золотое Царство", .name_en = "Golden Kingdom", .color = "#FFD700", .theme = "Будущее", .start_chapter = 667, .end_chapter = 999 },
};

const books = [_]Book{
    // Том 1
    .{ .number = 1, .title = "Начало Пути", .start_chapter = 1, .end_chapter = 37 },
    .{ .number = 2, .title = "Число Три", .start_chapter = 38, .end_chapter = 74 },
    .{ .number = 3, .title = "Константы Вселенной", .start_chapter = 75, .end_chapter = 111 },
    .{ .number = 4, .title = "Троичная Логика", .start_chapter = 112, .end_chapter = 148 },
    .{ .number = 5, .title = "Структуры Данных", .start_chapter = 149, .end_chapter = 185 },
    .{ .number = 6, .title = "Квантовые Кутриты", .start_chapter = 186, .end_chapter = 222 },
    .{ .number = 7, .title = "Нейронные Сети", .start_chapter = 223, .end_chapter = 259 },
    .{ .number = 8, .title = "Криптография", .start_chapter = 260, .end_chapter = 296 },
    .{ .number = 9, .title = "Завершение Теории", .start_chapter = 297, .end_chapter = 333 },
    // Том 2
    .{ .number = 10, .title = "Trinity Sort", .start_chapter = 334, .end_chapter = 370 },
    .{ .number = 11, .title = "Trinity Search", .start_chapter = 371, .end_chapter = 407 },
    .{ .number = 12, .title = "Trinity Compress", .start_chapter = 408, .end_chapter = 444 },
    .{ .number = 13, .title = "Язык VIBEE", .start_chapter = 445, .end_chapter = 481 },
    .{ .number = 14, .title = "Компилятор 999", .start_chapter = 482, .end_chapter = 518 },
    .{ .number = 15, .title = "Runtime HTML", .start_chapter = 519, .end_chapter = 555 },
    .{ .number = 16, .title = "PAS Методология", .start_chapter = 556, .end_chapter = 592 },
    .{ .number = 17, .title = "Бенчмарки", .start_chapter = 593, .end_chapter = 629 },
    .{ .number = 18, .title = "Завершение Практики", .start_chapter = 630, .end_chapter = 666 },
    // Том 3
    .{ .number = 19, .title = "999 OS", .start_chapter = 667, .end_chapter = 703 },
    .{ .number = 20, .title = "ЖАР-ПТИЦА", .start_chapter = 704, .end_chapter = 740 },
    .{ .number = 21, .title = "50 Языков", .start_chapter = 741, .end_chapter = 777 },
    .{ .number = 22, .title = "Квантовое Будущее", .start_chapter = 778, .end_chapter = 814 },
    .{ .number = 23, .title = "Космическая Интеграция", .start_chapter = 815, .end_chapter = 851 },
    .{ .number = 24, .title = "Сознание", .start_chapter = 852, .end_chapter = 888 },
    .{ .number = 25, .title = "Эволюция", .start_chapter = 889, .end_chapter = 925 },
    .{ .number = 26, .title = "Трансценденция", .start_chapter = 926, .end_chapter = 962 },
    .{ .number = 27, .title = "OMEGA", .start_chapter = 963, .end_chapter = 999 },
};

const fairy_openings = [_][]const u8{
    "В тридевятом царстве, в тридесятом государстве жил-был программист...",
    "Жил-был программист по имени Иван, и было у него три задачи...",
    "Давным-давно, когда компьютеры ещё говорили на языке единиц и нулей...",
    "За тридевять земель, за тридевять морей стоял терем алгоритмов...",
    "В некотором царстве, в некотором государстве правил царь-процессор...",
    "Было у царя три сына-программиста: старший, средний и младший...",
    "Жила-была функция рекурсивная, и звали её Фибоначчи...",
    "Стоял на распутье камень, а на камне написано было три пути...",
    "Текла река данных через три царства: Медное, Серебряное и Золотое...",
    "Отправился Иван-программист в путь-дорогу искать оптимальный алгоритм...",
    "Пришла к Ивану задача непростая, да делать нечего — надо решать...",
    "Призвал царь-заказчик Ивана и дал ему задачу невыполнимую...",
    "Напал на царство Кощей-баг бессмертный, и никто не мог его победить...",
    "Три дня и три ночи бился Иван с задачей, да всё без толку...",
    "Нашёл Иван перо Жар-птицы, а на нём код волшебный написан...",
    "Спустился Иван в подземелье памяти, где хранились данные древние...",
    "Взлетел Иван на ковре-самолёте async в облака вычислений...",
    "Достал Иван меч-кладенец оптимизации и пошёл на Змея-Горыныча...",
    "Однажды Иван заглянул в код древний и увидел там чудо чудное...",
    "Открыл Иван книгу мудрости и прочёл там слова заветные...",
    "Явилась Ивану во сне Василиса Премудрая и молвила...",
    "Встретил Иван старца-архитектора, и тот поведал ему тайну...",
    "Росло в саду дерево алгоритмов, и на каждой ветке — решение...",
    "Собрались три богатыря-алгоритма: QuickSort, MergeSort и TrinitySort...",
    "Летела Жар-птица над царством кода, роняя перья мудрости...",
    "Встретил Иван Бабу-Ягу legacy-кода, и та дала ему клубок рефакторинга...",
    "И понял Иван великую тайну Тройки, что правит всем миром...",
};

fn getVolume(chapter: u32) Volume {
    for (volumes) |v| {
        if (chapter >= v.start_chapter and chapter <= v.end_chapter) {
            return v;
        }
    }
    return volumes[2];
}

fn getBook(chapter: u32) Book {
    for (books) |b| {
        if (chapter >= b.start_chapter and chapter <= b.end_chapter) {
            return b;
        }
    }
    return books[26];
}

fn calculateSacredValue(chapter: u32) struct { n: u32, k: u32, value: f64 } {
    // 999 = 37 × 27 = 37 × 3³
    // Раскладываем номер главы на n × 3^k
    var k: u32 = 0;
    var n = chapter;
    
    while (n % 3 == 0 and n > 0) {
        n /= 3;
        k += 1;
    }
    
    const value = @as(f64, @floatFromInt(n)) * std.math.pow(f64, 3.0, @as(f64, @floatFromInt(k)));
    return .{ .n = n, .k = k, .value = value };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const output_base = "999/ⲕⲛⲓⲅⲁ";
    
    // Создаём директории
    const dirs = [_][]const u8{
        "999/ⲕⲛⲓⲅⲁ/ⲧⲟⲙ_1_ⲙⲉⲇⲛⲟⲉ",
        "999/ⲕⲛⲓⲅⲁ/ⲧⲟⲙ_2_ⲥⲉⲣⲉⲃⲣⲟ",
        "999/ⲕⲛⲓⲅⲁ/ⲧⲟⲙ_3_ⲍⲟⲗⲟⲧⲟ",
    };
    
    for (dirs) |dir| {
        std.fs.cwd().makePath(dir) catch {};
    }

    var generated: u32 = 0;
    
    for (1..1000) |i| {
        const chapter: u32 = @intCast(i);
        const volume = getVolume(chapter);
        const book = getBook(chapter);
        const sacred = calculateSacredValue(chapter);
        const fairy_idx = (chapter - 1) % 27;
        
        // Определяем путь
        const vol_dir = switch (volume.number) {
            1 => "ⲧⲟⲙ_1_ⲙⲉⲇⲛⲟⲉ",
            2 => "ⲧⲟⲙ_2_ⲥⲉⲣⲉⲃⲣⲟ",
            else => "ⲧⲟⲙ_3_ⲍⲟⲗⲟⲧⲟ",
        };
        
        const filename = try std.fmt.allocPrint(allocator, "{s}/{s}/chapter_{d:0>3}.999", .{ output_base, vol_dir, chapter });
        defer allocator.free(filename);
        
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        
        const writer = file.writer();
        
        // Записываем .999 код
        try writer.print(
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\// ГЛАВА {d} — {s}
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\// Том {d}: {s} | Книга {d}: {s}
            \\// Священная Формула: V = {d} × 3^{d} = {d:.4}
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\
            \\ⲙⲟⲇⲩⲗⲉ ⲕⲛⲓⲅⲁ.ⲅⲗⲁⲃⲁ_{d:0>3};
            \\
            \\// Священные константы
            \\ⲕⲟⲛⲥⲧ π = 3.14159265358979323846;
            \\ⲕⲟⲛⲥⲧ φ = 1.61803398874989484820;
            \\ⲕⲟⲛⲥⲧ CHAPTER = {d};
            \\ⲕⲟⲛⲥⲧ VOLUME = {d};
            \\ⲕⲟⲛⲥⲧ BOOK = {d};
            \\
            \\// Тождества
            \\// φ² + 1/φ² = 3 (точно!)
            \\// φ = 2cos(π/5) (точно!)
            \\
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\// СКАЗОЧНЫЙ ЗАЧИН
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\
            \\ⲥⲕⲁⲍⲕⲁ {{
            \\    "{s}"
            \\}}
            \\
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\// СВЯЩЕННАЯ ФОРМУЛА
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\
            \\ⲫⲟⲣⲙⲩⲗⲁ sacred_value() -> f64 {{
            \\    ⲣⲉⲧⲩⲣⲛ {d} * ⲡⲟⲱ(3, {d});  // V = {d} × 3^{d} = {d:.4}
            \\}}
            \\
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\// СОДЕРЖАНИЕ ГЛАВЫ
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\
            \\ⲥⲧⲣⲩⲕⲧ Chapter {{
            \\    number: u32,
            \\    volume: u32,
            \\    book: u32,
            \\    sacred_value: f64,
            \\    
            \\    // Три системы восприятия
            \\    intuition: f64,   // 20%
            \\    analysis: f64,    // 60%
            \\    synthesis: f64,   // 20%
            \\}}
            \\
            \\ⲫⲩⲛⲕ create_chapter() -> Chapter {{
            \\    ⲣⲉⲧⲩⲣⲛ Chapter {{
            \\        .number = {d},
            \\        .volume = {d},
            \\        .book = {d},
            \\        .sacred_value = sacred_value(),
            \\        .intuition = 0.20,
            \\        .analysis = 0.60,
            \\        .synthesis = 0.20,
            \\    }};
            \\}}
            \\
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\// МУДРОСТЬ ГЛАВЫ
            \\// ═══════════════════════════════════════════════════════════════════════════════
            \\
            \\ⲙⲩⲇⲣⲟⲥⲧⲩ {{
            \\    "И понял Иван-программист {d}-ю истину: всё в мире подчиняется Тройке."
            \\}}
            \\
            \\// Конец главы {d}
            \\
        , .{
            chapter, book.title,
            volume.number, volume.name_ru, book.number, book.title,
            sacred.n, sacred.k, sacred.value,
            chapter,
            chapter, volume.number, book.number,
            fairy_openings[fairy_idx],
            sacred.n, sacred.k, sacred.n, sacred.k, sacred.value,
            chapter, volume.number, book.number,
            chapter,
            chapter,
        });
        
        generated += 1;
    }
    
    std.debug.print("✅ Сгенерировано {d} глав .999\n", .{generated});
    std.debug.print("   Том 1 (Медное): главы 1-333\n", .{});
    std.debug.print("   Том 2 (Серебряное): главы 334-666\n", .{});
    std.debug.print("   Том 3 (Золотое): главы 667-999\n", .{});
}
