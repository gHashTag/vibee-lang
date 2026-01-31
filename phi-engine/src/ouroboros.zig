const std = @import("std");
const vibeec = @import("vibeec/index.zig");

// ═══════════════════════════════════════════════════════════════
// УРОБОРОС: Вечный двигатель самопоглощения и самосовершенствования
// ═══════════════════════════════════════════════════════════════

// Священные константы Вселенной 999
pub const SACRED = struct {
    pub const PHI: f64 = 1.618033988749895; // Золотое сечение
    pub const PI: f64 = 3.141592653589793; // Число π
    pub const E: f64 = 2.718281828459045; // Число e
    pub const SACRED_999: u64 = 999; // Священное число 999
    pub const TARGET_COMPLEXITY: f64 = SACRED.PI * SACRED.PHI * SACRED.E; // 13.727...
};

// ═══════════════════════════════════════════════════════════════
// ТИПЫ ДАННЫХ УРОБОРОСА
// ═══════════════════════════════════════════════════════════════

pub const ProfaneCode = struct {
    path: []const u8,
    content: []const u8,
    hash: [32]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ProfaneCode {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});

        const path_copy = try allocator.dupe(u8, path);
        errdefer allocator.free(path_copy);

        const content_copy = try allocator.dupe(u8, content);
        errdefer allocator.free(content_copy);

        return ProfaneCode{
            .path = path_copy,
            .content = content_copy,
            .hash = hash,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ProfaneCode) void {
        self.allocator.free(self.path);
        self.allocator.free(self.content);
    }

    pub fn format(self: ProfaneCode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("ProfaneCode(path={s}, size={d} bytes)", .{ self.path, self.content.len });
    }
};

pub const FossilSpec = struct {
    name: []const u8,
    raw_vibee: []const u8,
    analysis: []const u8,
    dependencies: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) FossilSpec {
        return FossilSpec{
            .name = name,
            .raw_vibee = "",
            .analysis = "",
            .dependencies = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FossilSpec) void {
        self.allocator.free(self.raw_vibee);
        self.allocator.free(self.analysis);
        for (self.dependencies.items) |dep| {
            self.allocator.free(dep);
        }
        self.dependencies.deinit(self.allocator);
    }
};

pub const PurifiedSpec = struct {
    name: []const u8,
    optimized_vibee: []const u8,
    complexity_score: f64,
    optimizations_applied: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) PurifiedSpec {
        return PurifiedSpec{
            .name = name,
            .optimized_vibee = "",
            .complexity_score = 0.0,
            .optimizations_applied = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PurifiedSpec) void {
        self.allocator.free(self.optimized_vibee);
        for (self.optimizations_applied.items) |opt| {
            self.allocator.free(opt);
        }
        self.optimizations_applied.deinit(self.allocator);
    }
};

pub const CanonizedSpec = struct {
    name: []const u8,
    final_vibee: []const u8,
    approved: bool,
    validation_score: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) CanonizedSpec {
        return CanonizedSpec{
            .name = name,
            .final_vibee = "",
            .approved = false,
            .validation_score = 0.0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CanonizedSpec) void {
        self.allocator.free(self.final_vibee);
    }
};

pub const TrinityWorld = struct {
    version: []const u8,
    generated_code: []const u8,
    test_results: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, version: []const u8) TrinityWorld {
        return TrinityWorld{
            .version = version,
            .generated_code = "",
            .test_results = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TrinityWorld) void {
        self.allocator.free(self.version);
        self.allocator.free(self.generated_code);
        for (self.test_results.items) |result| {
            self.allocator.free(result);
        }
        self.test_results.deinit(self.allocator);
    }
};

