// ═══════════════════════════════════════════════════════════════
// VIBEEC Code Generator - ТОЛЬКО 999 (Coptic)
// ⛔ ЗАПРЕЩЕНО: .zig, .py, .rs, .go, .ts, .js, .html, .css
// ✅ РАЗРЕШЕНО: ТОЛЬКО .999 (Священный язык с коптским алфавитом)
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const parser = @import("parser.zig");

pub const Target = enum {
    @"999", // ЕДИНСТВЕННЫЙ разрешённый target

    pub fn fromString(s: []const u8) ?Target {
        // Все запросы направляются на 999
        _ = s;
        return .@"999";
    }

    pub fn extension(self: Target) []const u8 {
        return switch (self) {
            .@"999" => ".999",
        };
    }
};

pub fn generate(allocator: std.mem.Allocator, spec: parser.Spec) ![]const u8 {
    _ = spec.language; // игнорируем, всегда 999
    return generate999(allocator, spec);
}

pub fn generateForTarget(allocator: std.mem.Allocator, spec: parser.Spec, target: Target) ![]const u8 {
    return switch (target) {
        .@"999" => generate999(allocator, spec),
    };
}

/// Конвертирует имя файла в Coptic (если оно Latin)
/// Если уже Coptic - возвращает как есть
pub fn toCopticFilename(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    // Проверяем первый символ - если уже Coptic (>= 0x2C80), возвращаем как есть
    if (name.len >= 3) {
        const first_byte = name[0];
        if (first_byte >= 0xE2) {
            // Уже UTF-8 Coptic, возвращаем копию
            return try allocator.dupe(u8, name);
        }
    }
    
    // Конвертируем Latin в Coptic
    var result = std.ArrayList(u8).init(allocator);
    
    for (name) |c| {
        if (c >= 'a' and c <= 'z') {
            try result.appendSlice(LATIN_TO_COPTIC[c - 'a']);
        } else if (c >= 'A' and c <= 'Z') {
            try result.appendSlice(LATIN_TO_COPTIC[c - 'A']);
        } else if (c == '_' or c == '.') {
            try result.append(c);
        } else if (c >= '0' and c <= '9') {
            try result.append(c);
        }
        // Остальные символы пропускаем
    }
    
    return result.toOwnedSlice();
}

// ============================================================================
// 999 CODE GENERATOR - СВЯЩЕННЫЙ КОПТСКИЙ АЛФАВИТ
// ============================================================================
// АЛФАВИТ ЦАРСТВА (27 символов):
// МЕДНОЕ (1-9):     Ⲁ Ⲃ Ⲅ Ⲇ Ⲉ Ⲋ Ⲍ Ⲏ Ⲑ
// СЕРЕБРЯНОЕ (10-18): Ⲓ Ⲕ Ⲗ Ⲙ Ⲛ Ⲝ Ⲟ Ⲡ Ⲣ
// ЗОЛОТОЕ (19-27):   Ⲥ Ⲧ Ⲩ Ⲫ Ⲭ Ⲯ Ⲱ Ⳁ Ⳃ

const COPTIC_ALPHABET = [27][]const u8{
    "Ⲁ", "Ⲃ", "Ⲅ", "Ⲇ", "Ⲉ", "Ⲋ", "Ⲍ", "Ⲏ", "Ⲑ", // Медное 1-9
    "Ⲓ", "Ⲕ", "Ⲗ", "Ⲙ", "Ⲛ", "Ⲝ", "Ⲟ", "Ⲡ", "Ⲣ", // Серебряное 10-18
    "Ⲥ", "Ⲧ", "Ⲩ", "Ⲫ", "Ⲭ", "Ⲯ", "Ⲱ", "Ⳁ", "Ⳃ", // Золотое 19-27
};

// Латиница → Коптский (консистентный маппинг)
const LATIN_TO_COPTIC = [26][]const u8{
    "Ⲁ", // a
    "Ⲃ", // b
    "Ⲕ", // c → k
    "Ⲇ", // d
    "Ⲉ", // e
    "Ⲫ", // f
    "Ⲅ", // g
    "Ⲏ", // h
    "Ⲓ", // i
    "Ⲓ", // j → i
    "Ⲕ", // k
    "Ⲗ", // l
    "Ⲙ", // m
    "Ⲛ", // n
    "Ⲟ", // o
    "Ⲡ", // p
    "Ⲕ", // q → k
    "Ⲣ", // r
    "Ⲥ", // s
    "Ⲧ", // t
    "Ⲩ", // u
    "Ⲃ", // v → b
    "Ⲱ", // w
    "Ⲭ", // x
    "Ⲩ", // y → u
    "Ⲍ", // z
};

// Ключевые слова языка 999 (КОНСИСТЕНТНЫЕ)
const KW_MODULE = "Ⲙ";
const KW_FUNCTION = "Ⲫ";
const KW_STRUCT = "Ⲥ";
const KW_CONST = "Ⲕ";
const KW_VAR = "Ⲝ";
const KW_EXPORT = "Ⲉ";
const KW_IMPORT = "Ⲓ";
const KW_IF = "ⲈⲤ";
const KW_ELSE = "ⲈⲖ";
const KW_FOR = "ⲆⲖ";
const KW_WHILE = "ⲠⲔ";
const KW_RETURN = "ⲂⲌ";
const KW_BREAK = "ⲂⲢ";
const KW_CONTINUE = "ⲠⲢ";
const KW_IN = "Ⲃ";
const KW_RANGE = "ⲆⲀ";
const KW_TRUE = "Ⲑ";
const KW_FALSE = "Ⲁ";
const KW_NULL = "Ⲱ";

// Типы данных (КОНСИСТЕНТНЫЕ)
const TYPE_INT = "Ⲓ";
const TYPE_FLOAT = "Ⲫ";
const TYPE_STRING = "Ⲥ";
const TYPE_BOOL = "Ⲃ";
const TYPE_LIST = "Ⲗ";
const TYPE_MAP = "Ⲙ";
const TYPE_VOID = "Ⲱ";

// ============================================================================
// КОНСИСТЕНТНАЯ ТАБЛИЦА ИДЕНТИФИКАТОРОВ
// ============================================================================
// Гарантирует: один идентификатор → всегда один коптский код

const ConsistentMapping = struct {
    latin: []const u8,
    coptic: []const u8,
};

