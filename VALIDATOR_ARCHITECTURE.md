# VIBEE VALIDATOR ARCHITECTURE - ФАЗА 2.1

## АРХИТЕКТУРНАЯ ПОДГОТОВКА

### 2.1.1 Модульная Архитектура Валидатора

```
┌─────────────────────────────────────────────────────────────────────┐
│                     VALIDATOR ENGINE                        │
│                  (Оркестратор 33 Богатырей)                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────┴────┐        ┌────┴────┐        ┌────┴────┐
    │  STAGE 1 │        │  STAGE 2 │        │  STAGE 3 │
    │  PARSER  │        │  SEMANTIC│        │  ANALYSIS│
    └────┬─────┘        └────┬─────┘        └────┬─────┘
         │                   │                   │
    ┌────┴───────────────────┴───────────────────┴────┐
    │              BOGATYR PLUGIN SYSTEM               │
    │    (Регистрация и вызов 33 богатырей)        │
    └──────────────────────┬────────────────────────┘
                           │
    ┌──────────────────────┼─────────────────────────────┐
    │                      │                             │
┌───┴────┐          ┌────┴────┐              ┌──────┴──────┐
│SYNTAX   │          │SEMANTIC  │              │LOGIC        │
│SQUAD    │          │SQUAD     │              │& INVARIANTS │
└─────────┘          └──────────┘              └──────────────┘
    │                      │                            │
  [5]                    [7]                         [8]
 bogatyrs              bogatyrs                    bogatyrs
```

### 2.1.2 Интерфейс Модуля-Богатыря

```zig
// src/vibeec/validator/bogatyr_interface.zig

const std = @import("std");

/// Контекст валидации - общие данные для всех богатырей
pub const ValidationContext = struct {
    allocator: std.mem.Allocator,
    spec_path: []const u8,
    source: []const u8,
    ast: *const Ast,      // AST из парсера
    symbol_table: *const SymbolTable,  // Таблица символов
    config: ValidatorConfig,
};

/// Конфигурация валидатора
pub const ValidatorConfig = struct {
    strict_mode: bool = false,           // Строгий режим (все ошибки)
    warning_as_error: bool = false,     # Предупреждения как ошибки
    cache_enabled: bool = true,         # Кэширование результатов
    parallel_enabled: bool = true,      # Параллельная валидация
    timeout_ms: u32 = 30000,           # Таймаут на валидацию
};

/// Результат проверки богатыря
pub const BogatyrVerdict = enum {
    Pass,           // ✅ Проверка прошла
    Fail,           // ❌ Проверка не прошла
    Warning,        // ⚠️ Предупреждение
    Skip,           // ⊘ Богатырь пропущен (например, не применим)
};

/// Ошибка валидации
pub const ValidationError = struct {
    code: []const u8,            // Код ошибки
    message: []const u8,         // Сообщение
    severity: BogatyrVerdict,    // Серьезность
    line: usize,                 // Номер строки
    column: usize,               // Номер колонки
    source_span: SourceSpan,     # Диапазон в исходном коде
    fix_hint: ?[]const u8,     // Подсказка для исправления
    metadata: ?[]const u8,      // Метаданные (JSON)
};

/// Метрики выполнения богатыря
pub const BogatyrMetrics = struct {
    duration_ns: i64,          // Время выполнения (наносекунды)
    memory_used: usize,         // Используемая память (байты)
    cache_hits: usize,          # Хиты кэша
    cache_misses: usize,        # Промахи кэша
    checks_performed: usize,     # Количество выполненных проверок
};

/// Интерфейс Богатыря
pub const BogatyrPlugin = struct {
    name: []const u8,               // Имя богатыря
    version: []const u8,            // Версия
    category: []const u8,           // Категория (syntax, semantic, logic, etc.)
    priority: u32,                 // Приоритет (меньше = раньше)
    dependencies: [][]const u8,      // Зависимости от других богатырей
    
    // Функция валидации
    validate: *const fn (*const ValidationContext) !BogatyrResult,
    
    // PAS DAEMONS метрики
    pas_performance: ?PASPerformance,
    pas_architecture: ?PASArchitecture,
    pas_security: ?PASSecurity,
    // ... остальные PAS метрики
};

/// Результат работы богатыря
pub const BogatyrResult = struct {
    verdict: BogatyrVerdict,
    errors: []const ValidationError,
    metrics: BogatyrMetrics,
    dependencies_satisfied: bool,
};

/// PAS DAEMONS - Performance
pub const PASPerformance = struct {
    latency_target_ms: f64,         // Целевая задержка
    throughput_target_ops: f64,      // Целевая пропускная способность
    resource_limit_mb: usize,        // Лимит ресурсов (МБ)
};

/// PAS DAEMONS - Architecture
pub const PASArchitecture = struct {
    modularity_score: f64,          // Оценка модульности (0-1)
    coupling_score: f64,             // Оценка связности (0-1, меньше = лучше)
    scalability: enum {
        None,
        Vertical,
        Horizontal,
        Auto,
    },
};

/// PAS DAEMONS - Security
pub const PASSecurity = struct {
    checks_injection: bool,          // Проверка инъекций
    checks_authz: bool,            # Проверка авторизации
    checks_data_leaks: bool,       # Проверка утечек данных
    vulnerability_scan: bool,       # Сканер уязвимостей
};
```