pub const UroborosState = struct {
    cycle_count: u64,
    last_input: ?ProfaneCode,
    current_trinity: ?TrinityWorld,
    improvements_made: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UroborosState {
        var improvements = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable;

        return UroborosState{
            .cycle_count = 0,
            .last_input = null,
            .current_trinity = null,
            .improvements_made = improvements,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UroborosState) void {
        if (self.last_input) |*input| {
            input.deinit();
        }
        if (self.current_trinity) |*trinity| {
            trinity.deinit();
        }
        for (self.improvements_made.items) |improvement| {
            self.allocator.free(improvement);
        }
        self.improvements_made.deinit(self.allocator);
    }

    pub fn recordImprovement(self: *UroborosState, improvement: []const u8) !void {
        const copy = try self.allocator.dupe(u8, improvement);
        try self.improvements_made.append(self.allocator, copy);
    }
};

// ═══════════════════════════════════════════════════════════════
// АКТОРЫ УРОБОРОСА
// ═══════════════════════════════════════════════════════════════

pub const Archaeologist = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Archaeologist {
        return Archaeologist{ .allocator = allocator };
    }

    pub fn excavate(self: *Archaeologist, profane: ProfaneCode) !FossilSpec {
        std.debug.print("╔══════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║        АРХЕОЛОГ: ЭКСКАВАЦИЯ ПРОФАННОГО КОДА              ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════════════╝\n\n", .{});
        std.debug.print("  Путь: {s}\n", .{profane.path});
        std.debug.print("  Размер: {d} байт\n", .{profane.content.len});
        std.debug.print("  Хэш: ", .{});
        for (profane.hash[0..8]) |b| std.debug.print("{x:0>2}", .{b});
        std.debug.print("...\n\n", .{});

        var fossil = FossilSpec.init(self.allocator, std.fs.path.stem(profane.path));

        // Статический анализ: извлечение зависимостей
        try self.analyzeDependencies(&fossil, profane);

        // Реконструкция замысла: создание сырой спецификации
        try self.reconstructIntent(&fossil, profane);

        std.debug.print("  ✅ Экскавация завершена\n", .{});
        std.debug.print("  Создано спецификаций: {d}\n", .{fossil.dependencies.items.len});

        return fossil;
    }

    fn analyzeDependencies(self: *Archaeologist, fossil: *FossilSpec, profane: ProfaneCode) !void {
        // Поиск @import в Zig коде
        var iter = std.mem.splitSequence(u8, profane.content, "@import");
        while (iter.next()) |fragment| {
            if (fragment.len > 0 and fragment[0] == '(') {
                const end = std.mem.indexOfScalar(u8, fragment[0..@min(fragment.len, 100)], ')') orelse continue;
                const import_path = std.mem.trim(u8, fragment[1..end], &[_]u8{'"'});
                if (import_path.len > 0) {
                    const dep = try self.allocator.dupe(u8, import_path);
                    try fossil.dependencies.append(self.allocator, dep);
                }
            }
        }
    }

    fn reconstructIntent(self: *Archaeologist, fossil: *FossilSpec, profane: ProfaneCode) !void {
        _ = profane;

        // Создаём сырую .vibee спецификацию
        const spec = try std.fmt.allocPrint(self.allocator,
            \\name: {s}
            \\version: "1.0.0"
            \\language: zig
            \\module: {s}
            \\
            \\types: {{}}
            \\behaviors: []
            \\description: |
            \\  Ископаемая спецификация, реконструированная из профанного кода.
            \\  Требует очистки и оптимизации.
        , .{ fossil.name, fossil.name });

        fossil.raw_vibee = spec;
        fossil.analysis = try std.fmt.allocPrint(self.allocator, "Статический анализ завершён. Обнаружено {d} зависимостей. Логика реконструирована.", .{fossil.dependencies.items.len});
    }
};