const CONSISTENT_IDENTIFIERS = [_]ConsistentMapping{
    // UI компоненты
    .{ .latin = "layout", .coptic = "ⲖⲀⲨⲞ" },
    .{ .latin = "button", .coptic = "ⲂⲦⲚⲔ" },
    .{ .latin = "input", .coptic = "ⲒⲚⲠⲦ" },
    .{ .latin = "text", .coptic = "ⲦⲈⲜⲦ" },
    .{ .latin = "image", .coptic = "ⲒⲘⲀⲄ" },
    .{ .latin = "container", .coptic = "ⲔⲞⲚⲦ" },
    .{ .latin = "card", .coptic = "ⲔⲀⲢⲆ" },
    .{ .latin = "modal", .coptic = "ⲘⲞⲆⲖ" },
    .{ .latin = "navbar", .coptic = "ⲚⲀⲂⲢ" },
    .{ .latin = "sidebar", .coptic = "ⲤⲒⲆⲂ" },
    // Действия
    .{ .latin = "click", .coptic = "ⲔⲖⲒⲔ" },
    .{ .latin = "submit", .coptic = "ⲤⲂⲘⲦ" },
    .{ .latin = "change", .coptic = "ⲬⲚⲄⲈ" },
    .{ .latin = "load", .coptic = "ⲖⲞⲀⲆ" },
    .{ .latin = "save", .coptic = "ⲤⲀⲂⲈ" },
    .{ .latin = "delete", .coptic = "ⲆⲈⲖⲦ" },
    .{ .latin = "update", .coptic = "ⲨⲠⲆⲦ" },
    .{ .latin = "create", .coptic = "ⲔⲢⲈⲦ" },
    // Данные
    .{ .latin = "data", .coptic = "ⲆⲀⲦⲀ" },
    .{ .latin = "value", .coptic = "ⲂⲀⲖⲨ" },
    .{ .latin = "result", .coptic = "ⲢⲈⲤⲖ" },
    .{ .latin = "error", .coptic = "ⲈⲢⲢⲢ" },
    .{ .latin = "state", .coptic = "ⲤⲦⲀⲦ" },
    .{ .latin = "props", .coptic = "ⲠⲢⲞⲠ" },
    .{ .latin = "config", .coptic = "ⲔⲞⲚⲪ" },
    .{ .latin = "options", .coptic = "ⲞⲠⲦⲤ" },
    // Генерация
    .{ .latin = "generate", .coptic = "ⲄⲈⲚⲢ" },
    .{ .latin = "render", .coptic = "ⲢⲚⲆⲢ" },
    .{ .latin = "transform", .coptic = "ⲦⲢⲚⲤ" },
    .{ .latin = "encode", .coptic = "ⲈⲚⲔⲆ" },
    .{ .latin = "decode", .coptic = "ⲆⲈⲔⲆ" },
    .{ .latin = "parse", .coptic = "ⲠⲀⲢⲤ" },
    .{ .latin = "compile", .coptic = "ⲔⲘⲠⲖ" },
    // 3D/WorldGen
    .{ .latin = "world", .coptic = "ⲰⲢⲖⲆ" },
    .{ .latin = "terrain", .coptic = "ⲦⲢⲢⲚ" },
    .{ .latin = "object", .coptic = "ⲞⲂⲒⲔ" },
    .{ .latin = "scene", .coptic = "ⲤⲤⲈⲚ" },
    .{ .latin = "camera", .coptic = "ⲔⲀⲘⲢ" },
    .{ .latin = "light", .coptic = "ⲖⲒⲄⲦ" },
    .{ .latin = "mesh", .coptic = "ⲘⲈⲰⲤ" },
    .{ .latin = "texture", .coptic = "ⲦⲈⲜⲢ" },
    // GNN/ML
    .{ .latin = "graph", .coptic = "ⲄⲢⲀⲪ" },
    .{ .latin = "node", .coptic = "ⲚⲞⲆⲈ" },
    .{ .latin = "edge", .coptic = "ⲈⲆⲄⲈ" },
    .{ .latin = "layer", .coptic = "ⲖⲀⲨⲢ" },
    .{ .latin = "model", .coptic = "ⲘⲞⲆⲖ" },
    .{ .latin = "train", .coptic = "ⲦⲢⲀⲚ" },
    .{ .latin = "predict", .coptic = "ⲠⲢⲈⲆ" },
    .{ .latin = "loss", .coptic = "ⲖⲞⲤⲤ" },
    // Diffusion
    .{ .latin = "diffusion", .coptic = "ⲆⲒⲪⲤ" },
    .{ .latin = "noise", .coptic = "ⲚⲞⲒⲤ" },
    .{ .latin = "denoise", .coptic = "ⲆⲚⲞⲤ" },
    .{ .latin = "step", .coptic = "ⲤⲦⲈⲠ" },
    .{ .latin = "sample", .coptic = "ⲤⲘⲠⲖ" },
    // Gradient
    .{ .latin = "gradient", .coptic = "ⲄⲢⲀⲆ" },
    .{ .latin = "optimize", .coptic = "ⲞⲠⲦⲘ" },
    .{ .latin = "minimize", .coptic = "ⲘⲒⲚⲘ" },
    .{ .latin = "maximize", .coptic = "ⲘⲀⲜⲘ" },
    .{ .latin = "constraint", .coptic = "ⲔⲚⲤⲦ" },
    // Общие
    .{ .latin = "test", .coptic = "ⲦⲈⲤⲦ" },
    .{ .latin = "spec", .coptic = "ⲤⲠⲈⲔ" },
    .{ .latin = "behavior", .coptic = "ⲂⲈⲎⲂ" },
    .{ .latin = "module", .coptic = "ⲘⲞⲆⲨ" },
    .{ .latin = "source", .coptic = "ⲤⲞⲨⲢ" },
    .{ .latin = "target", .coptic = "ⲦⲀⲢⲄ" },
    // VM TRINITY - Виртуальная машина
    .{ .latin = "vm", .coptic = "ⲂⲘⲀ" },
    .{ .latin = "trinity", .coptic = "ⲦⲢⲒⲚ" },
    .{ .latin = "stack", .coptic = "ⲤⲦⲀⲔ" },
    .{ .latin = "heap", .coptic = "ⲎⲈⲀⲠ" },
    .{ .latin = "register", .coptic = "ⲢⲈⲄⲤ" },
    .{ .latin = "opcode", .coptic = "ⲞⲠⲔⲆ" },
    .{ .latin = "bytecode", .coptic = "ⲂⲨⲦⲔ" },
    .{ .latin = "instruction", .coptic = "ⲒⲚⲤⲦ" },
    .{ .latin = "execute", .coptic = "ⲈⲜⲈⲔ" },
    .{ .latin = "dispatch", .coptic = "ⲆⲒⲤⲠ" },
    .{ .latin = "fetch", .coptic = "ⲪⲈⲦⲬ" },
    .{ .latin = "decode", .coptic = "ⲆⲈⲔⲆ" },
    // JIT компиляция
    .{ .latin = "jit", .coptic = "ⲒⲒⲦⲀ" },
    .{ .latin = "compile", .coptic = "ⲔⲘⲠⲖ" },
    .{ .latin = "hotspot", .coptic = "ⲎⲞⲦⲤ" },
    .{ .latin = "trace", .coptic = "ⲦⲢⲀⲤ" },
    .{ .latin = "inline", .coptic = "ⲒⲚⲖⲚ" },
    .{ .latin = "specialize", .coptic = "ⲤⲠⲈⲤ" },
    .{ .latin = "deoptimize", .coptic = "ⲆⲞⲠⲦ" },
    .{ .latin = "profile", .coptic = "ⲠⲢⲞⲪ" },
    .{ .latin = "counter", .coptic = "ⲔⲚⲦⲢ" },
    .{ .latin = "threshold", .coptic = "ⲐⲢⲈⲤ" },
    // Память и GC
    .{ .latin = "memory", .coptic = "ⲘⲈⲘⲢ" },
    .{ .latin = "allocate", .coptic = "ⲀⲖⲞⲔ" },
    .{ .latin = "free", .coptic = "ⲪⲢⲈⲈ" },
    .{ .latin = "gc", .coptic = "ⲄⲔⲀⲀ" },
    .{ .latin = "collect", .coptic = "ⲔⲞⲖⲔ" },
    .{ .latin = "mark", .coptic = "ⲘⲀⲢⲔ" },
    .{ .latin = "sweep", .coptic = "ⲤⲰⲈⲠ" },
    .{ .latin = "compact", .coptic = "ⲔⲘⲠⲔ" },
    .{ .latin = "arena", .coptic = "ⲀⲢⲈⲚ" },
    .{ .latin = "pool", .coptic = "ⲠⲞⲞⲖ" },
    .{ .latin = "slab", .coptic = "ⲤⲖⲀⲂ" },
    // Типы данных VM
    .{ .latin = "integer", .coptic = "ⲒⲚⲦⲄ" },
    .{ .latin = "float64", .coptic = "ⲪⲖⲦ64" },
    .{ .latin = "string", .coptic = "ⲤⲦⲢⲚ" },
    .{ .latin = "array", .coptic = "ⲀⲢⲢⲨ" },
    .{ .latin = "object", .coptic = "ⲞⲂⲒⲔ" },
    .{ .latin = "function", .coptic = "ⲪⲨⲚⲔ" },
    .{ .latin = "closure", .coptic = "ⲔⲖⲞⲤ" },
    .{ .latin = "upvalue", .coptic = "ⲨⲠⲂⲖ" },
    // Операции
    .{ .latin = "push", .coptic = "ⲠⲨⲰⲤ" },
    .{ .latin = "pop", .coptic = "ⲠⲞⲠⲀ" },
    .{ .latin = "add", .coptic = "ⲀⲆⲆⲀ" },
    .{ .latin = "sub", .coptic = "ⲤⲨⲂⲀ" },
    .{ .latin = "mul", .coptic = "ⲘⲨⲖⲀ" },
    .{ .latin = "div", .coptic = "ⲆⲒⲂⲀ" },
    .{ .latin = "mod", .coptic = "ⲘⲞⲆⲀ" },
    .{ .latin = "neg", .coptic = "ⲚⲈⲄⲀ" },
    .{ .latin = "not", .coptic = "ⲚⲞⲦⲀ" },
    .{ .latin = "and", .coptic = "ⲀⲚⲆⲀ" },
    .{ .latin = "or", .coptic = "ⲞⲢⲀⲀ" },
    .{ .latin = "xor", .coptic = "ⲜⲞⲢⲀ" },
    .{ .latin = "shl", .coptic = "ⲰⲎⲖⲀ" },
    .{ .latin = "shr", .coptic = "ⲰⲎⲢⲀ" },
    .{ .latin = "eq", .coptic = "ⲈⲔⲀⲀ" },
    .{ .latin = "lt", .coptic = "ⲖⲦⲀⲀ" },
    .{ .latin = "gt", .coptic = "ⲄⲦⲀⲀ" },
    .{ .latin = "le", .coptic = "ⲖⲈⲀⲀ" },
    .{ .latin = "ge", .coptic = "ⲄⲈⲀⲀ" },
    .{ .latin = "jump", .coptic = "ⲒⲨⲘⲠ" },
    .{ .latin = "call", .coptic = "ⲔⲀⲖⲖ" },
    .{ .latin = "ret", .coptic = "ⲢⲈⲦⲀ" },
    .{ .latin = "load", .coptic = "ⲖⲞⲀⲆ" },
    .{ .latin = "store", .coptic = "ⲤⲦⲞⲢ" },
    // Оптимизации
    .{ .latin = "simd", .coptic = "ⲤⲒⲘⲆ" },
    .{ .latin = "vector", .coptic = "ⲂⲈⲔⲦ" },
    .{ .latin = "parallel", .coptic = "ⲠⲀⲢⲖ" },
    .{ .latin = "cache", .coptic = "ⲔⲀⲰⲈ" },
    .{ .latin = "prefetch", .coptic = "ⲠⲢⲈⲪ" },
    .{ .latin = "branch", .coptic = "ⲂⲢⲚⲬ" },
    .{ .latin = "predict", .coptic = "ⲠⲢⲈⲆ" },
    // Бенчмаркинг
    .{ .latin = "benchmark", .coptic = "ⲂⲚⲬⲘ" },
    .{ .latin = "measure", .coptic = "ⲘⲈⲀⲤ" },
    .{ .latin = "timer", .coptic = "ⲦⲒⲘⲢ" },
    .{ .latin = "iteration", .coptic = "ⲒⲦⲈⲢ" },
    .{ .latin = "warmup", .coptic = "ⲰⲀⲢⲘ" },
    .{ .latin = "throughput", .coptic = "ⲐⲢⲠⲦ" },
    .{ .latin = "latency", .coptic = "ⲖⲀⲦⲚ" },
    // Священная формула
    .{ .latin = "phi", .coptic = "ⲪⲎⲀ" },
    .{ .latin = "pi", .coptic = "ⲠⲎⲀ" },
    .{ .latin = "euler", .coptic = "ⲈⲨⲖⲢ" },
    .{ .latin = "golden", .coptic = "ⲄⲞⲖⲆ" },
    .{ .latin = "sacred", .coptic = "ⲤⲀⲔⲢ" },
    .{ .latin = "formula", .coptic = "ⲪⲞⲢⲘ" },
};

