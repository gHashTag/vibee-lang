// VIBEE BOGATYR PLUGIN INTERFACE - Core Validator Architecture
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Контекст валидации - общие данные для всех богатырей
pub const ValidationContext = struct {
    allocator: Allocator,
    spec_path: []const u8,
    source: []const u8,
    config: ValidatorConfig,

    // AST (если уже спарсен)
    ast: ?*const struct {
        nodes: []const AstNode,
    },

    // Таблица символов (если уже построена)
    symbol_table: ?*const struct {
        symbols: std.StringHashMap(Symbol),
    },
};

pub const ValidatorConfig = struct {
    strict_mode: bool = false,
    warning_as_error: bool = false,
    cache_enabled: bool = true,
    parallel_enabled: bool = true,
    timeout_ms: u32 = 30000,
};

/// Результат проверки богатыря
pub const BogatyrVerdict = enum {
    Pass, // ✅ Проверка прошла
    Fail, // ❌ Проверка не прошла
    Warning, // ⚠️ Предупреждение
    Skip, // ⊘ Богатырь пропущен
};

/// Ошибка валидации
pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    severity: BogatyrVerdict,
    line: usize,
    column: usize,
};

/// Метрики выполнения богатыря
pub const BogatyrMetrics = struct {
    duration_ns: i64,
    checks_performed: usize,
};

/// Интерфейс Богатыря - каждый богатырь реализует этот трейт
pub const BogatyrPlugin = struct {
    name: []const u8,
    version: []const u8,
    category: []const u8,
    priority: u32,

    /// Функция валидации - реализуется каждым богатырем
    validate: *const fn (*const ValidationContext) anyerror!BogatyrResult,
};

/// Результат работы богатыря
pub const BogatyrResult = struct {
    verdict: BogatyrVerdict,
    errors: []const ValidationError,
    metrics: BogatyrMetrics,
};

/// Вспомогательные типы
pub const AstNode = struct {
    kind: []const u8,
    value: ?[]const u8,
    line: usize,
};

pub const Symbol = struct {
    name: []const u8,
    kind: []const u8,
    line: usize,
};

/// Создает ошибку валидации
pub fn createError(allocator: Allocator, code: []const u8, message: []const u8, line: usize, column: usize) !ValidationError {
    return ValidationError{
        .code = try allocator.dupe(u8, code),
        .message = try allocator.dupe(u8, message),
        .severity = .Fail,
        .line = line,
        .column = column,
    };
}