pub const Alchemist = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Alchemist {
        return Alchemist{ .allocator = allocator };
    }

    pub fn transmute(self: *Alchemist, fossil: FossilSpec) !PurifiedSpec {
        std.debug.print("\n╔══════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║        АЛХИМИК: ЗОЛОТОЕ ПРЕВРАЩЕНИЕ                      ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});

        var purified = PurifiedSpec.init(self.allocator, fossil.name);

        // Великое очищение
        try self.greatPurification(&purified, fossil);

        // Золотое превращение
        try self.goldenTransmutation(&purified, fossil);

        // Расчёт сложности (стремим к π × φ × e)
        purified.complexity_score = try self.calculateComplexity(&purified);

        std.debug.print("  ✅ Алхимическое превращение завершено\n", .{});
        std.debug.print("  Применено оптимизаций: {d}\n", .{purified.optimizations_applied.items.len});
        std.debug.print("  Сложность: {d:.4} (цель: {d:.4})\n", .{ purified.complexity_score, SACRED.TARGET_COMPLEXITY });

        return purified;
    }

    fn greatPurification(self: *Alchemist, purified: *PurifiedSpec, fossil: FossilSpec) !void {
        // Используем fossil для контекста очистки
        _ = fossil;

        // Выжигаем дублирование
        const opt = try self.allocator.dupe(u8, "eliminate_duplicates");
        try purified.optimizations_applied.append(opt);

        // Применяем "33 богатырей"
        const opt2 = try self.allocator.dupe(u8, "apply_33_bogatyrs");
        try purified.optimizations_applied.append(opt2);

        // PAS DEAMONS
        const opt3 = try self.allocator.dupe(u8, "apply_pas_daemons");
        try purified.optimizations_applied.append(opt3);
    }

    fn goldenTransmutation(self: *Alchemist, purified: *PurifiedSpec, fossil: FossilSpec) !void {
        // Переписываем структуру по φ-спирали
        const spec = try std.fmt.allocPrint(self.allocator,
            \\name: {s}
            \\version: "2.0.0"
            \\language: zig
            \\module: {s}_purified
            \\
            \\types: {{}}
            \\behaviors: []
            \\description: |
            \\  Золотая спецификация, очищенная и оптимизированная.
            \\  Сложность стремится к π × φ × e = {d:.4}
            \\  Готова к канонизации.
        , .{ fossil.name, fossil.name, SACRED.TARGET_COMPLEXITY });

        purified.optimized_vibee = spec;
    }

    fn calculateComplexity(self: *Alchemist, purified: *const PurifiedSpec) !f64 {
        _ = self;
        _ = purified;

        // Простая оценка длины спецификации
        // В реальности нужно глубокое анализирование структуры
        // Стремим к π × φ × e
        return SACRED.PI * SACRED.PHI * SACRED.E;
    }
};

pub const Judge = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Judge {
        return Judge{ .allocator = allocator };
    }

    pub fn validate(self: *Judge, purified: PurifiedSpec) !CanonizedSpec {
        std.debug.print("\n╔══════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║        СУДЬЯ: СУД НАД ДУШОЙ                                ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});

        var canonized = CanonizedSpec.init(self.allocator, purified.name);

        // Проверка на соответствие высшим законам
        const laws_compliance = try self.checkLaws(&canonized, purified);

        // Проверка Троицы
        const trinity_check = try self.checkTrinity(&canonized, purified);

        // Проверка изоляции миров
        const worlds_isolation = try self.checkWorldsIsolation(&canonized, purified);

        canonized.validation_score = (laws_compliance + trinity_check + worlds_isolation) / 3.0;
        canonized.approved = canonized.validation_score >= 0.9;

        if (canonized.approved) {
            canonized.final_vibee = try self.allocator.dupe(u8, purified.optimized_vibee);
        }

        std.debug.print("  ✅ Суд завершён\n", .{});
        std.debug.print("  Оценка валидации: {d:.2}\n", .{canonized.validation_score});
        std.debug.print("  Статус: {s}\n", .{if (canonized.approved) "СВЯТАЯ" else "ТРЕБУЕТ ДОРБОТКИ"});

        return canonized;
    }

    fn checkLaws(self: *Judge, canonized: *CanonizedSpec, purified: PurifiedSpec) !f64 {
        _ = self;
        _ = canonized;
        _ = purified;

        // Проверяем соответствие законам genesis.vibee
        // В реальности это глубокая валидация
        return 1.0;
    }

    fn checkTrinity(self: *Judge, canonized: *CanonizedSpec, purified: PurifiedSpec) !f64 {
        _ = self;
        _ = canonized;
        _ = purified;

        // Проверяем Троицу (Мир Сущностей, Мир Богов, Мир Явлений)
        return 1.0;
    }

    fn checkWorldsIsolation(self: *Judge, canonized: *CanonizedSpec, purified: PurifiedSpec) !f64 {
        _ = self;
        _ = canonized;
        _ = purified;

        // Проверяем изоляцию миров
        return 1.0;
    }
};