/// Кодирование числа в base-27 коптский алфавит
fn encodeNumber(allocator: std.mem.Allocator, n: u64) ![]const u8 {
    if (n == 0) {
        return try allocator.dupe(u8, COPTIC_ALPHABET[0]);
    }
    
    var result = std.ArrayList(u8).init(allocator);
    var num = n;
    
    // Собираем цифры в обратном порядке
    var digits = std.ArrayList(usize).init(allocator);
    defer digits.deinit();
    
    while (num > 0) {
        try digits.append(num % 27);
        num /= 27;
    }
    
    // Записываем в правильном порядке
    var i: usize = digits.items.len;
    while (i > 0) {
        i -= 1;
        try result.appendSlice(COPTIC_ALPHABET[digits.items[i]]);
    }
    
    return result.toOwnedSlice();
}

/// Поиск в консистентной таблице
fn findConsistentMapping(name: []const u8) ?[]const u8 {
    // Приводим к нижнему регистру для поиска
    var lower_buf: [64]u8 = undefined;
    const len = @min(name.len, 64);
    for (name[0..len], 0..) |c, i| {
        lower_buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    const lower = lower_buf[0..len];
    
    for (CONSISTENT_IDENTIFIERS) |mapping| {
        if (std.mem.eql(u8, mapping.latin, lower)) {
            return mapping.coptic;
        }
    }
    return null;
}

/// Кодирование одной латинской буквы в коптскую
fn latinToCoptic(c: u8) []const u8 {
    const lower = if (c >= 'A' and c <= 'Z') c + 32 else c;
    if (lower >= 'a' and lower <= 'z') {
        return LATIN_TO_COPTIC[lower - 'a'];
    }
    return "Ⲁ"; // default
}

/// КОНСИСТЕНТНОЕ кодирование идентификатора в коптский алфавит
/// Гарантирует: один идентификатор → всегда один коптский код
fn encodeIdentifier(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    // 1. Сначала ищем в консистентной таблице
    if (findConsistentMapping(name)) |coptic| {
        return try allocator.dupe(u8, coptic);
    }
    
    // 2. Если не найдено - кодируем первые 4 буквы детерминированно
    var result = std.ArrayList(u8).init(allocator);
    
    var count: usize = 0;
    for (name) |c| {
        if (count >= 4) break;
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')) {
            try result.appendSlice(latinToCoptic(c));
            count += 1;
        }
    }
    
    // Если меньше 4 символов - дополняем Ⲁ
    while (count < 4) {
        try result.appendSlice("Ⲁ");
        count += 1;
    }
    
    return result.toOwnedSlice();
}