### 2.1.3 Контракты для Каждей Категории Богатырей

#### ОТРЯД СИНТАКСИСА (5 богатырей)
```zig
// Пример: Богатырь Синтаксического Парсера
const syntax_parser_bogatyr = BogatyrPlugin{
    .name = "syntax_parser",
    .version = "1.0.0",
    .category = "syntax",
    .priority = 1,  // Самый высокий приоритет
    .dependencies = &[_][]const u8{},  // Нет зависимостей
    .pas_performance = PASPerformance{
        .latency_target_ms = 10,
        .throughput_target_ops = 1000,
        .resource_limit_mb = 10,
    },
    .pas_architecture = PASArchitecture{
        .modularity_score = 0.95,
        .coupling_score = 0.05,
        .scalability = .None,
    },
    .pas_security = null,  // Не применимо
    .validate = validateSyntax,
};

fn validateSyntax(ctx: *const ValidationContext) !BogatyrResult {
    const start_time = std.time.nanoTimestamp();
    
    // Валидация YAML синтаксиса
    var errors = std.ArrayList(ValidationError).init(ctx.allocator);
    defer errors.deinit();
    
    // Парсинг и проверка...
    // ...
    
    const end_time = std.time.nanoTimestamp();
    
    return BogatyrResult{
        .verdict = if (errors.items.len > 0) .Fail else .Pass,
        .errors = try ctx.allocator.dupe(ValidationError, errors.items),
        .metrics = BogatyrMetrics{
            .duration_ns = end_time - start_time,
            .memory_used = 0,  // TODO
            .cache_hits = 0,
            .cache_misses = 0,
            .checks_performed = errors.items.len + 1,
        },
        .dependencies_satisfied = true,
    };
}
```

#### ОТРЯД СЕМАНТИКИ (7 богатырей)
```zig
// Пример: Богатырь Проверки Типов
const type_validator_bogatyr = BogatyrPlugin{
    .name = "type_validation",
    .version = "1.0.0",
    .category = "semantic",
    .priority = 2,
    .dependencies = &[_][]const u8{"syntax_parser"},  // Зависит от парсера
    .pas_performance = PASPerformance{
        .latency_target_ms = 50,
        .throughput_target_ops = 500,
        .resource_limit_mb = 50,
    },
    .pas_architecture = PASArchitecture{
        .modularity_score = 0.90,
        .coupling_score = 0.10,
        .scalability = .Vertical,
    },
    .pas_security = null,
    .validate = validateTypes,
};

fn validateTypes(ctx: *const ValidationContext) !BogatyrResult {
    // Используем ctx.symbol_table для проверки типов
    // ...
}
```

### 2.1.4 Реестр Богатырей