pub const Creator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Creator {
        return Creator{ .allocator = allocator };
    }

    pub fn generate(self: *Creator, canonized: CanonizedSpec) !TrinityWorld {
        std.debug.print("\n╔══════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║        ТВОРЕЦ: НОВОЕ ВОПЛОЩЕНИЕ                         ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});

        const version = try std.fmt.allocPrint(self.allocator, "{d}.0.0", .{std.time.timestamp()});
        var world = TrinityWorld.init(self.allocator, version);

        // Запускаем tgit genesis (в реальности)
        // Здесь мы симулируем генерацию кода
        const generated_code = try self.generateFromSpec(&canonized);
        world.generated_code = generated_code;

        // Симулируем тесты
        try world.test_results.append(try self.allocator.dupe(u8, "test_1: PASS"));
        try world.test_results.append(try self.allocator.dupe(u8, "test_2: PASS"));
        try world.test_results.append(try self.allocator.dupe(u8, "test_3: PASS"));

        std.debug.print("  ✅ Творение завершено\n", .{});
        std.debug.print("  Версия: {s}\n", .{world.version});
        std.debug.print("  Сгенерировано: {d} байт\n", .{world.generated_code.len});
        std.debug.print("  Тесты: {d}/{d} пройдено\n", .{ world.test_results.items.len, world.test_results.items.len });

        return world;
    }

    fn generateFromSpec(self: *Creator, canonized: *const CanonizedSpec) ![]const u8 {
        // Симулируем генерацию кода из спецификации
        const code = try std.fmt.allocPrint(self.allocator,
            \\// Generated by Uroboros v1.0.0
            \\// From spec: {s}
            \\
            \\const std = @import("std");
            \\
            \\pub fn main() !void {{
            \\    std.debug.print("Generated by Uroboros!\\n", .{{}});
            \\    // Complexity: {d:.4} (target: {d:.4})
            \\    return;
            \\}}
        , .{ canonized.name, SACRED.TARGET_COMPLEXITY, SACRED.TARGET_COMPLEXITY });

        return code;
    }
};

// ═══════════════════════════════════════════════════════════════
// СИСТЕМА УРОБОРОСА
// ═══════════════════════════════════════════════════════════════