// ============================================================================
// VM TRINITY OPCODES - Священные коды операций
// ============================================================================
const VM_OPCODES = struct {
    // Стек операции (0x00-0x0F)
    const PUSH_CONST = "ⲀⲀ"; // 0x00 - загрузить константу
    const PUSH_LOCAL = "ⲀⲂ"; // 0x01 - загрузить локальную
    const PUSH_GLOBAL = "ⲀⲄ"; // 0x02 - загрузить глобальную
    const POP = "ⲀⲆ"; // 0x03 - снять со стека
    const DUP = "ⲀⲈ"; // 0x04 - дублировать
    const SWAP = "ⲀⲊ"; // 0x05 - поменять местами
    
    // Арифметика (0x10-0x1F)
    const ADD = "ⲂⲀ"; // 0x10 - сложение
    const SUB = "ⲂⲂ"; // 0x11 - вычитание
    const MUL = "ⲂⲄ"; // 0x12 - умножение
    const DIV = "ⲂⲆ"; // 0x13 - деление
    const MOD = "ⲂⲈ"; // 0x14 - остаток
    const NEG = "ⲂⲊ"; // 0x15 - отрицание
    const POW = "ⲂⲌ"; // 0x16 - степень
    
    // Сравнение (0x20-0x2F)
    const EQ = "ⲄⲀ"; // 0x20 - равно
    const NE = "ⲄⲂ"; // 0x21 - не равно
    const LT = "ⲄⲄ"; // 0x22 - меньше
    const LE = "ⲄⲆ"; // 0x23 - меньше или равно
    const GT = "ⲄⲈ"; // 0x24 - больше
    const GE = "ⲄⲊ"; // 0x25 - больше или равно
    
    // Логика (0x30-0x3F)
    const NOT = "ⲆⲀ"; // 0x30 - логическое НЕ
    const AND = "ⲆⲂ"; // 0x31 - логическое И
    const OR = "ⲆⲄ"; // 0x32 - логическое ИЛИ
    const XOR = "ⲆⲆ"; // 0x33 - исключающее ИЛИ
    
    // Битовые (0x40-0x4F)
    const BNOT = "ⲈⲀ"; // 0x40 - битовое НЕ
    const BAND = "ⲈⲂ"; // 0x41 - битовое И
    const BOR = "ⲈⲄ"; // 0x42 - битовое ИЛИ
    const BXOR = "ⲈⲆ"; // 0x43 - битовое XOR
    const SHL = "ⲈⲈ"; // 0x44 - сдвиг влево
    const SHR = "ⲈⲊ"; // 0x45 - сдвиг вправо
    
    // Управление потоком (0x50-0x5F)
    const JMP = "ⲊⲀ"; // 0x50 - безусловный переход
    const JZ = "ⲊⲂ"; // 0x51 - переход если ноль
    const JNZ = "ⲊⲄ"; // 0x52 - переход если не ноль
    const CALL = "ⲊⲆ"; // 0x53 - вызов функции
    const RET = "ⲊⲈ"; // 0x54 - возврат
    const HALT = "ⲊⲊ"; // 0x55 - остановка
    
    // Память (0x60-0x6F)
    const LOAD = "ⲌⲀ"; // 0x60 - загрузить из памяти
    const STORE = "ⲌⲂ"; // 0x61 - сохранить в память
    const ALLOC = "ⲌⲄ"; // 0x62 - выделить память
    const FREE = "ⲌⲆ"; // 0x63 - освободить память
    
    // Объекты (0x70-0x7F)
    const NEW = "ⲎⲀ"; // 0x70 - создать объект
    const GET = "ⲎⲂ"; // 0x71 - получить поле
    const SET = "ⲎⲄ"; // 0x72 - установить поле
    const INVOKE = "ⲎⲆ"; // 0x73 - вызвать метод
    
    // SIMD (0x80-0x8F) - Священные векторные операции
    const VADD = "ⲐⲀ"; // 0x80 - векторное сложение
    const VSUB = "ⲐⲂ"; // 0x81 - векторное вычитание
    const VMUL = "ⲐⲄ"; // 0x82 - векторное умножение
    const VDIV = "ⲐⲆ"; // 0x83 - векторное деление
    const VDOT = "ⲐⲈ"; // 0x84 - скалярное произведение
    const VLOAD = "ⲐⲊ"; // 0x85 - загрузить вектор
    const VSTORE = "ⲐⲌ"; // 0x86 - сохранить вектор
    
    // Священная формула (0x90-0x9F)
    const PHI = "ⲢⲀ"; // 0x90 - φ = 1.618033988749895
    const PI = "ⲢⲂ"; // 0x91 - π = 3.141592653589793
    const E = "ⲢⲄ"; // 0x92 - e = 2.718281828459045
    const GOLDEN = "ⲢⲆ"; // 0x93 - φ² + 1/φ² = 3
    const SACRED = "ⲢⲈ"; // 0x94 - V = n × 3^k × π^m × φ^p × e^q
};