```zig
// src/vibeec/validator/bogatyr_registry.zig

/// Реестр всех богатырей
pub const BogatyrRegistry = struct {
    allocator: std.mem.Allocator,
    plugins: std.StringHashMap(BogatyrPlugin),
    
    pub fn init(allocator: std.mem.Allocator) !Self {
        var registry = Self{
            .allocator = allocator,
            .plugins = std.StringHashMap(BogatyrPlugin).init(allocator),
        };
        
        // Регистрация богатырей
        try registry.register(syntax_parser_bogatyr);
        try registry.register(lexer_bogatyr);
        try registry.register(spec_structure_bogatyr);
        try registry.register(naming_conventions_bogatyr);
        try registry.register(cyclic_deps_bogatyr);
        
        try registry.register(type_validation_bogatyr);
        // ... и так далее для всех 33
        
        return registry;
    }
    
    pub fn register(self: *Self, plugin: BogatyrPlugin) !void {
        try self.plugins.put(plugin.name, plugin);
    }
    
    pub fn get(self: *Self, name: []const u8) ?BogatyrPlugin {
        return self.plugins.get(name);
    }
    
    pub fn getByCategory(self: *Self, category: []const u8) ![]BogatyrPlugin {
        var result = std.ArrayList(BogatyrPlugin).init(self.allocator);
        errdefer result.deinit();
        
        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.category, category)) {
                try result.append(entry.value_ptr.*);
            }
        }
        
        return result.toOwnedSlice();
    }
    
    pub fn getAll(self: *Self) ![]BogatyrPlugin {
        var result = std.ArrayList(BogatyrPlugin).init(self.allocator);
        errdefer result.deinit();
        
        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            try result.append(entry.value_ptr.*);
        }
        
        return result.toOwnedSlice();
    }
};
```

### 2.1.5 Оркестратор Валидации

```zig
// src/vibeec/validator/orchestrator.zig

pub const ValidatorOrchestrator = struct {
    allocator: std.mem.Allocator,
    registry: BogatyrRegistry,
    config: ValidatorConfig,
    
    pub fn run(self: *Self, spec_path: []const u8) !ValidationReport {
        // Stage 1: Parse
        const ast = try self.parse(spec_path);
        
        // Stage 2: Semantic Analysis
        const symbol_table = try self.analyzeSemantics(&ast);
        
        // Stage 3: Run all bogatyrs
        const context = ValidationContext{
            .allocator = self.allocator,
            .spec_path = spec_path,
            .source = try std.fs.cwd().readFileAlloc(self.allocator, spec_path, 1024*1024),
            .ast = &ast,
            .symbol_table = &symbol_table,
            .config = self.config,
        };
        
        var all_plugins = try self.registry.getAll();
        defer self.allocator.free(all_plugins);
        
        var all_errors = std.ArrayList(ValidationError).init(self.allocator);
        var all_metrics = std.ArrayList(BogatyrMetrics).init(self.allocator);
        
        // Топологическая сортировка по зависимостям
        const sorted = try self.topologicalSort(all_plugins);
        
        // Запуск богатырей (параллельно если включено)
        for (sorted) |plugin| {
            const result = try plugin.validate(&context);
            
            for (result.errors) |err| {
                try all_errors.append(err);
            }
            try all_metrics.append(result.metrics);
        }
        
        return ValidationReport{
            .errors = try all_errors.toOwnedSlice(),
            .metrics = try all_metrics.toOwnedSlice(),
            .verdict = if (all_errors.items.len > 0) .Fail else .Pass,
        };
    }
    
    fn topologicalSort(self: *Self, plugins: []BogatyrPlugin) ![]BogatyrPlugin {
        // Kahn's algorithm для топологической сортировки
        // ...
    }
};

pub const ValidationReport = struct {
    verdict: BogatyrVerdict,
    errors: []const ValidationError,
    metrics: []const BogatyrMetrics,
};
```

---

## ФАЗА 2.1.3 Спецификация Ядра Валидатора

Теперь создам .vibee спецификацию для ядра валидатора, которое будет оркестрировать вызовы богатырей.