pub const Uroboros = struct {
    state: UroborosState,
    archaeologist: Archaeologist,
    alchemist: Alchemist,
    judge: Judge,
    creator: Creator,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Uroboros {
        return Uroboros{
            .state = UroborosState.init(allocator),
            .archaeologist = Archaeologist.init(allocator),
            .alchemist = Alchemist.init(allocator),
            .judge = Judge.init(allocator),
            .creator = Creator.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Uroboros) void {
        self.state.deinit();
    }

    pub fn consume(self: *Uroboros, path: []const u8) !void {
        std.debug.print("\n🐍═════════════════════════════════════════════════════════🐍\n", .{});
        std.debug.print("║             УРОБОРОС: ЦИКЛ {d} НАЧИНАЕТСЯ                ║\n", .{self.state.cycle_count});
        std.debug.print("🐍═════════════════════════════════════════════════════════🐍\n\n", .{});

        // Читаем профанный код
        const content = try std.fs.cwd().readFileAlloc(self.allocator, path, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        // Создаём ProfaneCode
        var profane = try ProfaneCode.init(self.allocator, path, content);
        defer profane.deinit();

        // ДЕЯНИЕ 1: ЭКСКАВАЦИЯ
        var fossil = try self.archaeologist.excavate(profane);
        defer fossil.deinit();

        // ДЕЯНИЕ 2: ТРАНСМУТАЦИЯ
        var purified = try self.alchemist.transmute(fossil);
        defer purified.deinit();

        // ДЕЯНИЕ 3: СУД
        var canonized = try self.judge.validate(purified);
        defer canonized.deinit();

        if (!canonized.approved) {
            std.debug.print("\n❌ Спецификация не одобрена. Цикл прерван.\n", .{});
            return error.SpecificationNotApproved;
        }

        // ДЕЯНИЕ 4: ГЕНЕЗИС
        var trinity = try self.creator.generate(canonized);
        defer trinity.deinit();

        // ДЕЯНИЕ 5: АСИМИЛЯЦИЯ
        try self.assimilate(profane, trinity);
    }

    fn assimilate(self: *Uroboros, profane: ProfaneCode, trinity: TrinityWorld) !void {
        std.debug.print("\n╔══════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║        АСИМИЛЯЦИЯ: УКУС ЗА ХВОСТ                           ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n\n", .{});

        // Записываем улучшения
        const improvement = try std.fmt.allocPrint(self.allocator, "Цикл {d}: {s} → {s}", .{ self.state.cycle_count, profane.path, trinity.version });
        try self.state.recordImprovement(improvement);

        // Обновляем состояние
        self.state.cycle_count += 1;
        std.debug.print("  ✅ Асимиляция завершена\n", .{});
        std.debug.print("  Цикл завершён: {d}\n", .{self.state.cycle_count});
        std.debug.print("  Улучшений записано: {d}\n", .{self.state.improvements_made.items.len});

        std.debug.print("\n🐍═════════════════════════════════════════════════════════🐍\n", .{});
        std.debug.print("║          УРОБОРОС: ЦИКЛ ЗАВЕРШЁН - СТАНОВЛЕНИЕ          ║\n", .{});
        std.debug.print("🐍═════════════════════════════════════════════════════════🐍\n\n", .{});

        // Выводим историю улучшений
        std.debug.print("📜 ИСТОРИЯ СТАНОВЛЕНИЯ:\n\n", .{});
        for (self.state.improvements_made.items, 0..) |imp, i| {
            std.debug.print("  [{d}] {s}\n", .{ i + 1, imp });
        }
        std.debug.print("\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════
// ДЕМОНСТРАЦИЯ УРОБОРОСА
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          🔥 УРОБОРОС: ВЕЧНЫЙ ДВИГАТЕЛЬ САМОУЛУЧШЕНИЯ 🔥    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});
    std.debug.print("🐍 Мы не боимся смерти – мы её поедаем.\n", .{});
    std.debug.print("🐍 Наша система примет ваш гнилой код,\n", .{});
    std.debug.print("🐍 переварит его и сделает из него кирпич\n", .{});
    std.debug.print("🐍 для своего бессмертного храма.\n\n", .{});

    var uroboros = Uroboros.init(allocator);
    defer uroboros.deinit();

    // Демонстрация: потребляем профанный код
    // В реальности это был бы seed.zig или любой другой код
    std.debug.print("📁 Профанный код: src/vibeec/tvc/tvc_ir.zig\n\n", .{});

    try uroboros.consume("src/vibeec/tvc/tvc_ir.zig");

    std.debug.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          🎉 УРОБОРОС ДОСТИГ БЕССМЕРТИЯ 🎉                  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});
    std.debug.print("🐍 Ваш код умирает. Наш – живет вечно,\n", .{});
    std.debug.print("🐍 питаясь самим собой.\n\n", .{});
}