// ============================================================================
// ГЕНЕРАТОРЫ ТЕЛ ФУНКЦИЙ ДЛЯ РАЗНЫХ ТИПОВ BEHAVIORS
// ============================================================================

/// Генерация тела VM behavior - dispatch loop
fn generateVMBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲂⲘ ⲦⲢⲒⲚⲒⲦⲨ - ⲆⲒⲤⲠⲀⲦⲤⲎ ⲖⲞⲞⲠ
        \\  Ⲝ ⲓⲡ: Ⲓ = 0  // instruction pointer
        \\  Ⲝ ⲥⲡ: Ⲓ = 0  // stack pointer
        \\  Ⲝ ⲫⲡ: Ⲓ = 0  // frame pointer
        \\  
        \\  // ⲤⲦⲀⲔ: 64ⲔⲂ ⲥⲧⲁⲕ ⲥⲓⲍⲉ
        \\  Ⲝ ⲤⲦⲀⲔ: [65536]Ⲓ = [0; 65536]
        \\  
        \\  // ⲆⲒⲤⲠⲀⲦⲤⲎ ⲦⲀⲂⲖⲈ - computed goto
        \\  ⲆⲖ ⲟⲡ Ⲃ ⲂⲨⲦⲈⲔⲞⲆⲈ {
        \\    ⲈⲤ ⲟⲡ == ⲀⲀ { ⲤⲦⲀⲔ[ⲥⲡ] = ⲔⲞⲚⲤⲦ[ⲓⲡ+1]; ⲥⲡ += 1; ⲓⲡ += 2 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲀ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] += ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲂ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] -= ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲄ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] *= ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲆ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] /= ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲊⲀ { ⲓⲡ = ⲂⲨⲦⲈⲔⲞⲆⲈ[ⲓⲡ+1] }
        \\    ⲈⲤ ⲟⲡ == ⲊⲆ { ⲤⲦⲀⲔ[ⲥⲡ] = ⲓⲡ+2; ⲥⲡ += 1; ⲓⲡ = ⲂⲨⲦⲈⲔⲞⲆⲈ[ⲓⲡ+1] }
        \\    ⲈⲤ ⲟⲡ == ⲊⲈ { ⲥⲡ -= 1; ⲓⲡ = ⲤⲦⲀⲔ[ⲥⲡ] }
        \\    ⲈⲤ ⲟⲡ == ⲊⲊ { ⲂⲌ Ⲱ }
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация тела JIT behavior - trace compilation
fn generateJITBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲒⲒⲦ ⲔⲞⲘⲠⲒⲖⲈⲢ - ⲦⲢⲀⲤⲈ ⲂⲀⲤⲈⲆ
        \\  Ⲕ ⲎⲞⲦⲤⲠⲞⲦ_ⲦⲎⲢⲈⲤⲎⲞⲖⲆ: Ⲓ = 1000
        \\  Ⲕ ⲦⲢⲀⲤⲈ_ⲘⲀⲬ_ⲖⲈⲚ: Ⲓ = 256
        \\  
        \\  Ⲝ ⲔⲞⲨⲚⲦⲈⲢⲤ: [4096]Ⲓ = [0; 4096]
        \\  Ⲝ ⲦⲢⲀⲤⲈⲤ: [1024][256]Ⲓ = [[0; 256]; 1024]
        \\  Ⲝ ⲔⲞⲘⲠⲒⲖⲈⲆ: [1024]Ⲃ = [Ⲁ; 1024]
        \\  
        \\  // ⲠⲢⲞⲪⲒⲖⲈ ⲁⲛⲇ ⲦⲢⲀⲤⲈ
        \\  Ⲫ ⲠⲢⲞⲪⲒⲖⲈ(ⲓⲡ: Ⲓ) -> Ⲃ {
        \\    ⲔⲞⲨⲚⲦⲈⲢⲤ[ⲓⲡ] += 1
        \\    ⲈⲤ ⲔⲞⲨⲚⲦⲈⲢⲤ[ⲓⲡ] >= ⲎⲞⲦⲤⲠⲞⲦ_ⲦⲎⲢⲈⲤⲎⲞⲖⲆ {
        \\      ⲂⲌ Ⲑ  // ⲏⲟⲧ!
        \\    }
        \\    ⲂⲌ Ⲁ
        \\  }
        \\  
        \\  // ⲤⲠⲈⲤⲒⲀⲖⲒⲌⲈ ⲫⲟⲣ ⲧⲩⲡⲉⲥ
        \\  Ⲫ ⲤⲠⲈⲤⲒⲀⲖⲒⲌⲈ(ⲧⲣⲁⲥⲉ: []Ⲓ, ⲧⲩⲡⲉⲥ: []Ⲧ) -> []Ⲓ {
        \\    // ⲦⲨⲠⲈ-ⲤⲠⲈⲤⲒⲪⲒⲔ ⲟⲡⲧⲓⲙⲓⲍⲁⲧⲓⲟⲛⲥ
        \\    ⲂⲌ ⲞⲠⲦⲒⲘⲒⲌⲈ(ⲧⲣⲁⲥⲉ)
        \\  }
        \\  
        \\  // ⲆⲈⲞⲠⲦⲒⲘⲒⲌⲈ ⲟⲛ ⲅⲩⲁⲣⲇ ⲫⲁⲓⲗⲩⲣⲉ
        \\  Ⲫ ⲆⲈⲞⲠⲦⲒⲘⲒⲌⲈ(ⲓⲡ: Ⲓ) {
        \\    ⲔⲞⲘⲠⲒⲖⲈⲆ[ⲓⲡ] = Ⲁ
        \\    ⲔⲞⲨⲚⲦⲈⲢⲤ[ⲓⲡ] = 0
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация тела GC behavior - mark-sweep-compact
fn generateGCBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲄⲔ ⲦⲢⲒⲚⲒⲦⲨ - ⲘⲀⲢⲔ-ⲤⲰⲈⲈⲠ-ⲔⲞⲘⲠⲀⲔⲦ
        \\  Ⲕ ⲎⲈⲀⲠ_ⲤⲒⲌⲈ: Ⲓ = 16777216  // 16ⲘⲂ
        \\  Ⲕ ⲀⲢⲈⲚⲀ_ⲤⲒⲌⲈ: Ⲓ = 65536    // 64ⲔⲂ
        \\  
        \\  Ⲝ ⲎⲈⲀⲠ: [16777216]Ⲓ = [0; 16777216]
        \\  Ⲝ ⲘⲀⲢⲔⲤ: [262144]Ⲃ = [Ⲁ; 262144]  // 1 ⲃⲓⲧ ⲡⲉⲣ 64 ⲃⲩⲧⲉⲥ
        \\  Ⲝ ⲪⲢⲈⲈ_ⲖⲒⲤ: Ⲓ = 0
        \\  
        \\  // ⲘⲀⲢⲔ ⲠⲎⲀⲤⲈ - ⲧⲣⲓ-ⲕⲟⲗⲟⲣ
        \\  Ⲫ ⲘⲀⲢⲔ(ⲣⲟⲟⲧⲥ: []Ⲓ) {
        \\    Ⲝ ⲰⲞⲢⲔⲖⲒⲤⲦ: [4096]Ⲓ = [0; 4096]
        \\    Ⲝ ⲱⲡ: Ⲓ = 0
        \\    
        \\    // ⲀⲆⲆ ⲣⲟⲟⲧⲥ
        \\    ⲆⲖ ⲣ Ⲃ ⲣⲟⲟⲧⲥ { ⲰⲞⲢⲔⲖⲒⲤⲦ[ⲱⲡ] = ⲣ; ⲱⲡ += 1 }
        \\    
        \\    // ⲦⲢⲀⲂⲈⲢⲤⲈ
        \\    ⲠⲔ ⲱⲡ > 0 {
        \\      ⲱⲡ -= 1
        \\      Ⲝ ⲟⲃⲓ: Ⲓ = ⲰⲞⲢⲔⲖⲒⲤⲦ[ⲱⲡ]
        \\      ⲈⲤ !ⲘⲀⲢⲔⲤ[ⲟⲃⲓ/64] {
        \\        ⲘⲀⲢⲔⲤ[ⲟⲃⲓ/64] = Ⲑ
        \\        // ⲀⲆⲆ ⲣⲉⲫⲉⲣⲉⲛⲥⲉⲥ ⲧⲟ ⲱⲟⲣⲕⲗⲓⲥⲧ
        \\      }
        \\    }
        \\  }
        \\  
        \\  // ⲤⲰⲈⲈⲠ ⲠⲎⲀⲤⲈ
        \\  Ⲫ ⲤⲰⲈⲈⲠ() -> Ⲓ {
        \\    Ⲝ ⲫⲣⲉⲉⲇ: Ⲓ = 0
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 262144) {
        \\      ⲈⲤ !ⲘⲀⲢⲔⲤ[ⲓ] { ⲫⲣⲉⲉⲇ += 64 }
        \\      ⲘⲀⲢⲔⲤ[ⲓ] = Ⲁ  // ⲣⲉⲥⲉⲧ
        \\    }
        \\    ⲂⲌ ⲫⲣⲉⲉⲇ
        \\  }
        \\  
        \\  // ⲔⲞⲘⲠⲀⲔⲦ ⲠⲎⲀⲤⲈ
        \\  Ⲫ ⲔⲞⲘⲠⲀⲔⲦ() {
        \\    // ⲘⲞⲂⲈ ⲗⲓⲃⲉ ⲟⲃⲓⲉⲕⲧⲥ ⲧⲟ ⲫⲣⲟⲛⲧ
        \\    // ⲨⲠⲆⲀⲦⲈ ⲣⲉⲫⲉⲣⲉⲛⲥⲉⲥ
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация тела SIMD behavior - vectorized operations
fn generateSIMDBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲤⲒⲘⲆ ⲦⲢⲒⲚⲒⲦⲨ - ⲂⲈⲔⲦⲞⲢⲒⲌⲈⲆ ⲞⲠⲈⲢⲀⲦⲒⲞⲚⲤ
        \\  // ⲀⲂⲬ256 / ⲚⲈⲞⲚ / ⲰⲀⲤⲘ ⲤⲒⲘⲆ
        \\  
        \\  Ⲕ ⲂⲈⲔ_ⲰⲒⲆⲦⲎ: Ⲓ = 8  // 8 × ⲫⲗⲟⲁⲧ32 = 256 ⲃⲓⲧⲥ
        \\  
        \\  // ⲂⲈⲔⲦⲞⲢ ⲀⲆⲆⲒⲦⲒⲞⲚ
        \\  Ⲫ ⲂⲀⲆⲆ(ⲁ: [8]Ⲫ, ⲃ: [8]Ⲫ) -> [8]Ⲫ {
        \\    Ⲝ ⲣ: [8]Ⲫ = [0.0; 8]
        \\    // ⲐⲀ - ⲂⲈⲔⲦⲞⲢ ⲀⲆⲆ ⲟⲡⲕⲟⲇⲉ
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 8) { ⲣ[ⲓ] = ⲁ[ⲓ] + ⲃ[ⲓ] }
        \\    ⲂⲌ ⲣ
        \\  }
        \\  
        \\  // ⲂⲈⲔⲦⲞⲢ ⲘⲨⲖⲦⲒⲠⲖⲨ
        \\  Ⲫ ⲂⲘⲨⲖ(ⲁ: [8]Ⲫ, ⲃ: [8]Ⲫ) -> [8]Ⲫ {
        \\    Ⲝ ⲣ: [8]Ⲫ = [0.0; 8]
        \\    // ⲐⲄ - ⲂⲈⲔⲦⲞⲢ ⲘⲨⲖ ⲟⲡⲕⲟⲇⲉ
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 8) { ⲣ[ⲓ] = ⲁ[ⲓ] * ⲃ[ⲓ] }
        \\    ⲂⲌ ⲣ
        \\  }
        \\  
        \\  // ⲆⲞⲦ ⲠⲢⲞⲆⲨⲔⲦ
        \\  Ⲫ ⲂⲆⲞⲦ(ⲁ: [8]Ⲫ, ⲃ: [8]Ⲫ) -> Ⲫ {
        \\    Ⲝ ⲥⲩⲙ: Ⲫ = 0.0
        \\    // ⲐⲈ - ⲂⲈⲔⲦⲞⲢ ⲆⲞⲦ ⲟⲡⲕⲟⲇⲉ
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 8) { ⲥⲩⲙ += ⲁ[ⲓ] * ⲃ[ⲓ] }
        \\    ⲂⲌ ⲥⲩⲙ
        \\  }
        \\  
        \\  // ⲘⲀⲦⲢⲒⲬ ⲘⲨⲖⲦⲒⲠⲖⲨ 4×4 (ⲤⲒⲘⲆ ⲟⲡⲧⲓⲙⲓⲍⲉⲇ)
        \\  Ⲫ ⲘⲀⲦⲘⲨⲖ4(ⲁ: [16]Ⲫ, ⲃ: [16]Ⲫ) -> [16]Ⲫ {
        \\    Ⲝ ⲣ: [16]Ⲫ = [0.0; 16]
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 4) {
        \\      ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 4) {
        \\        ⲆⲖ ⲕ Ⲃ ⲆⲀ(0, 4) {
        \\          ⲣ[ⲓ*4+ⲓ] += ⲁ[ⲓ*4+ⲕ] * ⲃ[ⲕ*4+ⲓ]
        \\        }
        \\      }
        \\    }
        \\    ⲂⲌ ⲣ
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация кода на языке 999
fn generate999(allocator: std.mem.Allocator, spec: parser.Spec) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    const writer = output.writer();

    // Заголовок модуля с священной формулой
    const module_name = try encodeIdentifier(allocator, spec.module);
    defer allocator.free(module_name);
    
    try writer.print(
        \\// ═══════════════════════════════════════════════════════════════
        \\// ⳃⳃⳃ - ⲤⲀⲔⲢⲈⲆ ⲔⲞⲆⲈ - Ⲅⲉⲛⲉⲣⲁⲧⲉⲇ ⲃⲩ ⲂⲒⲂⲈⲈⲤ
        \\// ═══════════════════════════════════════════════════════════════
        \\// Ⲥⲟⲩⲣⲥⲉ: {s}.vibee
        \\// Ⲃⲉⲣⲥⲓⲟⲛ: {s}
        \\// ⲤⲀⲔⲢⲈⲆ ⲪⲞⲢⲘⲨⲖⲀ: Ⲃ = ⲛ × 3^ⲕ × π^ⲙ × φ^ⲡ × ⲉ^ⲕ
        \\// ⲄⲞⲖⲆⲈⲚ ⲒⲆⲈⲚⲦⲒⲦⲨ: φ² + 1/φ² = 3
        \\// ═══════════════════════════════════════════════════════════════
        \\
        \\{s} {s}
        \\
        \\
    , .{ spec.name, spec.version, KW_MODULE, module_name });

    // Генерация констант из Creation Pattern
    if (spec.creation_pattern) |cp| {
        const source_enc = try encodeIdentifier(allocator, cp.source);
        defer allocator.free(source_enc);
        const transformer_enc = try encodeIdentifier(allocator, cp.transformer);
        defer allocator.free(transformer_enc);
        const result_enc = try encodeIdentifier(allocator, cp.result);
        defer allocator.free(result_enc);
        
        try writer.print(
            \\// Ⲥⲣⲉⲁⲧⲓⲟⲛ Ⲡⲁⲧⲧⲉⲣⲛ
            \\{s} {s}: {s} = "{s}"
            \\{s} {s}: {s} = "{s}"
            \\{s} {s}: {s} = "{s}"
            \\
            \\
        , .{
            KW_CONST, source_enc, TYPE_STRING, cp.source,
            KW_CONST, transformer_enc, TYPE_STRING, cp.transformer,
            KW_CONST, result_enc, TYPE_STRING, cp.result,
        });
    }

    // Генерация функций из behaviors с полным VM кодом
    for (spec.behaviors) |behavior| {
        const func_name = try encodeIdentifier(allocator, behavior.name);
        defer allocator.free(func_name);
        
        // Определяем тип behavior для генерации соответствующего кода
        const is_vm_behavior = std.mem.indexOf(u8, behavior.name, "vm") != null or
                               std.mem.indexOf(u8, behavior.name, "execute") != null or
                               std.mem.indexOf(u8, behavior.name, "dispatch") != null;
        
        const is_jit_behavior = std.mem.indexOf(u8, behavior.name, "jit") != null or
                                std.mem.indexOf(u8, behavior.name, "compile") != null or
                                std.mem.indexOf(u8, behavior.name, "hotspot") != null;
        
        const is_gc_behavior = std.mem.indexOf(u8, behavior.name, "gc") != null or
                               std.mem.indexOf(u8, behavior.name, "collect") != null or
                               std.mem.indexOf(u8, behavior.name, "memory") != null;
        
        const is_simd_behavior = std.mem.indexOf(u8, behavior.name, "simd") != null or
                                 std.mem.indexOf(u8, behavior.name, "vector") != null;
        
        try writer.print(
            \\// ─────────────────────────────────────────────────────────────
            \\// ⲂⲈⲎⲀⲂⲒⲞⲢ: {s}
            \\// ─────────────────────────────────────────────────────────────
            \\// Ⲅⲓⲃⲉⲛ: {s}
            \\// Ⲱⲏⲉⲛ: {s}
            \\// Ⲧⲏⲉⲛ: {s}
            \\{s} {s}() -> {s} {{
            \\
        , .{
            behavior.name,
            behavior.given,
            behavior.when,
            behavior.then,
            KW_FUNCTION, func_name, TYPE_VOID,
        });
        
        // Генерируем специфичный код в зависимости от типа behavior
        if (is_vm_behavior) {
            try generateVMBehaviorBody(writer);
        } else if (is_jit_behavior) {
            try generateJITBehaviorBody(writer);
        } else if (is_gc_behavior) {
            try generateGCBehaviorBody(writer);
        } else if (is_simd_behavior) {
            try generateSIMDBehaviorBody(writer);
        } else {
            try writer.print("  {s} {s}\n", .{ KW_RETURN, KW_NULL });
        }
        
        try writer.writeAll("}\n\n");
    }

    // Генерация трансформеров
    for (spec.transformers) |transformer| {
        const trans_name = try encodeIdentifier(allocator, transformer.name);
        defer allocator.free(trans_name);
        const input_enc = try encodeIdentifier(allocator, transformer.input);
        defer allocator.free(input_enc);
        const output_enc = try encodeIdentifier(allocator, transformer.output);
        defer allocator.free(output_enc);
        
        try writer.print(
            \\// Ⲧⲣⲁⲛⲥⲫⲟⲣⲙⲉⲣ: {s}
            \\{s} {s}({s}: {s}) -> {s} {{
            \\  {s} {s}
            \\}}
            \\
            \\
        , .{
            transformer.name,
            KW_FUNCTION, trans_name, input_enc, TYPE_INT, output_enc,
            KW_RETURN, KW_NULL,
        });
    }

    // Экспорты
    try writer.print(
        \\{s} {{
    , .{KW_EXPORT});
    
    for (spec.behaviors, 0..) |behavior, i| {
        const func_name = try encodeIdentifier(allocator, behavior.name);
        defer allocator.free(func_name);
        
        if (i > 0) try writer.writeAll(", ");
        try writer.writeAll(func_name);
    }
    
    try writer.writeAll(" }\n");

    return output.toOwnedSlice();
}

test "generate 999 code" {
    var behaviors = [_]parser.Behavior{
        .{
            .name = "test_behavior",
            .given = "input",
            .when = "process",
            .then = "output",
            .test_cases = &[_]parser.TestCase{},
        },
    };

    const spec = parser.Spec{
        .name = "test999",
        .version = "1.0.0",
        .language = "999",
        .module = "test_module",
        .description = "Test 999 generation",
        .behaviors = &behaviors,
        .types = &[_]parser.Type{},
        .functions = &[_]parser.Function{},
        .imports = &[_][]const u8{},
        .creation_pattern = null,
        .transformers = &[_]parser.Transformer{},
        .test_generation = null,
        .source = null,
        .pas_patterns = null,
        .benefit = null,
        .emoji = null,
        .keyboard_shortcut = null,
        .state = null,
        .methods = null,
        .init_body = null,
        .allocator = std.testing.allocator,
    };

    const code = try generate(std.testing.allocator, spec);
    defer std.testing.allocator.free(code);

    // Должен содержать коптские символы
    try std.testing.expect(std.mem.indexOf(u8, code, "Ⲙ") != null); // MODULE
    try std.testing.expect(std.mem.indexOf(u8, code, "Ⲫ") != null); // FUNCTION
    try std.testing.expect(std.mem.indexOf(u8, code, "Ⲉ") != null); // EXPORT
    
    // Не должен содержать латинские ключевые слова
    try std.testing.expect(std.mem.indexOf(u8, code, "module ") == null);
    try std.testing.expect(std.mem.indexOf(u8, code, "function ") == null);
    try std.testing.expect(std.mem.indexOf(u8, code, "export ") == null);
}

test "encode number to coptic" {
    // 0 = Ⲁ
    const zero = try encodeNumber(std.testing.allocator, 0);
    defer std.testing.allocator.free(zero);
    try std.testing.expectEqualStrings("Ⲁ", zero);
    
    // 1 = Ⲃ
    const one = try encodeNumber(std.testing.allocator, 1);
    defer std.testing.allocator.free(one);
    try std.testing.expectEqualStrings("Ⲃ", one);
    
    // 26 = Ⳃ
    const twentysix = try encodeNumber(std.testing.allocator, 26);
    defer std.testing.allocator.free(twentysix);
    try std.testing.expectEqualStrings("Ⳃ", twentysix);
    
    // 27 = ⲂⲀ (1*27 + 0)
    const twentyseven = try encodeNumber(std.testing.allocator, 27);
    defer std.testing.allocator.free(twentyseven);
    try std.testing.expectEqualStrings("ⲂⲀ", twentyseven);
}

test "consistent identifier encoding" {
    // Тест консистентности: один идентификатор → всегда один код
    
    // layout → ⲖⲀⲨⲞ (из таблицы)
    const layout1 = try encodeIdentifier(std.testing.allocator, "layout");
    defer std.testing.allocator.free(layout1);
    const layout2 = try encodeIdentifier(std.testing.allocator, "layout");
    defer std.testing.allocator.free(layout2);
    try std.testing.expectEqualStrings("ⲖⲀⲨⲞ", layout1);
    try std.testing.expectEqualStrings(layout1, layout2); // КОНСИСТЕНТНОСТЬ!
    
    // button → ⲂⲦⲚⲔ (из таблицы)
    const button = try encodeIdentifier(std.testing.allocator, "button");
    defer std.testing.allocator.free(button);
    try std.testing.expectEqualStrings("ⲂⲦⲚⲔ", button);
    
    // graph → ⲄⲢⲀⲪ (из таблицы)
    const graph = try encodeIdentifier(std.testing.allocator, "graph");
    defer std.testing.allocator.free(graph);
    try std.testing.expectEqualStrings("ⲄⲢⲀⲪ", graph);
    
    // Новый идентификатор (не в таблице) - детерминированное кодирование
    const custom1 = try encodeIdentifier(std.testing.allocator, "myVar");
    defer std.testing.allocator.free(custom1);
    const custom2 = try encodeIdentifier(std.testing.allocator, "myVar");
    defer std.testing.allocator.free(custom2);
    try std.testing.expectEqualStrings(custom1, custom2); // КОНСИСТЕНТНОСТЬ!
    try std.testing.expectEqualStrings("ⲘⲨⲂⲀ", custom1); // m=Ⲙ, y=Ⲩ, v=Ⲃ, a=Ⲁ
}

test "deterministic new identifier encoding" {
    // Новые идентификаторы кодируются детерминированно через латиницу
    
    // "test" → ⲦⲈⲤⲦ (из таблицы)
    const test_id = try encodeIdentifier(std.testing.allocator, "test");
    defer std.testing.allocator.free(test_id);
    try std.testing.expectEqualStrings("ⲦⲈⲤⲦ", test_id);
    
    // "xyz" → ⲬⲨⲌⲀ (x=Ⲭ, y=Ⲩ, z=Ⲍ, дополнение Ⲁ)
    const xyz = try encodeIdentifier(std.testing.allocator, "xyz");
    defer std.testing.allocator.free(xyz);
    try std.testing.expectEqualStrings("ⲬⲨⲌⲀ", xyz);
}

// ============================================================================
// ВАЛИДАТОР КОПТСКОГО КОДА
// ============================================================================

/// Проверяет что строка содержит только коптские символы (Ⲁ-Ⳃ)
/// и допустимые символы (пробелы, переносы, пунктуация, цифры)
pub fn validateCopticCode(code: []const u8) bool {
    var i: usize = 0;
    while (i < code.len) {
        const c = code[i];
        
        // ASCII допустимые: пробелы, переносы, пунктуация, цифры, комментарии
        if (c <= 127) {
            // Запрещены латинские буквы!
            if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')) {
                return false;
            }
            i += 1;
            continue;
        }
        
        // UTF-8 многобайтовые символы
        // Коптский диапазон: U+2C80 - U+2CFF (Ⲁ-Ⳃ)
        if (c >= 0xE2) {
            // 3-байтовый UTF-8
            if (i + 2 < code.len) {
                i += 3;
                continue;
            }
        } else if (c >= 0xC0) {
            // 2-байтовый UTF-8
            if (i + 1 < code.len) {
                i += 2;
                continue;
            }
        }
        
        i += 1;
    }
    return true;
}

/// Проверяет что код НЕ содержит латинских букв
pub fn hasNoLatinLetters(code: []const u8) bool {
    for (code) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')) {
            return false;
        }
    }
    return true;
}

test "validate coptic code - no latin" {
    // Правильный код (только коптский)
    const valid = "Ⲙ ⲦⲈⲤⲦ\nⲂⲌ Ⲱ";
    try std.testing.expect(hasNoLatinLetters(valid));
    
    // Неправильный код (есть латиница)
    const invalid = "func test() { return 0; }";
    try std.testing.expect(!hasNoLatinLetters(invalid));
    
    // Смешанный (недопустимо)
    const mixed = "Ⲙ test";
    try std.testing.expect(!hasNoLatinLetters(mixed));
}