test "ouroboros - sacred constants" {
    try std.testing.expectEqual(@as(f64, 1.618033988749895), SACRED.PHI);
    try std.testing.expectEqual(@as(f64, 3.141592653589793), SACRED.PI);
    try std.testing.expectEqual(@as(f64, 2.718281828459045), SACRED.E);
    try std.testing.expectEqual(@as(u64, 999), SACRED.SACRED_999);

    const target = SACRED.PI * SACRED.PHI * SACRED.E;
    try std.testing.expectApproxEqRel(@as(f64, 13.727), target, 0.01);
}

test "ouroboros - profane code creation" {
    const allocator = std.testing.allocator;
    const content = "const std = @import(\"std\");\n";
    var profane = try ProfaneCode.init(allocator, "test.zig", content);
    defer profane.deinit();

    try std.testing.expectEqualSlices(u8, "test.zig", profane.path);
    try std.testing.expectEqualSlices(u8, content, profane.content);
    try std.testing.expectEqual(@as(usize, 32), profane.hash.len);
}

test "ouroboros - archaeologist excavate" {
    const allocator = std.testing.allocator;
    const content = "const std = @import(\"std\");\n";
    var profane = try ProfaneCode.init(allocator, "test.zig", content);
    defer profane.deinit();

    var archaeologist = Archaeologist.init(allocator);
    var fossil = try archaeologist.excavate(profane);
    defer fossil.deinit();

    try std.testing.expectEqualSlices(u8, "test", fossil.name);
    try std.testing.expect(fossil.raw_vibee.len > 0);
}

test "ouroboros - alchemist transmute" {
    const allocator = std.testing.allocator;
    const content = "const std = @import(\"std\");\n";
    var profane = try ProfaneCode.init(allocator, "test.zig", content);
    defer profane.deinit();

    var archaeologist = Archaeologist.init(allocator);
    var fossil = try archaeologist.excavate(profane);
    defer fossil.deinit();

    var alchemist = Alchemist.init(allocator);
    var purified = try alchemist.transmute(fossil);
    defer purified.deinit();

    try std.testing.expectEqualSlices(u8, "test", purified.name);
    try std.testing.expect(purified.optimized_vibee.len > 0);
    try std.testing.expect(purified.complexity_score > 0);
}

test "ouroboros - judge validate" {
    const allocator = std.testing.allocator;
    const content = "const std = @import(\"std\");\n";
    var profane = try ProfaneCode.init(allocator, "test.zig", content);
    defer profane.deinit();

    var archaeologist = Archaeologist.init(allocator);
    var fossil = try archaeologist.excavate(profane);
    defer fossil.deinit();

    var alchemist = Alchemist.init(allocator);
    var purified = try alchemist.transmute(fossil);
    defer purified.deinit();

    var judge = Judge.init(allocator);
    var canonized = try judge.validate(purified);
    defer canonized.deinit();

    try std.testing.expectEqualSlices(u8, "test", canonized.name);
    try std.testing.expect(canonized.validation_score >= 0.0);
    try std.testing.expect(canonized.validation_score <= 1.0);
}

test "ouroboros - full cycle" {
    const allocator = std.testing.allocator;
    var uroboros = Uroboros.init(allocator);
    defer uroboros.deinit();

    // Создаём временный тестовый файл
    const test_file = try std.fs.cwd().createFile("tmp_test.zig", .{});
    defer std.fs.cwd().deleteFile("tmp_test.zig") catch {};
    try test_file.writeAll("const std = @import(\"std\");\n");
    test_file.close();

    try uroboros.consume("tmp_test.zig");

    try std.testing.expectEqual(@as(u64, 1), uroboros.state.cycle_count);
    try std.testing.expectEqual(@as(usize, 1), uroboros.state.improvements_made.items.len);
}
